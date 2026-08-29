#!/usr/bin/env rust-script
//! SessionStart hook (matcher: clear) — inject a pending handoff doc into the fresh
//! session, announce it visibly, kick off the work, then consume the doc so a later
//! /clear never re-injects a stale handoff.
//!
//! stdin:  {"hook_event_name":"SessionStart","source":"clear","cwd":"...", ...}
//! stdout: JSON — hookSpecificOutput.additionalContext (the doc),
//!         .initialUserMessage (auto-resume), .sessionTitle, plus systemMessage.
//!
//! ```cargo
//! [dependencies]
//! chrono = "0.4"
//! serde_json = "1"
//! ```

use std::error::Error;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

fn main() -> Result<(), Box<dyn Error>> {
    let mut stdin = String::new();
    std::io::stdin().read_to_string(&mut stdin)?;
    let payload: serde_json::Value = serde_json::from_str(&stdin)?;

    let slug = slug(cwd(&payload)?);
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

    prune(&dir, 50);

    let output = serde_json::json!({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": format!(
                "A handoff document from the previous session follows. \
                 Treat it as the full context for this session.\n\n{doc}"
            ),
            "initialUserMessage": "Pick up from the handoff above. Start with its \"Next action\" section. Do not summarise the handoff back to me — just continue the work.",
            "sessionTitle": title,
        },
        "systemMessage": format!("↩ handoff injected from the previous session — archived to {}", archive.display()),
    });
    println!("{output}");
    Ok(())
}

/// The doc's first `# ` heading, capped to something that fits a session title.
fn title_of(doc: &str) -> Option<String> {
    let heading = doc.lines().find_map(|line| line.strip_prefix("# "))?;
    let title: String = heading.chars().take(60).collect();
    (!title.is_empty()).then_some(title)
}

fn cwd(payload: &serde_json::Value) -> Result<String, Box<dyn Error>> {
    match payload["cwd"].as_str() {
        Some(cwd) if !cwd.is_empty() => Ok(cwd.to_string()),
        _ => Ok(std::env::current_dir()?.to_string_lossy().into_owned()),
    }
}

/// One handoff file per project, named after the working directory.
fn slug(cwd: String) -> String {
    let base = Path::new(&cwd)
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

fn timestamp() -> String {
    chrono::Local::now().format("%Y-%m-%d-%H%M%S").to_string()
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
