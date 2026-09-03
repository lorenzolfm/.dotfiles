# Naming Things

> "There are only two hard things in Computer Science: cache invalidation, naming things, and off-by-one errors." — Phil Karlton

**Get the nouns and verbs just right.** Great names are the essence of great code: they capture what a thing is or does and hand the reader a crisp mental model. They are evidence that you understand the domain. Take the time to find nouns and verbs that work together, so the whole is greater than the sum of its parts.

## Contents

- [Case and form](#case-and-form)
- [Units and qualifiers](#units-and-qualifiers)
- [Meaning and symmetry](#meaning-and-symmetry)
- [Call history and parameters](#call-history-and-parameters)
- [Order within a file](#order-within-a-file)
- [Names that leave the code](#names-that-leave-the-code)
- [Comments and commits](#comments-and-commits)

## Case And Form

- `snake_case` for functions, variables and file names. The underscore is the closest thing programmers have to a space; it separates words and encourages descriptive names.
- **Do not abbreviate.** The one exception is a primitive integer used as an argument to a sort function or a matrix calculation.
- Long-form flags in scripts: `--force`, not `-f`. Single-letter flags are for interactive use only.
- Proper capitalization for acronyms: `VSRState`, not `VsrState`; `HTTPClient`, not `HttpClient`.
- Otherwise follow the language's own style guide.

## Units And Qualifiers

**Put units and qualifiers last, sorted by descending significance**, so the name starts with the most significant word and ends with the least.

```
latency_ms_max      not  max_latency_ms
latency_ms_min
latency_ms_p99
```

The payoff is second-order: the related names line up in the source, and everything about latency groups together alphabetically. This is "big-endian naming", and it is why alphabetical sorting is a reasonable tiebreak elsewhere.

## Meaning And Symmetry

**Infuse names with meaning.** `allocator: Allocator` is fine but boring. `gpa: Allocator` and `arena: Allocator` are excellent — they tell the reader whether cleanup must be called explicitly.

**Match character counts on related names.** As arguments to a copy function, `source` and `target` beat `src` and `dest`, because the derived names line up:

```
source_offset  target_offset
source_len     target_len
```

Equal-width names produce clean blocks in calculations and slices — symmetrical code that the eye parses and the reader checks quickly.

**Never overload a name with a second, context-dependent meaning.** TigerBeetle's *pending transfers* were first called *two-phase commit transfers*, which collided with the consensus protocol's *two-phase commit*. Two meanings, one term, permanent confusion.

## Call History And Parameters

- **Prefix a helper with the name of its caller** to show the call history: `read_sector()` and `read_sector_callback()`.
- **Callbacks go last** in the parameter list. This mirrors control flow — a callback is also *invoked* last.
- **Use named arguments when arguments can be mixed up.** A function taking two integers of the same type must use an options struct. If an argument can be null/`None`, name it so the meaning of a bare `null` at the call site is clear.
- **Thread singleton dependencies positionally** — an allocator, a tracer, a clock — from most general to most specific. They have unique types, so they cannot be mixed up.

## Order Within A File

Order matters for readability even when it does not affect semantics. A file is read top-down on the first pass, so put important things near the top. **`main` goes first.**

Within a type: **fields, then types, then methods.**

```rust
pub struct Tracer {
    time: Time,
    process_id: ProcessId,
}

struct ProcessId { cluster: u128, replica: u8 }   // Types section.

impl Tracer {
    pub fn init(gpa: &Allocator, time: Time) -> Tracer { /* ... */ }
}
```

If a nested type is complex, promote it to a top-level type. Not everything has a single right order — when in doubt, sort alphabetically and let big-endian naming do the grouping.

## Names That Leave The Code

Think about how a name will be used *outside* the code — in documentation, a design doc, a conversation.

**A noun is usually a better descriptor than an adjective or present participle**, because a noun can be used directly in prose without rephrasing. Compare `replica.pipeline` with `replica.preparing`: the first works as a section header; the second must be explained first. Nouns also compose more cleanly into derived identifiers, e.g. `config.pipeline_max`.

## Comments And Commits

- **Always say why.** Code alone is not documentation. Comments explain why you wrote it this way. Show your workings.
- **Always say how.** A test deserves a description at the top stating its goal and methodology, so a reader can get up to speed — or skip the section — without diving in.
- **Comments are sentences**: a space after the marker, a capital letter, and a full stop — or a colon when they introduce what follows. They are well-written prose about the code, not scribbles in the margin. A comment at the end of a line may be a phrase with no punctuation.
- **Write descriptive commit messages** that inform and delight, because they are read. A pull request description is not stored in the git repository and is invisible in `git blame`, so it is not a replacement for a commit message.
