# FR2: Agent Memory discovery, and how long an agent conversation keeps its context (BE-34)

- Date: 2026-11-13, 07:00 to 07:45 UTC. Org `agent-probe` (not scratch, not a sandbox, not a Dev Hub, no
  trial date). Every `sf` command ran with `-o agent-probe`. The org's API version is 68.0.
- CLI: `@salesforce/cli` 2.158.7. Local Agent Script compiler: `@sf-agentscript/agentforce` 2.9.27 (npm),
  through the agentforce-generate skill's `index-agent.mjs`.
- Read first: [feature-revision-2.md](../plans/feature-revision-2.md) (F74 to F80, F83, and the "Two memories"
  decision), [fr2-design.md](../plans/fr2-design.md), [pattern 05](../patterns/05-conversation-memory.md),
  [pattern 06](../patterns/06-agent-routing-and-verbatim-relay.md), the cards BE-26 and BE-35, and
  [fr2-agent-publish.md](fr2-agent-publish.md) (OPS-51) for the Apex calling pattern.
- Approvals ([gtm-burn-plan.md](../plans/gtm-burn-plan.md)): "FR2: spikes in `agent-probe`" is **approved**
  (Ben, 2026-11-12). The session measurement spends model calls under the approved "FR2: live checks" row. Nothing
  in the org was turned on, changed, deployed, published or activated.
- Status words: **verified** (seen in a command result or an org query here), **read** (a Salesforce page that
  was read in full), **snippet** (a search-engine summary of a Salesforce page that did not render for us),
  **third-party** (only a non-Salesforce write-up says it), **unproven** (inference or not found).
- Help article bodies render only in a browser, and the browser was not connected. developer.salesforce.com
  refused the fetcher (HTTP 403). So most Salesforce facts below are snippets. Help articles are cited by
  article name, because their links carry a query string.
- No record Ids, org Ids, session Ids, usernames, emails, tokens or org hostnames are written here.

## Plain answer

- **Agent Memory does not replace either of our memories.** It remembers things about one user for one agent
  (with a second, smaller pool a user's agents share). It is curated by a model, capped at 50 memories per user per
  agent, and replaces the oldest when full. It is not keyed to an account and has no retention per type. No
  object exposes it to SOQL; four standard memory actions exist, so Apex or a Flow may be able to call them for
  the running user, but that is untried and unproven. It works only inside a registered Agent Script agent, and our
  surfaces and the MCP door do not use the agent (F83). So none of it reaches the panel, the rail or MCP.
- **Data 360's agentic memory is a different product.** It is keyed to an individual or a unified individual
  profile in Data 360, is API first, and needs Data 360. Data 360 is **off** in agent-probe (verified).
- **Keep BE-26 and BE-35 as designed.** Hand to the platform only what it does well and we do not need: a
  rep's personal preferences inside the optional agent, as a later opt-in (one Agent Script line and a publish).
- **An agent conversation kept its context after 1, 5 and 15 idle minutes, and had lost it after 30**
  (one session per gap, verified). One sample per gap, and the cause of the loss at 30 is unproven (see below).

## What Salesforce's docs say

| # | Question | Answer | Status | Source |
|---|---|---|---|---|
| 1 | What it stores | Details users shared in past conversations with an agent, and profile details such as the user's name. Each memory is a short item a model writes, updates or deletes from the conversation | snippet; the action descriptions are verified | Release notes, "Let Agentforce Agents Remember What Matters to Your Users (Generally Available)" (Salesforce Help article `release-notes.rn_einstein_copilot.htm`); the `manageUserMemory` action below |
| 1 | Who owns it | The user, per agent: up to 50 memories per agent per user, plus up to 50 user-level memories every agent of that user can use. Not an account, a record or a team | snippet | Salesforce Help article `ai.agent_memory_manage.htm` ("Manage Your Agent's Memories") |
| 1 | Who owns it, for a service agent | The authenticated participant (a User, Contact, Lead or Account), supplied by the runtime from the verified session. That is the person chatting with the agent, not a rep's account history | verified | `getUserMemories` and `manageUserMemory` action describes in agent-probe |
| 2 | How it is turned on | In Agent Script, a top-level `context:` block with `memory:` and `enabled: True`. Legacy (non-script) agents are not supported | snippet; the syntax is verified locally | Salesforce Help article `ai.agent_memory_enable.htm` ("Enable Agent Memory"); the compiler, below |
| 2 | Related switches | The same `context:` block also takes `user_profile:` and `past_conversations:`, each with `enabled` | verified (compiler schema) | `@sf-agentscript/agentforce` 2.9.27 dialect schema |
| 2 | Edition | Enterprise, Performance, Unlimited and Developer, in Lightning Experience | snippet | `ai.agent_memory_enable.htm` |
| 2 | Status | Generally available (the Salesforce blog says it went GA in September) | read | [Salesforce blog, Agentforce memory update](https://www.salesforce.com/blog/agentforce-memory-update/) |
| 2 | Needs Data 360, licences, cost | Not stated in any Salesforce text we could read | unproven | searched the release note, the help nav and the blog |
| 2 | Employee agents | Each user opts in, and manages memories in a Memory and Preferences panel in the Agentforce panel in Lightning | snippet | `ai.agent_memory_enable.htm`, `ai.agent_memory_manage.htm` |
| 2 | Service agents | Memory is managed in the conversation, through standard actions a builder adds (a User Memory Management subagent) | third-party; the four actions are verified | [Salesforce Trail](https://salesforcetrail.com/agentforce-agent-memory/); the action list below |
| 3 | Limit | 50 per agent per user, 50 user-level; the oldest are replaced automatically when full | snippet | `ai.agent_memory_manage.htm` |
| 3 | Retention | No time-based expiry found; only the oldest-replaced rule | unproven | as above |
| 3 | User controls | View, delete and export memories; turn memory on or off per agent | snippet (help nav lists "Delete a Memory" and "Export Memories"); read for the console | `ai.agent_memory_manage.htm`; [Salesforce Engineering, persistent memory for Agentforce](https://engineering.salesforce.com/ai-agents-need-memory-building-persistent-memory-for-agentforce/) |
| 3 | Org-wide switch | One setting controls conversational memory for all agents and users. While it is off, existing memories are kept but not used, and the panel's memory icon goes away. Its Setup name and path were not readable | snippet | Release note "Control Conversational Memory for AI Agents Across Your Org"; help article "Turn Off Conversational Memory for Your Org" (title only) |
| 4 | Query, report, Apex | No object, DMO or Apex API is documented, and no report type was found. The four memory actions are on the standard invocable actions list, so Apex or a Flow may be able to call them for the running user and an agent; not tried here | unproven (docs); the action list is verified (org, below) | searched the help nav and the release notes |
| 5 | Agent API, `generateAiAgentResponse`, channels | Nothing we could read says memory applies, or does not, to the REST Agent API or to the invocable action. It is scoped to Agent Script agents: the Lightning panel for employee agents, and the conversation for service agents | unproven | as above |
| 5 | Our surfaces and the MCP door | Not reached. They call Apex services, not the agent (F83), and memory lives inside the agent's runtime | inference from rows 2 and 4; unproven as a test | [fr2-design.md](../plans/fr2-design.md#the-product) |
| 6 | Data 360 agentic memory | Memories extracted from conversation data into the `AiParticipantInsight` DMO, linked to an individual or a unified individual. Semantic memory (profile facts and preferences) and episodic memory (per conversation and per agent, kept until deleted). Read through a GetContext API filtered by the requester's permissions. API first; agents are registered in Data 360; the profile DMO is fixed at registration. Available in every edition Data 360 supports | snippet | [Agentic Memory and Context in Data 360](https://developer.salesforce.com/docs/data/agentic-memory-context/guide) |
| 6 | How it differs | Agent Memory: per user and per agent, inside the agent, set in Agent Script. Agentic memory: per individual profile in Data 360, across agents, through an API | snippet; third-party for the plain statement | the two rows above; [Salesforce Trail](https://salesforcetrail.com/agentforce-agent-memory/) |
| 7 | Session lifetime | No Salesforce text gives an idle timeout for an agent session through the Agent API or the invocable action. A REST call times out after 120 seconds. Messaging's own inactivity timer is 5 to 30 minutes and is a channel setting | unproven; snippet for the two numbers | [Agent API considerations](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-considerations.html); Salesforce Help article `sf.messaging_auto_end.htm` |

Public write-ups claimed: per user and per agent (confirmed, plus the user-level pool); set in Agent Script
(confirmed, `context.memory.enabled`); about 50 per user per agent (confirmed, oldest replaced); user controls
(confirmed); an org-wide off switch (confirmed, Setup path unproven); separate from Data 360's agentic memory
(confirmed in practice: different storage, owner and access path).

## What agent-probe has (read-only)

| Check | Command (abridged) | Result |
|---|---|---|
| Memory actions | `sf api request rest /services/data/v68.0/actions/standard` | Four: `getUserMemories`, `manageUserMemory`, `getAgentMemoryPreference`, `updateAgentMemoryPreference` (verified). At v66.0 the same call lists only the first two, so the API version matters |
| What they do | describe of each action | Get the user's memories for this agent (optional search text); create, update or delete a memory from the conversation using generative AI; read or set whether memory is on for the current user and agent. All act for the current user and the current agent (verified) |
| A memory object | `sf sobject list --sobject all`; EntityDefinition (SOQL and Tooling) for `%Memor%` | No queryable memory sObject among 1752. Tooling lists `CoworkerMemoryShare` and `CoworkerMemoryOwnerSharingRule`; `CoworkerMemory` itself returns NOT_FOUND to describe (verified). Whether that is Agent Memory's store is unproven |
| The org-wide setting | retrieve of Settings `AgentPlatform`, `EinsteinCopilot`, `EinsteinGpt`, `EinsteinAI`, `Bot`, `SetupCopilot`, `CustomerDataPlatform` at v66.0 and v68.0, to a temporary folder outside the repo | No field names memory (verified). So the switch's state is **unknown**: it is not exposed through these settings, which does not mean it is off. Setup was not opened (that needs a sign-in) |
| Data 360 | `CustomerDataPlatformSettings` | `enableCustomerDataPlatform` false (verified). The capability detector reports Data 360 as unknown. Agentic memory and STDM session traces are not available here |
| Our agent | `Customer_Summary.agent`; BotVersion | No `context:` block, so memory is not enabled for Customer_Summary. v2 is Active (verified) |
| The syntax | local compile of a scratch copy with `context: memory: enabled: True` | Compiles with 0 diagnostics. `enabled: true` (lower case) fails: "Expected True or False" (verified) |

## How long an agent conversation keeps its context

Pattern 05's open item. The spike is [`spikes/agent-memory/`](../../spikes/agent-memory): `session_lifetime.py`
drives `turn.apex.tmpl` through `sf apex run -o agent-probe`. Each run is one turn of the active Customer_Summary
agent through `Invocable.Action.createCustomAction('generateAiAgentResponse', 'Customer_Summary')` from anonymous
Apex. No REST Agent API, client app or consumer key; no deploy; no DML in the script. Session Ids stayed in the
runner's memory, apart from the one-turn apex file each run writes to a temporary folder outside the repo and
deletes after the turn.

- **Method:** one session per gap. Turn 1: "Give me a summary of Edge Communications". After the gap, on the
  same session: "What about their open cases?", which names no account.
- **Kept** means: the call succeeded, the same session came back, and the follow-up built a brief of Edge
  Communications (the running user's `Customer_Summary_Session__c` row for that account counted one more brief,
  read before and after the call). **Lost** is anything else.

| Idle gap | Turn 1 | Follow-up | Result |
|---|---|---|---|
| 1 min | ok, 30.3 s, brief +1 | ok, same session, 8.4 s, brief +1 | **kept** |
| 5 min | ok, 28.0 s, brief +1 | ok, same session, 10.1 s, brief +1 | **kept** |
| 15 min | ok, 31.2 s, brief +1 | ok, same session, 9.2 s, brief +1 | **kept** |
| 30 min | ok, 31.3 s, brief +1 | ok, same session, 2.8 s, **no brief**, a 345-character reply that is not the off-topic line and does not ask which account | **lost** |

- **What "kept" proves.** The conversation, with what the agent knew about it, survived the gap. It does not
  prove that `briefed_account_id` itself was read: when that variable is empty, the script tells the model to
  re-resolve the account named last in the conversation, which also ends in a brief of Edge. Only a session
  trace would tell them apart, and traces need Data 360, which is off here.
- **What "lost" shows.** At 30 minutes the call still succeeded and returned the same session, but no brief was
  built, and it answered in under 3 seconds. Whether `resolve_account` ran is not shown (it writes nothing). The
  reply text was not kept, so whether it was a session-ended message or a re-greeting is unproven.
- **The cause is unproven.** One sample, and a confound: the 30-minute session was the first of the four measured
  sessions to start (07:13:38 UTC; the others started at 07:14:11, 07:14:43 and 07:15:12), and eight sessions were
  open at once for the same user and agent (the four from the wasted first pass, started 07:10:38 to 07:12:14,
  were older still), so idle time is not separated from session age or the number of open sessions. A routing
  slip cannot be ruled out either.
- **What it means for the product:** nothing breaks. The panel and MCP keep their own history (BE-26) and never
  lean on the agent's session. A team using the optional agent should not count on a follow-up after 30 idle
  minutes keeping its context: it was lost at 30 on one sample, cause unproven.
- **Rows written:** only the product's own session rows. `Customer_Summary_Session__c` held 1 row before and 1
  after: **0 created, 1 updated** (the Edge Communications row). Its brief count went from 31 to 42: 11 briefs,
  which is 4 from a first attempt (below), 4 first turns and 3 kept follow-ups. Nothing else wrote that row in the
  window (the count adds up).
- **A first attempt was wasted.** The runner's first pass (07:10 to 07:12 UTC) misread the debug log, which
  escapes `|` as `&#124;`, so it kept no session and was stopped before any follow-up. It cost 4 first turns.
- **Model calls:** 12 agent turns (4 wasted, 8 measured), each with the brief's own model calls inside.

## Proposal only: Agent Memory on the optional agent

Not done here: BE-28 is parked (F83), and a publish needs its own Approvals row. If Ben wants a rep's preferences
remembered in the optional agent, this is the whole Agent Script change, placed after `config:` in
`force-app/main/default/aiAuthoringBundles/Customer_Summary/Customer_Summary.agent`:

```text
context:
    memory:
        enabled: True
```

It compiles locally with 0 diagnostics (verified on a scratch copy). Then:

1. `bash scripts/agent-check.sh` (local compile and org validate), then publish and activate under a new Approvals
   row.
2. Preconditions: the org-wide conversational memory switch is on, and the test rep has opted in to memory for
   the agent. Test, two sessions as one rep through `generateAiAgentResponse`: session A says "Remember that I want summaries
   in three bullets". Session B, started fresh, asks for a summary of Edge Communications. Pass when the
   `getAgentMemoryPreference` action reports memory on for that rep and agent, and session B's reply follows the
   preference. Print only pass or fail, and record the session rows written. A fail may mean memory does not apply through the
   invocable action (row 5's open question), not a defect.
3. Check that the panel and MCP are unchanged: their answers come from Apex, so they should not follow the
   preference. That is the proof that memory does not reach our surfaces.

## What later cards need to know

- **BE-26:** no change. The agent's own conversation context was kept at 15 idle minutes and lost at 30 (one
  sample, cause unproven); BE-26's session timeout is our own and need not match it.
- **BE-35:** no change. No object exposes Agent Memory to SOQL, and calling the memory actions from Apex is
  untried, so outcomes must not depend on it.
- **OPS-44:** "When you would add it" can name Agent Memory: a rep's preferences remembered per agent, one
  `context:` line and a publish, Agent Script agents only, managed by each user in the Lightning panel, and never
  seen by our surfaces or MCP.
- **OPS-43:** pattern 05's "has not been measured" line can give this result and link this page.

## Undo

Nothing to undo in the org. No setting, agent, version or metadata was changed. One existing
`Customer_Summary_Session__c` row was updated by the product's own memory write, as the panel does; nothing to
remove. Local only, outside git: the retrieved settings, the action describes, the compiled scratch copies and the
run log are in the session's scratch folder. The red evidence is in the worktree's git-ignored
`.delegation/BE-34/red-1.txt`.

## Gates

On the final commit:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 165 tests, OK.
- `bash scripts/check-docs.sh`: 48 pages, 0 broken.
- `git status --short`: empty; no `tests/__pycache__`.

## Coverage against F75 to F78, and the recommendation

| Need | Agent Memory | Data 360 agentic memory | Our design |
|---|---|---|---|
| Customer outcomes that persist against the account (F75, F76): a summary or an action, kept for its type's retention, in no single agent or session | **Not covered.** Per user and per agent, 50 at most, oldest replaced, no account key, no retention per type | **Not covered.** Keyed to an individual profile, not an account; episodic memory is per conversation and agent; needs Data 360 (off in agent-probe) | **Covered by BE-35:** `Customer_Outcome__c` in a master-detail to the account, retention per outcome type |
| Reusable past summaries (F78): earlier summaries fed to the next one ("what changed since") | **Not covered.** It keeps short model-written facts about the user, not the summaries; no object exposes them, and reading them through the memory actions from Apex is untried | **Partial.** Session summaries are retrievable through an API, but per profile and only for agents registered in Data 360; whether Apex can call it is unproven | **Covered by BE-35** (the last summary's headline and date go into the next summary) |
| Sentiment over time (F77) | **Not covered** | **Not covered** (nothing found) | **Covered by BE-36** (a score at each summary) and **FE-19** (the chart) |
| Context when the rep opens a conversation (F78, F79), on the panel, the rail and MCP | **Partial.** Only inside the registered agent, only that rep's own facts, and none of it reaches our surfaces or MCP (F83) | **Partial.** Profile-level context through an API, behind Data 360 and agent registration | **Covered by BE-35** (the outcome context every surface adds) and **BE-26** (the conversation history) |

**Recommendation.**

1. **Keep** both of our memories, as the "Two memories" decision says: the conversation history (BE-26) and the
   customer outcomes against the account (BE-35). The platform does not cover either, so there is no change to
   BE-26 or BE-35.
2. **Hand to the platform** only a rep's personal preferences inside the optional agent, and only as a later
   opt-in: the one `context:` line above plus a publish under its own Approvals row. Not in FR2 (BE-28 is parked).
3. **Do not build on** Data 360's agentic memory in FR2: it needs Data 360, which agent-probe does not have, and it
   keys memory to a person, not to an account.
4. **OPS-44** (the optional agent's appendix): add Agent Memory to "When you would add it", with the limits above,
   and say plainly that our surfaces and MCP never see it.
