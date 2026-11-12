# MCP outside door: runbook (OPS-23)

- Date: 2026-11-12, 15:40 to 16:00 UTC. Org alias `agent-probe` only; `experimental` was not touched.
- CLI: `@salesforce/cli` 2.158.7, API 68.0.
- Approvals: "Org setup for the MCP server and its External Client App (stretch), up to the sign-in"
  and "Run OPS-23 in `agent-probe`" in `docs/plans/gtm-burn-plan.md`, Approvals. The deploy went
  through the standing approval for production-classified deploys to `agent-probe`.
- Status words: **verified** (seen in a command result in this run), **unproven** (not run, or
  inference).
- No record Ids, org Ids, usernames, emails, consumer keys, tokens or My Domain names are written
  here. `<alias>`, `<server-id>`, `<asset-id>` and `<my-domain>` stand for them.
- Background and the API quirks: [salesforce-mcp.md](salesforce-mcp.md). The pattern page:
  [09-outside-door-mcp.md](../patterns/09-outside-door-mcp.md).

## Plain answer

- **The door is built in agent-probe and stops at the sign-in (verified).** There is a custom
  hosted MCP server `AccountBriefMcp`. It is active and has three tools: `resolve_account`,
  `get_account_brief` and `ask_account_brief`. There is also a dedicated External Client App
  `AccountBriefMcpClient` with the scopes `MCP` and `RefreshToken` and PKCE. `MCP` is taken to be
  the documented `mcp_api` scope; that mapping is inference (see the table).
- **The server URL is live and asks for a token (verified).** An unauthenticated `tools/list` to
  it returned HTTP 401, `JWT Token is required`.
- **No tool has been called (unproven).** The first call needs Ben's OAuth sign-in (step 9). Still
  unknown: whether the `public` Apex methods run, the tool schemas a client sees, and how long a
  brief takes.
- **The metadata is in the repo, in its own package folder.** It lives in `mcp-door/`, a
  non-default package directory in `sfdx-project.json`. The README quick start and
  `scripts/validate-org.sh` deploy only `force-app`, so a fresh-org install does not pick it up.
  It is deployed on purpose with one command (see "Deploy mcp-door on purpose").

## What exists in agent-probe now

| Component | Type | State | How it was made |
|---|---|---|---|
| `AccountBriefMcpClient` | External Client App (`ExternalClientApplication` and its three settings types) | Deployed. Scopes `MCP` (taken to be `mcp_api`) and `RefreshToken`. PKCE required, consumer secret optional, named-user JWT on. Callbacks for Claude and Postman. Permitted users: admin-approved, through `Account_Brief_Data_Access` | Metadata deploy from `mcp-door/` (steps 1 and 2) |
| `AccountBriefMcp` | Custom hosted MCP server (`McpServerDefinition`), type `PLATFORM` | **Active** | API Catalog REST (steps 3, 5, 6 and 8) |
| `resolve_account` | Tool, source `APEX_ACTION`, `AccountBriefResolver` | Own description; all hints false | Step 5 and step 6 |
| `get_account_brief` | Tool, source `APEX_ACTION`, `AccountBriefGetAction` | Own description; all hints false | Step 5 and step 6 |
| `ask_account_brief` | Tool, source `PLATFORM_AGENT`, the `Account_Brief` agent | Own description; all hints false | Step 5 and step 6 |

Nothing else was created. No user was created, no permission set was assigned, no plugin was
installed, and no sign-in, consent screen or credential entry happened.

## Proven and not proven

| Claim | Status |
|---|---|
| An External Client App for MCP deploys from source with `sf` (four files, scope name `MCP`) | verified: validate 4 of 4 components and 159 of 159 Apex tests, then quick deploy |
| `MCP` is an accepted scope name in `commaSeparatedOauthScopes` | verified: the org's own error listed the valid names |
| `MCP` is the documented `mcp_api` scope | **unproven**: inference from the name; no other MCP-like name was in the list. Ben checks it in step 9 |
| An External Client App needs `contactEmail` to deploy, although the type marks it optional | verified: deploy error "Enter a valid contact email address." |
| A tool description set by `PUT .../assets/<asset-id>` is stored as `descriptionOverride` | verified: the retrieved `McpServerDefinition` holds the three new texts |
| The stripped `mcp-door/` set passes a check-only deploy | verified, against agent-probe, where the components already existed and the server was still inactive (an update check) |
| A custom server can be activated by `POST .../activate` with no Setup step | verified: HTTP 204, then `active: true` |
| The server URL refuses a call without a token | verified: HTTP 401, `JWT Token is required` |
| Deploying `mcp-door/` creates the server in an org that never had it | **unproven**: never run in a second org |
| A client sees only the override texts, not the Apex wording | **unproven**: needs a client `tools/list` |
| Input and output field descriptions (`@InvocableVariable`, including "Relay it verbatim.") stay out of the client schema | **unproven**: the override covers the tool description only |
| A `public static` invocable method runs when called as a tool | **unproven** |
| The agent tool answers end to end | **unproven** |
| The consent screen is skipped for users with `Account_Brief_Data_Access` (admin-approved policy) | **unproven** |
| The External Client App is usable right away | **unproven**: Salesforce documents up to 30 minutes after creation |

## Steps, in order

Each step says whether it changes the org. Steps 0 to 8 ran in agent-probe on 2026-11-12. Steps
9 and 10 are Ben's.

Prerequisites (not part of this card, already true in agent-probe): `force-app` deployed,
`Account_Brief` published and active, and `Account_Brief_Data_Access` assigned to the user who will
sign in. The tools point at those classes and that agent, and the client app's policy names that
permission set.

### 0. Read-only checks (changes the org: no)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers -o <alias>
sf data query --use-tooling-api -q "SELECT DeveloperName FROM McpServerDefinition" -o <alias>
sf org list metadata -m ExternalClientApplication -o <alias>
```

Before this run, agent-probe had 15 `STANDARD` servers (all inactive), 0 `McpServerDefinition`
and 0 External Client Apps (verified).

### 1. Check-only deploy of the client app (changes the org: no)

The four client-app files are in `mcp-door/main/default/` (`externalClientApps`,
`extlClntAppGlobalOauthSets`, `extlClntAppOauthSettings`, `extlClntAppOauthPolicies`). The contact
email is the placeholder `__MCP_CONTACT_EMAIL__`. A `replacements` entry in `sfdx-project.json`
fills it from the environment variable `MCP_CONTACT_EMAIL` at deploy time, so no email is
committed.

```bash
export MCP_CONTACT_EMAIL=<admin email>
sf project deploy start --dry-run --source-dir mcp-door --target-org <alias> --test-level NoTestRun --wait 10 --json
```

Two failed rounds came before the pass. The first lacked `contactEmail`. The second used the scope
`McpApi`, and the org replied with its list of valid names, which includes `MCP`. Before the server
existed, only the four client-app files were in `mcp-door/`.

### 2. Deploy the client app (changes the org: yes)

agent-probe is treated as production, so the deploy went validate, then quick deploy:

```bash
sf project deploy validate --source-dir mcp-door --target-org <alias> --test-level RunLocalTests --wait 4 --json
CONFIRM_PROD=1 sf project deploy quick --job-id <validation id> --target-org <alias> --wait 10 --json
```

Validate: 4 of 4 components, 159 of 159 tests, 15:47:54 to 15:50:58Z. Quick deploy: 4 components,
completed 15:52:07Z (verified). The org generated the consumer key; it is not in source.

### 3. Create the server (changes the org: yes)

`POST /services/data/v68.0/api-catalog/mcp-servers` with:

```json
{"name": "AccountBriefMcp", "label": "Account Brief", "type": "PLATFORM",
 "description": "Account briefs for one Salesforce account, as the signed-in user: resolve the account, then brief it, or ask the Account Brief agent."}
```

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers -X POST --body @create.json -o <alias>
```

HTTP 201, `active: false`, `source: CUSTOM`, created 15:50:56Z (verified). `name` and `type`
cannot change later. The `serverUrl` has the Developer Edition form
`https://api.salesforce.com/platform/mcp/v1/d/<my-domain>/develop/custom/AccountBriefMcp`.

### 4. List what can be added (changes the org: no)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets/available/sources/APEX_ACTION -o <alias>
sf api request rest /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets/available/sources/PLATFORM_AGENT -o <alias>
```

`APEX_ACTION` listed three of our classes (`apex-AccountBriefResolver`,
`apex-AccountBriefGetAction`, `apex-ExploreAction`), and `PLATFORM_AGENT` listed `Account_Brief`
(verified). The asset rows carry the Apex text "...writes the brief. Relay the answer verbatim.",
which is why step 6 replaces every description.

### 5. Add the three tools (changes the org: yes)

`PUT /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets` (this replaces the whole set):

```json
{"assets": [
  {"assetId": "AccountBriefResolver", "kind": "MCP_TOOL", "source": "APEX_ACTION", "sourceId": "apex-AccountBriefResolver"},
  {"assetId": "AccountBriefGetAction", "kind": "MCP_TOOL", "source": "APEX_ACTION", "sourceId": "apex-AccountBriefGetAction"},
  {"assetId": "invoke", "kind": "MCP_TOOL", "source": "PLATFORM_AGENT", "sourceId": "Account_Brief", "name": "Account_Brief"}
]}
```

HTTP 200 (verified). This follows the quirks recorded in [salesforce-mcp.md](salesforce-mcp.md):
Apex tools are added with no `name` (a custom name there gave HTTP 500), `sourceId` is
`apex-<Class>`, and the agent needs a `name`. Only this working path was run here; the failing
cases were not repeated. The Apex tools came back named `<Class>apex_<Class>`. All three got the
default hints, all false (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`,
`returnDirect`). That is what the design asks for, because a brief writes a memory row.

### 6. Rename and override the descriptions (changes the org: yes)

One `PUT /services/data/v68.0/api-catalog/mcp-servers/<server-id>/assets/<asset-id>` per tool with
`{"name": ..., "description": ...}`. All returned HTTP 200 (verified). The texts the client model
reads:

| Tool | Description |
|---|---|
| `resolve_account` | Find one Salesforce account from its name, part of its name, or an account Id. Returns RESOLVED with the account Id, AMBIGUOUS with candidates to choose from, or NOT_FOUND. Call this first; get_account_brief needs the Id it returns. |
| `get_account_brief` | Write a brief on one account, given an account Id that resolve_account returned as RESOLVED. Covers profile, open deals, cases, contacts and recent activity, as the signed-in user can see them. Optionally pass the question as asked, or the sections wanted. |
| `ask_account_brief` | Ask the Account Brief agent in plain language: a brief on one account, or a question about the CRM data the signed-in user can see. The agent finds the account itself and answers in prose. |

An apostrophe came back HTML-escaped (`&#39;`), so the texts avoid apostrophes. Edit tools only
while the server is inactive.

### 7. Retrieve into mcp-door (changes the org: no)

Retrieve in metadata format to a folder **outside** the repo. The retrieved files carry the
consumer key, the contact email and the org Id (verified). A plain source retrieve would also
place new components in `force-app`, the default package directory (unproven: not run; it is how
`sf` treats a component with no local file):

```bash
sf project retrieve start \
  --metadata McpServerDefinition:AccountBriefMcp \
  --metadata ExternalClientApplication:AccountBriefMcpClient \
  --metadata ExtlClntAppOauthSettings:AccountBriefMcpClient \
  --metadata ExtlClntAppGlobalOauthSettings:AccountBriefMcpClient \
  --metadata ExtlClntAppOauthConfigurablePolicies:AccountBriefMcpClient \
  --target-metadata-dir <folder outside the repo> --unzip --target-org <alias> --json
```

Then copy each file to `mcp-door/main/default/<folder>/<file>-meta.xml`, stripping as you go:

- Remove `<consumerKey>` (and `<consumerSecret>`, if present) from the global OAuth settings.
- Remove `<orgScopedExternalApp>` from the app and `<oauthLink>` from the OAuth settings. Both
  start with the org Id.
- Replace the `<contactEmail>` value with `__MCP_CONTACT_EMAIL__`.

Then run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_mcp_door`. It fails on any
consumer key or secret, client secret, Salesforce Id, email or `my.salesforce.com` host under
`mcp-door/`. A source-format retrieve into a git-ignored folder in the project returned no files
in this run, so use the metadata-format route above. The retrieved `McpServerDefinition` has no
`active` element, so activation is not in source (verified, as in the earlier probe).

### 8. Activate (changes the org: yes)

```bash
sf api request rest /services/data/v68.0/api-catalog/mcp-servers/<server-id>/activate -X POST --body @empty.json -o <alias>
```

(`empty.json` holds `{}`.) HTTP 204 at 15:54Z; a GET then shows `active: true` (verified). No
separate Setup toggle was needed for the API call. Whether Setup > API Catalog > MCP Servers also
shows an org-wide switch that must be on for a client call is unproven; check it in step 9.

A read-only check after activation (changes the org: no): a `tools/list` POST to the server URL
with no `Authorization` header returned HTTP 401, `{"errors":[{"message":"JWT Token is required"}]}`
(verified).

### 9. Ben signs in (changes the org: yes, an OAuth grant; **this card stopped here**)

1. Wait at least 30 minutes after step 2. Salesforce documents up to 30 minutes before a new
   External Client App works.
2. Check that the app's scopes read `mcp_api` and `refresh_token` in Setup > External Client App
   Manager > Account Brief MCP Client (the `MCP` mapping is unproven). Then get the consumer key
   from the app's OAuth settings (the exact Setup path is unproven here). Never paste it into the
   repo.
3. Log into agent-probe in the default browser, and out of other orgs.
4. Postman first, to see the raw tool JSON. Use OAuth 2.0, authorization code with PKCE, the
   consumer key, no secret, and the callback `https://oauth.pstmn.io/v1/callback` (Postman's
   usual callback; unproven, not read from a source in this run). Or use Claude:
   Customize > Connectors > Add custom connector, the server URL from step 3, "Use your own OAuth
   client", the consumer key, the secret left blank. Claude's callback
   `https://claude.ai/api/mcp/auth_callback` is already on the app.
5. Accept the consent screen if one appears. It may not: the policy is admin-approved for
   `Account_Brief_Data_Access` holders.

### 10. First real tool call, and what to measure (changes the org: yes; a brief writes one memory row)

Run `tools/list`, then `resolve_account` with "Edge Communications", then `get_account_brief` with
the returned Id, then `ask_account_brief` with "Give me a brief on Edge Communications". Record:

- Whether each call runs, which answers the `public` versus `global` question.
- The exact tool descriptions and the input and output schemas the client sees. Do the
  "Relay it verbatim." field descriptions show?
- The wall time of each call. For comparison, an agent turn that wrote a full brief took 32.6 s
  through `generateAiAgentResponse` ([org-migration.md](org-migration.md), two-turn check).
- The status and text returned, compared with the panel's fixed texts.
- The API log entry with `API_CLIENT_CATEGORY = SALESFORCE_HOSTED_MCP`.
- Later, as a user without access to the account: NOT_FOUND.

## Deploy mcp-door on purpose

The one command, for a non-production org that already has `force-app` deployed and the agent
published:

```bash
MCP_CONTACT_EMAIL=<admin email> sf project deploy start --source-dir mcp-door --target-org <alias> --wait 10 --json
```

For an org treated as production, use the same `--source-dir mcp-door` with
`sf project deploy validate ... --test-level RunLocalTests`, then `sf project deploy quick`, as in
step 2. Then activate (step 8): the active flag is not in source. That this deploy creates the
server in a new org is unproven (see the table above). If it does not, steps 3 to 6 make the
server through the API.

## Undo

- Deactivate: `POST .../mcp-servers/<server-id>/deactivate` (unproven: the path follows the
  activate call and has not been run).
- Delete the server: `DELETE .../mcp-servers/<server-id>` with `--body @empty.txt` returned 204
  for an inactive server in the earlier probe (verified there, not here).
- Remove the client app: a destructive deploy of `ExternalClientApplication:AccountBriefMcpClient`
  and its settings (unproven).

## Choices made here

- Callback URLs: Claude's and Postman's, both with no query string.
- Permitted users: admin-approved users, through the existing `Account_Brief_Data_Access`
  permission set, not "all users may self-authorize". Only users who can already run the actions
  can sign in.
- Refresh tokens: valid until revoked (`Infinite`). The org itself turned on refresh-token rotation
  and the refresh-token time limit on the app.
- Names: server `AccountBriefMcp`, client app `AccountBriefMcpClient`.
