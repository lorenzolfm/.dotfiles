---
name: make-illegal-states-unrepresentable
description: Examine a part of an existing program and find the illegal states that the code can represent. Then propose changes in four layers - the store, the access layer, the types and the boundary. This skill applies to any technology. Use this skill to examine a data model or a state machine for holes, to make invariants, types and constraints stronger, to review whether illegal states are representable, or to close the gaps between what the domain permits and what the code permits.
---

# Make Illegal States Unrepresentable

Read a part of an existing program. Decide if the premise below is true for that code. Then propose the changes that close each gap. Do not change the code before the user asks. Refer to Phase 5.

> **The premise.** A program is a state machine. Our job is to build exactly the states and transitions the domain requires, and nothing else. Model data so that every value that makes sense is representable and no value that does not make sense is representable. Prefer *correct by construction* over *checked at runtime*.
> — <https://functional-architecture.org/make_illegal_states_unrepresentable/>

The four layers below are functions, not products. Each stack has all four functions. Sometimes a layer is thin. Sometimes one file does the work of two layers. In Phase 0, connect each function to the mechanisms that the applicable stack has. The other phases are the same for all technologies.

A finding is real only after you trace it through all four layers. Each proposal includes all four layers: store, access, types and boundary.

## The Four Layers

Authority moves downward. If only a layer above the store holds an invariant, that invariant is not durable.

| # | Layer | Function | It holds against | It cannot hold |
|---|-------|----------|------------------|----------------|
| 1 | **Store** | The durable shape of the data: a schema, a validator, the conditions on an item, an event log, a configuration file | Each writer: this service, a different service, a migration, a batch job, a person at a console, two concurrent writers | An invariant that needs the context of the program |
| 2 | **Access** | Each path that reads or writes the store: queries, repository functions, client calls, transactions | Legal transitions, atomicity, no lost updates | Anything, if a second code path does not use the same function |
| 3 | **Types** | The domain model in the language of the program | The program cannot construct an illegal state. Some compilers prove this | Anything about data that a different process wrote |
| 4 | **Boundary** | Each value that crosses the edge of the process: payloads, messages, arguments, environment variables, configuration, third-party responses | Nothing alone. Its function is to parse each value into layer 3 | Any invariant, without a parse step |

Apply these rules during the review:

- The store is the lowest layer. Do not accept "the program prevents it" for a durable invariant.
- Layer 3 removes the need to remember layer 2. Layer 1 is necessary because layer 3 is not the only writer.
- The boundary parses each value one time, at the edge, into the most narrow type. That type then moves through all the code without a change.
- If a layer cannot hold an invariant in this stack, the invariant is not safe. It is a known weakness. Tell the user which layer holds it, and how a person finds a violation.

## How To Do The Review

### Phase 0 — Set the scope, read the conventions, connect the stack

Set the scope: one feature module, one table with its access code, or one endpoint with all the code behind it.

Read `CLAUDE.md` or `AGENTS.md` first, then the lint and type configuration. Local conventions have more authority than the defaults of this skill. Domain types are usually in the repository already. Make a list of what exists before you propose something new: value constraints, closed sets, validated wrappers and typed identifiers.

Then connect the four layers. Read the code. Do not assume.

| Layer | Technology | Mechanisms it gives here | Limits |
|---|---|---|---|
| Store | Example: Postgres 16, MongoDB 7, DynamoDB, SQLite, a JSON file | The constraints that this version has | What this store cannot express |
| Access | Example: Diesel, Prisma, SQLAlchemy, the driver | Conditional writes? A count of the changed records? Transactions? | |
| Types | Example: Rust, TypeScript, Python, Go, Kotlin | Sum types? Opaque wrappers? A check for all cases? | |
| Boundary | Example: proto3, OpenAPI, GraphQL, command-line flags | Presence? Closed sets? Sum types? | |

The files in `references/stacks/` give the mechanisms. Read `references/stacks/other-stacks.md` in every review: it holds the conditional-write table for layer 2, the language-tier table for layer 3 and the boundary-format table for layer 4, and no other file has them. Then read the file for each technology in the scope — `postgres.md` when the store is Postgres, `rust.md` when the language is Rust — and skip the files for technologies that the scope does not use. A stack with no file of its own is in `other-stacks.md`; a stack that no file names at all gets *How to adapt to a new stack*, at the end of that file. Find the local mechanisms in the documentation of the store and in the code of the repository. Give each mechanism its correct name.

Never propose a mechanism that the stack does not have. Never write a proposal in the style of a different technology.

### Phase 1 — Find the intended state machine

Do not make a judgement yet. Write these three lists:

- **States** — a name for each state in the domain.
- **Transitions** — which state can become which state, the trigger for each change, and which states are terminal.
- **Invariants** — count ("a user has one open bill at a maximum"), time ("two validity periods do not overlap", "`confirmed_at` is not before `created_at`"), quantity ("an amount is never zero", "the total is equal to the sum of the items") and reference ("the event and the bill have the same user").

If you cannot name the intended states from the code, that is the most important finding. If no person can make the list of states, no mechanism can hold them.

### Phase 2 — Make the invariant and layer matrix

Find where the code holds each invariant from Phase 1. Read the store definition, the access code, the types, the boundary schema and the handler. Do not guess.

Work one layer at a time, and read that layer's file in `references/` before you fill its column: `layer-1-store.md`, then `layer-2-access.md`, then `layer-3-types.md`, then `layer-4-boundary.md`. Each file is a list of questions to ask of the code in front of you, and each question carries the gap code that its answer produces. A column that you fill without asking those questions is a guess.

```
Invariant                          | Store          | Access        | Types        | Boundary
-----------------------------------|----------------|---------------|--------------|--------------
one open bill for each user        | partial UIX    | -             | -            | not applicable
an amount is never zero            | -              | -             | assertion    | wide integer
paid means also closed             | -              | conditional   | -            | sum type OK
```

An empty column for a real invariant is a gap. A column that holds the invariant only to the right of the store is also a gap.

### Phase 3 — Give each gap a code

| Code | Gap | Shape |
|------|-----|-------|
| **G1** | The code can represent an illegal state | The type permits a state that the domain forbids: many optional fields together, two booleans with three legal combinations, free text for a closed set, an optional field that is absent in one state only |
| **G2** | A check does the work of a type | A run-time check, an assertion, a validation function or a comment does the work that a type or a constraint can do permanently |
| **G3** | The layers do not agree | The program holds the invariant and the store does not, or the opposite. The store is the durable authority, and a different writer finds the hole. If the store cannot hold the invariant, the finding becomes: the code depends on one writer, and no document records this fact |
| **G4** | A transition hole | The states are correct, but a write can move a record between two states that the machine forbids. Causes: no condition on the current state, no check on the direction of the change, no rule between a discriminator and its fields |
| **G5** | The model has too few states | The opposite gap, and a real finding. The model cannot express a legal state, so the code uses a work-around: a sentinel value, `-1`, an empty string that means absent, a "misc" variant, a flag with three meanings |
| **G6** | The boundary makes the type wide again | The code parses the value into a good type. Then the boundary changes it to a string, a wide number or a group of optional fields, and other code parses it a second time |

### Phase 4 — Propose changes in all four layers

Each finding gets one change for each layer, or a sentence that tells why that layer needs no change:

1. **Store** — the constraint, type, validator, index or condition that makes the illegal state impossible to write. Use the syntax of the store. Include the correction of the existing data if that data can break the new constraint. Include the rollback.
2. **Access** — the conditions on each write, and the count checks that make an illegal transition give an error.
3. **Types** — the sum type, the wrapper or the constructor. Connect it to the representation in the store, because then the two layers cannot become different.
4. **Boundary** — the closed set, the sum type in the payload, the rejection of an absent or default value, the more narrow response.

Show real code. Use the style of the repository and the mechanisms of the stack. A change that removes branches is better than a change that adds a check. If a fix removes branches or an error path, count them. This benefit persuades the reader.

If a layer cannot hold the invariant in this stack, write this fact. Then name the control that replaces it: the layer above plus a test, one writer only, or a scheduled check of the data. A weakness with a name and a test is much better than a weakness that no document records.

Do the work in this sequence: the store first, then the access layer, then the types, then the boundary. The store is the lowest layer, and it controls the other three.

`references/worked-examples.md` has three findings written out in full, in three different stacks. Read it before you write the first one: it is the shape that a finding takes, and its last section lists what a review must not report.

### Phase 5 — Report, then stop

Write the report below. Do not write a migration and do not change code before the user selects the items. A change to the store has large effects, and usually one migration goes into one pull request. The user makes the decisions about the data model.

## The Report

1. **The state machine now** — the states, the transitions and the invariants from Phase 1. Two sentences for each item at a maximum.
2. **The layers** — the table from Phase 0. One line for each layer. Include the limits of that layer in this stack.
3. **The verdict** — Is the premise true? Which invariants can no writer break? Which invariants are true only by chance?
4. **The findings**, in the sequence of severity. Give the gap code (G1 to G6), the illegal state, the path that writes it, and the fix for all four layers. The path must be real: a code path, two concurrent writes, or a manual correction by an operator.
5. **The sequence of work**. Mark each item that needs a data correction or two deployments.

Severity:

- **Critical** — the code can write the illegal state today, and that state corrupts money, balances, permissions or other data that no person can correct.
- **High** — the code can write the illegal state. No corruption occurs yet, or only a second writer causes it.
- **Medium** — a convention or a run-time check holds the invariant. A constraint can hold it instead.
- **Low** — the model is correct. The expression of the model can be more exact.

## Rules

- **Read the code. Do not guess.** Do not report "this value can be absent" before you read the store definition and each writer. Read the schema, the migration or the validator. The in-memory model is not evidence.
- **Connect the layers before you propose a change.** The stack must have each mechanism that you propose. Write that mechanism as this stack writes it.
- **Name the writer.** If no path writes the illegal state, the severity is Low at a maximum. These are also writers: concurrent requests, retries, a different service, a batch job and a manual correction.
- **Remove states. Do not add checks.** The best fix makes a branch impossible.
- **Do not add unnecessary types.** One wrapper type for each field gives no benefit. Add a constraint only where the domain has a constraint. A G5 finding is as important as a G1 finding.
- **Do not repeat the conventions of the repository.** If `CLAUDE.md` has the rule, refer to it and continue. Use the review for the subjects that the rules do not include.
- **Be realistic about migrations.** A stronger constraint on existing data needs a data correction and often two deployments. Write this fact. A proposal that no person can deploy is not a proposal.
- **Do not use a default value as a fix.** If the code changes invalid data to a valid value, illegal states enter the store. This is how the problem started.

## References

The four layer files give the questions. The stack files give the mechanisms. Read the layer file for each layer that you examine, `stacks/other-stacks.md` in every review, and the stack file for each technology from Phase 0. Skip the stack files for the technologies that the scope does not use.

- `references/layer-1-store.md` — the questions about durable invariants.
- `references/layer-2-access.md` — the questions about writes, transitions and concurrency.
- `references/layer-3-types.md` — the questions about the domain model in the program.
- `references/layer-4-boundary.md` — the questions about presence, closed sets and payload shape, for each wire format.
- `references/stacks/postgres.md` — the mechanisms of Postgres.
- `references/stacks/rust.md` — the mechanisms of Rust.
- `references/stacks/other-stacks.md` — the mechanisms of other stores, languages and boundaries, and how to adapt to a new stack.
- `references/worked-examples.md` — three complete reviews in three different stacks, before and after.
