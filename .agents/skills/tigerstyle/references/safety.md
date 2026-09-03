# Safety

Safety is the first design goal. When safety conflicts with performance or ergonomics, safety wins.

The foundation is [NASA's Power of Ten](https://spinroot.com/gerard/pdf/P10.pdf).

## Contents

- [Control flow](#control-flow)
- [Bounds](#bounds)
- [Assertions](#assertions)
- [Function shape](#function-shape)
- [Conditions and negation](#conditions-and-negation)
- [Errors](#errors)
- [Memory (advisory)](#memory-advisory)
- [External events](#external-events)

## Control Flow

- Use only simple, explicit control flow.
- **Do not use recursion.** Recursion makes a bound unprovable. Anything that should be bounded must be visibly bounded, which means a loop with a limit.
- Use a minimum of excellent abstractions, and only where they make the best sense of the domain. Abstractions are [never zero cost](https://isaacfreund.com/blog/2022-05/); every one risks leaking.
- Enable every compiler warning at the strictest setting, from day one.

## Bounds

**Put a limit on everything**, because everything has a limit in reality. Every loop and every queue has a fixed upper bound. This is [fail-fast](https://en.wikipedia.org/wiki/Fail-fast): a violation surfaces sooner rather than later.

Where a loop genuinely cannot terminate — an event loop, a supervisor — assert that fact so the exception is deliberate.

```rust
// The bound is named, so a reviewer can check it against the domain.
const BATCH_TRANSFERS_MAX: usize = 8189;
assert!(transfers.len() <= BATCH_TRANSFERS_MAX);
for transfer in transfers { /* ... */ }
```

Use explicitly-sized types — `u32`, `u64` — for anything stored, sent or compared. Avoid architecture-dependent widths (`usize`) outside indexing, because the same program must behave identically on every target.

## Assertions

> Assertions detect programmer errors. Unlike operating errors, which are expected and must be handled, assertion failures are unexpected. The only correct way to handle corrupt code is to crash. Assertions downgrade catastrophic correctness bugs into liveness bugs. Assertions are a force multiplier for discovering bugs by fuzzing.

**Density: two per function, on average.** Assert every function's arguments, return values, preconditions, postconditions and invariants. A function must not operate blindly on data it has not checked. The purpose of a function is to raise the probability that the program is correct, and its assertions are part of how it does that.

### The golden rule

**Assert the positive space you do expect, and the negative space you do not.** Interesting bugs live exactly where data crosses the valid/invalid boundary. The same rule makes tests exhaustive: test with valid data, with invalid data, and with valid data *as it becomes* invalid.

### Pair assertions

For every property, find at least two different code paths to assert it. Assert data is valid immediately before writing it to disk, and again immediately after reading it back. A single assertion proves a belief at one point; a pair proves the belief survived the round trip.

### Mechanics

- **Split compound assertions.** `assert(a); assert(b);` beats `assert(a and b);` — simpler to read, and the failure names which half broke.
- **Use a single-line `if` for an implication**: `if (a) assert(b)`.
- **Assert relationships between compile-time constants** as a sanity check and as enforcement of subtle invariants or type sizes. Compile-time assertions check the program's design integrity *before it executes*, which makes them the most powerful kind.
- **A blatantly true assertion can replace a comment** where the condition is critical and surprising. It is stronger documentation, because it cannot rot.

### Assertions are not a substitute for understanding

A fuzzer proves the presence of bugs, never their absence. The order is:

1. Build a precise mental model of the code.
2. Encode that understanding as assertions.
3. Write the code and comments that explain and justify the model to a reviewer.
4. Use simulation testing as the last line of defense — to find bugs in your and the reviewer's understanding.

## Function Shape

There is a sharp discontinuity between a function that fits on a screen and one that needs scrolling. Hence the hard limit of **70 lines**. Many splits satisfy the number; few feel right:

- **Good function shape is the inverse of an hourglass**: few parameters, a simple return type, a lot of meaty logic between the braces.
- **Centralize control flow.** Keep the `if`s, `match`es and `switch`es in the parent; move non-branchy fragments into helpers. One function owns control flow; the rest do not care about it. This is ["push `if`s up and `for`s down"](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html).
- **Centralize state manipulation.** The parent holds the relevant state in locals; helpers *compute what should change* and return it, rather than applying the change themselves. Keep leaf functions pure.

## Conditions And Negation

Compound conditions make it hard for the reader to verify that every case is handled. Split them into nested `if`/`else` branches, and split long `else if` chains into `else { if { } }` trees. Then ask whether each `if` also needs an `else` — so that the positive and negative spaces are both handled or asserted.

**State invariants positively.** Negations are not easy.

```rust
if index < count {
    // The invariant holds.
} else {
    // The invariant does not hold.
}
```

is easier to get right than `if index >= count { /* it is not true that the invariant holds */ }`, and it matches the grain of how `index` is compared to `count` in a loop condition.

## Errors

**All errors must be handled.** An [analysis of production failures in distributed data-intensive systems](https://www.usenix.org/system/files/conference/osdi14/osdi14-paper-yuan.pdf) found that most catastrophic failures were preventable by simply testing the error-handling code.

> "Specifically, we found that almost all (92%) of the catastrophic system failures are the result of incorrect handling of non-fatal errors explicitly signaled in software."

So: no swallowed errors, no bare `catch {}`, no `let _ =` on a fallible call, and error paths get tests like any other path.

**Pass options explicitly at the call site** rather than relying on library defaults. Explicit options read better, and they immunize the code against a library changing its defaults underneath it.

## Memory (Advisory)

TigerBeetle allocates all memory statically at startup and never allocates or frees afterwards. This removes unpredictable latency and makes use-after-free impossible, and as a second-order effect forces the design to account for every memory-usage pattern upfront.

This is the right rule for a database. **It is advisory here** — weigh it before adopting. Where the full rule does not fit, take the transferable parts: bound every buffer and collection, pre-size what you can, and keep allocation off the hot path.

## External Events

**Never do things directly in reaction to external events.** Run the program at its own pace and poll or drain instead. This keeps control flow yours, which is a safety property; it lets you batch instead of context-switching per event, which is a performance property; and it makes work-per-time-period easy to bound.
