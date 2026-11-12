# Agent re-review: Account_Brief agent script, test spec and release lifecycle (OPS-18)

Reviewed 2026-11-11 on `main` at f412df9. Files read in full: `Account_Brief.agent` (sha256 prefix `fb0fc27d`),
`Account_Brief.bundle-meta.xml`, `tests/agent/Account_Brief-testSpec.yaml`, `scripts/agent-check.sh`,
`docs/research/studio-preview.md`, `docs/research/agent-publish-failure.md`, plus `docs/research/agent-publish-spike.md`
(the newest release evidence), `tests/test_agent_bundle.py`, the two permission sets and the three invocable classes.
Earlier review: `docs/reviews/agent-review.md` (OPS-13). Standard: `agentforce-adlc` 0.14.0, skills `agentforce-generate`
and `agentforce-test`. Skill paths below are relative to `~/.claude/plugins/cache/salesforce/agentforce-adlc/0.14.0/skills/`.
Labels: **read** (seen in a file), **preview** (seen in `studio-preview.md`), **suspected** (inference, not run).

## Verdict

**Not ready.** The script on main is close: on its own it would be ready once the fixes below are made. But the
release lifecycle cannot ship it, so none of it is in front of users yet. The script on main fixes the serious problems the first review found. An org-wide question after a brief is no longer
narrowed to that account. The brief no longer stops at "Resolved: ...". Each part of the agent can hand a question back
to the router, and a failed lookup no longer leaves a stale account behind. A live Studio preview of these exact bytes
passed all 12 test cases. But the version users talk to today is still version 1. That is the older script the first
review criticised. Every attempt to publish a new version from the command line fails on the Salesforce side with
"Error saving or updating agent graph". Studio's Commit Version also fails, but whether for the same reason is not
confirmed. The 12-case test suite has never run against this script as a test
run. Only the preview has. No one has used the agent as an ordinary sales rep instead of an administrator, and no real
MCP call has been made. Before release, fix the explore follow-up and permission gaps below, unblock publishing, then
follow the ship order at the end.

## Checks run (read-only)

- `bash scripts/agent-check.sh` today: local compile with `@sf-agentscript/agentforce` 2.9.27 (npm), **0 diagnostics**
  (the first review saw 2). Then `sf agent validate authoring-bundle` on `experimental`: **pass**.
- Bundle shape (generate SKILL.md Rule 15): the directory and both files are named `Account_Brief`. The meta file is
  `<bundleType>AGENT</bundleType>` with no `<target>`. Correct.
- `python3 -m unittest discover -s tests`: green (the gate for this card).
- Not run: preview, publish, activate, `sf agent test`. Live actions write brief memory rows, so they are not read-only.
- Order of landing (read, git log): the OPS-15 Studio preview merged before BE-13 (date filters) and BE-14 (explorer
  column labels). The script hash is unchanged since then, but the explorer Apex behind it is not what was previewed.

## Earlier findings: status on main

"Fixed" means fixed in the file on main. **No fix is live**: the active version is v1 (`agent-publish-spike.md:14-15,112-114`).

| # | Earlier finding | Status | What decides it |
|---|---|---|---|
| 1 | After a brief, Explore scopes org-wide questions to the briefed account | fixed | `.agent:142-146`: explore_data runs with the question only. There is no `contextRecordId`, and the model cannot call the action. Router rule 1 and the hint come first (`.agent:36,44`). Preview case 9 passed (`studio-preview.md:30`) |
| 2 | On RESOLVED the reply is the resolver's message | fixed | `.agent:61-62` and the system line `.agent:2` ("RESOLVED is not a final answer"). Preview case 1 passed |
| 3 | No route out of a subagent, and no route for a candidate pick | fixed | `reclassify` in both subagents (`.agent:90-91,162-163`). Router rule 3 handles a pick (`.agent:38`). The preview shows the router is re-entered every turn (`studio-preview.md:48`), so reclassify only matters within one turn. The pick path was never previewed (row 7) |
| 4 | A null Id from a failed resolve passes the `!= ""` gate | fixed | The gate is `is not None and != ""` (`.agent:43,67,86`). The id and name are set unconditionally (`.agent:82-83`). Preview case 8 is consistent (`studio-preview.md:29`) |
| 5 | "Every answer comes from an action" contradicts the off-topic line | fixed | The exception is in `.agent:2`. Preview case 12 passed |
| 6 | A brief on the wrong account is stopped only by prose | open | `.agent:70` is still instruction text. The gate at `.agent:86` cannot tell which account is meant. Preview case 8 and spec `:62-77` name a second account after a brief, but one that does not resolve. Untested: a second account that resolves, where get_brief could fire on the old Id |
| 7 | The spec misses branches and cannot assert negatives | changed | Added: AMBIGUOUS (spec `:40-44`), three history cases (`:51-88`), a single-outcome fake-Id case (`:35-39`), and "calls no other action" (`:34,39,44`). Still missing: a list pick, RESOLVED by pasted Id, and a second account that resolves after a brief. `expectedTopic: topic_selector` stays on the off-topic case (`:100`), against `agentforce-test/references/batch-testing.md:84` |
| 8 | The repo workflow skips the skill lifecycle | changed | `agent-check.sh` adds the local compile and org validate with the CLI pinned and stderr kept (`:8-9,17,36,71`). `validate-org.sh` no longer deploys bundles (`test_agent_bundle.py:426-443`). The exact bytes were previewed. Still open: the spec never ran as a test run, and publish is blocked |
| 9 | `last_status` has writers and no reader | fixed | Removed (`test_agent_bundle.py:131-132`) |
| 10 | `contextRecordId: id` gives compiler diagnostics | changed | Now `object` with `lightning__recordIdType` (`.agent:173-178`), because Studio rejected `string` and `id`. This is not the fix proposed. Compile shows 0 warnings |
| 11 | "Character for character" makes the model pass the whole request | fixed | The script says "without the rest of the request" (`.agent:59,99`). The Apex label at `AccountBriefResolver.cls:23` still says "character for character". The script's text should be what the model sees (suspected) |
| 12 | NOT_FOUND says "open the account and ask again", but `knownAccountId` is unbound | open | `AccountBriefResolver.cls:215,222`. Unbound in `.agent:97-100`. It is Studio's one warning (`studio-preview.md:12`) |
| 13 | The unit tests check phrases, not behaviour | changed | `test_agent_bundle.py:32-110` parses blocks by indentation and asserts where each action sits (`:138-296`). This is good structure evidence, still static |
| 14 | Spec location | fixed (closed, no move) | Still `tests/agent/Account_Brief-testSpec.yaml:13-16`, outside `force-app` (known-issues.md Issue 1) |

The skill's four "Internal Error" causes are still clean: there is no `access:` block (correct for an Employee agent),
`outputs:` is present on all three actions (`.agent:101,124,179`), validate passes, and the CLI publish failure is now
captured as a server 401, not a script error (`agent-publish-spike.md:16-18`). Studio's commit failure was seen only as
a toast, so its cause is unconfirmed (`agent-publish-spike.md:38,68,83`).

## New findings (most severe first)

**N1. Users still run version 1, the pre-fix script, and no version can be published.** Blocker for release. Read.
- Where: `agent-publish-spike.md:14-18,112-114,141-147`. v1 was published from the script the first review called
  `main` (`agent-publish-failure.md:84`, `agent-review.md:198`).
- Scenario: a rep briefed on account A asks "How many open opportunities are there?". v1 still has the first review's
  finding 1, so the count can come back scoped to A (suspected, as in that review). Preview results for main describe
  a draft, not what users get.
- Fix: clear the server-side 401 first (spike `:168-187`: stock CLI app login, minimal probe agent, the Setup audit
  trail, JWT scopes). Until a version 2 exists, do not cite main's preview as user-facing behaviour.

**N2. The documented ship recipe runs the spec before activation, which the skill says cannot work.** Should-fix. Read.
- Where: `agent-publish-spike.md:162-163` ("Run the 12-case spec, then activate"). Against
  `agentforce-generate/references/agent-metadata-and-lifecycle.md:548` ("Tests run against activated published agents
  only"), and the org's `Account_Brief_Test` definition pins `subjectVersion v1` (`agent-publish-failure.md:87`).
- Scenario: v2 publishes and someone runs `sf agent test run` on the existing definition. It tests v1, which is still
  active, and the pass is credited to v2.
- Fix: recreate the test definition from the spec, check its subject version, activate v2 with an explicit
  `--version` in a test window, run, then keep it or roll back (see the ship order).

**N3. Explore follow-ups lose the previous question, and a pronoun can jump to the briefed account.** Should-fix.
The code path is read; the model outcome is suspected.
- Where: `.agent:145` passes only the raw message. `ExploreAction.cls:38` passes `null` history, although
  `DataExplorer.cls:69-84` accepts it. Router rules 1 and 4 (`.agent:36,39`) separate the two routes by whether
  "it/they/them" refers to an account, a semantic call the model makes on keywords it is told to watch for.
- Scenario A: "How many open opportunities are there?" then "Which close this quarter?". The explorer receives only
  the second sentence, with history NONE, so "which" has nothing to refer to. It may count every opportunity closing
  this quarter, open or not.
- Scenario B: after briefing A, then an org-wide count, the user asks "Which of them close this quarter?". Here
  "them" means the opportunities, so rule 1 applies on a literal read. But the model may read "them" as the briefed
  account, as rule 4 and the hint at `.agent:44` invite, and reply with a get_brief answer about A instead.
- Fix: add a history input to `ExploreAction` (Apex lane) bound from a variable holding the last explore question and
  answer. Limit rule 4 to follow-ups after an account_brief reply. Add both as preview cases.

**N4. The explorer runs before the explore subagent can hand the message back.** Should-fix. Suspected.
- Where: `before_reasoning` runs `explore_data` on every entry (`.agent:142-146`). Reclassify is a reasoning choice
  made after it (`.agent:152`), and the answer is already in the prompt as "Your whole reply" (`.agent:155-157`).
- Scenario: the router misroutes "the Singapore one" (a pick after AMBIGUOUS) to explore under rule 5. The explorer
  spends up to 5 model calls and 4 queries on it (`ARCHITECTURE.md:83-84`). The model then either reclassifies,
  discarding that work, or relays an explorer answer about Singapore accounts. A router-to-explore repeat runs the
  explorer again, up to the loop guard (`agentforce-generate/references/production-gotchas.md:216-220`). Skill: the
  "a transition reprocesses the same customer message" pitfall (`control-flow-lifecycle-side-effects.md`).
- Fix: preview the three reclassify paths out of explore and check the traces for a discarded `explore_data`
  FunctionStep. If one appears, tighten router rule 5 before considering a different trigger.

**N5. Access needs two permission sets plus a standard one, and nothing groups or documents them.** Should-fix. Read;
the failure mode is the skill's, not seen here.
- Where: `Account_Brief_Agent_Access` grants only the agent ("it grants nothing else"). `Account_Brief_Data_Access`
  grants the five entry classes, the app and read-only memory. There is no permission set group. No setup step in
  README or docs says to assign both (research docs mention the sets only as probe findings). `agentforce-generate/references/known-issues.md` Issue 10: if the user lacks permission for **any**
  action, the whole agent may fail. `agent-access-guide.md:69`: the panel also needs `CopilotSalesforceUser`.
- Scenario: an admin assigns only "Account Brief Agent Access". The rep sees the agent, and every turn errors instead
  of one action failing.
- Fix: one permission set group holding both sets, named in the setup doc with the standard Agentforce user set, then
  prove it with the non-admin run. Whether a rep needs anything extra for the Models API callout is unknown.

**N6. Verbatim relay of explorer tables is unproven on the current Apex.** Should-fix. Preview.
- Where: preview case 11 produced 41 lines against the action's 36, with two headers redacted (`studio-preview.md:37`).
  BE-14 later changed those headers to plain labels, which may remove the redaction, but the reshaping is the model's.
  Spec `:98` only asks for "a list", so the judge cannot catch a restated figure.
- Scenario: a rep reads an amount the model re-typed from the table and trusts it as the explorer's.
- Fix: re-preview case 11 on current Apex, diff the reply against the FunctionStep output, and make the spec outcome
  say the table rows are unchanged.

**N7. Notes.**
- `@system_variables.user_input` (`.agent:145`) is not documented in any `agentforce-generate` reference (grep finds no
  `system_variables`). It rests on SDK compiler source (`.agent:139-140`) and preview answer (a) (`studio-preview.md:44`).
  Re-check it after each CLI or SDK upgrade. Scenario: a runtime change maps it to a blank or history-wrapped string,
  the explorer gets no question, and every explore turn returns the fallback line (`.agent:159`) while the local gate
  stays green.
- The AMBIGUOUS list stops at 8 candidates plus "…and N more" (`AccountBriefResolver.cls:19,194-196`), so a 9th match
  can only be reached by refining the name.

## Limits and adoption

- Per-turn cost: a brief makes up to 3 model calls (two pre-reduces and the synthesis) on top of the section queries
  (`ARCHITECTURE.md:9-14`). An explore turn makes up to 5 model calls and 4 queries (`ARCHITECTURE.md:84`). A pronoun
  follow-up re-runs get_brief. The preview shows the model narrowing `include` (`studio-preview.md:28`), but that is
  its choice, not a cap. N4 can add a wasted explore run to a misrouted turn.
- Bulk: the agent sends one request per call, so this is safe. The resolver loops once per request
  (`AccountBriefResolver.cls:49-51`). A name search that is not a unique exact match runs exact `:84` and COUNT `:96`. A
  COUNT of 0 returns NOT_FOUND at once (`:97-99`), so a name that matches nothing costs 2 queries. A name with hits adds
  the partial query `:113`, for 3. It adds 1 more when that query fails on the city (fallback `:122`), 1 for a pasted Id
  (`:156`) and 1 for a known Id (`:138`). So 2 to 6 per name search, or 1 for a unique exact match. A Flow or MCP caller
  batching requests would reach the 100-SOQL limit at about 16 to 50 name-search resolves, or about 20 explores (5 callouts
  each, `ExploreAction.cls:34-44`). `AccountBriefGetAction` batches its one memory write (`:33-39`).
- Adoption: **yes, with conditions.** The pattern is sound and teachable: resolve-then-brief with the Id held in state,
  a deterministic explorer run, a reclassify transition in every subagent, structural unit tests and a local compile
  gate. A new team must first:
  - make the spec portable: it depends on sample account names (spec `:1-7`) and on three record Ids in the AMBIGUOUS
    outcome (spec `:44`, also asserted in `test_agent_bundle.py:342-347`). In a new org, case 5 and the Edge cases
    fail until they are edited;
  - edit `agent-check.sh`, which hard-codes the CLI path (`:17`), the skill version (`:18`, which an environment variable
    can override) and the org alias (`:71`), and may install the SDK over the network (`:39`). The `test` gate checks
    only that the script exists (`test_agent_bundle.py:379-391`), so someone must run it by hand;
  - set up the permission set group (N5);
  - have a publish path that works in its own org. This one has none today (N1).

## Security and access

- Runs as the signed-in rep: an Employee agent with no `access:` block (`agent-user-setup.md:13,20`). Sharing applies.
- All three entry classes are `with sharing`. Every Account query is `WITH USER_MODE` (`AccountBriefResolver.cls:84,96,
  113-127,138,156`; `AccountBrief.cls:206`), and explore queries run in user mode (`ARCHITECTURE.md:93`). A rep without
  Account read gets NOT_FOUND text, not an error (`AccountBriefResolver.cls:58-62`).
- get_brief's Id comes from state, not the model (`.agent:87`), and `AccountBrief` re-checks visibility
  (`AccountBrief.cls:152-154`), so a stale or invented Id yields "I can't see that account", never data.
- The AMBIGUOUS list shows names, cities and Ids only for accounts the rep can see. Explore binds no open record, so
  nothing from the briefed account leaks into an org-wide answer.
- Memory is written in system mode (`AccountBriefMemory.cls:117-140`), while the permission set grants read only. The
  rep cannot edit memory but the agent can write it. This is deliberate; the Apex review owns it.
- Permission sets grant no object access beyond the memory object (`tests/test_permission_sets.py:35-59`). Data access
  comes from the rep's own profile, which is right for this agent type.

## Failure handling: what the user sees

| Path | Reply | Exercised? |
|---|---|---|
| Resolve NOT_FOUND | Fixed resolver text (`AccountBriefResolver.cls:215`) | preview cases 3, 4, 8 |
| Resolve with a blank name | "Which account? ..." (`AccountBriefResolver.cls:222`) | no |
| Resolve AMBIGUOUS | Candidate list (`:189-199`) | preview case 5 |
| get_brief NOT_FOUND / ERROR / EMPTY | Fixed texts (`AccountBrief.cls:21-24`) | no |
| Explorer returned nothing | Fixed line (`.agent:159`) | no |
| Uncaught Apex exception, or a resolver ERROR (`.agent:62` names one; the resolver never returns it) | `messages.error` (`.agent:5`) | no (suspected) |

## What is proven, and what is not

Proven by tests and checks: bundle shape, which actions, gates, bindings and transitions sit in which block
(`test_agent_bundle.py`), spec structure, a clean local compile, and org validate. These are static.

Proven once, by preview: all 12 spec utterances on these script bytes, in Studio, as the admin, one sample each, with
explorer Apex older than BE-13 and BE-14 (`studio-preview.md:20-33`).

Not proven:
- **The non-admin run has not happened.** Every result above ran as an administrator.
- **A real MCP call has not happened.** The org listed the agent and the classes as tools, but no client called them
  (`docs/research/salesforce-mcp.md:17-25`).
- No `sf agent test run` of this spec. No version 2 has been published or activated. The Copilot panel surface itself
  was never used.
- Never exercised: a list pick, RESOLVED by pasted Id, a second account that resolves after a brief, explore follow-ups (N3), the
  reclassify transitions, the failure rows marked "no" above, and repeated runs. The model is not deterministic, so one
  pass per case is a sample, not a rate.
- `conversationHistory` replays text without setting variables (spec `:10-12`), so the stored-Id path is preview-only.

## Shipping an agent change safely

The local gate (unit tests plus `agent-check.sh`) proves only that the script compiles and is shaped right. It cannot
see routing, relay, permissions or the published version. In order:

1. **Unblock publishing first.** Today nothing can publish in `experimental` (N1). Run the spike's next tests with the
   owner's go (`agent-publish-spike.md:168-187`).
2. Edit the `.agent` file. Run `python3 -m unittest discover -s tests` and `bash scripts/agent-check.sh`; both must pass.
   Record the script's sha256.
3. Preview the exact bytes before publishing. Use Studio Live Test on the draft, or
   `sf agent preview start --authoring-bundle Account_Brief --use-live-actions`
   (`agentforce-test/references/preview-testing.md:138-145`). Cover every spec case plus the missing ones: list pick,
   pasted Id, a second account that resolves after a brief, explore follow-up, reclassify out of explore, and one failure path. Read the traces, not
   only the chat. Live actions write memory rows, so use a non-production org and test data (generate SKILL.md Rule 3).
   Do not `sf project deploy start` the bundle (`agent-publish-spike.md:158`; `deploy-reference.md:12-14` suggests it,
   and the repo deliberately differs).
4. Get the owner's approval. Publish once with the capture (`agent-publish-spike.md:156-157`). Then run
   `git checkout --` on the bundle folder and confirm `git status` is clean (`:159`).
5. Query `BotVersion` for the new version number N.
6. Recreate the test definition from `tests/agent/Account_Brief-testSpec.yaml` and confirm it targets N, not v1 (N2).
   Re-check `expectedTopic` names, because topic names can change on publish (`batch-testing.md:227`).
7. Activate N with an explicit `--version N` (`agent-publish-spike.md:162-163`). Run the spec and the two-turn check
   right away. On a failure, re-activate the previous version (`:166`).
8. As a non-admin rep holding both permission sets and the standard Agentforce user set, use the Copilot panel for
   one brief, one AMBIGUOUS pick, one explore question and one account the rep cannot see (expect NOT_FOUND).
9. Only then record the version as shipped, with the script sha256, the test run and the non-admin result.
