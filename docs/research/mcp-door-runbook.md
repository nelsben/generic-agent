# MCP outside door: runbook (OPS-31, under the Customer Summary names)

- Date: 2026-11-13, 19:09 to 19:18 UTC. Org alias `agent-probe` only; `experimental` was not touched.
- CLI: `@salesforce/cli` 2.158.7, API 68.0.
- Approvals: "FR2: the MCP server and client app under the new names, up to the sign-in (OPS-31); the
  old server and app stay active" and "FR2: the explorer as an MCP tool for outside clients" in
  `docs/plans/gtm-burn-plan.md`, Approvals. Both read "approved" before the run. The deploy went
  through the standing approval for production-classified deploys to `agent-probe`.
- Status words: **verified** (seen in a command result in this run), **unproven** (not run, or
  inference).
- No record Ids, org Ids, usernames, emails, consumer keys, tokens or My Domain names are written
  here. `<alias>`, `<server-id>`, `<asset-id>`, `<my-domain>` and `<validation id>` stand for them.
- Background and the API quirks: [salesforce-mcp.md](salesforce-mcp.md). The pattern page:
  [09-outside-door-mcp.md](../patterns/09-outside-door-mcp.md).
- History: OPS-23 built the first door on 2026-11-12 as `AccountBriefMcp` and
  `AccountBriefMcpClient`, with the agent as a third tool. Both are still in agent-probe (see
  "Undo"). This run rebuilt the door under the new names with Apex-action tools only.

## Plain answer

- **The door is built in agent-probe under the new names and stops at the sign-in (verified).**
  There is a custom hosted MCP server `CustomerSummaryMcp`. It is active and has three tools, all
  Apex actions: `resolve_account`, `get_account_summary` and `ask_anything` (the explorer). The
  agent is not a tool. There is also a dedicated External Client App `CustomerSummaryMcpClient`
  with the scopes `MCP` and `RefreshToken` and PKCE. Its description now names the scopes the way
  its metadata does.
- **The server is live and its URL asks for a token (verified), but the 401 alone proves little.**
  An unauthenticated `tools/list` to the server's own URL returned HTTP 401,
  `JWT Token is required`. The same call to a made-up server name on the same path also returned
  401, and so did a call to `CustomerSummaryMcp` before it existed. The token check runs before the
  server lookup, so the proof that the server exists and is active is the API Catalog listing
  (`active: true`), not the 401.
- **No tool has been called.** The first call needs Ben's OAuth sign-in (step 9). What is proven
  about a real call is tracked in the README's [Status table](../../README.md#status).
- **The metadata is in the repo, in its own package folder.** It lives in `mcp-door/`, a
  non-default package directory in `sfdx-project.json`. The README quick start and
  `scripts/validate-org.sh` deploy only `force-app`, so a fresh-org install does not pick it up.
  It is deployed on purpose (see "Deploy mcp-door on purpose").

## What exists in agent-probe now

| Component | Type | State | How it was made |
|---|---|---|---|
| `CustomerSummaryMcpClient` | External Client App (`ExternalClientApplication` and its three settings types) | Deployed. Scopes `MCP` (taken to be `mcp_api`) and `RefreshToken`. PKCE required, consumer secret optional, named-user JWT on. Callbacks for Claude and Postman. Permitted users: admin-approved, through `Customer_Summary_Data_Access` | Metadata deploy from `mcp-door/` (steps 6 and 7) |
| `CustomerSummaryMcp` | Custom hosted MCP server (`McpServerDefinition`), type `PLATFORM` | **Active** | API Catalog REST (steps 1, 3, 4 and 8); the deploy in step 7 also carried its retrieved definition |
| `resolve_account` | Tool, source `APEX_ACTION`, `CustomerSummaryResolver` | Own description; all hints false | Steps 3 and 4 |
| `get_account_summary` | Tool, source `APEX_ACTION`, `CustomerSummaryGetAction` | Own description; all hints false | Steps 3 and 4 |
| `ask_anything` | Tool, source `APEX_ACTION`, `ExploreAction` | Own description; all hints false | Steps 3 and 4 |
| `AccountBriefMcp`, `AccountBriefMcpClient` | The OPS-23 server (still active, with its three old tools) and client app | Untouched by this run | Left from before the rename (see "Undo") |

Nothing else was created. No user was created, no permission set was assigned, no plugin was
installed, and no sign-in, consent screen or credential entry happened. The consumer key and
secret were not retrieved.

## Proven and not proven

| Claim | Status |
|---|---|
| A custom server with three `APEX_ACTION` tools and no agent tool can be built through the API Catalog | verified: steps 1, 3 and 4, then the retrieved `McpServerDefinition` lists exactly those three |
| `ExploreAction` is offered as an Apex tool | verified: listed under `APEX_ACTION` in step 2 and added in step 3 |
| Deploying `mcp-door/` over a server that already has its tools leaves the tools as they were | verified: the tool list after the quick deploy matched the one before it (step 7) |
| `mcp-door/` validates with RunLocalTests and quick deploys | verified: 5 of 5 components and 277 of 277 Apex tests, then quick deploy of 5 components |
| A custom server can be activated by `POST .../activate` with no Setup step | verified: HTTP 204, then `active: true` |
| The server URL refuses a call without a token | verified: HTTP 401, `JWT Token is required` |
| An unauthenticated 401 shows that a server exists | **no**: a made-up server name and a not-yet-created server got the same 401 |
| `MCP` is the documented `mcp_api` scope | **unproven**: inference from the name. Ben checks it in step 9 |
| Deploying `mcp-door/` creates the server in an org that never had it | **unproven**: never run in a second org |
| A client sees only the override texts, not the Apex wording | **unproven**: needs a client `tools/list` |
| Input and output field descriptions (`@InvocableVariable`, including "Relay it verbatim.") stay out of the client schema | **unproven**: the override covers the tool description only |
| A real tool call, including whether `public` invocable methods run | See the README's [Status table](../../README.md#status) |
| The consent screen is skipped for users with `Customer_Summary_Data_Access` (admin-approved policy) | **unproven** |
| The External Client App is usable right away | **unproven**: Salesforce documents up to 30 minutes after creation |

## Steps, in order

Each step says whether it changes the org. Steps 0 to 8 ran in agent-probe on 2026-11-13. Steps
9 and 10 are Ben's. Unlike OPS-23, this run built the server first and deployed the client app
after, so the deploy could carry the server's retrieved definition too.

Prerequisites (not part of this card, already true in agent-probe): `force-app` deployed with the
Customer Summary classes and `ExploreAction`, and `Customer_Summary_Data_Access` in the org and
assigned to the user who will sign in. The tools point at those classes, and the client app's
policy names that permission set. The Salesforce plugin's deploy gate needs a default org in the
project, so `sf config set target-org <alias>` was run in the project first (a local, git-ignored
setting).

### 0. Read-only checks (changes the org: no)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers -o <alias>
sf org list metadata -m ExternalClientApplication -o <alias>
sf org list metadata -m PermissionSet -o <alias>
```

Before this run (verified): the custom servers were `AccountBriefMcp` only (active), there was no
`CustomerSummaryMcp`, the only External Client App was `AccountBriefMcpClient`, and
`Customer_Summary_Data_Access` existed. An unauthenticated `tools/list` to the would-be
`CustomerSummaryMcp` URL already returned HTTP 401 (see the plain answer).

### 1. Create the server (changes the org: yes)

`POST /services/data/v68.0/api-catalog/mcp-servers` with:

```json
{"name": "CustomerSummaryMcp", "label": "Customer Summary", "type": "PLATFORM",
 "description": "Account summaries and data questions for Salesforce, as the signed-in user: resolve an account, then summarize it, or ask anything about the CRM data the user can see."}
```

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers -X POST --body @create.json -o <alias>
```

HTTP 201, then a GET showed `active: false`, `source: CUSTOM` (verified). `name` and `type`
cannot change later. The `serverUrl` has the Developer Edition form
`https://api.salesforce.com/platform/mcp/v1/d/<my-domain>/develop/custom/CustomerSummaryMcp`.

### 2. List what can be added (changes the org: no)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets/available/sources/APEX_ACTION -o <alias>
```

`APEX_ACTION` listed `CustomerSummaryResolver`, `CustomerSummaryGetAction` and `ExploreAction`,
plus the two old `AccountBrief...` classes (verified; this run listed them on the old server's
id, which shows the same org-wide set). `PLATFORM_AGENT` was not used: the agent is not a tool.

### 3. Add the three tools (changes the org: yes)

`PUT /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets` (this replaces the whole set):

```json
{"assets": [
  {"assetId": "CustomerSummaryResolver", "kind": "MCP_TOOL", "source": "APEX_ACTION", "sourceId": "apex-CustomerSummaryResolver"},
  {"assetId": "CustomerSummaryGetAction", "kind": "MCP_TOOL", "source": "APEX_ACTION", "sourceId": "apex-CustomerSummaryGetAction"},
  {"assetId": "ExploreAction", "kind": "MCP_TOOL", "source": "APEX_ACTION", "sourceId": "apex-ExploreAction"}
]}
```

HTTP 200 (verified). As in [salesforce-mcp.md](salesforce-mcp.md), the Apex tools are added with
no `name` and `sourceId` is `apex-<Class>`. They came back named `<Class>apex_<Class>`, with the
default hints, all false (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`,
`returnDirect`). The hints were left there: a summary writes a memory row, so it is not read-only.
`ask_anything` runs read-only queries but also calls a model, and it keeps the same defaults as the
other two.

### 4. Rename and override the descriptions (changes the org: yes)

One `PUT /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets/<asset-id>` per tool with
`{"name": ..., "description": ...}`. All returned HTTP 200 (verified). The texts the client model
reads:

| Tool | Description |
|---|---|
| `resolve_account` | Find one Salesforce account from its name, part of its name, or an account Id. Returns RESOLVED with the account Id, AMBIGUOUS with candidates to choose from, or NOT_FOUND. Call this first; get_account_summary needs the Id it returns. |
| `get_account_summary` | Write a summary of one account, given an account Id that resolve_account returned as RESOLVED. Covers profile, open deals, cases, contacts and recent activity, as the signed-in user can see them. Optionally pass the question as asked, or the sections wanted. |
| `ask_anything` | Answer a question about the Salesforce data the signed-in user can see, such as which open deals close this quarter or which accounts have the most open cases. Runs safe, read-only queries and returns the answer with a short table of the last result. Pass the question in plain words; for a follow-up, also pass the History value the previous answer returned. |

The texts avoid apostrophes, which came back HTML-escaped in OPS-23. Edit tools only while the
server is inactive.

### 5. Retrieve the server into mcp-door (changes the org: no)

Retrieve only the server definition, in metadata format, to a folder **outside** the repo. Do not
retrieve the client app's settings: the global OAuth settings carry the consumer key.

```bash
sf project retrieve start --metadata McpServerDefinition:CustomerSummaryMcp \
  --target-metadata-dir <folder outside the repo> --unzip --target-org <alias> --json
```

The retrieved file held no Id, email or host (verified). It was copied to
`mcp-door/main/default/mcpServerDefinitions/CustomerSummaryMcp.mcpServerDefinition-meta.xml`. The
client app's description in `externalClientApps/CustomerSummaryMcpClient.eca-meta.xml` was changed
by hand to name the scopes `MCP` and `RefreshToken`, as its OAuth settings do. Then
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_mcp_door` passed. It checks the tool
list (three Apex actions, no agent), the scope names in the description, and that nothing under
`mcp-door/` holds a consumer key or secret, a Salesforce Id, an email or a `my.salesforce.com` host.
The retrieved `McpServerDefinition` has no `active` element, so activation is not in source.

### 6. Validate the deploy (changes the org: no)

The contact email is the placeholder `__MCP_CONTACT_EMAIL__`. A `replacements` entry in
`sfdx-project.json` fills it from the environment variable `MCP_CONTACT_EMAIL` at deploy time. The
value is the running admin user's email, read from the org in the same shell command and never
printed, exported or written to a file:

```bash
MCP_CONTACT_EMAIL="$(sf api request rest /services/data/v68.0/chatter/users/me -o <alias> \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("email") or "")')" \
  sf project deploy validate --source-dir mcp-door --target-org <alias> --test-level RunLocalTests --wait 4 --json
```

Stop if the email comes back empty. Validate: 5 of 5 components (the server definition and the
four client-app files), 277 of 277 Apex tests, 19:14:04 to 19:17:11Z (verified).

### 7. Quick deploy (changes the org: yes)

```bash
MCP_CONTACT_EMAIL="<read as in step 6>" CONFIRM_PROD=1 sf project deploy quick --job-id <validation id> --target-org <alias> --wait 10 --json
```

5 components, completed 19:17:39Z (verified). The org generated the consumer key; it is not in
source and was not read. A GET of the server's tools after the deploy showed the same three tools,
names, descriptions and hints as before it (verified).

### 8. Activate (changes the org: yes)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers/<server-id>/activate -X POST --body @empty.json -o <alias>
```

(`empty.json` holds `{}`.) HTTP 204 at 19:18Z; the API Catalog then lists `CustomerSummaryMcp`
with `active: true` (verified).

A read-only check after activation (changes the org: no), at 19:18Z: a `tools/list` POST with no
`Authorization` header to the server's own `serverUrl` returned HTTP 401,
`{"errors":[{"message":"JWT Token is required"}]}` (verified). The control, the same POST to a
made-up server name on the same path, returned the same 401. So the 401 shows the token gate, and
the API Catalog listing shows the server.

### 9. Ben signs in (changes the org: yes, an OAuth grant; **this card stopped here**)

1. Wait at least 30 minutes after step 7. Salesforce documents up to 30 minutes before a new
   External Client App works.
2. Check that the app's scopes read `mcp_api` and `refresh_token` in Setup > External Client App
   Manager > Customer Summary MCP Client (the `MCP` mapping is unproven). Then get the consumer key
   from the app's OAuth settings (the exact Setup path is unproven here). Never paste it into the
   repo.
3. Log into agent-probe in the default browser, and out of other orgs.
4. Postman first, to see the raw tool JSON. Use OAuth 2.0, authorization code with PKCE, the
   consumer key, no secret, and the callback `https://oauth.pstmn.io/v1/callback` (Postman's
   usual callback; unproven, not read from a source in this run). Or use Claude:
   Customize > Connectors > Add custom connector, the server URL from step 1, "Use your own OAuth
   client", the consumer key, the secret left blank. Claude's callback
   `https://claude.ai/api/mcp/auth_callback` is already on the app.
5. Accept the consent screen if one appears. It may not: the policy is admin-approved for
   `Customer_Summary_Data_Access` holders.

Use the new server and app, not the old `AccountBriefMcp` ones.

### 10. First real tool call, and what to measure (changes the org: yes; a summary writes one memory row)

Run `tools/list`, then `resolve_account` with "Edge Communications", then `get_account_summary`
with the returned Id, then `ask_anything` with "Which open deals close this quarter?". Record:

- Whether each call runs, which answers the `public` versus `global` question.
- The exact tool descriptions and the input and output schemas the client sees. Do the
  "Relay it verbatim." field descriptions show? Does the `History` field of `ask_anything` show?
- The wall time of each call. For comparison, an agent turn that wrote a full brief took 32.6 s
  through `generateAiAgentResponse` ([org-migration.md](org-migration.md), two-turn check).
- The status and text returned, compared with the panel's fixed texts.
- The API log entry with `API_CLIENT_CATEGORY = SALESFORCE_HOSTED_MCP`.
- Later, as a user without access to the account: NOT_FOUND.

Then update the README's [Status table](../../README.md#status).

## Deploy mcp-door on purpose

The one command, for a non-production org that already has `force-app` deployed:

```bash
MCP_CONTACT_EMAIL=<admin email> sf project deploy start --source-dir mcp-door --target-org <alias> --wait 10 --json
```

For an org treated as production, use the same `--source-dir mcp-door` with
`sf project deploy validate ... --test-level RunLocalTests`, then `sf project deploy quick`, as in
steps 6 and 7. Then activate (step 8): the active flag is not in source. That this deploy creates
the server in a new org is unproven (see the table above). If it does not, steps 1 to 4 make the
server through the API.

## Undo

- Deactivate: `POST .../mcp-servers/<server-id>/deactivate` (unproven: the path follows the
  activate call and has not been run).
- Delete the server: `DELETE .../mcp-servers/<server-id>` with `--body @empty.txt` returned 204
  for an inactive server in the earlier probe (verified there, not here).
- Remove the client app: a destructive deploy of `ExternalClientApplication:CustomerSummaryMcpClient`
  and its settings (unproven).
- `AccountBriefMcp` (server, still active) and `AccountBriefMcpClient` (client app): left from
  before the rename; removal needs Ben's go. This run did not deactivate or delete them. Removing
  them is `OPS-54`, which waits on its own Approvals row.

## Choices made here

- Callback URLs: Claude's and Postman's, both with no query string.
- Permitted users: admin-approved users, through the existing `Customer_Summary_Data_Access`
  permission set, not "all users may self-authorize". Only users who can already run the actions
  can sign in.
- Refresh tokens: valid until revoked (`Infinite`), as in OPS-23.
- Names: server `CustomerSummaryMcp`, client app `CustomerSummaryMcpClient`, explorer tool
  `ask_anything`.
- Tools: Apex actions only. The agent is not a tool (the plan review's call in
  `docs/plans/feature-revision-2.md`). Write tools (create a task, log a call) come later in
  `OPS-59`.
- Hints: the defaults, all false, for all three tools.
