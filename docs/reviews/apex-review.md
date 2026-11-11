# Apex review (OPS-11)

Lane: every file in `force-app/main/default/classes` (21 production classes, 18 test classes), `objects` (Account_Brief_Session__c) and `permissionsets` (2 sets).
Standard: the skills platform-apex-generate, platform-apex-test-generate, platform-soql-query and platform-permission-set-generate, read against ARCHITECTURE.md and the corrective plan.

## Summary

**Verdict: sound with fixes.**
The explorer's injection defence is strong. Every value is bound, and the SOQL text is built only from catalog paths and fixed tokens. Every class is `with sharing`, and the brief engine degrades a failed part into a status instead of throwing.
I found no blockers. There are ten should-fix items. Three of them are worth doing first:
- a brief where every section failed is reported as "nothing on record";
- one section reads Tasks in SYSTEM_MODE with no justification;
- three paths can hit limits that cannot be caught: a resolver SOQL-in-loop, aggregate queries with no row cap, and DML before a callout in bulk invocations.

The tests check behaviour and exact values, not just coverage. They have no bulk cases, no data factory, and almost no restricted-user runs.
The permission sets grant more than the engine uses. Whether a non-admin can run a brief is **unverified**.

**Access-mode assumption.** Every class is at API 68.0. The apex-generate skill says user mode is the default for Apex at API 67.0 and above, so plain static SOQL throws when field-level security (FLS) is missing. I did not confirm this against platform docs or the org.

Findings 2 and 7 hold either way:
- If the default holds, sections fail closed: an unreadable field turns the whole section into ERROR.
- If it does not hold, the static SOQL in the sections enforces sharing but not FLS.

**Access-mode inventory (every query and DML).** All 21 classes are `with sharing`.
- Explicit USER_MODE: `ExploreQuery.cls:54,76`, `DataExplorer.cls:274`.
- Explicit SYSTEM_MODE: `AccountBriefMemory.cls:93` (upsert) and `:131` (read). Both are justified and acceptable: the key includes the running user's Id, the object is Private, and the user never chooses the row. `AccountBriefActivitySection.cls:86` is not justified (finding 2).
- Implicit (API default): all other static SOQL in the 7 sections, the resolver, `AgentLlm.cls:56` and the panel controller. The only DML is the memory upsert.

Severity is blocker / should-fix / nit. "Verified" means confirmed by reading the code or an existing test; nothing was executed in an org. Tags are `new` or `planned §N` (corrective-plan.md).

## Findings (most severe first)

**1. A brief where every section failed is reported as EMPTY.** `AccountBrief.cls:136-140`
- *What is wrong:* `anyOk` counts only OK sections. If every section is ERROR, or a mix of ERROR and EMPTY, the brief finishes with status EMPTY and the text "Nothing is on record for the requested sections." Memory then records that turn as EMPTY.
- *Failure scenario:* a non-admin lacks FLS on one field in each section, or a platform problem breaks every query. The rep is told the account has no data, when the brief actually failed.
- *Fix:* if no section is OK and at least one is ERROR, finish with ERROR and ERROR text.
- should-fix · verified · apex-generate ("prevent silent failures") · new

**2. The Activity section reads Tasks in SYSTEM_MODE with no justification.** `AccountBriefActivitySection.cls:83-87`
- *What is wrong:* `Database.queryWithBinds(..., AccessLevel.SYSTEM_MODE)` bypasses CRUD and FLS on Task Subject, TaskSubtype, Type and Who.Name. Sharing still applies through the class keyword. Every other section query runs in the default mode. Neither the code nor the commit that added it (BE-4) gives a reason.
- *Failure scenario:* a user without FLS on Task.Subject gets subjects in the brief and in the model prompt. ARCHITECTURE.md says the brief "adds no visibility the user lacks".
- *Fix:* use `AccessLevel.USER_MODE`. The dynamic string exists only for the optional Type field, so it can stay.
- should-fix · verified · apex-generate ("only explicitly justified usages of SYSTEM_MODE") · new

**3. Bulk invocations hit callout-after-DML.** `AccountBriefGetAction.cls:32-35` with `AccountBrief.cls:143-147`
- *What is wrong:* `getBriefs` calls `run()` once per request. Each `run()` ends with the memory upsert, so request 2's model callout follows request 1's DML. The code's own comment at L142 says this ordering is not allowed.
- *Failure scenario:* a Flow or batch sends two requests. The second brief's synthesis call throws "uncommitted work pending", which is caught, and the request returns ERROR every time. SOQL and callouts also run inside the loop.
- *Fix:* either collect the memory writes and upsert once after the loop, or document and enforce one request per call (return ERROR for any extra requests).
- should-fix · verified by reading (not executed) · apex-generate (no DML/SOQL in loops, bulkify invocables) · new

**4. Aggregate queries have no row cap, so they can hit the 50,000 query-row limit.** `ExploreQuery.cls:139-141`, `ExplorePlan` row-limit rule
- *What is wrong:* an aggregate without groupBy gets no LIMIT, and a grouped one only limits groups. Every record a SUM, AVG, MIN or MAX aggregates counts toward the 50,000 query-row limit; I did not confirm how COUNT()/COUNT(Id) are counted. That LimitException cannot be caught.
- *Failure scenario:* "total pipeline across all opportunities" becomes `SUM(Amount) FROM Opportunity` with no filter. In an org with more than 50k opportunities the whole action dies with no status, and the agent shows a platform error. The section aggregates have the same shape but are scoped to one account, so the risk there is much lower: `OpenDeals:46` (SUM), `Cases:57` (MIN), `DealHistory:46` (AVG).
- *Fix:* require a filter or groupBy for SUM/AVG/MIN/MAX on large objects, or run a capped pre-check (for example `SELECT Id ... LIMIT 50001`, or a COUNT() once its row accounting is confirmed) and refuse above a threshold.
- should-fix · suspected (depends on data volume) · soql-query (governor limits), apex-generate · new

**5. The resolver runs one SOQL per pasted Id.** `AccountBriefResolver.cls:67-73`
- *What is wrong:* the `while (m.find())` loop calls `visibleAccount()` (one SOQL, L113) for each `001…` token until one is visible, then returns.
- *Failure scenario:* a user pastes a list of 100 or more Account Ids that are not visible to them: deleted, from another org or sandbox, or shared away. The 101st query throws a LimitException that cannot be caught, and the panel or agent action fails outright. One visible Id early in the list avoids it.
- *Fix:* collect the matches into a `Set<Id>`, run one `WHERE Id IN :ids WITH USER_MODE` query, and keep the first visible match.
- should-fix · verified · apex-generate hard stop (no SOQL in loops) · new

**6. Running out of turns throws away good results.** `DataExplorer.cls:78-95`
- *What is wrong:* nothing makes the model answer on its last turn.
- *Failure scenario:* turn 1 is INVALID and turns 2-5 each run a query. The loop exits and returns ERROR with "Try again in a minute", and `ExploreAction` shows only that text. Four valid result sets are dropped, and retrying repeats the cost. The test `queryPastCapIsRefusedAndRunningOutOfTurnsIsAnError` locks this behaviour in.
- *Fix:* on the final turn, tell the prompt to answer only. If the turns still run out with results in hand, return a PARTIAL status or OK with the last result table.
- should-fix · verified · apex-generate (error handling: recover where possible) · new

**7. Section queries leave their access mode implicit, and their catch blocks discard the cause.** The 7 section classes; catch lines: Profile:23, OpenDeals:26, Cases:30, Contacts:60, Activity:26, Calls:29, DealHistory:25
- *What is wrong:* the static SOQL relies on the API-version default (see the assumption above). Each `catch (Exception e)` drops `e` without logging it.
- *Failure scenario:* under user mode, one unreadable field (for example Account.AnnualRevenue or Event.Description) turns the whole section into ERROR, and nothing records why. If the default is system mode instead, those fields reach the model.
- *Fix:* add `WITH USER_MODE` explicitly, use `Security.stripInaccessible` or drop optional fields after a describe check, and log `e.getTypeName()` and the message.
- should-fix · suspected · apex-generate (CRUD/FLS; always handle exceptions) · new; the non-admin run is planned §6

**8. A date-only value on a Datetime field compares against midnight GMT.** `ExplorePlan.cls:576-581`
- *What is wrong:* `dateValue` turns a Date into `Datetime.newInstanceGmt(y,m,d)` for Datetime fields.
- *Failure scenario:* `CreatedDate = 2026-01-05` matches only records created at exactly midnight GMT, so the answer is a confident and wrong "none". `>=` and `<` are also off by the user's timezone offset.
- *Fix:* for `=` on a Datetime field, rewrite to the range `>= day start AND < next day start` in the user's timezone. For range operators, use local midnight (`Datetime.newInstance`).
- should-fix · verified by reading · soql-query (date handling) · new

**9. The data permission set grants more than the engine uses.** `Account_Brief_Data_Access.permissionset-meta.xml`
- *What is wrong (session object):* the set grants Create, Read and Edit on Account_Brief_Session__c, and read and edit on all 9 fields. The engine writes and reads memory in SYSTEM_MODE (`AccountBriefMemory.cls:93,131`), so none of those grants is used.
- *What is wrong (classes):* it grants all 21 classes, when only the entry points need access: the two invocables, `AccountBriefPanelController`, and `AccountBriefMemory` if its invocable stays.
- *Failure scenario:* any holder can edit their own memory rows through the API. That includes Turns_JSON, which the panel shows as history (`AccountBriefPanelController.cls:59`); no prompt reads it today. The sharing model is Private, so this is self-tampering only.
- *Fix:* keep Read only, or none, on the object. Grant only the entry-point classes.
- `tests/test_permission_sets.py` currently asserts both the Create/Edit grant and the every-class grant, so this fix has to change that test too.
- should-fix · verified · permission-set-generate (least privilege) · new

**10. A dead write action is exposed to Flow and Agent builders.** `AccountBriefMemory.cls:38-55`
- *What is wrong:* the invocable `recordFromFlow` ("Record Account Brief") is called only by tests; the engine calls `record()` directly.
- *Failure scenario:* it accepts any `accountId` and upserts in SYSTEM_MODE without the visibility check that `AccountBrief.run` does. A builder can wire it up and write memory rows linked to accounts the user cannot see.
- *Fix:* delete it, or make it check visibility. Also update the stale class doc at L1-11 ("the Flow calls record() last, after the prompt template calls").
- should-fix · verified (grep: only AccountBriefMemoryTest and an old BE-6 card) · apex-generate · new

**11. Memory writes race, and rows grow without bound.** `AccountBriefMemory.cls:65-93`
- *What is wrong:* `record()` reads, modifies and writes without `FOR UPDATE`. Each row's size is bounded (a ring of MAX_TURNS, Last_Brief clipped to 32768), but one row per user and account is kept forever.
- *Failure scenario (race):* two briefs for the same user and account run at the same time with no existing row. Both insert, the unique key rejects one with DUPLICATE_VALUE, the error is swallowed, and that turn is lost. With an existing row, the last writer wins, so Brief_Count and Turns_JSON lose a turn.
- *Failure scenario (growth):* row count grows with users × accounts ever briefed.
- *Fix:* `SELECT ... FOR UPDATE` and retry once on DUPLICATE_VALUE. Add a purge (for example, rows with Last_Activity older than N days) when one is needed.
- nit (memory is best-effort and losses are rare) · suspected · apex-generate · new

**12. Permission sets have no descriptions.** Both permission sets lack `<description>`.
- nit · verified · permission-set-generate · planned §3

**13. The provider seam leaves output length and some errors uncontrolled.** `AgentLlmModelsApi.cls:12-22`, `AgentLlm.cls:12`
- *What is wrong:*
  - `maxTokens` is accepted and ignored, so nothing caps reply length.
  - Only `createChatGenerations_ResponseException` is caught and wrapped.
  - The class doc's "Every failure is an AgentLlm.LlmException" is not true for other provider exceptions.
  - There is no per-call timeout control. One brief makes 1 call; one explore makes up to 5 sequential calls against the 120-second total callout limit and the agent action timeout.
- *Handled well:* empty and blank replies throw.
- *Fix:* catch `Exception` in the provider and wrap it with the cause; correct the doc. Track the timeout budget under plan §6.
- nit · verified (timeouts suspected) · apex-generate · new; timeouts planned §6

**14. Prompts are loaded with one SOQL per model call.** `AgentLlm.cls:56`
- *What is wrong:* a StaticResource query runs on every call, so up to 5 per explore.
- *Failure scenario:* this wastes queries, and whether a non-admin can read StaticResource in user mode is unverified.
- *Fix:* add a static `Map<String,String>` cache per transaction.
- nit · suspected · apex-generate (transaction cache) · new

**15. `drill` lets some exceptions through and passes raw messages to the UI.** `AccountBriefPanelController.cls:38-50`
- *What is wrong:* `drill` catches ExploreException, QueryException and NoAccessException. A `ExplorePlan.PlanException`, or any other exception from `DataExplorer.drill` → `ExploreQuery.run`, reaches the LWC unwrapped.
- The `handled(e.getMessage())` call passes QueryException text, which can include field names, straight to the UI.
- *Fix:* add a final `catch (Exception e)` that throws a generic AuraHandledException.
- nit · suspected · apex-generate (`@AuraEnabled` error handling) · new

**16. Invocable contracts: a missing null guard and no `callout=true`.** `ExploreAction.cls:27-30`, `AccountBriefGetAction.cls:23-26`
- *What is wrong:* in `ExploreAction`, a null `requests` or a null element causes a NullPointerException; the other invocables guard against this. Neither callout-making invocable declares `callout=true`, which the skill requires so Flow can order the transaction around the callout.
- nit · verified · apex-generate (null safety; invocable decorator rules) · new

**17. The resolver's partial-name search uses a leading wildcard.** `AccountBriefResolver.cls:82-92`
- *What is wrong:* `Name LIKE '%term%'` cannot use an index. It is bounded by LIMIT and the COUNT() is separate, but it scans the whole table on large Account tables. There is also no try/catch, so a QueryException in the AMBIGUOUS path (for example, no FLS on BillingCity) reaches the agent unhandled.
- nit · verified / suspected · soql-query (selectivity) · new

**18. Small hygiene items.**
- `money()` is duplicated in Profile:89, OpenDeals:144 and DealHistory:108.
- `System.debug` appears only in catch blocks, which the skill allows in place of a logging framework.
- A brief with some ERROR sections still reports OK. That is acceptable if synthesis mentions the gap, but it is untested.
- nit · verified · apex-generate · new

## Tests

**Strengths.**
- Tests assert behaviour (mostly exact rendered lines, not coverage) with `Assert.*`; ordering tests insert rows out of order on purpose; every model call goes through `AgentLlm.stub`.
- Good negative paths: resolver wildcards and blank input, plan validation, injection (`ExploreQueryTest.quoteAndKeywordsAreBoundNotInjected`), broken source and model failure in AccountBriefTest, and a null Id giving an ERROR section in each section test.

**Gaps.**
- Legacy `System.assertEquals/assertNotEquals` throughout AccountBriefMemoryTest. nit · verified · planned §3.
- No TestDataFactory: every class builds its data inline. nit · verified · planned §3.
- No invocable is tested with more than one request, which would have caught finding 3. should-fix · verified · new.
- No 251+ record bulk test anywhere; the largest is 12 Tasks or 8 Contacts. should-fix · verified · new.
- Restricted users (`runAs`) appear only in ExploreCatalogTest (Minimum Access profile) and the memory two-user test. No section, brief or explorer query runs as a user without FLS, so findings 2 and 7 are untested. should-fix · verified · new (live non-admin run planned §6).
- Org data or metadata: AccountBriefMemoryTest looks up the 'Standard User' profile by name; `AccountBriefPanelControllerTest.agentIdIsABotDefinitionIdOrNull` asserts conditionally on the org's BotDefinition; AgentLlmTest needs the deployed static resources (acceptable). nit · verified · new.
- Few tests use `Test.startTest/stopTest`, so limit use is never isolated. nit · verified · new.
- No memory concurrency test (hard in Apex), and AgentLlmModelsApiTest can only test request shape because the Models API callout cannot be mocked. nit · verified · new.

**Rubric.** The apex skills have no numeric rubric. Only platform-soql-query has a score guide (90+ production-ready, 80-89 good, 70-79 performance concerns, under 70 revise). I applied it per query family:

- Explorer **84** (bound values, USER_MODE, LIMIT and clamp; loses points for uncapped aggregates).
- Sections **78** (AccountId filters with caps; loses points for implicit mode, Activity SYSTEM_MODE, account-wide aggregates).
- Resolver **70** (SOQL in a loop, leading wildcard).

For tests, I scored the test-skill principles out of 100 with my own weights: behaviour assertions 18/20, negative paths 13/15, Assert class only 7/10, bulk 251+ 2/15, factory 3/10, no org data 7/10, runAs/permissions 4/10, startTest isolation 4/10. **Total 58/100**, which on the SOQL skill's bands reads as "revise". The cause is missing bulk and restricted-user cases, not weak assertions.

## Permission sets

- **Agent_Access** grants only the agent and has no description. It is fine apart from finding 12.
- **Data_Access** grants the app, every class and Create/Read/Edit on the session object (finding 9).
- Neither set grants Account, Opportunity, Case, Contact, Task or Event access, or any Models API or Agentforce user permission. Those depend on the user's profile or licence.

**Can a non-admin holding both sets run a brief? UNVERIFIED.** Nothing in the repo or the tests proves it, and I ran nothing in the org. Plan §6 already lists "Everything as a non-admin user". Expected risks:
- Models API access from Apex for a standard user;
- StaticResource read in user mode;
- FLS on the section fields (findings 1 and 7 decide whether this fails loudly or quietly).

## Deliberate differences (not defects)

- **Status-based responses instead of `isSuccess`/`errorMessage`/`errorType`** (ARCHITECTURE choice). *Opinion:* keep them; one status string is easier for the agent to route on. But log the error type, which the swallowed exceptions in finding 7 currently lose.
- **Apex only, no Flows.** *Opinion:* right for testability. `recordFromFlow` contradicts it, so removing it (finding 10) brings the code in line.
- **Prompts as static resources instead of prompt templates.** *Opinion:* fine; prompts stay in source control and testable with the stub. Costs: one SOQL per call (finding 14), no Prompt Builder versioning or admin UI.
- **No Service/Selector layering; inline SOQL per section.** *Opinion:* each section already is a small capped data-access unit; a Selector layer adds classes, not safety, at this size.
- **User text in constants instead of Custom Labels.** *Opinion:* acceptable while English-only; move to Labels if localised.

## Not reviewed, and why

- Prompt static resources, LWC, the agent bundle, app/tab/layout metadata: outside this lane.
- Live org behaviour: org access was read-only and I ran no org queries, so every org claim above is unverified.
- Apex tests were not run in any org. This was a read-only review, and the brief forbids running all local tests there. Coverage numbers are therefore not known.
- Code Analyzer: the plugin (5.16.0) is present, and I ran it with `pmd:Recommended` on the classes folder, output kept outside the repo. The PMD, SFGE and CPD engines could not start because no Java runtime is installed, so there are no analyzer results. Installing Java was out of scope. Adoption is planned §3.
- The API 68 default-user-mode claim was taken from the apex-generate skill and not confirmed in platform documentation.
