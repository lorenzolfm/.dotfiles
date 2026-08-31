# Layer 4 — The API Boundary

The wire format is the widest, weakest layer. It enforces nothing by itself; its only job is to be *parsed into* layer 3 at the edge, exactly once. Most G6 gaps live here: a value the domain models precisely gets flattened to `String`/`i64`/all-optional-fields on the way out, and every consumer re-invents the invariant.

## proto3 makes everything optional — plan for it

In proto3, scalar fields have no presence: a missing `string` arrives as `""`, a missing `int64` as `0`, a missing enum as the zero value. Generated Rust message structs are therefore *maximally wide* — the exact opposite of a tight domain type. Two consequences:

**Enums must reject their zero value.** Always define `UNSPECIFIED = 0` and treat it as invalid at the handler:

```protobuf
enum Status {
    STATUS_UNSPECIFIED = 0;
    STATUS_PENDING     = 1;
}
```

```rust
let status = match req.status() {
    proto::Status::Unspecified => return Err(Status::invalid_argument("status required")),
    proto::Status::Pending => Status::Pending,
};
```

A handler that maps `Unspecified` to a default, or uses a catch-all `_ =>` arm, is a G1 gap at the front door: the caller's omission becomes a silently-chosen business value.

**Absence and zero must not be conflated.** `amount: 0` for a required amount, or `""` for a required name, must be rejected — not defaulted. `req.amount.unwrap_or(0)` and `req.name.unwrap_or_default()` are the canonical forms of this bug. Use `message`-wrapped or `optional` fields where genuine absence must be distinguishable from zero.

## `oneof` is the wire's sum type — use it

If the domain has a sum type, the API must have a `oneof`. Anything else re-widens the model:

```protobuf
// BAD — 2^3 shapes on the wire, 3 legal; every client re-derives which one it got
message PaymentResult {
  bool     settled          = 1;
  string   failure_reason   = 2;
  Receipt  receipt          = 3;
}

// GOOD — the client's match is exhaustive and the illegal shapes do not exist
message PaymentResult {
  oneof outcome {
    Receipt          settled            = 1;
    InsufficientFunds insufficient_funds = 2;
    AlreadySettled    already_settled    = 3;
  }
}
```

This applies to responses as forcefully as to requests. A response message whose fields are "all optional, some combination will be set" pushes the entire invariant onto every client, including mobile apps that ship on their own schedule and cannot be fixed retroactively.

## Parse at the edge, once

```rust
// BAD — raw strings and wide integers travel inward; validation happens somewhere, or nowhere
async fn pay(req: PayRequest) -> Result<Response> {
    feature::pay(req.email, req.amount, req.currency).await
}

// GOOD — the boundary is the only place that can fail on shape
async fn pay(req: PayRequest) -> Result<Response> {
    let email: types::Email = req.email.parse().map_err(|_| invalid("email"))?;
    let amount = NonZeroU63::try_from(req.amount).map_err(|_| invalid("amount"))?;
    let currency = Currency::try_from(req.currency())?;   // enum, not String
    feature::pay(&email, amount, currency).await
}
```

Everything behind the handler then takes domain types. If a feature function's signature still contains `String`, `i64`, or `Option` for something the domain constrains, the parse either did not happen or was thrown away — G2/G6.

## REST / JSON specifics

- `serde(default)` and `Option<T>` on a required field are the JSON equivalents of proto3 widening.
- Deserialize straight into the newtype (`#[serde(try_from = "String")]`) so an invalid value never becomes a valid struct.
- Untagged enums silently pick the first shape that parses. Prefer an explicit tag so an ambiguous payload is an error, not a coin flip.
- Numbers: JSON has one number type. Money as a float is a Critical finding — integers in the smallest unit, or a string, never `f64`.

## Reviewing the boundary

For each field in the request and the response:

1. What does the domain allow? What does the wire type allow? Is the gap parsed away at the handler, or does it leak inward?
2. Is a zero value or empty string distinguishable from absence, and does the code care?
3. Does any response shape admit a combination the domain cannot produce? Who has to know which combination arrived?
4. Do old clients depend on a shape that makes the illegal state expressible? Note it: the fix may be additive (new `oneof` alongside the old fields, deprecate later) rather than a rewrite. Say which, and say what the migration path for clients is.

Additive-then-deprecate is usually the only shippable proposal for a public or mobile-facing API. Propose it that way.
