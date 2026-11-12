---
id: OPS-30
title: FR2: rename in agent-probe — deploy the Customer Summary metadata, publish and activate the Customer_Summary agent from force-app, assign the new group, and prove the panel, e2e and agent spec under the new names
domain: ops
tier: frontier
tier_reason: production-classified deploy plus agent publish and activation, then e2e and agent spec in a live org
status: blocked
blocked_by: [BE-23]
fixes: []
scope: [docs/research/fr2-rename-org.md, docs/research/fr2-rename-go.md, e2e/**, tests/**]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the full e2e run against agent-probe under the new names fails before the deploy (the Customer Summary app and panel do not exist yet) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2): after the repo rename (BE-23), agent-probe must run Customer Summary end to end so every later FR2 card builds on the new names. Old Account Brief metadata stays in the org until Ben approves removing it. Covers ledger rows F03 and F07 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/research/fr2-rename-go.md (the publish path that worked and the inventory), docs/research/org-migration.md and README.md 'See it in 5 minutes'. Load the skills salesforce-development:platform-metadata-deploy, agentforce-adlc:agentforce-generate and agentforce-adlc:agentforce-test before running sf commands; follow the documented agent lifecycle and diagnose any failure before retrying
- If BE-23 did labels only (fr2-rename-go.md says NO-GO), deploy the changed labels and publish the label change as a new Account_Brief version the same way; otherwise do the full path below
- Org, agent-probe only, under the Approvals lines 'Production-classified deploys to agent-probe ... standing' and 'Phase 2: cut and work new agent or design iteration cards in the new org': validate force-app with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Deploy the Customer_Summary bundle, publish it and activate the new version (this becomes the next version of the Customer_Summary agent BE-21 created). Assign the Customer_Summary_User permission set group to the signed-in admin only. Make at most two publish attempts, diagnosing between them
- Leave the old metadata alone: do not deactivate, change or delete Account_Brief, its classes, objects, permission sets, group, app or MCP server, and remove no assignments. Update the 'left behind' list in docs/research/fr2-rename-go.md under a new heading 'After the rename (FR2 org card)', and say removal needs Ben's go
- Prove it: the Customer Summary app's utility item opens the panel; npm run test:e2e passes in full under the new names (if spec 2 flakes on focus, rerun once and report both); the agent spec runs once against the active Customer_Summary version and passes at least as many cases as the last Account_Brief run (16 of 16 replies and actions); the panel's agent call reaches Customer_Summary. Record timings, the steps in order and the results in docs/research/fr2-rename-org.md
- Never sign in or out, never create a user, never touch experimental, never publish to any other org. No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
