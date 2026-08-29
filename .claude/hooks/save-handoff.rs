#!/usr/bin/env rust-script
//! PostCompact hook: archive the compaction summary as a durable handoff doc.
//!
//! stdin: {"hook_event_name":"PostCompact","trigger":"manual|auto","compact_summary":"...","cwd":"..."}
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

    let raw = payload["compact_summary"].as_str().unwrap_or_default();
    let unwrapped = strip_wrappers(raw);
    let summary = drop_leading_blank_lines(&unwrapped).trim_end_matches('\n');
    if summary.is_empty() {
        return Ok(());
    }

    let dir = handoff_dir()?;
    fs::create_dir_all(&dir)?;
    let file = dir.join(format!("{}-{}.md", slug(cwd(&payload)?), timestamp()));
    fs::write(&file, format!("{summary}\n"))?;

    prune(&dir, 50);

    println!("handoff saved → {}", file.display());
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

fn drop_leading_blank_lines(text: &str) -> &str {
    text.trim_start_matches('\n')
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
