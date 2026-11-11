---
id: OPS-7
title: Live probe: create an inactive custom MCP server in experimental through the API Catalog REST API, list which of our Apex actions and agents it can expose, and record it in docs/research/salesforce-mcp.md
domain: ops
tier: standard
tier_reason: small live probe against a documented REST API with judgment about findings; one doc file
status: merged
scope: [docs/research/salesforce-mcp.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**]
resources: [chrome]
red_test: none
gate: test
budget: 2-attempts
spend: 8
---
## Why

MCP is the outside door Ben cares about most, and what he described is a registered agent made callable over MCP. Three things decide the build: whether a Developer Edition org can create a custom hosted server at all, whether our `public` invocable methods are eligible or must be `global`, and whether the Employee-type Account_Brief agent can be exposed as a tool. All three can be answered by API without activating anything.

## Done when

- Read docs/research/salesforce-mcp.md and docs/ARCHITECTURE.md first. Org alias is `experimental` (Developer Edition, API 68.0). Change only docs/research/salesforce-mcp.md in the repo; keep request bodies, raw responses and any retrieved metadata in a scratch folder outside the repo (mktemp -d)
- Get the exact request shapes from the official page `https://developer.salesforce.com/docs/platform/api-catalog-connectapi/guide/create-custom-salesforce-mcp-servers.md` (WebFetch returns 403 there; use the Chrome tools, loaded in one ToolSearch call: select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__get_page_text,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__tabs_close_mcp). Browser is read only: no sign-ins, no forms, no downloads; close your tab at the end. Do not use the Setup UI
- This card lifts the earlier read-only rule for exactly these org writes, all through `sf api request rest ... -o experimental` under /services/data/v68.0/api-catalog/mcp-servers: (a) create ONE custom server of type PLATFORM named `AccountBriefProbe` (a throwaway name, so the final name stays free; it is created inactive); (b) set its assets (PUT) to the tools named below; (c) delete it at the end. Never call activate. No deploys, no External Client App changes, no permission changes, no other writes
- The create call is also the Developer Edition test. If it is refused, record the exact status and error body as the finding, skip the remaining steps and hand back. Do not try another org and do not work around it
- List available sources: GET the server's assets/available/sources, then the entries under APEX_ACTION and under PLATFORM_AGENT (and note the other source types returned). Record for each of AccountBriefResolver, AccountBriefGetAction and ExploreAction whether it is listed (they are `public with sharing` with `public static` invocable methods, not `global`), and whether the Account_Brief agent (Agent Script, AgentforceEmployeeAgent) is listed under PLATFORM_AGENT. Quote the relevant response rows
- If the two brief actions are listed: PUT them as tools named `resolve_account` and `get_account_brief`, then GET the server's assets and record the generated tool input and output schema and the default annotations. If Account_Brief is listed as an agent, add it as a third tool named `ask_account_brief` and record its schema too. If something is not listed, do not change any Apex; record it
- Record the `serverUrl` (or equivalent) the org returns for the custom server, since the docs show conflicting URL shapes
- Before deleting, retrieve the definition into the scratch folder with `sf project retrieve start --metadata McpServerDefinition:AccountBriefProbe -o experimental --output-dir <scratch>` and record the XML element names and structure in the doc (not the whole file if long). If retrieve fails, record the error
- Delete the probe server and confirm with a GET that no custom server remains. If no delete call exists or it fails, leave the server inactive, say so at the top of the hand-back, and give the exact call that failed
- Add a section `## Live probe (custom server)` to docs/research/salesforce-mcp.md with every result above marked verified, and update the Plain answer, Open questions and Recommendation to match. For the public-versus-global question write the finding and both options without choosing: flip the three action classes to global, or add a thin global facade class for MCP that calls the same engine (which also keeps the agent-facing 'relay it verbatim' descriptions out of MCP tool schemas)
- Add one line to the doc: one existing External Client App in the org already carries an MCP scope (seen in the earlier probe), and the baseline will use its own dedicated app instead of reusing it
- Scrub: remove every name of another app or agent in the org from this file (the two External Client App names, the second agent). Replace with generic words. `grep -i plesio docs/research/salesforce-mcp.md` must print nothing
- State what is still unverified after this probe: an end-to-end tool call from a client, tool-call timeout, per-call cost, behaviour for a non-admin user. No client names, no content from reference/. Keep the file under 260 lines. Gate passes: test. Commit, do not push

## Review

Brain read the live-probe section at 725f261 and confirmed in the org that no McpServerDefinition remains. Findings: Developer Edition creates custom servers; serverUrl form is api.salesforce.com/platform/mcp/v1/d/<my-domain>/develop/custom/<name>; all three public invocable classes list under APEX_ACTION (calling unverified); Account_Brief (Employee type) lists under PLATFORM_AGENT; no tool schema over REST; McpServerDefinition retrieves with tools/apiDefinition/descriptionOverride and has no active element. API deviations from docs recorded. Scrub confirmed.
