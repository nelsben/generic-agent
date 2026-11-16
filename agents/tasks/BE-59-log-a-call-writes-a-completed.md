---
id: BE-59
title: Log a call writes a completed Task with subtype Call (F17): LOG_CALL_AS set to Task, tests and docs follow, deployed to agent-probe
domain: backend
tier: standard
status: queued
fixes: []
scope: [force-app/main/default/classes/CustomerSummaryActions.cls, force-app/main/default/classes/CustomerSummaryActionsTest.cls, force-app/main/default/classes/CustomerSummaryActionCatalog.cls, force-app/main/default/classes/CustomerSummaryActionCatalogTest.cls, force-app/main/default/classes/CustomerSummaryActionDoorTest.cls, force-app/main/default/classes/CustomerOutcomes.cls, force-app/main/default/lwc/customerSummaryConversation/customerSummaryConversation.js, force-app/main/default/lwc/customerSummaryConversation/__tests__/customerSummaryConversationActions.test.js, tests/test_mcp_door.py, docs/patterns/13-write-actions.md, docs/patterns/09-outside-door-mcp.md, README.md, docs/research/fr2-log-call-task.md]
forbid: [docs/plans/**, agents/**, .chassis-delegation.json, reference/**, mcp-door/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, data/**, sfdx-project.json]
resources: [org-live]
red_test: CustomerSummaryActionsTest's default-path log_call test asserting a completed call Task fails when validated against the current org code (objectName Event) and passes after
gate: test
budget: 2-attempts
spend: 10
---
## Why

Ben answered F17 on 2026-11-16: "yes, switch it to task". Salesforce's own Log a Call saves a completed Task with TaskSubtype Call, and activity reports filter on that subtype, so a logged call written as an Event does not show in call reports. BE-27 already built and tested the Task path behind one constant.

## Done when

- Approval first: read the row "FR2+: log a call writes a completed Task with subtype Call instead of an Event" in docs/plans/gtm-burn-plan.md on origin/main. If its status does not start with "approved", change nothing in the org and hand back.
- CustomerSummaryActions.LOG_CALL_AS is 'Task', and the class comment above it says Ben chose a Task on 2026-11-16 (F17) and that setting it to 'Event' switches back. A logged call is a Task with Status Completed, TaskSubtype Call, ActivityDate today unless the person gave a date, Subject 'Call' by default, WhoId the contact (required), WhatId the account, Description the notes. Read buildCall first: the Task branch exists; change behaviour only where a test shows it is wrong.
- Apex tests: the default-path log_call test now asserts a completed call Task (objectName 'Task', Status, TaskSubtype, ActivityDate, WhoId, WhatId). The Event shape keeps one test that sets logCallAs = 'Event' through @TestVisible, so switching back stays proven. Check every class that names log_call (CustomerSummaryActionCatalogTest, CustomerSummaryActionDoorTest, CustomerSummaryActionsTest, CustomerOutcomes) and fix any assertion that assumed an Event. The draft text a person sees before confirming names the right object.
- Jest: customerSummaryConversationActions.test.js and customerSummaryConversation.js are checked for any text or fixture that says a logged call is an Event; change only what is wrong. tests/test_mcp_door.py is checked the same way. The MCP descriptionOverride texts need no change unless they name Event.
- Docs: docs/patterns/13-write-actions.md (the action table row for log_call and the LOG_CALL_AS section) and docs/patterns/09-outside-door-mcp.md say a logged call is a completed Task with subtype Call by default, and how to switch back. Any README line that says Event for log_call is fixed. A short note docs/research/fr2-log-call-task.md records: Ben's answer, why (Salesforce's Log a Call saves a completed Task with subtype Call; reports filter on TaskSubtype), what changed, the deploy and test counts, one live check, and an Undo section.
- Deploy to agent-probe only: validate with RunLocalTests (sf project deploy validate --source-dir <changed source dirs> -o agent-probe --test-level RunLocalTests --wait 40 --json), then CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o agent-probe --wait 30 --json. Job ids stay in shell variables, never in files. Record the test count and failures.
- One live check in agent-probe (approved under the standing row for tests that create their own records): through anonymous Apex, draft and commit one log_call on Gallowglass Textiles with one of its contacts, read back the record (object, Status, TaskSubtype, ActivityDate, WhatId set), then delete that Task and the Customer_Outcome__c row the commit wrote, and confirm both are gone. Record only counts and field values, no Ids.
- Org rules: agent-probe only, -o agent-probe on every sf command; never touch experimental; no destructive deploy; no user, no sign-in, no credential; no NoTestRun deploy. Unset any worktree-local target-org before handing back. No Ids, usernames, hostnames or URLs in any file.
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npx jest (all suites), and bash scripts/check-docs.sh (0 broken). No tests/__pycache__; git status --short empty after the commit.
