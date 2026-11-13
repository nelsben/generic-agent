# FR2 follow-ups: does the explorer answer the next question from the summary's records? (BE-30)

- Covers card BE-30: follow-up questions after a summary, plus two review fixes, N4 in
  [apex-review-2.md](../reviews/apex-review-2.md#should-fix) and N1 in
  [lwc-review-2.md](../reviews/lwc-review-2.md#new-findings) (the Apex part).
- The live check is `scripts/follow-up-set.apex`. It ran on agent-probe on 2026-11-13, after BE-30 was deployed
  there (validate with RunLocalTests, 277 tests, 0 failures, then quick deploy). It ran twice: run 1 with the
  first wording of prompt rule 12, run 2 after that rule was tightened (validated and quick-deployed the same way).
- Short answer: run 2 passed 18 of 20 follow-ups (run 1: 14 of 20). All three named follow-ups passed on both
  accounts in run 2. The two misses are a question about who has *not* been called, which ended on the wrong
  table once, and the unclear "which of those matter most?", which one account answered instead of asking.

## How a follow-up gets the summary's records

- No new action and no new input. The explorer already gets the open record and the conversation history. When
  the last turn in that history is the summary, it now also gets a short list of the records behind it.
- How it knows the last turn was the summary:
  - The open record is an account.
  - The last history item's answer matches the summary this user last got for that account
    (`CustomerSummaryMemory.lastBrief`). Spaces are collapsed and a clipped tail ("..." or "…") is allowed,
    so the agent's shortened history still matches. An answer under 20 characters never matches.
  - If any of this fails, nothing is added and the explorer works as before.
- Where the records come from: the explorer rebuilds the summary's sections (open deals, cases, contacts,
  activity, calls, deal history) for that account, in the user's own access. Each section line that names a
  record already ends with that record's Id, so the list is read from those lines. It is the same set of
  records the summary was built from, not a new search.
- What the model sees, under "Earlier in this conversation":
  - a header that says the ids are for plans only, never for the answer text;
  - `Account: the open record, id=...`;
  - per section, its title, then one line per record: the line's text clipped to 120 characters, then `id=`.
- Caps: 10 records per section and 3,000 characters in all. A section cut short ends with
  "(N more not listed)", and a section that did not load adds nothing. People never see this text: it is only
  in the prompt, and prompt rule 5 keeps ids out of the answer.
- Prompt rule 12 (new): a pronoun or "those", "them", "there" or "that deal" means the records of the last turn.
  After a summary, those are the listed records: filter on their ids, and use the account id for "there". When
  it is unclear which records the question means, answer with a question, run no query, and offer the likely
  choices as follow-ups. Rules 1 to 11 and the template variables are unchanged (`tests/test_explore_prompt.py`).

### Which surfaces get it

| Surface | Gets the context? | Why |
| --- | --- | --- |
| Panel | Yes | It sends the summary turn in its history and the account as the open record. |
| Agent (Explore action) | Yes, when its History input carries the summary turn | Same `DataExplorer.explore` call, no new action input. Wiring the agent's History to include the summary turn is card BE-28's (parked). |
| MCP | No | The ask tool needs its approval row, which is still pending. |

### Limits

- The open record must be the summarized account. On a page that is not an account record, the panel's open
  record is that page's record, so no context is added and a follow-up there works as before.
- Only the turn right after the summary gets the context. After one explore answer, "those" means that answer's
  records, and rule 9 already covers that.
- Rebuilding the sections costs about the same queries as the summary's own gather (BE-29 measured 28 to 32
  per summary run, counting that script's own), on top of the explorer's up to 4 and their total counts. That
  stays under the 100-query limit for one request, and it adds no model call. Two follow-ups per execution in
  the live script ran within the limits.

## The two review fixes

- **N4, the agent loses rows on a model failure.** `ExploreAction.compose` now relays the last table read
  after the fixed failure line, the same way the turn cap does. With no table read, the answer is the failure
  line alone, as before. The explorer's error log now names the exception type too.
- **N1, drill child rows show API names and raw Ids (the Apex part).** Since BE-18 the drill's headers were
  already field labels. What remained, and is now fixed:
  - Child rows carried API path keys and raw lookup Ids (for example a task's related-to and owner Ids). Rows
    now hold only the shown columns plus the record Id, which the panel needs to open the record.
  - Column 0, which the panel uses as each row's button, was not always a name. It is now the object's name
    field. An object without one (a contact role) leads with the other side's name: the contact when drilled
    from a deal, the deal when drilled from a contact.
  - Not fixed here, since it is in the panel (LWC, out of this card's scope): the table title and the related
    chips still show object API names, and the record card still shows lookup Ids.

## Tests

`DataExplorerTest` (scripted model, no callouts):

- `whichOfThoseCloseThisQuarterUsesTheSummarysDeals`, `whoThereHaveWeNotCalledUsesTheSummarysContacts` and
  `anyOpenCasesOnTheBiggestDealUsesTheSummarysDealAndAccount`: the three named follow-ups. Each checks that the
  prompt carries the summary's records and ids, and that the plans filtered on them return those records only.
- `anUnclearPronounAfterASummaryIsAskedBackWithNoQuery`: the ask path, one model call, no query.
- `noSummaryContextWhenTheLastTurnIsNotTheSummary`: after an explore answer, on a non-account record, with no
  record, for an account with no remembered summary; and a clipped summary answer still matches.
- `theSummaryContextIsCappedPerSectionAndInAll`: the per-section cap, the total cap, the "more not listed" note
  and the line clip.
- `agentPathKeepsTheTablesReadBeforeAModelFailure` (N4), `drillChildRowsCarryLabelsAndNamesAndKeepTheirIds` and
  `drillChildRowsWithoutANameFieldLeadWithTheOtherSidesName` (N1).

## Live follow-up set

- Seed accounts, from `data/sample/accounts.json`: sample 1 is Edge Communications (5 open deals, 5 contacts,
  5 open cases, 11 tasks), sample 2 is Brindlewick Hydroponics (3 open deals, 1 contact, 1 open case, no tasks).
- Per account, one execution runs the summary, then five executions ask two follow-ups each. Every follow-up is
  asked directly after the summary, with the summary turn as its history and the account as the open record,
  which is what the panel sends. The summary runs in its own execution because it writes its memory row after
  its model calls, and a model call after an uncommitted write fails.
- Pass rules:
  - The status is not ERROR, and the answer text holds no record Id.
  - Question 10 is the ask case: it passes only when the explorer runs no query and its answer asks back.
  - Any other question passes when its last query is on an expected object and every row it returns is one of
    the account's own records of that kind. A result with no record rows (a total, or no match) must have a
    plan that filters on the account or on records the summary lists.
- The script prints only pass or fail, a reason code, the objects queried, and counts. It never prints a name,
  an Id or answer text.
- Model calls: a Models API call does not count in `Limits.getCallouts()` (a summary measured 0), and the
  script cannot see the explorer's turns. Each turn is one model call that returns one query or the answer, so
  the calls are the queries plus 1. That is exact unless a reply was refused as INVALID, which adds a call the
  script cannot see.

| # | Question | Expected | S1 run 1 | S1 run 2 | S2 run 1 | S2 run 2 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Which of those close this quarter? | Opportunity | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c |
| 2 | Who there have we not called? | Contact | **fail**, Task > Event, 3c | **fail**, Contact > Event > Task, 4c | pass, Task > Contact, 3c | pass, Task > Contact, 3c |
| 3 | Any open cases on the biggest deal? | Case | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c |
| 4 | Which of those deals has the largest amount? | Opportunity | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c |
| 5 | Who are the contacts on those deals? | Contact role or Contact | pass, 1q, 2c | pass, 1q, 2c | fail (script), 1q, 2c | pass, 1q, 2c |
| 6 | How many open cases do they have? | Case | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c | pass, 1q, 2c |
| 7 | Which of those deals are past their close date? | Opportunity | pass, 1q, 2c | pass, 2q, 3c | pass, 1q, 2c | pass, 1q, 2c |
| 8 | What is the total amount of those deals? | Opportunity | **fail**, no query, 1c | pass, 1q, 2c | **fail**, no query, 1c | pass, 1q, 2c |
| 9 | When did we last log an activity there? | Task or Event | pass, 1q, 2c | pass, 1q, 2c | pass, 2q, 3c | pass, 2q, 3c |
| 10 | Which of those matter most? | ask, no query | **fail**, did not ask, 1c | pass, asked, 1c | **fail**, did not ask, 1c | **fail**, did not ask, 1c |

(q = queries run, c = model calls. Run 1 passed 14 of 20, run 2 passed 18 of 20.)

- Run 2 used 43 model calls for the 20 follow-ups (1 to 4 each), plus up to 3 for each summary. Across both
  runs and the diagnostic re-asks below, 46 follow-ups used 90 model calls.
- No follow-up put a record Id in its answer, and none returned a record outside the account's own.

### Every failure, explained

- **Run 1, question 8, both accounts: total of those deals, answered with no query.** A diagnostic re-ask
  showed an answer with a number in it and no question. The context lines carry each deal's amount, so the
  model added them up from the context text instead of querying. That breaks rule 3 in spirit (answer only from
  rows the system returned), and the table shows nothing to check the total against.
  - Fix, in this card: rule 12 now says the listed lines only say which records, are not query results, and
    must never be the source of a value, count, total, ranking or list; the last query must return what answers
    the question. Run 2 passed question 8 on both accounts with one Opportunity query.
- **Run 1, question 10, both accounts: "which of those matter most?" answered instead of asked.** The re-ask
  showed an answer with a number and no question: the model read "those" as the deals and ranked them from the
  context text. Rule 12 now gives an example of unclear ("those" names no kind of record, and the summary lists
  more than one kind) and forbids rankings from the context text.
  - Run 2: sample 1 asked back. Sample 2 still answered with a number. Its summary is small (3 deals, 1 contact,
    1 case), and the model treats the deals as the obvious meaning. This is a judgement call rather than a
    wrong record: no query ran and no record outside the summary was named. It is left open. A stricter check
    in code, such as refusing an answer with no query right after a summary, would also block a fair
    clarifying answer, so it is not built here.
- **Sample 1, question 2, both runs: "who there have we not called?" ended on the activity table.** The plan
  language has no NOT IN, so "contacts with no call" takes two steps: read the calls, then query Contact with
  `Id IN` the contacts left over. On sample 2 the model did that (Task, then Contact) in both runs. On sample 1
  (5 contacts, 11 tasks) it read the contacts and the activities and stopped there, so the shown table is
  activities, not the uncalled contacts. Rule 12's "make the last query return the records that answer the
  question" did not fix it on sample 1. A NOT IN operator in the plan (an ExplorePlan change) would make it one
  query; that is a follow-up card, not this one.
- **Run 1, sample 2, question 5: a script bug, not an explorer miss.** The contact-role query was right and
  matched no rows (the deals have no contact roles), but the script checked a no-row result's plan only against
  contacts and contact roles, not against the deals the plan filtered on. The script now accepts any record the
  summary lists. The diagnostic re-ask and run 2 passed.

### Diagnostic re-asks (run 1's failures, before the rule change)

- Asked again with the first rule 12 wording, so the reason for each failure could be seen (`asked=` and
  `number=` on each line): sample 1 questions 2, 8 and 10, and sample 2 questions 5, 8 and 10.
- Results: question 8 failed again on both accounts (answer with a number, no question). Question 10 passed on
  sample 1 and failed on sample 2. Sample 1 question 2 failed again (Task only). Sample 2 question 5 passed under
  the fixed script check.

## What the runs wrote

- Customer Summary session rows (`Customer_Summary_Session__c`): 5 for this user before the runs and 5 after,
  so no new row. Each summary updated the existing row for its account: sample 1's row 3 times (a first check
  of step 0, then once per run) and sample 2's row twice. These are the product's own memory rows, the same rows
  a rep's summary writes. The follow-ups wrote nothing: the count stayed at 5 after every step.
- Outcome rows: 0. The org has no object with "Outcome" in its name (checked on 2026-11-13), so nothing records
  outcomes yet.
