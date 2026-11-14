---
id: BE-51
title: FR2: outcome tests pass at any hour — four Apex tests compare a date made as a New York test user with one made as the running user, and fail every night between midnight New York and midnight on the running user's clock
domain: backend
tier: standard
tier_reason: test-only fix with a named cause, but it needs an org validate and quick deploy, which economy workers have not done her
status: merged
fixes: [BE-35]
scope: [force-app/main/default/classes/CustomerOutcomesTest.cls, force-app/main/default/classes/CustomerSummaryTest.cls, force-app/main/default/classes/DataExplorerTest.cls, force-app/main/default/classes/CustomerSummaryContextTest.cls, force-app/main/default/classes/CustomerSummaryMemoryTest.cls, force-app/main/default/classes/CustomerSummaryHistoryTest.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls]
forbid: [force-app/main/default/classes/CustomerOutcomes.cls, force-app/main/default/classes/CustomerSummary.cls, force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/CustomerSummaryContext.cls, force-app/main/default/classes/CustomerSummaryMemory.cls, force-app/main/default/classes/CustomerSummaryHistory.cls, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: CustomerOutcomesTest's two retention cases, with the author in Pacific/Kiritimati, fail in agent-probe on main's code (the expiry is one day off the running user's Date.today()) and pass after
gate: test, org
budget: 2-attempts
spend: 8
---
## Why

BE-27's validate in agent-probe failed four tests it did not touch, at 23:50 and 00:10 Central: CustomerOutcomesTest.aTypeWithItsOwnRetentionIsHonoured and anActionAndASavedAnswerExpireAfterTheirTypesRetention, CustomerSummaryTest.aNewSummaryThroughTheActionSeesTheLastSummarysHeadlineAndDate and DataExplorerTest.theActionSeesTheOpenAccountsOutcomeContext. Each builds the value inside System.runAs of a test user with TimeZoneSidKey America/New_York, but computes the expected date outside runAs (Date.today() or Datetime.now().format('yyyy-MM-dd')) as the running user, whose zone is behind New York, so for a few hours each night the two dates differ by one. Until fixed, every RunLocalTests deploy to agent-probe fails in that window.

## Done when

- The four named tests compute their expected date as the same user, and in the same time zone, that made the value: for example inside the same System.runAs block, or from that user's TimeZoneSidKey. No production class changes: CustomerOutcomes stamps the expiry from the creating user's Date.today(), and that stays as it is.
- Every other test in force-app/main/default/classes/*Test.cls that compares a date or a yyyy-MM-dd text made inside System.runAs with one made outside it is fixed the same way. The hand-back lists each test it checked and each it changed.
- The bug shows at any hour, not only at night: the author in the two CustomerOutcomesTest cases is created with TimeZoneSidKey Pacific/Kiritimati (UTC+14), which differs from the running user's date for most of the day. The red evidence is those cases failing in agent-probe on main's code with that zone, and passing after the fix.
- A validate of only the changed test classes with RunLocalTests in agent-probe passes with 0 failures, then a quick deploy with CONFIRM_PROD=1. The hand-back gives the test count and the UTC time of the run. Never use sf project deploy start.
- No org record is created outside Apex tests, no user or assignment changes, nothing is published.
- PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh pass; no tests/__pycache__, and git status --short is empty after the commit.

## Review

Brain review (2026-11-14). One attempt (6d740ce). The verifier found the report consistent and returned next=accept, so no separate reviewer ran. The brain found the cause from BE-27's failing validate before cutting the card and read the diff stat (3 test classes, 27 added lines).

Cause: four tests from BE-35 built a date inside System.runAs of a test user in America/New_York but computed the expected date outside it, as the running user, whose clock is behind New York. Every night between midnight New York and midnight on the running user's clock the two dates differed by one, so any RunLocalTests deploy to agent-probe failed in that window (BE-27 hit it at about 05:50 and 06:10 UTC).

Findings:
- CustomerOutcomesTest's newUser and rep take an optional time zone (default America/New_York). The two retention cases use an author in Pacific/Kiritimati (UTC+14), so the bug shows at most hours, and read Date.today() inside the author's runAs block.
- CustomerSummaryTest and DataExplorerTest format the expected yyyy-MM-dd text inside runAs.
- The worker checked the other date comparisons in the outcome, context, memory, history, panel controller, resolver and section tests and left them, as each compares dates made by one user.
- No production class changed: the expiry is still stamped from the creating user's Date.today().

Red: with the Kiritimati author, both retention cases failed in agent-probe on main's code (each expiry one day off); they pass after.

Org (worker's account): a validate of the three test classes with RunLocalTests (422 tests, 0 failures, at about 06:17 UTC, inside the failing window), then a quick deploy with CONFIRM_PROD=1. No record, user or assignment changed.

Gate (verifier): 176 Python tests, check-docs, validate-org pass (131 components, 329 tests).

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- One validate-org run moved to the background after a shell timeout; the worker waited on it.

Privacy grep over the diff (27 added lines): 0 hits.
