---
id: BE-54
title: Apex tests pass in a new org whose deploying admin does not yet hold Customer_Summary_User: the 12 field-access failures OPS-62 found are gone, proven by a validate in connect-24h with the group unassigned
domain: backend
tier: standard
status: blocked
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
