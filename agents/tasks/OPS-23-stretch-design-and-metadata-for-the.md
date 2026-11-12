---
id: OPS-23
title: The MCP outside door is set up in agent-probe up to Ben's sign-in, with its metadata kept in its own package folder and a runbook for the rest
domain: ops
tier: frontier
tier_reason: new platform surface with org-changing steps and stop lines
status: queued
fixes: []
scope: [docs/research/mcp-door-runbook.md, docs/patterns/09-outside-door-mcp.md, mcp-door/**, sfdx-project.json, tests/test_mcp_door.py]
forbid: [force-app/**, tests/test_access_group.py, tests/test_explore_prompt.py, scripts/**, e2e/**, data/**, agents/**, docs/plans/**, docs/patterns/01-route-gather-reduce.md, docs/patterns/02-ask-anything-explorer.md, docs/patterns/03-hotkey-panel.md, docs/patterns/04-model-provider-seam.md, docs/patterns/05-conversation-memory.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/patterns/07-trust-access-and-failure.md, docs/patterns/08-test-and-release-lifecycle.md, docs/assets/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: tests/test_mcp_door.py fails on main (no mcp-door package folder, sfdx-project.json has one package directory)
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Corrective plan step 4: the priority outside door is a custom MCP server exposing resolve_account, get_account_brief and ask_account_brief. Ben said "Run ops23" (2026-11-12), and the Approvals table approves the MCP org setup up to the sign-in, so this card now does the org setup in agent-probe, not the first org. The first real tool call still needs Ben's OAuth sign-in, so the card stops there.

## Done when

- Read first: docs/plans/corrective-plan.md step 4, docs/research/salesforce-mcp.md, docs/research/org-migration.md (the current org and how it was stood up; docs/research/agent-publish-spike.md records the first org and is history only), docs/patterns/09-outside-door-mcp.md, and docs/plans/gtm-burn-plan.md section 'Approvals' (lines 'Org setup for the MCP server and its External Client App' and 'Run OPS-23 in agent-probe'). Load the skills salesforce-development:platform-metadata-retrieve, salesforce-development:platform-metadata-deploy and integration:integration-connectivity-connected-app-configure before any sf command
- Decision already made: the MCP metadata lives in a second, non-default package folder `mcp-door/` (add it to sfdx-project.json packageDirectories with default false). README step 1 and scripts/validate-org.sh deploy only force-app, so a fresh-org install does not pick it up. The runbook gives the one command that deploys it on purpose
- Write docs/research/mcp-door-runbook.md: the exact ordered steps to create the custom MCP server with the three tools (using the API quirks recorded in salesforce-mcp.md), the External Client App with scopes mcp_api and refresh_token, the description overrides so agent-facing wording does not reach MCP clients, the retrieve command for the McpServerDefinition, the sign-in step Ben does, and the first real tool call to measure. Each step says whether it changes the org
- Org, agent-probe only: carry out the org-changing steps up to, but not including, any sign-in or consent screen. Retrieve the resulting metadata into mcp-door/ and record what was created. Never touch experimental
- Strip or never retrieve any consumer key, consumer secret, client secret, certificate or callback URL with a query string. tests/test_mcp_door.py asserts: sfdx-project.json has force-app as the only default package directory and mcp-door as a non-default one; no file under mcp-door/ contains consumerKey, consumerSecret, clientSecret, a 15- or 18-character Salesforce Id, an email, or a my.salesforce.com host
- docs/patterns/09-outside-door-mcp.md gains a short 'Status in agent-probe' paragraph: what exists in the org now, and that the first call waits on Ben's sign-in. Mark clearly in the runbook what is proven and what is not. No record Ids, org Ids, usernames, client secrets, tokens or URLs with query strings anywhere
- Gates pass: python3 -m unittest discover -s tests, bash scripts/validate-org.sh (check-only) and bash scripts/check-docs.sh (0 broken). Never sign in, accept a consent screen, enter credentials, create a user or install a plugin. Run Python with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/, git status --short is empty when you report
