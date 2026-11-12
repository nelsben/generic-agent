---
id: BE-15
title: Stretch: the panel can ask the registered Account_Brief agent, through an Apex wrapper with a test seam
domain: backend
tier: frontier
tier_reason: new Apex to agent integration with a seam, plus panel state changes
status: blocked
blocked_by: [OPS-22]
fixes: []
scope: [force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, force-app/main/default/classes/AccountBriefAgentClient*.cls, force-app/main/default/classes/AccountBriefAgentClient*.cls-meta.xml, force-app/main/default/lwc/accountBriefPanel/**, e2e/panel.spec.js, e2e/support/panel.js]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, tests/**, scripts/**, docs/**, agents/**, .chassis-delegation.json, reference/**]
red_test: the new Apex wrapper tests and the new Jest tests for the agent round trip fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

Corrective plan step 5. Today the panel hands 'Ask the agent' off to the built-in panel. Calling the registered agent from the custom panel proves the panel and the agent are one product, and it is only possible once a version with the BE-11 script is active.

## Done when

- Read docs/plans/corrective-plan.md step 5, docs/research/agent-api.md, docs/research/agent-publish-spike.md and docs/patterns/03-hotkey-panel.md first. If the spike write-up says no version with the BE-11 script is active, stop and hand back
- AccountBriefPanelController gains an @AuraEnabled method that sends one user message to the registered agent with generateAiAgentResponse and returns the reply text and the session Id. It unwraps the {type, value} envelope, returns fixed plain-English text on failure, and has a test seam because the action cannot run in Apex tests. Apex tests cover the unwrap, the failure text and session reuse through the seam, with Assert.*
- The panel's 'Ask the agent' sends through that method, keeps the session Id for follow-ups in the same panel session, shows progress the screen reader announces during the 14 to 18 second wait, and applies latest-wins like other requests. Jest tests cover it, with zero accessibility violations. The existing brief, explore and drill paths do not change
- Add one Playwright spec for an agent round trip in e2e/panel.spec.js but do not run it (the org does not have this code)
- No invocable signature, label or description changes. Gates pass: python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh (check-only). Never deploy for real, publish, activate or install a plugin. Run Python with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/, git status --short is empty when you report
