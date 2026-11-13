---
id: FE-11
title: FR2: voice input component — customerSummaryVoiceInput, a mic toggle using the browser's speech recognition that fills the composer and never sends, with a typed fallback; Jest with a mocked recognizer
domain: frontend
tier: standard
tier_reason: one self-contained LWC from a written pattern, with Jest and a docs page
status: blocked
blocked_by: [BE-23, OPS-29]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryVoiceInput/**, docs/patterns/11-voice-input.md]
forbid: [force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/flexipages/**, force-app/main/default/applications/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: the new Jest suite for customerSummaryVoiceInput fails on main (the component does not exist) and passes after
resources: [org-live]
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2): "Sellers don't want to type". Every Customer Summary window gets a mic. Ben approved the browser's built-in speech recognition, following the reference pattern written up in docs/plans/fr2-design.md. The conversation component puts this in its composer. Covers ledger rows F13 and F14 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (the section 'Voice', and the 'Accessibility' bullet under 'Conversation design'), and docs/research/fr2-surfaces-spike.md (its mic findings). Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate and experience-lwc:experience-lwc-security-validate first
- A new LWC force-app/main/default/lwc/customerSummaryVoiceInput behaves exactly as fr2-design.md 'Voice' says: SpeechRecognition or webkitSpeechRecognition, continuous with interim results, language from the user's locale with en-US fallback, one toggle button (aria-label Talk or Stop, aria-pressed, a visible recording state), stop after 3 s of silence with the timer reset on each result, lowercase events transcriptupdate, transcriptfinal, recordingstate and voiceerror, a public start() and stop(), and stop on disconnect. It never sends anything itself
- Errors and support: 'not-allowed' gives '<agent name> needs microphone permission to listen.' (the agent name is an @api property with 'Customer Summary' as default); any other error gives 'Voice input had an issue. Try again or type instead.'; with no API the button is hidden and a short note says voice is not available in this browser. A polite live region announces when listening starts and stops
- Styling reads only the fr2-design.md CSS variables with neutral fallbacks; honours prefers-reduced-motion. Target is not exposed on any page by itself (no app or flexipage change)
- Jest with a mocked recognizer covers start, interim and final text, silence stop, manual stop, not-allowed, other errors, unsupported browser, disconnect, and zero accessibility violations. The component passes the LWS security validation skill with no blocked API
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Write docs/patterns/11-voice-input.md: what it does, browser support (Chrome and Edge full, Safari patchy, Firefox none), the privacy line (Chrome sends audio to Google to transcribe it), why it never auto-sends, how to test it by hand, and how a surface embeds it. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh (check-only) and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
