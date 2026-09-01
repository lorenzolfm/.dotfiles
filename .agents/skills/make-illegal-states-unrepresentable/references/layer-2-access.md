# Layer 2 — The Access Layer: Questions

Each path that reads or writes the store: query functions, repository methods, ORM calls, client calls and transaction blocks. Layer 1 controls which states exist. Layer 2 controls which transitions occur.

`stacks/other-stacks.md` has the table of conditional writes for each family of store.

## Writes

1. **Is the condition of the transition in the write?** A write that sets a state field with no condition on the current state permits each transition, and also a transition backwards and a second completion. (G4)
2. **Does the caller read the count of the records that the write changed?** A write that changed no record is a lost transition, and a caller that ignores the count reports a success. Propose a function for "exactly one record" if the repository has none. (G4)
3. **Does a write set each field after a read?** A write such as `save(entity)` also writes the fields that this code path did not intend to change. It removes the changes of a concurrent writer.
4. **Does the code read the store and then write it?** Two statements use two views of the data, so a second writer can act between them. This applies to a read for uniqueness, a read of a balance before a subtraction, and "if no open record exists, create one". (G3, G4)
5. **Does a record that more than one function changes have a version?** Write with `WHERE version = ?` and increase the version. A count of zero means that a different writer was first, and the caller must read the record again. (G4)

## Transactions

6. **Is one legal change one transaction?** If related writes use more than one transaction, and a part of the change is illegal alone, name the intermediate state that a reader can see. (G4)
7. **Does an external effect run inside a transaction?** An HTTP call, a message to a queue or an email can occur, and then the transaction can roll back. Move the effect after the commit and make it idempotent. Or write a record in the same transaction and send the message from that record.
8. **Can the caller repeat a request, and does an idempotency key exist?** A repeated request must give the same state, not a second state. Put the key in the store with a unique constraint.
9. **Does this store have transactions across records?** If it does not, one record must be the unit of legal change. That change to the model is the finding.

## Reads

10. **Does a read give more data than the caller needs?** A read of a full record, where the caller uses three fields, makes the type wide again. (G6)
11. **Does a read remove the invalid records quietly?** Count them, write them to the log, or give an error. A filter hides the illegal states that the store holds now.
12. **Must each caller do the same check after a read?** Then one query function or one type is absent.
13. **Can the caller identify the result?** If the caller must examine the text of an error, or if a boolean hides the reason, the function needs a sum type. Refer to `layer-3-types.md`. (G1, G6)
