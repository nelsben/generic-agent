---
id: FE-13
title: FR2: the compact window — moves to the corner the surface spike picked, gains a launcher that shows Cmd/Ctrl-K, minimize, an expand button to the rail, and the sheet motion; pattern 03 updated
domain: frontend
tier: frontier
tier_reason: changes the live panel's position, hotkey handling and utility-bar setup, with e2e and captures
status: blocked
blocked_by: [FE-12]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/flexipages/**, force-app/main/default/applications/**, force-app/main/default/messageChannels/**, e2e/**, docs/patterns/03-hotkey-panel.md, docs/assets/fr2-compact-*.png, tests/test_app.py]
forbid: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest cases for the launcher key hint, minimize and expand fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): Ben keeps the compact agent as one surface, wants it opened by "a highlighted command K key", moved off the bottom left without fighting a CTI softphone, and able to "pop out with a button click to take up a larger part of the screen" with slide in and out. Covers ledger rows F20, F21, F22 (the compact frame), F23, F24 (the compact half), F31 and F35 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md ('Surfaces', 'Motion', 'Accessibility'), docs/research/fr2-surfaces-spike.md (corner, hotkeys, utility bar findings) and docs/patterns/03-hotkey-panel.md. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, salesforce-development:platform-flexipage-generate and salesforce-development:platform-metadata-deploy first
- The compact window sits in the corner and utility-bar position the spike recommended, about 420 px wide, and opens on the hotkey docs/research/fr2-surfaces-spike.md recommends, Cmd/Ctrl-K unless the spike found a clash (document listener that yields when defaultPrevented; Esc closes; focus moves in and back). A launcher button shows the agent name from brand settings and a visible key hint for that key ('⌘K' on Mac, 'Ctrl K' elsewhere, when the key is K) and scales away as the sheet opens
- A minimize control collapses it to the launcher and keeps the conversation; an expand control fires an event (and an LMS message if the spike says the rail lives in another component) carrying the current session so the rail opens on the same thread. Until the rail card lands, expand is hidden behind an @api flag so no dead button ships
- Panel limits from pattern 03 (ledger F62): **N4** in docs/reviews/lwc-review-2.md: Esc returns focus to where it was from at least three starting points (the global search button, a field inside another component on the record page, and the launcher), and when that element is gone it falls back to the launcher, never the page body; Playwright proves each. **14f** in the same review's table of first-review items: the Lightning app shows a brand block (the logo and agent name from brand settings) where the platform allows it; if it does not, say so and show the brand in the launcher only
- Motion per fr2-design.md: the sheet slides with cubic-bezier(0.32, 0.72, 0, 1) at about 280 ms and reduced motion turns it off. Opening the compact window takes under 300 ms to first paint in Playwright with a warm cache; record the measured number
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Jest covers the hotkey (and that it yields when another handler prevented default), the key hint per platform, minimize keeps the thread, expand event payload, Esc and focus return, and zero jest-axe violations. e2e: the existing panel tests updated for the new corner and launcher; all pass. Paste the Playwright summary line in the hand-back. tests/test_app.py follows any change to the app or its utility bar. Update docs/patterns/03-hotkey-panel.md (corner and why, hotkeys and why they are free on Chrome for Mac, launcher, minimize, expand). Capture docs/assets/fr2-compact-open.png and docs/assets/fr2-compact-launcher.png at 1440x900. Every still and GIF is taken through e2e/capture/kit.js. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
