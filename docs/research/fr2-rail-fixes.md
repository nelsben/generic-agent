# FR2 rail fixes (FE-32): History closed by default, and the sentiment chart thins to fit the rail

Status: done. The three bundles are deployed to agent-probe, and the rail and history e2e specs pass there.

Why: OPS-52's frames show History open by default, pushing the answer below the fold. The build review (L6) found
47 points crowded into the 215 px context column.

## Fixes, with file and line

Commits on agent/frontend/FE-32: 007f75d (LWC), 5b64f19 (e2e specs), 2e74f81 (labels, count reset, e2e regex),
then the brain's fix to the History body marker (item 7).

1. **History closed by default** (`lwc/customerSummaryRail/customerSummaryRail.js`, `historyOpen = false` at line 147;
   `historyExpanded`, `handleHistoryToggle`, `handleHistoryCount` from line 598).
   The History header is a button in `customerSummaryRail.html` (line 132 onward): `aria-expanded`, `aria-controls`
   bound to the body id, and the entry count once the timeline has loaded. The timeline and the chart mount only
   while History is open (`lwc:if={historyExpanded}`), so a closed History makes no `listOutcomes` call.
2. **Entry count** (`lwc/customerSummaryHistoryTimeline/customerSummaryHistoryTimeline.js`, line 124). The timeline
   dispatches `historycount` with the number of outcomes it loaded and the account it loaded them for. The rail
   shows the count on the header.
3. **Account change.** When the rail's account changes, History closes and its count clears
   (`customerSummaryRail.js`, line 173). A count that arrives while History is closed, or for another account, is
   ignored (`handleHistoryCount`).
4. **Sentiment chart bucketing** (`lwc/customerSummarySentimentChart/customerSummarySentimentChart.js`, lines 42-52
   for the constants, `bucketsOf` from line 59, `points` getter after line 200).
5. **Axis labels.** The start tick reads the first row's day and the end tick the last row's day, never a range;
   the end tick is blank when it would repeat the start (`get firstDate`, `get lastDate`). The chart's accessible
   label reads "from <first day> to <last day>".
6. **Axis text 11 px** (`lwc/customerSummarySentimentChart/customerSummarySentimentChart.css`, `.cs-band-label` and
   `.cs-axis`, lines 67 and 72). The chart is drawn at 215 units wide, which is 1:1 with the rail's context column
   (15 rem column, 12 px padding each side, 1 px border).
7. **History body marker** (brain fix). The History body first carried `data-section-body="history"`, the marker of
   the four context sections, each of which has `aria-busy`. Rail spec 6 waits for exactly four marked bodies, all
   with `aria-busy="false"`, so it timed out on both platforms. The History body now carries `data-history-body`,
   and a Jest case pins the four sections (deals, activity, cases, summary) and their `aria-busy`.

## Bucket rule

- Plot width is 215 - 78 - 12 = 125 px, so at most `floor(125 / 8)` = 15 points.
- Up to 15 plotted summaries: one point each, as before.
- More than 15: bucket by day if the days number 15 or fewer.
- Otherwise split the time from the first summary to the last into 15 equal spans, drop empty spans.
- A bucket of more than one sits at the mean of its band indexes, and is named by the band nearest that mean. Its
  accessible text is `date, mean <label>, N summaries`; a bucket of several days reads
  `YYYY-MM-DD to YYYY-MM-DD, mean <label>, N summaries`. The table still lists every summary.

## Counts

- Jest, full (`npm run test:unit`): 397 of 397 pass in 11 suites.
- Red run (before any source change): 6 of the new cases fail, as the card requires.
- Deploy: the three bundles were validated against agent-probe with RunLocalTests (564 tests, 0 errors) and quick
  deployed. The rail bundle was validated and quick deployed again after the marker fix.
- Playwright against agent-probe (`e2e/rail.spec.js`, `e2e/history.spec.js`): 10 of 10 pass (8 on `mac`, 2 on
  `windows`). Before the marker fix, rail spec 6 failed on both platforms and the other 8 passed. Spec 6's medians
  after the fix: first paint 24 ms (`mac`) and 17 ms (`windows`), context filled 355 ms and 397 ms.
- ESLint: not run. The repo has no ESLint config and ESLint is not a dependency (the same gap is recorded in
  `fr2-panel-render-fixes.md`), so `npx eslint` cannot run.

## Still open

- No e2e spec loads an account with more than 15 summaries, so the bucketed chart is checked in Jest only.
- Whether the rail clips the card's last column (raised in FE-31's review) was not looked at.

## Undo

Redeploy the three bundles from the previous main commit, 54569ae: check out
`force-app/main/default/lwc/customerSummaryRail`, `customerSummarySentimentChart` and `customerSummaryHistoryTimeline`
from 54569ae, then validate with RunLocalTests and quick deploy against agent-probe. Restore `e2e/rail.spec.js` and
`e2e/history.spec.js` from 54569ae the same way.
