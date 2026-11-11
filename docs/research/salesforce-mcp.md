# Salesforce MCP: exposing Apex actions and agents to outside clients

Researched 2026-11-11. Status words: documented (official page says it), verified (seen in the
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
4. One gap: docs say only a `global` `@InvocableMethod` qualifies. Ours are `public static`.
   Whether public methods are listed is not found; test it first (see Open questions).
5. A registered agent can also be a tool (source `PLATFORM_AGENT`), but only agents built with
   the new Agent Script builder. Account_Brief is an Agent Script bundle, so it should qualify.
   The April GA blog said "soon" for agents, so treat agent-as-tool as less proven than Apex.
6. The Salesforce DX MCP server (`@salesforce/mcp`) is a developer tool for sf CLI tasks, not a
   way to call our actions. It reached end of life on 2026-11-02.
7. Agentforce consuming outside MCP servers exists (Agentforce Registry / API Catalog) and does
   not matter for this baseline.
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
| Connected Apps are not supported; use an External Client App | documented | HMS/create-external-client-app.md |
| ECA scopes: `mcp_api` and `refresh_token`; "Issue JWT-based access tokens for named users" selected | documented | HMS/create-external-client-app.md |
| Claude callback URL `https://claude.ai/api/mcp/auth_callback` | documented | HMS/create-external-client-app.md |
| New ECA can take up to 30 minutes to become usable | documented | HMS/create-external-client-app.md |
| MCP servers are disabled by default; enable in Setup > API Catalog > MCP Servers; up to 2 minutes to activate | documented | HMS/activate-mcp-servers.md |
| Standard server URL: `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all`; custom prefix `custom/<name>` | documented | HMS/server-urls.md, hxl guide below |
| Developer Edition My Domain URL form `.../v1/d/<my-domain>/develop/<server-name>` | documented | HMS/server-urls.md |
| Org returned 15 STANDARD servers, all `active:false`, DE URL form `.../d/lets-get-experimental-dev-ed/develop/platform/sobject-all` | verified | org probe 4 below |
| Agent as tool: source `PLATFORM_AGENT`, kind `MCP_TOOL`; only agents from the new Agent Script builder | documented | HMS/agentforce.md, api-catalog-connectapi create-custom example |
| Agent/prompt tools run in the user's context, sharing and FLS apply | documented | HMS/agentforce.md |
| Blog at GA: "soon, you'll be able to invoke Agentforce agents via MCP" | documented | GA blog above (conflicts in tense with HMS/agentforce.md) |
| Prompt Builder: only published Flex templates, exposed as MCP prompts (Claude, Cursor support them; ChatGPT does not) or as tools | documented | HMS/prompt-builder.md; api-catalog-connectapi example |
| Our three classes are `public with sharing`, methods `public static`, not `global` | verified | `force-app/main/default/classes/*Action.cls`, `AccountBriefResolver.cls` |
| Account_Brief is an `AiAuthoringBundle` with `agent_type: "AgentforceEmployeeAgent"` | verified | `force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent` |
| Whether Employee-type agents can be MCP tools | not found | searched HMS/agentforce.md, api-catalog-connectapi; no agent_type statement |
| DX MCP server `@salesforce/mcp` EOL 2026-11-02, repo archived, package deprecated but installable; replaced by skills in `forcedotcom/sf-skills` | documented | `github.com/forcedotcom/mcp/issues/46` |

## Availability

- Status: GA (April 2026). Beta used old scopes and URL; the GA service needs `mcp_api` and a new URL (HMS/beta-to-ga-transition.md).
- Editions: documented "Enterprise Edition and above" (blog). The `experimental` org is a Developer Edition and serves the API-Catalog MCP endpoint (verified). That it can run an end-to-end tool call is unverified.
- Licence: Flex Credits (HMS overview). Prompt template tools consume credits per invocation (HMS/prompt-builder.md). Per-call price for Apex or agent tools: not found.
- API version: org on 68.0 (verified). Metadata type `McpServerDefinition` is listed by the org (verified). Minimum API version: not found.
- Client support: tested with Claude (claude.ai and Desktop; Claude Code inherits the connector), ChatGPT, Cursor, Postman, Agentforce Vibes (HMS/client-connection-overview.md, HMS/claude.md).
- Salesforce DX MCP server: was beta, now EOL (see table). `sf agent mcp` CLI commands (create, asset replace, list, fetch...) are Developer Preview (agentforce guide `agent-dx-mcp.md`); present in the installed CLI 2.154.4 (verified, `sf agent mcp --help`).

## What can be exposed

| Thing | Exposed how | Status | Source |
|---|---|---|---|
| Invocable Apex | custom server, source `APEX_ACTION`, tool | documented | HMS/invocable-actions.md |
| Autolaunched Flow | source `FLOW_ACTION`, tool; screen/scheduled flows excluded | documented | HMS/flows.md |
| Prompt template | source `PROMPT`, as MCP prompt or tool; Flex type only | documented | HMS/prompt-builder.md |
| Agentforce agent | source `PLATFORM_AGENT`, tool; Agent Script only | documented | HMS/agentforce.md |
| @AuraEnabled, Apex REST, Named Query, Connect/REST APIs | sources `AURA_ENABLED`, `APEX_REST`, `NAMED_QUERY`, `CONNECT` | documented | api-catalog-connectapi create-custom example |
| SOQL and record CRUD | standard servers `platform/sobject-reads`, `-mutations`, `-deletes`, `-all` (fixed, not editable) | documented; 4 of 15 seen in org | HMS/servers-reference.md; org probe 4 |
| Another hosted server's tools | source `PLATFORM_SERVER` | documented | api-catalog-connectapi create-custom example |

Our ExploreAction (SOQL via model-built plan) overlaps with `sobject-reads`; the Account brief is
the part that is unique to this baseline.

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
  - Connect API example response shows `https://<domain>.my.salesforce.com/services/mcp/<Name>` (documented, conflicts with the line above; use the `serverUrl` the org returns)
  - Developer Edition with My Domain: `.../v1/d/<my-domain>/develop/custom/<name>` is the pattern from the table; unverified for custom.

## Setup steps, in order

1. Check eligibility of the Apex (see Recommendation, step 1).
2. Setup > External Client App Manager > New. Enable OAuth; callback `https://claude.ai/api/mcp/auth_callback`; scopes `mcp_api`, `refresh_token`; select "Issue JWT-based access tokens for named users"; create; copy the consumer key. Wait up to 30 min. (HMS/create-external-client-app.md)
3. Setup > API Catalog > MCP Servers: create a custom server; add the Apex actions as tools; set names, descriptions, annotations; activate. Servers are off by default; activation takes up to 2 minutes.
4. Give users access: a permission set granting the Apex classes (unverified) and, if used, the ECA permission-set policy.
5. Log into the org in the default browser (log out of other orgs first; HMS/log-into-org.md).
6. Claude: Customize > Connectors > Add custom connector, server URL, own OAuth client, consumer key, Connect (HMS/claude.md). Test with Postman first to see raw tool JSON (HMS/client-connection-overview.md).

## Metadata types and source deploy

| Type | In org describe | Deploy from source with sf | Source |
|---|---|---|---|
| `McpServerDefinition` (`mcpServerDefinitions/*.mcpServerDefinition-meta.xml`) | verified | documented: `sf project retrieve start --metadata McpServerDefinition:<name>` and `sf project deploy start` | hxl guide; org probe 1 |
| `ExternalClientApplication` (`eca`), `ExtlClntAppOauthSettings`, `ExtlClntAppGlobalOauthSettings`, `ExtlClntAppOauthConfigurablePolicies` | verified (listed) | unverified: type names exist, no page read says an MCP ECA deploys cleanly; consumer key and secret are org-generated | org probe 1 |
| `ApexClass`, `PermissionSet` | n/a | yes (already in this repo) | repo |
| `AiAuthoringBundle` / `AiAgentDefinition` (Account_Brief) | verified (listed; org has `Account_Brief_1`, `Account_Brief_2`, `Account_Brief`) | yes (already in repo) | org probe 3; repo |
| `InvocableActionExtension`, `CatalogedApi`, `ApiNamedQuery` | verified (listed) | role in MCP: not found | org probe 1 |

Contents of `McpServerDefinition`: the hxl guide shows `<tools>` and `<resources>` children
(widget resources). Full field list: not found. The metadata reference page I guessed
(`.../api-metadata/references/meta-types/metadata-mcpserverdefinition.html`) returned 404. Retrieve
one real server after step 3 and commit that file as the source of truth.

Not in source: org enablement of standard servers, the ECA consumer key, the Claude connector,
users' OAuth grants. Whether `active` round-trips through deploy: not found.

## Limits and costs

- Client tool budget: "beyond a few dozen tools" clients pick badly; keep servers small per persona (HMS/custom-servers.html). Documented.
- Tool schema comes from the Apex Request/Response `@InvocableVariable` fields; complex or nested types are harder for clients (HMS/invocable-actions.md). Ours are flat strings. Documented.
- Changing the Apex signature needs the tool config updated in Setup (HMS/invocable-actions.md). Documented.
- No streaming or progress for long runs (stated for Flows, HMS/flows.md); assume the same for Apex (unverified). `AccountBriefGetAction` makes model calls inside Apex; the response time ceiling for a tool call: not found.
- Governor limits as normal Apex for the user. Callout and transaction limits unchanged. Documented.
- Billing: Flex Credits; Models API calls our brief makes are billed as they are today. Per-call MCP price: not found.
- ISV managed packages cannot yet bundle MCP server config (HMS/custom-servers.html), so a packaged baseline would ship the Apex and leave the server to the subscriber admin. Documented.

## Reverse direction: Agentforce consuming outside MCP servers

- Documented. Register an external MCP server in Agentforce Registry / API Catalog (`type: EXTERNAL`, OAuth or no auth); its tools are reviewed, allowlisted, and can become agent actions (`availableAsAgentAction`). Sources: api-catalog-connectapi `manage-external-mcp-servers.md`; `.../pkg2-dev/guide/dev2gp-package-mcp-agentforce.md` (packageable types ExternalCredential, ExternalServiceRegistration, NamedCredential, PermissionSet; MCP tool actions and gateway policies not packageable).
- Registration shows a tool-poisoning risk assessment (`securityWarning`).
- Matters for this baseline: not now. Our engine is Apex with no outside tool needs. Revisit only if the agent must call a third-party MCP server.

## Agent as an MCP tool

- Documented: the whole agent can be a tool, so a client delegates in natural language and Salesforce routes to the agent, which uses its own instructions and actions (HMS/agentforce.md). Source type `PLATFORM_AGENT` (api-catalog-connectapi example).
- Requirement: Agent Script builder agents only. Account_Brief is an authoring bundle (verified). Employee agent type: not found either way, so unverified.
- Tradeoffs: the agent reasons with an LLM and returns prose, while the actions are deterministic. HMS/agentforce.md itself recommends Apex actions or Flows when you want precise control. Agent calls cost agent credits (inference; per-call price not found).
- Even without exposing the agent, its actions (the three Apex classes) are exposable directly. That is the smaller step.

## Org probes (read-only, org alias `experimental`)

1. `sf org list metadata-types -o experimental`: lists `McpServerDefinition`, `ExternalClientApplication` (+ Extlclntapp* settings types), `AiAgentDefinition`, `AiAuthoringBundle`, `GenAiFunction`, `GenAiPlannerBundle`, `GenAiPromptTemplate`, `NamedCredential`, `ExternalAuthIdentityProvider`, `OauthCustomScope`, `OauthTokenExchangeHandler`, `ApiNamedQuery`, `CatalogedApi*`, `InvocableActionExtension`.
2. `sf data query --use-tooling-api "SELECT DeveloperName, MasterLabel FROM McpServerDefinition"`: 0 records. The same query without the tooling flag fails with INVALID_TYPE. Result: no custom MCP server exists. Also `sf org list metadata -m ExternalClientApplication` shows two ECAs (Plesio_Claude, Plesio_CI_Staging); their scopes were not read, so reuse for MCP is unverified.
3. `sf org list metadata -m AiAuthoringBundle` and `SELECT DeveloperName, Type FROM BotDefinition`: Account_Brief and Plesio_for_Slack exist, both type `InternalCopilot`; ApexClass query confirms the three action classes are deployed.
4. `sf api request rest /services/data/v68.0/api-catalog/mcp-servers` (GET): 15 `STANDARD` servers, all `active:false`: platform.sobject-all, -mutations, -reads, -deletes, content-readonly, content-write, metadata-experts, salesforce-api-context, agentforce-grid, headless-360, data.data360, data.data-cloud-queries, analytics.crma-beta, industries.engagement-interaction, industries.comms-offer-agent. `GET .../platform.sobject-all/assets` lists tool annotations. `GET .../assets/available/sources` on a standard server returns BAD_REQUEST ("only for custom PLATFORM servers"). Org is Developer Edition, not sandbox, API 68.0. `/connect/api-catalog/...` returned NOT_FOUND (wrong path).
5. Not probed: Setup UI, Apex class access, whether `mcp_api` scope exists on the org's ECA. No writes.

## Open questions

1. Do `public static` invocable methods show up under source `APEX_ACTION`? Docs say `global` only. If not, the classes and their Request/Response members must become `global` (Apex inference: global methods cannot use non-global parameter types; unverified).
2. Does an Employee-type Agent Script agent list under `PLATFORM_AGENT`? Is agent invocation GA or still rolling out (blog "soon" versus guide page)?
3. Does Developer Edition run custom hosted servers end to end, and what is the exact custom URL on it?
4. Do `ExternalClientApplication` and its OAuth settings types deploy cleanly with `sf` for an MCP client, and can the existing Plesio_Claude ECA take `mcp_api`?
5. Full `McpServerDefinition` schema and whether `active` and annotations round-trip on deploy.
6. Tool-call timeout and response size caps; Flex Credit price per Apex or agent call.
7. Does the user need Apex class access via permission set (we assume yes)?

## Recommendation for generic-agent

Smallest first step: expose `AccountBriefResolver` + `AccountBriefGetAction` (the brief needs a
resolved Id; without the resolver the client would need `sobject-reads` too) as two Apex-action
tools on one custom server `AccountBriefMcp`, on `experimental`, tested in Postman then Claude.
Leave ExploreAction and the agent for later. This keeps determinism and the user's identity.

1. Eligibility check in `experimental`: create the custom server (step 3) and open "Add Tools >
   Apex actions". If the two actions are listed, go on. If not, make the two classes and their
   inner `Request`/`Response` types `global` (repo change, own task) and redeploy.
2. Create the ECA per the setup section; scopes `mcp_api` + `refresh_token`; Claude callback.
3. Tools: name `resolve_account` ("Find one Salesforce account from words or an open record;
   call before the brief") and `get_account_brief` ("Write a brief for one resolved account Id").
   Annotations: not `readOnlyHint`, because `AccountBrief` writes `AccountBriefMemory` (DML), so
   `readOnlyHint:false`, `destructiveHint:false`, `idempotentHint:false`, `openWorldHint:false`.
4. Activate; connect Claude; ask "brief me on <account>"; check the API log for
   `SALESFORCE_HOSTED_MCP` and that a user without access to the account gets NOT_FOUND.
5. Retrieve and commit: `sf project retrieve start --metadata McpServerDefinition:AccountBriefMcp`
   into `force-app/main/default/mcpServerDefinitions/`.

Can live in the repo as source: the Apex (already), the permission set granting class access,
`McpServerDefinition` (documented retrieve/deploy), possibly the ECA (unverified). Setup-only:
ECA consumer key/secret and approval, enabling MCP, activating the server, each client connector.
Do not use the Salesforce DX MCP server for this.

## Pages read

Hosted MCP guide (all under `developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/`,
read as `.md` or `.html`): hosted-mcp-servers-overview, custom-servers, setup-overview,
create-external-client-app, log-into-org, activate-mcp-servers, client-connection-overview, claude,
server-urls, invocable-actions, agentforce, flows, prompt-builder, api-catalog,
products-supporting-mcp, servers-reference, general-best-practices, security-best-practices,
beta-to-ga-transition, test-connection, end-of-life. Also `llms.txt` indexes
(`/docs/llms.txt`, `llms-hosted-mcp-servers.txt`, `llms-api-catalog.txt`, `llms-genai.txt`);
`.../api-catalog-connectapi/guide/` get-started, create-custom-salesforce-mcp-servers,
manage-external-mcp-servers; `.../ai/agentforce/guide/` mcp, agent-dx-mcp;
`.../hxl/guide/` hxl-mcp-server, hxl-mcp-setup-org; `.../pkg2-dev/guide/dev2gp-package-mcp-agentforce`;
the GA blog; `github.com/forcedotcom/mcp` and issue 46; npm `@salesforce/mcp` 0.30.15 (`npm view`).
Not readable: Salesforce Help `api_catalog_manage_salesforce_hosted_mcp_servers` (page body empty
to the reader), the Metadata API `McpServerDefinition` reference (404), a Reddit community post
(blocked; not used). Not read: remaining guide pages (client pages for ChatGPT, Cursor, Postman,
Vibes; standard-server tool references; troubleshooting).
