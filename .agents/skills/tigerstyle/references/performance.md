# Performance

> "The lack of back-of-the-envelope performance sketches is the root of all evil." — Rivacindela Hudsoni

Performance is the second design goal, behind safety and ahead of developer experience.

## Contents

- [Design first, profile later](#design-first-profile-later)
- [The four resources](#the-four-resources)
- [Batching](#batching)
- [Control plane and data plane](#control-plane-and-data-plane)
- [Be explicit](#be-explicit)

## Design First, Profile Later

**The 1000x wins live in the design phase — precisely when you cannot measure or profile.** After implementation, fixes are harder and the gains are smaller. So think about performance from the outset, and have mechanical sympathy: like a carpenter, work with the grain.

This inverts the usual advice about premature optimization. The rule is not "optimize early", it is **"sketch early"**. A sketch costs minutes and is free to throw away.

## The Four Resources

Sketch against four resources and two characteristics each:

| Resource | Bandwidth | Latency |
|----------|-----------|---------|
| Network  | link capacity, fan-out | round trips |
| Disk     | sequential throughput | seek, fsync |
| Memory   | copy throughput | cache miss |
| CPU      | instructions retired | branch miss, dependency chain |

Sketches are cheap. Use them to be "roughly right" and land within 90% of the global maximum.

**Optimize the slowest resource first — network, disk, memory, CPU, in that order — after compensating for frequency of use.** Frequency dominates the ordering: a memory cache miss can cost as much as a disk fsync in aggregate, if it happens many thousands of times more often. Count the operations before ranking them.

## Batching

**Amortize network, disk, memory and CPU costs by batching accesses.**

Let the CPU be a sprinter doing the 100m. Be predictable. Do not force it to zig-zag and change lanes. Give it large enough chunks of work — which comes back to batching.

Batching is also what makes [running at your own pace](safety.md#external-events) practical: drain a queue of events into one batch instead of context-switching per event.

## Control Plane And Data Plane

Draw a clear line between the control plane (decisions, setup, coordination — executed once per batch) and the data plane (the per-item hot path).

This delineation is what buys assertion density for free. Assertions on the control plane run once per batch and cost nothing measurable, so **a high level of assertion safety costs no performance** when the planes are separated. If assertions are showing up in a profile, the boundary is in the wrong place.

## Be Explicit

Minimize dependence on the compiler doing the right thing for you.

In particular, **extract hot loops into standalone functions that take primitive arguments** rather than `self` or a struct reference. Two benefits:

1. The compiler no longer has to prove it can cache struct fields in registers — the values arrive already in registers.
2. A human reader can spot redundant computation, because everything the loop uses is in the signature.

```rust
// Prefer: the loop's inputs are all visible, and none can alias self.
fn checksum_blocks(blocks: &[u8], block_size: u32, seed: u64) -> u64 { /* ... */ }

// Over: the compiler must prove self.block_size does not change across iterations.
impl Grid {
    fn checksum_blocks(&self) -> u64 { /* ... */ }
}
```
