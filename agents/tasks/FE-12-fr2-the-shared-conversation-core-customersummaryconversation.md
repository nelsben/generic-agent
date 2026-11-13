---
id: FE-12
title: FR2: the shared conversation core — customerSummaryConversation renders the Claude-like thread, the composer with mic and the quick-action chips, themed by brand settings, with a stated public interface; the compact panel uses it; history, the scope chip and the card contract follow in FE-22
domain: frontend
tier: frontier
tier_reason: moves the live panel's logic into a new shared component every later surface depends on
status: merged
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryPanel/**, e2e/**, docs/assets/fr2-conversation-core.png]
forbid: [force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest suite for customerSummaryConversation fails on main (the component does not exist) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): every surface has voice, typing, quick actions and history, and should "feel more like Claude" instead of "really condensed". One component holds the conversation so the compact window, the rail and later the embedded surface differ only in their frame. Covers ledger rows F09, F12, F13, F19, F22 and F27 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (all of 'Conversation design', 'Theming' and 'Gotchas'), docs/patterns/03-hotkey-panel.md, docs/patterns/11-voice-input.md, docs/patterns/05-conversation-memory.md and docs/patterns/10-brand-and-theming.md. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-metadata-deploy first
- A new LWC customerSummaryConversation takes the record context and brand values as @api properties and owns: the thread (turn layout, type, labels, pending pulse, error turn, auto-scroll exactly as fr2-design.md says), rich text by runs with no lwc:inner-html, inline cards (summary sections, explorer table with 'Showing 50 of N rows', collapsible query trail, follow-up chips, and a typed field for action drafts and results, which FE-14 fills), the empty state naming the account, the composer (multi-line to about 6 lines, Enter sends, Shift-Enter new line, stopPropagation on keys, min-width 0) with customerSummaryVoiceInput on its row, and the quick-action chips from fr2-design.md that change on and off an account. FE-14 adds the action chips ('Create a follow-up', 'Log a call'); until then they stay hidden behind a flag that is off. The brand logo shows in the header beside the agent name, and nothing shows when no logo is set. The public interface is written at the top of the component's JavaScript file and tested, because FE-13 and FE-15 build on it and may not edit this folder, and FE-22, FE-14 and FE-23, which extend the component, must keep it: `@api recordId`, `@api sessionId`, `@api focusComposer()` and the event `sessionchange` (fired with the session id whenever it changes)
- It calls the existing ask and explorer paths through the panel's current Apex; no Apex changes in this card. The sessions control and reopening a past session, the scope chip, and rendering through the card contract are FE-22's, not this card's
- customerSummaryPanel keeps its frame, hotkey, position and ids that the e2e tests use, and delegates the whole conversation to the new component; every existing panel Jest test passes or is moved to the new component with the same assertions. All colours, fonts and radius come from the --cs-* variables set from BrandSettings; no hard-coded brand value. prefers-reduced-motion turns motion off
- Panel limits from pattern 03 (ledger F62; docs/reviews/lwc-review-2.md: N5, N9, and row 6 of its table of first-review items): a result table or list is one Tab stop, with the arrow keys moving inside it (roving tabindex), not one stop per row; drill lines and other small buttons meet the WCAG 2.2 target size (at least 24 by 24 px, or spaced so a 24 px circle on each does not overlap a neighbour); Esc while an IME composition is open ends the composition only and does not close the surface. Jest covers all three
- **An Id-shaped number is not a drill (docs/reviews/lwc-review-2.md N2, ledger F87):** a number in a line that looks like a record Id but is not one never becomes a drill button, and a drill that fails shows the fixed sentence, never platform text; Jest covers both
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- **What BE-24 and FE-11 left (merged after this card was cut):** BE-24's panel reads BrandSettings.getSettings, sets the seven --cs-* variables on its host, puts the logo and agent name at the start of the existing bar row (shown once the brand loads) and names the company in the empty state; its 8 brand Jest tests pass unchanged, or move with the code they test, keeping the same assertions. Keep the logo and name in the bar row, and do not add a second header showing them. FE-11's customerSummaryVoiceInput is the mic: wire its transcriptupdate and transcriptfinal events into the composer text, pass the brand's agent name to its agentName property, and do not edit its folder. Inside the panel the host's --cs-radius (0.25rem) reaches the mic button. If the design keeps the mic round, set --cs-radius: 50% on the c-customer-summary-voice-input element in the conversation's own CSS. The variable inherits through the shadow boundary, and the mic's folder stays untouched
- **First-run pop-up (OPS-30):** e2e spec 2 failed once on focus while a docked "Welcome to Data Cloud!" pop-up was open (docs/research/fr2-rename-org.md, "e2e"). Make the e2e support close that pop-up when it is shown, the way it already dismisses the Guidance Center walkthrough, and change no spec's assertions to get past it
- Jest covers turns, pending and error states, rich-text runs, chips on and off an account, Enter and Shift-Enter, the transcript filling the composer without sending, each part of the public interface, the action chips hidden while the flag is off, and zero jest-axe violations; the LWS validation skill reports no blocked API. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1; run the full e2e suite (all pass, the count noted). Paste the Playwright summary line in the hand-back. Capture docs/assets/fr2-conversation-core.png at 1440x900 on an account page. Every still and GIF is taken through e2e/capture/kit.js. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-12). Three attempts; the brain raised the budget from 2 to 3 for the last one (the brief records 3-attempts).

Attempt 1: scope refuted on tests/test_brand_settings.py (the theme test now reads the conversation bundle too). The brain read the diff and granted the amend. Attempt 2 (re-emitted hand-back at 71d06da): 27 confirmed, 1 refuted, 4 unverifiable. The refuted row was a hard-coded 6px radius on .abp-suggestion.

Attempt 3 (3fb4981) fixed that row and the three cosmetic flaws seen in the capture:
- the suggestion radius reads --cs-radius, and a Jest source check enforces it;
- the placeholder "Ask or /brief an account" fits on one line;
- the disabled Send drops the brand fill;
- the header button shows "Summarize", with the account in its aria-label and title.
Review: 23 confirmed, 0 refuted, 4 unverifiable. The brain read the attempt-3 diff and viewed the recaptured docs/assets/fr2-conversation-core.png: all four flaws are gone, sample data only, owner and emails masked.

Disclosed and accepted:
- The panel spinner assertions now target the kept data-testid="abp-spinner", because the pending pulse replaces lightning-spinner.
- The focus assertions read the conversation's shadow root.
- ask() and the Enter test type into the native textarea.
- The Summarize assertions read aria-label.

Org: validate RunLocalTests 260/260 and quick deploy succeeded (agent-probe). e2e: 8 passed (2.6m). Evidence is in .delegation/FE-12/org-3.txt and e2e-3.txt, counts only.

Still open:
- The Data Cloud pop-up handler has never run against a real pop-up.
- The action-draft/result turn has markup but no caller, and its only test reads the source: FE-14 must test it rendered.
- The accessibility matcher is @sa11y/jest (axe-core).
- The LWS review was a pattern grep, not the skill's report.

Privacy grep over the full diff: 0 hits besides 5 synthetic Jest Ids.

Seen in the capture, for a later conversation card:
- the empty state says "Your Company's data" (the default brand company name);
- "Earlier summaries of Edge …" truncates at 340px;
- "Customer Summary" shows in both the utility header and the brand row.
