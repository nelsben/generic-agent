# Calling Account_Brief programmatically (OPS-5)

Researched 2026-11-11; live probe run 2026-11-11 (OPS-6). Status words: documented (official
page says it), verified (seen in the `experimental` org), unverified (community source,
search-result summary or inference).

## Plain answer

- Outside Salesforce: the Agent API (REST, `api.salesforce.com`) can start a session, send
  messages, stream or receive replies and end the session. Its only stated exclusion is the
  "Agentforce (Default)" agent type. No official page says Employee agents ARE supported, and
  none says they are excluded. Account_Brief is `AgentforceEmployeeAgent`. Support is unproven.
- The Agent API's documented auth is an External Client App with the client credentials flow
  and `bypassUser=true`, which runs as the agent's assigned user. An Employee agent runs as the
  logged-in user and has no assigned user, so that exact recipe likely does not fit it
  (inference). A user-bound token with `bypassUser=false` is the probable route (unverified).
- Inside the same org (Apex or LWC): the custom agent invocable action
  `generateAiAgentResponse` works for Account_Brief. Verified live: two Apex calls returned
  replies about the right account, the second without naming it, in the same session. Inputs
  are `userMessage` and `sessionId`; outputs are `agentResponse` and `sessionId`. The reply
  string is a JSON envelope, `{"type":"Text","value":"..."}`, not bare text. It took 14 to 18
  seconds per turn. See "Live probe".
- Apex calling the Agent API through a Named Credential is possible in principle but needs an
  External Client App and a user-context token. It is the heavier path.
- Next step: wrap the action in an `@AuraEnabled` method for the panel (message, sessionId in;
  reply, sessionId out). Still unverified: a non-admin user, an Apex test, session lifetime.

## Facts

| Fact | Status | Source |
|---|---|---|
| Agent API: start session, send message (sync and streaming), end session, submit feedback | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-lifecycle.html |
| "The Agent API isn't supported for agents of type 'Agentforce (Default)'." Decides type support; no other type is named | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html |
| No official page found that lists Employee agents as supported or excluded. Searched: Agent API guide (get-started, lifecycle, examples, considerations, troubleshooting, variables), reference, Agent Script blocks, two web searches | not found | pages above |
| Agent Script `agent_type` values: `AgentforceServiceAgent` (default) or `AgentforceEmployeeAgent` | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html |
| Start: `POST https://api.salesforce.com/einstein/ai-agent/v1/agents/{AGENT_ID}/sessions` | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html (path shown for Gov Cloud host; same path otherwise) |
| Start body: `externalSessionKey` (UUID) and `instanceConfig.endpoint` (My Domain URL) required; `tz`, `variables`, `featureSupport` (Sync or Streaming), `streamingCapabilities`, `bypassUser` optional | documented | https://developer.salesforce.com/docs/ai/agentforce/references/agent-api (startSession) |
| Send sync: `POST /sessions/{id}/messages`, body `message {type:"Text", sequenceId, text}`; sequenceId rises each message | documented | same reference; https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-examples.html |
| Send streaming: `POST /sessions/{id}/messages/stream`, header `Accept: text/event-stream`, SSE | documented | same reference |
| End: `DELETE /sessions/{id}` with header `x-session-end-reason` (UserRequest, Transfer, Expiration, Error, Other) | documented | same reference |
| Feedback: `POST /sessions/{id}/feedback` (GOOD or BAD, stored in Data 360) | documented | same reference |
| Streaming events: ProgressIndicator, TextChunk, Inform (whole message), EndOfTurn, ValidationFailureChunk (discard earlier chunks) | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-examples.html |
| Reply is plain text in the message; citations arrive in `citedReferences` of the Inform message, as trailing sources or inline (`inlineMetadata`) | documented | agent-api-examples.html |
| Rich or Lightning Type results in the Agent API reply | not found. The reference schemas (InformMessage etc.) render only as "Loading", so the field list was not read. Not needed for Account_Brief, which returns text | https://developer.salesforce.com/docs/ai/agentforce/references/agent-api |
| Variables: array on start and on send. `$Context.*` set at start only, except `$Context.EndUserLanguage`. Drop `__c` for custom fields | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-variables.html |
| Custom variables must have "Allow value to be set by API" (ConversationVariable `visibility: external`) | documented | agent-api-variables.html |
| Passing a record Id: no dedicated parameter. It goes as a variable (for example `$Context.RecordId`); that name is not shown on any page read | not found for the exact name | agent-api-variables.html |
| Account_Brief declares no context variables. Its `briefed_account_id` is a mutable variable filled by the resolve action | verified (source) | force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent |
| Agent Script `runtime.streaming` controls incremental delivery; `runtime.citation` toggles citations | documented | ascript-blocks.html |
| ECA scopes: `api`, `refresh_token, offline_access`, `chatbot_api`, `sfap_api`; enable Client Credentials Flow; JWT-based access tokens for named users; Run As user with at least API Only access | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html |
| Token request uses My Domain (not `lightning.force.com`) | documented | agent-api-get-started.html |
| `bypassUser=true` uses the agent-assigned user; `false` uses the token's user. Set true for client credentials | documented | agent-api-get-started.html, reference above |
| Agent API is GA-style (v1.0.0, no beta label); editions and licences | not found | reference above |
| Gov Cloud host is `api.gov.salesforce.com` | documented | agent-api-considerations.html |
| 120-second timeout; a timeout returns HTTP 500 | documented | agent-api-considerations.html |
| HTTP 423 if a request is already in progress: one request at a time per session | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-troubleshooting.html |
| 429 "Too many requests" exists. No numeric rate limit published | documented (code), not found (number) | reference above |
| Agent API use consumes credits; see "Generative AI Usage and Billing" | documented | agent-api-considerations.html |
| Session expiry time | not found | searched lifecycle, considerations, troubleshooting |
| Flow: AI Agent action per active agent; inputs user message and optional session Id; outputs response and session Id | documented | https://developer.salesforce.com/blogs/2025/04/invoke-agentforce-agents-with-apex-and-flow (blog, official) |
| Apex: build a custom agent invocable action with the agent API name, pass user message and optional session Id, invoke via the Invocable Action API | documented | same blog |
| Same blog: "trigger any active Agentforce agent"; it describes employee-facing agents as using the user's permissions | documented (blog, not reference) | same blog |
| `generateAiAgentResponse` version 1.0.0 returns text, 1.1.0 structured output; Apex tests not supported for it; Flow use only in asynchronous paths; not for Experience Cloud site users; needs Manage AI Agents permission; Flow element moved to Run Agent in API 67.0 | unverified: from a web-search summary of help.salesforce.com pages whose bodies would not render in the browser | Salesforce Help article `ai.agent_custom_invocable_action_apex_example.htm` , Salesforce Help article `ai.agent_custom_invocable_action_flow_apex.htm` |
| LWC calls the agent through an Apex method that runs the invocable action | documented | invoke-agentforce-agents blog above |
| Headless sync prompt "lasts tens of seconds"; SSE recommended for UI | documented | https://developer.salesforce.com/blogs/2025/04/build-headless-agents-with-the-agent-api |
| A community answer says Employee agent sessions work via the Agent REST API from Apex or LWC | unverified (community, shorter path than official) | a Trailblazer Community feed post (link removed in the privacy pass) |

## Availability

- Agent API: documented as v1.0.0; needs Agentforce enabled and at least one agent activated
  (agent-api-get-started.html). GA, beta or pilot status, editions and licences: not found.
- In-org invocable action and Flow AI Agent action: blog dated 2025-04. Edition and licence
  terms: not found. Experimental org API version is 68.0 (verified, `sf org display`).

## Setup steps

Route A, in-org Apex and LWC (recommended first):
1. Confirm the running user has Agentforce and Manage AI Agents (unverified, see table).
2. Apex: `Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief')`,
   set `userMessage` and, for turn 2 and later, `sessionId`; invoke; read the reply and the
   returned session Id. Parameter names `userMessage`, `sessionId`: verified (describe).
3. Wrap in an `@AuraEnabled` method; the LWC holds the session Id between turns.
4. Pass the open record by writing it into the message text, for example
   "Brief account 001...". The route-gather-reduce agent already accepts an Id.

Route B, outside Salesforce (Agent API):
1. Create an External Client App with the scopes above and client credentials (documented).
2. Get the agent Id (BotDefinition `<agent id>`, verified).
3. For an Employee agent, expect to need a user-bound token and `bypassUser=false` (unverified).
4. Start session, send messages with increasing `sequenceId`, end session.
5. Test whether start-session accepts the Employee agent before building anything on it.

Route C, Apex to Agent API: as Route B, plus a Named Credential and External Credential
holding the token flow. The org already has Named Credentials for other services (verified
list), but none for the Agent API.

## Metadata types and deploy from source

| Type | In org | Deploys with sf |
|---|---|---|
| ExternalClientApplication, ExtlClntAppOauthSettings | verified: two existing External Client Apps; retrieved fine | yes (retrieve worked; ECA policy and secrets need care) |
| NamedCredential, ExternalCredential | verified: five Named Credentials for other services | yes |
| AiAuthoringBundle (agent), GenAiPlannerBundle | verified: Account_Brief bundle and `Account_Brief_v1` planner | yes |
| ConversationVariable, ConversationContextVariable | documented as the variable metadata | yes (Metadata API) |
| Agent-specific invocable action | no metadata; it is generated per active agent (verified) | n/a |

## Org probes (read-only, org `experimental`)

- `SELECT ... FROM BotDefinition`: Account_Brief `<agent id>`, Type `InternalCopilot`,
  AgentType `AgentforceEmployeeAgent`. Also a second agent, same types.
- `BotVersion`: Account_Brief v1 `0X9000000000000AAA` is Active. The second agent's v1 is Inactive.
- `ExternalClientApplication`: two existing apps. Their OAuth scopes are Api, Web,
  RefreshToken and RefreshToken, MCP. Neither has `chatbot_api` or `sfap_api`, so
  neither is an Agent API app. No ConnectedApplication query was usable (field names rejected).
- `GET /services/data/v68.0/actions/custom`, then `/generateAiAgentResponse`: lists one action,
  `Account_Brief`, type `GENERATE_AI_AGENT_RESPONSE`. The second, inactive agent is absent.
  This showed the action exists; the probe below then invoked it.
- `sf org list metadata` for NamedCredential and GenAiPlannerBundle matched the table above.

## Limits and cost

- 120 s per call, HTTP 500 on timeout; one request at a time per session (423); 429 exists
  with no published number (all documented). Session expiry and rate limits: not found.
- Credits: Agent API use consumes them (documented). Whether the in-org invocable action
  meters differently: not found. Assume each turn costs the same as a chat turn.
- Account_Brief answers are capped well under about 6K characters (ARCHITECTURE.md), far
  below any timeout risk, but a brief runs several actions and a model call: expect tens of
  seconds (the blog says sync calls last "tens of seconds").

## Other in-org options and whether the reply comes back

| Option | Reply to the caller | Status |
|---|---|---|
| Apex + `generateAiAgentResponse` | yes: reply text and session Id | documented (blog), details unverified |
| Flow AI Agent action | yes, as an output variable | documented |
| Apex calling the Agent API via Named Credential | yes (sync body or SSE; Apex cannot stream) | documented API, inference for Apex |
| ConnectApi classes for agents | not found: nothing read or surfaced in searches | not found |
| LWC calling `api.salesforce.com` directly | not recommended: needs a token in the browser and a CSP/CORS allowance | unverified inference |

## Live probe (generateAiAgentResponse)

Run 2026-11-11 in `experimental` as the org's admin user, `sf apex run`, 2 invocations.

Describe, `GET /services/data/v68.0/actions/custom/generateAiAgentResponse/Account_Brief`
(verified): type `GENERATE_AI_AGENT_RESPONSE`, `hasCallout` true.

| Direction | Name | Type | Required |
|---|---|---|---|
| input | `userMessage` | STRING | yes |
| input | `sessionId` | STRING | no |
| output | `agentResponse` | STRING | n/a |
| output | `sessionId` | STRING | n/a |

Account picked at run time: the most recently modified Account with an Opportunity (name
shown below as `<account>`). Turn 1 Apex (verified, ran as written):

```apex
Invocable.Action a = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief');
a.setInvocationParameter('userMessage', 'Give me a brief on <account>');
List<Invocable.Action.Result> rs = a.invoke();   // turn 2 also sets 'sessionId'
Map<String,Object> o = rs[0].getOutputParameters(); // keys agentResponse, sessionId
```

Results (each verified):

- Pass: turn 1 returned a non-empty reply about the picked account (1271 chars).
- Pass: a session Id came back (a UUID, for example `01a1cb57-...`). Turn 2 returned the
  same Id.
- Pass: turn 2, in a separate execution with the Id as a literal and the message `What about
  its open cases?`, answered about the same account without it being named (136 chars).
- `isSuccess` true and `getErrors()` empty on both turns. Nothing failed.
- Timing: turn 1 18.1 s, turn 2 13.8 s (wall clock around `invoke()`).
- Caller transaction counts: callouts 0 and DML 0 on both turns, although the describe says
  `hasCallout` true. The agent's own work does not show in the caller's limits.

Reply, first 300 characters, turn 1 (verified):
`{"type":"Text","value":"<account> Insurance faces an overdue new business opportunity with
zero pipeline value and silent engagement from the sole contact.\n\nAccount <account> is an
insurance company that became an account on August 5, 2026. The account is owned by <owner>.
No parent organizatio`

Reply, turn 2, whole text (verified):
`{"type":"Text","value":"<account> has no open cases. All cases associated with this account
are either closed or there are no cases at all."}`

Reply is not the action's text verbatim (verified). The brief text saved on the session row
(`Last_Brief__c`, 1156 chars) differs from turn 1's reply in three ways: the section label and
its body were joined on one line ("Open deals One open deal..."), the "- " bullets under
Watch next became plain lines, and the agent added a closing question ("Would you like more
details on <account>'s contacts, activity, or another area?"). The prompt asks for none of
that. So the agent rewrites lightly despite "reply verbatim". The panel should render the
`value` field and expect small format changes.

Turn 2 did not call the brief action (verified): the session row's `Turns_JSON__c` has no
entry for it and the row's LastModifiedDate did not move. The agent answered the case
question itself. Its "no open cases" matches turn 1's "No cases are open or on record".
It did not run a fresh case query (inference from the missing entry; not tested).

User context, partial check (verified): `Account_Brief_Session__c` is one row per user and
account, updated in place. The row for this account was created earlier by the same user
(`CreatedById` equals the running user from `sf org display user`) and turn 1 updated it
(`LastModifiedById` equals the running user too; no new row was created, Brief_Count 2). The
probe ran as the admin user, so this does not show a non-admin user is handled correctly.

## Open questions

1. Does the Agent API start-session accept an `AgentforceEmployeeAgent`? Not tested; this
   probe did not use the Agent API. Only matters for callers outside Salesforce.
2. Does the action run Account_Brief with the calling user's record access? The session row
   is written as the calling user, which fits. Record visibility for a non-admin user was not
   tested.
3. Does the action work for a non-admin user? It needs Manage AI Agents (unverified, from a
   search summary). Not tested.
4. Can the action run inside an Apex test? The summary says Apex tests are not supported
   (unverified). Not tested; the panel's Apex wrapper would need a stub seam.
5. Session lifetime and a rate limit number: not found, not tested. Turn 2 reused a session
   created about 30 seconds earlier.
6. Is the 1.1.0 structured output richer than `{"type":"Text","value":...}`? Only text was
   seen. Which version the org runs was not read.
7. Help article bodies and Agent API schema pages did not render; claims from them are
   marked unverified above. Pages read: agent-api, -get-started, -lifecycle, -examples,
   -considerations, -troubleshooting, -variables, the reference, ascript-blocks, two blogs.

## Recommendation

For a custom LWC panel holding a conversation with Account_Brief: use Route A. The door
exists and works for an Employee agent: two live turns, reply, same session Id, same account
without naming it. No ECA, token or Named Credential is needed.

Next steps, in this order:
1. Add one `@AuraEnabled` method (message, sessionId) that calls the action, parses the
   `agentResponse` JSON envelope, and returns (text, sessionId). Fall back to the raw string if
   it does not parse. The panel keeps the session Id between turns.
2. Before shipping, test as a non-admin user with Manage AI Agents and with a user lacking
   it, and record the error text for the second case.
3. Plan the Apex test seam: the action may not run in a test, so wrap it in a small class
   with a stub, as `AgentLlm.stub` does.
4. Show a progress state: 14 to 18 s per turn, no streaming.
5. Only for callers outside Salesforce, test Route B start-session once with a user token.

If Employee agents are rejected by the Agent API, a Service agent (`AgentforceServiceAgent`,
requires `default_agent_user`, fits `bypassUser=true`) would be needed. It runs as a fixed
user, not the caller, so record visibility changes: the engine's `with sharing` and the
visibility gate in `AccountBrief` would then apply to that one user.
