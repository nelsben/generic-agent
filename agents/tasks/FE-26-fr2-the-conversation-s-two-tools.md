---
id: FE-26
title: FR2: the conversation's two tools headings stay readable at compact width — "Sections: all" and "Earlier summaries of <account> (n)" wrap instead of truncating
domain: frontend
tier: standard
tier_reason: swap two base-component sections for native disclosures with their tests; the method is decided in the card
status: queued
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryPanel/__tests__/customerSummaryPanel.test.js, e2e/**]
forbid: [force-app/main/default/lwc/customerSummaryCard/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/lwc/customerSummaryPanel/customerSummaryPanel.js, force-app/main/default/lwc/customerSummaryPanel/customerSummaryPanel.html, force-app/main/default/lwc/customerSummaryPanel/customerSummaryPanel.css, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, scripts/**, tests/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new Jest test that the two tools headings are native disclosures with no nowrap or text-overflow fails on main (they are lightning-accordion-section today) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

FE-12's capture showed the 'Earlier summaries of <account>' heading cut off with an ellipsis at the compact frame width. FE-22 made its new headings wrap, but left these two, because they are lightning-accordion-section labels: the truncation happens inside the base component, and customerSummaryPanel's Jest test pins their label values, which was outside FE-22's scope.

## Done when

- In force-app/main/default/lwc/customerSummaryConversation, the two tools headings (the include-sections section and the history section, today lightning-accordion-section with labels from includeSummary and historyLabel) are native disclosures: a button with aria-expanded and aria-controls naming its panel, the panel hidden when closed. Their text is unchanged ('Sections: all' or the current includeSummary value, and 'Earlier summaries of <account> (n)'). Both start closed, as today, and open and close by click, Enter and Space.
- At the compact frame width (320 px) each heading's full text is visible on screen, wrapping onto a second line when needed, with no ellipsis and no text-overflow clipping. A Jest test asserts that neither heading's CSS sets nowrap or text-overflow, and an e2e spec at 320 px asserts each heading's scrollWidth is no wider than its clientWidth.
- The answer sections inside each summary (the lightning-accordion at the turn level, with label={s.label}) are not changed.
- force-app/main/default/lwc/customerSummaryPanel/__tests__/customerSummaryPanel.test.js (lines near 502 and 860 today) reads the headings from the new markup and still asserts the same texts, the same order (Sections first, Earlier summaries second) and that both work. No other assertion in that file changes.
- Every existing Jest test passes, with only the edits these headings need; e2e/support/panel.js locators are updated if they found the headings through the accordion section.
- The conversation bundle is validated with RunLocalTests and quick deployed to agent-probe with CONFIRM_PROD=1, deploying only that bundle (--source-dir). The full Playwright suite runs once, and its summary line is in the hand-back. The live-checks row allows the run; record how many session and outcome rows it wrote.
- The brand colours, the card component (customerSummaryCard) and any Apex class are unchanged.
