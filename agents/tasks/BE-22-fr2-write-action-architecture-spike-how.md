---
id: BE-22
title: FR2: write-action architecture spike — how a request to create a task or update a record becomes a draft the user confirms, the same way from the panel, the agent and MCP
domain: backend
tier: frontier
tier_reason: architecture decision across panel, agent and MCP doors from live-org probes
status: blocked
blocked_by: [OPS-29]
fixes: []
scope: [spikes/actions/**, docs/research/fr2-actions-spike.md]
forbid: [sfdx-project.json, tests/**, force-app/**, mcp-door/**, spikes/surface/**, spikes/rename/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none (spike: research page and optional throwaway spike package)
gate: test
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2) lets a seller create follow-ups and update records by voice or chat, with a draft and a Confirm before anything is written. Whether the registered agent can hand a structured draft back to the panel (through generateAiAgentResponse) or the panel needs its own Apex router decides how the action cards are built. Covers ledger rows F15, F16 and F18 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (section 'Write actions'), docs/research/agent-api.md, docs/research/panel-agent-1.md (from BE-20), docs/patterns/04-model-provider-seam.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, AccountBriefAgentClient and AccountBriefPanelController. Load the skills agentforce-adlc:agentforce-generate, salesforce-development:platform-apex-generate and salesforce-development:platform-apex-anonymous-run before running anything
- Answer, with evidence from agent-probe (anonymous Apex and sf agent preview only; no deploy to force-app): (1) to (3) are dropped (ledger F83: the agent is not a way in, so no action runs through it); (4) the cost and latency of an Apex router that classifies the request with the AgentLlm seam and builds the draft directly, without the agent
- Recommend one architecture for the six first actions (create task, create event, log a call, update contact, create case, update opportunity), stating how the panel and an MCP client each reach the same Apex service, where the draft is built, how Confirm commits it in user mode, and how the result is shown. Name the Apex classes and methods the build card should create
- Record the decision Ben has not made yet, without making it: Salesforce's Log a Call saves a completed Task, while Ben called it 'synonymous with create an event'. Describe both and what each looks like in the activity timeline
- Throwaway code, if any, lives in spikes/actions/ (inside the non-default 'spikes' package directory OPS-29 added; deploy it with --source-dir spikes/actions). Deploys of it to agent-probe use the standing approval (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1). Never publish or activate an agent, never create or change records except throwaway test records you delete in the same run, never sign in or out, never create a user, never touch experimental
- Write docs/research/fr2-actions-spike.md: the questions, the evidence, timings, the recommendation and the class and method plan. No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
