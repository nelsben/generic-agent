# Agent review: Account_Brief Agent Script, test spec and publish workflow (OPS-13)

Reviewed 2026-11-11. Lane: `Account_Brief.agent` and `Account_Brief.bundle-meta.xml` on `main` and on
`agent/backend/BE-8` (8a8afb6), `tests/agent/Account_Brief-testSpec.yaml` on both, `tests/test_agent_bundle.py`,
`scripts/validate-org.sh`, and the three invocable classes (read for the contract). On the lane files, `main`
matches the BE-8 merge base, so the BE-8 diff is the candidate next version. Standard: the installed
`agentforce-adlc` 0.14.0 skills `agentforce-generate` (audit references, core language, known issues),
`agentforce-test`, and `agentforce-architecture-analyze` (could not run, see the end).

## Summary

Verdict: **sound with fixes.** The structure is sound and clean for publish. Both versions compile, and the org
validates both. All three actions have `outputs:`. The resolve-then-brief gate binds the Id from state, so the
model cannot pass an Id of its own choosing. BE-8 is a real improvement over main on routing and relay. The defects
are in what happens after the first turn. Once an account is briefed, every Explore question carries that account
as the open record, so an org-wide count can come back scoped to one account. Neither subagent has a route out. A
null Id from a failed resolve probably passes the `!= ""` gate. BE-8's relay rule lists RESOLVED, which invites a
reply of just "Resolved: <name>". The spec has no multi-turn or AMBIGUOUS case. **BE-8 is not ready to publish as
is.** Fix findings 1 and 2, add the missing cases, then follow the skill lifecycle: preview every branch before
publishing. Nothing was previewed or run live. Every behavioural claim below rests on reading alone, and each one
says so.

## Checks run (read-only)

- Local compile (Rule 14): `index-agent.mjs` with SDK `@sf-agentscript/agentforce` 2.9.27 (npm provider, installed
  into a scratch cache). Main and BE-8 give no errors and the same two severity-2 diagnostics:
  `type-mismatch: input 'contextRecordId' expects 'id' but got 'string'` (main 135, BE-8 140) and
  `deprecated-field: 'id' is deprecated: Use string instead.` (main 146, BE-8 151).
- `sf agent validate authoring-bundle --json --api-name Account_Brief -o experimental`, from the OPS-13 worktree
  (main) and then the BE-8 worktree. Both return `{"status": 0, "result": {"success": true}, "warnings": []}`.
- Bundle shape (generate Rule 15): the directory and both files are named `Account_Brief`, and the meta is
  `<bundleType>AGENT</bundleType>` with no `<target>`. Correct.

## Findings (most severe first)

**1. After a brief, Explore scopes org-wide questions to the briefed account.** Blocker for BE-8; should-fix on
main. Verified code path; the model step is suspected. New.
- Where: `Account_Brief.agent` main 122-136, BE-8 127-141. The cause is
  `staticresources/AgentPrompt_Explore.resource` rule 8: "Use [the open record] when the question ... names nothing else."
- What: once `briefed_account_id` is set, `explore_data` is withdrawn (`available when ... == ""`). Only
  `explore_data_for_account` remains, and it always binds the account as `contextRecordId`. Nothing clears the Id.
- Scenario: briefed on account A, the user asks "How many open opportunities are there?". BE-8 sends this to
  explore because it names no account. The explorer gets A as the open record and, by rule 8, counts A's
  opportunities. The user sees that count as an org-wide fact.
- Skill: generate, action-and-state diagnostics ("availability is broader than the use case", "request-scoped state
  leaks into a later request").
- Fix: keep `explore_data` always available and offer `explore_data_for_account` only for questions that refer to the
  briefed account ("this account", "its"). Or drop the binding: under BE-8, account questions go to account_brief.

**2. BE-8 tells the model the resolve message is the whole reply, even on RESOLVED.** Should-fix. Verified conflict
in the text; the outcome is suspected. New (BE-8 only).
- Where: BE-8 line 59, step 6: "Your whole reply is the action's message or answer text ... for every status:
  RESOLVED, AMBIGUOUS, NOT_FOUND ...". Step 3 (line 56) says to call get_brief. The RESOLVED message is
  `Resolved: <Name>` (`AccountBriefResolver.cls` 122), and that output is `is_displayable: True`.
- Scenario: "Give me a brief on <account>". resolve_account returns RESOLVED; the model follows step 6 literally and
  replies "Resolved: <account>" with no brief. That is the main path.
- Skill: generate, instruction diagnostics ("global and local instructions demand incompatible outcomes"; "give each
  reachable branch one next outcome").
- Fix: remove RESOLVED from step 6 and say "on RESOLVED, call get_brief and relay its answer". Consider making the
  RESOLVED message not displayable (`filter_from_agent` or `is_displayable: False`).

**3. No route out of a subagent, and no route for a reply to a candidate list.** Should-fix. Suspected: the skill
does not say whether a new turn re-enters `start_agent`. New.
- Where: main 42-136, BE-8 47-141. Neither subagent has a transition. The router (BE-8 31-45) has no rule for "the
  second one" or "the Seattle one".
- The skill's `assets/agents/router-first.agent` gives every subagent a `reclassify` transition to `agent_router`, and
  architecture-patterns says to add one "when the conversation needs reclassification". Both imply the conversation
  stays in the current subagent between turns.
- If the conversation stays: after a brief, "How many open opportunities are there?" or "What is the weather?" lands
  in account_brief, which has no explore action and no refusal duty, so it answers from memory or calls get_brief.
  In explore, "brief me on A" cannot reach the resolver. BE-8's router hint at line 39 never fires.
- If the router runs every turn: after AMBIGUOUS the Id is blank (finding 4), so "the Seattle one" matches no router
  rule and may get the off-topic line.
- Skill: generate, action-and-state diagnostics (transitions: "a flow cannot return or exit when supported use cases
  require it"), and architecture-patterns.
- Fix: add `reclassify: @utils.transition to @subagent.agent_router` to both subagents, and a router rule that a reply
  picking from a candidate list goes to account_brief. One preview session decides which case holds: a brief, then
  an org-wide count, then read the trace.

**4. A null Id from a failed resolve probably passes the `!= ""` gate.** Should-fix. Suspected (the runtime's null
semantics are not documented). New.
- Where: main 63-69 / BE-8 68-74 set `briefed_account_id = @outputs.accountId` unconditionally and gate on `!= ""`.
  The resolver leaves `accountId`/`accountName` null on AMBIGUOUS and NOT_FOUND (`AccountBriefResolver.cls` 126-153).
- If null is stored as None, `None != ""` is true. get_brief becomes available with no Id, and `AccountBrief.run`
  line 161 returns "I can't see that account. Check the name or your access." The router and explore hints render
  with a blank name, and explore binds a null open record. If null becomes `""`, the gate holds. Core-language
  section 4 documents `is None`, which suggests None is a distinct value.
- Skill: generate, action-and-state diagnostics ("a branch depends on an accidental default").
- Fix: store the resolve status in its own variable, set only by resolve_account, and gate get_brief on
  `== "RESOLVED"`. That also gives `last_status` (nit 9) a consumer. Or gate on `is not None and != ""`.

**5. The global "every answer comes from an action" rule contradicts the router's own reply.** Should-fix.
Suspected. New.
- Where: main line 2 ("Every answer comes from an action."), BE-8 line 2 ("... from an action in the current
  turn"), against the off-topic line the router must write itself (main 35, BE-8 36).
- Scenario: "What is the weather in Paris today?". To obey the system rule, the model picks a transition (its only
  tools), so explore runs the question through the explorer and relays the result instead of the one-line refusal.
- Skill: generate, instruction resolution ("global and local instructions demand incompatible outcomes").
- Fix: add to `system.instructions` "except the fixed one-line reply for requests outside account briefs and CRM data".

**6. A brief on the wrong account is stopped only by prose.** Should-fix. Suspected. New.
- Where: main 66-72 / BE-8 71-77. get_brief stays available with the previous Id; only "A different account name
  must go through resolve_account first" stops it. BE-8 step 4 ("every reply needs a get_brief call in this turn")
  pushes the model toward calling it.
- Scenario: briefed on A, the user says "and B?". The model calls get_brief(A, "and B?"), and the reply describes A
  as though it answered about B.
- Skill: generate, posture-and-determinism / Rule 13 (a stable consequence that rests on model judgement).
- Fix: cover it with a preview case and a multi-turn spec case. The semantic call has to stay with the model; the
  brief names its account in its first line, which limits the harm.

**7. The test spec misses branches and cannot assert negatives.** Should-fix. Verified. New; plan §1d covers only
a manual two-turn check.
- No AMBIGUOUS case: every resolver branch except AMBIGUOUS is exercised. No multi-turn case, though
  `agentforce-test` `references/batch-testing.md` supports `conversationHistory` and the BE-8 card asked for one.
- `explore_data_for_account` is never reached, and no case follows a brief with an org-wide question (finding 1).
  A pronoun follow-up and a list pick are missing too.
- Suspected: a `conversationHistory` case cannot open the get_brief gate, because history does not set variables.
  A follow-up test therefore needs a live two-turn preview, not only the spec.
- `expectedActions` uses superset matching (batch-testing.md "Key Rules"). The off-topic `[]` and the not-found
  `[resolve_account]` can never fail on an extra call; only the LLM judge catches it. Say "calls no other action"
  in `expectedOutcome`.
- The fake-Id case (`001000000000000AAA`) can only come back NOT_FOUND, yet its outcome accepts "a brief or says no
  account matches". Make it say NOT_FOUND. The RESOLVED-by-Id path needs an org-specific Id; leave it to preview.
- Main still uses "Acme Corp", which does not exist in the org; BE-8 fixes that. BE-8's
  `expectedTopic: topic_selector` differs from the skill's advice to omit `expectedTopic` on guardrail cases. It is
  grounded in what the org reported, so keep it, but re-check it after each publish (batch-testing.md "Topic hash drift").

**8. The repo workflow skips the skill's lifecycle.** Should-fix. Verified. Already planned (plan rule 1, §1a, and
the §3 workflow card).
- `scripts/validate-org.sh` 39-43 runs a check-only deploy of all of `force-app`, bundle included. It has no local
  compile, no `sf agent validate`, and no preview. Lines 40 and 43 discard stderr (`2>/dev/null`), against generate Rule 1.
- The BE-8 card's own loop was publish, activate, then `sf agent test run`. The skill says the opposite: draft-first,
  preview every branch, approval, then publish (generate Rules 5-6 and "Deploy, Publish, and Activate").
  `sf agent test run` works only on an activated agent, so the spec cannot gate a candidate before publish; only
  preview can.
- The `sf` first on PATH in this shell is 2.130.9, below `agentforce-test`'s 2.131.0 floor for `--simulate-actions`
  and missing `org auth show-access-token`. The research doc records 2.157.8, so there are two CLIs, and the
  workflow card should pin which one runs.

**Nits** (verified unless noted; all new):
9. `last_status` has four writers and no reader (main 18, 63/72/130/136). It is state with no consumer (generate
   Rule 7). Use it as in finding 4 or delete it.
10. `contextRecordId: id` (main 146) gives the two compiler diagnostics. Declare it `string`; the Apex field can stay `Id`.
11. Step 1 (main 49, BE-8 54) says "Pass the user's words ... character for character". Suspected: a literal reading
   passes the whole request, so "Brief me on Edge Communications" gives NOT_FOUND (a pasted Id still works, since the
   resolver regex finds it). Say "the account name as written, without the rest of the request".
12. The resolver's NOT_FOUND texts say "open the account and ask again" (`AccountBriefResolver.cls` 144, 151), but
   the script never binds `knownAccountId`, so opening the record changes nothing. Reword the text, or bind a record
   context if the employee surface offers one (the skill names no such variable).
13. BE-8's new unit tests (`tests/test_agent_bundle.py` BE-8 55-63) check that phrases are present, not behaviour;
   `assertIn("userQuestion", ...)` passes from the action definition alone. Fine as tripwires, not as evidence.
14. Spec location: `agentforce-test` names `tests/<Agent>-testing-center.yaml`, while
   `docs/research/salesforce-skills.md` (gap 6) cites `specs/<Agent>-testSpec.yaml` from the generate docs. Neither
   is enforced. `tests/agent/` keeps `AiEvaluationDefinition` out of `force-app`, as known-issue 1 asks. No move is
   needed; plan §3's "if the skill requires it" can be closed.

## "Internal Error" on publish: the skill's four causes, checked

1. Access user: Employee agent, no `access:` block, which is correct for that type. Clean.
2. Missing `outputs:` (known-issue 15): all three definitions have one (main 82, 105, 149). Clean.
3. Structural drift: main is the script that published as v1, and BE-8 adds only prose and one `if` in the router.
   Both validate. No drift found.
4. Transient: not tested.

The recorded failure was not this error anyway: it was a 404 on the versions endpoint, plus "Error saving or
updating agent graph" on replay (`docs/research/agent-publish-failure.md`). Nothing in the script explains it.
Plan §1c can be marked checked from the script side.

## Deliberate differences

- Status strings instead of isSuccess/errorMessage (`platform-apex-generate`). I agree with keeping them: they are
  typed outputs, and relaying the status verbatim fits this agent better. The weak spot is that the model, not the
  runtime, branches on status; finding 4's status gate moves the one branch that matters into the runtime.
- Apex only, no Flows, and no prompt-template actions. The skill supports both but requires neither. No conflict.
- Generate Rule 7 prefers one `start_agent` block and no mutable state. That is not a recorded choice, but the design
  passes the skill's own test: two domains with different actions, and an Id with a deterministic consumer
  (`available when` plus binding).

## Is BE-8 safe to publish as the next version?

Not yet. It is better than main on routing (named-account asks), on relay wording, and on its spec account. Before
it publishes:
1. Fix findings 1 and 2, add the reclassify transitions (3), the gate change (4) and the system-line exception (5).
2. Add an AMBIGUOUS case, and a follow-up preview: a brief, then a pronoun, then an org-wide count.
3. Preview every branch and read the traces before publishing (plan §1a). Verbatim relay is still prose only; the
   OPS-6 probe saw the model rewrite, so judge it from preview output.

## What rests on reading alone, and what was not reviewed

- Reading alone: every routing, relay and state outcome above (1-7, 11), and the null semantics (4). Run: the
  compile, the org validate, and the bundle-shape check.
- Not run: preview, publish, activate, `sf agent test create/run` (out of scope).
- `agentforce-architecture-analyze` did not run. It needs PyYAML, which I put in a scratch venv; it then stopped with
  `STATUS=AUTH_REQUIRED` because sf 2.130.9 lacks `org auth show-access-token`. Updating the CLI is the owner's call.
- Not reviewed: `AccountBrief` internals, the sections, `DataExplorer` (only prompt rule 8 was read), the prompts,
  the LWC and the permission sets (other lanes); the published v1 in the org (the OPS-9 retrieve found it
  byte-identical to main); and the `agentforce-test` security suite.
