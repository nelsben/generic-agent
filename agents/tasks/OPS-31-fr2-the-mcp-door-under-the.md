---
id: OPS-31
title: FR2: the MCP door under the new name — deploy CustomerSummaryMcpClient, create and activate the CustomerSummaryMcp server with Apex-action tools (the agent is not a tool), prove HTTP 401 without a token, update the runbook and page 09
domain: ops
tier: frontier
tier_reason: External Client App deploy and MCP server creation through a REST path in a live org
status: parked
blocked_by: [OPS-51]
fixes: []
scope: [mcp-door/**, tests/test_mcp_door.py, docs/research/mcp-door-runbook.md, docs/patterns/09-outside-door-mcp.md]
forbid: [force-app/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_mcp_door.py gains a check of the tool list (Apex actions only, no agent tool) and of the scopes named in the client app's description; it fails on the tree BE-23 left and passes after. In the org, an unauthenticated tools/list to the CustomerSummaryMcp endpoint returns not-found before the card and HTTP 401 after
gate: test
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): the branded agent is "consumed by MCP", so the outside door must carry the Customer Summary name before Ben does the sign-in (runbook steps 9 and 10), or he would redo it. Covers ledger row F04 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/research/mcp-door-runbook.md (steps 0 to 8, the API Catalog REST path OPS-23 used to create and activate the server), docs/patterns/09-outside-door-mcp.md, docs/research/fr2-rename-org.md, docs/research/fr2-agent-publish.md (OPS-51) and mcp-door/ as renamed by BE-23. Load the skills integration:integration-connectivity-connected-app-configure, agentforce-adlc:agentforce-generate and salesforce-development:platform-metadata-deploy first
- **Approval first:** read the row "FR2: the MCP server and client app under the new names" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back. Stop too if `MCP_CONTACT_EMAIL` is not set in the environment: never invent one and never write it to a file
- Org, agent-probe only, under that row and the standing row "Production-classified deploys to `agent-probe`": deploy mcp-door (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, with MCP_CONTACT_EMAIL set from the environment and never written to a file). Create the custom MCP server CustomerSummaryMcp the same way OPS-23 did and activate it. **The tools are Apex actions:** resolve an account and get the summary, plus ask anything only if the row "FR2: the explorer as an MCP tool for outside clients" in the Approvals table of docs/plans/gtm-burn-plan.md starts with "approved"; if it does not, leave that tool out and say so in the runbook and on page 09. The optional agent is not an MCP tool. tests/test_mcp_door.py follows the tool list as built. An unauthenticated tools/list returns HTTP 401
- The client app's description names the scopes the way its metadata does (MCP and RefreshToken), fixing the mismatch OPS-23 left. Never retrieve or write the consumer key or secret; never sign in, accept a consent screen or enter credentials; never create a user
- Leave the old AccountBriefMcp server and AccountBriefMcpClient app as they are (do not deactivate or delete them); list them in the runbook's undo section as 'left from before the rename; removal needs Ben's go'. Removing them is OPS-54, which waits on its own row
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Update docs/research/mcp-door-runbook.md (new names, the steps as run, step numbers matching) and docs/patterns/09-outside-door-mcp.md (the new names and the tool list as built; for a real tool call, link the README's Status table (the 'Status' heading in README.md) instead of saying on the page that it is unproven; if OPS-48 has already rewritten page 09, keep its shape and change only the names, the tool list and its old-names line). No record Ids, org Ids, usernames, emails, tokens, consumer keys, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
