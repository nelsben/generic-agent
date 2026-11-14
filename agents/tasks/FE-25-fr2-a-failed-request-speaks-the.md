---
id: FE-25
title: FR2: a failed request speaks the panel's own fixed sentence in the live region, never the platform's raw error text
domain: frontend
tier: standard
tier_reason: one function in one component with a named red test
status: merged
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, docs/research/fr2-panel-proof.md]
forbid: [force-app/main/default/classes/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json, package.json]
resources: [org-live]
red_test: a new Jest case in customerSummaryConversation's tests rejects the Apex call with body.message 'Disconnected or Canceled' and asserts the live region and error turn show the fixed sentence; it fails on main and passes after
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

FE-16's proof pass found that when a panel request fails, the live region (what a screen reader hears) says the platform's own text, such as "Disconnected or Canceled", because errorText in customerSummaryConversation.js returns error.body.message whenever one exists. The design says a failure reads one fixed, plain sentence; raw platform or Apex messages should not reach a rep.

## Done when

- Read first: docs/research/fr2-panel-proof.md (FE-16, 'Finding for the panel's owner'), docs/plans/fr2-design.md ('Conversation design' and 'Accessibility') and customerSummaryConversation as FE-22 left it. Load the skills experience-lwc:experience-lwc-generate and experience-lwc:experience-lwc-accessibility-jest-run first
- A failed Apex call (a thrown AuraHandledException, a network abort, or any error object) shows and announces the panel's one fixed error sentence. Keep the exact sentence the component already uses for errors; do not invent a new one. If some Apex message is deliberately meant for the rep (look at what the Apex controllers throw on purpose), keep that path and say in the hand-back which messages pass through and why; everything else gets the fixed sentence
- The live region and the on-screen error turn say the same text
- Red test: a new Jest case that rejects the Apex call with an error whose body.message is 'Disconnected or Canceled' asserts the live region and the error turn show the fixed sentence; it fails on main and passes after. Existing Jest tests keep passing
- docs/research/fr2-panel-proof.md's finding is marked fixed by this card, in one line
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, naming only the changed LWC bundle (never all of force-app). Wait for each org job in the foreground, in waits under 10 minutes. Never publish or activate an agent, never create a user, never touch experimental
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No Ids, usernames, emails or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). One attempt (3b843d6, $0.33). The verifier found the report consistent and returned next=accept with no reviewer pass. The brain read the diff (18 added lines) and the code paths it relies on.

Findings:
- errorText() in customerSummaryConversation.js now always returns ERROR_TEXT ("I couldn't finish that right now. Try again in a minute."). A platform rejection such as "Disconnected or Canceled" no longer reaches the live region or the error turn.
- New Jest case rejects explore with { body: { message: 'Disconnected or Canceled' } } and checks the live region, the error turn and that the platform text appears nowhere in the component.
- docs/research/fr2-panel-proof.md gains one line under the finding: fixed by FE-25.
- Brain check of "no message passes through": the conversation component calls CustomerSummaryPanelController (resolve, getBrief, explore, drill, history, sources) and CustomerSummaryHistory (listSessions, getSession). The controller's only non-fixed text is drill's ExploreException message, and _drill's onError already ignored the text and showed ERROR_TEXT. The session open's onError shows its own SESSION_FAILED line. CustomerSummaryHistory throws ERROR_TEXT. So the only change to what a rep sees is that platform text is now replaced.

Gate (worker at 3b843d6): Python 216 tests, Jest 265, validate-org pass, check-docs 0 broken. The verifier confirmed the gate.

Org (worker's account), under the standing deploy row: a validate with RunLocalTests of the customerSummaryConversation bundle (518 tests, 0 errors), then a CONFIRM_PROD=1 quick deploy. The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook, then unset.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- validate-org ran over 2 minutes and was moved to the background by the harness; it finished green.

Still open:
- The VoiceOver run of the panel (fr2-panel-proof.md) is still Ben's.

Privacy grep over the diff (18 added lines): 0 hits.
