# TigerStyle In Rust

TigerStyle is written for Zig. Several rules name a Zig mechanism. Translate the intent — do not imitate the syntax.

## Contents

- [Assertions](#assertions)
- [Compile-time assertions](#compile-time-assertions)
- [Sized types](#sized-types)
- [Division](#division)
- [Naming: where Rust wins](#naming-where-rust-wins)
- [Named arguments](#named-arguments)
- [In-place construction](#in-place-construction)
- [Allocation](#allocation)
- [Errors](#errors)
- [Tooling config](#tooling-config)

## Assertions

The single most important translation. **`debug_assert!` is compiled out of release builds; `assert!` is not.**

TigerBeetle runs its assertions in production — that is the whole premise, since an assertion's job is to turn a correctness bug into a liveness bug *in the field*. So:

- **Default to `assert!`.** A comparison, a bounds check, a null check, a range check: keep it in release.
- **Use `debug_assert!` only for checks that are genuinely expensive** — anything worse than O(1) relative to the surrounding work, such as verifying a whole array is sorted inside a loop over that array.
- Never use `debug_assert!` for a cheap check merely out of habit. That silently deletes the safety net in the only build that matters.

`unwrap()` and `expect()` on a value that an invariant guarantees is an assertion, and is correct TigerStyle — it crashes on programmer error. `expect("...")` with a message stating the invariant is better than a bare `unwrap()`. This is distinct from `unwrap()` on an *operating* error, which is a bug.

Split compound assertions and use `if` for implication, as in Zig:

```rust
assert!(index < count);
assert!(count <= COUNT_MAX);
if committed { assert!(prepared); }
```

Prefer `assert_eq!`/`assert_ne!` over `assert!(a == b)` — the panic message carries both values.

## Compile-Time Assertions

Zig's `comptime` assertions have a direct equivalent:

```rust
const _: () = assert!(size_of::<Header>() == 128);
const _: () = assert!(PIPELINE_MAX < VIEW_CHANGE_HEADERS_MAX);
```

Inside a function, `const { assert!(...) }` (Rust 1.79+) works too. These check the design before the program runs, so use them freely on type sizes, alignment, and relationships between constants.

## Sized Types

Use `u32`/`u64`/`i64` for anything stored, sent over a wire, or compared against a protocol constant — the value must mean the same thing on every target.

`usize` is for indexing and lengths of in-memory collections, where it is the correct type. Convert at the boundary with `u32::try_from(len).unwrap()` (an assertion) rather than `as`, which truncates silently. Prefer `try_from` over `as` everywhere; `as` is a silent cast and hides exactly the off-by-one class TigerStyle is trying to eliminate.

## Division

Zig's `@divExact` / `@divFloor` / `div_ceil` show intent. Rust equivalents:

| Intent | Rust |
|--------|------|
| Exact | `assert_eq!(a % b, 0);` then `a / b` |
| Floor | `a / b` for unsigned; `a.div_euclid(b)` for signed |
| Ceiling | `a.div_ceil(b)` |

Bare `/` on unsigned is floor, but it does not *say* floor. Where rounding is interesting, make the choice visible.

## Naming: Where Rust Wins

TigerStyle asks for `VSRState` over `VsrState`. **Rust's own convention and `clippy` disagree** — Rust uses `VsrState`, and this is one of the places where [local conventions outrank the skill](../SKILL.md#rules-for-working-this-way). Follow Rust.

Everything else transfers unchanged: `snake_case` functions, variables and files (already Rust's convention), no abbreviations, units and qualifiers last (`latency_ms_max`), matched character counts on related names, caller-prefixed helpers.

## Named Arguments

Rust has no named arguments. Where a function takes two parameters of the same type that could be swapped, use a struct:

```rust
// Prefer.
pub struct ReadOptions { pub offset: u64, pub limit: u64 }
fn read(grid: &Grid, options: ReadOptions) -> Chunk { /* ... */ }

// Over: read(&grid, 4096, 128) — which is which?
fn read(grid: &Grid, offset: u64, limit: u64) -> Chunk { /* ... */ }
```

Better still, a newtype per meaning (`Offset(u64)`, `Limit(u64)`) makes the swap a compile error rather than a convention.

Singleton dependencies — an allocator, a clock, a tracer — stay positional and come first, most general to most specific.

## In-Place Construction

Rust has no stable placement-new, and return-value optimization is not guaranteed. For a genuinely large value, take `&mut MaybeUninit<T>` and write through it, or `Box::new_uninit()` and initialize in place, rather than building on the stack and moving.

For most types this is not worth the `unsafe`. **Measure before reaching for it** — the rule exists to prevent stack growth in a database's hot path, not as a general style rule. The transferable part is the ordinary one: if an argument is over 16 bytes and should not be copied, pass `&T`, not `T`.

## Allocation

Static allocation is [advisory](safety.md#memory-advisory). The Rust-shaped version:

- `Vec::with_capacity(BOUND)` at startup, then reuse the buffer instead of reallocating.
- Fixed-capacity containers where the bound is small and known: `[T; N]`, `arrayvec`, `heapless`.
- Assert capacity is never exceeded: `assert!(v.len() < v.capacity());` before a push on a hot path.
- Keep allocation out of the per-item path entirely.

## Errors

- **All errors handled.** `let _ = fallible();` is a swallowed error. So is `.ok();` used to discard a `Result`.
- Mark fallible functions' results `#[must_use]` where the type does not already carry it.
- Distinguish the two kinds, because they get opposite treatment: an **operating error** (disk full, peer disconnected, malformed input) is expected and must be handled and tested; a **programmer error** (a broken invariant) must panic.
- Test the error paths. That is where the catastrophic failures come from.

## Tooling Config

`rustfmt.toml` — 100 columns and 4 spaces are already rustfmt's defaults, so state them to make the intent explicit and pin them against a future default change:

```toml
max_width = 100
tab_spaces = 4
hard_tabs = false
```

`clippy.toml` — bring the function-length limit to TigerStyle's 70:

```toml
too-many-lines-threshold = 70
```

Then enable the lints that enforce the rules, in `Cargo.toml`:

```toml
[lints.clippy]
too_many_lines = "deny"        # H1: 70 lines.
as_conversions = "warn"        # Silent casts hide off-by-one bugs.
cast_possible_truncation = "warn"
indexing_slicing = "warn"      # Prefer an explicit bounds assertion.
unwrap_in_result = "warn"
```

Note `clippy::missing_panics_doc` and `clippy::unwrap_used` fight the assertion discipline — a deliberate panic on a broken invariant is the point. Leave them off, or allow them locally with a comment saying why the invariant holds.
