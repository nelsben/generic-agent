# Salesforce MCP: exposing Apex actions and agents to outside clients

Researched 2026-11-11; live probe of a custom server run the same day. Status words: documented (official page says it), verified (seen in the
`experimental` org), unverified (inference or community). Base URL for all doc links:
`https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/` (abbreviated `HMS/`).

## Plain answer

1. Salesforce Hosted MCP Servers are the offer that matters. They are Salesforce-managed MCP
   endpoints, GA since April 2026. An outside client (Claude, ChatGPT, Cursor, Postman)
   connects over OAuth and calls tools as the signed-in user.
2. A custom hosted server can expose Apex invocable actions as tools. That is the path for
   AccountBriefResolver, AccountBriefGetAction and ExploreAction, with the calling user's
   identity, sharing and permissions. No service account, no integration user.
3. Setup is: enable MCP in Setup, one External Client App (scopes `mcp_api` + `refresh_token`),
   one custom server with the Apex actions added, activate it, add the URL to the client.
4. Verified live (see Live probe): the `experimental` Developer Edition org creates a custom
   server through the API, and lists our `public with sharing` / `public static` invocable
   classes as `APEX_ACTION` sources, so they can be added as tools without being `global`. The
   docs say `global` only; the org does not enforce that at the listing and add-tool step.
   Whether a client tool call on a `public` method then runs is not tested (activation was
   out of scope). Two ways to be safe: flip the classes to `global`, or add a thin `global`
   facade class for MCP that calls the same engine.
5. A registered agent can also be a tool (source `PLATFORM_AGENT`). Verified: the Employee-type
   Account_Brief agent is listed and was added as a tool; a real call stays unverified.
6. The Salesforce DX MCP server (`@salesforce/mcp`) is a developer tool for sf CLI tasks, not a
   way to call our actions. It reached end of life on 2026-11-02.
7. Agentforce consuming outside MCP servers exists and does not matter for this baseline.
8. Hosted MCP is intended for customers with Flex Credits and may be billed.

## Facts table

| Fact | Status | Source |
|---|---|---|
| Hosted MCP Servers GA 2026-04-29, "every Enterprise Edition org and above"; pilot spring 2025, beta Oct 2025 | documented | blog `developer.salesforce.com/blogs/2026/04/salesforce-hosted-mcp-servers-are-now-generally-available` |
| Intended only for customers with Flex Credits; may be billed for server usage | documented | HMS/hosted-mcp-servers-overview.html |
| Custom servers can include Apex invocable actions, @AuraEnabled, Apex REST, autolaunched Flows, Named Queries, API Catalog endpoints | documented | HMS/custom-servers.html |
| Only a class with a `global` method annotated `@InvocableMethod` is eligible | documented | HMS/invocable-actions.md |
| Apex actions run as the authenticated user; governor limits and sharing rules apply as for any Apex run by that user | documented | HMS/invocable-actions.md |
| Every tool call has the user's CRUD, FLS and sharing; actions attributed to the named user | documented | HMS/security-best-practices.md |
| OAuth authorization code flow with PKCE only; no service accounts, no machine-to-machine, no dynamic client registration | documented | HMS/security-best-practices.md |
| ECA scopes: `mcp_api` and `refresh_token`; "Issue JWT-based access tokens for named users" selected | documented | HMS/create-external-client-app.md |
| MCP servers are disabled by default; enable in Setup > API Catalog > MCP Servers; up to 2 minutes to activate | documented | HMS/activate-mcp-servers.md |
| Standard server URL: `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all`; custom prefix `custom/<name>` | documented | HMS/server-urls.md, hxl guide below |
| Developer Edition My Domain URL form `.../v1/d/<my-domain>/develop/<server-name>` | documented | HMS/server-urls.md |
| Agent as tool: source `PLATFORM_AGENT`, kind `MCP_TOOL`; only agents from the new Agent Script builder | documented | HMS/agentforce.md, api-catalog-connectapi create-custom example |
| Prompt Builder: only published Flex templates, exposed as MCP prompts (Claude, Cursor support them; ChatGPT does not) or as tools | documented | HMS/prompt-builder.md; api-catalog-connectapi example |
| Our three classes are `public with sharing`, methods `public static`, not `global` | verified | `force-app/main/default/classes/*Action.cls`, `AccountBriefResolver.cls` |
| Account_Brief is an `AiAuthoringBundle` with `agent_type: "AgentforceEmployeeAgent"` | verified | `force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent` |
| Whether Employee-type agents can be MCP tools | verified: listed under `PLATFORM_AGENT` and added as a tool | live probe |
| Org lists `public` invocable Apex under `APEX_ACTION` and accepts it as a tool | verified (listing and add only) | live probe |
| Custom server create on Developer Edition returns 201, inactive, with `serverUrl` | verified | live probe |
| DX MCP server `@salesforce/mcp` EOL 2026-11-02, repo archived, package deprecated but installable; replaced by skills in `forcedotcom/sf-skills` | documented | `github.com/forcedotcom/mcp/issues/46` |

## Availability

- Status: GA (April 2026). Beta used old scopes and URL; the GA service needs `mcp_api` and a new URL (HMS/beta-to-ga-transition.md).
- Editions: documented "Enterprise Edition and above" (blog). The `experimental` org is a Developer Edition; it serves the API-Catalog MCP endpoint and created a custom server (verified, live probe). That it can run an end-to-end tool call is unverified.
- Licence: Flex Credits (HMS overview). Prompt template tools consume credits per invocation (HMS/prompt-builder.md). Per-call price for Apex or agent tools: not found.
- API version: org on 68.0 (verified). Metadata type `McpServerDefinition` is listed by the org (verified). Minimum API version: not found.
- Client support: Claude, ChatGPT, Cursor, Postman, Agentforce Vibes (HMS/client-connection-overview.md).
- Salesforce DX MCP server: was beta, now EOL (see table). `sf agent mcp` CLI commands (create, asset replace, list, fetch...) are Developer Preview (agentforce guide `agent-dx-mcp.md`); present in the installed CLI 2.154.4 (verified, `sf agent mcp --help`).

## What can be exposed

Documented sources for a custom server (HMS/custom-servers.html, HMS/invocable-actions.md,
HMS/flows.md, HMS/prompt-builder.md, HMS/agentforce.md): `APEX_ACTION`, `FLOW_ACTION` (autolaunched
only), `PROMPT` (Flex templates; tool or prompt), `PLATFORM_AGENT` (Agent Script agents),
`AURA_ENABLED`, `APEX_REST`, `NAMED_QUERY`, `CONNECT`, `PLATFORM_SERVER`. The org returned all nine
(verified). SOQL and record CRUD come from fixed standard servers `platform/sobject-*` (4 of 15 seen).
Our ExploreAction overlaps with `sobject-reads`; the Account brief is unique to this baseline.

## Registration, naming, auth, URL

- Registration: Setup > Integration > Salesforce MCP Servers (API Catalog > MCP Servers). Add server, Add Server Assets > Add Tools, choose "Apex actions", pick the action, name it, describe it, save, Activate (HMS/custom-servers.html; hxl guide `.../hxl/guide/hxl-mcp-server.md`). Documented.
- Same flow by API: `POST /api-catalog/mcp-servers` (`type: PLATFORM`, created inactive), `GET .../assets/available/sources/APEX_ACTION`, `PUT .../assets` (replace semantics), `PUT .../assets/{id}` for annotations, `POST .../activate`. Assets only editable while inactive. Documented (api-catalog-connectapi `create-custom-salesforce-mcp-servers.md`).
- Naming: tool name and description are set by the admin and are what the client model uses to choose a tool. Make one task-specific tool per task (HMS/agentforce.md, HMS/custom-servers.html). Server `name` and `type` are immutable after creation. Documented.
- Annotations (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`) are set explicitly on custom tools; an unannotated tool is treated as destructive (HMS/general-best-practices.md). Documented.
- Auth: per-user OAuth auth code + PKCE through an External Client App. Per-user only; there is no integration-user path (HMS/security-best-practices.md). Claude config: custom connector, URL, "Use your own OAuth client", paste ECA consumer key, leave secret blank (HMS/claude.md). Documented.
- Restrict users: require a custom permission set on the ECA OAuth policy (HMS/create-external-client-app.md). Documented.
- Audit: API logs, `API_CLIENT_CATEGORY = SALESFORCE_HOSTED_MCP` (HMS/security-best-practices.md). Documented.
- Sharing and FLS: documented as inherited from the calling user for all tools. For Apex the page states sharing rules and governor limits apply. Our code is `with sharing`; `ExploreQuery` uses `AccessLevel.USER_MODE` (ARCHITECTURE.md). Whether a called Apex action also needs class access via profile or permission set: unverified (inference from normal Apex action behaviour).
- URL shapes, three forms seen:
  - standard: `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all` (HMS/server-urls.md)
  - custom: `https://api.salesforce.com/platform/mcp/v1/custom/<name>` (hxl guide, documented)
  - Connect API example response shows `https://<domain>.my.salesforce.com/services/mcp/<Name>` (documented; the live org did not return this form)
  - Developer Edition (verified): the org returned `https://api.salesforce.com/platform/mcp/v1/d/<my-domain>/develop/custom/<name>`. Use the `serverUrl` the org returns.

## Setup steps, in order

1. Setup > External Client App Manager > New. Enable OAuth; callback `https://claude.ai/api/mcp/auth_callback`; scopes `mcp_api`, `refresh_token`; select "Issue JWT-based access tokens for named users"; create; copy the consumer key. Wait up to 30 min. (HMS/create-external-client-app.md)
2. Setup > API Catalog > MCP Servers: create a custom server; add the Apex actions as tools; set names, descriptions, annotations; activate. Servers are off by default; activation takes up to 2 minutes.
3. Give users access: a permission set granting the Apex classes (unverified) and, if used, the ECA permission-set policy.
4. Log into the org in the default browser (log out of other orgs first; HMS/log-into-org.md).
5. Claude: Customize > Connectors > Add custom connector, server URL, own OAuth client, consumer key, Connect (HMS/claude.md). Test with Postman first to see raw tool JSON (HMS/client-connection-overview.md).

## Metadata types and source deploy

| Type | In org describe | Deploy from source with sf | Source |
|---|---|---|---|
| `McpServerDefinition` (`mcpServerDefinitions/*.mcpServerDefinition-meta.xml`) | verified | documented: `sf project retrieve start --metadata McpServerDefinition:<name>` and `sf project deploy start` | hxl guide; org probe 1 |
| `ExternalClientApplication` (`eca`), `ExtlClntAppOauthSettings`, `ExtlClntAppGlobalOauthSettings`, `ExtlClntAppOauthConfigurablePolicies` | verified (listed) | unverified: type names exist, no page read says an MCP ECA deploys cleanly; consumer key and secret are org-generated | org probe 1 |
| `AiAuthoringBundle` / `AiAgentDefinition` (Account_Brief) | verified (listed; org has `Account_Brief_1`, `Account_Brief_2`, `Account_Brief`) | yes (already in repo) | org probe 3; repo |

Contents of `McpServerDefinition`: see the Live probe section (verified).

Not in source: org enablement, the ECA consumer key, client connectors, OAuth grants, and (per the probe) the `active` flag.

## Limits and costs

- Client tool budget: "beyond a few dozen tools" clients pick badly; keep servers small per persona (HMS/custom-servers.html). Documented.
- Tool schema comes from the Apex Request/Response `@InvocableVariable` fields; complex or nested types are harder for clients (HMS/invocable-actions.md). Ours are flat strings. Documented.
- No streaming or progress for long runs (stated for Flows); assume the same for Apex (unverified). `AccountBriefGetAction` makes model calls inside Apex; tool-call time ceiling: not found.
- Billing: Flex Credits; Models API calls our brief makes are billed as they are today. Per-call MCP price: not found.
- ISV managed packages cannot yet bundle MCP server config (HMS/custom-servers.html), so a packaged baseline would ship the Apex and leave the server to the subscriber admin. Documented.

## Reverse direction: Agentforce consuming outside MCP servers

- Documented. Register an external MCP server in Agentforce Registry / API Catalog (`type: EXTERNAL`, OAuth or no auth); its tools are reviewed, allowlisted, and can become agent actions (`availableAsAgentAction`). Sources: api-catalog-connectapi `manage-external-mcp-servers.md`; `.../pkg2-dev/guide/dev2gp-package-mcp-agentforce.md` (packageable types ExternalCredential, ExternalServiceRegistration, NamedCredential, PermissionSet; MCP tool actions and gateway policies not packageable).
- Matters for this baseline: not now. Revisit only if the agent must call a third-party MCP server.

## Agent as an MCP tool

- Documented: the whole agent can be a tool, so a client delegates in natural language and Salesforce routes to the agent, which uses its own instructions and actions (HMS/agentforce.md). Source type `PLATFORM_AGENT` (api-catalog-connectapi example).
- Requirement: Agent Script builder agents only. Account_Brief is an authoring bundle (verified). Employee agent type: not found either way, so unverified.
- Tradeoffs: the agent reasons with an LLM and returns prose, while the actions are deterministic. HMS/agentforce.md itself recommends Apex actions or Flows when you want precise control. Agent calls cost agent credits (inference; per-call price not found).

## Org probes (read-only, org alias `experimental`)

1. `sf org list metadata-types`: lists `McpServerDefinition`, ECA types, `AiAuthoringBundle`, `GenAiFunction`, `NamedCredential`, `ApiNamedQuery`, `InvocableActionExtension` and others.
2. `sf data query --use-tooling-api "SELECT DeveloperName, MasterLabel FROM McpServerDefinition"`: 0 records. The same query without the tooling flag fails with INVALID_TYPE. Result: no custom MCP server exists. Also `sf org list metadata -m ExternalClientApplication` shows two other ECAs; their scopes were not read here.
3. `sf org list metadata -m AiAuthoringBundle` and `SELECT DeveloperName, Type FROM BotDefinition`: Account_Brief and one other agent exist, both type `InternalCopilot`; ApexClass query confirms the three action classes are deployed.
4. `sf api request rest /services/data/v68.0/api-catalog/mcp-servers` (GET): 15 `STANDARD` servers, all `active:false`: platform.sobject-all, -mutations, -reads, -deletes, content-readonly, content-write, metadata-experts, salesforce-api-context, agentforce-grid, headless-360, data.data360, data.data-cloud-queries, analytics.crma-beta, industries.engagement-interaction, industries.comms-offer-agent. `GET .../platform.sobject-all/assets` lists tool annotations. `GET .../assets/available/sources` on a standard server returns BAD_REQUEST ("only for custom PLATFORM servers"). Org is Developer Edition, not sandbox, API 68.0. `/connect/api-catalog/...` returned NOT_FOUND (wrong path).
5. Not probed in this round: Setup UI, Apex class access. No writes (the later Live probe did write, and cleaned up).

## Open questions

Answered by the live probe: public versus global listing, Employee agent listing, Developer Edition create, custom URL, `McpServerDefinition` structure.

1. Does a client `tools/call` on a `public static` invocable method run, or fail at call time? Listing and adding succeeded; calling needs an activated server and a client.
2. Does an end-to-end call to the Employee agent tool work (agent GA versus blog "soon")?
3. Does the tool input and output schema match the Apex `@InvocableVariable` fields? The REST API returns no schema (see probe); only a client `tools/list` shows it.
4. Do `ExternalClientApplication` and its OAuth settings types deploy cleanly with `sf` for a new MCP client app?
5. Does `descriptionOverride` (seen in the retrieved XML) take effect on a tool description, and can it be set through REST?
6. Tool-call timeout and response size caps; Flex Credit price per Apex or agent call.
7. Does a non-admin user need Apex class access via permission set (we assume yes)?

## Recommendation for generic-agent

Smallest first step: expose `AccountBriefResolver` + `AccountBriefGetAction` (the brief needs a
resolved Id; without the resolver the client would need `sobject-reads` too) as two Apex-action
tools on one custom server `AccountBriefMcp`, on `experimental`, tested in Postman then Claude.
Leave ExploreAction and the agent for later. This keeps determinism and the user's identity.

1. Eligibility: the probe showed both classes are listed and addable while `public`. Decide
   before building, one of: (a) flip the three action classes and their `Request`/`Response`
   types to `global`; (b) add a thin `global` facade class for MCP that calls the same engine,
   which also keeps the agent-facing "relay it verbatim" descriptions out of MCP tool
   schemas. Not chosen here. If neither is done, test a real call on the `public` classes first.
2. Create the ECA per the setup section; scopes `mcp_api` + `refresh_token`; Claude callback.
   One existing External Client App in the org already carries an MCP scope (seen in the
   earlier probe); the baseline will use its own dedicated app instead of reusing it.
3. Tools: name `resolve_account` ("Find one Salesforce account from words or an open record;
   call before the brief") and `get_account_brief` ("Write a brief for one resolved account Id").
   Annotations: not `readOnlyHint`, because `AccountBrief` writes `AccountBriefMemory` (DML), so
   `readOnlyHint:false`, `destructiveHint:false`, `idempotentHint:false`, `openWorldHint:false`.
4. Activate; connect Claude; ask "brief me on <account>"; check the API log for
   `SALESFORCE_HOSTED_MCP` and that a user without access to the account gets NOT_FOUND.
5. Retrieve and commit: `sf project retrieve start --metadata McpServerDefinition:AccountBriefMcp`
   into `force-app/main/default/mcpServerDefinitions/`. Create steps use the REST calls in the
   Live probe section; the tool names there already work.

Can live in the repo as source: the Apex (already), the permission set granting class access,
`McpServerDefinition` (documented retrieve/deploy), possibly the ECA (unverified). Setup-only:
ECA consumer key/secret and approval, enabling MCP, activating the server, each client connector.
Do not use the Salesforce DX MCP server for this.

## Live probe (custom server)

Run 2026-11-11 against `experimental` (Developer Edition, API 68.0) through
`sf api request rest ... -o experimental` under `/services/data/v68.0/api-catalog/mcp-servers`.
One throwaway server `AccountBriefProbe`, never activated, deleted at the end. All verified.

**Create (verified).** `POST` with `{"name","label","description","type":"PLATFORM"}` returned
HTTP 201, `active:false`, `source:"CUSTOM"`, id `1g1000000000000AAA`, and
`serverUrl: https://api.salesforce.com/platform/mcp/v1/d/<my-domain>/develop/custom/AccountBriefProbe`.
So a Developer Edition org can create a custom hosted server, and the URL is the `api.salesforce.com`
`/v1/d/<my-domain>/develop/custom/<name>` form, not the `my.salesforce.com/services/mcp` form.

**Sources (verified).** `GET .../assets/available/sources` returned 9: `AURA_ENABLED`, `APEX_REST`,
`NAMED_QUERY`, `PLATFORM_AGENT`, `APEX_ACTION`, `FLOW_ACTION`, `PROMPT` (tool and prompt),
`CONNECT`, `PLATFORM_SERVER` (tool and prompt). Instances: `.../sources/<SOURCE>`; assets: `.../<id>?kind=MCP_TOOL`.

**Apex (verified).** `APEX_ACTION` returned 34 classes. All three of ours are listed although
they are `public with sharing` with `public static` methods:

| Class | Listed | Row |
|---|---|---|
| AccountBriefResolver | yes | `id: apex-AccountBriefResolver`, label "Resolve Account for Brief" |
| AccountBriefGetAction | yes | `id: apex-AccountBriefGetAction`, label "Get Account Brief" |
| ExploreAction | yes | `id: apex-ExploreAction`, label "Explore Data" |

`AccountBriefMemory` (also `public static`) is listed too, as are other classes in the org. The
asset row carries the Apex description as written ("...writes the brief. Relay the answer
verbatim."), which would reach MCP clients unless overridden. Finding: `public` invocable methods
are listed and can be added. Listing is not a call; calling is unverified.

**Agent (verified).** `PLATFORM_AGENT` returned 7 agents: six Salesforce-shipped ones and
`Account_Brief` ("Briefs a rep on one account ... Employee-facing."). The org's other agent is
not listed. Row for ours: `id: Account_Brief`; its asset is `assetId: "invoke"`, `name: "Account_Brief"`, `kind: MCP_TOOL`. So an Employee-type
Agent Script agent is eligible as a tool.

**Adding tools (verified, with deviations from the docs).**
- `PUT .../assets` body needs `assetId`, `kind`, `source`, `sourceId` (for Apex `sourceId` is
  `apex-<Class>`, not the bare class name: bare name gives 422 "Unknown or unavailable").
- A custom `name` in that PUT returned HTTP 500 ("Error while replacing MCP server asset
  whitelist"). With no `name`, or the listed name, it returns 200 and the tool is named
  `<Class>apex_<Class>`.
- Rename after adding with `PUT .../assets/<serverAssetId>` and `{"name":"resolve_account"}`
  (200). Names survive a later replace-style `PUT .../assets`.
- The agent needs a `name` in the PUT (omitted: 422, "text is null"); `Account_Brief` worked, then
  renamed to `ask_account_brief`. Final tools: `resolve_account`, `get_account_brief`, `ask_account_brief`.

**Schema and annotations (verified).** `GET .../assets` and `GET .../assets/<id>` return only
`id, name, label, description, kind, annotations`. No input or output schema is returned by the
REST API (`?includeSchema=true` is ignored, `/schema` is 404). Default annotations on every tool,
including the agent: `readOnlyHint:false, destructiveHint:false, idempotentHint:false,
openWorldHint:false, returnDirect:false`. So defaults are already explicit and non-read-only.
The real tool schemas are visible only to a client `tools/list` (unverified).

**Retrieved definition (verified).** `sf project retrieve start --metadata McpServerDefinition:AccountBriefProbe`
works; it needs a DX project root (`--output-dir` must be inside it). Structure of
`mcpServerDefinitions/AccountBriefProbe.mcpServerDefinition-meta.xml`: root `McpServerDefinition`,
children `description`, `masterLabel`, and one `tools` per tool. Each `tools` holds
`apiDefinition` (`apiIdentifier`, `apiSource`, `operation`), `descriptionOverride`, `destructive`,
`idempotent`, `openWorld`, `readOnly`, `returnDirect`, `toolName`, `toolTitle`. Values seen:
`apiIdentifier` `aa:apex-AccountBriefResolver` for Apex and `ag:Account_Brief` for the agent,
`apiSource` `API_CATALOG`, `operation` the class name or `invoke`. No `active` element and no
`<resources>` appeared, so activation state is not in source.

**Delete (verified).** `DELETE .../mcp-servers/<id>` returned 204; GET of that id is then 404;
the list shows 15 `STANDARD` servers and no `CUSTOM`; the tooling query finds 0
`McpServerDefinition`. Quirk: `sf api request rest -X DELETE` fails with "No 'mode' found in
'body' entry" unless an empty body file is passed (`--body @empty.txt`).

**Still unverified:** an end-to-end client tool call (and whether a `public` method runs), tool-call
timeout, per-call cost, non-admin user behaviour, client-visible schemas, `descriptionOverride`.

## Pages read

Hosted MCP guide (`developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/`): overview,
custom-servers, setup, ECA, log-into-org, activate, client pages (overview, claude), server-urls,
invocable-actions, agentforce, flows, prompt-builder, api-catalog, servers-reference, best
practices (general, security), beta-to-ga, end-of-life. Also the `llms*.txt` indexes;
`api-catalog-connectapi/guide/` create-custom-salesforce-mcp-servers (re-read for the probe) and
manage-external-mcp-servers; Agentforce `mcp`, `agent-dx-mcp`; hxl `hxl-mcp-server`; pkg2-dev
`dev2gp-package-mcp-agentforce`; the GA blog; `github.com/forcedotcom/mcp` issue 46; npm
`@salesforce/mcp`. Not readable: the Salesforce Help page (empty body), the Metadata API
`McpServerDefinition` reference (404). Not read: other client pages, standard server references.
