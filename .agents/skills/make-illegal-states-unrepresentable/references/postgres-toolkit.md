# Layer 1 — The Postgres Toolkit

The schema is the only layer that holds against every writer. Reach for these in roughly this order: the cheapest tool that makes the state unwritable wins.

## Domain types — constrain the value, once, everywhere

A domain is a named base type plus a `CHECK`. Every column of that domain inherits the guarantee, and the Rust newtype can be wired to it (see `rust-toolkit.md`).

```sql
CREATE DOMAIN pos_bigint       AS BIGINT CHECK (VALUE > 0);
CREATE DOMAIN nonneg_int       AS INT    CHECK (VALUE >= 0);
CREATE DOMAIN non_zero_bigint  AS BIGINT CHECK (VALUE != 0);
CREATE DOMAIN non_empty_text   AS TEXT   CHECK (LENGTH(VALUE) > 0);
CREATE DOMAIN bytea32          AS BYTEA  CHECK (LENGTH(VALUE) = 32);
CREATE DOMAIN uuidv7           AS UUID   CHECK (SUBSTRING(VALUE::text, 15, 1) = '7');
CREATE DOMAIN nonnan_double    AS DOUBLE PRECISION CHECK (VALUE != DOUBLE PRECISION 'NaN');
CREATE DOMAIN tautology        AS BOOL   CHECK (VALUE);
```

- `tautology` is the true-or-null pattern: the column is either `true` or absent — never `false`. It kills the classic tri-state boolean, and as a primary key (`id tautology PRIMARY KEY`) it makes a singleton table hold exactly one row.
- Empty string and empty bytea should be *unrepresentable*, not merely discouraged: absent is `NULL`, present is non-empty. Two encodings of "nothing" is a G1 gap.
- A bare `BIGINT` money column that can never legitimately be zero or negative is a finding. Say which domain it should be.

**Review question:** for every numeric, text, and bytea column in scope, is there a value of that type the domain forbids? If yes, name the domain.

## Enum types — never a bare `TEXT` for a fixed set

```sql
CREATE TYPE payment_state AS ENUM ('pending', 'settled', 'failed');
```

A `TEXT` column holding a known-finite set is always a G1 gap: it admits `'setled'`. `ALTER TYPE ... ADD VALUE` covers growth. Pair with `diesel_derive_enum::DbEnum` on the Rust side so the two cannot drift.

## `NOT NULL` — the most under-used constraint

A nullable column is a sum type with an extra variant. Ask, per column: *is there a state in which this is legitimately absent?* If no — `NOT NULL`. If yes — which state, and is that state itself represented (a `kind` enum, a discriminating timestamp)? A nullable column whose absence is not tied to a named state is a G1 gap.

## Foreign keys, composite where possible

```sql
-- Good: makes "event belongs to a different partner than the row referencing it" unwritable
FOREIGN KEY (event_id, partner_id) REFERENCES events (id, partner_id)
```

A single-column FK guarantees the row exists. A composite FK guarantees the row *agrees* with the referencing row about a shared parent. Whenever two joined rows must share a tenant/user/holder, a composite FK removes an entire class of cross-tenant bug that no application check reliably covers.

## Partial unique indexes — cardinality of a lifecycle

The workhorse for "at most one X in state S":

```sql
-- at most one open bill per (user, holder)
CREATE UNIQUE INDEX card_bills_single_opened ON card_bills (user_id, stark_holder_id)
WHERE paid_at IS NULL AND closed_at IS NULL;

-- at most one active policy per subject
CREATE UNIQUE INDEX policies_active_subject ON compliance_policies (subject_type)
WHERE status = 'active';

-- at most one in-flight reversal per end-to-end id
CREATE UNIQUE INDEX reversal_requests_inflight ON reversal_requests (end_to_end_id)
WHERE failed_at IS NULL;
```

This is the fix for "we check for an existing open row before inserting" — a check that loses to concurrency every time. If the review finds a `SELECT`-then-`INSERT` guarding uniqueness, that is a G3/G4 gap with a one-line schema fix.

## `EXCLUDE` — invariants across rows

`UNIQUE` compares with `=`. `EXCLUDE` compares with any operator, which buys the invariants unique indexes cannot express:

```sql
-- no two policies whose validity windows overlap
CREATE TABLE commission_policies (
    id       INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    validity tstzmultirange NOT NULL,
    EXCLUDE USING gist (validity WITH &&)
);

-- an email may repeat only inside the same owner group
ALTER TABLE users ADD CONSTRAINT users_email_per_owner EXCLUDE USING gist (
    email WITH =,
    COALESCE(business_owner_user_id, id) WITH <>
) WHERE (controller = 'bipa');
```

Reach for it whenever the invariant is "these must not overlap / must not collide except when …". Overlapping validity periods enforced by application code are a standing G3 gap.

## `CHECK` — the state machine, in the table

The single highest-value pattern for a `kind`-plus-timestamps table:

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

The `ELSE FALSE` matters: a new enum variant with no clause fails closed instead of admitting anything.

Also cheap and often missing:

```sql
enabled_at  TIMESTAMPTZ NOT NULL CHECK (enabled_at >= created_at),
disabled_at TIMESTAMPTZ NOT NULL CHECK (disabled_at > enabled_at),
```

Ordering between timestamps is an invariant. Unordered timestamp pairs are a G1 gap that shows up later as negative durations.

## Constraint triggers — aggregate invariants, deferred

For invariants a row-local `CHECK` cannot see — a total that must equal the sum of its line items — use a `DEFERRABLE INITIALLY DEFERRED` constraint trigger so it is validated at commit, after all rows in the transaction are written:

```sql
CREATE CONSTRAINT TRIGGER bill_total_matches_events
AFTER INSERT OR UPDATE OF cents_total, state ON card_bills
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION validate_bill_total();
```

Last resort, not first: it is application logic living in the database. But for a ledger total it is the only layer that catches every writer.

## Structural choices worth flagging

- `id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY` over `SERIAL` — `GENERATED ALWAYS` makes an explicitly-supplied id unwritable.
- **No `DEFAULT` values.** A default is a silent decision made by the schema instead of the code, and it hides "the caller forgot".
- **Append-only event tables over mutable state columns.** A row per transition, with the state derived, makes an illegal transition an illegal *insert* — and keeps the history. Where the code mutates a state column in place and the history matters, that is a design-level finding.
- **Two columns for one concept** (`state` and `state2` mid-migration) is a live G1 gap: the pair admits disagreement. Flag any such transitional duplication that has outlived its migration, and check for the `CHECK` that should tie them together while both exist.

## Migration realism

Adding a constraint to a populated table is a two-step change, and a proposal that skips this is not shippable:

1. Add the column/constraint permissively, backfill, then `SET NOT NULL` / `ADD CONSTRAINT ... NOT VALID` followed by `VALIDATE CONSTRAINT`.
2. Deploy the writer that satisfies the invariant before the constraint that requires it.

Always write `down.sql`, and verify with `diesel migration run` then `diesel migration redo`.
