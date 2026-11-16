# FR2+: log a call writes a completed Task (F17, BE-59)

Researched and built 2026-11-16. Status words: verified (seen in the `agent-probe` org).

## Ben's answer

On 2026-11-16 Ben answered F17: "yes, switch it to task". The approval row is in the gtm burn plan.

## Why

Salesforce's own Log a Call saves a completed Task with TaskSubtype Call, and activity reports filter on that subtype. A
call logged as an Event does not show in call reports. BE-22 had measured both shapes (both land in the account's activity
history), and BE-27 had built and tested the Task path behind one constant.

## What changed

- `CustomerSummaryActions.LOG_CALL_AS` is now `'Task'`. A logged call is a Task with Status Completed, TaskSubtype Call,
  ActivityDate today unless the person gave a date, Subject `Call` by default, the contact as WhoId (required), the account
  as WhatId and the notes as Description. `buildCall` already had this branch; no behaviour changed in it.
- `logCallObject()` now treats anything other than `'Event'` as a Task.
- Apex tests: the default-path log_call test asserts the completed call Task (object, Status, TaskSubtype, ActivityDate,
  WhoId, WhatId). One test sets `logCallAs = 'Event'` through the test seam, so switching back stays proven. The catalog
  test expects `Task`. The door test follows `logCallObject()` and needed no change.
- Jest, the MCP door tests and the MCP description texts named no Event for a logged call and were not changed.
- Docs: patterns 13 and 09 and this note.

## Deploy and tests

- Red first: the new default-path test and the catalog test failed against the then-current org code (expected Task, got
  Event).
- Validated with RunLocalTests against agent-probe: 565 tests run, 0 failures, 0 component errors. Quick deploy succeeded,
  68 components.
- Repo gates: 409 Python tests (4 skipped), 397 Jest tests in 11 suites, docs check 0 broken.

## Live check (agent-probe)

Through anonymous Apex, one log_call was drafted and committed on Gallowglass Textiles with one of its contacts. The draft
was READY with object Task. The record read back as a Task with Status Completed, TaskSubtype Call, ActivityDate today,
WhatId the account and WhoId the contact. The commit wrote one Customer_Outcome__c row. Both the Task and the row were
deleted, and a count afterwards showed 0 of each remaining.

## Undo

Change `LOG_CALL_AS` to `'Event'` in `CustomerSummaryActions.cls`, then validate and quick deploy. Nothing else changes: the
Event branch and its test stay. Calls already logged as Tasks stay as Tasks.
