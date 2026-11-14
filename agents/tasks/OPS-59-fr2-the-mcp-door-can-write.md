---
id: OPS-59
title: FR2: the MCP door can write — CustomerSummaryMcp gains the draft and commit tools from BE-27, limited to creating a task and logging a call, with the draft-then-confirm rule written into the tool descriptions
domain: ops
tier: frontier
tier_reason: adds write tools to a live MCP server in a production-classified org, and may touch the shared invocables
status: merged
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

## Review

Brain review (2026-11-14). One attempt (e4286f4). The verifier found the report consistent, and a sonnet review returned 20 confirmed, 0 refuted, 7 unverifiable. The unverifiable rows are org-side and process claims: the deploy job, the REST calls on the server, the unauthenticated 401, that the retrieved XML was not hand-edited, and the worker's own account of what it did not do.

Findings:
- CustomerSummaryMcp now lists five tools: resolve_account, get_account_summary and ask_anything from OPS-31, plus draft_action (read-only, not destructive) and commit_action (not read-only, destructive). The three OPS-31 tools keep all four hints false. No agent tool is listed.
- Both new tool descriptions carry the confirm rule: show the draft, commit only after the person's yes, pass the Draft JSON unchanged, two actions only.
- The allow-list lives in the two invocables. CustomerSummaryActionDraftAction holds DOOR_ACTIONS = {create_task, log_call}, a fixed DOOR_REFUSED_TEXT and allowed(). It checks the action named and the action the model drafts from words; a refusal returns no draft JSON and no card.
- CustomerSummaryActionCommitAction reads the draft once and refuses any action outside the two, so a hand-made draft sent straight to commit_action is refused and writes nothing.
- CustomerSummaryActions is unchanged, and the panel's controller still offers all six actions (a test pins it).
- New CustomerSummaryActionDoorTest covers refusals by name, by words and as a hand-made draft at commit, an allowed task and logged call, and the panel's six.
- Runbook gains "Write tools (OPS-59)" with steps W1 to W6, the refusal text, the confirm rule and the undo (remove the two tools from the server definition). Page 09 gains "Writing from an outside client". Both say no real tool call has been made until Ben signs in.

Gate (verifier at e4286f4): 178 Python tests, validate-org pass (147 components, 425 tests).

Org (worker's account), under the approved MCP-writes row and the standing deploy row:
- A scoped validate of the four changed classes with RunLocalTests (518 tests, 0 failures), then a quick deploy. The allow-list was live before the tools.
- Outside validate and quick deploy: the worker deactivated the server through the REST API, replaced its tool set with the five tools, set each new tool's name, description and hints, read them back, and reactivated it (07:59Z). An unauthenticated tools/list still returns 401. The approval row covers adding the two tools; the card did not name the deactivate and reactivate step. Disclosed to Ben.
- No sign-in, no tool call, no record created, no key or secret read, no user created, experimental not touched.

Disclosed and accepted:
- The org figures and REST results are the worker's account; nothing in git shows them.
- The allow-list sits in the shared invocables, so any non-panel caller, including a future agent, gets only create_task and log_call. A BE-27 test in CustomerSummaryActionsTest that drafted create_case through the invocable now asserts the refusal. Whether agents should also be limited is Ben's call.
- The validate and the gate were moved to the background by the harness after 180 s; the worker waited in foreground polls.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook, then unset.
- The red test's one changed assertion was re-run against the old definition by the worker's account only.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- docs/patterns/13-write-actions.md and the README Status table do not mention the door's two-action limit; a docs follow-up card.
- One real call of each write tool waits on Ben's MCP sign-in; a record-creating call also waits on its own approval.

Privacy grep over the diff (482 added lines): 0 denylist hits. The brain's extra grep for hostnames, URLs with query strings, Ids and usernames found only placeholders such as <server-id> and <alias>, and the retrieved server XML holds no endpoint URL.
