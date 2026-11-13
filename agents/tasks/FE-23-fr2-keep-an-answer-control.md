---
id: FE-23
title: FR2 (PARKED until Ben picks it from FE-17's list): a control that keeps an answer — one 'Keep' control on an answer writes a Saved answer outcome against the account, and only its author sees the text
domain: frontend
tier: standard
tier_reason: one control and one controller method on parts that already exist
status: parked
blocked_by: [FE-22, BE-35]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls, e2e/**]
forbid: [force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, agents/**, docs/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest tests for the Keep control, and a new CustomerSummaryPanelControllerTest case for saving an answer, fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2): the customer outcome store (BE-35) has three types, a summary, an action taken and "an answer a rep saves" (design principle 4, ledger F75 and F78), but no card built the control that saves one (findings 34 and 63 in docs/reviews/fr2-plan-review.md). The brain kept the type and parked the control, because Ben did not ask for it by name: FE-17 lists it among what the panel could add later, and Ben picks from that list.

## Done when

- PARKED: do not dispatch until Ben picks this item from FE-17's list (docs/research/fr2-panel-later.md) in chat. Read first: docs/plans/fr2-design.md (principles 4 and 5), docs/research/fr2-customer-outcomes.md (BE-35: the record method, the Saved answer type and who sees what), docs/research/fr2-card-contract-apex.md (BE-39) and the conversation component as FE-22 left it. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, salesforce-development:platform-apex-generate and salesforce-development:platform-metadata-deploy first
- One 'Keep' control on each finished answer that has an account. Pressing it writes one Saved answer outcome on that account through CustomerOutcomes.record (BE-35) with the question, the answer's plain text and its cards if the store keeps them. If the panel controller has no method for this, add one @AuraEnabled method that only passes through to CustomerOutcomes.record with the Saved answer type; add no other Apex. The control then reads 'Kept' and is disabled, so a second press writes nothing. A failed save shows one plain sentence and leaves the control ready to press again
- Only the author sees a kept answer's text; anyone else who can see the account sees its type and date, as BE-35 built it. This card changes no access rule and no field permission. FE-12's public interface and every existing Jest test stay as they are. An answer with no account shows no control
- Tests: Jest for the control (shown, hidden with no account, one write on two presses, the failure sentence, zero jest-axe violations) and one Apex test for the new method (it writes one Saved answer outcome as the running user, and a user who cannot see the account is refused). **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote. One e2e spec keeps an answer and removes the outcome row it wrote in teardown; it is written and run when the row is approved, and written but not run when it is not
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only, under the standing row "Production-classified deploys to `agent-probe`": validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/validate-org.sh. No tests/__pycache__, and git status --short is empty after the commit
