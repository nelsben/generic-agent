---
id: BE-30
title: FR2: follow-ups to the summary — the explorer answers the next question from the summary's context with no new build, keeps tables read before a model failure, and shows drill headers as labels; a live follow-up set proves it
domain: backend
tier: frontier
tier_reason: changes the explorer's context contract that the panel, the agent and MCP share, measured live in a production-classified org
status: merged
fixes: []
scope: [force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/DataExplorerTest.cls, force-app/main/default/classes/ExploreAction.cls, force-app/main/default/classes/ExploreActionTest.cls, force-app/main/default/classes/ExplorePlan.cls, force-app/main/default/classes/ExplorePlanTest.cls, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls, force-app/main/default/staticresources/AgentPrompt_Explore.resource, scripts/follow-up-set.apex, docs/research/fr2-follow-ups.md, tests/test_explore_prompt.py]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new DataExplorerTest cases fail on main (a follow-up after a summary loses the summary's account and deals; a model failure on the agent path drops the tables already read; drill child-row headers are API names) and pass after
gate: test, org
budget: 5-attempts
spend: 12
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 02. In a typical Agentforce build, "each follow-up question needs to be a flow, repurposed or rebuilt with context shoved back through". Here, follow-ups to the summary should work "organically", and that is "a core operating principle". He also asked to tackle the page's limits. Covers ledger rows F55 and F58 in docs/plans/feature-revision-2.md and principle 1 in docs/plans/fr2-design.md.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md (rows F54 to F59), docs/plans/fr2-design.md ('Operating principles'), docs/patterns/01-route-gather-reduce.md, docs/patterns/02-ask-anything-explorer.md, docs/patterns/05-conversation-memory.md, docs/reviews/apex-review-2.md (N4) and docs/reviews/lwc-review-2.md (N1, N3). Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate, salesforce-development:platform-soql-query and salesforce-development:platform-metadata-deploy first
- **Summary context:** when a summary was the last turn, the explorer gets a compact summary context: the account, and the Ids and names behind each summary section, capped, never shown to people. With it, "which of those close this quarter?", "who there have we not called?" and "any open cases on the biggest deal?" resolve against the same records. The context travels in the existing history input, so the panel and the optional agent's action get it with no new action; MCP gets it only if the ask tool is approved (the Approvals row "FR2: the explorer as an MCP tool for outside clients"). The explore prompt gains one rule: a pronoun or "those" means the records in the last turn, and when that is unclear, it asks
- **Apex N4:** on the agent path, a model failure after a query keeps the tables already read and returns them with the fixed failure line, as the panel path does. **Panel N1:** drill child rows return field labels and record names, not raw Ids or API names, and the DTO keeps Ids for opening records
- Tests with Assert.* cover each of the three follow-ups above with a scripted model, the context cap, the pronoun rule's ask path, N4 and N1. Existing explorer tests still pass
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- **Live follow-up set:** scripts/follow-up-set.apex runs a summary and then 10 follow-ups for 2 sample accounts in agent-probe. It prints only pass or fail per question, the object queried and the model calls used (no names, no Ids). Record the results in docs/research/fr2-follow-ups.md, with every failure explained. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Four attempts; the budget was raised three times by cards PRs (#174, #176, #177), each time to fix a claim, not code.

- Attempt 2 (69f2256; the first hand-back came while the worker still waited on its own deploy, and the verify run counted it as attempt 2): 18 confirmed, 2 refuted, 5 unverifiable. Every unverifiable row is an org fact: the live follow-up runs, the validate and quick deploy, the session row counts and the model-call figure. Both refuted rows were claims in docs/research/fr2-follow-ups.md, not in the code, and the brain confirmed both by hand:
  - The page said the record card "still shows lookup Ids". It does not: DataExplorer's display step drops every column whose path ends in Id, and the component drops `Id`.
  - The page said the three named-follow-up tests check that the filtered plans return those records only. The tests assert the prompt contents and the first row only.
- Attempt 3 (c16276a): the worker corrected those two lines and nothing else. 6 confirmed, 1 refuted, 2 unverifiable. The one refuted row was an untracked tests/__pycache__ in the worktree, written by the verifier's own gate run, not the worker's. The brain removed it, added `__pycache__/` to .gitignore (#176), and re-ran the verifier on the same sha. One unverifiable row: the page's "each checks" reads as the union of the three tests (only the first asserts the context header and account key).
- The verifier re-run on c16276a: 22 confirmed, 1 refuted, 5 unverifiable. The refuted row: scripts/follow-up-set.apex's header called its model-call count exact, while the page rightly calls it a floor.
- Attempt 4 (d5fa586): the worker rewrote that comment only. 9 confirmed, 0 refuted, 1 unverifiable (that no deploy ran; none was needed for a comment).
- Stronger tests for the three named follow-ups are cut as BE-48 (blocked by this card). The code is accepted as it stands.

Findings:
- Summary context: a follow-up after a summary carries what the summary showed, capped at 10 rows per section, 3,000 characters and 120 characters a line, with the account name first and only the keys shown.
- Prompt rule 12: a follow-up that names something in the summary filters on it; an unclear "those" asks back.
- N4: after a model failure the last table stays on screen with one plain error line.
- Live (approved live-checks row, seed accounts only): run 2 passed 18 of 20 follow-ups.
- The two misses: "who there have we not called?" on Edge Communications failed 3 of 3, most likely because the plan language has no anti-join (NOT IN); and "which of those matter most?" on Brindlewick Hydroponics was answered instead of asked back.

Org: deployed to agent-probe under the standing row (validate with RunLocalTests, then quick deploy). Live runs wrote session rows only (5 rows before and after, 5 updates). Nothing published, no user created, no AccountBrief* class touched.

Disclosed and accepted:
- The live numbers, the deploy record and the row counts are the worker's account; nothing in git shows them.
- The model-call figure is a floor, not a measured count.
- A tests/__pycache__ found at review time was removed before merge.

Still open:
- The anti-join gap (BE-48).
- The ask-back miss on a vague "those".
- The agent path was not exercised live; only the panel path ran.
- The LWC table title and the related chips still show object API names.

Privacy grep over the diff at d5fa586: 0 hits.
