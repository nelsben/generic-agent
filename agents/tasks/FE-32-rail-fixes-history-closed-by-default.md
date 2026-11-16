---
id: FE-32
title: Rail fixes: History closed by default, and the sentiment chart thins its points to fit the rail
domain: frontend
tier: standard
status: queued
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
