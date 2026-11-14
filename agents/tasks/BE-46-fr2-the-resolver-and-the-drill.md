---
id: BE-46
title: FR2: the resolver and the drill return cards — several matching accounts come back as a choice card, no match as a notice and a drilled record as a record card, next to text that does not change
domain: backend
tier: standard
tier_reason: three builders on a contract BE-39 already built, added next to outputs that must not change
status: merged
scope: [force-app/main/default/classes/CustomerSummaryResolver.cls, force-app/main/default/classes/CustomerSummaryResolverTest.cls, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls, force-app/main/default/classes/AnswerCard.cls, force-app/main/default/classes/AnswerCardTest.cls, docs/research/fr2-card-contract-apex.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new cases in CustomerSummaryResolverTest and CustomerSummaryPanelControllerTest that read the cards on an AMBIGUOUS response, a NOT_FOUND response and a record drill fail on main (the members do not exist) and pass after
gate: test, org
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2), operating principle 2: every answer is shown in cards from one typed contract (ledger F65). The card spike (FE-18, docs/research/fr2-card-architecture.md) found that BE-39 covers the summary and the explorer, but the account resolver and the panel's drill still answer in text only. It also found that the resolver's AMBIGUOUS message puts each candidate's record Id in its text. This card gives those two answers cards built from data they already hold, so the Ids have a home in `refs`.

## Done when

- Read first: docs/research/fr2-card-architecture.md (FE-18: the `choice`, `notice` and `record` rows of the catalog, their JSON examples, and the 'MCP clients' findings), docs/research/fr2-card-contract-apex.md (BE-39: the AnswerCard types as built; follow it where the two pages differ), and CustomerSummaryResolver, CustomerSummaryPanelController (the Drill class and drill method) and AnswerCard as they are on main. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- **The resolver returns cards.** CustomerSummaryResolver.Response gains one new invocable output, the cards as JSON text, with a description that reads well to a model. AMBIGUOUS gives one `choice` card: the question as the title, one item per candidate with its name as the label and its city (or the detail the message uses today) as the detail, and each candidate's Id only in `refs`. NOT_FOUND gives one `notice` card with status NOT_FOUND and the message. RESOLVED gives no card. Every output the resolver has today keeps its name, its type and its exact content, including the AMBIGUOUS message with its Ids: removing Ids from that message changes what the agent and an MCP client read and is Ben's decision, so do not do it here; say in the hand-back that it is still open
- **The drill returns a card.** CustomerSummaryPanelController.Drill gains one new @AuraEnabled member that holds its cards. A single-record drill gives one `record` card (title, the object as meta, the fields as label and value, lookups as refs, the related objects as the page's catalog row describes them). A related-rows drill gives one `recordList` or `table` card, whichever BE-39's page uses for the same result set from the explorer. Every member Drill has today is unchanged, and no existing controller method changes its signature
- The cards are built from data the method already holds: no new query, no new DML, no model call. Add builders to AnswerCard only for what BE-39 did not build, and change no existing builder or type. A card never holds a field the running user cannot read, and `text` never holds an Id. No change to the agent bundle, the MCP server definition or any LWC
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- Tests with Assert.*: the AMBIGUOUS choice card (item count and order equal the candidates in the message, every Id in `refs` and none in `text`), the NOT_FOUND notice, RESOLVED with no card, the record card and the related-rows card from a drill, a regression test that every existing output and Drill member is unchanged, the invocable's cards JSON parses back to the same cards, and a runAs test that a card holds no field the running user cannot read. tests/test_trust_rule.py passes unchanged
- Add a section to docs/research/fr2-card-contract-apex.md: what the resolver and the drill now return, one JSON example for each of the three cards taken from a test with any Id as a placeholder, and the open question about Ids in the AMBIGUOUS message
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row. No live run in the org beyond the deploy: no session opened, no record written
- Org, agent-probe only, under the standing row "Production-classified deploys to `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt (a8d54ae). The verifier found the report consistent and returned next=accept, so no separate reviewer ran. The brain read the resolver diff in full and the diff stat (5 files, 601 added lines).

Findings:
- The resolver's Response gains one `cards` output: JSON text, both an invocable variable and @AuraEnabled. Its description tells a model to relay the Message, not the cards.
  - AMBIGUOUS gives one choice card. Its title is the message's question line, and it has one item per candidate in the message's order, with the city (or "no city") as the detail. Each Id is only in refs.
  - NOT_FOUND gives one notice card, for both a no-match and a blank request.
  - RESOLVED and ERROR give an empty list.
  - A failure building a card is logged and gives an empty list. Every existing output, including the message text, is unchanged.
- The panel controller's Drill gains a `cards` member.
  - A single-record drill gives a record card: the name as the title, the object label as the meta, label and formatted value per field, lookups through refs, and one `related` item per related object (plural label). Blank values are left out.
  - A related-rows drill reuses DataExplorer.cards on the same result set, so its table card is identical to the explorer's; a test checks it.
  - No query, controller signature, AnswerCard or DataExplorer change.
- Tests cover each outcome, the order and refs, the card/explorer match, and runAs users without field access (built and rolled back inside the test).
- docs/research/fr2-card-contract-apex.md gains three example JSONs, composed from the code and the tests, not printed from a run.

Org (worker's account): a validate of the four changed classes with RunLocalTests (419 tests, 0 failures, AccountBrief* tests included), then a quick deploy under the standing row. No session opened, no record written, nothing published, no user created.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- One red validate timed out while another validate held the org and was re-run alone.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- The AMBIGUOUS message still lists each candidate's record Id in its text, which the agent and any MCP client read. The card's text holds none. Removing them from the message is Ben's call (from FE-18).
- No surface draws these cards yet: the panel's FE-22 and the agent's output declaration are follow-ups.

Privacy grep over the diff (601 added lines): 0 hits.
