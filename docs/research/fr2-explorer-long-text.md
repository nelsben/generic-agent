# FR2+ explorer long-text search (BE-44)

- Date: 2026-11-16. Org `agent-probe`. Validated with RunLocalTests (562 tests, 0 failures), then quick deployed. No record, user or setting was written by the proof; no agent was published or activated.
- Code: [ExploreQuery.cls](../../force-app/main/default/classes/ExploreQuery.cls). Tests: [ExploreQueryTest.cls](../../force-app/main/default/classes/ExploreQueryTest.cls).
- Proof: [sosl-proof.apex](../../spikes/explorer-scale/sosl-proof.apex), read-only anonymous Apex, run once. Output: [sosl-proof.txt](../../spikes/explorer-scale/results/sosl-proof.txt), counts only.
- End to end: five long-text questions on the deployed explorer, BE-31's [harness](../../spikes/explorer-scale/harness.apex) and engine `real`. Results: [be44.jsonl](../../spikes/explorer-scale/results/be44.jsonl).
- Earlier: [fr2-explorer-scale.md](fr2-explorer-scale.md) (BE-31's SOSL attempt) and [fr2-explorer-grammar.md](fr2-explorer-grammar.md) (BE-43's post-filter). Status words: verified (measured here), unverified (inference).

## Plain answer

- **SOSL in user mode finds seed-data long text in agent-probe.** Every word that a hand query found in a Description was also found by search, in user mode and in system mode (verified).
- **So the explorer now uses SOSL, but only past the scan cap.** Up to 2,000 candidate rows, BE-43's exact Apex match still runs. Past 2,000, a user-mode search narrows the candidates, and the same Apex match then confirms each one.
- **Search alone is not a correct answer.** It matches words in any field, and it stems them. For example, "pricing" also found an Event whose text says "price", and "renewal" found an Event whose Subject holds the word but whose Description does not. The Apex match removes those (verified).
- **All five long-text questions pass end to end**, and each matches its hand query (verified, one run).
- **Past either cap, the explorer refuses.** It says that it stopped at its cap, how many rows it scanned, and that it has no full count.

## The proof

`FIND '<word>' IN ALL FIELDS RETURNING <object>(Id, Description) LIMIT 2000`, once in user mode and once in system mode. `hand` is the number of rows whose Description holds the word: a SOQL query in user mode, matched in Apex, ignoring case. `holding` is the number of search results that hold it.

| object | word | hand | user mode: rows / holding | system mode: rows / holding |
|---|---|---|---|---|
| Account | renewal | 1 | 1 / 1 | 1 / 1 |
| Account | telecom | 1 | 1 / 1 | 1 / 1 |
| Account | support | 1 | 1 / 1 | 1 / 1 |
| Event | pricing | 1 | 2 / 1 | 2 / 1 |
| Event | router | 1 | 1 / 1 | 1 / 1 |
| Event | renewal | 0 | 1 / 0 | 1 / 0 |

- **Index wait.** The newest row that holds each word was last modified 95 hours before the run, and all of them were indexed (verified). The proof writes no record, so it cannot time how long a new record takes to reach the index. Salesforce indexes changes asynchronously, so a record saved moments ago can be missing from search (unverified here).
- **Why BE-31 found nothing.** BE-31 searched for `router`, `refund` and `calibration` in Case, Task and Opportunity. In this seed data, `router` is in an Event, not in those objects. A young index is the other possible cause (unverified).
- **Words, not substrings.** `renew` found 0 Accounts, and `renew*` found the one holding "renewal" (verified). `price* lock*` found the one Event holding both words, and `price* zebra*` found none, so words separated by spaces are ANDed (verified, in a one-off check). A two-letter prefix (`ro*`) is accepted.
- **System mode.** Inside a method declared in the anonymous block, system mode ran. At the top level of the block, the same call threw `SecurityException: Cannot use SYSTEM_MODE access level in anonymous execution of Apex` (verified; why it differs is unverified). It does not matter here: the explorer runs every SOSL and SOQL query in user mode.
- **Limits.** The proof used 20 of 20 SOSL queries, 13 SOQL queries and 0 DML statements.

## The choice

The card's rule is: if user-mode SOSL finds the record, use SOSL. It did. But search alone gives a different answer from `CONTAINS`:

- it finds a word in any field;
- it stems words;
- it misses a fragment inside a word;
- it can miss a record that is not indexed yet.

So `ExploreQuery` keeps one long-text path, and search only narrows its candidates:

1. **The scan.** The query runs with the plan's other filters and `LIMIT 2001`. Up to 2,000 rows, the Apex match keeps those whose text holds the value, ignoring case. The result is the same as BE-43, and it involves no search.
2. **Past 2,000 rows, a search narrows the candidates.**
   - The search text is the value's words of two or more letters or digits, in lower case, each one a word start (`renewal*`), separated by spaces.
   - `AND`, `OR` and `NOT` are dropped, because SOSL reads them as operators. Nothing else in the value reaches the search text, so a quote or a brace cannot change the query. Each value stays a bind in SOQL.
   - The search runs as `FIND '<words>' IN ALL FIELDS RETURNING <object>(Id) LIMIT 2000` in user mode.
   - The same query then runs again with `AND Id IN :bN` (also in user mode), and the same Apex match keeps only the rows whose long text holds the value.
   - The trail shows `(narrowed by search)`.
3. **Refusals.** Each of these throws `RowCapException`, which reaches the model as `INVALID: ...`:
   - **Search can't narrow the value**, because no word of two or more characters is left, the field is on a parent (search covers only the object's own fields), or the object can't be searched. The message is "CONTAINS on long text stopped at its cap after scanning 2000 rows, so there is no full count. More rows match the other filters, and a search can't narrow this value. Add filters to narrow it."
   - **The search returns 2,000 records.** The message is "...stopped at its cap after scanning 2000 rows, so there is no full count. The search found 2000 or more records with those words, the most it reads. Add filters to narrow it."

Why scan first: under 2,000 rows the scan is exact for any substring, and it has no index wait. Search only takes over where BE-43 refused.

## Row limits

| limit | value | where it comes from | past it |
|---|---|---|---|
| scan cap (`TEXT_SCAN`) | 2,000 candidate rows that match the other filters | ExploreQuery, BE-43 | a search narrows them |
| search cap (`SEARCH_CAP`) | 2,000 records holding the words, before the other filters | SOSL's own maximum per query | refused, with no count |
| query rows on the search path | at most 2,001 for the scan, plus 2,000 for the narrowed query | ExploreQuery | — |
| SOSL queries | 1 per long-text query, at most 4 per question (`MAX_QUERIES`); the platform allows 20 | DataExplorer, Apex limits | — |
| row cap for aggregates (`ROW_CAP`) | 10,000 | ExploreQuery; long text can't be used with aggregates | refused |

The search cap counts records that hold the words anywhere, before the plan's other filters. So a common word can fill it even when the other filters would leave only a few rows. Then the answer is a refusal, and never a partial count.

## End to end: five questions and their hand queries

Each question went once through the deployed `DataExplorer.explore` (model, plan and query). The harness compares the record set in the last result with the hand query. The hand query reads every row of the object in user mode and keeps those whose Description holds the text, ignoring case.

| question | hand query | hand rows | explorer rows | verdict |
|---|---|---|---|---|
| q25 Which accounts mention renewal in their description? | `SELECT Id, Description FROM Account`, Description holds "renewal" | 1 | 1 | PASS |
| q26 Which events have a description that mentions pricing? | `SELECT Id, Description FROM Event`, Description holds "pricing" | 1 | 1 | PASS |
| q44a Which accounts mention a support plan in their description? | `SELECT Id, Description FROM Account`, Description holds "support plan" | 1 | 1 | PASS |
| q44b Which events mention the router in their description? | `SELECT Id, Description FROM Event`, Description holds "router" | 1 | 1 | PASS |
| q44c Which events have a description that mentions renewal? | `SELECT Id, Description FROM Event`, Description holds "renewal" | 0 | 0 | PASS |

- q25 and q26 are BE-31's two long-text questions. q44a, q44b and q44c are new.
- q44c is the trap: search finds that Event through its Subject, but its Description does not hold the word.
- The seed data has 14 Accounts and 6 Events, so all five ran on the scan path. The search path ran in the org only through part 2 of the proof. There, on the same five values, the search hits, re-read and matched, gave exactly the hand counts: 1, 1, 1, 1 and 0. In "Event pricing", search returned 2 records and the match kept 1 (verified).
- Apex tests cover the search path with fixed search results.

## Tests

New `ExploreQueryTest` cases:

- **past the scan cap, a search runs once and the matching row comes back.** Of three candidates, the search returns two. One of those holds the word, and the third, which the search did not return, stands for a record that is not indexed yet. The SOQL text is asserted;
- **the search cap's message**: "stopped at its cap after scanning 2 rows, so there is no full count.";
- **the scan cap's message**, when a search can't narrow the value (one letter), with no search run;
- **the search text** keeps only words and word starts, and a hostile value adds nothing but its words;
- **ORDER BY on long text** is refused before any query;
- **GROUP BY on long text** is refused before any query.

The existing scan test now also asserts that no search runs under the cap. `ExplorePlanRejectionTest` case 33 (`SELECT Name, Id, Description FROM Account LIMIT 2001`) is unchanged and still passes.

## Limits and open items

- **Past 2,000 rows, CONTAINS matches only words and word starts.** "newal" finds nothing there, though the scan would find it in "renewal". Records saved too recently to be indexed are missing too. The answer does not say this; only the trail's `(narrowed by search)` shows that search was used.
- **The search path is not exercised end to end in agent-probe**, because the seed data never passes 2,000 rows. Its pieces are verified: the search text, the user-mode search with hits re-read and matched, and the Apex tests.
- **One run** of the five questions.
- **Heap**: the scan still loads up to 2,001 rows with their long text. The widest heap in the five runs was about 250 KB of 6 MB.

## Undo

- Org: deploy `ExploreQuery` and `ExploreQueryTest` from main with a validate (RunLocalTests) and a quick deploy. Past 2,000 rows, the explorer then refuses again, as in BE-43.
- Repo: revert the BE-44 commit.
