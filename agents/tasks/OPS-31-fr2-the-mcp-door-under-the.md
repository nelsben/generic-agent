---
id: OPS-31
title: FR2: the MCP door under the new name — deploy CustomerSummaryMcpClient, create and activate the CustomerSummaryMcp server with the renamed tools, prove HTTP 401 without a token, update the runbook and page 09
domain: ops
tier: frontier
tier_reason: External Client App deploy and MCP server creation through a REST path in a live org
status: parked
blocked_by: [OPS-30]
fixes: []
scope: [mcp-door/**, tests/test_mcp_door.py, docs/research/mcp-door-runbook.md, docs/patterns/09-outside-door-mcp.md]
forbid: [force-app/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: an unauthenticated tools/list to the CustomerSummaryMcp endpoint returns not-found before the card and HTTP 401 after; tests/test_mcp_door.py asserts the renamed tool targets
gate: test
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): the branded agent is "consumed by MCP", so the outside door must carry the Customer Summary name before Ben does the sign-in (runbook steps 9 and 10), or he would redo it. Covers ledger row F04 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/research/mcp-door-runbook.md (steps 0 to 8, the API Catalog REST path OPS-23 used to create and activate the server), docs/patterns/09-outside-door-mcp.md, docs/research/fr2-rename-org.md and mcp-door/ as renamed by BE-23. Load the skills integration:integration-connectivity-connected-app-configure, agentforce-adlc:agentforce-generate and salesforce-development:platform-metadata-deploy first
- Org, agent-probe only, under the Approvals lines 'Org setup for the MCP server and its External Client App (stretch), up to the sign-in' and the standing deploy line: deploy mcp-door (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, with MCP_CONTACT_EMAIL set from the environment and never written to a file). Create the custom MCP server CustomerSummaryMcp the same way OPS-23 did, with the three tools pointing at the renamed Apex and the Customer_Summary agent, and activate it. An unauthenticated tools/list returns HTTP 401
- The client app's description names the scopes the way its metadata does (MCP and RefreshToken), fixing the mismatch OPS-23 left. Never retrieve or write the consumer key or secret; never sign in, accept a consent screen or enter credentials; never create a user
- Leave the old AccountBriefMcp server and AccountBriefMcpClient app as they are (do not deactivate or delete them); list them in the runbook's undo section as 'left from before the rename; removal needs Ben's go'
- Update docs/research/mcp-door-runbook.md (new names, the steps as run, step numbers matching) and docs/patterns/09-outside-door-mcp.md (status in agent-probe under the new names; still unproven: a real tool call). No record Ids, org Ids, usernames, emails, tokens, consumer keys, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
