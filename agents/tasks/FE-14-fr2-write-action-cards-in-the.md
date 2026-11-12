---
id: FE-14
title: FR2: write-action cards in the conversation — draft card with Confirm, Edit and Cancel, result card with a link, action chips and voice that lead to a draft; e2e creates and removes its own task
domain: frontend
tier: frontier
tier_reason: first UI that writes records in a live org, with an e2e that creates and removes data
status: blocked
blocked_by: [BE-27, FE-12]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryActionCard/**, e2e/**, docs/assets/fr2-action-*.png]
forbid: [force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest cases for the draft and result cards fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2): sellers "create follow-up tasks, events" by voice or chat, and nothing is written until they confirm. This puts the action service (BE-27) into the shared conversation so every surface gets it. Covers ledger rows F15, F16, F18 and F27 (the action half) in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md ('Write actions', 'Cards inline'), docs/patterns/13-write-actions.md and the customerSummaryConversation component. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate and salesforce-development:platform-metadata-deploy first
- A typed or spoken request that names an action (for example 'create a follow-up for next Tuesday', 'log a call with Maria'), or a chip ('Create a follow-up', 'Log a call'), calls draftFromText (typed or spoken) or draftAction (chip) and shows a draft card; a 'not an action' result goes down the normal ask path. The draft card appears inside the agent turn with: the action, the target account, each field with its label and an editable value, any warnings, and Confirm, Edit and Cancel. Missing fields are highlighted and Confirm stays disabled until they are filled. Nothing is written before Confirm
- Confirm calls commitAction once (the button disables while it runs), then a result card shows what was written with a link to the record; a refusal or failure shows the plain-English error turn. Where the service supports it, updates offer Undo for 15 seconds. Each card reads only the --cs-* variables
- Jest covers draft rendering, editing a field, missing-field blocking, Cancel, Confirm calling commit once, the result card, the error path, and zero jest-axe violations. e2e in agent-probe: one test drafts and confirms a task on a test account, checks the result card and the record, then deletes that task in teardown; it never touches records it did not create. Capture docs/assets/fr2-action-draft.png and docs/assets/fr2-action-result.png at 1440x900
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
