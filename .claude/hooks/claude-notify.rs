#!/usr/bin/env rust-script
//! Notification hook — one notification per agent pane, and a click that jumps
//! to it. No third-party crates.
//!
//! Wired to `Notification` and `Stop` in settings.json. `Notification` is Claude
//! Code's own "I need your attention" event, and it fires whatever
//! `preferredNotifChannel` is set to: the dispatcher runs the hook first and
//! applies the channel after. `PermissionRequest` is deliberately not wired,
//! because it sits on the permission path for every tool call, including the
//! ones auto mode approves.
//!
//! Two phases, one file. With no argument this reads the payload on stdin and
//! decides whether to notify at all. With `--await` it *is* the waiter:
//! `notify-send --action` blocks until the notification is clicked or
//! dismissed, which cannot happen inside the hook itself, because Claude Code
//! reaps the hook long before a person reacts. So the first phase re-launches
//! the second under `setsid` and returns immediately.

use std::env;
use std::error::Error;
use std::io::Read;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, Stdio};

/// Freedesktop sounds, by the name each alert picks below.
const SOUNDS: &str = "/run/current-system/sw/share/sounds/freedesktop/stereo";

/// Long enough to carry a thought, short enough that swaync does not reflow.
const BODY_CHARS: usize = 150;

/// What the body says when the payload carried no text of its own.
const FALLBACK_BODY: &str = "Needs your attention";

fn main() {
    // A notification that fails must never fail the turn. Report on stderr,
    // which `claude --debug` surfaces, and always leave with 0.
    if let Err(error) = run() {
        eprintln!("claude-notify: {error}");
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    match env::args().nth(1).as_deref() {
        Some("--await") => await_click(),
        _ => announce(),
    }
}

/// How an event reads on screen.
struct Alert {
    headline: &'static str,
    urgency: &'static str,
    sound: &'static str,
    /// Replaces the payload's own text when that text is boilerplate.
    body: Option<&'static str>,
}

/// The reading of an event, or `None` for one worth no interruption.
///
/// `notification_type` is an open vocabulary that grows with the Claude Code
/// version, exactly like `claude-ps`'s `status`, so the wildcard arms are the
/// contract and not a fallback: an unknown type still reaches the screen.
fn classify(event: &str, kind: &str, message: &str) -> Option<Alert> {
    let alert = |headline, urgency, sound| {
        Some(Alert {
            headline,
            urgency,
            sound,
            body: None,
        })
    };
    // A turn asking something of its own, wearing a permission prompt.
    let asking = |headline, body| {
        Some(Alert {
            headline,
            urgency: "critical",
            sound: "window-question.oga",
            body: Some(body),
        })
    };
    match (event, kind) {
        // Signing in is not a reason to look at the screen — you are at it.
        ("Notification", "auth_success") => None,
        ("Notification", "permission_prompt" | "worker_permission_prompt") => {
            match tool_named(message) {
                Some("AskUserQuestion") => asking("asked you something", "Waiting on your answer"),
                Some("ExitPlanMode") => asking("has a plan for you", "Waiting on your review"),
                _ => alert("needs permission", "critical", "bell.oga"),
            }
        }
        ("Notification", "agent_needs_input") => alert("needs input", "critical", "bell.oga"),
        ("Notification", "idle_prompt") => {
            alert("waiting for you", "normal", "message-new-instant.oga")
        }
        ("Notification", "agent_completed") => alert("done", "normal", "complete.oga"),
        ("Notification", _) => alert("needs you", "critical", "bell.oga"),
        ("Stop", _) => alert("done", "normal", "complete.oga"),
        _ => alert("needs your attention", "normal", "bell.oga"),
    }
}

/// The tool a permission message is about.
///
/// Claude Code routes every interactive tool through the permission path, so
/// the tool name is the only thing separating a question from a request to run
/// a command. The message reads `Claude needs your permission to use <Tool>`,
/// sometimes with the arguments trailing, and a reworded message simply yields
/// `None` — the generic reading, which was the behaviour before this existed.
fn tool_named(message: &str) -> Option<&str> {
    let tail = message.rsplit_once(" to use ")?.1;
    let tool = tail.split([' ', '(']).next()?;
    (!tool.is_empty()).then_some(tool)
}

/// Phase one: read the payload, decide, and hand a decided notification to a
/// detached phase two.
fn announce() -> Result<(), Box<dyn Error>> {
    let mut payload = String::new();
    std::io::stdin().read_to_string(&mut payload)?;
    if payload.trim().is_empty() {
        payload.push_str("{}");
    }

    let field = |key| json::field(&payload, key).unwrap_or_default().unwrap_or_default();
    let event = field("hook_event_name");
    let kind = field("notification_type");
    let cwd = field("cwd");

    // `Stop` carries no `message`; its context is the turn that just ended.
    let text = match field("message") {
        text if text.is_empty() => field("last_assistant_message"),
        text => text,
    };

    let target = zellij_target(&field("session_id"));

    // Nothing to announce about a pane you are already reading.
    if let Some((session, _)) = &target {
        if focused_on(session) {
            return Ok(());
        }
    }

    let Some(alert) = classify(&event, &kind, &text) else {
        return Ok(());
    };

    // Label by zellij session, the same vocabulary claude-tray and the vicinae
    // extension use, so one agent reads the same everywhere. Pane 0 is the
    // common case and stays implicit.
    let label = match &target {
        Some((session, pane)) if pane != "0" => format!("{session}:{pane}"),
        Some((session, _)) => session.clone(),
        None => Path::new(&cwd)
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_else(|| "claude".into()),
    };

    let title = format!("{label} — {}", alert.headline);
    let body = match alert.body.map(str::to_owned).unwrap_or_else(|| oneline(&text)) {
        body if body.is_empty() => FALLBACK_BODY.to_string(),
        body => body,
    };

    if cfg!(target_os = "macos") {
        Command::new("terminal-notifier")
            .args(["-title", &title, "-message", &body])
            .args(["-activate", "com.mitchellh.ghostty"])
            .status()?;
        return Ok(());
    }

    let (session, pane) = target.unwrap_or_default();
    Command::new("setsid")
        .arg("--fork")
        .arg(env::current_exe()?)
        .arg("--await")
        .env("CN_TITLE", title)
        .env("CN_BODY", pango_escape(&body))
        .env("CN_URGENCY", alert.urgency)
        .env("CN_SOUND", format!("{SOUNDS}/{}", alert.sound))
        .env("CN_TAG", format!("claude-{label}"))
        .env("CN_SESSION", session)
        .env("CN_PANE", pane)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    Ok(())
}

/// Phase two, detached: show the notification, wait, and jump if it was clicked.
///
/// swaync treats the reserved action key `default` as a click on the body
/// rather than a button, which is why the notification needs no visible button
/// to be clickable.
fn await_click() -> Result<(), Box<dyn Error>> {
    let var = |key| env::var(key).unwrap_or_default();

    let sound = var("CN_SOUND");
    if Path::new(&sound).exists() {
        Command::new("pw-play")
            .arg(&sound)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .ok();
    }

    let clicked = Command::new("notify-send")
        .args(["--app-name", "Claude"])
        .args(["--icon", &icon()])
        .args(["--urgency", &var("CN_URGENCY")])
        .args([
            "--hint",
            &format!("string:x-canonical-private-synchronous:{}", var("CN_TAG")),
        ])
        .args(["--action", "default=Jump to pane"])
        .args(["--", &var("CN_TITLE"), &var("CN_BODY")])
        .output()?;

    let session = var("CN_SESSION");
    if String::from_utf8_lossy(&clicked.stdout).trim() == "default" && !session.is_empty() {
        // claude-nav owns every rule about reaching a pane: which window shows
        // it, whether to raise or retarget, and when to attach a new terminal.
        Err(Command::new("claude-nav")
            .args(["jump", &session, &var("CN_PANE")])
            .exec()
            .into())
    } else {
        Ok(())
    }
}

fn icon() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{home}/.local/share/icons/notifications/claude.png")
}

/// The agent's zellij pane, as `(session, pane)`.
///
/// The hook runs inside the pane, so the environment already holds the answer
/// and costs nothing. `claude-ps` is the fallback for the case the environment
/// cannot cover — a pane renumbered since the agent started — and it joins on
/// `session_id`, the one key a hook payload and a `claude-ps` row share.
fn zellij_target(session_id: &str) -> Option<(String, String)> {
    let from_env = (
        env::var("ZELLIJ_SESSION_NAME").unwrap_or_default(),
        env::var("ZELLIJ_PANE_ID").unwrap_or_default(),
    );
    if !from_env.0.is_empty() && !from_env.1.is_empty() {
        return Some(from_env);
    }
    if session_id.is_empty() {
        return None;
    }

    let listing = Command::new("claude-ps").output().ok()?;
    let listing = String::from_utf8(listing.stdout).ok()?;
    for agent in json::elements(&listing).ok()? {
        if json::field(agent, "session_id").ok()?.as_deref() != Some(session_id) {
            continue;
        }
        // `zellij` is null for an agent running outside zellij. It has no pane,
        // so it has nowhere to jump to, and the notification still goes out.
        let pane = json::raw_field(agent, "zellij").ok()??;
        return Some((
            json::field(pane, "session").ok()??,
            json::field(pane, "pane").ok()??,
        ));
    }
    None
}

/// Whether the focused window is showing that zellij session.
///
/// ghostty takes its title from zellij as `<session> | <pane title>`, so the
/// prefix is the whole test. Every failure here answers "not focused", which
/// keeps a stale `HYPRLAND_INSTANCE_SIGNATURE` — a zellij server outliving a
/// compositor restart — from silently swallowing notifications.
fn focused_on(session: &str) -> bool {
    let Ok(window) = Command::new("hyprctl").args(["activewindow", "-j"]).output() else {
        return false;
    };
    let Ok(window) = String::from_utf8(window.stdout) else {
        return false;
    };
    match json::field(&window, "title") {
        Ok(Some(title)) => title.starts_with(&format!("{session} | ")),
        _ => false,
    }
}

/// One line of at most `BODY_CHARS` characters, whitespace collapsed.
fn oneline(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(BODY_CHARS)
        .collect()
}

/// swaync advertises `body-markup`, so conversation text must not arrive as
/// markup. Anything a turn quoted — a generic, a shell redirect — would
/// otherwise be eaten as a tag.
fn pango_escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

/// Enough JSON to read a hook payload and a `claude-ps` listing.
///
/// A real parser rather than a search, because the payload carries arbitrary
/// conversation text — a turn quoting `"cwd": "/somewhere/else"` must not be
/// mistaken for the real field.
mod json {
    /// The string value of a top-level `key`, or `None` when it is absent or
    /// holds something other than a string.
    pub fn field(input: &str, key: &str) -> Result<Option<String>, String> {
        let Some(raw) = raw_field(input, key)? else {
            return Ok(None);
        };
        if !raw.starts_with('"') {
            return Ok(None);
        }
        let mut parser = Parser {
            input: raw,
            pos: 0,
        };
        Ok(Some(parser.string()?))
    }

    /// The value at a top-level `key`, still encoded — the way into a nested
    /// object such as `claude-ps`'s `zellij`.
    pub fn raw_field<'a>(input: &'a str, key: &str) -> Result<Option<&'a str>, String> {
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
            let start = parser.pos;
            parser.value()?;
            if found == key {
                return Ok(Some(&input[start..parser.pos]));
            }
            parser.space();
            match parser.bump() {
                Some(',') => continue,
                Some('}') => return Ok(None),
                other => return Err(format!("expected `,` or `}}`, found {other:?}")),
            }
        }
    }

    /// Every element of a top-level array, still encoded.
    pub fn elements(input: &str) -> Result<Vec<&str>, String> {
        let mut parser = Parser { input, pos: 0 };
        let mut out = Vec::new();
        parser.space();
        parser.expect('[')?;
        parser.space();
        if parser.peek() == Some(']') {
            return Ok(out);
        }
        loop {
            parser.space();
            let start = parser.pos;
            parser.value()?;
            out.push(&input[start..parser.pos]);
            parser.space();
            match parser.bump() {
                Some(',') => continue,
                Some(']') => return Ok(out),
                other => return Err(format!("expected `,` or `]`, found {other:?}")),
            }
        }
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
                other => Err(format!(
                    "expected `{want}` at byte {}, found {other:?}",
                    self.pos
                )),
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
