---
id: BE-54
title: Apex tests pass in a new org whose deploying admin does not yet hold Customer_Summary_User: the 12 field-access failures OPS-62 found are gone, proven by a validate in connect-24h with the group unassigned
domain: backend
tier: standard
status: merged
blocked_by: [BE-53, FE-28]
scope: [force-app/main/default/classes/*Test.cls, force-app/main/default/classes/*Test.cls-meta.xml, force-app/main/default/classes/CustomerSummaryTestUsers.cls, force-app/main/default/classes/CustomerSummaryTestUsers.cls-meta.xml, docs/research/fresh-org-run.md]
forbid: [force-app/main/default/objects/**, force-app/main/default/permissionsets/**, force-app/main/default/permissionsetgroups/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, README.md, data/**, scripts/**, tests/**, agents/**, docs/plans/**, spikes/**, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json]
resources: [org-connect]
red_test: a RunSpecifiedTests validate in connect-24h, run as an admin without Customer_Summary_User, fails 12 tests on main and 0 on the branch
gate: test
budget: 2-attempts
spend: 20
---
## Why

OPS-62's clean install in connect-24h found that the README's order fails in a new org: the deploy runs our tests as the admin before README step 3 assigns Customer_Summary_User, and 12 of 425 tests fail because user-mode queries cannot see the new fields (Related_Record_Id__c on Customer_Outcome__c, Session_Key__c on Customer_Summary_Session__c). In agent-probe the admin always held the group, so this never showed. The tests must not depend on the deploying user's permissions.

## Done when

- **Org guard first, before any org step.** Run `sf org display -o connect-24h --json` and `sf org display -o agent-probe --json` and compare `result.id` and `result.username` in a shell expression that prints only SAME or DIFFERENT, never the values. If connect-24h does not resolve, or either value is the same, take no org step and say so
- Read first: docs/research/fresh-org-run.md's OPS-62 section (the 12 failures and the order that got the org up), and the three failing classes: CustomerSummaryContextTest, CustomerSummaryActionsTest and CustomerSummaryActionUpdatesTest. Some of their methods already run as a test user that is given a permission set inside the test (System.runAs with a PermissionSetAssignment); the failing methods run as the deploying user. Load the skills salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- **The fix is in the tests only.** Every test method that reads or writes Customer Summary's own objects and fields runs as a test user created inside the test that holds the product's permission sets (Customer_Summary_Data_Access and Customer_Summary_Outcome_Access, or the Customer_Summary_User group), never as the deploying user. Put the shared set-up in one helper (an existing test utility class if there is one, otherwise a new @IsTest class) rather than copying it into each class. Product classes are unchanged: user-mode access is the product's rule. Check every *Test.cls under force-app for the same dependency, not only the three that failed, and list the classes changed
- **Red, then green, in connect-24h** (Ben gave full control of that org on 2026-11-15; the Approvals row 'FR2+: Agentforce Coworker live steps' records it). Only `connect-24h`, with `-o connect-24h` on every `sf` command. Remove the running admin's Customer_Summary_User assignment (record that you did). Validate the README's 13 `--source-dir` list from main's tests with `--test-level RunSpecifiedTests --tests <every *Test.cls name>` and `--async`, and read the result with `sf project deploy report` (foreground calls under 10 minutes each, never a timed-out client): the 12 failures appear (red). Validate again from your branch: 0 failures (green). Validate only; do not quick deploy. Then assign Customer_Summary_User to the admin again and check that it is assigned. Never sign in, enter credentials or create a real user (a User inserted inside an Apex test is rolled back and is fine)
- Record in docs/research/fresh-org-run.md, under the OPS-62 section, a short 'Fixed by BE-54' paragraph: the cause, the classes changed, and the red and green test counts. If the README's quick start can now run in its written order, say so there and keep the README unchanged; otherwise say what still blocks it
- No org Ids, record Ids, job Ids, usernames, emails or hostnames in any file or in the hand-back. Workers may read docs/plans/** and run scripts/check-docs.sh but edit neither
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. End with the [[report]] line

## Review

Brain review (2026-11-15). One attempt (632a7c1, f137ce7), sonnet, standard tier, $1.19. The mod judged it consistent and accepted it without a reviewer pass; the brain read the diff and checked the org.

Findings:
- New @IsTest helper CustomerSummaryTestUsers.productUser(): a System Administrator user, inserted inside the test (rolled back), that holds Customer_Summary_Data_Access and Customer_Summary_Outcome_Access. It is with sharing, reads WITH USER_MODE and inserts as user, so it needs no system-context exception under the repo's trust rule.
- Every test method that touches the product's objects now runs inside System.runAs of that user, across 8 test classes. Methods that already used runAs are unchanged. No product class, object, permission set or group changed. Most of the diff is re-indentation inside the runAs blocks.
- Red/green in connect-24h, with the admin's Customer_Summary_User assignment removed for each run: main's tests failed 12 of 425 (the OPS-62 set); the branch passed 425 of 425 (150 components), three times, the last on f137ce7. Check-only validates with RunSpecifiedTests over the 31 test classes; no quick deploy.
- docs/research/fresh-org-run.md: a "Fixed by BE-54" paragraph with the cause, the classes and the counts.

Gate (worker, gate-mac lane): Python 390 tests, 4 skipped; check-docs 0 broken. Mod: green.

Org: the admin's group assignment was removed and given back three times. The brain confirmed by query after the hand-back that the admin holds Customer_Summary_User (count 1). No real user was created.

Disclosed and accepted:
- A second round changed the helper to user mode after test_trust_rule flagged a system-context marker.
- The page's line that the e2e frontdoor check still blocks predates FE-29's merge; FE-29 fixed the landing check, and what is left is the intermittent hotkey spec.

Still open:
- The README's production two-step (validate RunLocalTests) still cannot pass in connect-24h, because the orgfarm template's own classes do not compile. In an org whose classes compile, the validate path should now pass in the README's order. That is not yet shown in such an org.

Privacy check over the full branch diff (1,629 added lines, mostly re-indented tests): 0 denylist hits. The pattern hits are an @IsTest annotation and the example.com test addresses; the only URL host is the standard soap.sforce.com metadata namespace.
