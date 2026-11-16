---
id: FE-32
title: Rail fixes: History closed by default, and the sentiment chart thins its points to fit the rail
domain: frontend
tier: standard
status: merged
scope: [force-app/main/default/lwc/customerSummaryRail/**, force-app/main/default/lwc/customerSummarySentimentChart/**, force-app/main/default/lwc/customerSummaryHistoryTimeline/**, e2e/rail.spec.js, e2e/history.spec.js, docs/research/fr2-rail-fixes.md]
forbid: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/lwc/customerSummaryCard/**, force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/classes/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, playwright.config.js, e2e/panel.spec.js, e2e/global-setup.js, e2e/support/**, e2e/.auth/**, docs/assets/**, docs/patterns/**, docs/plans/**, README.md, agents/**, reference/**, .chassis-delegation.json, sfdx-project.json]
resources: [org-live]
red_test: npm run test:unit -- customerSummaryRail customerSummarySentimentChart (new Jest cases for the History default and the thinned point count fail on main and pass after)
gate: jest
budget: 2-attempts
spend: 10
---
## Why

OPS-52's frames show History open by default in the rail, pushing the answer below the fold, and the build review (L6) found the sentiment chart crowding 47 points into 215 px: overlapping dots, 6 px axis text and two date ticks reading the same day. Ben gave full-burn flexibility on bug fixes (2026-11-15).

## Done when

- History in the rail is closed by default (brain's decision under the full-burn go, reversible): the section header is a button with aria-expanded=false and aria-controls, it shows the entry count, opening it loads the timeline and chart as today, and a closed History makes no Apex call. Jest pins the default and the toggle; e2e/rail.spec.js and e2e/history.spec.js are updated to open History before they assert on it
- L6: the sentiment chart draws at most one point per 8 px of plot width (so about 26 in the 215 px rail), bucketing by day or by equal time spans and showing each bucket's mean label with its count in the point's accessible text; the server LIMIT of 50 is unchanged. Axis text is at least 11 px, and no two ticks read the same date. The data table or accessible summary the chart already has still lists every row it was given
- Gates: npm run test:unit passes in full; npx eslint on the changed LWC files passes. Deploy the changed LWC bundles to agent-probe only: sf project deploy validate --source-dir <the changed bundles> --test-level RunLocalTests -o agent-probe, then CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o agent-probe. If the deploy hook refuses for want of a target org, set it worktree-local and unset it before hand-back. Then run npx playwright test e2e/rail.spec.js e2e/history.spec.js once against agent-probe and report the counts; a failure the change did not cause is reported, not fixed
- docs/research/fr2-rail-fixes.md (new) lists each fix with file and line, the bucket rule, the Jest and e2e counts, what was not fixed and why, and an Undo list (the bundles to redeploy from the previous main commit)
- Nothing creates, edits or deletes a record beyond the product's own session and outcome rows the e2e suite already writes. No Id, job Id, username, email, hostname or local path is written to a committed file. e2e/.auth is never printed or committed. No screenshots are re-captured

## Review

Brain review (2026-11-16). Two worker attempts (haiku, an experiment from sonnet on a standard card; $1.41 with one advisor call). The first stopped on its stop rule and a tool outage; the second was refuted on files (it left out e2e/rail.spec.js). The brain finished the card by hand instead of a respawn: it quick deployed the worker's validated bundles, ran the two e2e specs, found and fixed a regression, and rewrote the research note. The brain read the whole diff.

Findings:
- History in the rail is closed by default. Its header is a button with aria-expanded and aria-controls, and shows the entry count once the timeline has loaded. The timeline and the chart mount only while History is open, so a closed History makes no outcomes call.
- An account change closes History and clears the count. A count from a closed timeline, or one loaded for another account, is ignored.
- The sentiment chart is drawn 1:1 in the 215 px context column and shows at most 15 points (125 px of plot, 8 px per point). Past 15 summaries it buckets by day, then by 15 equal spans of time. A bucket sits at the mean of its labels, is named by the nearest band, shows no reason text, and says how many summaries it holds. The table still lists every summary. Axis text is 11 px, and the axis ticks read single days, never a range.
- Brain fix (46cfc22): the History body reused data-section-body, the marker of the four context sections that each carry aria-busy. Rail spec 6 waits for exactly four such bodies, so it timed out on both platforms. The History body now carries data-history-body, and a Jest case pins the four sections and their aria-busy.

Gate (mod verify at 46cfc22): green. Jest 397 of 397 in 11 suites. check-docs 84 pages, 0 broken.

e2e against agent-probe (rail.spec.js, history.spec.js): 10 of 10 pass after the fix (8 mac, 2 windows). Before it, rail spec 6 failed on both platforms and the other 8 passed.

Org: agent-probe only. The three LWC bundles were validated with RunLocalTests and quick deployed; the rail bundle was validated and quick deployed again after the fix. No Apex changed. No record, user or setting was created. The worktree-local target org is unset.

Disclosed and accepted:
- No e2e spec loads an account with more than 15 summaries, so bucketing is checked in Jest only.
- ESLint cannot run: the repo has no eslint config or dependency.
- The history spec's focus check now also accepts a "YYYY-MM-DD to YYYY-MM-DD" range.

Still open:
- Whether the rail clips the card's last column (raised in FE-31's review).

Privacy check over the branch's own diff (409 added lines): 0 denylist hits, no pattern hits, no URL hosts.
