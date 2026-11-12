# Apex review 2 (OPS-16)

Second read-only review of the Apex layer after the OPS-11 fixes. Scope: every file under
`force-app/main/default/classes/`, `permissionsets/`, `objects/` and the `AgentPrompt_*` static
resources, read against `docs/reviews/apex-review.md` (the earlier review) and `docs/ARCHITECTURE.md`.
No code was changed. Nothing in the org was run or changed for this review, and no Apex tests were run.

Salesforce skill references used (plugin salesforce-development 2.7.0):
- `platform-apex-generate/SKILL.md`: hard stops (no SOQL or DML in loops, handle every exception), invocables, SYSTEM_MODE only when justified, and user mode as the default at API 67+. That last claim is still **unverified** against platform documentation.
- `platform-apex-test-generate/SKILL.md`: bulk 251+, Assert class, runAs for user-mode code, mock boundaries.
- `platform-soql-query/SKILL.md`: no queries in loops, wildcards, aggregate row cost.
- `platform-permission-set-generate/SKILL.md`: least privilege, description required.

## Verdict

**Ready with fixes.** The earlier review found real problems: briefs that said "nothing on record" when
they had actually failed, an activity section that ignored the user's access, and a memory write that
broke when the agent asked for more than one brief. Those are fixed and each has a test. The brief and
the data explorer now read only what the signed-in user may read, and no Apex path writes anything the
user does not own. Nothing found here is a blocker for the one-brief-per-turn agent path. Four things
should be fixed before another team builds on this:
- a caller that asks for many briefs at once can hit a hard platform limit and get no answer at all;
- one hidden field blanks a whole section;
- the final-brief prompt does not tell the model what a failed section means;
- the agent loses the explorer's partial results when the model fails.

It is not proven in real use yet: no non-admin user has run it and no real MCP call has been made.

Two things have **not happened**, and the pattern is not proven until they do:
- no non-admin user has run a full brief holding only the two shipped permission sets;
- no real MCP call has been made.

Every model call in the tests is a stub.

## Earlier findings: status

Status key:
- **fixed**: the problem is gone.
- **open**: the problem remains.
- **changed**: fixed on one path, or reshaped, with a residual noted.

| # | Earlier finding | Status | Decided by |
|---|---|---|---|
| 1 | All-ERROR brief reported as EMPTY | fixed | `AccountBrief.cls:176-179`; `AccountBriefTest.everySectionErrorGivesErrorNotEmpty`, `errorAndEmptySectionsGiveError` |
| 2 | Activity section read in SYSTEM_MODE | fixed | `AccountBriefActivitySection.cls:74-79, 88-92` (USER_MODE, optional Type describe-checked); `AccountBriefActivitySectionTest.taskTheUserCannotReadIsNotInTheBrief`, `standardUserReadsTasksInUserMode` |
| 3 | Memory DML before the next request's callout | changed | DML ordering fixed: `AccountBrief.cls:127-145`, `AccountBriefGetAction.cls:33-39`, `AccountBriefTest.threeRequestsMakeNoModelCallAfterDml`. The cost still grows with each request and has no cap: N1 |
| 4 | Aggregates can exceed the 50k row limit | changed | Explorer fixed with a capped pre-count: `ExploreQuery.cls:76-81, 111-114`, measured in `ExploreQueryTest`. Section aggregates unchanged: N5 |
| 5 | Resolver SOQL in a loop over pasted Ids | fixed | `AccountBriefResolver.cls:143-164`; `AccountBriefResolverTest.manyPastedIdsUseOneQuery` (150 Ids) |
| 6 | Explorer turn cap threw away rows already read | fixed | `DataExplorer.cls:98-103`, `ExploreAction.cls:57-85`; `DataExplorerTest.queryPastCapIsRefusedAndRunningOutOfTurnsKeepsTheResults` |
| 7 | Implicit access mode in sections; causes swallowed | fixed | Every section query has `WITH USER_MODE`; cause kept in `AccountBriefSection.cls:34-43`; `AccountBriefSectionErrorTest` (Minimum Access user). Coarse grain remains: N2 |
| 8 | Date-only values on Datetime fields | fixed | `ExplorePlan.cls:403-432, 635-654`, `ExploreQuery.cls:159-180`; `ExploreQueryTest.aDateOnlyValueOnADatetimeFieldIsReadInTheUsersTimeZone`, `rangeOperatorsAndInCoverTheWholeLocalDayForADateOnlyValue` |
| 9 | Data_Access too broad (every class, Create/Edit) | fixed | Read-only object and field grants, entry-point classes only. One leftover class grant: N10 |
| 10 | `recordFromFlow` invocable writes memory | fixed | No `@InvocableMethod` left in `AccountBriefMemory.cls`; class doc updated (L4-6) |
| 11 | Memory lost-turn race and unbounded rows | fixed | `AccountBriefMemory.cls:60-81` (retry on DUPLICATE_VALUE), `129-142` (per-user cap), `209-217` (FOR UPDATE); `AccountBriefMemoryTest.aRowSavedByAnotherTransactionIsKeptNotOverwritten`, `rowsPerUserAreCappedAndTheOldestGoFirst`, `theCapNeverPurgesAnotherUsersRows` |
| 12 | Permission sets lack descriptions | fixed | Both sets have a description |
| 13 | Model output and errors unbounded | changed | Output cap `AgentLlm.cls:58-60`, every provider error wrapped `AgentLlm.cls:44-53`, `AgentLlmModelsApi.cls:16-33`. There is still no timeout control, and the cap truncates silently: N8 |
| 14 | Prompt static resource queried on every call | fixed | `AgentLlm.cls:37, 77-90`; `AgentLlmTest.aPromptIsLoadedOncePerTransaction` |
| 15 | Panel leaked raw exception text | fixed | `AccountBriefPanelController.cls:72-76` and the fixed-text wrapper; `AccountBriefPanelControllerTest.drillTurnsEveryExceptionIntoTheFixedText`, `unexpectedExceptionsBecomeFixedText` |
| 16 | Invocables missing `callout=true`; null request | fixed | `AccountBriefGetAction.cls:23-27`, `ExploreAction.cls:28-38`; `ExploreActionTest.nullRequestsAreHandled` |
| 17 | Resolver leading wildcard | changed | Kept on purpose, with the reason at `AccountBriefResolver.cls:89-96`. Failure handling was added (`55-63`, `111-130`), and every QueryException now reads as NOT_FOUND: N7 |
| 18 | Money formatting; partial ERROR untested | changed | `money()` centralised (`AccountBriefSection.cls:88-100`); partial ERROR tested with a stub only (`AccountBriefTest.someErrorSectionsStillGiveAnOkBrief`). The prompt has no ERROR rule: N3 |
| T1 | Legacy `System.assert*` | fixed | None left in any `*Test.cls` |
| T2 | No TestDataFactory | open | Deliberately decided against in the BE-12 card; data is built inline |
| T3 | No multi-request invocable test | fixed | `AccountBriefTest.threeRequestsMakeNoModelCallAfterDml` (3 requests, thin data) |
| T4 | No 251+ bulk test | fixed | `AccountBriefTest.bulkBriefOverThreeHundredTasksStaysWithinLimits` (251 contacts, 300 tasks) |
| T5 | No restricted-user runs | fixed | `AccountBriefSectionErrorTest`, `AccountBriefActivitySectionTest` (Minimum Access and Standard User via `runAs`) |
| T6 | Tests depend on org profiles by name | open | Five lookups: `AccountBriefSectionErrorTest.cls:4`, `AccountBriefMemoryTest.cls:11`, `ExploreQueryTest.cls:195`, `ExploreCatalogTest.cls:4`, `AccountBriefActivitySectionTest.cls:109` |
| T7 | Little `Test.startTest/stopTest` isolation | changed | Used in 6 of 19 test classes |
| T8 | No concurrency test; Models API not mockable | changed | Race simulated through the `racingRows` seam (`AccountBriefMemory.cls:114-118`); Models API still testable only for request shape |

## New findings

There are no blockers.

### Should-fix

**N1. A request batch with no cap can hit an uncatchable governor limit.**
- Where: `AccountBrief.cls:127-145`, `AccountBriefGetAction.cls:28-46`, `ExploreAction.cls:29-45`.
- How it fails: both invocables loop over every request in one transaction.
  - One brief runs up to about 25 SOQL queries. That is a static worst case: 24 queries are written in the seven section classes, plus the visibility check, and some are conditional. `bulkBriefOverThreeHundredTasksStaysWithinLimits` asserts only that the count is under the limit, so no exact figure is measured.
  - One brief also makes up to 3 model callouts.
  - The prompt cache saves only the 3 prompt loads after the first brief.
- At roughly the fourth request, the transaction reaches the 100-query limit. That `LimitException` cannot be caught, so the whole invocation fails and no request gets an answer. The memory write at the end makes it worse: 1 or 2 more queries (`findRowsForUpdate`, plus `purgeOverflow` when a row is inserted), and at most 4 if the DUPLICATE_VALUE retry runs.
- The explorer uses up to 5 callouts and up to about 10 queries per question: 4 plan queries, each with at most one count, plus the prompt load and the context-record lookup. Many questions approach the callout count and the 120 s cumulative callout time limit. Whether Models API calls count toward those limits is **unverified**.
- Scenario: a Flow or a bulk caller passes ten accounts to "Get Account Brief" and the user gets a fault with zero briefs. The agent path normally sends one request, which is why this is should-fix and not a blocker.
- Fix: process only as many requests as `Limits` allows, and return ERROR with fixed text for the rest. Alternatively, document and enforce one request per call.

**N2. One unreadable field fails a whole section.**
- Where:
  - `AccountBriefProfileSection.cls:33-40` selects 13 fields: AnnualRevenue, Website, Description and others.
  - `AccountBriefOpenDealsSection.cls:81-87` selects `Contact.Name` on contact roles.
  - `AccountBriefCallsSection.cls:67-74` selects `Description` and `Who.Name`.
- How it fails: `WITH USER_MODE` throws when any one selected field is not readable, and the section becomes ERROR (`AccountBriefSection.cls:34-43`).
- The user sees "Couldn't load Account right now." Those words suggest a passing fault, but this failure is permanent. The cause goes only to `System.debug`, which needs a trace flag to see.
- Scenario: an org hides AnnualRevenue from sales reps. Every rep's brief then has a broken Account section indefinitely, and nobody can tell why without a debug log.
- Fix: describe-check optional fields and drop them, as the Activity section already does for Type (`AccountBriefActivitySection.cls:83-92`) and as `ExploreCatalog.cls:181-193` does for the explorer.

**N3. The synthesis prompt has no rule for a failed section.**
- Where: `AgentPrompt_BriefSynthesis.resource` rule 5 (L9) covers EMPTY inputs only. `AccountBrief.cls:289-298` passes a failed section as `ERROR: Couldn't load Cases right now.`, and `AccountBrief.cls:265-272` sends ERROR inputs into the pre-reduce prompts too, which have no ERROR rule either.
- How it fails: the brief is OK when any section is OK (`AccountBrief.cls:189`), and the agent action returns only the status and the text (`AccountBriefGetAction.cls:39-44`).
- Scenario: the Cases query fails for a user, and the model writes "Service health: no open cases." That is a confident false statement, and nothing marks the brief as partial. This is real-model behaviour, so it is not tested. The stub test checks only the status.
- Fix: add a rule that an ERROR input is stated as "could not be loaded", and test that the rule text exists, as `AgentLlmTest.everyBriefPromptHasBothParts` does for structure.

**N4. The agent loses explorer results when the model fails mid-question.**
- Where: `DataExplorer.cls:104-111`, `ExploreAction.cls:54-55`.
- How it fails:
  - A model failure after one or more queries returns ERROR. The result sets are kept on the Result (`DataExplorerTest.modelFailureKeepsResultSets`), so the panel can show them.
  - `compose` returns only the fixed text when the status is ERROR, so the agent user gets "I couldn't finish that right now" and none of the rows already read (`ExploreActionTest.modelFailureRelaysTheErrorText`).
  - The log line keeps only `getMessage()`, not the exception type. The brief path logs both (`AccountBrief.cls:186`).
- `docs/ARCHITECTURE.md` L94 ("keeps the result sets already read") is true for the panel only.
- Scenario: a three-query question fails on its last model call, and the agent discards the two tables the user's question needed.
- Fix: relay the last table with a short note, the same way the turn cap does.

### Notes

- **N5. Section aggregates on very large accounts.**
  - Where: `AccountBriefOpenDealsSection.cls:38-43` (SUM), `AccountBriefCasesSection.cls:49-55` (MIN), `AccountBriefDealHistorySection.cls:38-44` (AVG).
  - These read every matching row with no pre-count. An account with tens of thousands of cases or opportunities can reach the 50,000-row limit, and that `LimitException` cannot be caught.
  - Rare for one account, but there is no guard like the explorer's.
- **N6. Memory outlives access.**
  - Where: `AccountBriefMemory.cls:165-188` and `AccountBriefPanelController.cls:82-89`.
  - The user's own past briefs are returned without checking that the user can still see the account.
  - `Last_Brief__c` (up to 32,768 characters) is readable in reports through the Read grant, with `enableReports` on the object.
  - Scenario: a rep loses access to an account after a territory change but can still read its last brief text, including deal amounts.
  - The object's sharing is Private, so other reps cannot read the row. Admins can, and so can users above the rep in the role hierarchy if hierarchy access applies.
- **N7. Every QueryException reads as NOT_FOUND.**
  - Where: `AccountBriefResolver.cls:55-63`, `AccountBrief.cls:205-212`.
  - A missing object permission or field-level access gives "couldn't find that account", which sends admins looking for missing data instead of missing access.
- **N8. The output cap cuts mid-sentence without notice.**
  - Where: `AgentLlm.cls:58-60` cuts the text at `maxTokens * 4` characters.
  - The synthesis allowance is 1,500 tokens, which is 6,000 characters. `docs/ARCHITECTURE.md` L65 puts the chat relay limit at about 6K characters, and `ExploreAction.MAX_CHARS` (5,900) stays under it, but the brief has no such clamp. A brief that runs long ends mid-sentence with no marker.
- **N9. Record text reaches the prompt with no fence.**
  - Account Description, Event Description, task subjects and case subjects reach the prompts as plain text.
  - A crafted Description can steer the brief's wording.
  - The harm is limited: every read is in user mode, there is no write path from the model, and the reader is the same user.
- **N10. A class grant with no use is locked in by a test.**
  - `AccountBriefMemory` is granted at `Data_Access.permissionset-meta.xml:11-14`, but no entry point is left on that class.
  - `tests/test_permission_sets.py:59-68` asserts the exact set, so removing the grant means changing that test, which is outside this review's scope.
  - The object and field Read grants are also unused by the engine: it reads the object in SYSTEM_MODE keyed to the user. They do serve the report access noted in N6.
- **N11. Two queries run in implicit mode.**
  - Where: StaticResource (`AgentLlm.cls:83`) and BotDefinition (`AccountBriefPanelController.cls:107-108`). They are the only queries without an explicit mode.
  - Whether a non-admin can read StaticResource from Apex here has not been checked. If they cannot, every brief and every explorer question fails as "Prompt not found".
- **N12. The model name is a constant.**
  - `AgentLlmModelsApi.cls:10` hard-codes the model name, so an org without that model must change code.

## Security and access summary

- Sharing:
  - Every class is `with sharing`.
  - The record reads are the section queries, explorer queries, resolver and visibility check, plus the drill. All of them use `WITH USER_MODE` or `AccessLevel.USER_MODE`, so object, field and sharing access apply.
  - The only SYSTEM_MODE code is in `AccountBriefMemory`. It is justified in the class doc and always filtered to `UserInfo.getUserId()`.
- Writes: the only DML is on memory rows, in SYSTEM_MODE.
  - It creates or updates the running user's row.
  - `purgeOverflow` (`AccountBriefMemory.cls:129-142`) deletes the running user's oldest rows beyond the cap, and only that user's rows (`theCapNeverPurgesAnotherUsersRows`).
  - The permission sets grant no Delete, View All or Modify All.
- Explorer:
  - The SOQL text is built only from catalog paths, fixed operators and generated aliases. Every value is a bind variable (`ExploreQuery.cls:116-208`).
  - The catalog is describe-checked per user (`ExploreCatalog.cls:152-224`).
- What the sets grant:
  - Agent_Access grants the agent.
  - Data_Access grants:
    - the app;
    - five classes;
    - Read on `Account_Brief_Session__c` and its fields.
  - Neither set grants standard-object access, the Models API or Einstein/Agentforce user permissions. Nothing in this layer lists what else a non-admin needs. Name it in ARCHITECTURE, or in a setup note, before adoption.

## Proven by tests, and what is not

**Proven by tests in the repo.** These tests use the stub model. Per the BE-10 and BE-12 cards, they ran in the org through check-only deploys with named tests; they were not re-run here.
- Section, brief and explorer behaviour, including ERROR versus EMPTY, the turn and query caps, and row-cap refusal.
- Row accounting for aggregates, measured.
- Date-only handling in the user's time zone.
- Pasted-Id resolution with one query.
- Fixed panel error text.
- Memory: the per-user cap, the purge that spares other users' rows, and the simulated race.
- Prompt caching.
- A 251-contact, 300-task brief within limits.
- Three requests with no callout after DML.
- Minimum Access and Standard User runs (`runAs`) for sections and the catalog.

**Not proven.**
- **The non-admin run has not happened.** No user holding only the two permission sets has run a full brief or explorer question (planned as FE-5). The Playwright suite in `e2e/` runs as the developer's own admin user.
- **A real MCP call has not happened.**
- Real-model behaviour: whether the model follows the prompts on ERROR inputs, length and keeping Ids out (N3, N8).
- Callout time against the 120 s limit, and the agent action's own timeout.
- More than three requests in one invocation (N1).
- Large data volumes on the section aggregates (N5).
- True concurrent memory writes (the race is simulated through a seam).
- Code Analyzer was not run for this review.

## Adoption by a new team

What helps:
- Adding a source means writing one class that implements the interface and adding one registry line, and `docs/ARCHITECTURE.md` lists the steps.
- A catalog object is one entry in `CURATED`.
- The model provider is one seam (`AgentLlm.Provider`), with a stub for tests.
- Statuses are uniform (OK / EMPTY / ERROR / NOT_FOUND), and the user-facing text is fixed.

What will slow a new team down:
- Failures are recorded only in debug logs, and there is no persistent error record (N2, N4, N7).
- The tests need the 'Standard User' and 'Minimum Access - Salesforce' profiles (T6).
- The Models API cannot be mocked.
- The org needs the Models API, Einstein and the named model enabled (N12).
- A new source is not narrated until someone also edits `AgentPrompt_BriefSynthesis` (its section list is fixed text).
- The prompts have no rule for ERROR inputs (N3).
