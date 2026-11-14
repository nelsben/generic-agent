---
id: FE-26
title: FR2: the conversation's two tools headings stay readable at compact width — "Sections: all" and "Earlier summaries of <account> (n)" wrap instead of truncating
domain: frontend
tier: standard
tier_reason: swap two base-component sections for native disclosures with their tests; the method is decided in the card
status: merged
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

## Review

Brain review (2026-11-14). One attempt (6d9709c, $0.52). The chassis-delegation mod dropped out of the session as the worker handed back, so no verifier ran then. After a window reload the brain ran dispatch verify on the same sha: the verifier found the report consistent (branch, sha, scope, files, gate and red all held) and returned next=accept with no reviewer pass. The brain read the diff (132 added lines).

Findings:
- The conversation's two tools headings, "Sections: ..." and "Earlier summaries of <account> (n)", are native disclosures instead of lightning-accordion-section labels: a button.abp-tool-toggle with aria-expanded and aria-controls naming a hidden panel, and a chevron icon (right when closed, down when open, like the existing "Full summary" toggle).
- Both start closed. The toggle's CSS sets white-space: normal and overflow-wrap: anywhere, with no nowrap, text-overflow or slds-truncate, so the text wraps at compact width.
- The turn-level accordions (label={s.label}), the card component, Apex and the brand colours are unchanged.
- customerSummaryPanel.test.js reads the headings from the new buttons; the texts, order and the "Sections: Open deals" check are asserted as before.
- The Fr2 Jest file replaces the old "label is on the section" test with three: the history disclosure's aria wiring, closed start and toggle; the Sections toggle; and a source check that both are buttons and the CSS never truncates.
- New e2e spec FR2 4 sets a 320 px viewport and asserts each heading's scrollWidth is no wider than its clientWidth and has no ellipsis.

Gate (verifier at 6d9709c): pass. Worker: Jest 311, Python 242 (2 skipped), validate-org pass (148 components, 425 tests).

Org (worker's account), under the standing deploy row: a validate with RunLocalTests of the conversation bundle (518 tests, 0 errors), then a CONFIRM_PROD=1 quick deploy. The worktree's target-org was set for the deploy hook, then unset.

E2E (worker's account): the full Playwright suite, one run, 34 passed and 1 skipped, including FR2 4.

Disclosed and accepted:
- The worker did not count the session and outcome rows the suite wrote: a hook blocked its raw SOQL query. The suite's model calls (FR2 1 and 3) and the brief write the account's session row as before.
- The panel ids are static (abp-tool-include, abp-tool-history). LWC scopes template ids and the matching aria-controls together, and there is one conversation instance, so they cannot collide.

Still open:
- None from this card. FE-27 (View record in the body-mounted stage) is next on this component.

Privacy check over the full branch diff: 0 denylist hits, no URLs, Ids, local paths or job Ids.
