Shape the <summary> as a handoff document for a fresh agent picking this work up cold — not a chronological recap of the conversation.

Structure it exactly like this:

1. **Goal** — what we are trying to achieve and why. Write it so it stands alone, with no reference to "the conversation" or "the user asked".
2. **Current state** — what is done, what is half-done, what is still untouched. Mark each claim as verified (tested/observed) or assumed.
3. **Key decisions** — choices already made and the reasoning behind them, so they are not relitigated.
4. **Artifacts** — specs, plans, ADRs, issues, commits, diffs, and files touched, referenced by path or URL. Do NOT duplicate content that already lives in them; point to them instead.
5. **Traps** — dead ends already tried, gotchas, environment quirks, and anything that cost time. Be specific about what failed and how it failed.
6. **Suggested skills** — skills the next agent should invoke, by name.
7. **Next action** — the single concrete thing to do next, specific enough to begin immediately without asking a question.

Rules:

- Preserve exact identifiers verbatim: file paths, function and symbol names, shell commands, error strings, URLs, version numbers. Never paraphrase these.
- Redact secrets and personal data — API keys, tokens, passwords, PII — as [REDACTED].
- Drop conversational back-and-forth that changed nothing, and drop work that was superseded.
- If a focus for the next session was given above, weight every section toward it and cut what is irrelevant to it.
