---
id: BE-39
title: FR2: the card contract in Apex — the summary and the explorer return typed cards next to their text through one AnswerCard class, so the compact window, the rail and an MCP client all read the same shape; nothing they return today changes
domain: backend
tier: frontier
tier_reason: a contract every surface and the action service build on, added to two live services without changing anything they return today
status: merged
fixes: []
scope: [force-app/main/default/classes/AnswerCard*.cls, force-app/main/default/classes/AnswerCard*.cls-meta.xml, force-app/main/default/classes/CustomerSummary.cls, force-app/main/default/classes/CustomerSummaryTest.cls, force-app/main/default/classes/CustomerSummaryGetAction.cls, force-app/main/default/classes/CustomerSummaryGetActionTest.cls, force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/DataExplorerTest.cls, force-app/main/default/classes/ExploreAction.cls, force-app/main/default/classes/ExploreActionTest.cls, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls, docs/research/fr2-card-contract-apex.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: a new AnswerCardTest, and new cases in CustomerSummaryTest and DataExplorerTest that read the cards on a result, fail on main (the class and the cards member do not exist) and pass after
gate: test, org
budget: 3-attempts
spend: 12
---
## Why

Feature revision 2 (FR2): operating principle 2 says every answer is richly formatted and shown in cards from one typed contract that every surface reads (ledger F65). FE-18 designs that contract as a spike, but as first cut no card built it into the Apex services, so the conversation would have had to guess cards from text and an MCP client would have had none (finding 34 in docs/reviews/fr2-plan-review.md). This card puts the contract where the answers are made.

## Done when

- Read first: docs/plans/fr2-design.md (principle 2, 'Cards inline' and 'Rich text'), docs/research/fr2-card-architecture.md (FE-18: the catalog, the contract and its JSON example for each card type; follow it, and where it is silent use this card), docs/research/fr2-follow-ups.md (BE-30), tests/test_trust_rule.py, and the summary engine, the explorer, the two invocable actions (CustomerSummaryGetAction and ExploreAction) and CustomerSummaryPanelController as they are on main. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- **One contract class:** AnswerCard (with AnswerCardTest), `with sharing`, with no query, no DML and no callout. It holds the typed shape FE-18's page fixes (card type, version, title, fields, rich text as runs, record links, the plain-text fallback) as Apex types with @AuraEnabled members, and one builder per card type. It builds every card type the summary and the explorer can produce today, as FE-18's catalog lists them, and it defines the action draft and action result types for BE-27 to fill; it does not build those two. A card never carries HTML, and every card carries its plain-text fallback
- **From FE-18 (merged 2026-11-13; docs/research/fr2-card-architecture.md):** build the envelope exactly as the page's 'The contract' section and its Apex type sketch give it: one flat AnswerCard with lists of small inner classes (Block, Run, Field, Column, Row, Item, Control, Ref), no Map or Object member, every table cell a formatted string, `total` and `shown` on a list or a grid, and record Ids only in `refs`, pointed at by key. The type names, the member names and the `status` words are the page's; where a name is missing from the page, choose one and list it in the hand-back. `text` follows the page's plain-text rule for the type and never holds an Id. The rich-text parser lives in AnswerCard, so a service hands it text and gets `body` blocks of runs back and no surface has to parse: every row of the page's 'Rich text' table is a case in AnswerCardTest with the same expected runs. The JSON examples in this card's page equal the page's examples for the same type, Ids aside. A table card holds no more rows than the service's text shows (the same `shown`). The cards JSON an invocable returns has its own character cap, which this card chooses and states with its reason; when the cards would go over it, the output is empty and the text output is unchanged, never cut-off JSON. The resolver and the drill are not in this card (BE-46)
- **The services return cards next to their text.** The summary result and the explorer result each gain one new member that holds their cards. Every member they have today keeps its name, its type and its content. The cards are built from data the service already holds: no new model call and no new query. The panel controller passes the cards through on what it returns to the panel. The two invocable actions return the cards as one JSON text output next to their existing outputs, with a description that reads well to a model; their existing outputs do not change
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- Tests with Assert.*: one per card type built from a fixture (fields, runs, fallback, version); the summary and the explorer each return cards that agree with their text (the same counts, row order and record labels); a regression test that every text member a caller reads today is unchanged by this card; a failed section still gives a card and never drops the rest; the JSON an invocable returns parses back to the same cards; and a runAs test shows that no card holds a field the running user cannot read. tests/test_trust_rule.py passes unchanged
- Write docs/research/fr2-card-contract-apex.md: the Apex types as built; one JSON example per card type, taken from a test, with any record Id written as a placeholder; exactly what the panel receives; exactly what an MCP client receives from each tool (the text, and the cards as JSON text) and what it does not; whether a turn the history store keeps also keeps its cards (read docs/research/fr2-conversation-history.md only if it exists, and change no history class here: a reopened turn without cards shows as text); what was left out and why; and how to add a card type. FE-22, BE-27, FE-14 and FE-19 read this page
- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote. The live run is one summary and one explorer question on that account from anonymous Apex, printing the card types and their counts only
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only, under the standing row "Production-classified deploys to `agent-probe`": validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Two worker attempts; the budget was raised to 3 by a cards PR (#186).

- Attempt 1 (eec3748): 23 confirmed, 1 refuted, 5 unverifiable. The refuted row was a tests/__pycache__ written by the verifier's own gate run after the commit, not by the worker. The brain removed it and re-ran the verifier on the same sha. The second review (18 confirmed, 1 refuted, 5 unverifiable) refuted a real gap: FE-18 gives `Item` a `status` member, and AnswerCard.Item had none. The brain confirmed it by hand.
- Attempt 2 (f55e3e1): the worker added `Item.status` (null unless set), one round-trip test and the doc row, and deployed only AnswerCard and its test. The mod counted the worker's pause for its deploy as the attempt and stopped on budget, so the brain raised the budget and re-ran the verifier at f55e3e1: 19 confirmed, 0 refuted, 3 unverifiable (the live-run figures, the deploy result, and the choices, which the synthetic hand-back did not carry).

Findings:
- AnswerCard is one `with sharing` class with no query, DML or callout, no Map or Object member, and Ids only in Ref. It holds FE-18's types and member names, 14 builders, the rich-text parser (one test per row of FE-18's table) and toJson/fromJson. The action draft and result types have text rules but no builder yet (BE-27).
- CustomerSummary.Result and DataExplorer.Result each gain only a `cards` member, built from what they already hold: no new query or model call. A test pins every existing member and its text.
- The panel controller passes the cards through unchanged. CustomerSummaryGetAction and ExploreAction each gain a `cards` JSON text output, which tells a model to relay the Answer. The explorer's table card holds exactly the rows its text shows.
- The cards JSON is capped at 60,000 characters; over the cap the output is empty and the answer is unchanged. A failure building cards leaves them empty and changes nothing else.
- Tests cover a failed section, a JSON round trip on both invocables, and a runAs user who cannot read a field.

Live check (worker's account, approved live-checks row, seed account): the explorer returned 4 cards and the summary 8. One existing session row was updated and none created.

Org: validate with RunLocalTests (338 tests), then a quick deploy of the 11 changed classes. Attempt 2 then validated (339 tests) and quick deployed only AnswerCard and AnswerCardTest. Both under the standing row. No AccountBrief* class was touched, nothing was published, and no user was created.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- tests/__pycache__ made by the gate runs was removed before merge.

Still open:
- The Customer_Summary agent declares its action outputs by name, so it does not see `cards`. Adding them is an agent change.
- `cards` has not been read through a signed-in MCP client; that waits on Ben's MCP sign-in.
- No builder sets Item.status yet.

Privacy grep over the diff (3,308 added lines): 0 hits.
