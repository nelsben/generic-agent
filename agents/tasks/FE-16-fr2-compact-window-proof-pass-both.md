---
id: FE-16
title: FR2: compact window proof pass — both hotkey branches, the dark theme and its contrast, and what a screen reader is given, proven in agent-probe, with a short VoiceOver script for Ben
domain: frontend
tier: standard
tier_reason: browser checks against a built surface, with a clear pass line for each; no product judgement
status: blocked
blocked_by: [FE-13]
fixes: []
scope: [e2e/**, docs/research/fr2-panel-proof.md, docs/assets/fr2-compact-dark*.png]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new e2e checks for the Ctrl-K branch and the accessibility snapshot fail or are missing on main and pass after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 03: "make sure limits and open items are covered". The page's "Not yet proven" list names the second hotkey branch (one run exercises only Cmd-K or only Ctrl-K), the dark theme and its contrast, and real screen-reader output; the live region has been checked in the page markup only. The non-admin run stays with FE-5. Covers ledger row F62 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F60 to F64), docs/plans/fr2-design.md ('Conversation design', 'Accessibility' and 'Theming'), docs/patterns/03-hotkey-panel.md (its Limits and open items), docs/reviews/lwc-review-2.md, docs/research/fr2-surfaces-spike.md (OPS-29) and the e2e suite as FE-13 left it. Load the skills experience-lwc:experience-accessibility-validate and experience-lwc:experience-lwc-accessibility-jest-run first
- **Both hotkey branches:** Playwright runs the open, ask and Esc path twice in agent-probe: once as a Mac (Cmd-K) and once as Windows or Linux (Ctrl-K, set through the browser context's user agent and platform), and checks that on a Mac Ctrl-K inside a text field is left alone. Both pass
- **Dark theme:** find out whether agent-probe offers a dark theme for Lightning. If it does, capture docs/assets/fr2-compact-dark.png at 1440x900 with an answer showing and run axe colour-contrast on the open window (zero violations). If it does not, say so in the research page with the source, and check the brand colours on the light theme instead
- **What a screen reader is given:** a Playwright accessibility snapshot of the window closed, open, pending, answered and in error. Each check asserts the window's accessible name, the composer's label, the live region's text at each step and the focus target after Esc. Write a VoiceOver script of about five steps in docs/research/fr2-panel-proof.md for Ben to run by hand, with what he should hear at each step; automated browsers cannot hear a screen reader
- docs/research/fr2-panel-proof.md records each check, the result and what remains unproven. Read-only against the org: no deploy, no data change. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken), and the e2e suite passes (the count noted). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
