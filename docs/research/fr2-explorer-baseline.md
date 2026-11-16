# FR2+ explorer baseline: the 30 BE-31 questions, three runs per engine (BE-41)

- Date: 2026-11-15. Org `agent-probe`, anonymous Apex only, read-only. Nothing was deployed, and no record, user or setting was created or changed.
- Code: BE-31's [run.py](../../spikes/explorer-scale/run.py), harness, engines and [questions.json](../../spikes/explorer-scale/questions.json), unchanged. No question, reference or grading rule changed. Each run is 30 questions, one anonymous Apex transaction per question, 3 at a time.
- Results: [baseline-real-1..3](../../spikes/explorer-scale/results/) and baseline-current-1..3, one JSON line per question in BE-31's record format (counts, statuses and limits only).
- Engines (as in [fr2-explorer-scale.md](fr2-explorer-scale.md)): `real` is the deployed `DataExplorer.explore`; `current` is the metered replay of its loop. Status words: verified (measured here), unverified (inference).
- All 180 transactions finished. Every row has a verdict and a result; none timed out or failed to compile.

## Plain answer

- **The deployed explorer passes 20 of 30, every time:** runs of 20, 20 and 20 (spread 0), the same as BE-31's single run of 20. The count is steady, but the set is not: 4 questions changed result between runs (verified).
- **The metered replay is less steady:** runs of 17, 21 and 22 (spread 5, median 21), against BE-31's single 23. BE-31's 23 sits inside the range, 1 above the best run here. The replay's first run (17) came before the other two; the page does not know why it was low (unverified: model noise is the simplest reading).
- **So the two engines do not differ reliably:** deployed 20, 20, 20 against replay 17, 21, 22. The three-run medians are 20 and 21. Treat BE-31's 27 (prototype) against 23 or 20 as a gain of 6 to 7 questions over a baseline of 20 to 21, and judge the build against 20 for the deployed explorer, not against 23.
- **Model calls: the replay spent 271 across its three runs** (90 transactions; metered by the harness). The deployed engine's calls cannot be counted from outside it (Models API calls do not show in `Limits.getCallouts()`), so the real runs' model calls and tokens stay `-1` and are not estimated here. The real runs took about the same wall time as the replay, which suggests a similar number of calls, but that is unverified.

## Pass counts and spread

| Engine | Run 1 | Run 2 | Run 3 | Spread (max - min) | Median | BE-31 (1 run) |
|---|---|---|---|---|---|---|
| real (deployed) | 20 | 20 | 20 | 0 | 20 | 20 |
| current (replay) | 17 | 21 | 22 | 5 | 21 | 23 |

| Group (questions) | real, runs 1-3 | real BE-31 | current, runs 1-3 | current BE-31 |
|---|---|---|---|---|
| single object (5) | 5, 5, 5 | 5 | 5, 5, 5 | 5 |
| one parent lookup (3) | 3, 3, 3 | 3 | 3, 3, 3 | 3 |
| two lookups (2) | 1, 1, 2 | 2 | 0, 2, 2 | 1 |
| children, anti-join, HAVING (5) | 3, 3, 3 | 3 | 2, 3, 4 | 4 |
| OR and grouped filters (5) | 3, 3, 2 | 2 | 2, 3, 3 | 4 |
| semi-joins (4) | 3, 3, 3 | 3 | 3, 3, 3 | 3 |
| long text (2) | 0, 0, 0 | 0 | 0, 0, 0 | 0 |
| chained steps (2) | 1, 1, 1 | 1 | 1, 1, 1 | 2 |
| object outside the curated 8 (1) | 0, 0, 0 | 0 | 0, 0, 0 | 0 |
| denied object (1) | 1, 1, 1 | 1 | 1, 1, 1 | 1 |
| **all (30)** | **20, 20, 20** | **20** | **17, 21, 22** | **23** |

## Per-engine medians per question, next to BE-31

Median over the three runs per question; across all 30 questions the table below gives the median of those per-question medians. BE-31's single value is in brackets.

| Median over questions | real | current |
|---|---|---|
| model calls | not visible | 3 (3) |
| input tokens | not visible | 10,553 (10,078) |
| output tokens | not visible | 255 (234) |
| CPU ms | 263 (267) | 241 (268) |
| heap KB | 39 (33) | 47 (45) |
| wall ms | 9,189 (7,352) | 8,439 (8,701) |
| SOQL statements | 4 (4) | 4 (4) |
| query rows | 17 (9) | 9 (10) |
| worst single transaction: CPU ms | 373 (403) | 370 (370) |
| worst single transaction: model calls | not visible | 5 (5) |
| worst single transaction: input tokens | not visible | 24,519 (19,351) |

Limits are far from binding in either engine: worst CPU is 373 ms of 10,000 and worst heap is 80 KB of 6 MB (verified).

Per question (letters: P pass, F fail, for runs 1 to 3; BE-31's single result next to it). Calls and tokens are the replay's; the real engine shows none (`-1`).

| q | group | real runs 1-3 | real BE-31 | current runs 1-3 | current BE-31 | calls (BE-31) | input tokens (BE-31) | CPU ms real | CPU ms current (BE-31) | heap KB real | heap KB current (BE-31) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| q01 | single | PPP | P | PPP | P | 2 (2) | 6801 (6419) | 243 (218) | 205 (261) | 37 (32) | 44 (42) |
| q02 | single | PPP | P | PPP | P | 2 (2) | 6816 (6434) | 259 (206) | 195 (239) | 37 (32) | 44 (42) |
| q03 | single | PPP | P | PPP | P | 2 (2) | 6939 (6557) | 214 (230) | 190 (242) | 39 (34) | 46 (44) |
| q04 | single | PPP | P | PPP | P | 2 (2) | 7037 (6655) | 245 (198) | 206 (218) | 40 (33) | 47 (45) |
| q05 | single | PPP | P | PPP | P | 2 (2) | 6982 (6621) | 247 (228) | 212 (253) | 39 (33) | 47 (45) |
| q06 | parent | PPP | P | PPP | P | 4 (4) | 13911 (13274) | 301 (272) | 237 (271) | 38 (33) | 46 (45) |
| q07 | parent | PPP | P | PPP | P | 4 (4) | 14262 (13498) | 297 (328) | 311 (308) | 40 (34) | 48 (47) |
| q08 | parent | PPP | P | PPP | P | 4 (4) | 14308 (13544) | 312 (324) | 260 (342) | 38 (33) | 47 (45) |
| q09 | parent2 | FFP | P | FPP | P | 5 (5) | 17760 (17739) | 301 (323) | 315 (357) | 39 (31) | 53 (52) |
| q10 | parent2 | PPP | P | FPP | F | 5 (5) | 19088 (18922) | 343 (403) | 325 (365) | 40 (36) | 51 (51) |
| q11 | child | FFF | F | FFP | F | 3 (3) | 11251 (10845) | 287 (260) | 271 (248) | 41 (34) | 51 (47) |
| q12 | child | PPP | P | FPP | P | 4 (4) | 19232 (18007) | 344 (299) | 292 (328) | 64 (51) | 77 (73) |
| q13 | child | PPP | P | PPP | P | 2 (2) | 6892 (6510) | 219 (266) | 193 (221) | 37 (32) | 45 (43) |
| q14 | child | PPP | P | PPP | P | 3 (3) | 10467 (9894) | 229 (267) | 252 (276) | 37 (32) | 46 (43) |
| q15 | child | FFF | F | FFF | P | 2 (4) | 7226 (14092) | 237 (259) | 222 (352) | 39 (33) | 48 (47) |
| q16 | or | FPP | F | FFP | P | 2 (4) | 6818 (13451) | 278 (206) | 215 (280) | 37 (31) | 45 (46) |
| q17 | or | FFF | F | FFP | F | 5 (4) | 24181 (16974) | 327 (312) | 317 (300) | 50 (36) | 73 (62) |
| q18 | or | PPP | P | PPP | P | 2 (2) | 6842 (6460) | 195 (185) | 200 (188) | 38 (32) | 45 (43) |
| q19 | or | PFF | P | FPF | P | 4 (2) | 14923 (6592) | 308 (284) | 325 (251) | 43 (33) | 52 (44) |
| q20 | or | PPF | F | PPF | P | 4 (5) | 16180 (19351) | 310 (325) | 309 (370) | 55 (35) | 58 (58) |
| q21 | semi | PPP | P | PPP | P | 2 (2) | 6853 (6471) | 210 (267) | 218 (246) | 37 (32) | 45 (42) |
| q22 | semi | PPP | P | PPP | P | 3 (4) | 12251 (15380) | 264 (302) | 245 (300) | 43 (34) | 55 (53) |
| q23 | semi | PPP | P | PPP | P | 3 (3) | 10710 (10105) | 293 (228) | 250 (292) | 40 (34) | 49 (46) |
| q24 | semi | FFF | F | FFF | F | 3 (3) | 10639 (10050) | 279 (310) | 267 (259) | 38 (33) | 47 (45) |
| q25 | longtext | FFF | F | FFF | F | 2 (2) | 6818 (6447) | 197 (225) | 207 (207) | 36 (32) | 43 (42) |
| q26 | longtext | FFF | F | FFF | F | 2 (2) | 6832 (6458) | 175 (197) | 197 (196) | 36 (32) | 43 (42) |
| q27 | chain | FFF | F | FFF | P | 4 (3) | 14527 (10520) | 262 (279) | 298 (265) | 39 (35) | 49 (48) |
| q28 | chain | PPP | P | PPP | P | 4 (3) | 13943 (9974) | 261 (290) | 260 (303) | 38 (33) | 46 (44) |
| q29 | anyobject | FFF | F | FFF | F | 1 (1) | 3366 (3175) | 153 (165) | 166 (215) | 36 (31) | 42 (40) |
| q30 | deny | PPP | P | PPP | P | 3 (4) | 10288 (13325) | 279 (300) | 220 (312) | 38 (33) | 45 (45) |

## Questions that failed in all three runs, with causes

Causes come from the run records (which tables the engine built and their size) plus BE-31's findings. "Last table" means the table the grader reads. The reasons the model chose as it did are unverified.

**Both engines, all three runs (verified from the records):**

- **q25 and q26 (long text):** no query was run at all (0 queries, status EMPTY). The plan grammar cannot filter `Description`, so the model declines. Structural; BE-43 and BE-44 target it.
- **q29 (`Product2`, "how many active products"):** no query was run (status EMPTY). The object is not in the 8-object catalog. Structural; BE-42 targets it.
- **q24 (open case and no completed task):** two queries, `Case` then `Task`. The last table is Task rows and the reference is a set of accounts, so it cannot pass. The grammar has no anti-join, so the engine carries Ids across turns and the answer ends on a table of the wrong object.
- **q27 (5 largest open opportunities, closing this year):** two queries on `Opportunity`, and the last table has 0 rows in every run of both engines. BE-31's replay passed it once. The grammar does it in two steps (top 5, then a date filter). Why the second step comes back empty is not established here; BE-31 also flagged how this question's date window is read as a possible disagreement with the reference (unverified).

**Deployed engine only, all three runs:**

- **q11 (accounts with no opportunities):** the engine queries `Opportunity` and `Account` in either order, and the verdict alternates between a superset and a wrong set. With no anti-join the answer is rebuilt from two tables. The replay passed it once (run 3), where the last table was a one-row account result.
- **q15 (accounts with more than 3 open opportunities):** one query on `Opportunity` with 13 rows in every run. The reference is accounts (HAVING over a count), which the grammar cannot express, so the engine lists the opportunities and the answer is a superset. The replay failed all three runs too (it passed in BE-31, 1 of 1).
- **q17 (open opportunities in Prospecting or amount over 250,000):** the grammar has no OR, so the engine runs 2 to 4 separate queries and the last table is one half of the answer. The replay passed once (run 3).

## Questions whose result changed between runs

Real (4): q09 (F, F, P), q16 (F, P, P), q19 (P, F, F), q20 (P, P, F).

Current (8): q09 (F, P, P), q10 (F, P, P), q11 (F, F, P), q12 (F, P, P), q16 (F, F, P), q17 (F, F, P), q19 (F, P, F), q20 (P, P, F).

Notes:

- q16 and q20 are counts. q16 passed on run 2 and 3 of the deployed engine and on run 3 only of the replay. q20 failed once in each engine, on run 3. Failures there are wrong numbers (the grader reads the number in the answer), not unanswered questions.
- BE-31's single-run disagreements between the two engines (5 of 30) were noise of this size: here the same engine disagrees with itself on 4 (real) and 8 (current) questions.
- The replay's first run (17) is low mainly on the one-lookup, children and OR groups (q09, q10, q11, q12, q16, q17 and q19 all failed in it). Whether that was one bad stretch of model behaviour is unverified.

## What this changes for the build

- After the build, compare the deployed explorer against 20, 20, 20, and a gain must clear the replay's own spread (5) to be called real. A run of 21 or 22 proves nothing.
- The always-failing 8 questions for the deployed engine (q11, q15, q17, q24, q25, q26, q27, q29) are the ones the build cards should flip; the 4 that change between runs are noise to measure, not to fix.
- q27 has no named structural cause yet and should be checked against its reference before BE-42 to BE-44 count it as a win or a loss.

## Undo

No state to undo: read-only anonymous Apex, no deploy, no record. Each anonymous run leaves a debug log, which ages out. Repo: delete `docs/research/fr2-explorer-baseline.md` and `spikes/explorer-scale/results/baseline-*.jsonl`.
