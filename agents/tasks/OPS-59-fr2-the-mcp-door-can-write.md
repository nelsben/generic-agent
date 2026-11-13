---
id: OPS-59
title: FR2: the MCP door can write — CustomerSummaryMcp gains the draft and commit tools from BE-27, limited to creating a task and logging a call, with the draft-then-confirm rule written into the tool descriptions
domain: ops
tier: frontier
tier_reason: adds write tools to a live MCP server in a production-classified org, and may touch the shared invocables
status: blocked
blocked_by: [BE-27]
fixes: []
scope: [mcp-door/**, tests/test_mcp_door.py, docs/research/mcp-door-runbook.md, docs/patterns/09-outside-door-mcp.md, force-app/main/default/classes/CustomerSummaryAction*.cls, force-app/main/default/classes/CustomerSummaryAction*.cls-meta.xml]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_mcp_door.py gains a check that the server definition lists draft_action (read-only) and commit_action (destructive) and no agent tool; it fails on main and passes after. In the org, tools/list without a token still returns HTTP 401
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Ben, 2026-11-13: "i think we have our one agent, with multiple tools available that can be called. searching records and creating tasks are examples of that." He then chose that outside MCP clients get all four tools, with writes added once BE-27 builds them (Approvals row "FR2: MCP clients may write"). OPS-31 ships the door with find, summarize and search; this card adds the write pair.

## Done when

- Read first: docs/research/fr2-actions-spike.md (BE-22: the draft and commit pair, and how the tools are marked), docs/patterns/13-write-actions.md (BE-27), docs/research/mcp-door-runbook.md and docs/patterns/09-outside-door-mcp.md as OPS-31 left them, and the invocable classes BE-27 added. Load the skills agentforce-adlc:agentforce-generate (its MCP section) and salesforce-development:platform-metadata-deploy first
- **Approval first:** read the rows "FR2: MCP clients may write (create a task, log a call)" and "Production-classified deploys to `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If the first does not start with "approved", change nothing in the org and hand back
- **Two tools, not six:** the CustomerSummaryMcp server gains BE-27's draft_action and commit_action, added the same way OPS-31 added its tools. draft_action is marked read-only; commit_action is marked not read-only and destructive (BE-22). Over MCP only two actions are allowed: create a task and log a call (logged the way ledger F17 decides, an Event by default). Any other action name sent through the MCP door gets a fixed refusal and writes nothing. If BE-27's invocables cannot tell the MCP door from the panel or an agent, add the smallest door allow-list to the invocable classes, with Assert-based tests (a refused action from MCP, an allowed one, and the panel's six unchanged); the panel's behaviour does not change
- **The confirm rule travels with the tools:** each tool's description tells the client to show the draft to the person and call commit_action only after they say yes, and that commit_action takes the draft back unchanged. The tools run as the signed-in user in user mode, so the door can only write what that user may write
- tests/test_mcp_door.py checks the tool list as built (OPS-31's tools plus the two, the read-only and destructive markings, and no agent tool) and fails on the tree before this card. An unauthenticated tools/list still returns HTTP 401. No live tool call: nobody signs in in this card, and no record is created in the org (only Ben signs in; tests that create records wait on their own row)
- Update the runbook (the tools, the two allowed actions, the undo: remove the two tools from the server definition) and page 09 (a 'Writing from an outside client' part: draft, the client's yes, commit; which two actions; the refusal). Say plainly that no real tool call has been made until Ben signs in
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Never publish or activate an agent. If the deploy needs MCP_CONTACT_EMAIL, read the running admin user's email from the org in the same shell command and never print it or write it to a file
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/validate-org.sh. No tests/__pycache__, and git status --short is empty after the commit
