---
id: BE-48
title: FR2: the three named follow-up tests assert the records the filtered plan returns, not only the prompt and the first row
domain: backend
tier: standard
tier_reason: test-only change to one Apex test class with a clear assertion target
status: queued
fixes: [BE-30]
scope: [force-app/main/default/classes/DataExplorerTest.cls, docs/research/fr2-follow-ups.md]
forbid: [force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/ExplorePlan.cls, force-app/main/default/classes/ExploreAction.cls, force-app/main/default/staticresources/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (test-only)
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
