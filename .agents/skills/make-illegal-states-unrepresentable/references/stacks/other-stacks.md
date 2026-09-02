# Stack Reference — Other Stacks

The mechanisms of the stacks that have no file of their own. Each table is a start point, not an authority. Confirm each mechanism against the version in the repository before you propose it.

## Contents

- [Conditional writes (layer 2)](#conditional-writes-layer-2)
- [Stores (layer 1)](#stores-layer-1) — MySQL and MariaDB, SQLite, MongoDB and other document stores, DynamoDB and key-value stores, event logs
- [Languages (layer 3)](#languages-layer-3) — the tier table
- [Boundaries (layer 4)](#boundaries-layer-4) — proto3, JSON and OpenAPI, GraphQL, Avro, command line
- [How To Adapt To A New Stack](#how-to-adapt-to-a-new-stack)

## Conditional writes (layer 2)

Each store has this shape: put the condition in the write, then read the count of the records that the write changed.

| Store | Conditional write | Signal |
|---|---|---|
| SQL | `UPDATE ... WHERE id = ? AND <condition>` | the count of changed rows |
| MongoDB | `updateOne({_id, <condition>}, ...)` | `matchedCount` |
| DynamoDB, Cassandra | `ConditionExpression`, or an `IF` clause | an error for the failed condition |
| Redis | `WATCH` with `MULTI`, or a Lua script | the return value of the script |
| HTTP resource | `If-Match: <etag>` | status `412` |
| Event log | an append with the expected version | an error for the version conflict |

If the code reads the store and then writes it, use this sequence of fixes. First, put the condition in the store: a unique constraint, a conditional write, or an insert with explicit behaviour for a conflict. Second, use one statement that tests and writes, such as `UPDATE ... WHERE balance >= ?`. Third, lock the key of the group inside a transaction, and give the cost of the lock in the proposal. A higher isolation level is also legal, but only if the code repeats the transaction after a serialisation error.

## Stores (layer 1)

### MySQL and MariaDB

| Question | Mechanism | Notes |
|---|---|---|
| Value limits | `CHECK`, in version 8.0.16 and later | **Confirm the version.** An earlier version accepts the syntax and ignores the constraint. There are no domain types, so each column repeats the constraint |
| Closed sets | `ENUM(...)`, or a table of values with a foreign key | An `ALTER` on an `ENUM` is expensive. A table of values is safer for a group that grows |
| Conditional uniqueness | a unique index on a generated column that is `NULL` outside the state | There are no partial indexes. A unique index ignores `NULL`, and this makes the pattern work |
| Rules between rows | none | Use one writer, or add a scheduled check |
| Totals | `BEFORE` and `AFTER` triggers, but not deferred | A trigger runs for each statement, so a transaction can fail after it writes some rows. Calculate the total instead |
| Identifiers | `AUTO_INCREMENT` | A caller can also supply the value. There is no equivalent of `GENERATED ALWAYS` |

### SQLite

| Question | Mechanism | Notes |
|---|---|---|
| Value limits | `CHECK` | The column types are advisory. Use `STRICT` tables (version 3.37 and later) |
| Closed sets | `CHECK (col IN (...))`, or a foreign key to a table of values | There is no enum type |
| Conditional uniqueness | a partial unique index | SQLite supports this fully |
| Foreign keys | **off by default.** Each connection needs `PRAGMA foreign_keys = ON` | A schema with many foreign keys that no connection enforces is a frequent and severe finding |
| Rules between rows | none | SQLite has one writer, and this is the control that replaces the mechanism. Write this fact |
| Migrations | `ALTER TABLE` has limits, so a change usually needs a new table and a copy | Give this cost in the proposal |

### MongoDB and other document stores

| Question | Mechanism | Notes |
|---|---|---|
| Value limits, required fields | a `$jsonSchema` validator with `required` and `bsonType` | Use `validationLevel: "strict"` and `validationAction: "error"`. Other values make the validator advisory |
| Closed sets | `enum` in the validator | |
| The shape of each state | `oneOf` over one schema for each state, with a `kind` field | This is the equivalent of a `CASE` constraint |
| Conditional uniqueness | a partial unique index (`partialFilterExpression`) | The most frequent tool. A unique sparse index also works |
| Agreement between references | none. MongoDB has no foreign keys | Put the child document inside the parent document. Then disagreement is impossible. Or make one access function the only writer |
| Totals | none | Put the items in the parent document, or calculate the total. A stored total with the items in a different collection has no mechanism |
| Transitions | `updateOne` with the condition in the filter, then read `matchedCount` | |
| Atomicity | A write to one document is atomic. A write across documents needs a replica set and a session | Change the model, and make one document the unit of change |

A validator applies to new writes only. MongoDB does not validate the documents that exist. Therefore a proposal for a validator needs the same count of violations as a proposal for a SQL constraint.

### DynamoDB, key-value stores and wide-column stores

| Question | Mechanism | Notes |
|---|---|---|
| Uniqueness | a second item, where the key is the unique value, in a transaction with the main item | This is the standard pattern. There is no unique index |
| Conditional transition | `ConditionExpression` on the current value of the attribute | It gives an error for the failed condition, and the caller must handle that error |
| Value limits, closed sets | none in the store | The invariant lives in layer 3. Change the model, and make one item the unit of change |
| Totals | atomic counters, or a calculated projection | The data is eventually consistent, so a stored total is not evidence |

The honest report for this group: the store holds the keys and the conditions, and nothing else. Therefore layers 2 and 3 hold the model. For each other invariant, a scheduled check replaces prevention.

### Event logs and append-only stores (Kafka, EventStore, ledger tables)

The events are the model of the state. The invariants change their shape. "Which event can follow which event" becomes a check in the projection, or optimistic concurrency on the append. "Which events can exist" becomes a validator in the producer. Uniqueness and totals live in the projection, so a projection that can produce an illegal state is the finding. Old events do not change, and a replay reads them again, so the proposal must include the versions of the schema.

## Languages (layer 3)

Tier A gives the most proof, and tier D gives none.

| Language | Tier | Sum type | Wrapper | Check for each case | Look for |
|---|---|---|---|---|---|
| TypeScript (strict) | B | a union with a literal `kind` field | a branded type (`string & {__brand}`), or a class with a `#private` field | `assertNever` in the default branch | An `any` or an `as` cast removes each proof. Without `strictNullChecks`, layer 3 proves nothing. Parse at the edge with a schema library, then derive the type from the schema |
| Python | B | a `Union` of frozen dataclasses with `match`, or an `Enum` | `NewType` (the checker only), or a frozen dataclass with a check in `__post_init__` | `typing.assert_never`, and an exception at run time | The type checker must run in the pipeline. If it does not run, the annotations are comments |
| Go | C | an interface with unexported implementations, or a struct with a `Kind` field and a constructor | an unexported field, and `New...() (T, error)` in its own package | none. The `default:` case must give an error | `var x T` constructs the zero value and uses no constructor. Therefore the store must hold more |
| Java | C | a `sealed interface` with records (version 17 and later) | a `final` class, a private constructor and a static factory | The compiler checks a `switch` over a sealed type (version 21 and later). Other versions need `default: throw` | A setter and a constructor with no arguments open each invariant that the constructor closed |
| C# | C to B | records, a sealed hierarchy, `required` members | a `readonly record struct` with a private constructor and a `Create` factory | A switch expression gives a warning, not an error | Nullable reference types must be on for the full project |
| Kotlin, Swift | A | `sealed` and `enum` with associated values | a `value class` or a `struct` with a private initializer and a factory | The compiler checks `when` and `switch` | A platform type at the boundary with Java adds a null again |
| Elixir, Erlang | D (typespecs are advisory) | tagged tuples: `{:ok, x}`, `{:pending, at}` | an opaque type with a constructor in its module | Dialyzer, but it is not complete | The pattern in the head of the function is the mechanism. A crash for an unmatched clause is correct behaviour here |
| Haskell, OCaml, F# | A | native | an abstract type in the module signature | The compiler checks each case | The risk here is too many states, not too few. G5 findings are the most frequent |
| Ruby, JavaScript | D | an object with a tag from a factory | `Object.freeze` with a factory, or `private_constant` in Ruby | none. Give an error for an unknown tag | The constructor is the only control point, so the report must use layers 1 and 2 |

## Boundaries (layer 4)

| Format | Presence | Closed set | Sum type | The main problem |
|---|---|---|---|---|
| proto3 | Scalars have none. Use `optional` or a message field | `enum` with `UNSPECIFIED = 0`, which the handler rejects | `oneof` | An absent string arrives as `""`, an absent number as `0`, and an absent enum as the zero value. Therefore the zero value becomes a business value |
| JSON with OpenAPI | a `required` list. Also separate `null` from "no key" | `enum` | `oneOf` with a `discriminator` | Default values, optional fields for required values, and floating-point numbers for money. A union with no tag selects the first shape that parses |
| GraphQL | nullability for each field and each element of a list | `enum` | `union` or an interface | A nullable field for a required value. `[Type!]!` and `[Type]` are different, and the second permits a list with holes |
| Avro, or a schema registry | a union with `null` | `enum` | a union of records | The compatibility mode controls which changes break a client |
| Command line, environment, configuration | Each value is a string, so you must define "absent" | Parse into an enum when the program starts | a subcommand, or a configuration block with a tag | A default value that works in development and hides an absent production value. Give the error when the program starts, not at the first use |

Two more rules for each format. Parse the value into the wrapper type directly, because then an invalid value never becomes a valid object. Give each enum an explicit value for "unknown", and reject that value in the handler.

## How To Adapt To A New Stack

1. **Read. Do not assume.** Find the constraints of the store in its own documentation, for the version in use. Then search the repository for the constraints, validators and wrapper types that exist. The local pattern is usually there already.
2. **Connect each question** from `../layer-1-store.md` to a mechanism, or to the words "this store does not have this mechanism".
3. **For each absent mechanism, name the control that replaces it.** Also give the method that finds a violation. This is part of the report, not an excuse.
4. **Write the proposal in the syntax of the stack.** Confirm the syntax against the documentation. A team cannot merge a fix in the incorrect syntax, and a mechanism that does not exist removes the value of the full review.
