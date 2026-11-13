---
id: OPS-30
title: FR2: rename in agent-probe — deploy the Customer Summary metadata, assign the new group, and prove the panel and the e2e suite under the new names; the agent publish is OPS-51's
domain: ops
tier: frontier
tier_reason: production-classified deploy of the renamed metadata, then the full e2e run in a live org
status: blocked
blocked_by: [BE-23]
fixes: []
scope: [docs/research/fr2-rename-org.md, docs/research/fr2-rename-go.md, e2e/**, tests/**, force-app/**]
forbid: [force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the full e2e run against agent-probe under the new names fails before the deploy (the Customer Summary app and panel do not exist yet) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): after the repo rename (BE-23), agent-probe must run Customer Summary end to end so every later FR2 card builds on the new names. Old Account Brief metadata stays in the org until Ben approves removing it. Covers ledger rows F03 and F07 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/research/fr2-rename-go.md (the go or no-go and the inventory), docs/research/org-migration.md and README.md 'See it in 5 minutes'. Load the skill salesforce-development:platform-metadata-deploy before running sf commands, and diagnose any failure before retrying
- If docs/research/fr2-rename-go.md says NO-GO, BE-23 renamed everything except the agent bundle, its spec and the bundle name in the agent check script: the steps below are the same, and the bundle keeps its old name. Either way this card publishes and activates nothing: the agent publish, its activation and the agent proof are OPS-51's
- Org, agent-probe only, under the standing row "Production-classified deploys to `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md: validate force-app with RunLocalTests, then quick deploy with CONFIRM_PROD=1 (the agent bundle deploys as source with the rest; nothing here publishes or activates it). Assign the Customer_Summary_User permission set group to the signed-in admin only
- A fix under force-app/, e2e/ or tests/ is allowed only when the deploy or the e2e run fails because of the rename. List each fix in the hand-back and in docs/research/fr2-rename-org.md with the failure it fixed. No new feature, no refactor, and never the agent bundle
- Leave the old metadata alone: do not deactivate, change or delete Account_Brief, its classes, objects, permission sets, group, app or MCP server, and remove no assignments. Update the 'left behind' list in docs/research/fr2-rename-go.md under a new heading 'After the rename (FR2 org card)', and say removal needs Ben's go. Record in docs/research/fr2-rename-org.md which classes and tests now exist only in the org (the old AccountBrief* ones): RunLocalTests keeps running them in every later deploy until OPS-54 removes them, and OPS-54 waits on its own row in the Approvals table
- Prove it: the Customer Summary app's utility item opens the panel, and npm run test:e2e passes in full under the new names (if spec 2 flakes on focus, rerun once and report both). Run no agent spec, agent test or preview here: the agent proof is OPS-51's. Record timings, the steps in order and the results in docs/research/fr2-rename-org.md. Paste the Playwright summary line in the hand-back
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Never sign in or out, never create a user, never touch experimental, never publish or activate an agent. No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
