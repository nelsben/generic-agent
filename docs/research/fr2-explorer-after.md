# FR2+ explorer after-evaluation: the 30 BE-31 questions, three runs on the rebuilt deployed explorer (BE-45)

- Date: 2026-11-16. Org `agent-probe`, anonymous Apex only, read-only. Nothing was deployed, and no record, user or setting was created or changed.
- Status words: verified (measured here), unverified (inference).
- Results: [after-deployed-1..3](../../spikes/explorer-scale/results/), one JSON line per question in BE-31's record format (counts, statuses and limits only; engine label `after`). Before: [baseline-real-1..3](../../spikes/explorer-scale/results/) from [fr2-explorer-baseline.md](fr2-explorer-baseline.md) (BE-41).
- Questions, references and grading: BE-31's [questions.json](../../spikes/explorer-scale/questions.json) and [harness.apex](../../spikes/explorer-scale/harness.apex), unchanged; [run.py](../../spikes/explorer-scale/run.py) unchanged too. Each run is 30 questions, one anonymous Apex transaction per question, 3 at a time. All 90 transactions finished with a verdict; none timed out, failed to compile or lost its session, so no question was rerun.

## Which engine produced the after numbers

The **deployed `DataExplorer.explore`** (prompt `Explore_v2`, catalog built per question), called from a small engine file kept in the session scratch folder, not in the repo. It is BE-43's driver with the label changed: it calls `DataExplorer.explore(question, null, null)`, then reads the counts `DataExplorer.lastRun` keeps. It is not run.py's `current` replay (that one uses the old StaticResource prompt and a catalog built with no question). It is not BE-31's `real` engine file either, because that one prints no model calls.

- **Model calls are exact** (from `lastRun`). **Input tokens are an estimate**: (prompt file characters x calls + every variable sent) / 4. BE-41's real runs show neither, so the before columns for these two are "not visible" and no before/after token comparison is made.
- Deployed code since BE-41: BE-42 (catalog), BE-43 (grammar v2, prompt `Explore_v2`), BE-44 (long-text search past 2,000 rows), BE-57 (named picklist values) and BE-58 (an answer with text and no query is OK, not EMPTY). The runs measure the whole stack together; they cannot split the gain between cards.

## Plain answer

- **After: 28, 27 and 28 of 30** (median 28, spread 1). **Before: 20, 20, 20** (spread 0). The worst after run is 7 above the best before run (verified).
- **7 questions are a gain** by the rule (after 3 of 3, before at most 1 of 3): q09, q11, q15, q17, q25, q26 and q29. 
- **3 questions flip between runs after the build:** q13 (P, F, P), q19 (F, P, F) and q24 (P, F, P). Before, 4 flipped: q09, q16, q19 and q20.
- **26 of 30 pass 3 of 3; 1 fails all 3 (q27).** Before, 18 passed 3 of 3 and 8 failed all 3.
- **Named as within the spread, not gains:** q16 (before 2 of 3, now 3), q20 (before 2 of 3, now 3), q24 (before 0 of 3, now 2: closest to a gain but short of 3 of 3), q19 (1 of 3 before, 1 of 3 now, flips), q13 (3 of 3 before, 2 now: one wrong count, FAIL:number in run 2), and all 17 questions that passed 3 of 3 both times. q27 fails 3 of 3 both times: no change.
- **BE-58 alone moves no verdict.** The harness's grade reads the status only to fail on ERROR; every status was OK or EMPTY before and OK after, so the status change alone cannot flip a pass or a fail. The statuses it did change: q25, q26, q29 and q30 had EMPTY in baseline (a text answer, no query), now all 90 rows are OK. q25, q26 and q29 pass now because of BE-42 to BE-44 (they have result sets and an answer), not because of the label. q30 (denied object) passed before and after.
- **Cost:** model calls per question median 2 (1 to 4), 74, 71 and 68 calls per 30-question run; input tokens (estimate) median about 7,130 per question, worst 15,340. CPU median 713 ms, worst 1,615 ms of 10,000 (before: 263 and 373). Heap median about 241 KB, worst about 255 KB of 6 MB (before: 38 and 63). CPU and heap rose about 2.7x and 6x because the catalog is now built per question; limits are still far from binding (verified). Wall time median 7.6 s (before 9.2 s).

## Pass counts and spread

| | Run 1 | Run 2 | Run 3 | Spread (max - min) | Median |
|---|---|---|---|---|---|
| before (BE-41, deployed) | 20 | 20 | 20 | 0 | 20 |
| after (deployed, BE-45) | 28 | 27 | 28 | 1 | 28 |

| Group (questions) | before, runs 1-3 | after, runs 1-3 | calls per question | input tokens per question | CPU ms per question | heap KB |
|---|---|---|---|---|---|---|
| single (5) | 5, 5, 5 | 5, 5, 5 | 2.0 (2.0-2.0) | 6433.2 (6432.4-6441.4) | 607.6 (588.4-677.2) | 235.0 (233.6-235.4) |
| parent (3) | 3, 3, 3 | 3, 3, 3 | 2.7 (2.0-2.7) | 9432.7 (7176.0-9433.3) | 966.3 (768.3-995.3) | 244.8 (244.6-247.9) |
| parent2 (2) | 1, 1, 2 | 2, 2, 2 | 3.0 (2.0-3.5) | 10549.0 (7099.0-12653.0) | 1177.0 (985.5-1469.0) | 251.5 (250.0-251.9) |
| child (5) | 3, 3, 3 | 5, 4, 5 | 2.0 (2.0-2.2) | 7230.4 (7226.2-7961.2) | 670.8 (646.0-681.0) | 244.4 (244.3-244.7) |
| or (5) | 3, 3, 2 | 4, 5, 4 | 2.4 (2.4-2.4) | 8070.4 (8065.8-8145.6) | 758.2 (754.8-785.6) | 239.3 (239.2-239.5) |
| semi (4) | 3, 3, 3 | 4, 3, 4 | 2.8 (2.8-3.0) | 10389.8 (10327.8-11295.8) | 854.8 (817.2-863.2) | 245.9 (245.0-246.2) |
| longtext (2) | 0, 0, 0 | 2, 2, 2 | 2.0 (2.0-2.0) | 6891.0 (6883.0-6895.5) | 695.0 (690.5-714.5) | 239.4 (237.7-240.5) |
| chain (2) | 1, 1, 1 | 1, 1, 1 | 2.5 (2.5-3.0) | 8594.5 (8585.5-10479.0) | 733.0 (732.5-785.0) | 239.5 (233.0-239.5) |
| anyobject (1) | 0, 0, 0 | 1, 1, 1 | 3.0 (3.0-4.0) | 9782.0 (9750.0-13230.0) | 676.0 (594.0-811.0) | 238.4 (223.6-238.6) |
| deny (1) | 1, 1, 1 | 1, 1, 1 | 1.0 (1.0-3.0) | 3135.0 (3135.0-9965.0) | 482.0 (407.0-781.0) | 230.8 (230.8-235.7) |


Per category: passes out of the category's questions, per run. The three right columns are the mean per question in the category, per run: median of the three runs, with the range of the three runs in brackets.

## Per question

Before and after are passes out of 3 (letters P, F for runs 1 to 3). Calls, tokens, CPU and heap are the median over the three after runs, with the range in brackets. Tokens are the estimate described above. BE-41 shows no calls or tokens for the deployed engine; its CPU and heap are in the baseline note.

| q | group | before (BE-41) | after | calls | input tokens (est.) | CPU ms | heap KB | result |
|---|---|---|---|---|---|---|---|---|
| q01 | single | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 6361 (6361-6361) | 624 (550-751) | 234 (234-234) | passed 3 of 3 before too |
| q02 | single | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 6195 (6195-6198) | 575 (532-705) | 232 (230-232) | passed 3 of 3 before too |
| q03 | single | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 6503 (6499-6541) | 573 (546-646) | 236 (231-236) | passed 3 of 3 before too |
| q04 | single | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 6570 (6570-6570) | 627 (587-710) | 238 (238-238) | passed 3 of 3 before too |
| q05 | single | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 6537 (6537-6537) | 626 (574-740) | 237 (233-237) | passed 3 of 3 before too |
| q06 | parent | 3 of 3 (PPP) | 3 of 3 (PPP) | 3 (2-3) | 9858 (6494-9861) | 1070 (859-1216) | 246 (245-246) | passed 3 of 3 before too |
| q07 | parent | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 7322 (7322-7322) | 753 (741-791) | 245 (244-245) | passed 3 of 3 before too |
| q08 | parent | 3 of 3 (PPP) | 3 of 3 (PPP) | 3 (2-3) | 11117 (7712-11118) | 942 (693-1125) | 244 (244-254) | passed 3 of 3 before too |
| q09 | parent2 | 1 of 3 (FFP) | 3 of 3 (PPP) | 2 (2-4) | 7072 (7041-14738) | 1011 (942-1615) | 252 (252-253) | gain |
| q10 | parent2 | 3 of 3 (PPP) | 3 of 3 (PPP) | 3 (2-4) | 10568 (7157-14026) | 1323 (960-1412) | 251 (248-251) | passed 3 of 3 before too |
| q11 | child | 0 of 3 (FFF) | 3 of 3 (PPP) | 2 (2-2) | 7355 (7345-7357) | 729 (714-732) | 244 (244-244) | gain |
| q12 | child | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 7493 (7441-7498) | 567 (536-624) | 254 (253-255) | passed 3 of 3 before too |
| q13 | child | 3 of 3 (PPP) | 2 of 3 (PFP) | 2 (2-2) | 6926 (6896-6942) | 584 (551-636) | 239 (238-239) | flips |
| q14 | child | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-3) | 7000 (6997-10646) | 704 (646-823) | 241 (241-241) | passed 3 of 3 before too |
| q15 | child | 0 of 3 (FFF) | 3 of 3 (PPP) | 2 (2-2) | 7396 (7385-7412) | 701 (696-746) | 244 (244-245) | gain |
| q16 | or | 2 of 3 (FPP) | 3 of 3 (PPP) | 2 (2-2) | 6426 (6396-6426) | 622 (578-666) | 235 (234-235) | within the spread |
| q17 | or | 0 of 3 (FFF) | 3 of 3 (PPP) | 2 (2-2) | 6793 (6793-6793) | 642 (619-675) | 241 (241-241) | gain |
| q18 | or | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 7008 (7008-7008) | 840 (834-894) | 242 (241-242) | passed 3 of 3 before too |
| q19 | or | 1 of 3 (PFF) | 1 of 3 (FPF) | 3 (3-3) | 9577 (9570-10316) | 807 (789-837) | 238 (238-238) | flips |
| q20 | or | 2 of 3 (PPF) | 3 of 3 (PPP) | 3 (3-3) | 10555 (10185-10555) | 894 (886-910) | 241 (241-242) | within the spread |
| q21 | semi | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-2) | 7007 (7004-7007) | 666 (602-682) | 242 (242-242) | passed 3 of 3 before too |
| q22 | semi | 3 of 3 (PPP) | 3 of 3 (PPP) | 3 (3-3) | 11932 (11907-11987) | 905 (874-949) | 249 (249-250) | passed 3 of 3 before too |
| q23 | semi | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-3) | 7342 (7308-11126) | 734 (704-811) | 247 (242-247) | passed 3 of 3 before too |
| q24 | semi | 0 of 3 (FFF) | 2 of 3 (PFP) | 4 (4-4) | 15063 (15030-15340) | 1059 (993-1162) | 246 (246-247) | flips |
| q25 | longtext | 0 of 3 (FFF) | 3 of 3 (PPP) | 2 (2-2) | 7178 (7178-7181) | 879 (804-880) | 241 (241-244) | gain |
| q26 | longtext | 0 of 3 (FFF) | 3 of 3 (PPP) | 2 (2-2) | 6601 (6588-6613) | 549 (502-586) | 237 (234-238) | gain |
| q27 | chain | 0 of 3 (FFF) | 0 of 3 (FFF) | 3 (3-3) | 10118 (10092-10130) | 744 (695-760) | 237 (224-237) | fails all 3 |
| q28 | chain | 3 of 3 (PPP) | 3 of 3 (PPP) | 2 (2-3) | 7079 (7071-10828) | 721 (706-875) | 242 (242-242) | passed 3 of 3 before too |
| q29 | anyobject | 0 of 3 (FFF) | 3 of 3 (PPP) | 3 (3-4) | 9782 (9750-13230) | 676 (594-811) | 238 (224-239) | gain |
| q30 | deny | 3 of 3 (PPP) | 3 of 3 (PPP) | 1 (1-3) | 3135 (3135-9965) | 482 (407-781) | 231 (231-236) | passed 3 of 3 before too |

Questions that changed result between after runs: q13, q19 and q24. q13 in run 2 was a wrong number (FAIL:number, one query, 5 rows). q19 failed runs 1 and 3 as a superset (one query, 11 rows) and passed run 2 with two queries. q24 failed run 2 on the set (3 queries, 0 rows in the last table) and passed runs 1 and 3 (1 row). q27 failed all three runs as a wrong set: 2 queries and an empty last table, every time, the same as baseline.

## Five lines for pattern 02 (for OPS-39 to paste)

1. The deployed explorer answered 28, 27 and 28 of BE-31's 30 questions correctly in three runs (n = 3 runs x 30 questions = 90 transactions), against 20, 20 and 20 before the catalog, grammar and long-text builds (n = 90).
2. Seven questions are a real gain (right in 3 of 3 runs after, at most 1 of 3 before): a question over two lookups, accounts with no opportunities, accounts with more than 3 open opportunities, an OR filter, both long-text searches and an object outside the first catalog (n = 7 of 30 questions, 3 runs each).
3. Run to run, 3 of 30 questions still flip (an OR with a date range, a count, an anti-join), 1 never passes (the top-5-then-date chain), and 26 pass every time (n = 30 questions, 3 runs); one run is not enough to claim a gain on a single question.
4. Each question took a median of 2 model calls (range 1 to 4) and about 7,100 estimated input tokens (worst about 15,300) (n = 90 transactions; calls exact, tokens estimated).
5. Platform limits stay far from binding: CPU median 713 ms and worst 1,615 ms of 10,000, heap worst about 255 KB of 6 MB (n = 90 transactions; before: CPU worst 373 ms, heap worst 63 KB, n = 90).

## What this does not show

- Which card caused which gain: the three builds were deployed before the runs and were not measured one at a time here (BE-42 and BE-43 each ran once; see their notes).
- Whether the grader is right on q27: BE-41 flagged how its date window is read; that is still unchecked here (unverified).
- Model output tokens and the before engine's calls: not visible from outside the deployed class.

## Undo

No state to undo: read-only anonymous Apex, no deploy, no record. Each anonymous run leaves a debug log, which ages out. Repo: delete `docs/research/fr2-explorer-after.md` and `spikes/explorer-scale/results/after-deployed-*.jsonl`.
