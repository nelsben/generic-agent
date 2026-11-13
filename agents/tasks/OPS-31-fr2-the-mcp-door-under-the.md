---
id: OPS-31
title: FR2: the MCP door under the new name — deploy CustomerSummaryMcpClient, create and activate the CustomerSummaryMcp server with Apex-action tools (the agent is not a tool), prove HTTP 401 without a token, update the runbook and page 09
domain: ops
tier: frontier
tier_reason: External Client App deploy and MCP server creation through a REST path in a live org
status: merged
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
- **Approval first:** read the row "FR2: the MCP server and client app under the new names" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back. `MCP_CONTACT_EMAIL` is the running admin user's email in `agent-probe`, as the runbook's "<admin email>" says (brain-recorded, 2026-11-13): read it from the org and set it in the same shell command as the validate and the quick deploy. Never print, echo or log it, and never write it to a file. Stop if the org returns none
- Org, agent-probe only, under that row and the standing row "Production-classified deploys to `agent-probe`": deploy mcp-door (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, with MCP_CONTACT_EMAIL set from the environment and never written to a file). Create the custom MCP server CustomerSummaryMcp the same way OPS-23 did and activate it. **The tools are Apex actions:** resolve an account and get the summary, plus ask anything only if the row "FR2: the explorer as an MCP tool for outside clients" in the Approvals table of docs/plans/gtm-burn-plan.md starts with "approved"; if it does not, leave that tool out and say so in the runbook and on page 09. The optional agent is not an MCP tool. tests/test_mcp_door.py follows the tool list as built. An unauthenticated tools/list returns HTTP 401
- The client app's description names the scopes the way its metadata does (MCP and RefreshToken), fixing the mismatch OPS-23 left. Never retrieve or write the consumer key or secret; never sign in, accept a consent screen or enter credentials; never create a user
- Leave the old AccountBriefMcp server and AccountBriefMcpClient app as they are (do not deactivate or delete them); list them in the runbook's undo section as 'left from before the rename; removal needs Ben's go'. Removing them is OPS-54, which waits on its own row
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Update docs/research/mcp-door-runbook.md (new names, the steps as run, step numbers matching) and docs/patterns/09-outside-door-mcp.md (the new names and the tool list as built; for a real tool call, link the README's Status table (the 'Status' heading in README.md) instead of saying on the page that it is unproven; if OPS-48 has already rewritten page 09, keep its shape and change only the names, the tool list and its old-names line). No record Ids, org Ids, usernames, emails, tokens, consumer keys, instance hostnames or URLs with query strings in any file. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt (3efd8b1). The verifier found the report consistent; a reviewer then returned 17 confirmed, 0 refuted, 8 unverifiable. Every unverifiable row is an org fact or a command the worker ran: the API Catalog calls, the validate and quick deploy, the activation, the 401 probes, the read-only pre-checks, and how MCP_CONTACT_EMAIL was read.

Approvals: the rows "FR2: the MCP server and client app under the new names" and "FR2: the explorer as an MCP tool for outside clients" (approved 2026-11-13), and the standing agent-probe deploy row.

Findings:
- agent-probe now has an active CustomerSummaryMcp server with three Apex-action tools: resolve_account (CustomerSummaryResolver), get_account_summary (CustomerSummaryGetAction) and ask_anything (ExploreAction). The agent is not a tool.
- The retrieved McpServerDefinition is in mcp-door; it holds no Id, email or host. The client app's settings, consumer key and secret were never retrieved.
- The client app description now names the scopes as its metadata does (MCP and RefreshToken).
- Tests pin the tool list (exactly the three Apex actions, no agent entry), one description per tool, and the scope names.
- The runbook is rewritten under the new names; steps 9 and 10 (sign-in and the first real call) stay with Ben. Page 09 shows the new tool list and an old-names line.

Red condition: the card expected the endpoint to answer "not found" before the server existed. It does not: the token check runs before the server lookup, so an unauthenticated call returns 401 for any name, real or made up. The proof the server exists and is active is the API Catalog listing. The red file, the runbook and page 09 say so.

Choices accepted:
- All tool hints are left at the defaults (all false), including the read-only explorer.
- MCP_CONTACT_EMAIL is the admin user's email, read inside the deploy commands and never printed or written.
- The tool is named ask_anything, not BE-23's ask_account_summary.

Org: validate with RunLocalTests (277 of 277), then quick deploy of 5 components, under the standing row; the server activated last. No sign-in, consent or real tool call; nothing published; no user created.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- The old AccountBriefMcp server and AccountBriefMcpClient app are still active in agent-probe; removing them is Ben's call (OPS-54).
- The MCP sign-in and one real call of each tool (runbook steps 9 and 10) are Ben's.

Privacy grep over the diff (276 added lines): 1 hit, a prose line naming the my.salesforce.com host pattern in a "never commit" rule; no real host. Otherwise 0.
