# Verbatim examples

These are real comments by Lorenzo, copied as posted. Typos are kept as written. Copy the shape of these comments, not the typos. `[...]` marks a cut. Handles, commits, links and names that would point to a project are replaced with placeholders such as `@a`, `<sha>` and `<issue link>`.

Contents: one-line questions · renames and direct asks · repeats · explaining · code suggestions · scope and PR hygiene · review bodies · replies on own PRs · disagreeing · pings · Portuguese

## One-line questions

- first?
- read?
- filter snapshot_at is not null?
- should `Ok(None)` be handled?
- can user have more than one unused?
- make a separate one for admin?
- do we need two db transactions
- should we avoid dangling internal_transfers?
- Will this be backfilled?
- is this clippy?
- why the behavior change?
- redundant if Option<T>?
- equals, or is greater than?
- log::debug at least?
- maybe dumb question, but why is id hardcoded to zero?
- what if the request fails? should you reactivate here as well?
- converted_at is nullable, right? its set when the money is given to the user afaik
- wonder if this shouldn't be coming from current_user_addresses

## Renames and direct asks

- list_for_admin?
- cancel_transaction_id
- nonneg_smallint?
- with_capacity
- use the consts luke
- no expect pls
- prefix index with table name pls
- nit: name check
- nit: can we avoid aliasing `Version`? makes grep more tricky
- i would avoid comments like these
- do you mind turning this into a outcome as well?
- this logic is getting a little outta hand. is it simplifiable?
- call this active instead of unsubscribed. Fill with created_at on creation

> this is not the way to do computed columns
>
> you should use generated. see examples in other migrations

## Repeats

- same
- same as above
- same on renames here

## Explaining

> I think log::error is not necessary here, as this will probably be triggered by typos on the input 99% of the time

> wont this trigger a lot of notifications when:
>
> 1) user turns notifications off
> 2) user buys lots of stuff
> 3) user turns notifications back on
>
> ?

> Using random in a function named parse is very weird for me. I would rename this to `parse_and_resolve_dns`

> I think you can just put the value here, will make test easier to comprehend for smol brains like mine

> Should we avoid catch all so that a new variant is silently handled as new?
>
> Avoiding catch all forces all matches to handle every variant explicitly. I find it useful to avoid introducing errors

> btw, I was taking a look at bitcoin core impl and they randomize before returning to difficult eclipsing a node. Maybe its worth to shuffle the results here as well 🤔

> I think this is a bit overkill. You're testing serde, not our code. Maybe you should do something more end-to-end.

> Yes, but you already called `accept_header` above, which _could_ reorg the chain, right? If you return,we throw away the rest of the message. Which is exactly what makes the fork win. So with the return we accept one fork header per headers message. A N block fork needs N messages instead of 1. And once the reorg happen in the middle of the loop, the headers after it do extend the tip, so we do want their blocks.

> Imagine a scenario were we're still in `Syncing` and some peer sends us an empty headers message.
>
> We switch to `Waiting(Instant::now())`, and 60s later the timeout calls `finish_sync`. Will we have the header for the checkpoint block by then? If not, won't the node skip the `mark_checkpoint` call?

> I question myself about the usefulness of some tests here. They don't test much logic, it's more like asserting that we wont change the "API". And I say in quotes because choosing how to *display* an error is != choosing which error gets *returned*.
>
> Also, we've need to keep in mind that each line of code in the project increases compile time for a tiny bit. This is bad specially for Rust, which is known for its slow compile time.
>
> Given the above, I would be totally fine with **not** having tests for this code specifically or at least come up with a test that provides more value than those.

## Code suggestions

> This is swallowing deserialization error, maybe you would like to do something like
>
> `.map_err(|e| InvalidParameterType(format!("{field_name}: {e}")))` to avoid it?

> How do you feel about being defensive against underflow?
>
> ```
> let elapsed_validated = validated_block_time.saturating_sub(genesis_time);
> let elapsed_total = now.max(header_tip_time).saturating_sub(genesis_time);
> ```
>
> Or even `checked_sub`?
>
> I think underflow is impossible on mainnet, but maybe some weird scenarios on regtest can trigger it.

> "Exacly one of Result or Error will be some" sounds like a perfect fit for an enum. You can play around with serde to serialize to what you need.
>
> Maybe something like
>
> ```
> [...]
> ```

> take already handles the case where `count > address length` so the above `if/else` is redundant.
>
> You can simply do something like
>
> ```rust
> let count = if count == 0 { usize::MAX } else { count as usize };
> ```
>
> and let take handle the case where `count > address lenght`

## Scope and PR hygiene

> Adding all that in this PR is a little disruptive IMO. I would proceed without it and open a separate PR for it, or keep only the nix package-ecosystem for now

> i think you should avoid arbitrary renames. It makes your PR easier to review :)

> While I do agree on the majority of denies added here I question if this is the correct commit (or even PR) to include this.

> Addressed some comments. By the way there are still some renames on variable names that I think you should avoid doing. The smaller the diff, the higher the quality of reviews you'll get :)

## Review bodies

Approvals have an empty body. Bodies of comment and request-changes reviews:

- some comments
- Minor stuff only
- call me for qa when able
- can you write a test?
- lets think on how to migrate
- but does it compile?

> Can we only add the new API in this PR?
>
> I'm not sure I agree with the extra outcomes added and renames on the other APIs. We can discuss this separately.

> This is a big, complex and scary PR. I wonder if its worth splitting into smaller chunks so reviewing is easier.
>
> Also, would be cool to have some sort of guarantee that both runtimes end up with users in the same state.

Repos that follow Bitcoin Core's ACK convention (always a COMMENT review, never APPROVE):

- ACK <full head sha>
- another round :)

> utACK <full head sha>
>
> I'm not a shguy myself btw

> This PR looks to move the project in the wanted direction.
>
> I think my comment on using untagged enum instead of struct might be worth taking a look at. But not a dealbreaker
>
> ACK <full head sha>

> Hi @x. Thanks for your work on this. Your PR is going on the right direction :)
>
> I've made some comments about simplifying the `Internal` variant, the value of some tests you added and notes about some changes that you may want to avoid to keep this PR on track with your goal and keep it easy for contributors to review.

> Some comments. Sorry to rehash this again, but I think at least the double locking is worth to avoid.
>
> Btw, I think you also need to change the formula here: doc/rpc/<method>.md

## Replies on own PRs

- Done in <sha>
- Fixed in <full sha>
- fixed on amend
- Here you go <sha>
- Good point, @x. Checkout the new commit :)
- you're correct
- Sounds good!
- Dumb move by me
- Not at all, my mistake. `<commit link>`
- changed my mind, hehe. take a look into `<commit link>`
- Looked at other tables and your suggestions seems more standard `<commit link>`

> Nice catch
>
> <sha>

## Disagreeing

> But removing it makes the test pass if schema changes. I think its not worth dropping it

> Would like to, but it would require shenanigans to convert from `VendorDateTime`

> You're correct in the sense that this will slow the webhook reply. But since this is not a critical webhook that we have to reply in X secs "or else..." I think we're good with this code for the moment.

> I like the validation but I think Its kinda outta scope for this PR. My initial intent was just removing unsafe casting and arithmetic operations. But I would love to do this in a subsequent PR

> Proper error handling clicks for me, but there's no error variant available that semantically maps to what's happening here.
>
> [...]
>
> If I had to choose I'd go with parsing count as `u16` from the get go, to avoid adding another error variant to map internal errors.

> I'm okay with either approach tbh.
>
> [...]
>
> OnceLock will make running tests that depend on wallet config more difficult, tho

> That's a good question, @x. I've first approached this change exactly like you've described. After talking with @a and @b I've came to the conclusion that this might be not be the best approach because our fee modeling is for users and mixing concepts might not be good.
>
> I think the optional reads like: "this concept does not apply here", which is different from saying "there's fee for us and it charges 0%"

## Pings and housekeeping

- :eyes: @a @b @c
- @a addressed all comments. Can you :eyes: ?
- cc @x
- CI failed but it seems like non related to this PR. Can someone rerun the failed job for me?
- Did you picked this up after all, @x? I can review the PR if its still open

> Closing this after discussing with @a the best path forward for bringing safe arithmetic to the project :)
>
> See <issue link> for details

## Portuguese (when the thread is in Portuguese)

> vc pode so escrever
> `base_fee DOUBLE PRECISION` tbm

> a api deles realmente fica misturando lowercase, camelCase e snake_case sera que isso nao eh um camelCase de uma palavra so :thinking:
>
> levantando o ponto pq pode quebrar a deserializacao se surgir um camelCase ai

> do jeito que ta modelado hoje a unica maneira de apelar seria fazendo requisicao pro suporte. Talvez algo relacionado essa cta? "Entre em contato com o suporte pra reavaliar"
>
> Talvez valha ate botar um reject reason na tabela :eyes:

> nao, por causa do lock que pega no inicio da funcao

> well, its already not null. viajei

> Essa eh uma boa pergunta. Eu concordo com voce que semanticamente parece mais razoavel um erro mapear pra outro.
>
> Dito isso, ela ficou assim pelos seguintes motivos:
>
> 1) Eu acho okay falar que dentro do nosso sistema certas coisas sao okay enquanto pros clients eh um erro. [...]
