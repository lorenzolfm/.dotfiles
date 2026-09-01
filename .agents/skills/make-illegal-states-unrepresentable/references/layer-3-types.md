# Layer 3 — The Types: Questions

Layer 3 makes an illegal state impossible to construct inside this process. The decisions about the model are the same in each language. The proof is not: some compilers check the model, and some languages check nothing.

Read the tier of the language in `stacks/other-stacks.md` first. In a tier D language the compiler proves nothing, so the store and the access layer must hold more of the model. Write this fact in the report.

## The shape of the model

1. **Does a record have optional fields that belong to one state?** Use one variant for each state, and give each variant the fields of that state only. (G1)
2. **Does a boolean have three meanings?** Also look for two booleans with a forbidden combination. (G1)
3. **Does a comment say "set only when ..."?** That comment is the type that the author did not write. (G1)
4. **Does a branch use `unreachable`, `panic("must be set")`, or a default case that hides a state?** Each one marks a state that the type permits and the code forbids. (G1)
5. **Does the same test for "not absent" repeat at many call sites?** The test belongs in the type. (G2)
6. **Does one field carry more than one state, each behind a sentinel?** A `-1` that means "no limit", an empty string that means "absent", a `0` that means "blocked", a `"misc"` variant that absorbs the states that nobody named. The model cannot express the legal state, so each reader must know the meaning of the sentinel, and a reader who does not know it compares the sentinel as an ordinary value. Give each state its own variant. (G5)

## Construction

7. **Can code construct a value without the check?** A type holds an invariant only with three properties: no public path to a value without the check, a constructor that gives a failure and not an exception that no code catches, and no method that changes the value after construction. (G2)
8. **Is the wrapper connected to the representation in the store?** Then the two layers cannot become different, and a corrupt record gives a parse error, not a valid value. (G3)
9. **Does a type for this invariant exist in the repository already?** Search the types of the repository before you propose a new type. A second type for the same invariant is a finding.
10. **Are the identifiers typed?** A typed identifier makes "this is the identifier of a different table" a static error. It is the wrapper with the highest value in a schema with many tables. (G1)

## Proof that moves with the value

11. **Does a function validate its arguments and return nothing?** The function discards the knowledge. Move the check into a constructor and change the signature. (G2)
12. **Is there a numeric conversion with no check on the range, or a floating-point number for money?** Also look for a default value in place of invalid data, and an assertion that does the work of a constraint. (G2)
13. **Does the sequence of operations matter?** Then put the state in the type, and the compiler rejects a call in the incorrect sequence. Use this pattern only where an error is expensive. On a simple flow it is a finding about complexity.
14. **Does a raw string cross an internal edge?** Parse the string into the closed type at the edge, then pass the type. Then the language can prove that the code covers each value. (G1)
15. **Does an error message carry a decision that the caller needs?** Return a sum type for a result that the caller must identify. A general error type is correct for a failure that no caller examines. (G1, G6)
