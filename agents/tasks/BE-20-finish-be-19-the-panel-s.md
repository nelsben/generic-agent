---
id: BE-20
title: Finish BE-19: the panel's "Ask the agent" calls the Account_Brief agent directly in agent-probe, from the stopped attempt's work (Jest 50/50 done); deploy, e2e, docs and asset
domain: backend
tier: frontier
tier_reason: live deploy, e2e and agent spec in the org plus recapture, continuing Apex-to-agent work with a seam
status: queued
fixes: []
scope: [force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, force-app/main/default/classes/AccountBriefAgentClient.cls, force-app/main/default/classes/AccountBriefAgentClient.cls-meta.xml, force-app/main/default/classes/AccountBriefAgentClientTest.cls, force-app/main/default/classes/AccountBriefAgentClientTest.cls-meta.xml, force-app/main/default/lwc/accountBriefPanel/**, force-app/main/default/permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml, e2e/panel.spec.js, e2e/support/**, e2e/capture/**, e2e/README.md, docs/assets/**, docs/patterns/03-hotkey-panel.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/research/panel-agent-1.md, README.md, tests/**]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/staticresources/**, force-app/main/default/permissionsetgroups/**, data/**, agents/**, docs/plans/**, docs/reviews/**, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new Playwright agent round-trip step in e2e/panel.spec.js fails against main's panel in agent-probe (the button hands off to the built-in panel) and passes after the deploy; the new Apex and Jest tests from the work in progress fail on main and pass
gate: test, jest, org
budget: 2-attempts
spend: 35
---
## Why

BE-19's worker was stopped by an interrupt after the probe, the red tests, the Apex client and the LWC change (Jest 50/50), just before the org validate. The mod cannot resume it (its ledger marks the stopped attempt live and its unchanged branch as merged), so this card continues the same work from the committed work-in-progress. Ben confirmed the panel should call the agent directly and that this card should finish now, with a light touch on the panel because a redesign follows.

## Done when

- Start from the work-in-progress commit this worktree is cut from (BE-19's stopped attempt). Read agents/tasks/BE-19-the-panel-s-ask-the-agent.md: its Done when is this card's Done when, with the changes below. Read .delegation/BE-19/red-1.txt if present, git log -1 and git show --stat first; build on that work, do not start over. Load the skills that card names before writing code or running sf commands
- Re-check the work in progress against BE-19's Apex, LWC and permissions lines; finish what is missing. Before deploying, re-run the probe once (one generateAiAgentResponse call plus one session-reuse call as the signed-in admin through anonymous Apex) and record the result shape, timing and permission in docs/research/panel-agent-1.md; if it fails, stop and hand back gate=fail with the evidence
- Light touch on the panel: the LWC change is limited to the direct agent call, the multi-turn session, the screen-reader progress state and latest-wins. No layout, position, size or styling changes, because a redesign follows
- Org, agent-probe only, under the Approvals lines 'The panel calls the registered agent directly' and 'Production-classified deploys to agent-probe ... standing': validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental
- e2e, agent spec, docs and asset exactly as BE-19's Done when says: red then green agent round-trip step, npm run test:e2e 9 of 9, the Account_Brief agent spec once after e2e (16 of 16 replies and actions), README.md and patterns 03 and 06 describe the direct call with the sequence diagram updated, new docs/assets/panel-ask-agent.png (or GIF) read by eye, MANIFEST.md rows and alt text updated, every other asset byte-identical unless it shows the hand-off
- No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings in any file or image. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
