---
id: BE-38
title: FR2: an Agentforce Testing Center suite for Customer Summary — a capped set of cases for the summary and the explorer through the optional agent, one script that recreates the test for the active version and prints counts, and a rung in the run
domain: backend
tier: frontier
tier_reason: creates and runs a Testing Center definition in a production-classified org, where each run spends model calls and runs real actions
status: blocked
blocked_by: [OPS-30, BE-29, BE-30]
fixes: []
scope: [tests/agent/**, tests/test_agent_bundle.py, scripts/agent-test.sh, tests/test_agent_test_script.py, docs/research/fr2-testing-center.md]
forbid: [force-app/main/default/aiEvaluationDefinitions/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_agent_test_script.py fails on main (scripts/agent-test.sh does not exist and the spec has neither the case cap nor the new cases) and passes after
gate: test
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: "we have a really awesome opportunity to build out some really cool Agentforce Testing Center suite that we can incorporate into the run", and "how we communicate how to effectively test these agents as well as part of this bundle". Testing Center tests a registered agent (its spec names a BotDefinition), so the optional agent is the test bench: its actions call the same Apex services the panel and MCP call. It does not test the panel, the rail or cards; Playwright does. Covers ledger row F88 in docs/plans/feature-revision-2.md, and the version-pinning item (agent re-review N2) on page 08.

## Done when

- **Dispatched only after Ben's go** on the Testing Center row in the Approvals table of docs/plans/gtm-burn-plan.md. Read first: docs/plans/feature-revision-2.md (rows F88 to F92, the decision that the optional agent is the test bench, and the review of page 08's open items), docs/patterns/08-test-and-release-lifecycle.md, tests/agent/ (today's spec), docs/research/agent-iteration-1.md and docs/research/org-migration.md (how the last spec runs went). Load the skills agentforce-adlc:agentforce-test and salesforce-development:platform-metadata-deploy first
- **Settle the facts first** at the top of docs/research/fr2-testing-center.md, from Salesforce's public docs and the skill's references: what a test can assert (subagent, actions, outcome judged by a model, and any custom evaluation on an action's output), what one run costs in the org's generative AI usage, Salesforce's advice to run Testing Center in a sandbox and what that means for a Developer Edition org that has none (a scratch org, as OPS-28 uses, is one answer), and how a definition stays tied to one agent version
- **The suite,** at most 20 cases, in tests/agent/Customer_Summary-testSpec.yaml: a summary for a named account, not found, several matches, a follow-up that needs the first turn (conversation history), an org-wide explorer question, a question outside the agent's job, and one case per error status BE-29 added. Each case has an expected outcome in plain words; use subagent and action checks where they apply. No write actions: no case asks to create, change or delete a record. A summary still records what it always records (its session row and, after BE-35, a customer outcome), so the cases use one dedicated test account, named in the research page, whose timeline nobody demos; record in the research page what one run writes. The agent is not republished in this card: a case that fails because the agent's script lags behind the Apex is a finding for Ben, not a fix
- **scripts/agent-test.sh** creates or updates the test definition for the active Customer_Summary version, runs it, and prints one line per assertion type with pass and fail counts (leaving out the known false failure of the subagent check on cases that set no subagent), and the version it ran against. A run leaves git status unchanged (any file the CLI writes goes to a temporary folder, or matches the committed definition), so OPS-28 can run it in a scratch org. It prints and writes no record Ids, usernames, job Ids or hostnames. tests/test_agent_bundle.py today pins the old 12-case spec: update it to the new spec in the same change. **No definition in force-app:** the script builds the test definition from the YAML at run time, outside force-app (for example in a temporary project folder), so validate-org.sh and the README's quick start never deploy a test that needs the agent. tests/test_agent_test_script.py checks the spec's shape, the case cap, that no case uses a write action, and the script's flags. Run it once in agent-probe and record the counts in the research page
- **Security cases:** do not write or run any. Record in the research page what a security suite would cover and that it needs a non-production org and Ben's go. Never publish, activate or deactivate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
