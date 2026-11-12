---
id: OPS-28
title: The README quick-start runs end to end in a brand-new scratch org from my-devhub, followed literally, with every deviation recorded and fixed in the README
domain: ops
tier: frontier
tier_reason: a new org created and driven end to end through deploy, publish, activate, access and e2e with judgement on each deviati
status: blocked
blocked_by: [OPS-36]
scope: [config/project-scratch-def.json, README.md, docs/research/fresh-org-run.md, docs/research/org-migration.md, e2e/README.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/panel.spec.js, e2e/support/**, e2e/capture/**, docs/assets/**, docs/patterns/**, docs/plans/**, agents/**, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (docs and config): the evidence is the run log in docs/research/fresh-org-run.md; before the run the README proof table says the clean install is not fully proven
gate: test
budget: 2-attempts
spend: 30
---
## Waits for the FR2 README (2026-11-12)

Re-blocked on OPS-36 so the new-org run tests the README people will actually use after feature revision 2. Every Account Brief name in this card reads as its Customer Summary name after BE-23.

## Why

The README's clean-install row says "Not fully proven": main was stood up in agent-probe, but the README steps as written were never run end to end in a new org. Ben approved a scratch org from my-devhub now, and later a Developer Edition org he signs up for. A reader who copies the steps must land on a working panel and agent, and a reader with a Dev Hub should get a scratch-org path.

## Done when

- Read first: README.md 'See it in 5 minutes' and its proof table, docs/research/org-migration.md, e2e/README.md, docs/plans/gtm-burn-plan.md section 'Approvals' (line 'Run the README quick-start end to end in a brand-new org'). Load the skills salesforce-development:dx-org-manage, salesforce-development:platform-metadata-deploy, salesforce-development:platform-data-manage and agentforce-adlc:agentforce-generate before any sf command
- Org, new scratch org only: check my-devhub's scratch capacity first (sf org list limits -o my-devhub: ActiveScratchOrgs and DailyScratchOrgs remaining; if either is 0, stop and hand back). Create config/project-scratch-def.json with edition Developer, features EnableSetPasswordInApi and Einstein1AIPlatform, and settings lightningExperienceSettings.enableS1DesktopEnabled=true, agentPlatformSettings.enableAgentPlatform=true and einsteinGptSettings.enableEinsteinGptPlatform=true. Create the org with sf org create scratch --definition-file config/project-scratch-def.json --target-dev-hub my-devhub --alias ga-scratch --duration-days 7. Never use the experimental or experimental-web hub, never sign in, never create a user other than the scratch org's own admin, never touch agent-probe or experimental
- Check the org: sf org list metadata --metadata-type GenAiPlannerBundle -o ga-scratch must not return INVALID_TYPE; if it does, stop and hand back with the evidence
- Follow the README literally: in this worktree run sf config set target-org ga-scratch (local) and npm ci, then run each step of 'See it in 5 minutes' exactly as written, substituting only <org-alias> = ga-scratch. A scratch org is not production, so use the plain deploy commands the README gives. Before the publish, check whether .forceignore excludes aiAuthoringBundles (it must not, or publish fails with 'No source-backed components'). Do not change any repo file other than the scope to make a step work
- Record every deviation in docs/research/fresh-org-run.md: the command as written, what happened (error text with Ids and hosts removed), and the change that made it work. Then fix the README so a reader following it would not hit that deviation
- **Without the agent first (FR2 ledger F82, F83), if the README by then makes the agent optional:** run the required steps with no agent publish and without the agent's permission set, assign the group, and run npm run test:e2e. Record the pass count. This is the proof that the product runs without the agent; OPS-36 and OPS-44 mark that claim "not yet proven" until it passes. Then run the optional agent steps, ending with the Testing Center suite through scripts/agent-test.sh (BE-38, ledger F88) in this scratch org, and record its counts
- Step 4 and step 5 run too: deploy Account_Brief_Agent_Access and the Account_Brief_User group, assign the group to the scratch admin, and check whether the CopilotSalesforceUser permission set exists in this org (record yes or no; if yes and the README says to assign it, assign it). For step 5, run npm run test:e2e with SF_TARGET_ORG=ga-scratch and record the pass count; also run the Account_Brief agent spec once against the activated version and record replies, actions and topic
- README: add a short 'Have a Dev Hub? Use a scratch org' path next to the quick-start that uses config/project-scratch-def.json (one create command, then the same steps). Change the proof table's clean-install row only if every step ran end to end and e2e passed; say 'proven in a scratch org (2026-11-12); a new Developer Edition org run is pending' and leave the Developer Edition claim for the later card
- Update docs/research/org-migration.md with one line pointing to fresh-org-run.md. Leave the scratch org in place (it expires in 7 days) and say so. No record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings in any file
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
