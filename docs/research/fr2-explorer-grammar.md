# FR2+ explorer plan grammar v2 (BE-43)

- Date: 2026-11-15. Org `agent-probe`. Validated with RunLocalTests (556 tests, 0 failures), then quick deployed. No record, user or setting was created; no agent was published or activated.
- Code: [ExplorePlan.cls](../../force-app/main/default/classes/ExplorePlan.cls), [ExploreQuery.cls](../../force-app/main/default/classes/ExploreQuery.cls), [DataExplorer.cls](../../force-app/main/default/classes/DataExplorer.cls) and the new prompt file [AgentPrompt_Explore_v2](../../force-app/main/default/staticresources/AgentPrompt_Explore_v2.resource). Tests: [ExplorePlanTest.cls](../../force-app/main/default/classes/ExplorePlanTest.cls), [ExploreQueryTest.cls](../../force-app/main/default/classes/ExploreQueryTest.cls), [ExplorePlanRejectionTest.cls](../../force-app/main/default/classes/ExplorePlanRejectionTest.cls).
- Measurement: BE-31's 30 [questions](../../spikes/explorer-scale/questions.json) and harness, run once on the deployed explorer, the same way as BE-42. Results: [be43.jsonl](../../spikes/explorer-scale/results/be43.jsonl), one JSON line per question in BE-31's record format (counts, statuses and limits only). Earlier runs: [fr2-explorer-baseline.md](fr2-explorer-baseline.md) (BE-41) and [fr2-explorer-catalog.md](fr2-explorer-catalog.md) (BE-42). Status words: verified (measured here), unverified (inference).

## Plain answer

- **The deployed explorer passed 27 of 30 in one run.** BE-41's three real runs scored 20, 20 and 20, and BE-42's one run scored 22 (verified).
  - The gain of 7 over BE-41 is larger than the replay's spread of about 5. It is still one run: three runs would show whether it holds.
- **The three grammar targets now pass** (verified):
  - q11, child rows;
  - q15, a child count;
  - q17, an OR group.

  Each failed in all three BE-41 runs. q15 and q17 also failed in BE-42's run.
- **Long text and the anti-join now pass.** q24, q25 and q26 had failed in every earlier run (verified).
- **Cost went down:**
  - model calls: 69 over 30 questions, against BE-42's 84, with a median of 2 (verified, exact);
  - queries per question: median 1, worst 3;
  - input tokens: median about 7,175 (an estimate, as in BE-42);
  - CPU: median 642 ms and worst 1,034, against BE-42's 725 and 1,385;
  - heap: about the same, median 241 KB and worst 254 KB, against 239 and 262.
- **Still failing:** q18 (a wrong count), q19 (an OR with a date range) and q27 (a chain over a top 5). The cause of q18 was found, and it lies in the catalog. See [q18](#q18).

## Pass counts by category

| category | questions | BE-41 real (3 runs) | BE-42 (1 run) | BE-43 (1 run) |
|---|---|---|---|---|
| single object | 5 | 5, 5, 5 | 5 | 5 |
| parent, one lookup | 3 | 3, 3, 3 | 3 | 3 |
| parent, two lookups | 2 | 1, 1, 2 | 2 | 2 |
| child rows | 5 | 3, 3, 3 | 4 | 5 |
| OR | 5 | 3, 3, 2 | 2 | 3 |
| semi- and anti-join | 4 | 3, 3, 3 | 3 | 4 |
| long text | 2 | 0, 0, 0 | 0 | 2 |
| chained steps | 2 | 1, 1, 1 | 1 | 1 |
| any object | 1 | 0, 0, 0 | 1 | 1 |
| deny | 1 | 1, 1, 1 | 1 | 1 |
| **total** | **30** | **20, 20, 20** | **22** | **27** |

## Next to BE-41 and BE-42

| | BE-41 real (3 runs) | BE-42 (1 run) | BE-43 (1 run) |
|---|---|---|---|
| pass count | 20, 20, 20 | 22 | 27 |
| model calls, median per question | not visible | 2.5 | 2 |
| model calls, total | not visible | 84 over 30 | 69 over 30 |
| queries, total | not recorded here | 49 | 34 |
| input tokens, median per question (estimate) | not visible | about 7,305 | about 7,175 |
| input tokens, worst question (estimate) | not visible | about 19,700 | about 14,900 |
| CPU ms, median / worst | 262 / 373 | 725 / 1,385 | 642 / 1,034 |
| heap KB, median / worst | 38 / 63 | 239 / 262 | 241 / 254 |

Input tokens are calculated as for BE-42: the prompt file once per model call, plus every variable sent, divided by 4 characters. The prompt file is larger now (`AgentPrompt_Explore_v2`), so each call carries more prompt. The total still went down because there were fewer calls.

Changed against BE-42:
- Six failures became passes: q15, q17, q20, q24, q25 and q26.
- One pass became a failure: q19. It passed in BE-41 run 1 and BE-42, and failed in BE-41 runs 2 and 3. It moves between runs, so one result does not show a regression (unverified).

Per question: BE-41 real runs 1 to 3, BE-42, then BE-43 with its own counts.

| q | group | BE-41 real | BE-42 | BE-43 | calls | input tokens, estimate | queries | CPU ms | heap KB |
|---|---|---|---|---|---|---|---|---|---|
| q01 | single | PPP | P | P | 2 | 6,361 | 1 | 550 | 233 |
| q02 | single | PPP | P | P | 2 | 6,205 | 1 | 515 | 232 |
| q03 | single | PPP | P | P | 2 | 6,546 | 1 | 632 | 235 |
| q04 | single | PPP | P | P | 2 | 6,570 | 1 | 575 | 237 |
| q05 | single | PPP | P | P | 2 | 6,537 | 1 | 557 | 237 |
| q06 | parent | PPP | P | P | 3 | 11,174 | 1 | 831 | 245 |
| q07 | parent | PPP | P | P | 2 | 7,276 | 1 | 693 | 244 |
| q08 | parent | PPP | P | P | 3 | 11,126 | 1 | 860 | 244 |
| q09 | parent2 | FFP | P | P | 2 | 7,079 | 1 | 841 | 251 |
| q10 | parent2 | PPP | P | P | 3 | 10,592 | 1 | 1,034 | 251 |
| q11 | child | FFF | P | P | 2 | 7,335 | 1 | 655 | 244 |
| q12 | child | PPP | P | P | 2 | 7,500 | 1 | 534 | 253 |
| q13 | child | PPP | P | P | 2 | 6,925 | 1 | 553 | 238 |
| q14 | child | PPP | P | P | 2 | 6,996 | 1 | 623 | 241 |
| q15 | child | FFF | F | P | 2 | 7,368 | 1 | 675 | 244 |
| q16 | or | FPP | P | P | 2 | 6,414 | 1 | 588 | 234 |
| q17 | or | FFF | F | P | 2 | 6,793 | 1 | 544 | 241 |
| q18 | or | PPP | F | F | 2 | 7,170 | 1 | 754 | 241 |
| q19 | or | PFF | P | F | 4 | 14,083 | 3 | 848 | 238 |
| q20 | or | PPF | F | P | 2 | 6,843 | 1 | 594 | 241 |
| q21 | semi | PPP | P | P | 2 | 7,020 | 1 | 572 | 241 |
| q22 | semi | PPP | P | P | 2 | 7,519 | 1 | 648 | 245 |
| q23 | semi | PPP | P | P | 2 | 7,322 | 1 | 635 | 246 |
| q24 | semi | FFF | F | P | 4 | 14,884 | 3 | 927 | 246 |
| q25 | longtext | FFF | F | P | 2 | 7,179 | 1 | 752 | 244 |
| q26 | longtext | FFF | F | P | 2 | 6,588 | 1 | 492 | 237 |
| q27 | chain | FFF | F | F | 3 | 10,130 | 2 | 730 | 237 |
| q28 | chain | PPP | P | P | 3 | 10,595 | 1 | 705 | 241 |
| q29 | anyobject | FFF | P | P | 3 | 9,780 | 1 | 669 | 238 |
| q30 | deny | PPP | P | P | 1 | 3,135 | 0 | 475 | 230 |

## q18

"How many accounts are in the Energy or Technology industries?" The reference count is 4: 3 Energy and 1 Technology.

- **The plan and the query are right when the model keeps both values.** A diagnostic re-ask got `Industry = :b0 OR Industry = :b1` and a count of 4 (verified).
- **The model is told that Technology does not exist.** In that same re-ask the answer said "Technology is not available as an industry option" (verified).
- **Cause: the catalog cuts the picklist values before it ranks them.** Account's Industry has 32 active values. `ExploreCatalog` keeps the first 12 in describe order, Agriculture to Engineering, so Technology never reaches the model. BE-42's rule puts the values a question names first, but it ranks within those 12 (verified by describe).
- When the model drops the value, it counts Energy only and gets 3, which is the wrong number the harness records. This matches BE-42's q18 result too (unverified for BE-42's run, since that run was not traced).
- **Fix:** match the question's words against all of a picklist's values before cutting to 12. That change is in `ExploreCatalog`, which this task may not touch, so it was not made.

## What the grammar does now

Every name is checked against `ExploreCatalog` for the running user. Every value is bound (`:b0`, `:b1` and so on). No model text is joined into SOQL.

- **`where`**: a tree of conditions with `and`, `or` and `not`, at most 4 groups deep and 20 conditions. The older flat `filters` list still works and is ANDed in.
- **Two-level parent paths**, such as `Opportunity.Account.Owner.Name`. The first lookup must point to one object, and the rest must be a path that object's own catalog entry allows.
- **Ops**: `=`, `!=`, `<`, `<=`, `>`, `>=`, `LIKE`, `IN`, `NOT IN` and `CONTAINS`.
  - `CONTAINS` on a filterable text field becomes `LIKE '%value%'`, with the value's own `%`, `_` and `\` escaped.
  - On long text, it is matched in Apex after the query. That is allowed only at the top level of `where`, and never with aggregates. It reads at most 2,000 rows; past that it is refused and asks for more filters.
- **`sub`**: a semi-join (`IN`) or an anti-join (`NOT IN`) as one sub-select. These are refused before any query runs:
  - more than 2;
  - a `sub` inside `or` or `not`, or nested in another `sub` or a child list;
  - Task or Event, or the same object as the outer query;
  - a right side that is not a lookup, or that cannot point to the left side's object.
- **`children`**: at most 2 child lists, of at most 10 rows each, 5 by default. Each child list becomes a sub-select in the field list. Its cell in the result is the row count.
- **`having`**: up to 5 conditions on the plan's own aggregates. It needs `groupBy`.
- **Step values**: `{"step": n, "field": "Id"}` with `IN` or `NOT IN` filters on the record Ids an earlier query of the same question returned.
  - It is refused when that query showed only some of its rows and was not sorted. A sorted top-N is a deliberate set of Ids.
  - The Ids are written into the plan, so the plan JSON replays without the earlier steps.
- **Long text** can't be sorted or grouped, and can be filtered only with `CONTAINS`.
- **Caps are unchanged**: at most 5 model calls (`MAX_TURNS`) and 4 queries (`MAX_QUERIES`) per question. Chained steps count against these caps.

## Tests

- **`ExplorePlanRejectionTest`** holds all 44 shapes of [rejections.apex](../../spikes/explorer-scale/rejections.apex), each with the outcome in [rejections.txt](../../spikes/explorer-scale/results/rejections.txt): 30 refused with their reason, 14 that run, with the SOQL they build. Four differ from the prototype in wording or data, not in outcome:
  - case 2 names a retired object without the product's old name;
  - case 30 is worded `Amount takes a number; "lots" is not one.`;
  - case 32 filters on `Account.Owner.Title`, because BE-42's deny list now hides `User.IsActive` (that field is refused, which is also asserted);
  - case 39 reads `COUNT(Id) a0`, not `a1`.

  Further refusals have one test each: an Event inner select, a `sub` inside a child list or another `sub`, GROUP BY and ORDER BY on long text, and `CONTAINS` on long text with aggregates.
- **`ExploreQueryTest`** covers:
  - a hostile value in an OR group, which reaches the query as a bind and changes no SOQL text;
  - a chained step, and planJson replaying without it;
  - a truncated step refused, and a sorted one allowed;
  - a child count cell, HAVING, `CONTAINS` escaping, and the long-text match with its row cap;
  - `NOT` and `NOT IN`.

## Prompt file

`AgentPrompt_Explore` has other readers, so it was not edited:
- `AgentLlmTest`;
- the BE-31 spike engines `engine-current.apex` and `engine-v2.apex`;
- `tests/test_explore_prompt.py` and `tests/test_pattern_06.py`;
- the earlier research pages.

`DataExplorer` now loads `AgentPrompt_Explore_v2`. It is a copy with a new PLAN grammar section and new rules 1 and 2. The RESULT line also ends in `step=K`, so the model knows which step number to cite. `Explore_v2` has no prompt setting record of its own, so it uses `AgentLlm`'s defaults. They are the same model and token cap as the `Explore` record.

## Limits and open items

- **One run only.** 27 is above the spread seen so far, but three runs would show whether it holds.
- **q18** is a catalog fix (above).
- **q19 and q27** fail on the result set. Why is not established (unverified). q19 used 3 queries and q27 used 2.
- **The long-text match loads up to 2,001 rows,** each with its long-text field, onto the heap. The widest heap in this run was 254 KB of 6 MB. A large text field on many rows could come close to the limit, so the row cap is the guard.
- **Input tokens are an estimate.** `AgentLlmModelsApi` does not return usage.

## Undo

- Org: deploy the previous `ExplorePlan`, `ExploreQuery`, `DataExplorer` and their tests from main with a validate and a quick deploy. `DataExplorer` from main reads `AgentPrompt_Explore` again. The `_v2` static resource can stay, since nothing else reads it.
- Repo: revert the BE-43 commit.
