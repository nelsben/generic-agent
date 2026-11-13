# 07. Trust, access and failure

## The outcome

The assistant shows a rep only records that rep can already open in Salesforce. When something
goes wrong, the rep reads one plain sentence that says what to do next, never a stack trace.
Granting access is one step: assign the permission set group `Customer_Summary_User` (two narrow
sets that grant nothing extra), plus Salesforce's standard Agentforce user set for the built-in agent.

## The problem it removes

An assistant that runs with broad access can show a rep a deal they are not allowed to see. One
that passes raw errors through confuses people and can expose internals. A permission set copied
from a template often grants far more than the feature needs. Here every read runs in the rep's
own access. Failures become fixed text, and the permission sets are cut to what the entry points
use.

## How it works

```mermaid
sequenceDiagram
    actor U as Rep
    participant P as Panel or agent
    participant C as CustomerSummaryPanelController
    participant R as CustomerSummaryResolver
    participant B as CustomerSummary
    participant S as CustomerSummary sections
    participant DB as CRM records
    U->>P: /brief an account the rep cannot see
    P->>C: resolve(text)
    C->>R: resolve
    R->>DB: SOQL WITH USER_MODE
    DB-->>R: no visible rows
    R-->>P: NOT_FOUND, fixed message
    U->>P: /brief a name several accounts share
    R-->>P: AMBIGUOUS, up to 8 lines of name, city and Id
    P->>C: getBrief(accountId)
    C->>B: run
    B->>S: build WITH USER_MODE
    S-->>B: ERROR, "Couldn't load Cases right now."
    B-->>P: OK with that section marked, or ERROR fixed text
    C-->>P: any unexpected exception becomes AuraHandledException with fixed text
```

1. **Sharing everywhere.** Every Apex class is `with sharing`.
2. **User mode for every read of CRM data.** The resolver, the brief's visibility check, all
   seven sections and the explorer query `WITH USER_MODE` or `AccessLevel.USER_MODE`. Object
   access, field access and sharing all apply. A rep who cannot see a field gets that section as
   ERROR, not a quiet gap.
3. **Fixed status texts.** NOT_FOUND from the resolver reads 'No account matches "…". Try a
   fuller or different account name.' A brief that cannot be finished reads "I couldn't
   finish the brief right now. Try again in a minute." These come from Apex constants, and the
   agent relays them as they are.
4. **AMBIGUOUS is a choice.** Up to 8 candidates, one line each with name, city and Id. The panel
   shows them as buttons without the raw Id.
5. **A failed part stays a part.** A section that throws becomes ERROR with "Couldn't load
   <title> right now." The brief still returns the other sections.
6. **No raw errors.** `CustomerSummaryPanelController` catches every exception. Expected ones carry
   their own user text. Anything else is logged and becomes an `AuraHandledException` with
   "I couldn't finish that right now. Try again in a minute."
7. **No markup.** The panel renders model text as plain text, never as HTML.
8. **Two narrow permission sets.** `Customer_Summary_Data_Access` shows the app, grants the five
   entry-point classes, and gives read-only access to the memory object. `Customer_Summary_Agent_Access`
   grants the agent and nothing else. `Customer_Summary_User` is a permission set group holding both.

## See it

![The panel after "/brief Zephyr Quartz Holdings": "No account matches "Zephyr Quartz Holdings". Try a fuller or different account name."](../assets/not-found.png)

![The panel after "/brief United Oil": "Several accounts match "United Oil". Which one?", then three candidate buttons, United Oil & Gas Corp. — New York, United Oil & Gas, Singapore — Singapore, and United Oil & Gas, UK — no city](../assets/ambiguous.png)

## Why you can trust it

- **Fail-closed sections are tested.** [CustomerSummarySectionErrorTest](../../force-app/main/default/classes/CustomerSummarySectionErrorTest.cls)
  `everySectionFailsClosedAndKeepsTheCauseForAUserWithoutAccess` runs every section as a user
  without access. [CustomerSummaryTest](../../force-app/main/default/classes/CustomerSummaryTest.cls)
  `brokenSourceBecomesErrorSection` and `someErrorSectionsStillGiveAnOkBrief`.
- **Resolver texts are tested.** [CustomerSummaryResolverTest](../../force-app/main/default/classes/CustomerSummaryResolverTest.cls)
  `unknownNameIsNotFound`, `tenMatchesAreAmbiguousWithEightLinesAndMore` and `blankInputIsNotFound`.
- **No raw errors reach the panel.** [CustomerSummaryPanelControllerTest](../../force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls)
  `unexpectedExceptionsBecomeFixedText` and `drillTurnsEveryExceptionIntoTheFixedText`, and the
  Jest tests "shows the fixed fallback, never raw script text" and "renders markup in answers,
  cells, section lines and follow-ups as text" in
  [customerSummaryPanel.test.js](../../force-app/main/default/lwc/customerSummaryPanel/__tests__/customerSummaryPanel.test.js).
- **The permission sets are tested.** [test_permission_sets.py](../../tests/test_permission_sets.py)
  checks that only the entry-point classes are granted, that the session object is never given
  delete, view all or modify all, and that the agent set has no class or object access.
- **Review findings are fixed in code.** From the Apex review
  ([apex-review.md](../reviews/apex-review.md)): finding 2 (Activity read Tasks in system mode),
  finding 7 (implicit access modes and discarded causes), finding 9 (the data permission set
  granted more than the engine uses), and finding 15 (drill passed raw messages to the UI). From
  the LWC review ([lwc-review.md](../reviews/lwc-review.md)): finding 10 (raw Apex errors). Each is
  fixed and covered by the tests above. The re-reviews confirm Apex findings 2, 7, 9 and 15
  fixed, with small residuals noted below, and LWC finding 10 fixed inside the methods
  ([apex-review-2.md](../reviews/apex-review-2.md), [lwc-review-2.md](../reviews/lwc-review-2.md)).
  Both rate their layer "Ready with fixes" with no blockers. The agent re-review rates the agent
  "Not ready" ([agent-review-2.md](../reviews/agent-review-2.md)); see [06](06-agent-routing-and-verbatim-relay.md).
- **It runs live.** In the Studio preview of the draft agent, cases 3, 4, 5 and 8 show NOT_FOUND and AMBIGUOUS relayed as the
  resolver wrote them ([studio-preview.md](../research/studio-preview.md)).

## Adopt it

1. Copy both permission sets from `force-app/main/default/permissionsets/`, the group from
   `force-app/main/default/permissionsetgroups/`, and `tests/test_permission_sets.py` and
   `tests/test_access_group.py`.
   **Give a user access:** assign the group `Customer_Summary_User` and the standard Agentforce user
   permission set `CopilotSalesforceUser` (the name agent-review-2 cites; the org-migration run did
   not confirm it, so check it in your org). Assign the group, not the two sets one by one: a
   missing set can make every agent turn fail.
2. Keep `with sharing` and `WITH USER_MODE` on every new query. Make every new source return
   `CustomerSummarySection.failed(...)` from its catch block.
3. Keep every user-facing failure as a constant in Apex, and wrap every new `@AuraEnabled` method
   in the controller's catch-all.
4. **Change the grants.** Add a class to `Customer_Summary_Data_Access` only when it becomes an entry
   point called from the panel or the agent. Update the Python test in the same change.

## Limits and open items

- Memory runs in system mode on purpose. The row key holds the running user's Id and the object is
  private. See [05](05-conversation-memory.md).
- Every query error in the resolver reads as NOT_FOUND, not ERROR, so a missing permission looks
  like missing data (Apex re-review N7, [apex-review-2.md](../reviews/apex-review-2.md)).
- A user without access to one field in a section, such as contact roles or event names, loses
  the whole section rather than that field, and the message reads like a passing fault (N2,
  should-fix).
- Two queries, for the prompt files and the agent's definition, run without an explicit access
  mode. Whether a non-admin can read the prompt files from Apex has not been checked; if not, every
  brief and question fails (N11).
- Access is the group `Customer_Summary_User` plus the standard Agentforce user set, named in the
  "Give a user access" step above and in the README (agent re-review N5,
  [agent-review-2.md](../reviews/agent-review-2.md)). Whether the Models API callout needs anything
  extra for a rep is unknown.
- A number in a brief line that looks like a record Id becomes a drill button, and clicking it
  can show platform error text instead of the fixed sentence (panel re-review N2,
  [lwc-review-2.md](../reviews/lwc-review-2.md)).
- Apex at API 68.0 is assumed to run plain static SOQL in user mode. The sections now state
  `WITH USER_MODE` explicitly, so they do not depend on that.

> [!WARNING]
> **Not yet proven:** a live run as a non-admin user with only the group `Customer_Summary_User` and
> the standard set. The Apex
> tests use `runAs` for users without access, which checks the code paths, not the real profile,
> the app and the agent together.
