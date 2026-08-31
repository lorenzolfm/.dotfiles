---
name: make-illegal-states-unrepresentable
description: Audit an existing slice of code against the premise that illegal states should be unrepresentable, then propose end-to-end fixes across the Postgres schema, the query layer, the Rust types, and the API boundary. Use when asked to check a data model or state machine for holes, to harden invariants/types/constraints in existing code, to review whether illegal states are representable, or to close gaps between what the domain allows and what the code allows.
---

# Make Illegal States Unrepresentable

Read a slice of existing code, decide whether the premise below holds, and propose the changes that close every gap. Review and propose — do not apply changes until asked (see Phase 5).

> **The premise.** A program is a state machine. Our job is to build exactly the states and transitions the domain requires, and nothing else. Model data so that every value that makes sense is representable and no value that does not make sense is representable. Prefer *correct by construction* over *checked at runtime*.
> — <https://functional-architecture.org/make_illegal_states_unrepresentable/>

Two toolkits do the work:

- **Postgres** — domain types, enum types, `NOT NULL`, composite FKs, partial unique indexes, `EXCLUDE`, `CHECK`, constraint triggers, generated identity.
- **Rust** — newtypes with private fields and smart constructors, sum types instead of `Option`/`bool` soup, typestate, parse-don't-validate at the edge.

A finding is only real once it has been traced through **all four layers**. Every suggestion is end-to-end: schema → queries → runtime → API.

## The Four Layers

Authority runs downward. An invariant enforced only above the schema is not durably enforced at all.

| # | Layer | Enforces with | Guarantees | Cannot guarantee |
|---|-------|---------------|------------|------------------|
| 1 | **Schema** | domains, enums, `NOT NULL`, FKs, unique/partial-unique, `EXCLUDE`, `CHECK`, constraint triggers | Holds against *every* writer: this service, other services, migrations, a human in `psql`, concurrent transactions | Anything needing application context or external state |
| 2 | **Query layer** | guard filters (`.filter(col.is_null())`), precise row-count traits, transactions | Legal *transitions*, atomicity, no lost updates | Nothing, if a second code path skips the guard |
| 3 | **Runtime types** | newtypes, sum types, smart constructors, typestate | Illegal states cannot be *constructed* in this process; the compiler carries the proof | Anything about rows written by another process |
| 4 | **API boundary** | request/response schema, `oneof`, rejecting `UNSPECIFIED` | Nothing on its own — the wire is the widest, weakest surface. Its job is to *parse into* layer 3 | Any invariant, ever, without a parse step |

Corollaries to apply while reviewing:
- The schema is the floor. "Rust prevents it" is not an answer for a durable invariant.
- Layer 3 exists to make layer 2 unnecessary to remember. Layer 1 exists because layer 3 is not the only writer.
- The boundary parses once, at the edge, into the narrowest type — then that type flows through the whole call chain untouched.

## How To Run The Review

### Phase 0 — Scope and conventions

Establish the slice: a feature module, a table plus its queries, an endpoint plus everything behind it. Read the repo's `CLAUDE.md` / `AGENTS.md` first — documented local conventions override this skill's defaults, and existing domain types are almost always already there. Inventory what already exists before proposing anything new: `SELECT`-able domains, enum types, validated newtypes (`types/`, `src/types/`), strongly-typed IDs.

### Phase 1 — Recover the intended state machine

Do not judge anything yet. Write down, explicitly:

- **States** — every state the domain has, named.
- **Transitions** — which state can become which, triggered by what, and which are terminal.
- **Invariants** — cardinality ("at most one open bill per user"), temporal ("validity windows never overlap", "`confirmed_at >= created_at`"), monetary ("deltas are non-zero", "line items sum to the total"), referential ("the event and the bill belong to the same user").

If the intended states cannot be named from reading the code, **that is the headline finding.** A model nobody can enumerate is a model nothing can enforce.

### Phase 2 — Build the invariant × layer matrix

For every invariant from Phase 1, find where it is actually enforced. Read the migration, the queries, the types, and the proto/handler — do not infer.

```
Invariant                          | Schema      | Queries     | Types       | API
-----------------------------------|-------------|-------------|-------------|-------------
at most one open bill per user     | partial UIX | —           | —           | n/a
amount is never zero               | —           | —           | assert!()   | i64 (wide)
paid implies closed                | —           | guard filter| —           | oneof ✓
```

Empty column + real invariant = a gap. Enforcement *only* to the right of the schema = a gap.

### Phase 3 — Classify each gap

| Code | Gap | Shape |
|------|-----|-------|
| **G1** | Representable-illegal | The type or column set admits a state the domain forbids: `Option` soup, two booleans with three legal combinations, `TEXT` where an enum belongs, nullable columns that are only null in one state |
| **G2** | Guarded-not-encoded | A runtime check, `assert!`, validation function, or code comment does a job a type or constraint could do permanently |
| **G3** | Layer asymmetry | Enforced in Rust but not in Postgres (or vice versa). The DB is the durable authority; another writer will find the hole |
| **G4** | Transition hole | The state set is fine but an `UPDATE` can move between states the machine forbids: no null-guard filter, no monotonicity check, no `CHECK` tying `kind` to its timestamps |
| **G5** | Over-constrained | The dual, and a real finding: a legitimate state cannot be expressed, so the code works around the model. Look for sentinel values, `-1`, empty-string-means-absent, a "misc" enum variant, or a bool that means three things |
| **G6** | Re-widened at the boundary | The value was parsed into a good type, then flattened back to `String`/`i64`/all-optional-fields at the API or serialization edge, and reparsed downstream |

### Phase 4 — Propose end-to-end changes

Every finding carries a concrete change per layer, or an explicit "no change needed here, because …":

1. **Migration SQL** — the constraint, domain, enum, index, or `CHECK` that makes the state unwritable. Include the backfill path when live data may violate it, and the `down.sql`.
2. **Query layer** — the guard filters and row-count trait that make illegal transitions fail loudly.
3. **Rust types** — the sum type, newtype, or smart constructor, wired to the SQL type (`FromSql`/`ToSql` against the domain, `DbEnum` against the enum type).
4. **API** — the `oneof`, the required-field rejection, the narrowed response shape.

Show real code, in the repo's own idiom. Prefer the change that *deletes* branches over the change that adds a check. If a fix collapses several downstream `match` arms or removes an entire error path, say so — that is the payoff, and it is the argument that lands.

Order the work: schema first (it is the floor and it dictates the rest), then queries, then types, then the boundary.

### Phase 5 — Report, then stop

Produce the report below. Do not write migrations or edit code until the user picks what to act on — migrations are consequential, often one-per-PR, and the data model decision is theirs.

## Report Format

1. **The state machine as it stands** — states, transitions, invariants (Phase 1 output). Two sentences per item, no more.
2. **Verdict** — does the premise hold? Which invariants are unrepresentable-by-construction today, and which merely happen to be true?
3. **Findings**, ordered by severity, each with: gap code (G1–G6), the illegal state, the concrete way it gets written (a real path — a code path, a concurrent transaction, an admin `UPDATE`), and the end-to-end fix.
4. **Suggested order of work**, with anything that needs a backfill flagged.

Severity:

- **Critical** — an illegal state that is reachable today and corrupts money, balances, or auth.
- **High** — reachable illegal state; no corruption yet, or only via a second writer.
- **Medium** — invariant holds only by convention or by a runtime check that a constraint could own.
- **Low** — model works, expression could be tighter.

## Rules

- **Trace, do not speculate.** Never report "this could be null" without checking the column's `NOT NULL` and every writer. Read the migration; do not guess from the Rust struct.
- **Name the writer.** A gap with no plausible way to reach the illegal state is a Low at best. Concurrency, retries, another service, and manual SQL all count as writers.
- **Prefer deleting states over guarding them.** The best fix makes a branch impossible, not checked.
- **Do not gold-plate.** A newtype per field is noise. Constrain what the domain constrains — nothing more. G5 findings are as real as G1.
- **Do not duplicate the repo's conventions back at the user.** If `CLAUDE.md` already mandates a rule, cite it and move on; spend the review on what the rules do not yet cover.
- **Migration realism.** Adding `NOT NULL` or a `CHECK` to a populated table needs a backfill and often a two-step deploy. Say so; a proposal that cannot ship is not a proposal.
- **No `unwrap_or` fixes.** Silently defaulting invalid data is how illegal states got in.

## References

- `references/postgres-toolkit.md` — every schema-level tool, what invariant each one buys, and when to reach for it.
- `references/rust-toolkit.md` — sum types, newtypes, smart constructors, typestate, and query-layer guards.
- `references/api-boundary.md` — proto3/REST widening, `oneof`, `UNSPECIFIED`, and parsing at the edge.
- `references/worked-examples.md` — full four-layer walkthroughs, before and after.
