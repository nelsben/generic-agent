---
id: FE-12
title: FR2: the shared conversation core — customerSummaryConversation renders the Claude-like thread, composer with mic, quick-action chips, inline cards and history, themed by brand settings; the compact panel uses it
domain: frontend
tier: frontier
tier_reason: moves the live panel's logic into a new shared component every later surface depends on
status: blocked
blocked_by: [OPS-30, BE-24, FE-11, BE-26, FE-18]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryPanel/**, e2e/**, docs/patterns/03-hotkey-panel.md, docs/assets/fr2-conversation-core.png]
forbid: [force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest suite for customerSummaryConversation fails on main (the component does not exist) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2): every surface has voice, typing, quick actions and history, and should "feel more like Claude" instead of "really condensed". One component holds the conversation so the compact window, the rail and later the embedded surface differ only in their frame. Covers ledger rows F09, F12, F13, F19, F22 and F27 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (all of 'Conversation design', 'Theming' and 'Gotchas'), docs/patterns/03-hotkey-panel.md, docs/patterns/11-voice-input.md, docs/patterns/05-conversation-memory.md and docs/patterns/10-brand-and-theming.md. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-metadata-deploy first
- A new LWC customerSummaryConversation takes the record context and brand values as @api properties and owns: the thread (turn layout, type, labels, pending pulse, error turn, auto-scroll exactly as fr2-design.md says), rich text by runs with no lwc:inner-html, inline cards (summary sections, explorer table with 'Showing 50 of N rows', collapsible query trail, follow-up chips, and a slot or typed field for action drafts and results so ACT-UI can add them), the empty state naming the account, the composer (multi-line to about 6 lines, Enter sends, Shift-Enter new line, stopPropagation on keys, min-width 0) with customerSummaryVoiceInput on its row, and the quick-action chips from fr2-design.md that change on and off an account
- History: a sessions control lists the user's past sessions for this account (from CustomerSummaryHistory) and reopens one into the thread; a new-conversation button starts fresh. It calls the existing ask, explorer and agent paths through the panel's current Apex; no Apex changes in this card
- customerSummaryPanel keeps its frame, hotkey, position and ids that the e2e tests use, and delegates the whole conversation to the new component; every existing panel Jest test passes or is moved to the new component with the same assertions. All colours, fonts and radius come from the --cs-* variables set from BrandSettings; no hard-coded brand value. prefers-reduced-motion turns motion off
- Scope is visible (ledger F58, panel N3 in docs/reviews/lwc-review-2.md): when a question will be tied to the summarized account, a small chip above the composer says so ("About <Account>") with a control to ask org-wide instead; Jest covers both
- Panel limits from pattern 03 (ledger F62; docs/reviews/lwc-review-2.md: N5, N9, and row 6 of its table of first-review items): a result table or list is one Tab stop, with the arrow keys moving inside it (roving tabindex), not one stop per row; drill lines and other small buttons meet the WCAG 2.2 target size (at least 24 by 24 px, or spaced so a 24 px circle on each does not overlap a neighbour); Esc while an IME composition is open ends the composition only and does not close the surface. Jest covers all three
- **An Id-shaped number is not a drill (docs/reviews/lwc-review-2.md N2, ledger F87):** a number in a line that looks like a record Id but is not one never becomes a drill button, and a drill that fails shows the fixed sentence, never platform text; Jest covers both
- **Cards and rich text (ledger F65):** the thread renders answers through the card contract and card catalog in docs/research/fr2-card-architecture.md (FE-18), with the rich-text subset it defines; any card type FE-18 proposed for a later card is left out and named in the hand-back
- Jest covers turns, pending and error states, rich-text runs, chips on and off an account, Enter and Shift-Enter, the transcript filling the composer without sending, history list and reopen, and zero jest-axe violations; the LWS validation skill reports no blocked API. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1; run the full e2e suite (all pass, the count noted) and capture docs/assets/fr2-conversation-core.png at 1440x900 on an account page. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
