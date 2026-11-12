---
id: OPS-23
title: Stretch: design and metadata for the MCP outside door, built up to the point where an org change or Ben's sign-in is needed
domain: ops
tier: frontier
tier_reason: new platform surface with org-changing steps and stop lines
status: queued
fixes: []
scope: [docs/research/mcp-door-runbook.md, force-app/main/default/mcpServerDefinitions/**, force-app/main/default/externalClientApps/**, force-app/main/default/extlClntAppOauthSettings/**]
forbid: [force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Corrective plan step 4: the priority outside door is a custom MCP server exposing resolve_account, get_account_brief and ask_account_brief. Creating the server and its External Client App changes org setup and the first real call needs Ben's OAuth sign-in, so tonight's card prepares everything that can be prepared and stops at those lines.

## Done when

- Read docs/plans/corrective-plan.md step 4, docs/research/salesforce-mcp.md, docs/research/agent-publish-spike.md and docs/patterns/09-outside-door-mcp.md first. Read docs/plans/gtm-burn-plan.md section 'Approvals'
- Write docs/research/mcp-door-runbook.md: the exact ordered steps to create the custom MCP server with the three tools (using the API quirks recorded in salesforce-mcp.md), the External Client App with scopes mcp_api and refresh_token, the description overrides so agent-facing wording does not reach MCP clients, the retrieve command for the McpServerDefinition, the sign-in step Ben does, and the first real tool call to measure. Each step says whether it changes the org
- Only if the approvals line for MCP org setup says approved: carry out the org-changing steps up to, but not including, any sign-in or consent screen, retrieve the resulting metadata into force-app, and record what was created. Otherwise create nothing in the org
- Mark clearly in the runbook what is proven tonight and what is not. No record Ids, org Ids, usernames, client secrets, tokens or URLs with query strings anywhere
- Gates pass: python3 -m unittest discover -s tests and bash scripts/validate-org.sh (check-only) if force-app changed. Never sign in, accept a consent screen, enter credentials or install a plugin. Run Python with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/, git status --short is empty when you report
