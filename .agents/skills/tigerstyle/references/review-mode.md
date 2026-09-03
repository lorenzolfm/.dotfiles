# Review Mode

Use this when the user asks to audit code against TigerStyle rather than to write code in it. Report findings; do not change code until the user selects what to fix.

## Contents

- [Phase 0 — Scope and conventions](#phase-0--scope-and-conventions)
- [Phase 1 — The mechanical pass](#phase-1--the-mechanical-pass)
- [Phase 2 — The judgement pass](#phase-2--the-judgement-pass)
- [Severity](#severity)
- [The report](#the-report)
- [What a review must not report](#what-a-review-must-not-report)

## Phase 0 — Scope And Conventions

Set the scope: a diff, a module, a file, or a pull request. A whole repository is not a scope.

Read `CLAUDE.md`/`AGENTS.md`, the formatter config and the linter config **first**. Local conventions outrank TigerStyle. If the project formats at 80 columns, 80 is the limit for this review; do not report 90-column lines as violations, and note in the report which TigerStyle numbers the project has overridden.

Then state which language mechanisms exist here, so findings are actionable: does the language have compile-time assertions, sum types, sized integers, an assertion form that survives release builds? For Rust, read `rust.md`.

## Phase 1 — The Mechanical Pass

These are countable. Count them; do not eyeball.

| Check | Rule | How |
|-------|------|-----|
| Function length | ≤ 70 lines | Count bodies; list every function over |
| Line length | ≤ 100 columns | Find lines over the limit |
| Assertion density | ≥ 2 per function, averaged | Count assertions ÷ functions in scope |
| Loop bounds | Every loop bounded | For each loop, name the bound or mark it unbounded |
| Recursion | None | Find direct and mutual recursion |
| Error handling | All handled | Find discarded results, empty catches, swallowed errors |
| Dependencies | No unjustified additions | Diff the manifest |

Report the assertion density as a single number for the scope, then list the functions with zero assertions. Zero-assertion functions matter more than the average.

## Phase 2 — The Judgement Pass

These need reading, not counting. For each, cite the file and line.

- **Compound conditions and negated invariants.** Does a condition make it hard to verify every case is handled? Is an invariant stated negatively where the positive form reads naturally?
- **Missing negative space.** Is only the expected case asserted? Where does data cross the valid/invalid boundary with nothing checking it?
- **Unpaired assertions.** Is a property asserted on write but not on the matching read?
- **Scattered control flow.** Do branches live in leaf functions instead of the parent? Do helpers mutate state instead of computing it?
- **Names.** Abbreviations, units in the wrong position, overloaded terms, participles where a noun belongs, related names of unequal width.
- **Aliased or duplicated state**, variables declared far from use, POCPOU gaps.
- **Return-type dimensionality.** Is a `Result`/`Option` propagating through the call chain when the value could be validated once at the boundary?
- **Off-by-one surface.** Are `index`, `count` and `size` distinguishable by name? Is division's rounding intent visible?
- **Unmotivated decisions.** Is there a non-obvious choice with no comment saying why?

## Severity

- **Critical** — a safety rule is broken and a real input reaches it: an unbounded loop or queue on a request path, an unhandled error on a write path, recursion on attacker-controlled depth, a buffer bleed.
- **High** — a safety rule is broken with no demonstrated path yet: a zero-assertion function on a hot path, a swallowed error in a branch nothing currently hits, an unbounded internal loop.
- **Medium** — a hard rule is broken without a safety consequence: a 140-line function, lines past the column limit, an undocumented dependency addition.
- **Low** — style and clarity: naming, ordering, comment quality, a compound condition that reads badly.

Rank by severity, not by file order. A reviewer reads the top of the list.

## The Report

1. **Scope** — what was read, and which TigerStyle numbers the project has overridden.
2. **The mechanical table** — the Phase 1 counts, pass or fail per row, with the worst offenders named.
3. **Findings**, most severe first. Each one: the rule, the location as `file:line`, what the code does, what goes wrong, and the fix.
4. **What is already good.** Name it. A review that only lists faults gets discounted as noise.
5. **Suggested order of work**, marking anything that needs a design decision rather than an edit.

Then stop and let the user choose.

## What A Review Must Not Report

- **Violations in untouched code when the scope was a diff.** If the user asked about a change, review the change.
- **A rule the project has explicitly overridden.** Read the config first; do not relitigate the project's own choices.
- **"Add an assertion here" with no candidate assertion.** State the property to assert. If you cannot name a property, there is no finding.
- **Function-length findings with no split proposal.** Name the seam — which fragment becomes a helper, and whether control flow stays in the parent. If a split would scatter branching, say the function should stay long and why.
- **Dependency findings for dependencies that already existed.** H7 governs *additions*.
- **Reformatting as a finding.** If the formatter has not been run, that is one finding, not one per line.
