# FR2 rail context: one Apex call for the rail's prefetch (BE-25)

- Covers FR2 ledger row F29 in [feature-revision-2.md](../plans/feature-revision-2.md): the rail shows open deals,
  recent activity (with emails, calls and case comments synced to Salesforce), cases and the last summary.
- The service is [CustomerSummaryContext](../../force-app/main/default/classes/CustomerSummaryContext.cls), one
  `@AuraEnabled(cacheable=true)` method `getContext(Id accountId)`. The rail (`FE-15`) calls it when it opens.
- Tests: [CustomerSummaryContextTest](../../force-app/main/default/classes/CustomerSummaryContextTest.cls).

## What it returns

| Part | Rows | Order | Fields |
| --- | --- | --- | --- |
| `openDeals` | up to 5 open Opportunities | soonest close first, no close date last | name, stage, amount, close date |
| `recentActivity` | up to 10 items | newest first, across every source | kind, text, date, who |
| `openCases` | up to 5 open Cases | High, Medium, Low, then any other priority; oldest first within one | number, subject, status, priority |
| `lastSummary` | the running user's own newest stored summary for the account, or null | | date saved, first 3 non-blank lines |
| `unavailable` | the keys of the parts that could not load for this user | | |

Every row keeps its record Id (`recordId`) so the rail can open the record. No text field carries an Id.

Recent activity merges five sources:

- **Tasks** with `AccountId` = the account and a date through today. `TaskSubtype` gives the kind: `call`, `email`
  or `task`. The platform sets a task's `AccountId` from its related record or its contact, so activity on the
  account's contacts and deals is included. A task sorts at its date and the time of day it was created.
- **Events** on the account that have started, as `event`.
- **Emails**: `EmailMessage` rows related to the account, or logged as one of those tasks
  (`EmailMessage.ActivityId`). An email replaces the task it was logged as, so a synced email shows once, as
  `email`, with its subject or, when it has none, the start of its body.
- **Case comments** on the account's cases, as `case_comment`. The rail opens the case.
- `text` is the subject, or a 140-character excerpt of the body; `who` is the contact or lead on a task or event,
  the sender of an email, and the author of a case comment.

## Access

- Runs as the signed-in user: the class is `with sharing` and all 8 queries run `WITH USER_MODE`, so object, field
  and record access apply.
- System context: none on this path. The last summary is read from the user's own row of
  `Customer_Summary_Session__c` in user mode; `Customer_Summary_Data_Access` already grants read on it.
- The account is read first. An account the user cannot see, or no Account access at all, gives an empty context.
- Each part loads on its own. A part the user cannot read (no EmailMessage access, say) comes back empty and its key
  is listed in `unavailable`; the other parts still load. An unexpected failure becomes an `AuraHandledException`
  with one fixed sentence.
- `Customer_Summary_Data_Access` grants the class; [test_permission_sets.py](../../tests/test_permission_sets.py)
  lists it as an entry point.

## Queries

One call issues at most 8 SOQL queries: the account check, open deals, open cases, tasks, events, emails, case
comments and the last summary. The open deals and open cases queries use the same filters and order as the Open
deals and Service health sections; those sections return text, not rows, so their queries are mirrored here rather
than called. Open cases are ranked in Apex from the 200 oldest open cases, because `ORDER BY Priority` follows
picklist order.

## A live call

On 2026-11-13, after a RunLocalTests validate (3 components, 286 tests, 0 failures, 91% of the class's lines
covered) and a quick deploy to `agent-probe`, one anonymous Apex call ran `getContext` as the org's admin user for
the sample account with the most open deals. The script picks the account and prints sizes only.

| Measure | Value |
| --- | --- |
| Elapsed inside Apex | 305 ms (CPU 92 ms), the first call, with no cache |
| SOQL queries | 8 |
| `openDeals` | 5 |
| `recentActivity` | 10: 3 calls, 3 emails, 2 events, 2 tasks |
| `openCases` | 5 |
| `lastSummary` | present |
| `unavailable` | empty |

The elapsed time is server time only; the rail adds the network round trip. Because the method is cacheable,
a second open of the same account can be served from the client cache.

## Limits and open items

- An email that is only linked to a contact (an `EmailMessageRelation`, with no task and no account on it) is not
  reached. Emails logged through the platform get a task, and the task carries the account.
- A task sorts at the time of day it was created, because a task has a date and no time.
- Past 200 open cases, a newer High case can be missed by the ranking.
- In Apex tests the platform returns no `CreatedBy` row for a `CaseComment`, so a comment's author falls back to the
  running user's name when they wrote it, and is empty otherwise. Whether a live org returns the author was not
  checked: `agent-probe` has no case comments.
- The sample data has no emails or case comments, so the live call shows emails only as logged tasks.
