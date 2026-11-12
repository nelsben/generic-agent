---
id: BE-28
title: FR2: the agent catches up — brand tone in its instructions and the write actions with confirmation, then one publish and activate of Customer_Summary in agent-probe; agent spec extended
domain: backend
tier: frontier
tier_reason: agent publish and activate in a live org, with write actions routed by a model
status: blocked
blocked_by: [BE-27, BE-24, OPS-30, BE-30, FE-18, BE-35]
fixes: []
scope: [force-app/main/default/aiAuthoringBundles/Customer_Summary/**, tests/agent/**, docs/research/fr2-agent-next.md, docs/patterns/06-agent-routing-and-verbatim-relay.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/classes/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new agent spec cases for the draft-and-confirm flow fail against the active agent before the card and pass after the publish
gate: test, org, agent
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2): the same branded agent should speak in the prospect's tone and create follow-ups and updates in Agentforce's own panel too, not only in our surfaces. Publishes are slow and have failed before, so tone and actions go into one publish. Covers ledger rows F02, F08 (tone in the agent), F15 and F16 (agent side) in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/patterns/13-write-actions.md, docs/patterns/10-brand-and-theming.md, docs/research/fr2-actions-spike.md (Agent Script confirmation findings) and docs/research/fr2-rename-org.md. Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-test and salesforce-development:platform-metadata-deploy first
- In the Customer_Summary authoring bundle: the system instructions carry the tone from the Default brand settings record as a clearly marked line that the swap guide tells sellers to change (or read at run time if the spike showed that works); the agent name in its greeting comes from the same place. A new 'act' subagent or topic routes requests to the six invocable actions from CustomerSummaryActions and always shows the draft and asks for an explicit yes before calling commit; it never commits on an ambiguous reply. Existing summary and ask-anything routing keep working and keep the verbatim relay
- **Customer history (ledger F78):** the agent receives the account's outcome context through the shared services (BE-35) with no new action. Check in preview that it uses it (for example, it mentions the last summary's date when asked what changed). If docs/research/fr2-customer-outcomes.md says the instructions need a line for that, add it here, inside the same one publish
- Follow-ups (ledger F55 and F58, agent review docs/reviews/agent-review-2.md): the ask-anything route passes the history the explorer action returns (it now carries the summary context from BE-30) back in on the next turn, so a follow-up keeps the question before it and a pronoun means the records in the last turn, not the summarized account by default (agent N3). Fix agent N4 too if the fix is in the bundle. The verbatim relay of an explorer table is proven in a live run, and the result is recorded (agent N6). The agent spec gains a summary followed by two follow-ups, and a table relay case
- **Rich answers (ledger F65):** the agent's replies and action outputs follow FE-18's recommendation in docs/research/fr2-card-architecture.md for Agentforce's own panel (for example custom Lightning types for action outputs, if FE-18 recommends them); where FE-18 marked something unproven, prove it in this card's one publish or record why not
- One publish and one activate of Customer_Summary in agent-probe, under the Approvals line for FR2 agent publishes. If the publish fails, diagnose before retrying (at most two attempts) and record what happened in docs/research/fr2-agent-next.md. Old agent versions are left as they are
- The agent spec (tests/agent/Customer_Summary-testSpec.yaml after BE-23, used by scripts/agent-check.sh) gains cases: tone line present in a greeting, a follow-up request yields a draft and a confirmation question, a 'no' cancels, a 'yes' commits once (the test task is deleted afterwards), and the summary and ask-anything cases still pass. bash scripts/agent-check.sh passes. MCP write tools are out of scope (they need Ben's go). Never create a user, never touch experimental, never sign in. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh, bash scripts/agent-check.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
