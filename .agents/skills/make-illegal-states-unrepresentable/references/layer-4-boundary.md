# Layer 4 — The Boundary: Questions

Each value that crosses the edge of the process: RPC and HTTP payloads, queue messages, webhook bodies, command-line arguments, environment variables, configuration files and third-party responses.

The edge is the widest and the weakest layer. It holds no invariant alone. Its only function is to parse each value into layer 3, one time, at the edge. `stacks/other-stacks.md` gives the mechanisms for each format.

## The three questions for each field

Ask them in requests, responses and messages:

1. **Presence.** Can the code identify the difference between "absent", "empty" and "zero"? A required amount that arrives as `0`, or a required name that arrives as `""`, must give an error. The code must not use a default value. (G1)
2. **Closed sets.** Does the format send a finite group of values as a closed type? Does the handler reject the unknown value and the default value, instead of giving it a meaning? (G1)
3. **Shape.** Can the payload hold a combination that the domain cannot produce? Then which code must identify the combination that arrived? A payload of optional fields, where "one combination is always present", moves the invariant to each client. (G1, G6)

## The parse step

4. **Does the handler parse each value into a domain type, one time, at the edge?** Each function behind the handler must then take domain types. (G2)
5. **Does a signature behind the handler still hold a raw string, a wide number or an optional value for something that the domain limits?** Then the code did not parse the value, or it discarded the result. (G6)
6. **Does each rejection name the field that failed?**

## The shape of the payload

7. **Does each sum type of the domain have a sum type in the payload?** Each other shape makes the model wide again. This applies to a response with the same force as to a request. (G6)
8. **Does money cross the boundary as a floating-point number?** Use an integer of the smallest unit, or a string. An integer above 2^53 must also be a string. This is a Critical finding.
9. **Did a person decide about the unknown fields?** This boundary must reject them or ignore them. Rejection is safer for an internal API, and "ignore" is necessary for compatibility with a new client. No decision is the finding.
10. **Does a queue payload have a version and an idempotency key?** Production holds old messages, in the queue and in the replay data. The queue also sends a message more than one time.
11. **Does a response type of a third party move into the domain?** Parse each response into your own types in the client wrapper. Their schema is not your schema, and their promises are not a mechanism. (G6)

## A change to an existing boundary

12. **Does an old client depend on a shape that permits the illegal state?** Then propose an addition: add the sum type beside the old fields, and remove the old fields later. This is usually the only proposal that a team can deploy for a public boundary, a mobile client or a partner. Give the sequence of steps for the clients.
