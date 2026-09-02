# Stack Reference — Rust

The mechanisms of layers 2 and 3 when the language is Rust. The query examples use Diesel. `../layer-3-types.md` and `../layer-2-access.md` give the questions. This file gives the answers for this language.

Rust is a tier A language: the compiler proves the model. A change to the model gives more certainty here than the same change in a tier C language.

## Contents

- [Sum types in place of records with holes](#sum-types-in-place-of-records-with-holes)
- [Newtypes with a constructor that can fail](#newtypes-with-a-constructor-that-can-fail)
- [Parse, do not validate](#parse-do-not-validate)
- [Typestate for a sequence of operations](#typestate-for-a-sequence-of-operations)
- [Enums at each boundary](#enums-at-each-boundary)
- [Layer 2 — conditions on each query](#layer-2--conditions-on-each-query)
- [Enums for results, not text in errors](#enums-for-results-not-text-in-errors)

## Sum types in place of records with holes

A flat record with many optional fields permits combinations that the domain forbids. Use one variant for each state. Each variant holds the fields of that state only.

```rust
// BAD - 16 combinations are representable, 3 are legal
struct Connection {
    state: ConnState,
    connected_at: Option<OffsetDateTime>,
    disconnected_at: Option<OffsetDateTime>,
    last_error: Option<String>,
}

// GOOD - 3 states are representable, each with its own data
enum Connection {
    Connecting { started_at: OffsetDateTime },
    Connected { since: OffsetDateTime, session: SessionId },
    Disconnected { at: OffsetDateTime, reason: DisconnectReason },
}
```

Look for these signs. Each one is a G1 gap:

- Two or more `Option` fields with fewer legal combinations than the total number of combinations.
- A `bool` with three meanings, or two `bool` fields with a forbidden combination.
- A field with the comment "set only when ...". That comment is the type that the author did not write.
- A `match` arm with `unreachable!()` or `expect("must be set")`. Also `_ => {}` that hides a state. Each one marks a state that the type permits and the code forbids.
- The same `if x.is_some()` test at many call sites. The test belongs in the type.

The fix usually removes branches. Count them in the proposal.

## Newtypes with a constructor that can fail

A private field and a constructor that can fail hold the invariant for each value of the type, permanently. Parse the value one time, at the edge. Then pass the type, never the raw value.

```rust
pub struct NonEmptyString(String);   // the field is private, so only TryFrom can construct it

impl TryFrom<String> for NonEmptyString {
    type Error = Error;
    fn try_from(value: String) -> Result<Self, Self::Error> {
        if value.is_empty() { Err(Error::EMPTY) } else { Ok(Self(value)) }
    }
}
```

Connect the newtype to the SQL domain (`postgres.md`). Then the two layers cannot become different, and a corrupt row gives a deserialization error, not a valid value:

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

**Search the type modules of the repository before you propose a new type**, including the module that holds the typed identifiers. A second type for an invariant that a type already holds is a finding. A typed identifier (never a raw `i32`) makes "this is the identifier of a different table" a compile error. It is the newtype with the highest value in a schema with many tables.

## Parse, do not validate

```rust
// BAD - the function validates the value and then discards the result
fn charge(email: &str, cents: i64) -> Result<()> {
    if !email.contains('@') { bail!("bad email") }
    ...
}

// GOOD - the proof moves with the value
fn charge(email: &Email, cents: NonZeroCents) -> Result<()> { ... }
```

A function that validates its arguments and returns `()` discards the knowledge. This is a G2 gap. Move the check into a constructor and change the signature.

Other G2 problems: an `as` cast (it removes the high bits quietly, so use `TryFrom`), `unwrap_or` and `unwrap_or_default` on domain data (they invent a valid value for invalid data), and `assert!` or `ensure!` for something that a domain or a `CHECK` can hold permanently.

## Typestate for a sequence of operations

If the sequence of operations matters, put the state in the type. Then the compiler rejects a call in the incorrect sequence:

```rust
struct Draft;
struct Approved;
struct Withdrawal<S> { id: WithdrawalId, cents: NonZeroCents, _state: PhantomData<S> }

impl Withdrawal<Draft>    { fn approve(self, by: AdminId) -> Withdrawal<Approved> { ... } }
impl Withdrawal<Approved> { fn execute(self) -> Result<Executed> { ... } }   // Draft cannot call this
```

Use this pattern for a transition where an error is expensive. For most flows, a sum type and a condition on the write are sufficient. A tower of `PhantomData` on a simple flow is a finding about complexity.

## Enums at each boundary

A raw string for a finite group of values is a G1 gap at each place: request handlers, configuration and message payloads. Parse the string into the enum at the boundary and pass the enum. Then `match` proves that the code covers each value. This proof is the benefit of the change.

## Layer 2 — conditions on each query

The database decides if a transition is legal. Put the condition of the transition in the filter. Then an illegal transition changes no row, and a row-count check turns that into an error.

Diesel itself gives `execute`, which returns `QueryResult<usize>` and leaves the count to the caller. `execute_one` and `execute_at_most_one` below are an extension trait on top of it — the shape most repositories end up with, not a method that ships with Diesel. Search the repository for its own version before you name one, and propose the trait only where no equivalent exists:

```rust
// Only a row that is not complete can become complete
pub async fn complete(conn: &mut crate::Conn, id: ThingId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(things::table.find(id))
        .filter(things::completed_at.is_null())
        .set(things::completed_at.eq(now))
        .execute_one(conn)
        .await
}

// The full condition: the row is validated, and no code confirmed it before
pub async fn confirm(conn: &mut crate::Conn, id: AttemptId, now: OffsetDateTime) -> QueryResult<()> {
    diesel::update(attempts::table.find(id))
        .filter(attempts::validated_at.is_not_null())
        .filter(attempts::confirmed_at.is_null())
        .set(attempts::confirmed_at.eq(now))
        .execute_one(conn)
        .await
}
```

Report these problems at this layer:

- An `UPDATE` that sets a state column with **no filter on the current state**. This is always a G4 gap. It permits each transition, and also a transition backwards and a second completion.
- `execute()` with the returned count discarded, where the transition permits exactly one row. An update that changed no row is a lost transition, and the code reports a success. The fix is the repository's own row-count helper, or `execute_one` above where it has none.
- A `SELECT` before an `INSERT` or an `UPDATE`, for uniqueness or for a condition on the state. Two statements use two views of the data, so a second writer can act between them. Use a partial unique index or a filter on the update.
- External effects (HTTP, a message to a queue) inside a transaction block. Also related writes in more than one transaction, where a part of the change is illegal alone.
- `ALL_COLUMNS` or `Selectable` that loads a full row into a struct with optional fields, where the caller uses three columns. A more narrow type can describe the state that the caller reads.

## Enums for results, not text in errors

If the caller must identify the result, return a sum type. Do not put the difference in the text of an error:

```rust
pub enum Outcome {
    Settled(Receipt),
    InsufficientFunds { available: NonNegI64 },
    AlreadySettled,
}
```

Use `anyhow` with context for a failure that no caller examines. An `Err` with a message that the code examines, or a `bool` where the caller needs the reason, is a G1 or G6 gap.
