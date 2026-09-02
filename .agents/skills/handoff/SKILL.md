---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

**Ask for the path — do not construct it.** Run:

```bash
~/.dotfiles/.claude/hooks/handoff.rs --pending-path
```

Write the document to exactly the path it prints, overwriting whatever is there. Do not adjust, normalise, or prettify that path in any way — not even a leading dot.

The same program reads this path back on the next `/clear` and injects the document into the fresh session automatically. Deriving the filename yourself instead of asking has already silently lost a handoff (`~/.dotfiles` → the leading dot in `.dotfiles` was dropped), which is why the program is now the only thing that decides the name.

Follow the structure and rules in `~/.dotfiles/.claude/compact-handoff.md` — read that file and use its seven sections (Goal, Current state, Key decisions, Artifacts, Traps, Suggested skills, Next action) verbatim. It is the single source of truth for handoff shape, shared with the `PreCompact` hook.

If the user passed arguments, treat them as a description of what the next session will focus on, and weight the document toward it.

When you are done, tell the user the doc is ready and that `/clear` will pick it up — nothing needs to be copied.
