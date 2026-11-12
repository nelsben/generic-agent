---
id: OPS-23
title: The MCP outside door is set up in agent-probe up to Ben's sign-in, with its metadata kept in its own package folder and a runbook for the rest
domain: ops
tier: frontier
tier_reason: new platform surface with org-changing steps and stop lines
status: merged
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

## Review

# OPS-23 hand check (attempt 1, f3d94f2, plus brain fix 9a2c1d6)

Accepted after a hand check.

- In agent-probe: the External Client App `AccountBriefMcpClient` is deployed, and the custom MCP server `AccountBriefMcp` is active with three tools (`resolve_account`, `get_account_brief`, `ask_account_brief`). A call without a token gets HTTP 401. No sign-in, consent screen, credential entry or user creation happened. These are the worker's reported org facts; the reviewer could not check them from the tree.
- The reviewer refuted 1 claim: page 09 stated the `mcp_api` scope as fact, while the deployed scope is named `MCP` and only the runbook marked the mapping unproven. The brain fixed it in 9a2c1d6: the Status paragraph names the scopes as the metadata has them (`MCP`, `RefreshToken`) and says the mapping is not yet proven, and the limits list carries the same point.
- The client app's description text in `mcp-door/` still says "scopes mcp_api and refresh_token". It matches what is in the org, so it was left alone. Change it with the next deliberate deploy of `mcp-door/`.
- Amend granted by the mod: `tests/test_sfdx_project.py`, a one-line change so its exact package-directory check allows the non-default `mcp-door` entry.
- Privacy grep of the 538 added lines found nothing: denylist 0, Ids 0, emails 0, query-string URLs 0, home paths 0. The consumer key and the two org-Id elements were stripped before commit. The contact email is a placeholder filled from `MCP_CONTACT_EMAIL` at deploy time.
- Worker choices to confirm with Ben:
  - the server was activated before the sign-in, so it is a live endpoint;
  - the refresh token policy is Infinite, with rotation and TTL enforcement on;
  - the callbacks are for Claude and Postman.
- Still unproven, each marked in the runbook: a real tool call, whether `public` methods run when called, the schemas a client sees, deploying `mcp-door/` into an org that never had the server, the `MCP` = `mcp_api` mapping, the Setup path to the consumer key, the Postman callback, and the undo commands. Per-field Apex descriptions, including "Relay it verbatim.", may still reach clients.
- Gates at 9a2c1d6: unit tests 100 OK, validate-org pass (61 components, 154 tests), check-docs 0 broken.
