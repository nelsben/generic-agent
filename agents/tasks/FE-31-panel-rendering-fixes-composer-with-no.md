---
id: FE-31
title: Panel rendering fixes: composer with no speech API, chips fit, card table and badge, mic focus ring, header target size, one fallback palette
domain: frontend
tier: standard
status: queued
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/lwc/customerSummaryCard/**, force-app/main/default/lwc/customerSummaryPanel/**, e2e/panel.spec.js, docs/research/fr2-panel-render-fixes.md]
forbid: [force-app/main/default/lwc/customerSummaryRail/**, force-app/main/default/lwc/customerSummarySentimentChart/**, force-app/main/default/lwc/customerSummaryHistoryTimeline/**, force-app/main/default/classes/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, playwright.config.js, e2e/global-setup.js, e2e/support/**, e2e/.auth/**, docs/assets/**, docs/patterns/**, docs/plans/**, README.md, agents/**, reference/**, .chassis-delegation.json, sfdx-project.json]
resources: [org-live]
red_test: npm run test:unit -- customerSummaryConversation customerSummaryVoiceInput customerSummaryCard (new Jest cases for the unsupported-note placement, the chip row wrap, the card badge text and the fallback colour fail on main and pass after)
gate: jest
budget: 2-attempts
spend: 10
---
## Why

The build review (M2, M5, L5, L7, L8) and OPS-52's new frames found rendering bugs a buyer sees in the first minute: the composer crushed to 10 px when the browser has no speech API, clipped chips, a table that cuts off its last column, an "Empty" badge on a follow-up card, no focus ring on the mic, and a 1280x720 target-size failure. Ben gave full-burn flexibility on bug fixes (2026-11-15).

## Done when

- M2: when the browser has no speech recognition, the voice component's unsupported note renders below the composer row (full width), not inside the no-wrap flex row; the textarea keeps at least its normal width. A Jest case with SpeechRecognition undefined pins it
- L5: the five quick-action chips are all visible in the 420 px compact window with no sideways scroll: the row wraps (flex-wrap) and no chip label is cut. A Jest case pins the wrap class; an e2e check at the 420 px window asserts each chip's box is inside the row's box
- The 'Empty' badge (customerSummaryCard.js:63 maps EMPTY to 'Empty') no longer shows on a follow-up card that has a body: find why the follow-up card is classed EMPTY and fix the cause, not the label. If the fix is in Apex (forbidden here), leave it, say so in the hand-back and make no Apex change
- A card's table never hides its last column (OPS-52 saw the Close column cut off in the rail): the table sits in its own horizontally scrollable box with tabindex=0, role=region and an aria-label, so the page never scrolls sideways and a keyboard user can scroll it; at the rail's width at 1440x900 the last column header is reachable
- The mic button has a visible focus ring (SLDS focus style or a 2 px outline meeting 3:1 against its background) wherever it renders, including in the rail
- M5: the window header's icon buttons (Minimize and its neighbours) meet WCAG 2.2 2.5.8 at 1280x720: each target is at least 24x24 CSS px, or has the spacing the rule allows. e2e/panel.spec.js gains an axe scan of the compact window and the draft card at 1280x720 (setViewportSize inside the test; playwright.config.js is not changed) with the suite's WCAG_TAGS, and it passes
- L7 and L8: the voice component and the conversation use one fallback palette (the conversation's #0176d3 family, as CSS custom properties with the same fallbacks), and the mic's agentName default is empty with the label built so an empty name still reads well (e.g. 'Speak your question'); the conversation still passes its name
- Gates: npm run test:unit passes in full; npx eslint on the changed LWC files passes. Deploy the changed LWC bundles to agent-probe only: sf project deploy validate --source-dir <the changed bundles> --test-level RunLocalTests -o agent-probe, then CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o agent-probe. If the deploy hook refuses for want of a target org, set it worktree-local (sf config set target-org agent-probe) and unset it before hand-back. Then run npx playwright test e2e/panel.spec.js once against agent-probe and report its counts; a failure the change did not cause is reported, not fixed
- docs/research/fr2-panel-render-fixes.md (new) lists each fix with file and line, the e2e and Jest counts, what was not fixed and why, and an Undo list (the bundles to redeploy from the previous main commit)
- Nothing creates, edits or deletes a record beyond the product's own session and outcome rows the e2e suite already writes. No Id, job Id, username, email, hostname or local path is written to a committed file. e2e/.auth is never printed or committed. No screenshots are re-captured (a later card does that)
