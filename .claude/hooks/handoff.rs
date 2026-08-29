#!/usr/bin/env rust-script
//! Handoff hooks — two events, one script, no third-party crates.
//!
//! PostCompact: archive the compaction summary as a durable handoff doc.
//!
//! SessionStart (matcher: clear): inject a pending handoff doc into the fresh
//! session, announce it visibly, kick off the work, then consume the doc so a
//! later /clear never re-injects a stale handoff.
//!
//! Both hooks in settings.json point at this file; `hook_event_name` on stdin
//! decides which half runs.

use std::error::Error;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::SystemTime;

/// Sent as the first user message of the injected session.
const RESUME: &str = "Pick up from the handoff above. Start with its \"Next action\" section. \
                      Do not summarise the handoff back to me — just continue the work.";

/// How many archived handoffs to keep.
const KEEP: usize = 50;

fn main() -> Result<(), Box<dyn Error>> {
    let mut stdin = String::new();
    std::io::stdin().read_to_string(&mut stdin)?;
    match json::field(&stdin, "hook_event_name")?.as_deref() {
        Some("PostCompact") => save(&stdin),
        Some("SessionStart") => inject(&stdin),
        _ => Ok(()),
    }
}

/// stdin: {"hook_event_name":"PostCompact","trigger":"manual|auto","compact_summary":"...","cwd":"..."}
fn save(payload: &str) -> Result<(), Box<dyn Error>> {
    let raw = json::field(payload, "compact_summary")?.unwrap_or_default();
    let unwrapped = strip_wrappers(&raw);
    let summary = unwrapped.trim_start_matches('\n').trim_end_matches('\n');
    if summary.is_empty() {
        return Ok(());
    }

    let dir = handoff_dir()?;
    fs::create_dir_all(&dir)?;
    let file = dir.join(format!("{}-{}.md", slug(&cwd(payload)?), timestamp()));
    fs::write(&file, format!("{summary}\n"))?;

    prune(&dir, KEEP);

    println!("handoff saved → {}", file.display());
    Ok(())
}

/// stdin:  {"hook_event_name":"SessionStart","source":"clear","cwd":"...", ...}
/// stdout: JSON — hookSpecificOutput.additionalContext (the doc),
///         .initialUserMessage (auto-resume), .sessionTitle, plus systemMessage.
fn inject(payload: &str) -> Result<(), Box<dyn Error>> {
    let slug = slug(&cwd(payload)?);
    let dir = handoff_dir()?;
    let pending = dir.join(format!("pending-{slug}.md"));
    if !pending.is_file() {
        return Ok(()); // plain /clear, nothing pending — stay silent
    }

    let doc = fs::read_to_string(&pending)?;
    let doc = doc.trim_end_matches('\n');
    if doc.is_empty() {
        return Ok(());
    }

    let title = title_of(doc).unwrap_or_else(|| format!("Handoff: {slug}"));
    let archive = dir.join(format!("{slug}-{}.md", timestamp()));
    fs::rename(&pending, &archive)?;

    prune(&dir, KEEP);

    let context = format!(
        "A handoff document from the previous session follows. \
         Treat it as the full context for this session.\n\n{doc}"
    );
    let specific = json::object(&[
        ("hookEventName", json::quote("SessionStart")),
        ("additionalContext", json::quote(&context)),
        ("initialUserMessage", json::quote(RESUME)),
        ("sessionTitle", json::quote(&title)),
    ]);
    let announcement = format!(
        "↩ handoff injected from the previous session — archived to {}",
        archive.display()
    );
    println!(
        "{}",
        json::object(&[
            ("hookSpecificOutput", specific),
            ("systemMessage", json::quote(&announcement)),
        ])
    );
    Ok(())
}

/// Drop the `<analysis>` block the compactor emits and unwrap the `<summary>` tags,
/// leaving just the handoff body.
fn strip_wrappers(raw: &str) -> String {
    let mut out = String::with_capacity(raw.len());
    let mut rest = raw;
    while let Some(open) = rest.find("<analysis>") {
        let after_open = &rest[open + "<analysis>".len()..];
        // An unterminated block is not a block: leave the rest untouched.
        let Some(close) = after_open.find("</analysis>") else { break };
        out.push_str(&rest[..open]);
        rest = &after_open[close + "</analysis>".len()..];
    }
    out.push_str(rest);
    out.replace("<summary>", "").replace("</summary>", "")
}

/// The doc's first `# ` heading, capped to something that fits a session title.
fn title_of(doc: &str) -> Option<String> {
    let heading = doc.lines().find_map(|line| line.strip_prefix("# "))?;
    let title: String = heading.chars().take(60).collect();
    (!title.is_empty()).then_some(title)
}

fn cwd(payload: &str) -> Result<String, Box<dyn Error>> {
    match json::field(payload, "cwd")? {
        Some(cwd) if !cwd.is_empty() => Ok(cwd),
        _ => Ok(std::env::current_dir()?.to_string_lossy().into_owned()),
    }
}

/// One handoff file per project, named after the working directory.
fn slug(cwd: &str) -> String {
    let base = Path::new(cwd)
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    let sanitised: String = base
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-') { c } else { '-' })
        .collect();
    match sanitised.trim_end_matches('-') {
        "" => "session".to_string(),
        slug => slug.to_string(),
    }
}

fn handoff_dir() -> Result<PathBuf, Box<dyn Error>> {
    let home = std::env::var("HOME")?;
    Ok(PathBuf::from(home).join(".claude/handoffs"))
}

/// Local wall-clock time, from coreutils rather than a date crate. If `date` is
/// missing, epoch seconds still sort and still never collide.
fn timestamp() -> String {
    Command::new("date")
        .arg("+%Y-%m-%d-%H%M%S")
        .output()
        .ok()
        .filter(|out| out.status.success())
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
        .filter(|stamp| !stamp.is_empty())
        .unwrap_or_else(|| {
            SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .map(|since| since.as_secs().to_string())
                .unwrap_or_else(|_| "0".to_string())
        })
}

/// Keep the `keep` most recent archives. `pending-*.md` is the skill's inbox, not an
/// archive — it is never a pruning candidate.
fn prune(dir: &Path, keep: usize) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    let mut archives: Vec<(SystemTime, PathBuf)> = entries
        .flatten()
        .filter(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            name.ends_with(".md") && !name.starts_with("pending-")
        })
        .filter_map(|entry| Some((entry.metadata().ok()?.modified().ok()?, entry.path())))
        .collect();
    archives.sort_by(|a, b| b.0.cmp(&a.0));
    for (_, stale) in archives.into_iter().skip(keep) {
        let _ = fs::remove_file(stale);
    }
}

/// Just enough JSON for a hook payload: pull a string field off the top-level
/// object, and build the object we answer with.
///
/// The reader walks the object properly instead of searching for the key,
/// because the payload carries arbitrary conversation text — a summary quoting
/// `"cwd": "/somewhere/else"` must not be mistaken for the real field.
mod json {
    /// The string value of a top-level `key`, or `None` when it is absent or
    /// holds something other than a string.
    pub fn field(input: &str, key: &str) -> Result<Option<String>, String> {
        let mut parser = Parser { input, pos: 0 };
        parser.space();
        parser.expect('{')?;
        parser.space();
        if parser.peek() == Some('}') {
            return Ok(None);
        }
        loop {
            parser.space();
            let found = parser.string()?;
            parser.space();
            parser.expect(':')?;
            parser.space();
            if found == key {
                return match parser.peek() {
                    Some('"') => Ok(Some(parser.string()?)),
                    _ => Ok(None),
                };
            }
            parser.value()?;
            parser.space();
            match parser.bump() {
                Some(',') => continue,
                Some('}') => return Ok(None),
                other => return Err(format!("expected `,` or `}}`, found {other:?}")),
            }
        }
    }

    /// `text` as a JSON string literal, quotes included.
    pub fn quote(text: &str) -> String {
        let mut out = String::with_capacity(text.len() + 2);
        out.push('"');
        for c in text.chars() {
            match c {
                '"' => out.push_str("\\\""),
                '\\' => out.push_str("\\\\"),
                '\n' => out.push_str("\\n"),
                '\r' => out.push_str("\\r"),
                '\t' => out.push_str("\\t"),
                c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
                c => out.push(c),
            }
        }
        out.push('"');
        out
    }

    /// An object built from fields whose values are already encoded JSON.
    pub fn object(fields: &[(&str, String)]) -> String {
        let body: Vec<String> = fields
            .iter()
            .map(|(key, value)| format!("{}:{value}", quote(key)))
            .collect();
        format!("{{{}}}", body.join(","))
    }

    struct Parser<'a> {
        input: &'a str,
        pos: usize,
    }

    impl<'a> Parser<'a> {
        fn rest(&self) -> &'a str {
            &self.input[self.pos..]
        }

        fn peek(&self) -> Option<char> {
            self.rest().chars().next()
        }

        fn bump(&mut self) -> Option<char> {
            let c = self.peek()?;
            self.pos += c.len_utf8();
            Some(c)
        }

        /// Consume `prefix` if it is next, reporting whether it was.
        fn eat(&mut self, prefix: &str) -> bool {
            let found = self.rest().starts_with(prefix);
            if found {
                self.pos += prefix.len();
            }
            found
        }

        fn space(&mut self) {
            while matches!(self.peek(), Some(c) if c.is_ascii_whitespace()) {
                self.pos += 1;
            }
        }

        fn expect(&mut self, want: char) -> Result<(), String> {
            match self.bump() {
                Some(c) if c == want => Ok(()),
                other => Err(format!("expected `{want}` at byte {}, found {other:?}", self.pos)),
            }
        }

        fn string(&mut self) -> Result<String, String> {
            self.expect('"')?;
            let mut out = String::new();
            loop {
                match self.bump().ok_or("unterminated string")? {
                    '"' => return Ok(out),
                    '\\' => out.push(self.escape()?),
                    c => out.push(c),
                }
            }
        }

        /// The character a `\` introduces.
        fn escape(&mut self) -> Result<char, String> {
            Ok(match self.bump().ok_or("unterminated escape")? {
                '"' => '"',
                '\\' => '\\',
                '/' => '/',
                'b' => '\u{8}',
                'f' => '\u{c}',
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'u' => self.unicode()?,
                other => return Err(format!("unknown escape `\\{other}`")),
            })
        }

        /// A `\uXXXX` body, rejoining the surrogate pair JSON uses for anything
        /// above the BMP. A half pair degrades to U+FFFD rather than failing the
        /// whole parse.
        fn unicode(&mut self) -> Result<char, String> {
            let leading = self.hex4()?;
            let code = match leading {
                0xD800..=0xDBFF if self.eat("\\u") => match self.hex4()? {
                    trailing @ 0xDC00..=0xDFFF => {
                        0x10000 + ((leading - 0xD800) << 10) + (trailing - 0xDC00)
                    }
                    _ => return Ok(char::REPLACEMENT_CHARACTER),
                },
                0xD800..=0xDFFF => return Ok(char::REPLACEMENT_CHARACTER),
                bmp => bmp,
            };
            Ok(char::from_u32(code).unwrap_or(char::REPLACEMENT_CHARACTER))
        }

        fn hex4(&mut self) -> Result<u32, String> {
            let mut code = 0;
            for _ in 0..4 {
                let c = self.bump().ok_or("truncated `\\u` escape")?;
                let digit = c.to_digit(16).ok_or_else(|| format!("bad hex digit `{c}`"))?;
                code = code * 16 + digit;
            }
            Ok(code)
        }

        /// Advance past one value of any type without building it.
        fn value(&mut self) -> Result<(), String> {
            self.space();
            match self.peek().ok_or("expected a value")? {
                '"' => {
                    self.string()?;
                }
                '{' => self.nested('{', '}')?,
                '[' => self.nested('[', ']')?,
                _ => self.literal(),
            }
            Ok(())
        }

        /// Skip a balanced object or array. Strings are skipped *as strings*, so a
        /// stray `}` inside conversation text cannot close the payload early.
        fn nested(&mut self, open: char, close: char) -> Result<(), String> {
            self.expect(open)?;
            loop {
                self.space();
                match self.peek().ok_or("unterminated object or array")? {
                    '"' => {
                        self.string()?;
                    }
                    c if c == close => {
                        self.bump();
                        return Ok(());
                    }
                    '{' => self.nested('{', '}')?,
                    '[' => self.nested('[', ']')?,
                    // Separators, numbers and bare literals need no structure.
                    _ => {
                        self.bump();
                    }
                }
            }
        }

        /// Skip a number, `true`, `false` or `null` — anything that ends where the
        /// surrounding structure resumes.
        fn literal(&mut self) {
            while let Some(c) = self.peek() {
                if matches!(c, ',' | '}' | ']') || c.is_ascii_whitespace() {
                    return;
                }
                self.bump();
            }
        }
    }
}
