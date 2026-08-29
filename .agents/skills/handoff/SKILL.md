---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

**Save it to exactly this path**, overwriting whatever is there:

```
~/.claude/handoffs/pending-<basename of the current working directory>.md
```

Create `~/.claude/handoffs/` if it does not exist. Sanitise the basename to `[A-Za-z0-9._-]`. Do not write it into the workspace, and do not invent a different filename — a `SessionStart` hook reads this exact path on the next `/clear` and injects it into the fresh session automatically. A different path means the handoff is silently lost.

Follow the structure and rules in `~/.dotfiles/.claude/compact-handoff.md` — read that file and use its seven sections (Goal, Current state, Key decisions, Artifacts, Traps, Suggested skills, Next action) verbatim. It is the single source of truth for handoff shape, shared with the `PreCompact` hook.

If the user passed arguments, treat them as a description of what the next session will focus on, and weight the document toward it.

When you are done, tell the user the doc is ready and that `/clear` will pick it up — nothing needs to be copied.
