# Layers 2 & 3 — The Rust Toolkit

Layer 3 makes illegal states unconstructible in this process. Layer 2 makes illegal *transitions* fail loudly at the database.

## Sum types instead of product types with holes

The original formulation of the principle: a flat record with many optionals admits combinations the domain forbids. Split it into one variant per state, each carrying only the fields that state actually has.

```rust
// BAD — 2^4 representable combinations, 3 of them legal
struct Connection {
    state: ConnState,
    connected_at: Option<OffsetDateTime>,
    disconnected_at: Option<OffsetDateTime>,
    last_error: Option<String>,
}

// GOOD — exactly 3 representable states, each with exactly its own data
enum Connection {
    Connecting { started_at: OffsetDateTime },
    Connected { since: OffsetDateTime, session: SessionId },
    Disconnected { at: OffsetDateTime, reason: DisconnectReason },
}
```

Signals to hunt for, each a G1 gap:

- Two or more `Option` fields whose legal combinations are fewer than the product.
- A `bool` that means three things, or a pair of bools with a forbidden combination.
- A field documented as "only set when …". The comment is the type that should have been written.
- `match` arms with `unreachable!()`, `expect("must be set")`, or `_ => {}` swallowing a state — each marks a state the type admits and the code denies.
- The same `if x.is_some()` check repeated across call sites: the check belongs in the type.

The fix generally deletes downstream branches. Say how many when proposing it.

## Newtypes with smart constructors

Private field + fallible constructor = the invariant holds for every value of the type, forever. Parse once, at the edge; pass the type, never the raw value.

```rust
pub struct NonEmptyString(String);   // field private — construction only via TryFrom

impl TryFrom<String> for NonEmptyString {
    type Error = Error;
    fn try_from(value: String) -> Result<Self, Self::Error> {
        if value.is_empty() { Err(Error::EMPTY) } else { Ok(Self(value)) }
    }
}
```

Wire the newtype to the SQL domain so the two layers cannot drift, and so a corrupt row is a deserialization error rather than a silently-accepted value:

```rust
#[derive(Clone, Copy, Debug, AsExpression, FromSqlRow)]
#[diesel(sql_type = schema::schema::sql_types::NonZeroBigint)]
pub struct NonZeroBigInt(pub std::num::NonZeroI64);

impl FromSql<sql_types::NonZeroBigint, Pg> for NonZeroBigInt {
    fn from_sql(bytes: PgValue<'_>) -> deserialize::Result<Self> {
        FromSql::<BigInt, _>::from_sql(bytes).and_then(|raw| {
            std::num::NonZero::<i64>::new(raw)
                .ok_or_else(|| "nonzerobigint-corruption".into())
                .map(Self)
        })
    }
}
```

**Before proposing a new type, search `types/`, `src/types/`, and `db/src/types/ids.rs`.** Reinventing an existing validated type is its own finding. Strongly-typed ids (never a raw `i32`) make "passed the wrong id" a compile error — the highest-value newtype in any schema with dozens of tables.

## Parse, don't validate

```rust
// BAD — validated then discarded; every later caller must re-trust or re-check
fn charge(email: &str, cents: i64) -> Result<()> {
    if !email.contains('@') { bail!("bad email") }
    ...
}

// GOOD — the proof travels with the value
fn charge(email: &Email, cents: NonZeroU63) -> Result<()> { ... }
```

If a function validates its arguments and returns `()` or a plain value, the knowledge is thrown away — G2. The fix is to move the check into a constructor and change the signature.

Related G2 smells: `as` casts (silently truncate — use `TryFrom`), `unwrap_or` / `unwrap_or_default` on domain data (invents a legal-looking value for missing data), and `assert!`/`ensure!` guarding something a domain or `CHECK` could own permanently.

## Typestate for transition safety

When the *order* of operations matters, encode the state in the type so a wrong-order call does not compile:

```rust
struct Draft;
struct Approved;
struct Withdrawal<S> { id: WithdrawalId, cents: NonZeroU63, _state: PhantomData<S> }

impl Withdrawal<Draft>    { fn approve(self, by: AdminId) -> Withdrawal<Approved> { ... } }
impl Withdrawal<Approved> { fn execute(self) -> Result<Executed> { ... } }   // unreachable from Draft
```

Reserve it for transitions where a mistake is expensive; for most flows a plain sum type plus a DB guard is the right cost/benefit, and a `PhantomData` tower on a simple flow is its own complexity finding.

## Enums at every boundary

Raw strings for a known-finite set are a G1 gap wherever they appear — request handlers, config, message payloads. Parse into the enum at the boundary and pass the enum down. `match` then proves exhaustiveness for you; that is the whole return on the change.

## Layer 2 — query guards

The database is the arbiter of transitions. Filter on the *precondition* so that an illegal transition affects zero rows and the row-count trait turns that into an error:

```rust
// Guard against overwrite: only an uncompleted row may be completed
pub async fn complete(conn: &mut crate::Conn, id: ThingId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(things::table.find(id))
        .filter(things::completed_at.is_null())
        .set(things::completed_at.eq(now))
        .execute_one(conn)
        .await
}

// Full transition precondition: validated, and not yet confirmed
pub async fn confirm(conn: &mut crate::Conn, id: AttemptId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(attempts::table.find(id))
        .filter(attempts::validated_at.is_not_null())
        .filter(attempts::confirmed_at.is_null())
        .set(attempts::confirmed_at.eq(now))
        .execute_one(conn)
        .await
}
```

What to flag at this layer:

- An `UPDATE` that sets a state column with **no filter on the current state** — G4, always. It permits every transition, including a row going backwards or being completed twice.
- `execute()` where `execute_one` / `execute_at_most_one` belongs: an update that silently touched zero rows is a lost transition that reports success.
- `SELECT`-then-`INSERT`/`UPDATE` used to enforce uniqueness or a state precondition — two statements, two snapshots, one race. Push it into a partial unique index or a filtered update.
- Side effects (HTTP, queue publishes) inside a transaction block, and related writes spread across several transactions where a partial application is illegal.
- `ALL_COLUMNS` / `Selectable` loading a whole row into a struct with optional fields, when the caller needs three columns and a narrower type could describe exactly the state being read.

## Outcome enums over stringly-typed errors

When a caller must *distinguish* results, return a sum type; do not encode the distinction in an error message.

```rust
pub enum Outcome {
    Settled(Receipt),
    InsufficientFunds { available: NonNegI64 },
    AlreadySettled,
}
```

`anyhow` with context is for failures nobody branches on. An `Err` whose message is matched on, or a `bool` returned where the caller needs to know *why*, is a G1/G6 gap.
