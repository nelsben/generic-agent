# FR2 rail fixes (FE-32): History closed by default, and the sentiment chart thins to fit the rail

Status: partial. The Jest work and the History default are done and committed. The chart defects below are open,
the e2e suite has not been run, and nothing has been deployed. The card's deploy and e2e gates are not met.

Why: OPS-52's frames show History open by default, pushing the answer below the fold. The build review (L6) found
47 points crowded into the 215 px context column.

## Fixes, with file and line

Commits on agent/frontend/FE-32: 007f75d (LWC), 5b64f19 (e2e specs).

1. **History closed by default** (`lwc/customerSummaryRail/customerSummaryRail.js`, `historyOpen = false` at line 147;
   `historyExpanded`, `handleHistoryToggle`, `handleHistoryCount` from line 598).
   The History header is a button in `customerSummaryRail.html` (line 132 onward): `aria-expanded`, `aria-controls`
   bound to the body id, and the entry count once the timeline has loaded. The timeline and the chart mount only
   while History is open (`lwc:if={historyExpanded}`), so a closed History makes no `listOutcomes` call.
2. **Entry count** (`lwc/customerSummaryHistoryTimeline/customerSummaryHistoryTimeline.js`, line 124). The timeline
   dispatches `historycount` with the number of outcomes it loaded. The rail shows it on the header.
3. **Sentiment chart bucketing** (`lwc/customerSummarySentimentChart/customerSummarySentimentChart.js`, lines 42-52
   for the constants, `bucketsOf` from line 59, `points` getter after line 200).
4. **Axis text 11 px** (`lwc/customerSummarySentimentChart/customerSummarySentimentChart.css`, `.cs-band-label` and
   `.cs-axis`, lines 67 and 72). The chart is drawn at 215 units wide, which is 1:1 with the rail's context column
   (15 rem column, 12 px padding each side, 1 px border).
5. **Same-date ticks** (`customerSummarySentimentChart.js`, `get lastDate`, line 260): the end tick is blank when it
   would repeat the start tick. This covers the two-summaries-on-one-day case only; see open items.

## Bucket rule

- Plot width is 215 - 78 - 12 = 125 px, so at most `floor(125 / 8)` = 15 points.
- Up to 15 plotted summaries: one point each, as before.
- More than 15: bucket by day if the days number 15 or fewer.
- Otherwise split the time from the first summary to the last into 15 equal spans, drop empty spans.
- A bucket of more than one sits at the mean of its band indexes, and is named by the band nearest that mean. Its
  accessible text is `date, mean <label>, N summaries`. The table still lists every summary.

## Counts

- Jest, targeted (`customerSummaryRail`, `customerSummarySentimentChart`, `customerSummaryHistoryTimeline`):
  66 of 66 pass at 007f75d.
- Jest, full (`npm run test:unit`): 394 of 394 pass at 007f75d.
- Red run (before any source change): 6 of the new cases fail, as the card requires. The output is saved in the
  worktree's `.delegation/FE-32/red-1.txt`, which is git-ignored.
- ESLint: not run. The repo has no ESLint config and ESLint is not a dependency (the same gap is recorded in
  `fr2-panel-render-fixes.md`), so `npx eslint` cannot run.
- Deploy: a `deploy validate` against the org was started and stopped before it finished. No quick deploy was made,
  and no bundle is on the org from this change.
- Playwright (`e2e/rail.spec.js`, `e2e/history.spec.js`): not run. The specs were updated for the new History
  header, but they test code that is not yet deployed.

## Not fixed (open, blocking the card)

1. **Multi-day bucket labels in the axis.** `firstDate` and `lastDate` read the bucket date, which for a multi-day
   bucket reads "A to B". Two such labels cannot fit in the 125 px plot, and `chartLabel` can read "from A to B to
   C to D". Fix: keep the first and last row's day for the axis and the label. The Jest case covers only two rows.
2. **E2E focus regex.** `history.spec.js` expects the focus text to start with a single date. A multi-day bucket
   reads "A to B, mean ...", so the regex will fail once bucketing is live. Fix: loosen it to the date prefix.
3. **Stale count across accounts.** Nothing resets `historyCount` when the rail's account changes. With History
   closed, the header can show the previous account's count. Fix: reset the count where the account changes, decide
   whether `historyOpen` also resets, and pin both in Jest.
4. **Same-date ticks beyond two rows.** Only the end tick is blanked when it equals the start tick. A bucket that
   spans days still shows a range. Covered by item 1.

## Undo

Redeploy the three bundles from the previous main commit, 54569ae: check out
`force-app/main/default/lwc/customerSummaryRail`, `customerSummarySentimentChart` and `customerSummaryHistoryTimeline`
from 54569ae, then run the same validate and quick deploy against agent-probe. The e2e spec changes in 5b64f19 can be
reverted with `git revert 5b64f19`.
