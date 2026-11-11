# Calling Account_Brief programmatically (OPS-5)

Researched 2026-11-11. Status words: documented (official page says it), verified (seen in
the `experimental` org), unverified (community source, search-result summary or inference).

## Plain answer

- Outside Salesforce: the Agent API (REST, `api.salesforce.com`) can start a session, send
  messages, stream or receive replies and end the session. Its only stated exclusion is the
  "Agentforce (Default)" agent type. No official page says Employee agents ARE supported, and
  none says they are excluded. Account_Brief is `AgentforceEmployeeAgent`. Support is unproven.
- The Agent API's documented auth is an External Client App with the client credentials flow
  and `bypassUser=true`, which runs as the agent's assigned user. An Employee agent runs as the
  logged-in user and has no assigned user, so that exact recipe likely does not fit it
  (inference). A user-bound token with `bypassUser=false` is the probable route (unverified).
- Inside the same org (Apex or LWC): the documented route is the custom agent invocable action
  `generateAiAgentResponse`, called from Apex. It takes a user message and an optional session
  Id and returns the agent's reply and a session Id. A Salesforce blog says it works for any
  active agent, employee-facing included. The experimental org already exposes it for
  Account_Brief (verified listing). Whether a call actually returns a reply was not run.
- Apex calling the Agent API through a Named Credential is possible in principle but needs an
  External Client App and a user-context token. It is the heavier path.
- Smallest first step: one throwaway Apex call of `generateAiAgentResponse` for Account_Brief
  run as the Ben user, with no Agent API, ECA or Named Credential. If it returns a reply,
  wrap it in an `@AuraEnabled` method for the panel.

## Facts

| Fact | Status | Source |
|---|---|---|
| Agent API: start session, send message (sync and streaming), end session, submit feedback | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-lifecycle.html |
| "The Agent API isn't supported for agents of type 'Agentforce (Default)'." Decides type support; no other type is named | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html |
| No official page found that lists Employee agents as supported or excluded. Searched: Agent API guide (get-started, lifecycle, examples, considerations, troubleshooting, variables), reference, Agent Script blocks, two web searches | not found | pages above |
| Agent Script `agent_type` values: `AgentforceServiceAgent` (default) or `AgentforceEmployeeAgent` | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html |
| Start: `POST https://api.salesforce.com/einstein/ai-agent/v1/agents/{AGENT_ID}/sessions` | documented | https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html (path shown for Gov Cloud host; same path otherwise) |
| Start body: `externalSessionKey` (UUID) and `instanceConfig.endpoint` (My Domain URL) required; `tz`, `variables`, `featureSupport` (Sync or Streaming), `streamingCapabilities`, `bypassUser` optional | documented | https://developer.salesforce.com/docs/ai/agentforce/references/agent-api?meta=startSession |
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
| `generateAiAgentResponse` version 1.0.0 returns text, 1.1.0 structured output; Apex tests not supported for it; Flow use only in asynchronous paths; not for Experience Cloud site users; needs Manage AI Agents permission; Flow element moved to Run Agent in API 67.0 | unverified: from a web-search summary of help.salesforce.com pages whose bodies would not render in the browser | https://help.salesforce.com/s/articleView?id=ai.agent_custom_invocable_action_apex_example.htm , https://help.salesforce.com/s/articleView?id=ai.agent_custom_invocable_action_flow_apex.htm |
| LWC calls the agent through an Apex method that runs the invocable action | documented | invoke-agentforce-agents blog above |
| Headless sync prompt "lasts tens of seconds"; SSE recommended for UI | documented | https://developer.salesforce.com/blogs/2025/04/build-headless-agents-with-the-agent-api |
| A community answer says Employee agent sessions work via the Agent REST API from Apex or LWC | unverified (community, shorter path than official) | https://trailhead.salesforce.com/trailblazer-community/feed/0D5KX00000pOkO00AK |

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
   returned session Id. Exact parameter names: unverified, check the example-class page.
3. Wrap in an `@AuraEnabled` method; the LWC holds the session Id between turns.
4. Pass the open record by writing it into the message text, for example
   "Brief account 001...". The route-gather-reduce agent already accepts an Id.

Route B, outside Salesforce (Agent API):
1. Create an External Client App with the scopes above and client credentials (documented).
2. Get the agent Id (BotDefinition `0XxgK000002WVtxSAG`, verified).
3. For an Employee agent, expect to need a user-bound token and `bypassUser=false` (unverified).
4. Start session, send messages with increasing `sequenceId`, end session.
5. Test whether start-session accepts the Employee agent before building anything on it.

Route C, Apex to Agent API: as Route B, plus a Named Credential and External Credential
holding the token flow. The org already has Named Credentials for other services (verified
list), but none for the Agent API.

## Metadata types and deploy from source

| Type | In org | Deploys with sf |
|---|---|---|
| ExternalClientApplication, ExtlClntAppOauthSettings | verified: 2 apps, `Plesio_CI_Staging` and `Plesio_Claude`; retrieved fine | yes (retrieve worked; ECA policy and secrets need care) |
| NamedCredential, ExternalCredential | verified: Tavily_API, Plesio_Anthropic, Plesio_Einstein, Plesio_Anthropic_User, Brave_API | yes |
| AiAuthoringBundle (agent), GenAiPlannerBundle | verified: Account_Brief bundle and `Account_Brief_v1` planner | yes |
| ConversationVariable, ConversationContextVariable | documented as the variable metadata | yes (Metadata API) |
| Agent-specific invocable action | no metadata; it is generated per active agent (verified) | n/a |

## Org probes (read-only, org `experimental`)

- `SELECT ... FROM BotDefinition`: Account_Brief `0XxgK000002WVtxSAG`, Type `InternalCopilot`,
  AgentType `AgentforceEmployeeAgent`. Also Plesio_for_Slack `0XxgK0000023fblSAA`, same types.
- `BotVersion`: Account_Brief v1 `0X9gK0000048xtRSAQ` is Active. Plesio_for_Slack v1 is Inactive.
- `ExternalClientApplication`: Plesio_CI_Staging and Plesio_Claude. Their OAuth scopes are
  Api, Web, RefreshToken and RefreshToken, MCP. Neither has `chatbot_api` or `sfap_api`, so
  neither is an Agent API app. No ConnectedApplication query was usable (field names rejected).
- `GET /services/data/v68.0/actions/custom`, then `/generateAiAgentResponse`: lists one action,
  `Account_Brief`, type `GENERATE_AI_AGENT_RESPONSE`. Plesio_for_Slack is absent (inactive).
  This shows the action exists. It was not invoked (a call opens a billable session).
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

## Open questions

1. Does Agent API start-session accept an `AgentforceEmployeeAgent`? Needs a live test or
   Salesforce confirmation. This is the deciding question for Route B.
2. Does `generateAiAgentResponse` run Account_Brief as the calling user, with the same record
   access as the chat panel? Employee agents are documented as running in the user's context.
3. Reply shape in 1.1.0 "structured output": can it carry anything beyond text?
4. Session lifetime and a rate limit number.
5. Pages not read: the Help articles (bodies would not render in the browser tools); their
   claims above come from a search summary and are marked unverified. Agent API schema
   pages (InformMessage, CitedReference) did not render.
6. Pages read: agent-api, -get-started, -lifecycle, -examples, -considerations,
   -troubleshooting, -variables, the reference (summary, startSession, sendMessage, with
   the other operations on the same page), ascript-blocks, and the two developer blogs above.

## Recommendation

For a custom LWC panel holding a conversation with Account_Brief: use Route A. The agent
type is a likely fit, the in-org action is listed for this agent, no ECA, token or Named
Credential is needed, and it runs as the signed-in user, which is what an Employee agent
expects. It is not streaming, so show a progress state for tens of seconds.

Smallest first step, in this order:
1. Anonymous Apex in `experimental`: call `generateAiAgentResponse` for Account_Brief with
   "Brief Acme" and print the reply and session Id; call again with the session Id and a
   follow-up. Confirms reply, multi-turn and user context in one go (costs a few credits).
2. If it works, add one `@AuraEnabled` method (message, sessionId) returning (reply,
   sessionId), and point the panel at it as an alternative to the existing Apex and Named
   Credential bypass path.
3. Only for callers outside Salesforce, test Route B start-session once with a user token. If
   it rejects Employee agents, the fallback is an Apex `@RestResource` that wraps Route A,
   or a Service-type agent sharing the same three actions.

If Employee agents are rejected by the Agent API, a Service agent (`AgentforceServiceAgent`,
requires `default_agent_user`, fits `bypassUser=true`) would be needed. It runs as a fixed
user, not the caller, so record visibility changes: the engine's `with sharing` and the
visibility gate in `AccountBrief` would then apply to that one user.
