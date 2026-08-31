# Worked Examples

Three end-to-end walkthroughs. They double as the template for finding write-ups: illegal state → the writer that reaches it → one change per layer.

---

## Example 1 — "At most one open bill per user" (G3, cardinality)

**Intended invariant.** A user has at most one bill in the `open` state per card holder. Closing a bill creates the next one.

**As found.**

```sql
CREATE TABLE card_bills (
    id              INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id         INT NOT NULL REFERENCES users (id),
    stark_holder_id INT NOT NULL REFERENCES stark_holders (id),
    cents_total     BIGINT NOT NULL,
    closed_at       TIMESTAMPTZ,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL
);
```

```rust
// features/card_bills.rs
let open = db::queries::card_bills::find_open(conn, user_id, holder_id).await?;
if open.is_none() {
    db::queries::card_bills::create(conn, user_id, holder_id, now).await?;
}
```

**Matrix.**

| Invariant | Schema | Queries | Types | API |
|---|---|---|---|---|
| ≤1 open bill per (user, holder) | — | `SELECT`-then-`INSERT` | — | n/a |
| paid implies closed | — | — | — | n/a |
| total is non-negative | — | — | — | n/a |

**Gap.** G3 + G4. The uniqueness lives in application code across two statements: two concurrent requests both read `None` and both insert. Nothing stops an admin `INSERT` either. And `paid_at IS NOT NULL AND closed_at IS NULL` — paid but never closed — is freely writable.

**Fix, end to end.**

*Schema* — make the second open bill unwritable, and tie the lifecycle timestamps together:

```sql
CREATE UNIQUE INDEX card_bills_single_opened ON card_bills (user_id, stark_holder_id)
WHERE paid_at IS NULL AND closed_at IS NULL;

ALTER TABLE card_bills
    ALTER COLUMN cents_total TYPE nonneg_bigint,
    ADD CONSTRAINT card_bills_paid_implies_closed CHECK (paid_at IS NULL OR closed_at IS NOT NULL),
    ADD CONSTRAINT card_bills_closed_after_created CHECK (closed_at IS NULL OR closed_at >= created_at);
```

Backfill first: check for existing duplicate-open rows and paid-but-unclosed rows before the index and the `CHECK` can be created.

*Queries* — the `SELECT`-then-`INSERT` becomes a single insert whose failure is meaningful, and closing gains its precondition:

```rust
pub async fn close(conn: &mut crate::Conn, id: CardBillId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(card_bills::table.find(id))
        .filter(card_bills::closed_at.is_null())
        .set(card_bills::closed_at.eq(now))
        .execute_one(conn)
        .await
}
```

*Types* — the three lifecycle states stop being a timestamp puzzle:

```rust
enum CardBill {
    Open   { id: CardBillId, cents_total: NonNegI64, created_at: OffsetDateTime },
    Closed { id: CardBillId, cents_total: NonNegI64, closed_at: OffsetDateTime },
    Paid   { id: CardBillId, cents_total: NonNegI64, closed_at: OffsetDateTime, paid_at: OffsetDateTime },
}
```

*API* — a response exposing `closed_at`/`paid_at` as independent optionals becomes a `oneof` over the three states, added alongside the existing fields for old clients.

**Payoff.** The race disappears, the "which bill is open" query becomes index-backed and unambiguous, and every `if bill.paid_at.is_some() && bill.closed_at.is_none()` branch in the codebase becomes dead code — delete it.

---

## Example 2 — Ledger deltas that can be zero and untyped (G1 + G6, money)

**Intended invariant.** Every ledger event moves a non-zero amount of cents, and belongs to the same user as its bill.

**As found.** `amount_cents BIGINT NOT NULL`, `card_bill_id INT NOT NULL REFERENCES card_bills (id)`, `user_id INT NOT NULL REFERENCES users (id)`, and a gRPC handler doing `let amount = req.amount_cents;`.

**Gaps.**

- G1: `0` is representable — a no-op event that pollutes sums and audit trails.
- G1: `user_id` and `card_bill_id` can disagree; nothing says the bill belongs to that user.
- G6: `i64` off the wire flows through the whole feature untouched.

**Fix.**

```sql
CREATE DOMAIN non_zero_bigint AS bigint CHECK (VALUE != 0);

ALTER TABLE card_bill_events
    ALTER COLUMN amount_cents TYPE non_zero_bigint,
    ADD CONSTRAINT card_bill_events_bill_user
        FOREIGN KEY (card_bill_id, user_id) REFERENCES card_bills (id, user_id);
```

The composite FK needs `UNIQUE (id, user_id)` on `card_bills` to reference — cheap, and it is what makes the agreement checkable.

```rust
// wired to the domain: a zero in the column is a deserialization failure, not a value
pub struct NonZeroBigInt(pub std::num::NonZeroI64);
```

```rust
// handler: parse at the edge, once
let amount = NonZeroI64::new(req.amount_cents)
    .map(NonZeroBigInt)
    .ok_or_else(|| Status::invalid_argument("amount_cents must be non-zero"))?;
```

**Payoff.** Every `if amount == 0 { return Ok(()) }` early-return in the feature disappears, and no other service — or `psql` session — can write a zero-delta event.

---

## Example 3 — Over-constrained model forcing a sentinel (G5, the dual)

**Intended domain.** A withdrawal limit is either a specific cents cap, or "no limit configured", or "blocked entirely".

**As found.**

```sql
limit_cents BIGINT NOT NULL   -- -1 means unlimited, 0 means blocked
```

```rust
if limit_cents == -1 { /* unlimited */ } else if limit_cents == 0 { /* blocked */ } else { /* cap */ }
```

**Gap.** G5, and G1 in the same column. Three domain states are crammed into one integer, so the type both forbids a legitimate shape (an explicit "unlimited" state) and admits illegal ones (`-2`, `-1` accidentally arriving from an `as` cast or a client default). Every reader must know the sentinel convention, and one that does not know it will compare `limit_cents` against an amount and let everything through.

**Fix.** Name the states; give each its own representation.

```sql
CREATE TYPE withdrawal_limit_kind AS ENUM ('capped', 'unlimited', 'blocked');

ALTER TABLE user_limits
    ADD COLUMN kind withdrawal_limit_kind NOT NULL,
    ALTER COLUMN limit_cents TYPE pos_bigint,
    ALTER COLUMN limit_cents DROP NOT NULL,
    ADD CONSTRAINT user_limits_kind_cents CHECK (
      CASE kind
        WHEN 'capped'    THEN limit_cents IS NOT NULL
        WHEN 'unlimited' THEN limit_cents IS NULL
        WHEN 'blocked'   THEN limit_cents IS NULL
        ELSE FALSE
      END
    );
```

```rust
enum WithdrawalLimit { Capped(PosI64), Unlimited, Blocked }
```

The API grows a `oneof` (or an explicit `kind` enum with `UNSPECIFIED` rejected) instead of shipping `-1` to clients.

**Payoff.** The sentinel convention stops being tribal knowledge; a reader who forgets a state gets a non-exhaustive `match` error instead of a silently permissive comparison.

---

## Anti-example — what not to report

- **A newtype per field.** `struct UserName(NonEmptyString)` where the domain constrains nothing beyond non-emptiness adds a hop and buys nothing.
- **A `CHECK` restating a domain.** If the column is `pos_bigint`, do not also propose `CHECK (col > 0)`.
- **Typestate on a two-step flow** with one call site. A sum type plus a guarded update is the right cost.
- **"This could be null."** Not without having read the migration and every writer. If the column is `NOT NULL`, there is no finding.
- **A rewrite where an additive change ships.** Especially at a mobile-facing API. Propose the path that can actually merge.
