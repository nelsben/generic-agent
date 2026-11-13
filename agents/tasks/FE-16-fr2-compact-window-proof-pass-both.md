---
id: FE-16
title: FR2: compact window proof pass — the dark theme and its contrast, and what a screen reader is given, proven in agent-probe, with a short VoiceOver script for Ben
domain: frontend
tier: standard
tier_reason: browser checks against a built surface, with a clear pass line for each; no product judgement
status: merged
fixes: []
scope: [e2e/**, docs/research/fr2-panel-proof.md, docs/assets/fr2-compact-dark*.png]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new e2e checks for the accessibility snapshot are missing on main and pass after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 03: "make sure limits and open items are covered". The page's "Not yet proven" list names the second hotkey branch (one run exercises only Cmd-K or only Ctrl-K), the dark theme and its contrast, and real screen-reader output; the live region has been checked in the page markup only. The non-admin run stays with FE-5. Covers ledger row F62 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md (rows F60 to F64), docs/plans/fr2-design.md ('Conversation design', 'Accessibility' and 'Theming'), docs/patterns/03-hotkey-panel.md (its Limits and open items), docs/reviews/lwc-review-2.md, docs/research/fr2-surfaces-spike.md (OPS-29) and the e2e suite as FE-13 left it. Load the skills experience-lwc:experience-accessibility-validate and experience-lwc:experience-lwc-accessibility-jest-run first
- **Dark theme:** find out whether agent-probe offers a dark theme for Lightning. If it does, capture docs/assets/fr2-compact-dark.png at 1440x900 through e2e/capture/kit.js with an answer showing and run axe colour-contrast on the open window (zero violations). If it does not, say so in the research page with the source, and check the brand colours on the light theme instead
- **What a screen reader is given:** a Playwright accessibility snapshot of the window closed, open, pending, answered and in error. Each check asserts the window's accessible name, the composer's label, the live region's text at each step and the focus target after Esc. Write a VoiceOver script of about five steps in docs/research/fr2-panel-proof.md for Ben to run by hand, with what he should hear at each step; automated browsers cannot hear a screen reader
- **What FE-13 left (merged after this card was cut):** the launcher and the window are a stage mounted on document.body, and the window is a non-modal `<dialog>` opened with show(). The page's synthetic shadow DOM hides the stage from document.querySelectorAll, so AxeBuilder's include selectors find nothing: run axe the way spec 8 in e2e/panel.spec.js does, on the stage element itself, with the direct devDependency axe-core. Do not import @axe-core/playwright and do not edit package.json. Find the stage through the helpers in e2e/support/panel.js. The e2e axe scan covers the stage only; the note in the utility item's own panel is covered by Jest. Before brand settings load, the window's name falls back to "Assistant" and the launcher to "Ask the assistant": assert the branded name after load and say in the page whether a screen reader can hear the fallback
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-panel-proof.md records each check, the result and what remains unproven. No deploy. Writes only the product's own session rows. The two hotkey branches are FE-21's. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken), and the e2e suite passes (the count noted). Paste the Playwright summary line in the hand-back. No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt (d49c5ad). The verifier found the report consistent and returned next=accept; no separate reviewer ran. The brain read the whole research page and the diff stat (3 files, 345 added lines).

Findings:
- New e2e specs 11 to 13 (e2e/a11y-snapshot.spec.js): an accessibility snapshot of the stage closed, open, pending, answered and in error, each asserting the window's name ("Customer Summary"), the composer's label and the live region's text, and focus returning to the element the hotkey was pressed on after Esc; the fallback names measured before the brand loads (about 220 ms, never in the live region); and axe color-contrast on the open window with an answer showing (0 violations, 2 incomplete). axe runs on the stage element with the direct axe-core dependency, as spec 8 does; package.json is unchanged.
- Pending and error states are made in the browser (a held and an aborted resolve request), so no org change.
- docs/research/fr2-panel-proof.md records each check, the computed brand-colour ratios (the primary is 4.63:1, close to the 4.5 limit), the five-step VoiceOver script for Ben and the "Not yet proven" list. e2e/README.md lists the three specs.

Dark theme: agent-probe (Developer Edition) offers none: Setup Quick Find and the profile menu show no theme setting. docs/assets/fr2-compact-dark.png was not captured, and dark-theme contrast stays unproven, as the card allows.

Live check (approved live-checks row, seed account Edge Communications): no model call, 0 session rows written (5 before and after), no outcome object in the org. No deploy.

Disclosed and accepted:
- The full e2e run had one failure in existing spec 7 (a focus wait timing out); it passed alone. Flaky, not touched.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- On a failed request the live region speaks the platform's text ("Disconnected or Canceled"), not the panel's fixed sentence, because errorText returns error.body.message when present. A force-app change; cut as a follow-up.
- The primary colour is 0.13 above the contrast limit; the brand swap guide should say to keep it at 4.5:1 against white.
- Real screen-reader output waits on Ben's VoiceOver run.

Privacy grep over the diff (345 added lines): 0 hits.
