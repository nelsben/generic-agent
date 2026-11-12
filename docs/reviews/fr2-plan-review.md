# FR2 plan review (OPS-37)

Reviewed 2026-11-12 on `main` at `98dd6c7`, before any FR2 spike or build is dispatched. Ben asked for an adversarial
review of the whole plan once his chapter notes were done. Read for this page: the ledger, decisions, to-do and order in
[feature-revision-2.md](../plans/feature-revision-2.md); the design brief [fr2-design.md](../plans/fr2-design.md); the
Approvals table and brain runbook in [gtm-burn-plan.md](../plans/gtm-burn-plan.md); every open card under
`agents/tasks/` and the merged BE-20; the pattern pages under `docs/patterns/` and the other living docs those cards
rewrite; the Python tests that pin them; and `.chassis-delegation.json`.

**Method.** Four independent read-only reviewers took one lens each: org safety and approvals; whether the cards can run
in the order the graph gives; the document set a reader ends up with; and coverage, tracing every ask in Ben's sixteen
messages to a card line. The brain then read all four reports against the source, checked how the delegation tool treats
statuses in the tool's own contract document, modelled the proposed dependency graph by script, and decided each edit.
Nothing in the repo or in any org was changed, and no `sf` command was run.

**How to read a citation.** `BE-8:22` is line 22 of the card file whose name starts `BE-8-`. `plan:N` is a line of
feature-revision-2.md, `approvals:N` of gtm-burn-plan.md, `design:N` of fr2-design.md. Any other file is cited by its
path. Every line number is as of `98dd6c7`, and every quoted line was re-read by script before this page was committed.
`...` inside a quote skips words on the same line. M1 to M16 are Ben's messages in the order he sent them; the verbatim
copy stays outside the repo.

**Labels.** A statement with no label was read in this repo. **tool**: how the delegation tool behaves, read in the
tool's contract document and changelog outside this repo; that the installed copy matches was not confirmed.
**machine**: this Mac's own configuration, outside the repo. **unverified**: not checkable without running something in
an org or on the network.

## Verdict

**Not dispatchable as written. Fixable without a re-plan.**

What is wrong, in one paragraph: one stale `queued` card orders a publish in `experimental`. Every hold on Ben's word
lives in prose, while the tool sets a `blocked` card to `queued` by itself as soon as its last blocker merges. The NO-GO
branch of the rename cannot pass its own red test, and the close waits on four decisions that have no default. Six
pattern pages and `docs/ARCHITECTURE.md` have no card that leaves them in final form, the closing review traces only
half the ledger, and the MCP door is described three ways that cannot all be true.

What is sound: the dependency graph has no cycle, the red tests are real, tabled items are parked the way Ben asked, the
safety lines that exist are right, and 148 of 177 asks already reach a build or doc line.

The fix is small next to the plan: status and frontmatter edits, about a hundred and ten card edits (most are one
sentence), ten new cards (three are splits of cards that are too big, three are parked placeholders), five new Approvals
rows that only narrow what is allowed, and a rewritten Order. Sixty-nine findings follow: 10 blockers, 34 major, 25
minor. The [edit table](#edit-table) at the end is the worklist.

## What Ben needs to decide

Only the first row stops work. Every other row has a default the plan follows if Ben says nothing. Row 6 is the one
default that can still stall a build, and it says how.

| # | Decision | Default with no answer | What changes on a yes |
|---|---|---|---|
| 1 | **Go for the burn.** One word covers the spikes row (approvals:79) and a new row for live checks that spend model calls and write the product's own rows on existing sample accounts (finding 22). | Nothing is dispatched. | Spikes, then builds in order, each deploy under the standing approval. |
| 2 | **Log a call: Event or Task** (F17). Ben said "synonymous with create an event" (M2); the brain recommends a completed Task. | An Event, as Ben said. One constant switches it. | "Make it a Task" changes one line of BE-27. |
| 3 | **The MCP door under the new names** (approvals:83, OPS-31), with its tool set: resolve the account, get the summary, and ask anything through the explorer; the agent is not a tool. Asking anything opens the explorer to outside clients. | OPS-31 stays parked. The door keeps running under the old names with its old tools, and page 09 and the README say so. The close does not wait. | OPS-31 runs after the agent publish. A yes to the door without the explorer gives two tools. |
| 4 | **Tests that create and delete their own task** (approvals:84). | FE-14's end-to-end test stops at the draft card and Cancel; Jest and Apex tests prove the confirm path, and the docs say so. | The test confirms a task on an existing sample account and removes the task and its outcome. |
| 5 | **The Testing Center suite** (approvals:82, BE-38). It tests the optional agent only, not our surfaces. | BE-38 stays parked. The test ladder prints "skipped: agent suite not built" and page 08 says the suite is not run in this build. | BE-38 runs after the agent publish. |
| 6 | **Remove the old Account Brief leftovers from agent-probe after the rename is proven** (approvals:85; new card OPS-54). The old classes and tests stay deployed and run in every real deploy (finding 11). | They stay. Later cards keep every signature the old classes use, and a card whose deploy fails in an old test stops and hands back. This is the one default that can stall a build. | One destructive deploy removes the old agent actions, classes, tests, component and MCP server together. Brain recommends yes. |
| 7 | **If the rename go/no-go fails:** one publish of `Account_Brief` for the new label. | No publish. The optional agent keeps its old label and the appendix says so. | One publish, two attempts at most. |
| 8 | **Hide the Agentforce icon for reps.** Ben already said drop it (M12); what is left is leave to change an org setting. | Unchanged. FE-20 records the Setup step for Ben to do himself. | A worker flips it under a new Approvals row. |
| 9 | **Create the non-admin user** (approvals:75). | FE-5 stays parked and every "not yet proven for a rep" line stays. | FE-5 runs after the surfaces land. |
| 10 | **File names.** | Kept. Titles and reading order are fixed in card text and an index page. | "Tidy the names" becomes one last mechanical card before the public snapshot. |
| 11 | **Who sees history and outcomes** (F32, F81). | History is own-only. Another rep sees an outcome's type, date and sentiment label, not its text. | As Ben says. |
| 12 | **Schedule the outcome purge job.** | Nothing expires; the batch is never run in agent-probe. | One schedule under a new row. |
| 13 | **After OPS-31: the MCP sign-in, then one call of each tool.** | Page 09 shows the unauthenticated call as text, labelled "not a real tool call". | OPS-53 flips the README's status row. |
| 14 | **A deploy script instead of hand-typed deploys** (finding 19). | Not built. Deploys stay hand-typed, where the plugin's hook on this Mac sees each one. | One small card before the first deploy. |
| 15 | **Two additions to the delegation tool's settings file in this repo** (`.chassis-delegation.json`): a `docs` gate that re-runs the link check on every docs card, and the org rules added to every worker's brief (findings 18, 44). A settings change is Ben's call. | Not changed. Every org-lock card carries the org rules as its own line, and the brain runs the link check before each merge. | One small change adds both, so the tool enforces what the cards say, including on cards cut later. Brain recommends yes. |

Still Ben's and unchanged: the microphone check, the VoiceOver script, picking from FE-17's list, the industry switch
(F50, tabled), whether MCP may write, Java, GitHub Actions, and filing the Salesforce case. New and optional: unset the
default org in the main checkout and the default Dev Hub on this Mac, which both point at `experimental` (finding 15),
and say who supplies `MCP_CONTACT_EMAIL` for OPS-31.

"That completes everything" (M16) is read as: no notes are coming for page 09 or the README. The ledger still says more
notes are coming (finding 64).

### Decisions the brain made, and how to overrule each

| Decision | Overrule by saying |
|---|---|
| One go starts the whole burn; the order and the org lock pace it. | "Spikes only, then ask again." |
| Log a call defaults to an Event. | "Make it a Task." |
| The MCP door's tools are Apex actions; the agent is not a tool. | "Keep the agent as an MCP tool." |
| On NO-GO, everything is renamed except the agent bundle. Labels-only is dropped. | "Labels only on NO-GO." |
| File names stay. | "Tidy the names." |
| Undo is offered for updates only. | "Undo creates too." |
| The Saved answer type stays in the store; the control that writes one is a parked card (FE-23). | "Build the keep control" or "drop saved answers." |
| The outcomes report type and the record-page placement stay, recorded as brain decisions. | "Drop them." |
| Chapter 00 states each platform limit plainly with its number, and keeps a short "when standard fits" section. | "Drop the when-standard-fits section." |
| For anyone but its author, an action outcome shows a fixed phrase for its kind, not its title. | "Show titles to everyone who can see the account." |
| The agent publish is split from the rename deploy, so seven cards wait on it, not thirty-two. | "Keep OPS-30 whole." |
| The drift check retrieves `force-app` metadata read-only with no new Approvals row. | "Add a row for it." |
| No deploy script. | "Cut the deploy script." |
| Gitignored material is restated in tracked files; the tool's local-brief setting is not used. | "Use the local brief." |
| OPS-10 is parked, not marked merged: its write-up says "partly done" and the rest is Ben's. | "Mark it merged." |
| The three superseded cards (BE-8, BE-15, BE-19) are set to `parked`, the one status the tool never dispatches. No tool setting changes. | "Delete the three cards." |
| An org-lock card is dispatched only after the previous org-lock card is merged, so each builds on the last. | "Dispatch on hand-back." |
| No card parked on its own approval sits upstream of the close. A missing yes narrows what the close proves, and the pages say so. | "The close waits for" and the approval's name. |

## Numbers

| | As written | After the edits |
|---|---|---|
| Active cards, spend at one attempt each | 47, $603 | 50, $614 |
| Cards that hold the org lock (strictly serial) | 33, $495 | 35, $507 |
| Cards parked on their own approval | 3 held in prose, $50; FE-5 is a fourth, counted as active | 9 by status, $105 |
| Longest dependency chain | 14 cards, $264 | 18 cards, $277 |
| Cards that wait on the agent publish | 32 | 7 |
| First demo: the renamed panel | 5 cards, $103 | 5 cards, $71 |
| The compact window | 14 cards, $231 | 11 cards, $167 |
| The rail | 16 cards, $268 | 21 cards, $285 |
| Write actions | 18 cards, $301, and F17 | 26 cards, $370 |
| History and sentiment on screen | 21 cards, $325 | 29 cards, $410 |
| Asks traced (177): carried, partial, spike only, dropped, over-read | 148, 25, 2, 1, 1 | every partial has an edit below or a stated default above |

Both columns were counted by script. "As written" is counted over the card files at `98dd6c7`: the 47 active cards
include this review's own card (OPS-37, $10) and FE-5, whose status is `queued` although approvals:75 holds it; they
leave out the three cards held in prose and the four stale ones in finding 1. "After the edits" is counted over the
proposed graph in section E: no cycle, and no card parked on its own approval is upstream of the close. The rail and
write actions come later than as written because they now wait for the cards whose files they share (finding 24); as
written they would have run earlier and overwritten each other. Spend is each card's per-attempt ceiling, so two
attempts double it. The lock, not the worker count, sets the pace: 35 cards run one after another.

## Findings

Each finding gives the evidence, what goes wrong, and the direction of the fix. The exact edits are in the [edit
table](#edit-table), which names the finding behind each row.

### Blockers

**1. A queued card orders a publish in `experimental`, and three more stale cards read as ready.**
- Evidence: BE-8:7 "status: queued"; BE-8:22 "Org alias is `experimental`."; BE-8:28 "publish with `sf agent publish
  authoring-bundle -o experimental -n Account_Brief --skip-retrieve --json`". The merged card OPS-14:24 says "BE-8 is
  superseded by BE-9, which contains its commits." BE-8 has no `blocked_by` and no lock. OPS-10:7 "status: queued" has a
  scope outside the repo, and its own write-up, docs/research/telemetry-off.md:3, reads "Status: partly done." BE-15 and
  BE-19 carry `status: superseded`, a word the tool does not know and so treats as `queued` (**tool**).
- Goes wrong: the tool dispatches `queued`. A brain clearing the queue sends a worker to publish and activate in the org
  nothing may touch.
- Fix: BE-8, BE-15 and BE-19 become `parked`, the one status the tool refuses, each with a line under Why naming what
  replaced it. OPS-10 is parked too. No tool setting changes. This ships first, as its own small change.

**2. Every hold on Ben's word lives in prose, and the tool releases `blocked` cards by itself.**
- Evidence: approvals:79 "pending Ben's go (brain recommends yes; the standing deploy line covers the deploys)", yet
  OPS-29:7 "status: queued", and OPS-29:30 "Org, agent-probe only, under the standing approval for production-classified
  deploys" never names that row. BE-31, BE-32 and BE-34 are `queued` too; BE-31:24 "**Dispatched only after Ben's go on
  the FR2 spikes**" is addressed to a worker, who does not control dispatch. FE-20 is `queued` and its only hold,
  FE-20:24 "**Dispatched only after Ben's chapter notes are done**", is now met, though Ben has given no go for builds.
  BE-28:20 "**Parked.**", OPS-33 and OPS-34 are `status: blocked`. FE-5:7 "status: queued" while approvals:75 says "Ben
  does this himself; FE-5 stays parked".
- **tool**: when the last blocker of a `blocked` card is finished, the tool sets the card to `queued`. `parked` is the
  one status it refuses to dispatch and never releases. A made-up word such as `held` is read as `queued`. A card set to
  `blocked` after its blockers merged is never released.
- Goes wrong: OPS-29 can be dispatched today under a row that says pending. BE-28 is released when its six blockers
  merge and then points a worker at a third agent publish; OPS-33 and OPS-34 are released the same way. The brain
  runbook (approvals:189 onward) has no step that checks a row before dispatch.
- Fix: `status: parked` on every root card until Ben's go and on every card that waits on its own approval. The first
  Done-when line of each gated card reads its Approvals row and stops if the row does not start with "approved". The
  runbook gains the check. The plan gains the rule for what the brain does on Ben's word.

**3. OPS-31 cites a spent approval; its own row is pending.**
- Evidence: OPS-31:25 "under the Approvals lines 'Org setup for the MCP server and its External Client App (stretch), up
  to the sign-in' and the standing deploy line". That is approvals:67, approved on 2026-11-11 for the first server. The
  FR2 row is approvals:83 "pending Ben (brain recommends yes; it is a second live endpoint until the old one is
  removed)". The card never says `experimental`, and has no fallback for a no.
- Goes wrong: the tool releases OPS-31 when OPS-30 merges, and its worker creates a second live MCP endpoint and OAuth
  client app in a production-classified org, believing it approved.
- Fix: park OPS-31, cite row 83 by name, and take it out of the close so a no (or no answer) costs nothing.

**4. The record-creating test is pending, and FE-14 cites only the standing deploy approval.**
- Evidence: FE-14:27 "one test drafts and confirms a task on a test account, checks the result card and the record, then
  deletes that task in teardown"; FE-14:28 "Org, agent-probe only, under the standing approval"; approvals:84 "pending
  Ben (brain recommends yes); no test touches a record it did not create". BE-27:25 says a commit "records one Action
  outcome on the account", which a teardown that deletes only the task leaves behind on every run. "A test account" is
  undefined, so a worker may create one.
- Fix: FE-14's test is conditional on row 84 and has a written fallback; it names an existing sample account and removes
  the outcome too.

**5. The NO-GO branch of the rename cannot pass, and it strands fourteen scopes.**
- Evidence: BE-23:14 "asserts no Account Brief name remains outside the historical folders and that the Customer_Summary
  bundle, CustomerSummaryPanelController and customerSummaryPanel exist". BE-23:26 on NO-GO: "change only labels and
  visible strings". plan:270 "The brain re-cuts those scopes before dispatching anything after `BE-23`."
- Goes wrong: on NO-GO the red test can never go green, so BE-23 fails both attempts. If it were forced through, the
  tool would release the fourteen cards whose scopes name `CustomerSummary*` paths before any re-cut, and those paths
  would not exist.
- Fix: BE-21 only tests whether the agent can be published under a new name, so narrow the fallback to match: on NO-GO
  everything is renamed except the agent bundle, its spec and the bundle name in the agent check script. No later card
  then has a NO-GO variant.

**6. The close hangs on four decisions that have no default.**
- Evidence: OPS-35:8 "blocked_by: [FE-13, FE-14, FE-15, FE-20, OPS-31]"; OPS-46 and OPS-47 are blocked by BE-38; OPS-36
  by OPS-31, OPS-35 and OPS-47; BE-27:20 "Not dispatched until Ben answers F17". The four are OPS-31's row, BE-38's row,
  F17 and the record-test row. plan:254 covers only a "no" on BE-38, and only as a promise that the brain will edit four
  cards by hand.
- Goes wrong: with no answer on any one of them, OPS-36 and OPS-28 never become ready.
- Fix: each gets a default (table above). OPS-31 and BE-38 leave every `blocked_by` list on the path to the close, and
  the cards downstream say in one line what they do when the optional piece is absent.

**7. The sweep card was never cut, so six pattern pages and the architecture page have no final-form owner.**
- Evidence: plan:232 "Pages he has no notes on get the same treatment in one sweep card, cut after his"; no such card
  exists, it is not in the Order and not in OPS-36's blockers. OPS-36:31 "Pattern pages: only their image links and alt
  text change here". design:141 "Every pattern page follows it." Pages 09 to 14 are written by OPS-31, BE-24, FE-11,
  FE-15, BE-27 and OPS-32, and none of those cards mentions the page shape or the diagram rule. Page 09's seven open
  items (docs/patterns/09-outside-door-mcp.md:108 onward) have no owner. docs/ARCHITECTURE.md:95 "Only memory runs in
  system mode." goes false under BE-35, and no card has the file in scope for more than one link.
- Fix: cut OPS-48 (the sweep, with an index page that fixes the reading order) and OPS-49 (the architecture page), both
  upstream of the README card.

**8. The closing review traces half the ledger and can run before the product is finished.**
- Evidence: OPS-35:25 "for each ledger row F01 to F43"; the ledger runs to F92, and rows F44 to F92 hold all eight
  chapter notes. Its blockers (finding 6) do not reach FE-16, FE-19, FE-21, BE-33 or BE-36. OPS-35:27 "one service
  behind each skill for panel, agent and MCP" still counts the agent as a door.
- Fix: trace the whole ledger, wait for every surface and service card, and review the three real doors.

**9. The MCP door is described three ways, and nobody makes a real call.**
- Evidence: OPS-31:25 "with the three tools pointing at the renamed Apex and the Customer_Summary agent". OPS-44:24 "Say
  plainly that none of our surfaces or MCP use it." design:15 "service sits behind each skill, and every door calls it."
  docs/patterns/09-outside-door-mcp.md:119 "Org-wide questions through `ExploreAction` are not a tool". BE-30:25 "the
  panel, the agent action and MCP all get it". tests/test_mcp_door.py pins the agent tool. OPS-31:28 leaves "still
  unproven: a real tool call", and no to-do line says to make the call after the hold lifts.
- Goes wrong: over MCP every plain question goes through the agent that F83 made optional and froze. Three cards will
  each write a different story.
- Fix: the door's tools are Apex actions (resolve, summary, and ask anything if Ben approves exposing the explorer); the
  agent is not a tool. Every line that says otherwise is edited to match, and Ben's to-do gains the sign-in and one call
  per tool.

**10. OPS-36 cannot meet its own "See it" rule and contradicts its own safety line.**
- Evidence: OPS-36:32 "capture it on each surface where it runs (compact window, rail; the MCP door as a client
  transcript image)" needs a signed-in call that is on hold. OPS-36:27 "the brand swap before and after" needs a deploy,
  and OPS-36:28 says "never deploy, publish, create a user or touch experimental". OPS-36:29 "as OPS-44's hand-back
  proposes" depends on a note that is never in the repo (OPS-44:26 "as a short note in the hand-back, not in
  README.md"). Its red test line says none, yet it adds a test file. One card at spend 25 writes the README, four
  diagrams and captures for fifteen pages.
- Fix: split it. OPS-52 takes the captures and the See-it sections with an exact list per page; OPS-36 keeps the README,
  loses the org lock, and reads a tracked page for the quick-start change.

### Major

**11. Old Apex left in agent-probe compiles against classes later cards change, and every real deploy runs its tests.**
- Evidence: OPS-30:27 "do not deactivate, change or delete Account_Brief, its classes". The rename covers only
  `AccountBrief*`; the shared classes keep their names, and the old copies bind to them:
  force-app/main/default/classes/AccountBriefTest.cls:8 "private class Stub implements AgentLlm.Provider". The `org`
  gate cannot see the problem, because scripts/validate-org.sh:56 runs "--test-level RunSpecifiedTests" with the repo's
  own tests, while the approved deploy is approvals:68 "validate with RunLocalTests, then quick deploy with
  CONFIRM_PROD=1". Removal is approvals:85 "not approved; needs Ben's go". plan:271 lists the leftovers without any
  Apex.
- Goes wrong: the first card that changes a signature the old classes use passes its gate and then fails its real
  deploy, in a class that is no longer in the repo. **unverified** that the failure happens in this org.
- Fix: the cards that change shared classes (BE-24, BE-29, BE-30, BE-33, BE-35, BE-36, BE-37 and the new BE-39) keep
  every signature the old classes use and stop if an old test fails. OPS-30 records which org-only classes and tests
  remain. OPS-54 (parked on approvals:85) removes the leftovers together; removing the Apex alone is not possible,
  because the old agent's actions, the old component and the old MCP server reference it.

**12. The publish cards cite the wrong row, the plan says one publish where the cards make two, and the NO-GO publish
has no row.**
- Evidence: BE-21:26 "under the Approvals lines 'Phase 2: cut and work new agent or design iteration cards in the new
  org'"; the row that covers both publishes, with Ben's stop condition, is approvals:80. plan:229 "**One more agent
  publish only, for the rename** (`OPS-30`)" and design:176 "FR2 has one, for the rename (`OPS-30`)", while BE-21 and
  OPS-30 each publish and activate. OPS-30:25 "deploy the changed labels and publish the label change as a new
  Account_Brief version the same way" is covered by no row.
- Fix: both cards cite row 80 by name and carry Ben's condition. The plan and the brief say two. The NO-GO publish
  becomes a pending row (decision 7).

**13. After BE-23 the repo holds two bundles named `Customer_Summary`.**
- Evidence: BE-21:25 "holds a copy of the Account_Brief bundle with developer name Customer_Summary"; BE-23:27 "use
  spikes/rename/ only as a reference; do not change spikes/".
- Goes wrong: which copy `sf agent publish` resolves is **unverified**. If it is the spike copy, the active agent runs
  on the old Apex and the agent check still passes.
- Fix: BE-23 deletes `spikes/rename/` and adds a test that fails on two bundles. The publish card confirms, read-only,
  that the active version's actions name the renamed classes.

**14. BE-21 and OPS-30 run the agent spec while the Testing Center row is pending.**
- Evidence: BE-21:27 "one sf agent preview (or the existing agent spec, run once)"; OPS-30:28 "the agent spec runs once
  against the active Customer_Summary version"; approvals:82 is pending and names BE-38 only.
- Fix: BE-21 uses the preview only. The publish card runs the spec only if row 82 is approved, otherwise one preview
  turn.

**15. This Mac's defaults point at `experimental`, and OPS-28's scripts default to agent-probe.**
- Evidence (**machine**): the global `sf` config names `experimental` as the default Dev Hub, and the main checkout's
  own config names it as the default org. OPS-28:30 "run each step of 'See it in 5 minutes' exactly as written,
  substituting only `<org-alias>` = ga-scratch", but e2e/support/env.js:6 "const ORG = process.env.SF_E2E_ORG ||
  process.env.SF_TARGET_ORG || 'agent-probe';" ignores `sf config`, and both gate scripts default the same way.
- Goes wrong: a README scratch-org command with no hub flag creates the org on the wrong hub. OPS-28's "runs without the
  agent" proof is recorded from agent-probe, where the agent exists.
- Fix: OPS-28 puts the hub flag on every scratch command and exports both variables for the whole run. The brain runbook
  says every `sf` command carries `-o agent-probe`.

**16. The drift check may retrieve the OAuth consumer key.**
- Evidence: OPS-46:27 "for example by retrieving to a temporary folder and comparing";
  docs/research/mcp-door-runbook.md:181 says the retrieved files carry the "consumer key, the contact email and the org
  Id (verified)."
- Fix: the check covers `force-app` only, never a client app or MCP server definition, in a temporary folder outside the
  repo; a test checks the script names none of those types.

**17. The closing review loads the agent test skill and has no ban on security tests.**
- Evidence: OPS-35:24 "salesforce-development:platform-apex-generate (review mode) and agentforce-adlc:agentforce-test
  first"; OPS-35:28 "never deploy, publish, create a user or touch experimental". That skill also covers red-team and
  prompt-injection suites, which need Ben's yes and a non-production org.
- Fix: drop the skill; ban agent tests and security tests of any kind in the card.

**18. The hard rules reach a worker only through its card, and many org cards lack them.**
- Evidence: `briefExtra` in `.chassis-delegation.json` is empty. By grep over the open cards: no "sign in" rule in
  BE-23, BE-26, BE-27, FE-11 to FE-15, FE-21, OPS-33, OPS-35, OPS-36 or OPS-46; no Ids-and-hostnames sentence in BE-26,
  BE-27, BE-28, FE-11 to FE-15, OPS-33 or OPS-36; no `experimental` in BE-23, FE-11 or OPS-31.
- Fix: one org-rules line, the same on every card that holds the org lock. On Ben's yes to decision 15 the same line
  also goes in `briefExtra`, which the tool adds to every brief (**tool**), so cards cut later carry it too; a dry run
  then confirms a brief has it.

**19. No script performs the approved deploy; about twenty cards hand-type a production deploy.**
- Evidence: `scripts/` has the check-only `validate-org.sh` and no deploy script. The confirmation marker is read by a
  plugin hook on this Mac (**machine**), which gates any production org and does not gate a publish, an activation,
  anonymous Apex or a data command.
- Not adopted by the brain: a script would run where the hook cannot see the single commands, and Ben approved the
  two-step method as typed. It is decision 14. Instead, the org-rules line on each card spells out the method and
  forbids `deploy start`.

**20. Two spikes say "through the Agent API", and four cards read a file a worktree does not have.**
- Evidence: BE-32:25 "through the Agent API from a caller in spikes/standard-limits"; BE-34:27 "through the Agent API:
  the same session after 1, 5, 15 and 30 minutes"; docs/research/agent-api.md:13 "The Agent API's documented auth is an
  External Client App with the client credentials flow". BE-32:24 "the brain's generic restatement at
  .delegation/fr2/operating-pattern.md", and the same file in OPS-38:23 and OPS-41:23, is gitignored. BE-32:29 claims
  "(no deploy, no data change)" though a summary writes session rows.
- Goes wrong: a worker builds a client app and handles a consumer secret, or stalls on a missing file.
- Fix: both spikes call the agent only from anonymous Apex with the invocable action. The three cards read the ledger
  rows and the design brief, which already restate the pattern in generic terms.

**21. BE-35 lets one rep's free text reach another rep's screen and model prompt.**
- Evidence: BE-35:25 "another rep sees the type, date, title of an action, the related record link"; BE-35:29 puts "the
  last summary's headline and date, the last few actions" into the next conversation's context; BE-35:28 exposes the
  write as "an invocable for the agent and MCP" that takes the sentiment fields.
- Goes wrong: an action title can carry a case subject the viewer cannot read, and it is text another user wrote landing
  in someone else's prompt. It also sits against plan:296 "Until then MCP stays read-only".
- Fix: non-authors see a fixed phrase per action kind and the date, on screen and in context. The invocable takes a
  Saved answer only, never sentiment, and is not an MCP tool in FR2.

**22. Live checks that spend model calls and write product rows have no Approvals row.**
- Evidence: BE-29:26 "scripts/summary-accuracy.apex runs the summary for up to five sample accounts in agent-probe";
  similar runs in BE-30, BE-35 and BE-36, and in every e2e run. approvals:57 "The brain and every worker do only what
  these lines approve." FE-16:28 says "Read-only against the org: no deploy, no data change" while it runs the e2e
  suite, which makes summaries.
- Goes wrong: a careful worker skips its proof; a careless one leaves rows that never expire and later show in history
  and sentiment captures.
- Fix: one new pending row, folded into the go (decision 1). Each card names an existing sample account and records how
  many rows it wrote.

**23. Six cards commit captures without the capture kit or the reject list.**
- Evidence: FE-15:28 "Capture docs/assets/fr2-rail-open.png, docs/assets/fr2-rail-context.png and a short
  docs/assets/fr2-rail.gif"; the same pattern in FE-12, FE-13, FE-14, FE-19 and OPS-35. The runbook's image rule
  (approvals:211) and privacy grep name only earlier cards.
- Goes wrong: a plain screenshot call skips the kit's page guard and commits the running user's name.
- Fix: every still and GIF goes through `e2e/capture/kit.js`; the runbook's two checks apply to any card that changes
  docs or adds an asset.

**24. Unordered org-lock cards rewrite the same files, and the lock ends at hand-back.**
- Evidence (**tool**): a worker holds a resource from spawn to hand-back, not to merge. Pairs with no path between them
  in `blocked_by`: BE-24 and BE-30 (the explorer classes); BE-24, BE-25 and BE-26 (the data-access permission set);
  BE-26 and BE-35 (the panel controller); FE-14 against FE-13, FE-15, FE-16, FE-19 and FE-21 (all hold `e2e/**`).
- Goes wrong: the second worker's worktree lacks the first's unmerged change, and its deploy puts an older copy of the
  shared file into agent-probe.
- Fix: order each pair in `blocked_by`, and add the plan rule that an org-lock card is dispatched only after the
  previous one is merged.

**25. Tests that pin what a card changes sit outside the card's scope.**
- Evidence: tests/test_permission_sets.py:68 "self.assertEqual(sorted(granted), sorted(entry_points))" pins the class
  list that BE-25, BE-26, BE-27 and BE-35 extend. tests/test_explore_prompt.py:67 "self.assertEqual(list(self.rules),
  list(range(1, 12)))" pins the rule count BE-30 raises. tests/test_app.py:51 "self.assertEqual(len(items), 1)" pins the
  utility bar FE-13 and FE-15 change. playwright.config.js:6 "End-to-end suite for the Account Brief panel" and
  `jest.config.js` (its mocks path names the old component folder) are outside BE-23's scope. BE-23:15 "gate: test,
  jest, org" runs a check-only deploy with no lock.
- Goes wrong: the `test` gate fails, and each scope amendment waits for approval.
- Fix: add each test to the scope of the card that breaks it; BE-23 takes the lock.

**26. OPS-30 forbids `force-app` though it is the first real deploy of the rename, and one publish gates thirty-two
cards.**
- Evidence: OPS-30:11 forbids `force-app/**`; a deploy error there needs an approval to fix. Its gate has no `agent`
  though it publishes. Thirty-two of forty-seven active cards sit behind it, though F83 made the agent optional.
- Fix: split. OPS-30 keeps the deploy, the group assignment and the e2e run, and may make listed fixes. OPS-51
  publishes, activates and proves the agent. Only the chapter on the optional agent (OPS-44) waits on it directly, plus
  four parked cards (BE-38, OPS-31, BE-28, OPS-54); seven active cards sit behind it in all, every one a closing doc
  card.

**27. Forty cards wait on a surface spike for one JSON entry, and FE-18 undoes the shared package directory.**
- Evidence: BE-21:25 "inside the non-default 'spikes' package directory OPS-29 added"; FE-18:29 "added to
  sfdx-project.json for the run and removed before hand-back". FE-18's Jest tests never run, because jest.config.js:7
  "`roots: ['<rootDir>/force-app'],`" excludes `spikes/`.
- Fix: OPS-50, an economy card with no org step, adds the package directory. BE-21, BE-22 and OPS-29 wait on it. FE-18
  does not touch `sfdx-project.json` and runs its Jest tests with an explicit roots argument.

**28. Two cards own the same hotkey test, and one asks for traces the config rules out.**
- Evidence: FE-16:25 "**Both hotkey branches:** Playwright runs the open, ask and Esc path twice in agent-probe";
  FE-21:26 "**Both hotkey branches:** the hotkey specs run on the Mac branch (Meta) and the Windows branch". FE-21:25
  "with Playwright traces on failure" against playwright.config.js:9 "Tracing, video and HAR stay off: a trace records
  request headers and Aura POST bodies".
- Fix: FE-21 owns the test and waits for FE-16; tracing stays off.

**29. FE-13 and FE-15 need an interface FE-12 never promises, in a folder they may not touch.**
- Evidence: FE-13:26 "carrying the current session"; FE-15:28 "open from expand with a session id"; FE-12:25 promises
  only "record context and brand values as @api properties". Both later cards forbid the shared conversation folder.
- Fix: FE-12 states its public interface and tests it. FE-12 is also split: history, the scope chip and card rendering
  move to FE-22, so the first demo does not wait on five services.

**30. FE-5 is queued with no lock, the old names, and no place in the Order.**
- Evidence: FE-5:7 "status: queued"; FE-5:24 "the panel loads in the Account Brief app for this user"; FE-20:27 "leave
  the non-admin check to FE-5", but FE-5 has no such check. OPS-36, OPS-45 and BE-33 also defer to it.
- Fix: park it until Ben's user exists; give it blockers, the lock, the new names and the checks other cards hand it.

**31. The README card leaves its table, its links and its quick-start list to chance.**
- Evidence: OPS-36:25 "the pattern workbook table (each pattern's business outcome, what it proves, its page)" does not
  say which pages or in what order; the build review and proof pages are not linked. README.md:66 onward lists the
  deploy folders by hand, FR2 adds three metadata folders, and no card owns the list, so OPS-28 meets the stale list at
  the last and dearest step.
- Fix: the table follows the index page; the proof table links the build review; a test compares the quick start's
  folders with the folders on disk.

**32. BE-27's scope misses what its bullets need, and FE-19 must place components it has no way to assign.**
- Evidence: BE-27:26 "through the existing model seam (pattern 04)" needs a prompt file its scope does not name, and
  "undo(token) within 15 seconds restores the previous values" needs state between two calls while the card forbids new
  objects. FE-19:27 "Both sit in the rail's context area (FE-15) and on the account record page" has no application or
  page assignment in scope.
- Fix: BE-27's scope gains the prompt file and setting; the undo token carries the previous values itself. FE-19's
  components expose the record-page target, and placing them is a step in the swap guide.

**33. The nine chapter cards will not produce one shape.**
- Evidence: they can run before the builds they describe: OPS-38:8 "blocked_by: [BE-23, BE-24, BE-29]" while OPS-38:28
  tests "that the reduction table lists every registry key in the engine class", which BE-35 and BE-36 change later with
  docs forbidden. Each invents its own headings: design:144 "**The business problem:**", OPS-38:24 "**Part 1, the
  business impact:**", OPS-39:24 "**The business outcome:**". The trust line of design:150 "part says what runs as the
  user and names any system-context use, per principle 5 (F87)." appears in OPS-45 only. OPS-44:24 "Keep the file name
  (the sweep card settles final numbering and file names for every page)." defers names to a card that cannot edit the
  cards after it. Three "not yet proven" lines sit on pages whose proving card may not edit them. OPS-38:26 "check each
  with the GitHub markdown API (gh api markdown, read-only)" may return the code block untouched and prove nothing
  (**unverified**).
- Fix: the brief fixes the exact headings and the exemptions; OPS-38 ships one shared test helper; each chapter waits
  for its builds and opens its trust part with the same sentence; file names are final; pages link the README's status
  rows instead of stating proof themselves; the render check must first be shown to fail on a broken diagram.

**34. Nobody builds the card contract on the Apex side or for MCP, and no control keeps an answer.**
- Evidence: FE-18:26 "that the Apex services return and every surface reads"; FE-12:26 "no Apex changes in this card";
  no backend card returns the contract. OPS-41:25 will write "the answer and its cards come from one typed contract
  (FE-18) and render every time, and MCP uses the same services". BE-35:28 "A saved answer is written only when a rep
  asks to keep one", and no front-end card lets a rep ask.
- Fix: BE-39 builds the contract in the services and states what an MCP client receives. FE-23 (parked until Ben picks
  it from FE-17's list) is the keep control.

**35. Pages 11 to 13 go stale after their only writer, and pages 12 and 14 never link chapter 00.**
- Evidence: page 13 is written by BE-27 before any screen exists, and FE-14 has neither the page nor the manifest in
  scope. FE-19 forbids the pattern pages, so page 12 never shows the timeline. plan:260 "each surface page (03, the
  rail, the embedded surface) links it" is in no card.
- Fix: the sweep card's bullets for each page.

**36. BE-23's red test fails on text the card itself says to leave.**
- Evidence: BE-23:14 "asserts no Account Brief name remains outside the historical folders", while the card leaves old
  image alt text in place: README.md:6 "![The Account Brief panel on an account page".
- Fix: the test also excludes `docs/assets`, image alt text, and link text that points into a historical folder.

**37. Two Done-when steps cannot be done once FE-20 has run.**
- Evidence: FE-20:26 "delete AccountBriefAgentClient and its test from the repo" runs first; then OPS-30:28 "the panel's
  agent call reaches Customer_Summary" and BE-23:27 "Apex that names the agent (the generateAiAgentResponse call) uses
  Customer_Summary" have nothing to prove or rename.
- Fix: delete both clauses.

**38. OPS-28 contradicts itself.**
- Evidence: OPS-28:33 "deploy Account_Brief_Agent_Access and the Account_Brief_User group" uses names the rename
  removes. It proves the "runs without the agent" claim but may not edit the page that carries it.
- Fix: new names, the agent steps as the optional track, and it flips its own README status row.

**39. "Any object, any combination" has only a spike behind it, and two doc cards state it without a guard.**
- Evidence: design:25 "is answered by the explorer from the same context, on any object the user" and design:26 "can
  read, in any combination"; only BE-31 carries it, and BE-31:31 ends in "a list of proposed build cards". OPS-39 guards
  its own page against the claim; OPS-36:33 and OPS-41:26 do not.
- Fix: the same guard sentence on both cards; the principle is reworded to what pattern 02 lists as proven. When BE-31
  merges, the brain cuts the build cards its research page proposes and puts their cost to Ben; until then the ask is
  open, and the pages say so.

**40. Ben's answer on the icon comes back to him as a question.**
- Evidence: M12 "I'm all for dropping the Astro icon button"; plan:294 "Decide whether to hide the Agentforce icon for
  reps."; FE-20:27 "do not change that setting: hiding it is Ben's call (his to-do)".
- Fix: the to-do line becomes an approval to change one setting (decision 8). FE-5 gains the rep-side check.

**41. The company name and the logo have settings fields and almost no stated place on screen.**
- Evidence: M2 "they should be able to change the company name, the agent name, the logo, the colors, the tone of the
  agent". BE-24:27 "every visible use of the agent name comes from Agent_Name__c" says nothing for the company name. The
  logo appears outside BE-24 only in FE-13:27 "where the platform allows it; if it does not, say so and show the brand
  in the launcher only".
- Fix: BE-24 says where each shows and that the company name reaches the prompts; FE-12 and FE-15 name the logo.

**42. "Log a call" is treated as unanswered and holds all six write actions.**
- Evidence: M2 "We can do log a call, which I think is synonymous with create an event."; plan:42 "**open**: `BE-27`
  waits for Ben's answer."; BE-27:20 (finding 6).
- Fix: default to his words, in one constant (decision 2).

**43. Principle 4 promises more sharing than BE-35 builds.**
- Evidence: design:36 says an outcome is visible to "whoever can see the account"; BE-35:25 shows another rep no body,
  and history is own-only. For a second rep, no summary text is reused, and the README would print the principle as
  written.
- Fix: reword the principle to what is built; the to-do line on outcome visibility says what the default costs.

**44. Nothing re-runs the link check, and e2e claims rest on the worker's word.**
- Evidence: the config's gate ids are `test`, `org`, `agent` and `jest`. Cards name `bash scripts/check-docs.sh` in
  prose only.
- Fix: every card whose scope names `docs/` or `README.md` names the link check in its gates line, and the brain runs it
  in the worktree before the merge. On Ben's yes to decision 15 it becomes a `docs` gate id that the verifier re-runs.
  E2E cards paste the Playwright summary in the hand-back.

### Minor

45. **Throwaway records.** BE-22:28 "never create or change records except throwaway test records you delete in the same
    run" allows any insert, which can fire automation. Use a savepoint and roll back; never update an existing record.
46. **Records made or backdated for a capture.** FE-19:26 "Fewer than two points shows a plain note instead of a chart",
    BE-36:27 and FE-15:26 each invite it. Add: use only existing sample data and outcomes from real summaries; show the
    empty state otherwise.
47. **Spent Approvals rows still read "approved"**, including approvals:62 "Real deploy of `main` to `experimental`
    (never the agent bundle)". That is how OPS-31 came to cite row 67. Append "spent, closed" to each.
48. **Org settings flipped for a proof have no stated method.** BE-24:28 "the 'after' state is restored to Default in
    the org when done"; BE-33:29 flips a setting for one run. Each flip is its own validate and quick deploy, and the
    hand-back's first line says whether the org is back to Default.
49. **OPS-33 makes `experimental` conditional.** OPS-33:27 "create a user, or touch experimental without Ben's go in
    chat". No exception.
50. **Nobody keeps one list of what FR2 leaves in agent-probe.** OPS-35 builds a "Left in agent-probe" table from every
    research page's Undo list; BE-22 and FE-18 list what they deploy.
51. **Spend ceilings look low on a few cards** (**unverified**, no cost history read). BE-33 covers research, a metadata
    type, a second provider, a trace and a deploy at $12. Raise it to 20.
52. **Page 01's registry-key test** (finding 33) is resolved by ordering OPS-38 after BE-35 and BE-36.
53. **Hotkeys are hard-coded after a spike that may change them.** OPS-29:27 "If one fails, pick a replacement";
    FE-13:25 and FE-15:25 name the keys. Read them from the spike's research page.
54. **Two read-first lists name files that may not exist yet.** FE-17:23 reads page 11 before FE-11 writes it; BE-22:24
    reads a class FE-20 deletes.
55. **OPS-41 assumes BE-32 produced numbers.** OPS-41:24 "Each point carries its number from BE-32 or a public doc
    link". Allow "not measured", with BE-32's reason.
56. **FE-21's smoke subset runs before two surfaces exist.** FE-21:27 "runs one spec per surface in under two minutes".
    FE-14, FE-15 and FE-19 each tag one spec for it.
57. **Stale facts and names.** BE-38:27 "today pins the old 12-case spec" (main pins 16). OPS-31:13 names a red test
    that is already green after BE-23. FE-12:25 "so ACT-UI can add them" names an id that does not exist (it is FE-14).
    FE-12:26 "the existing ask, explorer and agent paths". BE-22's title and BE-22:20 still ask whether the agent can
    hand a draft back. BE-24:20 "(tone in the agent itself is a later card)" points at the parked BE-28. design:130 "the
    agent or the Apex router picks the action".
58. **The Order disagrees with the graph** in five places (the review before any build, BE-21 beside OPS-29, BE-24
    beside BE-25, OPS-41 before OPS-38, OPS-35 after the chapters). Rewrite it from the graph.
59. **Withdrawn text still drives work.** plan:194 "The review of page 08's open items below stays, because every
    chapter rechecks its open items (F80)" keeps two script features and two to-do lines that rest on a sentence Ben
    withdrew. Kept, and moved to the brain's decisions.
60. **The rail has no visible key hint.** M1 asked for the highlighted key "to also be here"; FE-15:25 "opens on
    Cmd/Ctrl-Shift-K, on the launcher's expand and on the compact window's expand" shows none.
61. **"Why custom" is softened with no recorded decision.** M8 "It's because the standard Astro icon is bad. It doesn't
    scale."; OPS-41:24 "Say it respectfully: what we gain, not what is wrong with the platform". State each limit
    plainly with its number, and record the tone as a brain decision.
62. **The ledger names cards whose Done-when lacks the sentence**: long-text filters (BE-31), the chapter 00 link
    (FE-15, OPS-32), the access step in Adopt it (plan:181 gives it to OPS-36, which cannot edit chapters), and a
    sentence on ease (OPS-38).
63. **Work with no ask behind it**: Undo, read two ways (BE-27:26 "restores the previous values of an update or deletes
    a record" and FE-14:26 "updates offer Undo for 15 seconds"); the Saved answer type; BE-35:30 "A report type Customer
    Outcomes with Account"; the record-page placement. Each is kept and recorded as a brain decision.
64. **Message 16 has no ledger row, and the ledger still expects notes.** plan:10 "More notes are coming page by page,
    starting with the README."; OPS-36:24 waits on "every F42 note Ben has added by dispatch time". Add row F93 and
    close F42.
65. **"The last summary" in the rail does not say whose.** BE-25:25 "lastSummary (date and the first lines of the newest
    stored summary, or none)". It is the running user's own.
66. **The Testing Center ask is carried in part.** The to-do does not tell Ben the suite tests only the optional agent.
67. **Ben's to-do has gaps**: the non-admin user, the MCP sign-in and calls, the removal, the Salesforce case; and
    plan:306 "Say go for the spikes, and for `OPS-37`." is half done. Three things he asked the brain's view on (page 06
    as an appendix, a switch instead of commented-out code, page 07 as a principles page) are recorded as brain
    decisions but never put to him for a yes or no.
68. **The prompt-template page has no wording for a spike that stops short.** BE-33:29 allows "record why and stop at
    the tested seam"; OPS-42 must then say the switch is tested with a stub.
69. **Small document gaps**: the brief says each limit links "the card that owns it" (design:152) in a repo that may go
    public without the cards; a fourth placement (the record page) that no page documents; pages 00 and 04 have no
    See-it part and no stated exemption.

## Org actions against the Approvals table

| Action class | Cards | Row | Reads | Gap, and the finding |
|---|---|---|---|---|
| Deploy to agent-probe: validate, then quick deploy | FE-20, BE-24 to BE-27, BE-29, BE-30, BE-33, BE-35 to BE-37, FE-12 to FE-15, FE-19, OPS-30, OPS-31 | approvals:68 | approved, standing | hand-typed (19); old tests run in it (11) |
| Spike work in agent-probe | OPS-29, BE-21, BE-22, BE-31, BE-32, BE-34, FE-18 | approvals:79 | pending | four are `queued`; three have no hold (2) |
| Agent publish and activate in agent-probe | BE-21, OPS-30; BE-28 parked | approvals:80, :81 | approved with a condition; "not needed" | wrong row cited, two publishes, NO-GO publish has no row (12) |
| Anything in `experimental` | BE-8 | old rows | forbidden | the card is `queued` (1) |
| Testing Center create and run | BE-38; also BE-21 and OPS-30 | approvals:82 | pending | two cards run the spec with no row (14) |
| Agent calls from Apex or preview | BE-21, BE-22, BE-32, BE-34 | approvals:79 | pending | "Agent API" can be read as the REST API (20) |
| MCP server and client app | OPS-31 | approvals:83 | pending | cites row 67 (3) |
| Tests that create and delete a record | FE-14, then FE-21, OPS-35, OPS-36, FE-5 | approvals:84 | pending | cites the standing row; no fallback (4) |
| Live checks that spend model calls and write product rows | BE-29, BE-30, BE-33, BE-35, BE-36, every e2e run | none | no row | (22) |
| Throwaway records by anonymous Apex | BE-22 | none | no row | (45) |
| Flip a custom metadata record and flip it back | BE-24, BE-33, OPS-36 | approvals:68 if done as a deploy | method not stated | (10, 48) |
| Assign a permission set group to the admin | OPS-30, OPS-28 | none | no row | folded into the live-checks row (22) |
| Schedule or run the outcome purge | BE-35 | none | held in prose | new row, not approved (decision 12) |
| Read-only retrieve for the drift check | OPS-46 | none | no row | can pull the consumer key (16) |
| Scratch org from `my-devhub` | OPS-28 | approvals:71 | approved | wrong default hub and org on this Mac (15) |
| Destructive removal | none planned; OPS-54 proposed | approvals:85 | not approved | leftover Apex may force it (11) |
| Paid or trial features | OPS-33 | approvals:86 | not approved | the card is `blocked`, so the tool releases it (2) |
| Changes on this Mac outside the repo | OPS-10 | none | no row | the card is `queued` (1) |
| The non-admin user | FE-5 | approvals:75 | Ben does it | the card is `queued` with no lock (30) |

## Holds, before and after

| Hold | Cards | Today | After the edits | With no answer |
|---|---|---|---|---|
| Ben's go | OPS-50, FE-20, BE-31, BE-32, BE-34 (the roots) | four `queued`, prose holds | `parked`; the brain sets `queued` on his word | nothing runs |
| F17 | BE-27 | prose hold, no default | no hold | an Event |
| The renamed MCP door | OPS-31 | `blocked`, wrong row | `parked`, off the path to the close | the old door stays |
| Record-creating tests | FE-14 | none | conditional line in the card | the test stops at Cancel |
| Testing Center | BE-38 | `blocked`, prose hold | `parked`, off the path to the close | the ladder prints "skipped" |
| The non-admin user | FE-5 | `queued` | `parked`, with blockers and the lock | "not yet proven for a rep" stays |
| Agent tone and actions | BE-28 | `blocked` | `parked` | stays parked |
| Embedded spike; demo data | OPS-33; OPS-34 | `blocked` | `parked` | stay parked |
| Removal of leftovers | OPS-54 (new) | no card | `parked` on approvals:85 | leftovers stay |
| Status-row flips after Ben's manual checks | OPS-53 (new) | no card | `parked` | rows stay "not yet proven" |
| The keep-answer control | FE-23 (new) | no card | `parked` until picked from FE-17's list | not built |
| NO-GO re-cut | the brain | a promise in plan:270 | not needed (finding 5) | n/a |

## Order after the edits

`*` marks a card that holds the org lock. Starred cards run strictly one after another: the next is dispatched only
after the previous one is merged. Unstarred cards use the second worker slot. The order is the same on GO and NO-GO.

- **Before any dispatch (brain, no spend):** the holds, then the card edits in the edit table.
- **Wave 0, on Ben's go:** OPS-50.
- **Wave 1, the rename:** \*FE-20, \*BE-21, read the go/no-go, \*BE-23, \*OPS-30. Second slot after BE-23: OPS-32.
- **Wave 2, first demo:** \*BE-37, \*BE-24, \*OPS-29, \*FE-11, \*FE-12, \*FE-13. Second slot: FE-17.
- **Wave 3, the agent publish and the spikes:** \*OPS-51, \*BE-34, \*BE-31, \*BE-32, \*BE-22, \*FE-18.
- **Wave 4, services:** \*BE-29, \*BE-30, \*BE-25, \*BE-26, \*BE-33, \*BE-35, \*BE-36, \*BE-39.
- **Wave 5, surfaces and tests:** \*FE-22, \*FE-16, \*FE-21, \*FE-15, \*BE-27, \*FE-14, \*FE-19, \*OPS-46. Second slot:
  OPS-38, then OPS-44, OPS-42, OPS-41, OPS-39, OPS-40, OPS-43, OPS-45, OPS-47.
- **Wave 6, the close:** OPS-48, OPS-49, \*OPS-35, \*OPS-52, OPS-36, \*OPS-28.
- **Each on its own approval, never upstream of the close:** BE-38, OPS-31, FE-5, OPS-53, FE-23, OPS-54. **Parked:**
  BE-28, OPS-33, OPS-34.

## Checked and clean

- The `blocked_by` graph has no cycle, as written and after the edits (script over every open card).
- Each card with a component folder in scope has the `jest` gate, each with `force-app` in scope has the `org` gate, and
  BE-23 is the only `org` gate without the lock.
- The chapter cards' red tests are real on main, and so are FE-20's, OPS-46's and BE-38's.
- Both gate scripts and the e2e suite default to `agent-probe`, and a worktree has no `sf` config of its own, so an `sf`
  command with no `-o` fails there instead of reaching `experimental`.
- FE-20's leftover classes are self-contained, its safety line is complete, and it leaves the icon to Ben.
- OPS-31 forbids retrieving or writing the consumer key, signing in and accepting consent. `mcp-door/` holds no consumer
  key value.
- BE-38 bans security cases and new records. OPS-28 names `my-devhub` on its create command and checks hub capacity
  first.
- BE-26 and BE-35 name each system-context use with its reason. BE-27 withholds MCP write tools.
- The brand, voice (never sends by itself) and draft-then-confirm rules agree across every card that touches them. Sizes
  and hotkeys agree between the brief and the cards.
- Tabled items are parked the way Ben said: the embedded surface, demo data, the one-command swap, industry repos.
- The confidential guide and the reference application are named in no card line, plan line or page read for this
  review.

## Unverified

- How the installed copy of the delegation tool treats an unknown status and a parked card. Each is confirmed by a dry
  run when the holds land. `briefExtra` and a new gate id are used only after a yes to decision 15, and are confirmed by
  a dry run then.
- Whether a deploy with RunLocalTests fails on a stale dependent class in agent-probe (finding 11).
- Which bundle `sf agent publish` picks when two share a developer name (finding 13).
- Whether the GitHub markdown API renders Mermaid at all (finding 33).
- Whether a Playwright trace or `sf org display` output carries a token. The edits avoid both.
- Whether the public snapshot keeps `agents/tasks/` (finding 69).
- Per-attempt cost against the ceilings (finding 51).

## Edit table

This is the worklist. This card (OPS-37) changes no card and no plan; the edits land afterwards in two changes: section
A by itself, straight away, then sections B to E together. Nothing is dispatched in between.

- **Where** is a line as of `98dd6c7`, or `fm` for the card's frontmatter. New wording is given in single quotes.
- **Finding** is the number above.
- **Decides**: `brain` means the edit is made unless Ben overrules it; `Ben N` means it follows decision N in the table
  at the top and is written at that decision's default until he answers.

### A. Holds and statuses (first, on their own)

| Target | Where | Change | Finding | Decides |
|---|---|---|---|---|
| BE-15, BE-19 | fm `status` | `parked`. Today it is `superseded`, a word the tool does not know and reads as `queued`. Keep, or add, one line under Why naming what replaced the card | 1 | brain |
| BE-8 | fm `status` | `parked`; one line under Why: 'Superseded by BE-9 (see OPS-14). Never dispatch.' | 1 | brain |
| OPS-10 | fm `status` | `parked`; one line under Why: 'The write-up says partly done; the remaining step is Ben's.' | 1 | brain |
| OPS-29, BE-31, BE-32, BE-34, FE-20 | fm `status` | `parked` until Ben's go | 2 | Ben 1 |
| FE-5 | fm `status` | `parked` until Ben's user exists | 2, 30 | Ben 9 |
| BE-28, OPS-33, OPS-34 | fm `status` | `parked` (they are `blocked` today, which the tool releases) | 2 | brain |
| OPS-31 | fm `status` | `parked` on approvals:83 | 3 | Ben 3 |
| BE-38 | fm `status` | `parked` on approvals:82 | 6 | Ben 5 |
| agents/tasks/README.md | line 32 | The status row lists what the tool does with each word: `queued` and `claimed` dispatch; `blocked` is released when its last blocker is finished; `parked` is refused and never released; a superseded card is `parked` with a line under Why naming what replaced it; any other word is read as `queued` | 1, 2 | brain |
| Check, no file | after the merge | A dry-run dispatch of BE-31 is refused as parked, of BE-21 as blocked, and of BE-8, BE-15 and BE-19 as parked. A script over the real cards lists every card that reads as ready (status `queued` or an unknown word, every blocker merged): the list is empty. Record the results in the change's description | 1, 2 | brain |

### B. Plan documents, and the tool settings on a yes

| Target | Where | Change | Finding | Decides |
|---|---|---|---|---|
| feature-revision-2.md | plan:3, plan:10 | Say the ledger covers sixteen messages and the notes are complete; delete 'More notes are coming' | 64 | brain |
| feature-revision-2.md | ledger, new row F93 | Ben's last message, quoted, with its reading: no notes for page 09 or the README; it is the word for OPS-37 only | 64 | brain |
| feature-revision-2.md | plan:87 (F42) | Closed by F93 | 64 | brain |
| feature-revision-2.md | F06 and F43 rows | Quote Ben's words in full; both are cut short today | 64 | brain |
| feature-revision-2.md | plan:42 (F17) | 'Default: an Event, as Ben said, in one constant. The brain recommends a completed Task; Ben can switch it in one line.' | 42 | Ben 2 |
| feature-revision-2.md | plan:86 (F41) | BE-20 is merged, not running | 57 | brain |
| feature-revision-2.md | plan:129 (F62) | Name FE-22 for the items that move there with the split | 29 | brain |
| feature-revision-2.md | plan:181 (F86) | The access step in each page's Adopt it part belongs to the chapter cards and OPS-48, not OPS-36 | 62 | brain |
| feature-revision-2.md | plan:194 (F92) | Unchanged; the kept open-items review is listed under the brain's decisions as kept by the brain, not asked for | 59 | brain |
| feature-revision-2.md | plan:229 | 'Two agent publishes: the spike copy (BE-21) and the renamed agent (OPS-51).' | 12 | brain |
| feature-revision-2.md | plan:254 | A no, or no answer, on BE-38 needs no hand edits: the ladder, page 08 and the README each carry the fallback line | 6 | brain |
| feature-revision-2.md | plan:260 | Owners named: OPS-48 for pages 12 and 14, OPS-49 for ARCHITECTURE.md | 35, 62 | brain |
| feature-revision-2.md | plan:270 | 'On NO-GO everything is renamed except the agent bundle, its spec and the bundle name in the agent check script. No scope is re-cut.' | 5 | brain |
| feature-revision-2.md | plan:271 | The leftovers list gains the old Apex classes and their tests; OPS-54 removes them on Ben's go | 11 | Ben 6 |
| feature-revision-2.md | 'Decisions the brain made' | Add the eighteen decisions from this page's overrule table, each with its overrule | 63 | brain |
| feature-revision-2.md | 'Decisions the brain made' | Add the dispatch rules: every root card is `parked` until Ben's go; on his word the brain sets the roots to `queued`; an org-lock card is dispatched only after the previous org-lock card is merged; no card parked on its own approval may be upstream of OPS-36 or OPS-28; a card that depends on a spike reads the spike's research page; when BE-31 merges, the brain cuts the build cards it proposes and puts their cost to Ben | 2, 6, 24, 39 | brain |
| feature-revision-2.md | 'Ben's to-do', plan:276 to plan:306 | Rewrite from the decision table at the top of this page, in the same order, with each default. Drop 'and for `OPS-37`'. Add: the non-admin user, the MCP sign-in and one call per tool after OPS-31, the removal of leftovers, filing the Salesforce case, the two optional defaults on this Mac, who supplies `MCP_CONTACT_EMAIL`, and a yes or no on the three views he asked for (page 06 as an appendix, the switch, page 07 as a principles page) | 40, 67 | brain |
| feature-revision-2.md | 'Order', plan:310 to plan:321 | Replace with the waves under 'Order after the edits' | 58 | brain |
| fr2-design.md | design:14 | Add: 'Over MCP the tools are Apex actions; the optional agent is not an MCP tool.' | 9 | Ben 3 |
| fr2-design.md | design:24 | Principle 1 claims what pattern 02 lists as proven; 'any object, any combination' is named as BE-31's question | 39 | brain |
| fr2-design.md | design:34 | Principle 4 says what BE-35 builds: the author sees the text, anyone who can see the account sees type, date and sentiment label, and only the author's own outcomes feed their next conversation in full | 43 | Ben 11 |
| fr2-design.md | design:130 | 'the Apex router picks the action' | 57 | brain |
| fr2-design.md | 'Pattern page shape', design:139 to design:152 | Fix the exact H2 strings: 'The business problem', 'The architecture in a few steps', 'How it works', 'See it', 'Why you can trust it', 'How it scales', 'Adopt it', 'Limits and open items'. The H1 is the title with no number | 33 | brain |
| fr2-design.md | 'Pattern page shape' | Exemptions: page 00 has no See it, Why you can trust it, How it scales or Adopt it part; page 04's See it is a text block; page 06 is a short appendix; page 07 is one screen; page 14 is a placeholder | 33, 69 | brain |
| fr2-design.md | 'Pattern page shape' | The trust part opens with: 'It opens with what runs as the signed-in user and names each system-context use on this path with its reason, or says there is none.' | 33 | brain |
| fr2-design.md | 'Pattern page shape' | Pages never state proof status themselves; they link the README's status rows. Pages name roles, not people. A limit names the open item in words and does not link a card file | 33, 69 | brain |
| fr2-design.md | design:176 | Two publishes, as plan:229 | 12 | brain |
| gtm-burn-plan.md | approvals:62 to :67, :69, :70, :72, :77 | Append '; spent, closed' to each status | 47 | brain |
| gtm-burn-plan.md | Approvals, new row | 'FR2: live checks in `agent-probe` that spend model calls and write the product's own session and outcome rows on existing sample accounts, and assigning the user group to the admin' with status 'pending Ben (brain recommends yes)' | 22 | Ben 1 |
| gtm-burn-plan.md | Approvals, new row | 'FR2: the explorer as an MCP tool for outside clients' with status 'pending Ben' | 9 | Ben 3 |
| gtm-burn-plan.md | Approvals, new row | 'FR2: if the rename is NO-GO, one publish of `Account_Brief` for the new label' with status 'pending Ben' | 12 | Ben 7 |
| gtm-burn-plan.md | Approvals, new row | 'FR2: schedule or run the outcome purge job in `agent-probe`' with status 'not approved; needs Ben's go' | 22 | Ben 12 |
| gtm-burn-plan.md | Approvals, new row | 'FR2: hide the Agentforce icon for reps (an org setting)' with status 'Ben flips it himself, or says go' | 40 | Ben 8 |
| gtm-burn-plan.md | approvals:85 | Status unchanged; name OPS-54 as the card | 11 | Ben 6 |
| gtm-burn-plan.md | Brain runbook, after approvals:192 | 'Before dispatch: find the card's row in the Approvals table. If it does not start with "approved", do not dispatch.' | 2 | brain |
| gtm-burn-plan.md | Brain runbook | 'Every `sf` command carries `-o agent-probe`. An org-lock card is dispatched only after the previous org-lock card is merged.' | 15, 24 | brain |
| gtm-burn-plan.md | approvals:207, approvals:211 | Both checks apply to any card that changes `docs/` or `README.md` or adds a file under `docs/assets/`, not to named cards | 23 | brain |
| gtm-burn-plan.md | Brain runbook | 'Before merging a card that changes `docs/` or `README.md`, run `bash scripts/check-docs.sh` in its worktree: 0 broken.' | 44 | brain |
| `.chassis-delegation.json` | `gateMap` | Only on Ben's yes: add `"docs": "bash scripts/check-docs.sh"`, and add `docs` to the `gate` of every card whose scope names `docs/` or `README.md` | 44 | Ben 15 |
| `.chassis-delegation.json` | `briefExtra` | Only on Ben's yes: the org-rules line from section D, one rule per line, so every brief carries it, including cards cut later | 18, 19 | Ben 15 |
| Check, no file | after the merge | The graph script, run over the real cards, reports no cycle and no own-approval card upstream of the close. The ready-list script from section A still prints an empty list. After a yes to decision 15, a dry-run dispatch of one org card shows the org-rules lines in its brief | 2, 6, 18 | brain |

### C. New cards

Every new card follows the card format (frontmatter, Why, Done when), has `budget: 2-attempts`, and names the link check
in its gates line if its scope names `docs/` or `README.md`. In the table, 'link check' means that line plus the brain's
own run before the merge; it becomes the `docs` gate id on a yes to decision 15. A card that holds the lock carries the
org-rules line from section D. Its blockers are in section E.

| Card | What it is | Scope | Gate, lock, spend | Status | Done when, in short | Finding |
|---|---|---|---|---|---|---|
| OPS-50 | The `spikes` package directory | `sfdx-project.json`, `tests/test_sfdx_project.py`, `spikes/README.md` | test; no lock; 3; economy | parked until the go | One non-default package directory named `spikes`; the test allows it; the README says nothing under it is deployed by the quick start. No org step | 27 |
| OPS-51 | Publish, activate and prove the optional agent | `docs/research/fr2-agent-publish.md` | test, agent, link check; lock; 10 | blocked | Reads approvals:80 first and carries Ben's stop condition. On GO: one publish and one activation of `Customer_Summary`. On NO-GO: publishes only if the NO-GO row is approved, otherwise records that the agent keeps its old label. Runs the spec only if approvals:82 is approved, otherwise one preview turn. Confirms, read-only, that the active version's actions name the renamed classes | 12, 13, 14, 26 |
| BE-39 | The card contract in the Apex services | the summary, explorer and action result classes and their tests; `docs/research/fr2-card-contract-apex.md` | test, org, link check; lock; 12 | blocked | Each service returns the typed contract from FE-18's research page next to its existing text. Existing signatures stay (the old-Apex sentence). The research page states exactly what an MCP client receives | 34 |
| FE-22 | History, the scope chip and card rendering in the conversation | the conversation component folder; `e2e/**` | test, jest, org; lock; 10 | blocked | Takes FE-12:26 (history), FE-12:28 (scope is visible) and FE-12:31 (cards and rich text). Renders BE-39's contract; an unknown card type falls back to text | 29, 34 |
| FE-23 | A control that keeps an answer | the conversation component folder | test, jest, org; lock; 8 | parked until Ben picks it from FE-17's list | One control on an answer writes a Saved answer outcome through BE-35; only its author sees the text | 34, 63 |
| OPS-48 | The sweep: pages 09 to 14 and the pattern index | `docs/patterns/**`, `tests/test_pattern_pages.py` | test, link check; no lock; 20 | blocked | Pages 09 to 13 follow the full page shape with the theme block, the trust sentence and a way-back line; page 14 stays a placeholder. A new `docs/patterns/README.md` index fixes titles and reading order. Page 09 says the org runs the door under the old names until OPS-31, and each of its open items is closed or owned. Page 12 shows the timeline; pages 12 and 14 link chapter 00; page 13 is rewritten from FE-14's screens. Each Adopt it part has the access step. One test runs the shared shape helper over every page | 7, 33, 35, 62 |
| OPS-49 | Rewrite `docs/ARCHITECTURE.md` | `docs/ARCHITECTURE.md`, `tests/test_architecture_doc.py` | test, link check; no lock; 6 | blocked | New names; three doors and the optional agent; the system-context uses listed from BE-37's research page; the pattern list follows the index; links chapter 00 and page 14 | 7 |
| OPS-52 | Captures and the See it part of every page | `e2e/capture/**`, `docs/assets/**`, the See it part of each page under `docs/patterns/` | test, link check; lock; 15 | blocked | An exact capture list per page, every still and GIF through the capture kit. No deploy and no settings flip: the brand before-and-after is BE-24's capture. The MCP door is shown as the unauthenticated call in a text block labelled 'not a real tool call' | 10, 23 |
| OPS-53 | Flip the README's status rows after Ben's manual checks | `README.md`, `docs/patterns/09-outside-door-mcp.md` | test, link check; no lock; 4; economy | parked until Ben reports a check | For each check Ben reports (the MCP sign-in and one call per tool, the microphone, VoiceOver, the non-admin run) the row changes from 'not yet proven' to the result and its date. Nothing else changes | 9, 33 |
| OPS-54 | Remove the old Account Brief leftovers from agent-probe | `docs/research/fr2-leftovers-removal.md`, `manifest/destructive/**` | test, link check; lock; 10 | parked on approvals:85 | Reads approvals:85 first. Lists, read-only, everything in the org under the old names that the repo no longer has. Deactivates the old agent, then removes its actions, classes, tests, component, permission sets and the old MCP server and app in one destructive deploy, as a validate and then a quick deploy. Never touches a `Customer_Summary` component. Records what was removed and what could not be | 11 |

### D. Existing cards

Rows that apply to several cards come first.

| Card | Where | Change | Finding | Decides |
|---|---|---|---|---|
| OPS-29, BE-21, BE-22, BE-31, BE-32, BE-34, FE-18 | first Done-when line | 'Read the row "FR2: spikes in `agent-probe`" in the Approvals table first. If its status does not start with "approved", change nothing in the org and hand back.' It replaces the 'Dispatched only after' bullets at BE-31:24, BE-32:24, BE-34:24 and FE-18:24 | 2 | brain |
| BE-29, BE-30, BE-33, BE-35, BE-36, FE-16 | first Done-when line | The same sentence for the new live-checks row; and: 'Name the existing sample account you used and record how many session and outcome rows the run wrote.' | 22 | Ben 1 |
| BE-24, BE-29, BE-30, BE-33, BE-35, BE-36, BE-37 | new line | 'The old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class.' | 11 | Ben 6 |
| FE-12, FE-13, FE-14, FE-15, FE-19, OPS-35 | FE-12:32, FE-13:29, FE-14:27, FE-15:28, FE-19:27, OPS-35:26 | 'Every still and GIF is taken through e2e/capture/kit.js.' | 23 | brain |
| FE-12 to FE-16, FE-19, FE-20, FE-21, OPS-30 | the e2e line | 'Paste the Playwright summary line in the hand-back.' | 44 | brain |
| Every card whose scope names `docs/` or `README.md` | the gates line in Done when | Name `bash scripts/check-docs.sh` (0 broken) where it is missing | 44 | brain |
| Every card that holds the org lock (section E) | new Done-when line, the same on each | 'Org rules: `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back.' | 18, 19 | brain |
| OPS-38 to OPS-45, OPS-47 | the trust part | The trust sentence from the design brief; the page's test calls the shared helper `tests/pattern_shape.py` (OPS-41 for the parts it has) | 33 | brain |
| OPS-38, OPS-39, OPS-40, OPS-43 | OPS-38:28, OPS-39:27, OPS-40:27, OPS-43:26 | The See it images are OPS-52's, not OPS-36's | 10 | brain |
| OPS-38 to OPS-45, OPS-47 | fm `blocked_by` | Each waits for the builds it describes (section E) | 33 | brain |
| BE-32, OPS-38, OPS-41 | BE-32:24, OPS-38:23, OPS-41:23 | Read ledger rows F60 to F66 and the design brief; drop the gitignored file | 20 | brain |
| FE-19, BE-36, FE-15 | FE-19:26, BE-36:27, FE-15:26 | 'Use only existing sample data and outcomes written by real summaries. Never insert or backdate a record for a capture; show the empty state instead.' | 46 | brain |
| FE-14, FE-15, FE-19 | the e2e line | Tag one spec for FE-21's smoke subset | 56 | brain |
| BE-21, BE-22, FE-18, OPS-29 | the research page line | The page ends with an 'Undo' list of everything the card left in agent-probe | 50 | brain |
| BE-21 | BE-21:25 | The package directory is OPS-50's | 27 | brain |
| BE-21 | BE-21:26 | Cite approvals:80 by name, with Ben's stop condition and the validate-then-quick-deploy method | 12 | brain |
| BE-21 | BE-21:27 | Delete '(or the existing agent spec, run once)' | 14 | brain |
| BE-21 | new line | On NO-GO, delete nothing in the org | 50 | brain |
| BE-22 | fm `title`, BE-22:20 | The title ends 'from the panel and MCP'; delete the question about the agent handing a draft back | 57 | brain |
| BE-22 | BE-22:24 | Drop the class FE-20 deletes from the read-first list | 54 | brain |
| BE-22 | BE-22:28 | 'Run every write inside a savepoint and roll it back. Never update an existing record. No test class that reads org data.' The package directory is OPS-50's | 45, 27 | brain |
| BE-23 | fm | `resources: [org-live]`; scope gains `jest.config.js`, `playwright.config.js` and `spikes/rename/**`; forbid names the other spike folders one by one | 25, 13 | brain |
| BE-23 | BE-23:14 | The red test excludes the historical folders, `docs/assets`, image alt text, link text that points into a historical folder, and on NO-GO the agent bundle, its spec and the agent check script. A second test fails if two bundles are named `Customer_Summary` | 5, 13, 36 | brain |
| BE-23 | BE-23:26 | NO-GO: 'rename everything as on GO except the agent bundle's developer name and folder, its spec's subject name and the bundle name in scripts/agent-check.sh' | 5 | brain |
| BE-23 | BE-23:27 | Delete the clause on Apex that names the agent; add 'after FE-20 no Apex names the agent; list any that does'. Replace the spikes clause with 'delete spikes/rename/ in this card' | 13, 37 | brain |
| BE-24 | BE-24:20, BE-24:28 | Tone in the agent is the parked BE-28 | 57 | brain |
| BE-24 | BE-24:27 | The company name shows in the empty state and is passed to the summary and explorer prompts; the logo shows in the conversation header on every surface | 41 | brain |
| BE-24 | BE-24:28, BE-24:29 | Each flip of the brand record is its own validate and quick deploy; the hand-back's first line says whether the org is back to Default | 48 | brain |
| BE-25 | fm scope; BE-25:25 | Scope gains `tests/test_permission_sets.py`; `lastSummary` is the running user's own | 25, 65 | brain |
| BE-26 | fm scope; BE-26:26 | Scope gains `tests/test_permission_sets.py`; the data-access set grants the new class | 25 | brain |
| BE-27 | BE-27:20 | Delete the F17 hold | 6, 42 | Ben 2 |
| BE-27 | BE-27:25 | Log a call writes an Event; the choice is one constant with a comment that names F17 | 42 | Ben 2 |
| BE-27 | fm scope | Gains `tests/test_permission_sets.py`, the action prompt's static resource and its prompt-setting record | 25, 32 | brain |
| BE-27 | BE-27:26 | 'The undo token carries the previous values itself; nothing is stored.' Undo is for updates only | 32, 63 | brain |
| BE-28 | BE-28:20 | Parked by status; blockers as section E | 2 | brain |
| BE-30 | fm scope; BE-30:25 | Scope gains `tests/test_explore_prompt.py`; 'the panel and the optional agent get it; MCP gets it only if the ask tool is approved' | 25, 9 | Ben 3 |
| BE-31 | BE-31:27 | Add long-text filters to the combinations it tests | 62 | brain |
| BE-32 | BE-32:25 | 'from anonymous Apex with the generateAiAgentResponse invocable action; never the REST Agent API, a client app or a consumer key' | 20 | brain |
| BE-32 | BE-32:29 | 'No deploy. The only data written is the product's own session rows; record how many.' | 20, 22 | brain |
| BE-33 | fm `spend`; BE-33:29 | Spend 20; a settings flip for the proof is a validate and a quick deploy, and is flipped back | 51, 48 | brain |
| BE-34 | BE-34:27 | The same wording as BE-32:25 | 20 | brain |
| BE-35 | fm scope | Gains `tests/test_permission_sets.py` | 25 | brain |
| BE-35 | BE-35:25 | Another rep sees a fixed phrase for the kind of action, and its date; no title, no record link | 21 | brain |
| BE-35 | BE-35:26 | Never run or schedule the purge batch in agent-probe | 22 | Ben 12 |
| BE-35 | BE-35:28 | The invocable accepts a Saved answer only and never the sentiment fields; it is not an MCP tool in FR2. `remove` runs in system context under a BE-37 marker after checking the author | 21 | brain |
| BE-35 | BE-35:29 | Context for a non-author is type and date only. The MCP proof applies only if the ask tool is approved | 21, 9 | brain |
| BE-35 | BE-35:30 | Kept; recorded under the brain's decisions | 63 | brain |
| BE-38 | BE-38:24, BE-38:27 | The row check replaces the hold bullet; '16-case'; the developer name comes from docs/research/fr2-rename-go.md | 57 | Ben 5 |
| FE-5 | fm | `resources: [org-live]`; blockers as section E | 30 | Ben 9 |
| FE-5 | FE-5:23, FE-5:24 | New names; add: the rail opens, a draft card and Cancel, another rep's outcome shows no text, the built-in panel does not offer our agent | 30, 40 | brain |
| FE-5 | FE-5:28 | 'Check the alias with sf alias list. Never print sf org display output.' | 15 | brain |
| FE-12 | fm | Spend 15; scope drops page 03; blockers as section E | 29 | brain |
| FE-12 | FE-12:25 | 'FE-14 adds the action chips'; they stay hidden behind a flag until then. The logo shows in the header. The public interface is stated and tested: `@api recordId`, `@api sessionId`, `@api focusComposer()` and the event `sessionchange` | 29, 41, 57 | brain |
| FE-12 | FE-12:26, FE-12:28, FE-12:31 | Move to FE-22. What stays says 'the existing ask and explorer paths' | 29, 57 | brain |
| FE-13 | fm scope; FE-13:25 | Scope gains `tests/test_app.py`; the hotkey comes from docs/research/fr2-surfaces-spike.md | 25, 53 | brain |
| FE-14 | FE-14:27 | 'If the Approvals row on record-creating tests is approved: confirm a task on an existing sample account and remove the task and its Action outcome in teardown. If not: stop at the draft card and Cancel.' Never create an account or contact | 4 | Ben 4 |
| FE-14 | FE-14:28 | Cite the record-test row for the test and the standing row for the deploy | 4 | brain |
| FE-14 | fm scope | Gains the manifest; page 13 is OPS-48's | 35 | brain |
| FE-15 | fm scope; FE-15:25 | Scope gains `tests/test_app.py`; the rail header shows its key and the logo; the hotkey comes from the spike's research page | 25, 41, 53, 60 | brain |
| FE-16 | FE-16:25 | Delete; FE-21 owns the hotkey branches | 28 | brain |
| FE-16 | FE-16:28 | 'No deploy. Writes only the product's own session rows.' | 22 | brain |
| FE-17 | FE-17:23 | Read page 11 after FE-11 (section E) | 54 | brain |
| FE-18 | fm scope; FE-18:29 | Scope drops `sfdx-project.json` and its test. 'Do not edit sfdx-project.json. Run Jest with an explicit roots argument that names the spike folder. The contract goes into the research page; BE-39 and FE-22 build from it.' | 27, 34 | brain |
| FE-19 | FE-19:27 | 'Both expose the record-page target. Placing them on a page is a step in the swap guide, not in this card.' | 32 | brain |
| FE-20 | FE-20:24 | Delete the hold bullet; the status holds it | 2 | brain |
| FE-20 | FE-20:27 | Unchanged in substance: the icon stays Ben's own click unless the new row is approved | 40 | Ben 8 |
| FE-21 | FE-21:25 | 'with screenshots and console logs on failure; tracing stays off' | 28 | brain |
| FE-21 | FE-21:26 | The keys come from the spike's research page | 53 | brain |
| OPS-28 | OPS-28:28 | Every scratch-org command carries `--target-dev-hub my-devhub` | 15 | brain |
| OPS-28 | OPS-28:30 | 'Export SF_TARGET_ORG and SF_E2E_ORG as ga-scratch for the whole run.' | 15 | brain |
| OPS-28 | OPS-28:33 | New names; the agent steps are the optional track | 38 | brain |
| OPS-28 | OPS-28:34; fm scope | It flips its own README status row; the link check in its gates line | 33, 38 | brain |
| OPS-29 | fm scope; OPS-29:24 | Scope drops `sfdx-project.json` and its test; the package directory is OPS-50's | 27 | brain |
| OPS-29 | OPS-29:30 | Cite the spikes row, not only the standing row | 2 | brain |
| OPS-30 | fm | Spend 15; forbid allows `force-app` fixes, 'each listed in the hand-back' | 26 | brain |
| OPS-30 | OPS-30:25, OPS-30:26 | The publish, the activation and the agent proof move to OPS-51 | 12, 26 | brain |
| OPS-30 | OPS-30:27 | Add: record which org-only classes and tests remain | 11 | brain |
| OPS-30 | OPS-30:28 | Delete 'the panel's agent call reaches Customer_Summary' and the agent spec run | 14, 37 | brain |
| OPS-31 | OPS-31:13 | A red test that is red after BE-23 | 57 | brain |
| OPS-31 | OPS-31:25 | Cite approvals:83. The tools are Apex actions: resolve and summary, plus ask anything only if the explorer row is approved. The agent is not a tool. `tests/test_mcp_door.py` follows. Stop if `MCP_CONTACT_EMAIL` is not set. Never touch `experimental` | 3, 9 | Ben 3 |
| OPS-32 | OPS-32:25 | Drop the ARCHITECTURE.md link; OPS-49 owns that file | 7 | brain |
| OPS-33 | OPS-33:27 | 'never touch experimental', with no exception | 49 | brain |
| OPS-35 | fm | Blockers as section E | 6, 8 | brain |
| OPS-35 | OPS-35:24 | Drop the agent test skill | 17 | brain |
| OPS-35 | OPS-35:25 | 'F01 to F93'; a row whose card has not merged reads 'not landed' | 8 | brain |
| OPS-35 | OPS-35:26 | Add the rail's context sections, the outcomes timeline, the sentiment chart and the draft card (through Confirm if the record-test row is approved, otherwise to Cancel) | 8 | brain |
| OPS-35 | OPS-35:27 | 'the compact window, the rail and MCP'; one line if the MCP door is not renamed yet | 8, 9 | brain |
| OPS-35 | OPS-35:28 | Ban agent tests and security tests of any kind. Review scripts are not named `*.spec.js`. Add one 'Left in agent-probe' table built from every research page's Undo list | 17, 50 | brain |
| OPS-36 | fm | No lock; spend 15; scope is `README.md` and `tests/test_readme_fr2.py`; a real red test line; blockers as section E | 10 | brain |
| OPS-36 | OPS-36:24 | Drop the F42 clause | 64 | brain |
| OPS-36 | OPS-36:25 | The workbook table follows the index page; the proof table links the build review; the heading 'See it in 5 minutes' stays; the quick start deploys every folder except the agent bundle, and a test compares its list with the folders on disk | 31 | brain |
| OPS-36 | OPS-36:26 | The same render check as the chapter cards | 33 | brain |
| OPS-36 | OPS-36:27, OPS-36:28, OPS-36:31, OPS-36:32 | Move to OPS-52 | 10 | brain |
| OPS-36 | OPS-36:29 | Read docs/research/fr2-quick-start-change.md | 10 | brain |
| OPS-36 | OPS-36:33 | Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven | 39 | brain |
| OPS-36 | OPS-36:34 | The Testing Center count appears only if the suite ran; otherwise 'not run in this build' | 6 | Ben 5 |
| OPS-38 | fm scope | Gains `tests/pattern_shape.py` | 33 | brain |
| OPS-38 | OPS-38:24 | The exact headings from the design brief; a sentence on how easy the pattern is to take | 33, 62 | brain |
| OPS-38 | OPS-38:26 | The render check must first be shown to fail on a broken diagram; the method goes into `_diagram-theme.md` | 33 | brain |
| OPS-39 | OPS-39:24 | The exact headings | 33 | brain |
| OPS-40 | new line | The card catalog from FE-18's research page | 34 | brain |
| OPS-41 | OPS-41:24 | 'State each limit plainly with its number, or "not measured" with BE-32's reason.' Keep a short section on when the standard chat fits | 55, 61 | brain |
| OPS-41 | OPS-41:25 | Describe the contract as built (BE-39, FE-22) and what an MCP client receives | 34 | brain |
| OPS-41 | OPS-41:26 | The same guard as OPS-36:33 | 39 | brain |
| OPS-42 | OPS-42:24 | If BE-33 stopped at the tested seam, say the switch is tested with a stub | 68 | brain |
| OPS-42 | new line | See it is the prompt-try output as a text block | 69 | brain |
| OPS-43 | new line | One line on the record-page target | 69 | brain |
| OPS-44 | OPS-44:24 | 'The file name is final.' | 33 | Ben 10 |
| OPS-44 | fm scope; OPS-44:26 | The quick-start change is written to docs/research/fr2-quick-start-change.md, which joins the scope | 10 | brain |
| OPS-45 | OPS-45:24, OPS-45:25 | 'The file name is final.' The page links the README's status rows instead of stating 'not yet proven' | 33 | brain |
| OPS-46 | fm | Blockers as section E | 6 | brain |
| OPS-46 | OPS-46:25 | The `--agent` rung runs scripts/agent-test.sh when it exists, otherwise prints 'skipped: agent suite not built' | 6 | Ben 5 |
| OPS-46 | OPS-46:27 | The drift check covers `force-app` only, never retrieves a client app or an MCP server, and works in a temporary folder outside the repo; the test checks the script names none of those types | 16 | brain |
| OPS-47 | OPS-47:24 | If scripts/agent-test.sh does not exist, the Testing Center section says the suite is not run in this build | 6 | Ben 5 |

### E. Dependencies, lock and spend

Generated by script from the cards at `98dd6c7` and the proposed graph. A blocker in bold is new. `parked (until the
go)` marks a root; `parked (own approval)` marks a card that waits on its own row and is never upstream of the close.
OPS-29 is parked in section A and becomes `blocked` here once OPS-50 exists.

| Card | Status now | Status after | `blocked_by` after (new in bold) | Dropped | Org lock | Spend |
|---|---|---|---|---|---|---|
| BE-21 | blocked | blocked | **OPS-50** | OPS-29 | yes | 20 |
| BE-22 | blocked | blocked | **OPS-50** | OPS-29 | yes | 20 |
| BE-23 | blocked | blocked | BE-21, FE-20 | none | no → yes | 25 |
| BE-24 | blocked | blocked | OPS-30, BE-37 | none | yes | 25 |
| BE-25 | blocked | blocked | OPS-30, BE-37, **BE-24** | none | yes | 12 |
| BE-26 | blocked | blocked | OPS-30, BE-30, BE-34, **BE-25** | none | yes | 15 |
| BE-27 | blocked | blocked | BE-22, OPS-30, BE-35 | none | yes | 20 |
| BE-28 | blocked | parked (own approval) | BE-27, BE-24, **OPS-51**, BE-30, FE-18, BE-35 | OPS-30 | yes | 20 |
| BE-29 | blocked | blocked | OPS-30, BE-24, BE-37 | none | yes | 10 |
| BE-30 | blocked | blocked | OPS-30, BE-37, **BE-24** | none | yes | 12 |
| BE-31 | queued | parked (until the go) | none | none | yes | 10 |
| BE-32 | queued | parked (until the go) | none | none | yes | 10 |
| BE-33 | blocked | blocked | OPS-30, BE-24, BE-29, BE-37 | none | yes | 12 → 20 |
| BE-34 | queued | parked (until the go) | none | none | yes | 8 |
| BE-35 | blocked | blocked | OPS-30, BE-29, BE-30, BE-34, **BE-26** | none | yes | 15 |
| BE-36 | blocked | blocked | BE-35, BE-33 | none | yes | 10 |
| BE-37 | blocked | blocked | OPS-30 | none | yes | 6 |
| BE-38 | blocked | parked (own approval) | **OPS-51**, BE-29, BE-30 | OPS-30 | yes | 8 |
| BE-39 | new | blocked | FE-18, BE-30 | none | yes | 12 |
| FE-5 | queued | parked (own approval) | **OPS-30**, **FE-14**, **FE-15**, **FE-19**, **BE-33** | none | no → yes | 10 |
| FE-11 | blocked | blocked | BE-23, OPS-29 | none | yes | 10 |
| FE-12 | blocked | blocked | OPS-30, BE-24, FE-11 | BE-26, FE-18 | yes | 25 → 15 |
| FE-13 | blocked | blocked | FE-12, OPS-29 | none | yes | 15 |
| FE-14 | blocked | blocked | BE-27, **FE-22**, **FE-15** | FE-12 | yes | 20 |
| FE-15 | blocked | blocked | **FE-22**, FE-13, OPS-29, BE-25, BE-26, **FE-21** | FE-12 | yes | 25 |
| FE-16 | blocked | blocked | FE-13 | none | yes | 6 |
| FE-17 | blocked | blocked | OPS-29, **FE-11** | none | no | 6 |
| FE-18 | blocked | blocked | OPS-29 | none | yes | 12 |
| FE-19 | blocked | blocked | BE-35, BE-36, FE-15, FE-18, **FE-14** | none | yes | 10 |
| FE-20 | queued | parked (until the go) | none | none | yes | 8 |
| FE-21 | blocked | blocked | FE-12, FE-13, FE-20, **FE-16** | none | yes | 6 |
| FE-22 | new | blocked | FE-12, BE-26, FE-18, BE-39 | none | yes | 10 |
| FE-23 | new | parked (own approval) | FE-22, BE-35 | none | yes | 8 |
| OPS-28 | blocked | blocked | OPS-36 | none | yes | 30 |
| OPS-29 | queued | blocked | **OPS-50** | none | yes | 25 |
| OPS-30 | blocked | blocked | BE-23 | none | yes | 25 → 15 |
| OPS-31 | blocked | parked (own approval) | **OPS-51** | OPS-30 | yes | 15 |
| OPS-32 | blocked | blocked | BE-23 | none | no | 4 |
| OPS-33 | blocked | parked (own approval) | OPS-32 | none | yes | 25 |
| OPS-34 | blocked | parked (own approval) | BE-24 | none | no | 5 |
| OPS-35 | blocked | blocked | FE-14, FE-15, **FE-16**, **FE-19**, **FE-21**, **BE-33**, **BE-36**, FE-20, **OPS-46** | FE-13, OPS-31 | yes | 20 |
| OPS-36 | blocked | blocked | OPS-35, OPS-32, FE-20, OPS-38, OPS-39, OPS-40, OPS-41, OPS-42, OPS-43, OPS-44, OPS-45, OPS-47, **OPS-48**, **OPS-49**, **OPS-52** | OPS-31 | yes → no | 25 → 15 |
| OPS-38 | blocked | blocked | BE-23, BE-24, BE-29, **BE-30**, **BE-33**, **BE-35**, **BE-36** | none | no | 6 |
| OPS-39 | blocked | blocked | OPS-38, BE-30, BE-31, FE-20, **BE-26**, **BE-35**, **FE-22**, **FE-14** | none | no | 6 |
| OPS-40 | blocked | blocked | OPS-38, FE-12, FE-13, FE-16, FE-17, FE-18, OPS-41, FE-20, **FE-22**, **FE-14**, **FE-15** | none | no | 6 |
| OPS-41 | blocked | blocked | OPS-38, BE-32, FE-18, **FE-22**, **BE-39** | none | no | 6 |
| OPS-42 | blocked | blocked | OPS-38, BE-33, **BE-36** | none | no | 8 |
| OPS-43 | blocked | blocked | OPS-38, BE-34, BE-26, BE-35, BE-36, FE-19 | none | no | 6 |
| OPS-44 | blocked | blocked | OPS-38, FE-20, **OPS-51**, BE-34 | OPS-30 | no | 5 |
| OPS-45 | blocked | blocked | OPS-38, OPS-40, BE-37, BE-26, BE-33, BE-35, FE-20 | none | no | 4 |
| OPS-46 | blocked | blocked | OPS-30, FE-21 | BE-38 | yes | 5 |
| OPS-47 | blocked | blocked | OPS-38, OPS-46, FE-21, FE-20, OPS-44 | BE-38 | no | 6 |
| OPS-48 | new | blocked | OPS-38, OPS-39, OPS-40, OPS-41, OPS-42, OPS-43, OPS-44, OPS-45, OPS-47, OPS-32, BE-24, FE-11, FE-15, FE-19, BE-27, FE-14 | none | no | 20 |
| OPS-49 | new | blocked | OPS-48 | none | no | 6 |
| OPS-50 | new | parked (until the go) | none | none | no | 3 |
| OPS-51 | new | blocked | OPS-30 | none | yes | 10 |
| OPS-52 | new | blocked | OPS-48 | none | yes | 15 |
| OPS-53 | new | parked (own approval) | OPS-36 | none | no | 4 |
| OPS-54 | new | parked (own approval) | OPS-51 | none | yes | 10 |

## Appendix: the coverage table

Every ask in Ben's sixteen messages, in his words, traced to the ledger row and the card line that carries it: 177 asks,
of which 148 are carried, 25 are partial, 2 have only a spike behind them, 1 was dropped and 1 was over-read. This is the
coverage reviewer's table as handed back, checked by the brain against the cards. In this table `OPS-36 l24` is line 24
of the card OPS-36, the line cited as `OPS-36:24` elsewhere on this page, and "plan line" is a line of
feature-revision-2.md. "[reference app]" and "[reference guide]" stand in for two names Ben used that stay out of the
repo. Every partial verdict has a row in the edit table above, or a default in the decision table at the top of this page.

### Verdict rule

- **carried**: a Done-when line of a card that is not parked and is not a spike builds it or writes it. An item Ben
  tabled himself, parked the way he asked, also counts as carried.
- **partial**: a carrying line exists, but part of the ask is missing, or it hangs on something no card or to-do owns.
- **only a spike**: only a discovery or spike card carries it, so nothing in FR2 builds it.
- **dropped**: no ledger row and no carrying line.
- **over-read**: the plan does work the words do not support (here: withdrawn text that still drives cards).

### Message 1

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 1.01 | "providing feedback on each page, starting with the README" | F42 (open) | OPS-36 l24 ("every F42 note Ben has added by dispatch time") | partial: no README note ever arrived; Message 16 closes the notes; F42 is still "open" and plan line 10 still says "More notes are coming" |
| 1.02 | "tactically update certain sections and add additional features to align with ... go-to-market strategy" | F39, F43 | OPS-36 l25 | carried |
| 1.03 | "create a generic agent that we can distribute to other customers" | F01 | OPS-36 l25; BE-24 l25 | carried |
| 1.04 | "take this as an accelerator, understand what needs to be built, and then bring it to other users, other use cases" | F01 | OPS-36 l25; fr2-design 'Pattern page shape' step 7 (Adopt it); OPS-38 l25 | carried |
| 1.05 | "think about Agentforce a little bit differently" | F01 | OPS-41 l24 | carried |
| 1.06 | "one agent with a lot of sub-agent capabilities ... one branded agent or one agentic capability top of mind" | F02 | fr2-design lines 8 to 13; FE-12 l25; OPS-36 l25 | carried |
| 1.07 | "Much like how Claude can handle and route different requests" | F02 | FE-14 l25 (draftFromText, then 'not an action' goes down the ask path); BE-27 l26 | carried |
| 1.08 | "instead of account brief, customer summary" | F03 | BE-23 l27, l28; OPS-30 l26 | carried |
| 1.09 | "can be used in multiple different places" | F04 | FE-13 l25; FE-15 l25; OPS-31 l25 | carried |
| 1.10 | "and can be consumed by MCP" | F04 | OPS-31 l25, l28 | partial: OPS-31 l28 leaves "still unproven: a real tool call"; ask-anything reaches MCP only through the agent tool; no card and no to-do makes the first call |
| 1.11 | "Users respond better to something that's branded ... more seller-friendly" | F05 | BE-24 l25, l27 | carried |
| 1.12 | "a salesperson can come in, grab the repo, spin it up" | F06 | OPS-36 l25 (quick start); OPS-28 l30 | carried |
| 1.13 | "replace the agent name placeholder with the customer name and customer information or prospect information" | F06 (quote cut after "customer name") | BE-24 l25, l27, l28 | partial: the company name gets a field and no place on screen; wider prospect information is the tabled demo data (F10) |
| 1.14 | "generate a compelling demo just based on easy placeholder swap outs" | F06 | BE-24 l28 (swap guide, before and after pair); OPS-36 l25 | carried |
| 1.15 | "introduce several different layers of agentic capability" | F12 | fr2-design lines 8 to 13; FE-12 l25 | carried |
| 1.16 | "pop-out needs to move from the bottom left to the bottom right-hand part of the screen" | F20 | OPS-29 l25; FE-13 l25 | carried (Message 2 lets the spike decide) |
| 1.17 | "Right rail has always been where agents pop out and communication happens" | F20 | OPS-29 l25 | carried |
| 1.18 | "We want our agent on the command press key ... to pop out from there" | F21 | FE-13 l25 | carried |
| 1.19 | "the view is really condensed and really does not scale well" | F22 | FE-13 l25 (about 420 px); FE-12 l25 | carried |
| 1.20 | "feel a little bit more like Claude ... Reference [reference app] ... styling and design" | F22 | fr2-design 'Conversation design'; FE-12 l25 | carried |
| 1.21 | "Definitely not opposed to the compact agent ... one of the agent surfaces" | F23 | FE-13 l25 | carried |
| 1.22 | "pop out with a button click to take up a larger part of the screen. That's going to be very important" | F24 | FE-13 l26 (expand); FE-15 l25, l26 | carried |
| 1.23 | "I like the slide in and slide out, and we want to be able to demonstrate how that can be done" | F24 | FE-13 l28 (motion); FE-15 l28 (GIF: open, ask, expand from compact) | carried |
| 1.24 | "a little microphone button in all of our windows and widgets" | F13 | FE-12 l25 (mic in the shared composer); FE-11 l25 | carried |
| 1.25 | "able to capture voice with our custom component" | F13 | FE-11 l25 | carried |
| 1.26 | "Sellers don't want to type. They shouldn't need to type." | F13 | FE-11 l25; FE-14 l25 ("typed or spoken") | carried (the real mic check is Ben's, by hand) |
| 1.27 | "verbally or through the chat create follow-up tasks, events, those types of things" | F15 | BE-27 l25, l26; FE-14 l25 | carried |
| 1.28 | "a consideration for our architecture ... along the parallel path of like ask any question" | F15 | BE-22 l25, l26; BE-27 l26; OPS-36 l26 | carried |
| 1.29 | "more about the surface and the interaction than ... underlying architecture, though you may provide some different feedback" | none (nearest F28) | fr2-design 'Surfaces' ("All of them use one conversation component") | carried |
| 1.30 | "a highlighted command K key to open up the agent. We want that, maybe through a different command structure, to also be here" | F21 (filed under the compact window; the second sentence is cut) | FE-13 l25 (key hint on the compact launcher); FE-15 l25 (no hint for the rail's key) | partial: Ben says it in the rail paragraph; the rail's hotkey has no visible hint |
| 1.31 | "the agent is hidden, sellers press a button, the agent pops open" | F25 | OPS-29 l28; FE-15 l25 | carried |
| 1.32 | "pushes the content from the right-hand side of the screen to the left" | F25 | OPS-29 l26; FE-15 l25 | carried (slide-over fallback accepted in Message 2) |
| 1.33 | "It can also be a hover over, or there could be like a minimize" | F26 | OPS-29 l26 (c); FE-15 l25 | carried |
| 1.34 | "a full experience that feels like Claude built into or overlaying Salesforce" | F27 | FE-15 l26; FE-12 l25 | carried |
| 1.35 | "meaningful conversations ... perform briefs, perform follow-ups, questions, and create tasks and action items" | F27 | FE-15 l26; BE-30 l25; FE-14 l25 | carried |
| 1.36 | "These aren't competing ... surfaces ... a couple of different levels of variability would be really good" | F28 | OPS-36 l25 ("the three surfaces ... and when to use each") | carried |
| 1.37 | "more context for session history, open deals, and ... other prefetched information" | F29 | BE-25 l25; FE-15 l26 | carried |
| 1.38 | "that the user might want to interact with very quickly" | F29, F31 | FE-15 l26 (click opens the record; prefetch on key press), l27 | carried |
| 1.39 | "bringing that surface to light in a larger window automatically with the button press" | F30 | FE-15 l25 | carried |
| 1.40 | "streamlined, it feels good to use, and we can keep things moving fast and feeling fluid" | F31 | FE-15 l27; FE-13 l28 | carried |
| 1.41 | "show that this customer has had this interaction through history" | F32 (open) | BE-26 l26 (own-only); FE-19 l25 (others see type, date and label) | partial: both memories default to author-only; Q7 was never answered |
| 1.42 | "comfortable, not too tight, and feel like Claude or coworker inside of the right-hand window" | F33 | FE-15 l25 (480 to 640 px); fr2-design 'Conversation design' | carried |
| 1.43 | "hit a keystroke to open up the agent to see information or to expand on something that isn't on the screen" | F34 | FE-15 l25; OPS-36 l25 | carried |
| 1.44 | "third surface ... embedding on a page directly. Take CTI as an example" | F36 (tabled) | OPS-32 l24; OPS-33 l24 (parked) | carried (tabled as Ben asked) |
| 1.45 | "accept the call, that customer's information would populate your screen and an agentic prompt or conversation would potentially start" | F36 (tabled) | OPS-32 l24 | carried (tabled as Ben asked) |
| 1.46 | "embedded on the screen as a component. It wouldn't necessarily be a pop-up or a hover over. Those are still options." | F36 (tabled; last sentence cut) | OPS-32 l24 | carried (tabled as Ben asked) |
| 1.47 | "briefed on their customer as soon as they accept the call ... account map, and variables and fields" | F37 (tabled) | OPS-32 l24 | carried (tabled as Ben asked) |
| 1.48 | "access to things like knowledge articles or support ... take action to follow up with that customer" | F37 (tabled) | OPS-32 l24 | carried (tabled as Ben asked) |
| 1.49 | "voice is still prominent. We want to be able to talk to our agent, to be able to have it to do things" | F19 | FE-12 l25; FE-14 l25 | carried |
| 1.50 | "We also need to be able to type" | F19 | FE-12 l25 | carried |
| 1.51 | "thinking about what quick actions look like" | F19 | FE-12 l25 (chips); fr2-design 'Quick actions' | carried |
| 1.52 | "and also conversation history" | F19 | BE-26 l25, l26; FE-12 l26 | carried |
| 1.53 | "pause here and allow you to process and ask questions" | F39 | the brain's reply with questions 1 to 11 | carried |
| 1.54 | "cut new cards, do design ... me as your product stakeholder, you as the designer, the consultant, the workflow lead" | F39 | plan line 9; fr2-design; the FR2 cards | carried |

### Message 2 (answers to questions 1 to 11)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 2.01 | "we don't want to compete with any sort of CTI connector ... Typically, these actions stack" | F20 | OPS-29 l25 | carried |
| 2.02 | "fine if it's bottom left versus bottom right, but I'm expecting you to be able to do a spike" | F20 | OPS-29 l25 | carried (the ask is a spike) |
| 2.03 | "Agree on spike for number 2" | F25 | OPS-29 l26 | carried (the ask is a spike) |
| 2.04 | "take a look at what [reference app] has done to capture voice ... Pull it in" | F14 | fr2-design 'Voice'; FE-11 l25 | carried |
| 2.05 | "[reference app] chat is open, so you can reference ... and ask it a question" | F14 | fr2-design 'Voice' (pattern taken from the reference app) | carried |
| 2.06 | "follow your recommendation on number 2, as long as we can do it effectively" | F07 | BE-23 l27 | carried |
| 2.07 | "If we hit the same friction ... publishing multiple agent versions, we can skip number 2" | F07 | BE-21 l27; BE-23 l26 | carried |
| 2.08 | "they should be able to change the company name" | F08 | BE-24 l25 (field only) | partial: Company_Name__c is defined and no line shows it anywhere or puts it in a prompt |
| 2.09 | "the agent name" | F08 | BE-24 l27 | carried |
| 2.10 | "the logo" | F08 | BE-24 l25, l28; FE-13 l27 ("where the platform allows it") | partial: shown only in the compact window's brand block, and only if the platform allows; nothing in the rail |
| 2.11 | "the colors" | F08 | BE-24 l27; OPS-35 l26 | carried |
| 2.12 | "the tone of the agent, which I understand might be a larger architectural change" | F08 | BE-24 l26 (tone line in the Apex prompts) | carried (BE-24 l20 and l28 still promise "a later card", which is the parked BE-28) |
| 2.13 | "We'll focus on demo data and industry prospect situations later" | F10 (tabled) | OPS-34 l23 (parked) | carried (tabled as Ben asked) |
| 2.14 | "table one command or a setup page in the org for later" | F11 (tabled) | OPS-34 l23 (parked) | carried (tabled as Ben asked) |
| 2.15 | "different GitHub repos with different options ... industry scenarios ... once we get the core working" | F10 (tabled) | OPS-34 l25 (parked) | carried (tabled as Ben asked) |
| 2.16 | "sliding over the page is acceptable if pushing is impossible" | F26 | FE-15 l25 | carried |
| 2.17 | "different hotkeys for the bottom terminal pop-out, and then a different hotkey for the larger view" | F35 | FE-13 l25; FE-15 l25 | carried |
| 2.18 | "pick 2 hotkey combinations that aren't reserved by Chrome on Mac" | F35 | OPS-29 l27 | carried |
| 2.19 | "Browser's built-in speech recognition is appropriate" | F14 | FE-11 l25 | carried |
| 2.20 | "create a task, create an event" | F16 | BE-27 l25 | carried |
| 2.21 | "log a call, which I think is synonymous with create an event" | F17 (open) | BE-27 l20 ("Not dispatched until Ben answers F17"), l25 | partial: Ben's stated reading is turned into a question that blocks all six actions |
| 2.22 | "skip draft an email for now" | F16 | BE-27 l25 ("No email drafting") | carried |
| 2.23 | "update contact, create a case, update opportunity" | F16 | BE-27 l25 | carried |
| 2.24 | "table this as a much larger spike ... true and realistic ... call center workflows" | F38 (tabled) | OPS-33 l24 (parked) | carried (tabled as Ben asked) |
| 2.25 | "put a placeholder in and keep it safe for now" | F38 | OPS-32 l24 | carried |
| 2.26 | "Number 9 are the key details" (open deals, recent activity, cases, the last brief) | F29 | BE-25 l25; FE-15 l26 | carried (the "last summary" has no rule on whose it is; see the findings) |
| 2.27 | "recent engagement ... under recent activity ... emails, phone calls, case comments synced back" | F29 | BE-25 l25 | carried |
| 2.28 | "follow your recommendation regarding BE19" | F41 | BE-20 (merged; F83 then removed the button through FE-20) | carried (ledger F41 still says "running") |
| 2.29 | "Yes, regarding number 11" | F22 | fr2-design 'Conversation design' | carried |
| 2.30 | "keep styling flexibility based on the prospect, so our sales teams ... implementation teams can easily pull in details" | F09 | BE-24 l27; FE-12 l27 | carried |
| 2.31 | (no answer to question 1: is "Customer Summary" the agent name or the headline skill?) | Decision, plan line 212 | BE-23 l28 | carried (a decision fills the gap) |
| 2.32 | (no answer to question 7: who sees history?) | F32 (open) | BE-26 l26; to-do line 282 | partial: open, on Ben's to-do |

### Message 3

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 3.01 | "cut cards for all of this feedback ... ensuring that none of the feedback has been dropped or lost" | F39 | the ledger; OPS-37 l23 | carried |
| 3.02 | "tagged as feature revision 2 ... so we can do an adversarial review against the cards" | F40 | OPS-37 l23 | carried |

### Message 4 (pattern 01)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 4.01 | "talk about the philosophy of route, gather, reduce" | F44 | OPS-38 l24 | carried |
| 4.02 | "how we can use Agentforce without Data Cloud to shape customer context" | F44 | OPS-38 l24 | carried |
| 4.03 | "there's two parts of this. There's the business impact and then there's the architecture" | F45 | OPS-38 l24, l25 | carried |
| 4.04 | "Everyone wants deal history, service history, and an insight into the customer" | F46 | OPS-38 l24 | carried |
| 4.05 | "What we need to be able to articulate here is how easy it is" | F46 | OPS-38 l24 (no sentence on ease) | partial: nothing in the Done-when says how little a team has to do |
| 4.06 | "a narrative overlaying customer summaries that's customizable by industry" | F46 | OPS-38 l25 ("How to change the narrative per industry") | carried (by hand; a built switch is open as F50) |
| 4.07 | "how we scale that out architecturally" | F47 | OPS-38 l27 | carried |
| 4.08 | "super simple to build a graph of all of the data, pass it to an LLM" | F47 | OPS-38 l25 (the account's data graph) | carried |
| 4.09 | "make sure that the summary is accurate" | F47 | BE-29 l26 | carried |
| 4.10 | "Focused LLM callouts to summarize key information ... [reference guide] ... the design pattern that we want to communicate" | F48 | OPS-38 l25 | carried |
| 4.11 | "incorporate auto number, colors, fonts, and build truly beautiful sequence diagrams" | F49 | OPS-38 l26; fr2-design 'Diagrams' | partial: the rule is "for every diagram", and pages 09 to 14 have no card that applies it |
| 4.12 | "each step can correspond with a specific number to allow the user to track" | F49 | OPS-38 l26 | carried |
| 4.13 | "show from the document our reduction structure ... case history ... order history" | F50 | OPS-38 l25 | carried |
| 4.14 | "why you can trust this architecture and how you can scale it" | F51 | OPS-38 l27 | carried |
| 4.15 | "cover limits and open items as part of future cards to cut" | F52 | BE-29 l25; OPS-38 l27 | carried |
| 4.16 | "overall holistic feedback here, having a simple header and articulating the business problem ... high architecture steps" | F53 | OPS-38 l24; fr2-design 'Pattern page shape' | partial: "every pattern page" depends on a sweep card that was never cut (pages 09 to 14) |

### Message 5 (pattern 02)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 5.01 | "each follow-up question needs to be a flow ... endless build cycles ... when they can just use Claude" | F54 | OPS-39 l24 | carried |
| 5.02 | "support follow-up questions to that summary we just provided organically" | F55 | BE-30 l25, l28 | carried |
| 5.03 | "make sure that it scales to any object, any combination of data" | F55 | BE-31 l26 to l31 (discovery; it proposes cards) | only a spike |
| 5.04 | "that is a core operating principle for us" | F55 | fr2-design principle 1; OPS-36 l33; OPS-39 l24 | carried (the principle states 5.03 as fact; see the findings) |
| 5.05 | "beautiful sequence diagrams with auto number, with numbered steps that correspond to each" | F56 | OPS-39 l25 | carried |
| 5.06 | "an easy, consistent pattern that we should be able to highlight" | F56 | fr2-design 'Diagrams' | carried |
| 5.07 | "in the see it section, we want to record or highlight and capture images for each see it" | F57 | OPS-36 l32 | partial: "the MCP door as a client transcript image" needs a real tool call that no card or to-do makes |
| 5.08 | "tackle limits and open items as our follow-up to this set of this feature" | F58 | BE-30 l26; FE-12 l28; BE-31 l27 | partial: OR filters, parent paths and long-text filters sit only in the discovery card, and long-text filters are not in its Done-when |
| 5.09 | "make sure cards are cut for that discovery" | F59 | BE-31 l31 | carried |

### Message 6 (pattern 03)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 6.01 | "I like the hotkey panel, being able to snap in, hide, display different chats" | F60 | FE-13 l26; FE-12 l26; OPS-40 l24 | carried |
| 6.02 | "I don't think anybody is dying to use the Astro button, so that makes sense" | F61 | OPS-40 l24 | carried |
| 6.03 | "make sure limits and open items are covered" | F62 | FE-12 l29; FE-13 l27; FE-16 l25 to l27; FE-5 l24 | partial: the non-admin run sits on FE-5, which is outside the Order and waits on a user that is not on the FR2 to-do |
| 6.04 | "think about the hotkey panel and other items we should add later" | F63 | FE-17 l24, l25 | carried (the ask is to think it through) |
| 6.05 | "how it works also needs auto number with numbered suggestions down below" | F64 | OPS-40 l25 | carried |

### Message 7 (pattern 03, the panel's answers)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 7.01 | "whenever we display text inside of any of our services, it's richly formatted" | F65 | FE-12 l31; FE-18 l26 | partial: the LWC thread renders cards, but no card makes the Apex services or the MCP door return the contract |
| 7.02 | "we have a card architecture that we can display and put on display" | F65 | FE-18 l29 (research page and prototype captures) | only a spike: no living page shows the card architecture; OPS-40's Done-when never mentions it |
| 7.03 | "one of the spikes coming out of this is, what does our card architecture look like ... feels best in class?" | F65 | FE-18 l25 to l29 | carried (the ask is a spike) |

### Message 8 (why custom)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 8.01 | "articulate the why behind us bringing in a custom architecture ... instead of standard Salesforce and Agentforce" | F66 | OPS-41 l24 to l26 | carried |
| 8.02 | "It's because the standard Astro icon is bad. It doesn't scale." | F66 (rewritten as: The standard launcher "doesn't scale") | OPS-41 l24 ("Say it respectfully: what we gain, not what is wrong with the platform") | partial: the ledger drops "is bad" and the card tells the writer not to say what is wrong |
| 8.03 | "There's soft limits for how many characters" | F66 | BE-32 l25; OPS-41 l24 | carried |
| 8.04 | "teams decelerate when trying to incorporate lightning cards into the responses" | F66 | BE-32 l26; OPS-41 l24 | carried |
| 8.05 | "I'm not sure where that needs to live, but that is a note that we need to make sure we communicate to our teams" | F66 | OPS-41; OPS-36 l30; OPS-40 l24 | carried (the rail page and the embedded page do not link it, though the decision says they do) |
| 8.06 | "we can work in the architecture of the why" | F66 | OPS-41 l25 | carried |
| 8.07 | "The [reference guide] for the agent build ... There should be a section there on the limits" | F66 | BE-32 l24 (the brain's generic restatement) | carried |

### Message 9 (pattern 04)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 9.01 | "prompt templates require a lot of overhead. We want to be able to accelerate very fast" | F67 | OPS-42 l24 | carried |
| 9.02 | "they don't represent the entire context of the request ... because of things like the trust layer" | F67 | BE-33 l25; OPS-42 l24 | carried |
| 9.03 | "direct call out to the LLM provider via Salesforce, but doesn't offer a UI, which is a kind of a trade-off" | F68 | OPS-42 l24 | carried |
| 9.04 | "still giving teams the opportunity to incorporate in a prompt template to the call if they need to" | F69 | BE-33 l26, l29 | carried (BE-33 l29 may "stop at the tested seam"; OPS-42 has no wording for that case) |
| 9.05 | "two approaches to our package. One where we have a commented out section ... and another one where it doesn't" | F69 | Decision, plan line 263 (a switch, not commented-out code); BE-33 l26 | carried (Ben asked for thoughts; the decision is recorded) |
| 9.06 | "going with an API-first approach of models API makes the most sense ... easier to vibe out" | F70 | fr2-design principle 3; OPS-42 l24 | carried |
| 9.07 | "Interested on your thoughts but we would want that conversation represented" | F69, F70 | OPS-42 l24 ("The decision" and "when a template still fits") | carried |
| 9.08 | "we need auto number, we need a better design that looks good for the how it works, sequence diagram" | F71 | OPS-42 l25 | carried |
| 9.09 | "limits and open items should also be explored in a little bit more detail, and cards cut" | F72 | BE-33 l26 to l31; OPS-42 l27 | carried |
| 9.10 | "how to update context for your prompt call out ... how to use it, how to tune your prompt" | F73 | OPS-42 l26; BE-33 l30 | carried |

### Message 10 (pattern 05)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 10.01 | "research what Agentforce Memories are to see if that impacts our design at all" | F74 | BE-34 l25 to l28 | carried (the ask is research) |
| 10.02 | "something a little bit more persistent. And generic at that" | F75 | BE-35 l25 | carried |
| 10.03 | "history records in a more agnostic way. So whether I create a task, whether I generate a brief" | F75 | BE-35 l25, l28; BE-27 l25 | carried |
| 10.04 | "should persist against that customer for a period of time, potentially for forever" | F76 | BE-35 l26 | carried |
| 10.05 | "show a graph of change in customer sentiment over time" | F77 | BE-36 l25 to l27; FE-19 l26 | carried |
| 10.06 | "we need to make sure that our past outcomes are reusable" | F78 | BE-35 l29 | partial: by default only the author's own summary text is reused; another rep gets type, date and label |
| 10.07 | "doesn't supersede our ability to store briefs and have context and history ... when the rep opens up the conversation" | F79 | BE-34 l28; BE-35 l29; OPS-43 l24 | carried |
| 10.08 | "auto number with explanations ... formatting of the sequence diagram to make it look really good" | F81 | OPS-43 l25 | carried |
| 10.09 | "limits and open items should be rechecked and verified that we don't need new additional work" | F80 | OPS-43 l26; BE-26 l26; BE-34 l27 | carried |

### Messages 11 and 12 (pattern 06)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 11.01 | "I don't think we want to promote using the default agent force pop-out panel" | F82 | OPS-36 l29; OPS-44 l24; FE-20 l28, l29 | carried (several cards that are not parked still carry the old path; see the findings) |
| 11.02 | "If you decide to use number 6, that means you're not using any of the other avenues" | F82 | OPS-44 l24 ("When you would add it") | carried |
| 11.03 | "I'd propose that we drop this. What are your" | F82 | Decision, plan lines 234 to 240 (kept as an optional appendix); OPS-44 | carried (kept by a recorded decision; Message 14's Testing Center ask needs a registered agent) |
| 12.01 | "what's the ask the agent meant to do? I guess I don't understand that part" | F83 | FE-20 l25, l26 | carried |
| 12.02 | "We don't need to say is this agent force ... it's just a different skinned version of it" | F84 | OPS-41 l24; OPS-36 l29 | carried |
| 12.03 | "I'm all for dropping the Astro icon button" | F83 | FE-20 l27 ("do not change that setting: hiding it is Ben's call") | partial: his answer comes back as a to-do question, and the check for a rep is left to FE-5, which has no line for it |
| 12.04 | "and then also the ask the agent button too. We probably don't need those two items" | F83 | FE-20 l25 | carried |

### Message 13 (pattern 07)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 13.01 | "I again don't know if this is an entire chapter. I think this is more so design philosophy" | F85 | OPS-45 l24; fr2-design principle 5; OPS-36 l33 | carried |
| 13.02 | "How we give access to records and permission sets is an implementation detail almost" | F86 | OPS-36 l33 (one line in the quick start); OPS-45 l24 | carried (the ledger also promises "each chapter's Adopt it (OPS-36)", which OPS-36 l31 cannot write) |
| 13.03 | "runs in with sharing, except for things where it needs system context, like memory records ... I would align to that" | F87 | BE-37 l25 to l27 | carried |
| 13.04 | "The question is, does it need to be its own section?" | F85 | Decision, plan line 241; OPS-45 l24 | carried |

### Messages 14 and 15 (pattern 08)

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 14.01 | "I'd really like to explore in Section 8 testing lifecycle even more" | F88, F91 | OPS-47 l24 to l27 | carried |
| 14.02 | "build out some really cool Agentforce Testing Center suite that we can incorporate into the run" | F88 | BE-38 l26, l27; OPS-46 l25 (only with --agent) | partial: outside the default run, capped at 20 cases, waits for Ben's go, and tests an agent that FR2 lets lag (BE-28 parked) |
| 14.03 | "playwright tests for testing front-end changes" | F89 | FE-21 l27 (smoke subset); each surface card's e2e | carried |
| 14.04 | "any other test classes in Apex that we may have generated to like prove that this thing works well" | F90 | OPS-47 l26 | carried |
| 14.05 | "not sure exactly what the Chromium thing means ... I'm assuming that this is UI UX tests" | F89 | OPS-47 l26 (one line on Chromium) | carried |
| 14.06 | "how we communicate how to effectively test these agents as well as part of this bundle" | F88 | OPS-47 l24, l26 | carried |
| 14.07 | "testing adoption ... really important ... Salesforce users who haven't historically done this type of testing" | F91 | OPS-47 l24, l26; OPS-46 l25 | carried |
| 14.08 | (withdrawn) "on top of that, lets review open items" | F92 | plan lines 196 to 208; OPS-46 l26, l27; to-do lines 303 to 305 | over-read: the open-items review was withdrawn and still drives two script features and two to-do items, kept under F80 (a pattern 05 note) |
| 15.01 | "this section can be dropped from my previous message. it was picked up by tts" | F92 | plan line 194 | carried (the tone rule and the grading test are gone; see 14.08 for what stayed) |

### Message 16

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 16.01 | "that completes everything" | none | plan lines 3 and 10 still say "two messages" and "More notes are coming"; F42 open | dropped: nothing records that the notes are closed, so OPS-36 l24 still waits for F42 notes |
| 16.02 | "kick off a comprehensive review of all the feedback" | F40 | OPS-37 l23 | carried |
| 16.03 | "cut new cards" | none | Decision, plan lines 231 to 233 ("one sweep card, cut after his last chapter note") | partial: the sweep card is due now and does not exist |
| 16.04 | "iron out any questions or dependencies" | none | to-do lines 276 to 306 | partial: see the to-do check below |

### The standing request behind F43

| # | Ask (Ben's words) | Ledger | Carrying card and line | Verdict |
|---|---|---|---|---|
| 43.1 | "gtm ready with screenshots" | F43 (quote cut to its last clause) | OPS-36 l27, l32 | carried |
| 43.2 | "beatiful industry ready github repo with gifs, screenshots sequence diagrams" | F43 | OPS-36 l25 to l27 | carried |
| 43.3 | "read like a gtm business driven outcome workbook ... for each architecture pattern" | F43 | OPS-38 to OPS-45, OPS-47 (pages 00 to 08) | partial: pages 09 to 14 have no chapter card and no sweep card |
| 43.4 | "this includes testing" | F43 | OPS-46 l25; OPS-47 | carried |
| 43.5 | "playwright screenshots with frontend validation" | F43 | OPS-35 l26 | partial: the list has no outcomes timeline, sentiment chart, rail context sections or Confirm path, and OPS-35 is not blocked by FE-19 |
| 43.6 | "architecture reviews" | F43 | OPS-35 l25, l27 | partial: the trace stops at "F01 to F43", so F44 to F91 are never traced |

### Card lines with no ask and no recorded decision behind them

| Card and line | What it builds | Nearest ask |
|---|---|---|
| BE-27 l26; FE-14 l26 | An Undo for 15 seconds; BE-27 also "deletes a record the user just created", FE-14 offers it for updates only | none (fr2-design 'Write actions' offers it "after an update") |
| BE-35 l25, l28, l31 | A "Saved answer" outcome type; nothing in FR2 lets a rep save one (FE-17 l24 only lists it as a candidate) | F80 (rechecked open item) |
| BE-35 l30 | A report type "Customer Outcomes with Account" | none |
| FE-19 l27 | The timeline and the chart also placed on the account record page | F77 names the graph, not where it sits |
| BE-32 l28; OPS-41 l24, l26 | "Fair to the platform", "Say it respectfully", "When standard is the right choice" | none; Ben's words were "the standard Astro icon is bad" |
| OPS-46 l26, l27 | A Java-less code scan and an org drift check | the withdrawn "lets review open items" |

### Ben's to-do, checked against the cards

Missing from the list (a card waits on it):

- FE-5 l22: "Prerequisite done by Ben ... a Standard User in agent-probe ... signed into the sf CLI as alias
  agent-probe-enduser". It is in gtm-burn-plan.md line 75 only. OPS-36 l33, OPS-45 l25, BE-33 l27 and FE-20 l27 wait on
  FE-5, and FE-5 is not in the Order.
- The MCP sign-in itself. Line 284 says to hold it until OPS-31 lands; nothing says to do it afterwards, and OPS-36 l32
  ("the MCP door as a client transcript image") and BE-35 l29 ("Prove in the doc that the MCP path receives it") need
  a real call.
- A go for the spikes is listed, but OPS-29 (status queued, no blocked_by), BE-21 and BE-22 carry no "Dispatched only
  after Ben's go" line, although Approvals line 79 lists them as pending.
- Filing the Salesforce case (plan line 200: "is Ben's to file").
- Approving removal of the leftovers (plan lines 271 and 272; OPS-29 l30; FE-20 l26; OPS-31 l27).
- A yes or no on three decisions Ben asked for thoughts on: 06 kept as an appendix (F82), a switch instead of
  commented-out code (F69), 07 as a principles page (F85).

No longer needed, or wrongly framed:

- "and for OPS-37" (line 306): Message 16 gave the word.
- "Answer F17" (line 279) as a blocker: Ben said "synonymous with create an event".
- "Decide whether to hide the Agentforce icon" (line 294): Ben said "I'm all for dropping the Astro icon button"; what
  is left is a go to flip an org setting.
