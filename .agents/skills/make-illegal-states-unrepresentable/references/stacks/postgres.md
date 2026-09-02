# Stack Reference — Postgres

The mechanisms of layer 1 when the store is Postgres. `../layer-1-store.md` gives the questions. This file gives the answers for this store. Select the least expensive tool that makes the illegal state impossible to write.

## Contents

- [Domain types](#domain-types--one-limit-in-each-place-that-uses-the-type) — one limit, in each place that uses the type
- [Enum types](#enum-types--never-text-for-a-finite-group) — never `TEXT` for a finite group
- [`NOT NULL`](#not-null--the-constraint-that-schemas-use-too-little) — the constraint that schemas use too little
- [Foreign keys](#foreign-keys-with-more-than-one-column-where-possible) — with more than one column where possible
- [Partial unique indexes](#partial-unique-indexes--the-count-of-records-in-a-state) — the count of records in a state
- [`EXCLUDE`](#exclude--rules-between-rows) — rules between rows
- [`CHECK`](#check--the-state-machine-in-the-table) — the state machine in the table
- [Constraint triggers](#constraint-triggers--rules-across-rows-at-the-commit) — rules across rows, at the commit
- [Structural choices to report](#structural-choices-to-report)
- [Is the migration realistic?](#is-the-migration-realistic)

## Domain types — one limit, in each place that uses the type

A domain is a base type with a `CHECK`. Each column of that domain gets the limit. A Rust newtype can also connect to the domain. Refer to `rust.md`.

```sql
CREATE DOMAIN pos_bigint       AS BIGINT CHECK (VALUE > 0);
CREATE DOMAIN nonneg_int       AS INT    CHECK (VALUE >= 0);
CREATE DOMAIN nonneg_bigint    AS BIGINT CHECK (VALUE >= 0);
CREATE DOMAIN non_zero_bigint  AS BIGINT CHECK (VALUE != 0);
CREATE DOMAIN non_empty_text   AS TEXT   CHECK (LENGTH(VALUE) > 0);
CREATE DOMAIN bytea32          AS BYTEA  CHECK (LENGTH(VALUE) = 32);
CREATE DOMAIN uuidv7           AS UUID   CHECK (SUBSTRING(VALUE::text, 15, 1) = '7');
CREATE DOMAIN nonnan_double    AS DOUBLE PRECISION CHECK (VALUE != DOUBLE PRECISION 'NaN');
CREATE DOMAIN tautology        AS BOOL   CHECK (VALUE);
```

- `tautology` permits `true` and `NULL` only. The column is never `false`. It removes the boolean with three states. As a primary key (`id tautology PRIMARY KEY`) it also limits a table to one row.
- An empty string and an empty bytea must be impossible to write. `NULL` means "absent" and a non-empty value means "present". Two representations of "absent" are a G1 gap.
- A `BIGINT` column for money that is never zero or negative is a finding. Name the domain that it needs.

## Enum types — never `TEXT` for a finite group

```sql
CREATE TYPE payment_state AS ENUM ('pending', 'settled', 'failed');
```

A `TEXT` column with a finite group of values is always a G1 gap, because it also permits `'setled'`. `ALTER TYPE ... ADD VALUE` adds a new value later. Connect the type to the enum in the program (`diesel_derive_enum::DbEnum` in Rust). Then the two cannot become different.

## `NOT NULL` — the constraint that schemas use too little

A nullable column is a sum type with one more variant. Ask this question about each column: is there a state in which this column is correctly absent? If there is no such state, add `NOT NULL`. If there is such a state, name it, and confirm that the schema represents that state with an enum or a timestamp. A nullable column with no named state for its absence is a G1 gap.

## Foreign keys, with more than one column where possible

```sql
-- This makes one illegal state impossible: an event of a different partner
FOREIGN KEY (event_id, partner_id) REFERENCES events (id, partner_id)
```

A foreign key of one column shows that the target row exists. A foreign key of two columns also shows that the two rows have the same parent. Use it where two rows must have the same tenant, user or account. It removes a large group of bugs that no check in the program removes.

## Partial unique indexes — the count of records in a state

The most frequent tool for "one X in state S at a maximum":

```sql
-- one open bill for each user and account at a maximum
CREATE UNIQUE INDEX bills_single_open ON bills (user_id, account_id)
WHERE paid_at IS NULL AND closed_at IS NULL;

-- one active policy for each subject at a maximum
CREATE UNIQUE INDEX policies_active_subject ON compliance_policies (subject_type)
WHERE status = 'active';

-- one reversal in progress for each end-to-end id at a maximum
CREATE UNIQUE INDEX reversal_requests_inflight ON reversal_requests (end_to_end_id)
WHERE failed_at IS NULL;
```

This is the fix for "the code reads the store for an open row before the insert". Two concurrent requests both read "none" and both insert. A read before a write for uniqueness is a G3 or G4 gap with a fix of one line.

## `EXCLUDE` — rules between rows

`UNIQUE` compares two values with `=`. `EXCLUDE` compares them with each operator, so it holds the invariants that a unique index cannot express:

```sql
-- two validity periods must not overlap
CREATE TABLE commission_policies (
    id       INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    validity tstzmultirange NOT NULL,
    EXCLUDE USING gist (validity WITH &&)
);

-- an email can repeat inside one group of owners only
ALTER TABLE users ADD CONSTRAINT users_email_per_owner EXCLUDE USING gist (
    email WITH =,
    COALESCE(org_owner_user_id, id) WITH <>
) WHERE (controller = 'internal');
```

Use it where the invariant is "these must not overlap" or "these must not collide, except in the same group". Validity periods that the program controls are a G3 gap.

## `CHECK` — the state machine in the table

The tool with the highest value for a table with a `kind` column and timestamps:

```sql
ALTER TABLE my_logs ADD CONSTRAINT my_logs_state CHECK (
  CASE
    WHEN kind = 'pending'   THEN (completed_at IS NULL     AND failed_at IS NULL)
    WHEN kind = 'completed' THEN (completed_at IS NOT NULL  AND failed_at IS NULL)
    WHEN kind = 'failed'    THEN (completed_at IS NULL      AND failed_at IS NOT NULL)
    ELSE FALSE
  END
);
```

`ELSE FALSE` is important. If a person adds a new enum value and no clause for it, the constraint rejects the row.

These constraints are also inexpensive, and many schemas do not have them:

```sql
enabled_at  TIMESTAMPTZ NOT NULL CHECK (enabled_at >= created_at),
disabled_at TIMESTAMPTZ NOT NULL CHECK (disabled_at > enabled_at),
```

The sequence of two timestamps is an invariant. A pair of timestamps with no rule is a G1 gap, and it becomes a negative duration later.

## Constraint triggers — rules across rows, at the commit

A `CHECK` sees one row only. For a total that must be equal to the sum of its items, use a `DEFERRABLE INITIALLY DEFERRED` constraint trigger. Postgres validates it at the commit, after the transaction writes each row:

```sql
CREATE CONSTRAINT TRIGGER bill_total_matches_events
AFTER INSERT OR UPDATE OF cents_total, state ON bills
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION validate_bill_total();
```

Use this tool last, not first, because it puts the logic of the program in the database. But for the total of a ledger it is the only layer that holds each writer.

## Structural choices to report

- `id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY` is better than `SERIAL`. `GENERATED ALWAYS` makes an identifier from the caller impossible to write.
- **No `DEFAULT` values.** A default is a decision that the schema makes for the code, and it hides the error "the caller forgot this field".
- **A table of events is better than a mutable state column.** One row for each transition, with a calculated state, changes an illegal transition into an illegal insert. It also keeps the history. If the code changes a state column, and the history is important, this is a finding about the design.
- **Two columns for one concept** (`state` and `state2` during a migration) is a live G1 gap, because the pair permits disagreement. Report each pair from an incomplete migration. Also look for the `CHECK` that must connect the two columns while both exist.

## Is the migration realistic?

A new constraint on a table with data needs two steps. A proposal without these steps is not complete:

1. Add the column or constraint in a weak form, correct the data, then use `SET NOT NULL`. Or use `ADD CONSTRAINT ... NOT VALID` and then `VALIDATE CONSTRAINT`.
2. Deploy the writer that satisfies the invariant before the constraint that needs it.

Write the rollback migration. Test it with the migration tool of the repository: run the migration, roll it back, and run it again.
