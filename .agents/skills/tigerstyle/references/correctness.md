# Correctness

The two remaining hard things: cache invalidation and off-by-one errors. Both reduce to the same cause — **a semantic gap, caused by a gap in time or space.** Code that is not contained along those dimensions is code you cannot check.

## Contents

- [Do not duplicate state](#do-not-duplicate-state)
- [Shrink the scope](#shrink-the-scope)
- [Reduce dimensionality](#reduce-dimensionality)
- [Off-by-one](#off-by-one)
- [Buffer bleeds](#buffer-bleeds)
- [Grouping allocation](#grouping-allocation)
- [Layout by the numbers](#layout-by-the-numbers)

## Do Not Duplicate State

- **Do not duplicate variables or take aliases to them.** Every copy is a chance for state to drift out of sync.
- **If an argument is more than 16 bytes and should not be copied, pass it by const reference.** This catches bugs where the caller makes an accidental stack copy before the call.
- **Construct large values in place** by passing an out-pointer, rather than returning by value and moving. In-place initialization can assume pointer stability and immovable types, and eliminates intermediate copy-moves that grow the stack. It is viral: if any field is initialized in place, the whole containing value should be.
- **Functions run to completion without suspending**, so that a precondition asserted at the top stays true for the function's lifetime. With a suspension point in the middle, those assertions are not documentation — they are misleading.

## Shrink The Scope

**Declare variables at the smallest possible scope, and minimize the number of variables in scope**, to reduce the probability that the wrong one is used.

**Calculate or check a variable close to where it is used. Do not introduce variables before they are needed, and do not leave them around after.** The distance between a check and a use is a POCPOU — place-of-check to place-of-use, the spatial cousin of [TOCTOU](https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use).

## Reduce Dimensionality

Simpler signatures and return types mean fewer branches at the call site — and that dimensionality is viral, propagating up the whole call chain.

The ladder, best to worst:

```
()  >  bool  >  u64  >  Option<u64>  >  Result<u64, E>
```

Each step right adds a case every caller must handle. Prefer the leftmost type the function can honestly return. This is a reason to make a function infallible by construction — validating at the boundary — rather than returning an error the caller must thread upward.

## Off-By-One

**The usual suspects are casual interactions between an `index`, a `count` and a `size`.** All three are primitive integers, but treat them as distinct types with explicit conversion rules:

| From | To | Rule |
|------|-----|------|
| `index` | `count` | add one — indexes are 0-based, counts are 1-based |
| `count` | `size` | multiply by the unit |

This is another reason [units and qualifiers in names](naming.md#units-and-qualifiers) matter: `block_index`, `blocks_count` and `blocks_size_bytes` cannot be confused; `n`, `len` and `size` can.

**Show your intent with respect to division.** Use an operation that names the rounding — exact, floor, or ceiling — so the reader knows you thought through the cases where rounding matters. A bare `/` says nothing about which case you intended.

## Buffer Bleeds

Be on guard for **[buffer bleeds](https://en.wikipedia.org/wiki/Heartbleed)** — the opposite of a buffer overflow. A buffer is not fully utilized and its padding is not zeroed, so stale bytes travel with the data. This leaks whatever was previously in memory, and it also breaks determinism, which matters wherever byte-for-byte reproducibility is a guarantee.

Zero padding explicitly. Assert the unused region is zero before writing and after reading — a natural [pair assertion](safety.md#pair-assertions).

## Grouping Allocation

Use newlines to group a resource acquisition with its matching release: a blank line before the acquisition and after the corresponding cleanup statement. The pair then reads as one visual block, and a missing release is visible as an unbalanced block rather than something you have to search for.

## Layout By The Numbers

- **Run the formatter.** Whatever the project's canonical formatter is, run it; do not hand-format.
- **4 spaces of indentation**, not 2 — more obvious to the eye at a distance.
- **100 columns**, unless the project configures its own width. Use it up, never go past it. Nothing should hide behind a horizontal scrollbar. Set a column ruler in your editor. To wrap a signature, call or data structure, add a trailing comma and let the formatter do the rest. The motivation for 100 is physical, like the 70-line function: just enough to fit two copies of the code side by side on a screen.
- **Braces on every `if`**, unless the whole statement fits on a single line. Consistency, and defense in depth against ["goto fail;"](https://www.imperialviolet.org/2014/02/22/applebug.html) bugs.
