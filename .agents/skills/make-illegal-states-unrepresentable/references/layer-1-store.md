# Layer 1 — The Store: Questions

The store is the only layer that holds an invariant against each writer. Ask each question below about the data in the scope of the review. The stack files give the mechanisms.

Always select the least expensive mechanism that makes the illegal state impossible to write.

## Values

1. **Can a field hold a value that the domain forbids?** Examples: an amount of money that is zero, a hash with the incorrect length, an empty name, a percentage above 100. (G1)
2. **Does "absent" have more than one representation?** An empty string, an empty array and a zero must not be second representations of `NULL`. (G1)
3. **Does a field hold one value from a finite group, and does the store permit other values?** Free text also permits the spelling error, and the spelling error is not a state of the domain. (G1)
4. **Is a field optional with no named state for its absence?** If a state permits the absence, the store must represent that state with a discriminator or a timestamp. (G1)

## Records and references

5. **Must two records have the same parent, and does the store hold that agreement?** A reference shows that the target record exists. It does not show that the two records have the same tenant, user or account. (G1, G3)
6. **Does the domain permit one record in a state at a maximum, and does the store hold that count?** Examples: one open bill for each user, one active policy for each subject. (G3, G4)
7. **Does an invariant compare records with something other than "equal"?** Examples: two validity periods must not overlap, two ranges must not touch. (G3)
8. **Does the store keep a total, a count or a balance that must agree with other records?** Calculate the value instead, if this is possible. A stored total with no mechanism is a Critical finding if the total is money.

## States

9. **Does a discriminator control which fields are present, and does the store hold that rule?** The rule must also reject an unknown value of the discriminator. Then a new variant with no rule fails. (G1, G4)
10. **Is the sequence of two timestamps a rule, and does the store hold it?** A pair of timestamps with no rule becomes a negative duration later. (G1)
11. **Does the code change a state field in place, where one record for each transition is better?** A record for each transition changes an illegal transition into an illegal insert, and it keeps the history.
12. **Do two fields hold one concept?** A pair such as `state` and `state2` from an incomplete migration permits disagreement. (G1)
13. **Does one column carry more than one state of the domain?** The signs: a sentinel such as `-1` or `0` with a meaning in a comment, an empty string that means "absent", a magic timestamp such as `9999-12-31`, or a `'misc'` value in an enum. The column then cannot express one legal state, and it also permits the values between the sentinels. Give each state a name and its own representation. (G5, and usually G1 in the same column)

## Structure

14. **Can a writer supply the identifier?** An identifier that the store generates is better.
15. **Does a domain field have a default value?** A default is a decision that the store makes for the code, and it hides the error "the caller forgot this field". Technical fields such as a creation timestamp are the exception. (G2)

## Limits and migration

16. **What can this store not hold?** Each store has a limit, and an invariant above that limit is still a finding. Report four items: the invariant, the reason why this store cannot hold it, the one place above the store that holds it now, and the method that finds a violation. "A convention holds this invariant, and no person monitors it" must not remain after a review.
17. **Is the migration realistic?** Count the violations first, because the count shows if this is a change to a constraint or a project to correct data. Then add the constraint in a weak form, correct the data, and make the constraint strong. Deploy the new writer before the new constraint. Write the rollback and test it. The stack file gives the commands.
