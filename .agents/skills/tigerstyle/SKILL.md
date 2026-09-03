---
name: tigerstyle
description: Apply TigerBeetle's TigerStyle when writing, editing or reviewing code — safety first, then performance, then developer experience. Covers bounded everything, assertion density, small functions, exact naming, off-by-one discipline and a zero-dependency default. The rules are language-agnostic with Rust-first examples. Use this skill when the user asks for TigerStyle or TigerBeetle style, when a repository declares TigerStyle as its convention, or to audit existing code against it.
---

# TigerStyle

TigerStyle is TigerBeetle's coding style, from `docs/TIGER_STYLE.md`. It is a design discipline, not a formatter. This skill states its rules language-agnostically; `references/rust.md` maps the Zig-specific mechanisms.

## The Design Goals, In Order

**Safety, then performance, then developer experience.** All three matter. When two conflict, the earlier one wins. Readability is table stakes — a means, not the end.

> "The design is not just what it looks like and feels like. The design is how it works." — Steve Jobs

Two corollaries that shape every decision below:

- **Simplicity is the hardest revision, not the first attempt.** Spend the thought upfront, before implementation and testing multiply the cost of changing it.
- **Zero technical debt.** Ask "what could go wrong", not "what's wrong". When a showstopper is found, solve it now — do not ship a known latency spike or a known exponential algorithm with a TODO.

## Two Modes

**Apply** (default) — writing or editing code. Follow the hard rules below without being asked. Consult the reference file for whichever discipline the code touches.

**Review** — auditing existing code against TigerStyle. Read `references/review-mode.md` for the workflow, severity scale and report shape. Do not change code before the user selects findings.

Pick Apply unless the user asked for a review, an audit, or "does this follow TigerStyle".

## Hard Rules

These are mechanically checkable. Do not break one silently. To break one, say why in the same breath and let the user decide.

| # | Rule | The check | Why |
|---|------|-----------|-----|
| H1 | **70 lines per function, maximum** | Count the body | There is a sharp discontinuity between a function that fits on a screen and one that needs scrolling |
| H2 | **100 columns per line, maximum** | Count the widest line | Two copies of the code fit side by side; nothing hides behind a horizontal scrollbar |
| H3 | **Every loop and every queue has a fixed upper bound** | Name the bound for each | Fail fast: an unbounded loop is an infinite loop or a tail-latency spike that has not happened yet |
| H4 | **A loop that cannot terminate asserts that fact** | An event loop asserts its own invariant | The exception to H3 must be deliberate and visible |
| H5 | **Two assertions per function, on average** | Count assertions ÷ functions in the change | Assertions downgrade catastrophic correctness bugs into liveness bugs, and multiply the yield of fuzzing |
| H6 | **Assert arguments, return values, preconditions, postconditions and invariants** | Every function checks the data it operates on | A function's purpose is to raise the probability that the program is correct |
| H7 | **No new third-party dependency without accepted justification** | State the cost, name the alternative, wait for the user | Dependencies are supply-chain, safety, performance and install-time risk, amplified for anything foundational |

Where the project configures its own limits, those replace H1 and H2. Otherwise break a rule only where the user agrees the code cannot be written another way, and say which rule and why. H7 is always a question to the user, never a unilateral `cargo add`.

## The Disciplines

Each line is the whole rule in short form. Read the reference file before working in that area.

### Safety — `references/safety.md`

- Only simple, explicit control flow. **No recursion**, so that everything bounded is provably bounded.
- Put a limit on everything. Explicitly-sized types (`u32`, not `usize`) for everything crossing a boundary.
- Assert the **positive space** you expect and the **negative space** you do not. Bugs live where data crosses that border.
- **Pair assertions**: for every property, find two code paths to assert it — before a write and after the matching read.
- Split compound assertions: `assert(a); assert(b);` beats `assert(a && b);`.
- Split compound conditions into nested `if`/`else`. State invariants **positively** (`if index < count`, not `if index >= count`).
- **All errors are handled.** 92% of catastrophic distributed-system failures came from mishandling errors the software had already signalled.
- Pass options explicitly at the call site instead of relying on library defaults.
- Do not react directly to external events — run at your own pace and batch.
- Advisory (TigerBeetle-specific, weigh before adopting): allocate all memory at startup, never after.

### Performance — `references/performance.md`

- The 1000x wins are in the design phase, exactly when you cannot profile. Sketch first.
- Back-of-the-envelope across four resources — **network, disk, memory, CPU** — on two axes, bandwidth and latency.
- Optimize the slowest resource first, after weighting by frequency.
- Batch to amortize. Separate control plane from data plane so assertions cost nothing on the hot path.
- Be explicit; do not depend on the compiler. Extract hot loops into standalone functions with primitive arguments.

### Naming — `references/naming.md`

- Get the nouns and verbs exactly right; great names are the essence of great code.
- `snake_case` for functions, variables and files. No abbreviations. Long-form flags (`--force`).
- Units and qualifiers last, sorted by descending significance: `latency_ms_max`, not `max_latency_ms`.
- Infuse names with meaning (`gpa`/`arena`, not `allocator`). Match character counts on related names (`source`/`target`) so calculations line up.
- Prefix a helper with its caller: `read_sector()` and `read_sector_callback()`. Callbacks go last in the parameter list.
- Order matters: `main` first; in a type, fields, then types, then methods.
- Prefer nouns over present participles (`replica.pipeline`, not `replica.preparing`) so the name survives into prose.
- Never overload a name with a second, context-dependent meaning.

### Correctness — `references/correctness.md`

- Do not duplicate variables or alias them; state drifts out of sync.
- Declare at the smallest possible scope. Compute values close to their use — a gap in time or space is a gap you cannot check.
- Simpler return types reduce dimensionality at every call site: `void` > `bool` > `u64` > `Option<u64>` > `Result<u64>`.
- Off-by-one: `index`, `count` and `size` are distinct types wearing the same integer. Index → count adds one; count → size multiplies by the unit.
- Show intent with division — say floor, ceil or exact rather than letting `/` decide.
- Watch for **buffer bleeds**: under-filled buffers with unzeroed padding.
- Group allocation with its matching cleanup using blank lines, so a leak is visible.

### Communication

- **Always motivate. Always say why.** A rationale shares the criteria by which the decision can be re-evaluated.
- Comments explain *why*, and for a test, *how* — its goal and methodology. Code alone is not documentation.
- Comments are sentences: space after the marker, capital letter, full stop (or colon when introducing what follows). End-of-line comments may be phrases without punctuation.
- Write descriptive commit messages. A PR description is not in `git blame` and is not a substitute.

## Rules For Working This Way

- **Announce the goal a decision serves.** When you make a trade-off, name which of safety, performance or developer experience won, and what lost.
- **Local conventions outrank this skill.** Read `CLAUDE.md`/`AGENTS.md`, the linter and the formatter config first. If the repository says 80 columns or 2-space indent, that wins over TigerStyle's 100 and 4.
- **Do not retrofit uninvited.** Apply TigerStyle to the code being written or changed. Reformatting untouched files is not the task.
- **Do not add assertions as decoration.** An assertion must encode a real belief about the code. Two useless assertions per function is worse than none — it teaches the reader to ignore them.
- **Do not confuse assertions with error handling.** Operating errors are expected and must be handled. Assertion failures are programmer errors, and crashing is the correct response.
- **Splitting a function to satisfy H1 must improve it.** Centralize control flow in the parent, push non-branchy fragments into pure leaf helpers — "push `if`s up and `for`s down". A split that scatters branching has made the code worse; say so rather than doing it.
- **Zig-specific mechanisms need translation, not imitation.** Read `references/rust.md` before writing assertions, integer types or division in Rust.

## References

- `references/safety.md` — assertions, bounds, control flow, error handling, static allocation.
- `references/performance.md` — sketching, the four resources, batching, control vs data plane.
- `references/naming.md` — the full naming discipline, with worked before/after pairs.
- `references/correctness.md` — aliasing, scope, off-by-one, return-type dimensionality, buffer bleeds.
- `references/rust.md` — the Zig-to-Rust mapping: assertions, sized types, division, formatting, allocation.
- `references/review-mode.md` — the audit workflow, severity scale and report format.
- Source: <https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md>
