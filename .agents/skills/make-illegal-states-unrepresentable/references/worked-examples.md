# Worked Examples

Three complete reviews, each in a different stack. They are also the template for a finding: the illegal state, the writer that creates it, and one change for each layer in the mechanisms of that stack.

## Contents

- [Example 1 — One open bill for each account (G3, a count) — Postgres and Rust](#example-1--one-open-bill-for-each-account-g3-a-count--postgres-and-rust)
- [Example 2 — Ledger entries that can be zero (G1 and G6, money) — MongoDB and TypeScript](#example-2--ledger-entries-that-can-be-zero-g1-and-g6-money--mongodb-and-typescript)
- [Example 3 — A sentinel value for an absent state (G5) — MySQL and Go](#example-3--a-sentinel-value-for-an-absent-state-g5--mysql-and-go)
- [What Not To Report](#what-not-to-report)

---

## Example 1 — One open bill for each account (G3, a count) — Postgres and Rust

**The intended invariant.** A user has one bill in the `open` state for each account at a maximum. When the code closes a bill, it creates the next bill.

**The code now.**

```sql
CREATE TABLE bills (
    id              INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id         INT NOT NULL REFERENCES users (id),
    account_id      INT NOT NULL REFERENCES accounts (id),
    cents_total     BIGINT NOT NULL,
    closed_at       TIMESTAMPTZ,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL
);
```

```rust
let open = db::queries::bills::find_open(conn, user_id, account_id).await?;
if open.is_none() {
    db::queries::bills::create(conn, user_id, account_id, now).await?;
}
```

**The matrix.**

| Invariant | Store | Access | Types | Boundary |
|---|---|---|---|---|
| one open bill for each user and account | - | a read before the insert | - | not applicable |
| paid means also closed | - | - | - | not applicable |
| the total is not negative | - | - | - | not applicable |

**The gap.** G3 and G4. The program holds the uniqueness with two statements. Two concurrent requests both read `None`, and both insert a row. A person with `psql` can also insert a second row. The state `paid_at IS NOT NULL AND closed_at IS NULL` (paid, but never closed) is also easy to write.

**The fix, in four layers.**

*Store* — make the second open bill impossible to write, and connect the timestamps:

```sql
CREATE UNIQUE INDEX bills_single_open ON bills (user_id, account_id)
WHERE paid_at IS NULL AND closed_at IS NULL;

ALTER TABLE bills
    ALTER COLUMN cents_total TYPE nonneg_bigint,
    ADD CONSTRAINT bills_paid_implies_closed CHECK (paid_at IS NULL OR closed_at IS NOT NULL),
    ADD CONSTRAINT bills_closed_after_created CHECK (closed_at IS NULL OR closed_at >= created_at);
```

Correct the data first. Find the users with two open bills, and the bills that are paid but not closed. Postgres cannot create the index and the constraint before you correct those rows.

The rollback drops what the migration added, and it loses nothing, because this migration corrects data and adds constraints only:

```sql
ALTER TABLE bills
    ALTER COLUMN cents_total TYPE BIGINT,
    DROP CONSTRAINT bills_paid_implies_closed,
    DROP CONSTRAINT bills_closed_after_created;

DROP INDEX bills_single_open;
```

*Access* — the read before the insert becomes one insert, and its error has a meaning. The function that closes a bill gets its condition:

```rust
pub async fn close(conn: &mut crate::Conn, id: BillId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(bills::table.find(id))
        .filter(bills::closed_at.is_null())
        .set(bills::closed_at.eq(now))
        .execute_one(conn)
        .await
}
```

*Types* — the three states stop being a puzzle of timestamps:

```rust
enum Bill {
    Open   { id: BillId, cents_total: NonNegI64, created_at: OffsetDateTime },
    Closed { id: BillId, cents_total: NonNegI64, closed_at: OffsetDateTime },
    Paid   { id: BillId, cents_total: NonNegI64, closed_at: OffsetDateTime, paid_at: OffsetDateTime },
}
```

*Boundary* — the response sends `closed_at` and `paid_at` as two independent optional fields. Add a `oneof` over the three states. Keep the old fields for the old clients.

**The benefit.** The race between two requests is impossible. The query for the open bill uses the index and gives one row. Each branch such as `if bill.paid_at.is_some() && bill.closed_at.is_none()` becomes dead code. Remove it.

---

## Example 2 — Ledger entries that can be zero (G1 and G6, money) — MongoDB and TypeScript

**The intended invariant.** Each ledger entry moves a whole number of cents, and that number is never zero. Each entry has the same user as its bill.

**The code now.** The `ledger_entries` collection has no validator. An Express handler writes it:

```ts
app.post("/entries", async (req, res) => {
  await db.collection("ledger_entries").insertOne({
    billId: new ObjectId(req.body.billId),
    userId: new ObjectId(req.body.userId),
    amountCents: req.body.amountCents,
    createdAt: new Date(),
  });
});
```

**The gaps.**

- G1: the collection permits `0`. A zero entry has no effect, but it changes each sum and each audit report. The collection also permits `12.5` and `"12"`, because nothing controls the type.
- G1: `billId` and `userId` can disagree. Nothing shows that the bill belongs to that user. MongoDB has no foreign keys, so the store cannot hold this invariant.
- G6: `req.body.amountCents` moves from the wire into the store with no check. The boundary parses nothing.

**The fix, in four layers.**

*Store* — a strict validator controls the type, the whole number and the zero:

```js
db.runCommand({
  collMod: "ledger_entries",
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["billId", "userId", "amountCents", "createdAt"],
    properties: {
      billId:      { bsonType: "objectId" },
      userId:      { bsonType: "objectId" },
      amountCents: { bsonType: "long", not: { enum: [0] } },
      createdAt:   { bsonType: "date" },
    },
    additionalProperties: false,
  }},
  validationLevel: "strict",
  validationAction: "error",
});
```

The validator applies to new writes only. Count the documents that break it first: the documents with `amountCents: 0`, and the documents with an incorrect type. MongoDB keeps those documents, and the code still reads them.

`bsonType: "long"` also puts a requirement on the writer. The driver serialises a JavaScript number as `int32` when it is a safe integer in that range, and as `double` in each other case. It never produces a `long`. A validator that asks for `long` therefore rejects each write that passes a plain number, so the writer must construct the `Long` itself. The alternative, a validator that accepts `double`, gives away the exactness above 2^53 that money needs.

MongoDB has no mechanism for the agreement between the two references. There are two options, and the user selects one. **Option 1:** put the entries inside the bill document. Then disagreement is impossible, and the write of an entry is atomic with the bill. **Option 2:** keep the collection, make one repository function the only writer, and add a scheduled query that finds each entry with the incorrect user. Report the weakness with a name in both cases. This is question 16 of `layer-1-store.md`: what this store cannot hold.

*Access* — one repository function reads the bill and writes the entry in one session. The callers do not use the collection directly:

```ts
import { Long } from "mongodb";

async function addEntry(ref: BillRef, amount: NonZeroCents): Promise<void> {
  const session = client.startSession();
  await session.withTransaction(async () => {
    // this filter is the reference check that the store cannot make
    const bill = await bills.findOne({ _id: ref.billId, userId: ref.userId }, { session });
    if (!bill) throw new BillNotFound(ref);
    await entries.insertOne(
      {
        billId: bill._id,
        userId: bill.userId,
        // a plain number would arrive as int32 or double, and the validator rejects both
        amountCents: Long.fromNumber(amount),
        createdAt: new Date(),
      },
      { session },
    );
  });
}
```

This function is also the only place that builds the `Long`. A second writer that passes a number gets an error from the validator, and that error is the mechanism, not a convention.

*Types* — a branded type moves the invariant with the value. TypeScript is tier B. Refer to `stacks/other-stacks.md`.

```ts
declare const brand: unique symbol;
export type NonZeroCents = number & { readonly [brand]: "NonZeroCents" };

export function nonZeroCents(n: unknown): NonZeroCents {
  if (typeof n !== "number" || !Number.isInteger(n) || n === 0) throw new InvalidAmount(n);
  return n as NonZeroCents;
}
```

*Boundary* — parse the payload at the edge, one time. Reject an invalid value. Do not correct it.

```ts
const Body = z.object({
  billId: z.string().regex(/^[a-f0-9]{24}$/),
  userId: z.string().regex(/^[a-f0-9]{24}$/),
  amountCents: z.number().int().refine(n => n !== 0, "must be non-zero"),
});
```

**The benefit.** Each test such as `if (!entry.amountCents) return;` becomes unnecessary. The sums do not depend on the behaviour of each caller. A string amount from a JavaScript client gives status 400 immediately. Before this change it became a document that broke an aggregation three weeks later.

---

## Example 3 — A sentinel value for an absent state (G5) — MySQL and Go

**The intended domain.** A withdrawal limit has three states: a specific limit in cents, "no limit", or "no withdrawals".

**The code now.**

```sql
limit_cents BIGINT NOT NULL   -- -1 means no limit, 0 means no withdrawals
```

```go
if l.LimitCents == -1 {
    // no limit
} else if l.LimitCents == 0 {
    // no withdrawals
} else {
    // a limit in cents
}
```

**The gap.** G5, and also G1 in the same column. The column holds three states of the domain in one integer. Therefore the model cannot express one legal state (an explicit "no limit"), and it also permits illegal values such as `-2`. Each reader must know the meaning of the two sentinel values. A reader without that knowledge compares `LimitCents` with an amount and permits each withdrawal. Go makes the problem larger: `UserLimit{}` is a valid value, so an absent field means "no withdrawals".

**The fix, in four layers.**

*Store* — give each state a name and its own representation. Confirm the version of MySQL first, because a version before 8.0.16 ignores a `CHECK`.

This is three migrations with a deployment between them. One `ALTER` cannot do the work: `ADD COLUMN kind ... NOT NULL` gives each existing row the implicit default of the type, which is `'capped'`, and `'capped'` on a row that holds `-1` is the same invented value that question 15 of `layer-1-store.md` forbids. MySQL 8.0.16 and later also validates a new `CHECK` against the rows that exist, so the single statement fails with error 3819 on the first sentinel row that it reads.

```sql
-- migration 1 — add the new shape beside the old one, and keep both writable
ALTER TABLE user_limits
    ADD COLUMN kind ENUM('capped','unlimited','blocked') NULL,
    ADD COLUMN version BIGINT NOT NULL DEFAULT 0,   -- technical, so a default is correct
    MODIFY limit_cents BIGINT NULL;
```

*Deployment 1:* the writer sets `kind` and the sentinel together, and each reader prefers `kind` where it is present.

```sql
-- migration 2 — give each old row its state. Count the rows that no state covers
-- first: each one of them makes migration 3 fail.
SELECT COUNT(*) FROM user_limits WHERE limit_cents < -1;

UPDATE user_limits SET kind = 'unlimited' WHERE limit_cents = -1;
UPDATE user_limits SET kind = 'blocked'   WHERE limit_cents = 0;
UPDATE user_limits SET kind = 'capped'    WHERE limit_cents > 0;
```

*Deployment 2:* the writer stops writing the sentinel, and each reader uses `kind` only.

```sql
-- migration 3 — remove the sentinel values, then close the column
UPDATE user_limits SET limit_cents = NULL WHERE kind <> 'capped';

ALTER TABLE user_limits
    MODIFY kind ENUM('capped','unlimited','blocked') NOT NULL,
    ADD CONSTRAINT user_limits_kind_cents CHECK (
        (kind = 'capped'    AND limit_cents IS NOT NULL AND limit_cents > 0)
     OR (kind <> 'capped'   AND limit_cents IS NULL)
    );
```

Write the rollback before you run migration 3, because that migration is the one that loses data:

```sql
ALTER TABLE user_limits
    DROP CHECK user_limits_kind_cents,
    MODIFY kind ENUM('capped','unlimited','blocked') NULL;

-- the sentinel values are gone, so the rollback must also rebuild them
UPDATE user_limits SET limit_cents = -1 WHERE kind = 'unlimited';
UPDATE user_limits SET limit_cents = 0  WHERE kind = 'blocked';
```

*Access* — the update writes both fields together. A write of one field only gives the illegal state:

```go
res, err := tx.ExecContext(ctx,
    `UPDATE user_limits SET kind = ?, limit_cents = ?, version = version + 1
       WHERE user_id = ? AND version = ?`,
    kind, cents, userID, expectedVersion)
```

Read the count of the changed rows. A count of zero means that a different writer was first, and the caller must read the row again. The `version = version + 1` is not optional: without it the column never moves, and each `WHERE version = ?` passes forever.

*Types* — Go is tier C, so the constructor is the only control point. Each state is a type behind an interface:

```go
type PositiveCents int64

// The method is unexported, so only this package can add a variant. It is what
// seals the interface, and each variant must declare it or the type switch below
// does not compile.
type WithdrawalLimit interface{ isWithdrawalLimit() }

type Capped struct{ cents PositiveCents } // the field is unexported, so only NewCapped can set it
type Unlimited struct{}
type Blocked struct{}

func (Capped) isWithdrawalLimit()    {}
func (Unlimited) isWithdrawalLimit() {}
func (Blocked) isWithdrawalLimit()   {}

func NewCapped(cents int64) (Capped, error) {
    if cents <= 0 { return Capped{}, fmt.Errorf("cap must be positive, got %d", cents) }
    return Capped{cents: PositiveCents(cents)}, nil
}
```

Write `switch l := limit.(type)` with `default: return fmt.Errorf("unhandled limit %T", l)`. The default case gives an error, and this is the nearest equivalent of a complete check in Go. Write the limit of this fix in the report: if a person adds a new state, the compiler does not report this switch. Therefore the default case must give an error, and it must never permit the operation.

*Boundary* — the API sends `-1` to the clients now. Add an explicit `kind` enum, and reject the unspecified value. Or add a `oneOf`. Send `kind` and the old `limit_cents` together until each old client uses `kind`.

**The benefit.** The meaning of the sentinel values is in the schema, not in the knowledge of the team. `UserLimit{}` does not mean "no withdrawals". A reader who forgets a state gets an error, not a comparison that permits each withdrawal.

---

## What Not To Report

- **A mechanism that the stack does not have.** Examples: a partial unique index in MySQL, an `EXCLUDE` constraint in SQLite, a foreign key in MongoDB, or a Rust `enum` in a Go program. Connect the layers in Phase 0, then propose.
- **One wrapper type for each field.** `UserName(NonEmptyString)`, where the domain has no other limit on a name, adds one step and gives no benefit.
- **A constraint that repeats a constraint.** If the type of the column forbids the value, do not also propose a `CHECK` for it.
- **Typestate on a flow of two steps** with one call site. A sum type and a condition on the write are sufficient.
- **"This value can be absent."** Do not report this before you read the store definition and each writer. If the store requires the value, there is no finding.
- **A large change where a small addition is sufficient.** This applies to a public boundary and a mobile client. Propose the change that the team can merge.
- **Silence about a layer that cannot hold the invariant.** Silence reads as "this layer holds it". Name the layer that holds it now, and the method that finds a violation.
