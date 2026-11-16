# How the custom UI calls the agent: five doors compared, one prototyped (BE-56)

Run 2026-11-15 in `connect-24h` (a non-production org), as the org's admin user. The org guard ran first: `sf org display`
for `connect-24h` and `agent-probe` was compared on org Id and username and read DIFFERENT and DIFFERENT. Only
`connect-24h` was touched. Org Ids, record Ids, session Ids, usernames, hostnames, keys and tokens are left out of this page.

Read with [agent-api.md](agent-api.md) (the first probe of the invocable and the Agent API),
[fr2-standard-limits.md](fr2-standard-limits.md) (BE-32, the standard chat measured against the direct panel path),
[fr2-coworker-spike.md](fr2-coworker-spike.md) (BE-53, the Coworker doors) and [panel-agent-1.md](panel-agent-1.md)
(BE-19, finished as BE-20: the panel's "Ask the agent" already calls the agent through the invocable).

## Result

- **For agent turns from our own panel, use the Apex invocable `generateAiAgentResponse` behind an `@AuraEnabled`
  method.** It is the only door that needs no new app, no credential and no Named Credential, and it works for
  `Customer_Summary`. The prototype in [spikes/agent-door](../../spikes/agent-door/) holds the session id between turns and
  continued the same session on turn 2 in 3 of 3 conversations.
- **It cannot end a session.** No standard or custom action ends one (checked in the org), and the Agent API's end call
  needs a token from an External Client App. The prototype's `endSession` releases the session on our side only and says
  so. The platform expires it on its own timer, which no page read says the length of.
- **The Agent API also works, and it can end the session.** With a user-bound token from an External Client App
  (Ben's go, 2026-11-15), 2 two-turn conversations ran start, message, message, end, all HTTP 200, with turn 2 using
  turn 1's context. It costs an app, a sign-in and a token to hold. See [Agent API measurement](#agent-api-measurement).
- **Latency is the agent's, not the door's.** A first turn took 11 to 31 s and a follow-up 9 to 13 s, in the range of
  BE-32's agent numbers.

## Options

Each row is cited to a Salesforce page read in a browser on 2026-11-15 (see [Sources](#sources)), unless the cell says
otherwise. "Measured" means this card ran it.

| Door | How it is called | Multi-turn | Auth | Cost to set up | Latency | Limits |
|---|---|---|---|---|---|---|
| **1. Apex invocable `generateAiAgentResponse`** (BE-53's control path) | Apex: `Invocable.Action.createCustomAction('generateAiAgentResponse', '<agent API name>')`, set `userMessage` and optional `sessionId`, `invoke()`; an LWC calls an `@AuraEnabled` method that does it [S1]. Flow has the same action [S1] | Yes: the first reply returns a session id, pass it back for turn 2 and the agent keeps context [S1]. Measured: turn 2 used turn 1's context in 3 of 3 | The running user's own session. The agent runs as the logged-in user for an employee agent [S1]. No token to manage | One small Apex class plus an LWC. No app, no credential | Measured: first turn 11, 15 and 31 s; follow-up 9, 10 and 13 s | No end-session call (checked in the org). No Apex test can run it, so the class needs a stub seam. Not for Experience Cloud site users and needs the Manage AI Agents permission: **unverified**, from a help-page summary in [agent-api.md](agent-api.md). No streaming: the reply arrives whole |
| **2. Agent API** (REST) | `POST` start session, `POST` message (sync or streaming), `DELETE` end session, on the Agent API host [S2], [S3] | Yes, and it has a documented end call [S2] | An External Client App with the client credentials flow, or any flow that yields a JWT access token [S3]. Scopes `api`, `refresh_token`, `chatbot_api`, `sfap_api` [S3]. A user-bound token needs a sign-in flow [S3] | The most: an External Client App, a token flow and a place to keep the secret. From Apex, also a Named Credential. From an LWC, a token in the browser (not recommended: unverified) | Measured: first turn 14 and 32 s; follow-up 10 and 30 s; start 1 to 2 s; end 1 s | Not supported for agents of type "Agentforce (Default)"; 120-second timeout, a timeout returns HTTP 500; credits are consumed [S4]. No page says employee agents are accepted, but it worked for `Customer_Summary` with a user-bound token and `bypassUser` false (measured below) |
| **3. Drive the standard Agentforce panel from an LWC** (`lightning/accApi`) | `open(botId?)`, `close()`, `execute(utterance, botId)`, `reset()` from a custom LWC [S5] | The panel keeps its own conversation; `execute` calls queue in order [S5] | The user's Lightning session | Low: one LWC import | Not applicable: nothing comes back | "The execute method does not return the agent's textual response to your component" [S5]. Desktop Lightning Experience only, default panel only, API 59.0 or later [S5]. Only utterances, not actions [S5]. It opens the standard panel, so our branded cards and panel do not show the reply |
| **4. Embedded Messaging / Enhanced Chat** | A messaging channel and an embedded service deployment, routed to an Agentforce Service Agent, shown on a website or Experience Cloud site [S6] | Yes, it is a chat | Customer-facing: messaging and Omni-Channel routing, a site domain on the channel's allowlist [S6] | High: messaging settings, routing configuration, queue, presence status and configuration, a published site, a channel, a deployment [S6] | Not measured | It routes to an Agentforce **Service** Agent [S6]. `Customer_Summary` is an employee agent that runs as the signed-in user; whether messaging accepts it is **undocumented**. It is a widget on a site, not a call from our panel |
| **5. Coworker** (BE-53's doors) | No in-org API, Connect class, Apex class, invocable or LWC module for Coworker's Ask was found [S7]. BE-53 tried the invocable against Coworker's `SearchAgent`: the transaction stopped at the call with no error. The nearest call that answered was `ConnectApi.Search.findAndGroup`, which is search, not Ask [S7] | Not shown | The user's Lightning session; the Coworker MCP server needs a connected app or External Client App and a sign-in (undocumented in the pages read) [S7] | Coworker must be on, and our code has no door to it | The `Customer_Summary` control turn BE-53 ran answered in 14 s; Coworker's own time is not measured [S7] | The guide says Coworker times out if it cannot hand a request to an agent within 90 seconds [S8]. A headless call to Coworker is ledger F83, which is Ben's decision, not this page's [S7] |

## The prototype

[spikes/agent-door](../../spikes/agent-door/) holds:

| File | What it is |
|---|---|
| `classes/AgentDoorController.cls` | `with sharing`. `sendMessage(message, sessionId, accountId)` calls the invocable through a gateway interface, returns reply text (the `{"type":"Text","value":...}` envelope unwrapped, raw text if it does not parse), the session id, seconds and reply length. On the first turn only, it reads the account name with `WITH USER_MODE` and appends it to the message. `endSession(sessionId)` releases the session and returns `endedOnPlatform=false`. No system-context code, no marker comments |
| `classes/AgentDoorControllerTest.cls` | Six tests through a stub gateway (the platform cannot run the agent in a test): two turns share one session, the first turn adds the account name read in user mode, blank message refused, gateway failure surfaces, `endSession`, envelope unwrap. 6 of 6 pass in the org |
| `lwc/agentDoor` | An Account record-page component: a message box, "Send turn 1" then "Send turn 2" (then locked), an End button, a progress label while it waits. The session id lives in a component field and is never rendered. 5 Jest tests pass under `npx sfdx-lwc-jest -- --roots spikes/agent-door` |
| `apex/two-turns.apex` | The anonymous Apex that ran the conversations below through the deployed class |
| `main/default/*` External Client App files | `Agent_Door_Spike`, see [Agent API measurement](#agent-api-measurement). The contact email in `Agent_Door_Spike.eca-meta.xml` is the placeholder `__AGENT_DOOR_CONTACT_EMAIL__`; it was replaced by the admin's address for the deploy only and put back before the commit, so a deploy from a fresh checkout must replace it first |

Deployed with `sf project deploy start --source-dir spikes/agent-door -o connect-24h --test-level RunSpecifiedTests --tests AgentDoorControllerTest`.
Not `RunLocalTests`: the org's template classes do not compile.

## Measured: 3 two-turn conversations through the deployed Apex

Account: Edge Communications. Each conversation ran in one anonymous Apex execution calling the deployed
`AgentDoorController.sendMessage` twice and then `endSession`. The LWC was not placed on a page (that needs a page
layout change outside this card's scope), so the Apex ran the conversations.

| # | Turn 1 | Turn 2 (a follow-up that only makes sense with turn 1) | T1 seconds | T1 reply (chars) | T2 seconds | T2 reply (chars) | Turn 2 used turn 1's context | Same session | Session ended |
|---|---|---|---|---|---|---|---|---|---|
| 1 | "Give me a brief on Edge Communications" | "What about its open cases?" | 31 | 2,605 | 9 | 767 | yes: five cases for the account, no account named in turn 2 | yes | no: released here only |
| 2 | "How many open opportunities does Edge Communications have, and what is the largest one?" | "When does it close?" | 11 | 834 | 10 | 892 | yes: close dates of the same deals | yes | no: released here only |
| 3 | "Who are the main contacts at Edge Communications?" | "Which of them was contacted most recently?" | 15 | 1,452 | 13 | 1,387 | yes: picked one of the contacts from turn 1 | yes | no: released here only |

- Every call returned success with no error. A pilot of the same three conversations earlier the same day, run as inline
  anonymous Apex with the same call shape before the deploy, gave first turns of 34, 12 and 15 s and follow-ups of 8, 11
  and 12 s.
- Turn 2 named no account in all three. It answered about the right account, so the session carried the context.
- Replies kept the agent's section labels with "not requested" filler in some sections (for example "Open deals Not
  requested"). That is the agent's own formatting on a narrow question, not the door's.
- "Session ended: no". The class's `endSession` is honest about it (`endedOnPlatform=false`). The three sessions are left to expire.

### Against BE-32

BE-32 measured the same agent behind the standard chat against the direct panel path in `agent-probe`
([fr2-standard-limits.md](fr2-standard-limits.md)). The numbers here are from a different org and a different account's
data volume, so this is a range check, not a controlled comparison.

| Question type | BE-32: through the agent | BE-32: direct panel path | This card: first turn | This card: follow-up |
|---|---|---|---|---|
| Brief | 31 to 36 s | 22 to 25 s | 31 s (the brief turn) | 9 to 13 s |
| Narrower question | 13 to 33 s (explore) | 5 to 9 s (explore) | 11 to 15 s | 9 to 13 s |

The invocable door adds nothing visible over the agent's own time: the brief took 31 s here against 31 to 36 s there. The
direct path stays two to four times faster for a question the panel can answer without the agent, which is why the
panel's brief and explore keep the direct path (BE-32's finding).

## Agent API measurement

Two conversations through the Agent API (start session, two sync messages, end session) against `Customer_Summary`,
on the Edge Communications account, with a **user-bound token**: authorization code with PKCE through the External
Client App `Agent_Door_Spike`, Ben signing in once in a browser. No client secret was ever created, read or typed, and the
token, session ids and agent Id are not on this page. The app is the one part of this card that needed Ben's go
(approved 2026-11-15). The same turn texts as conversations 1 and 3 above, so the two doors can be read side by side.

| # | Turn 1 | Turn 2 | T1 seconds | T1 reply (chars) | T2 seconds | T2 reply (chars) | Turn 2 used turn 1's context | Same session | Session ended |
|---|---|---|---|---|---|---|---|---|---|
| A1 | "Give me a brief on Edge Communications" | "What about its open cases?" | 31.5 | 2,651 | 9.8 | 760 | yes: five open cases for the account, none named in turn 2 | yes (one session id for both calls) | **yes**: the end call returned 200 in 1.4 s |
| A2 | "Who are the main contacts at Edge Communications?" | "Which of them was contacted most recently?" | 14.2 | 1,117 | 30.3 | 58 | yes: named one of the two contacts from turn 1 | yes | **yes**: the end call returned 200 in 1.2 s |

Session start took 1.9 s and 1.3 s. Every call returned HTTP 200.

- **Same agent time, same reply shape.** The Agent API's turns (14 to 32 s first, 10 to 30 s follow-up) sit in the same
  range as the invocable's (11 to 31 s and 9 to 13 s). The one 30 s follow-up returned a 58-character answer, so the time
  is the agent's, not the reply's. Two conversations are too few to say one door is faster.
- **The Agent API does what the invocable cannot: it ends the session.** That is its one clear advantage here.
- **An employee agent works through the Agent API with a user-bound token.** [agent-api.md](agent-api.md) left this
  open; no Salesforce page settles it. It is one agent in one org with `bypassUser` false.
- **Not tried:** the client credentials flow (it needs the consumer secret in a request, which this card does not
  handle), a non-admin user, streaming, and calling the API from Apex or an LWC. The token came from a browser
  sign-in in a script outside the repo, not from a Named Credential, so a panel would still need that piece built.

## Recommendation

1. **Use door 1 for agent turns in the custom panel.** It is already what BE-20 shipped for "Ask the agent" in
   `agent-probe` (the panel sends through Apex, keeps the session id, follow-ups reuse the session). This card's
   prototype adds what BE-20's wrapper can borrow: a gateway seam, a user-mode read for context, and a clear end-of-session
   answer.
2. **BE-15 stays parked, and is superseded.** BE-19 re-cut it and BE-20 finished that work. Nothing in this card
   reopens it. If the panel ever needs a real end-of-session, that is the only reason to look at door 2.
3. **Keep the direct path for brief and explore.** The agent's turn time (11 to 31 s here, 13 to 36 s in BE-32) is the
   cost of going through the agent, not of the door. Door 1 does not make it faster.
4. **Do not build on door 3, 4 or 5.** Door 3 returns no reply to our code. Door 4 targets Service Agents and a public
   site. Door 5 has no documented in-org API, and F83 is Ben's call.
5. **What needs Ben's go.** Nothing for door 1. For door 2 in a real org: an External Client App (this card created
   `Agent_Door_Spike` in `connect-24h` under Ben's approval of 2026-11-15) and, if Apex or a server calls it, a Named
   Credential or a place to hold a token. Any connected app for another door needs its own go.
6. **What door 2 needs in a real org.** A user-bound token for every panel user, not a shared one: an External Client App with the authorization code flow
and PKCE (or any flow that yields a JWT access token [S3]) and the scopes `api`, `refresh_token`, `chatbot_api` and
`sfap_api` [S3], [S9]; a sign-in step for each user, since a client-credentials token runs as the agent's assigned
user and an employee agent has none (the first probe's inference in [agent-api.md](agent-api.md), supported by this
card's use of `bypassUser` false); a Named Credential or server that holds and refreshes the token if Apex calls the API; a
decision on whether the token may live in the browser (not recommended, unverified); and credits, because Agent API use
consumes them [S4]. The one thing it buys over door 1 is a real end-of-session call. Salesforce documents that a new
External Client App can take up to 30 minutes before it works, per [mcp-door-runbook.md](mcp-door-runbook.md) (unproven there).

## Sources

All read in a Chrome tab on 2026-11-15 unless the line says otherwise. Plain fetches of these pages return HTTP 403.

- [S1] Invoke Agentforce Agents with Apex and Flow (Salesforce Developers blog, 2025-04):
  https://developer.salesforce.com/blogs/2025/04/invoke-agentforce-agents-with-apex-and-flow
- [S2] Agent API Session Lifecycle: https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-lifecycle.html
  (the endpoints themselves are in the Agent API reference, https://developer.salesforce.com/docs/ai/agentforce/references/agent-api,
  read by an earlier card, 2026-11-11, and not re-read)
- [S3] Get Started with the Agent API: https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html
- [S4] Agent API Considerations: https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html
- [S5] Agentforce Conversation Client API: https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html
- [S6] Exercise 1: Configure a Service Deployment (Agentforce service agent workshop):
  https://developer.salesforce.com/workshops/agentforce-new-workshop/service-agents/1-configure-a-service-deployment
- [S7] The Agentforce Coworker guide pages BE-53 and OPS-57 read in a browser on 2026-11-13 to 2026-11-15, and BE-53's two
  live tries: see [fr2-coworker-spike.md](fr2-coworker-spike.md) (Sources S8 to S10, S20 to S25, and its "Headless doors"
  section). Not re-read by this card.
- [S8] Search Agent and Agent Delegation in Agentforce Coworker (timeout wording), read by BE-53:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-customize-delegate-agent.html
- [S9] ExtlClntAppOauthSettings (Metadata API), for the External Client App's scope names:
  https://developer.salesforce.com/docs/platform/api-metadata/references/meta-types/metadata-extlclntappoauthsettings.html

## Undo

Everything below is in `connect-24h` only. Nothing was deployed, created or changed in `agent-probe`. The spike stays
deployed until the org expires.

| What | Type | How to remove |
|---|---|---|
| `AgentDoorController` | Apex class | destructive deploy or delete in Setup |
| `AgentDoorControllerTest` | Apex class | same |
| `agentDoor` | Lightning web component (not placed on any page) | same |
| `Agent_Door_Spike` | External Client App with its OAuth settings, global OAuth settings and OAuth policies (four metadata components, authorization code with PKCE, no client secret) | delete the app in Setup > External Client App Manager, or destructively deploy the four components |
| Ben's consent to `Agent_Door_Spike` | OAuth token for the admin user | revoke in the user's OAuth connected apps, or delete the app |

- **Agent sessions left open:** 3 from the invocable conversations above (the door has no end call: they expire on the
  platform's own timer, which no page read states), plus 3 more from the earlier inline pilot of the same conversations.
  The 2 Agent API sessions were ended (end call, HTTP 200).
- **Not in the org:** no user, no Named Credential, no connected app (the External Client App is the only app), no
  permission set, no data written. The Apex test inserts one Account inside the test and rolls back with it.
- **Left on this machine, outside the repo and deleted at the end of the card:** the sign-in script's token file and the
  retrieved settings file that held the consumer key. The consumer key is not in any committed file. The deploy used a
  worktree-local `sf config set target-org connect-24h` (the plugin's deploy gate asked for one); it was unset before the card ended.
