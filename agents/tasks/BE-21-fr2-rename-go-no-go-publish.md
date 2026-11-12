---
id: BE-21
title: FR2: rename go/no-go — publish and activate a copy of the agent named Customer_Summary (label "Customer Summary") in agent-probe from a spike package, and inventory what a full rename would leave behind
domain: backend
tier: frontier
tier_reason: agent publish and activate in a live org, where publishing has failed before; go/no-go judgement
status: blocked
blocked_by: [OPS-29]
fixes: []
scope: [spikes/rename/**, docs/research/fr2-rename-go.md]
forbid: [sfdx-project.json, tests/**, force-app/**, mcp-door/**, spikes/surface/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none (spike: research page and a spike package)
gate: test
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2) renames Account Brief to Customer Summary, including internal API names, but Ben said to skip the internal rename if agent publishing hits the friction seen before. This spike publishes one renamed agent first so the roughly 87-file rename only starts on a proven path. Covers ledger rows F03 and F07 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/research/agent-publish-spike.md, docs/research/agent-publish-failure.md, docs/research/org-migration.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/patterns/08-test-and-release-lifecycle.md and the Account_Brief bundle under force-app/main/default/aiAuthoringBundles/. Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-test and salesforce-development:platform-metadata-deploy before writing metadata or running sf commands; follow the documented agent lifecycle (validate, deploy the bundle, publish, then activate) and diagnose any failure before retrying
- Spike package only: spikes/rename/ (inside the non-default 'spikes' package directory OPS-29 added; deploy it with --source-dir spikes/rename) holds a copy of the Account_Brief bundle with developer name Customer_Summary and label 'Customer Summary'. Its actions still point at the existing AccountBrief* Apex. Nothing in force-app/ changes
- Org, agent-probe only, under the Approvals lines 'Phase 2: cut and work new agent or design iteration cards in the new org' and 'Production-classified deploys to agent-probe ... standing': deploy the bundle, publish it, and activate the new agent's version. Make at most two publish attempts, diagnosing between them. Never deactivate, change or delete Account_Brief; never sign in or out; never create a user; never touch experimental
- Go/no-go: GO if the publish and activation succeed and one sf agent preview (or the existing agent spec, run once) answers a summary question for a sample account through Customer_Summary. NO-GO if publishing returns the earlier 'Error saving or updating agent graph' class of failure or stalls; then record the evidence and recommend labels-only (the agent label and every visible string become 'Customer Summary', API names stay Account_Brief)
- Inventory, in docs/research/fr2-rename-go.md: every Account Brief API name in the repo by metadata type (count of files per type; use git grep, not a guess), and what a full rename leaves behind in agent-probe (the old agent and its versions, Account_Brief_Session__c and its rows, the permission sets and group and their assignments, the message channel, the External Client App and the active MCP server, the utility bar and app). Removing any of them is a destructive change that needs Ben's go; say so. Also record the elapsed time and the commands of the publish path that worked, so the rename card can repeat it
- No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
