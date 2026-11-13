---
id: BE-48
title: FR2: the three named follow-up tests assert the records the filtered plan returns, not only the prompt and the first row
domain: backend
tier: standard
tier_reason: test-only change to one Apex test class with a clear assertion target
status: merged
fixes: [BE-30]
scope: [force-app/main/default/classes/DataExplorerTest.cls, docs/research/fr2-follow-ups.md]
forbid: [force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/ExplorePlan.cls, force-app/main/default/classes/ExploreAction.cls, force-app/main/default/staticresources/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the three strengthened DataExplorerTest methods fail in a check-only validate on agent-probe when each scripted plan's filter on the summary's Ids is removed, and pass with it restored
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

BE-30's review found that DataExplorerTest's three named follow-up tests check the prompt contents and rows[0] only, while its research page first claimed they check that the filtered plans return those records only. The page is corrected in BE-30's third attempt; this card makes the tests check what the page first said, so a plan that ignores the summary's records fails a test.

## Done when

- Read first: docs/research/fr2-follow-ups.md ('Tests') and the three tests in force-app/main/default/classes/DataExplorerTest.cls: whichOfThoseCloseThisQuarterUsesTheSummarysDeals, whoThereHaveWeNotCalledUsesTheSummarysContacts and anyOpenCasesOnTheBiggestDealUsesTheSummarysDealAndAccount. Load the skills salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- Each of the three tests inserts at least one record that matches the question but is NOT among the summary's records (for example an open deal on a second account, or a contact on another account), and asserts the exact number of rows returned and that every returned row's Id is one of the summary's records. Keep each test's existing prompt assertions
- whoThereHaveWeNotCalledUsesTheSummarysContacts: the plan language has no anti-join today, so assert only what the scripted plan actually filters on (the summary's contact Ids); do not add an operator, change ExplorePlan, DataExplorer, ExploreAction or the prompt resource. Anti-joins belong to the parked card BE-43
- Each strengthened test fails if its scripted plan's filter on the summary's Ids is removed: show this once per test in the hand-back (remove the filter locally, run the test, paste the failing assertion line, restore it)
- Change no file but DataExplorerTest.cls, and docs/research/fr2-follow-ups.md's 'Tests' paragraph for those three tests only if its wording no longer matches what they assert
- Org, agent-probe only, with -o agent-probe on every sf command, under the standing row 'Production-classified deploys to agent-probe': validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, never deploy start. No live run, no publish, no user created, never touch experimental. No Ids, usernames, emails, hostnames or query-string URLs in any file
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/validate-org.sh pass. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Two attempts on one sha (87c33e2). The verifier refuted attempt 1 on red only: the card said "none (test-only)", and the verifier does not count an Apex test class as a test file. The brain renamed the red test to the filter-removal runs (cards PR #180), and attempt 2 rewrote the red file only. The verifier returned consistent with next=accept; no separate reviewer ran.

The brain read the whole diff. Findings:
- Each of the three named follow-up tests now inserts a record on a second account that matches the question but is not behind the summary (an open deal; a contact with a logged call; an open case). Each asserts the exact row count and that every returned row's Id is the summary's record (for cases, the summary account's own case). The existing prompt and first-row assertions stay.
- The contacts test asserts only what its scripted plan filters on (the summary's contact Ids). No anti-join was added; ExplorePlan, DataExplorer, ExploreAction and the prompt are untouched.
- docs/research/fr2-follow-ups.md's 'Tests' paragraph now says what the three tests check, and that "not called" is not checked (parked BE-43).

Red evidence (worker's account, Ids redacted): with each plan's filter removed, a check-only validate on agent-probe failed the three tests (3 of 34); restored, the validate with RunLocalTests passed.

Org: validate with RunLocalTests, then quick deploy, to agent-probe under the standing row. Only a test class changed. No live run, no publish, no user created.

Disclosed and accepted:
- The deploy and the filter-removal runs are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe so the deploy hook would run.

Still open:
- In the deals test, removing the filter failed on the older first-row assertion, which runs before the new row-count assertion, so that run does not show the new assertion failing on its own.

Privacy grep over the diff (35 added lines): 0 hits.
