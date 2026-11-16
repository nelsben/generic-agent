# Coworker calls our agent: what the docs say, and why no way was tried yet (OPS-64)

Researched 2026-11-15 for `connect-24h`. **Status: the reading half is done; the four ways were not tried.** At the
first org step in the browser, the Chrome session for `connect-24h` showed the Salesforce login page, not the org.
The card forbids signing in for Ben, so no Coworker chat ran, no description was changed and nothing was published.
Every answer below is from Salesforce pages read in a Chrome tab on 2026-11-15, or from read-only CLI queries.
Ids, usernames and hostnames are left out. Read with [fr2-coworker-spike.md](fr2-coworker-spike.md#delegation-measured),
which holds OPS-63's 0 of 9 baseline.

## Plain answer

- **Coworker picks another agent only for a request it cannot complete itself.** Then it reads the agent and topic
  descriptions of the Agentforce agents the user can access, and routes on those descriptions only, not on topic
  instructions [C1], [C2].
- **To be callable, an agent needs the user's agent access and descriptions that match the request.** No Coworker page
  names a Setup list of callable agents, a Coworker switch for delegation, or a step to add an agent to Coworker [C1],
  [C4], [C5], [C6]. Employee agent access is granted on the agent's Agent Access page or a permission set's Enabled
  Agent Access [C3]. The admin in `connect-24h` already holds `Customer_Summary_Agent_Access` (OPS-63).
- **"Add our agent to Coworker as a connected agent" is not a documented step.** Connected subagents are added inside
  an orchestrator agent you edit in Agentforce Builder [C7], and Coworker's Search Agent is platform-managed and cannot be
  modified [C1]. No page read ties connected subagents to Coworker.
- **The documented user lever is to ask.** The delegation page tells users who hit its timeout to "ask Agentforce
  Coworker to delegate" to an accessible agent [C1]. That is way (a), and it is the first thing to try once the browser
  is signed in.
- **Measured: nothing new.** OPS-63's 0 of 9 stands. Why it did not delegate fits the "cannot complete" rule: Coworker
  answered each question from its own CRM search. That is an inference from [C1] and OPS-63's thinking steps, not a
  measurement.

## Org guard and read-only state

- **Guard.** `sf org display` for `connect-24h` and for `agent-probe`, compared before any org step: org Id
  **DIFFERENT**, username **DIFFERENT**. Nothing was run against `agent-probe` or `experimental`.
- **Agents (read-only SOQL on `BotDefinition` and `BotVersion`).** Seven agent definitions. `SearchAgent` (label
  "Coworker Agent", Employee agent type) has v1 active. `Customer_Summary` has v1 active, with the repo's agent
  description unchanged. `Customer_Summary_Coworker_Spike` (FE-28) has v1 active and was left alone. The other four are
  sample agents that came with the org.
- **Session rows are not readable by SOQL.** `AiAgentSession`, `AiAgentSessionParticipant`, `BotSession` and
  `AiAgentInteraction` each returned `INVALID_TYPE`. So whether a turn delegated has to be read from the thinking steps
  Coworker streams, as OPS-63 did, not from `Customer_Summary` session rows.
- **Browser.** One new Chrome tab. The Salesforce docs read fine. The org's record page redirected to the Salesforce
  login page. The tab was closed; nothing was typed into it.

## How Coworker chooses another agent

| Question | What the docs say | Source |
|---|---|---|
| When does it delegate? | Only "When your users make a request that Agentforce Coworker can't complete". The section page says the same: when it "can't complete a request on its own, it can hand the request off to another Agentforce agent" | [C1], [C2] |
| What does it read to choose? | The agent and topic descriptions of the agents those users can access. Topics are also called sub-agents. It compares the request with each agent's capabilities and delegates on a match. It uses only those descriptions, not topic instructions | [C1] |
| Which agents? | Any Agentforce agent the users have access to, custom agents included; up to 50 agents | [C1] |
| Timeout | It times out if it cannot direct the request to another agent within 90 seconds. The page's remedy: rephrase, ask Coworker to delegate to an accessible agent, or try later | [C1] |
| What the user sees | The delegated agent's thinking steps streamed live, a confirmation when a delegated topic asks for one, and the agent's response, with cards from custom Lightning types and HXL widgets | [C1] |
| How to write descriptions | Agent and topic descriptions "act as routing rules". Scope each agent to one job, avoid overlapping sub-agents, keep replies well inside 90 seconds, and say which questions the agent handles best | [C1] |
| Trailhead's wording | Coworker "Routes requests to the right AI agent based on what you need" and acts as a front door to specialised agents | [C10] |

## Must an agent be added or granted to be callable?

| Mechanism | Answer | Source |
|---|---|---|
| Agent access (permission sets) | **Yes, needed.** Coworker considers only agents the user can access [C1]. For an Employee agent, access is set on the agent's Agent Access page in Agentforce Builder, or on a permission set or profile's Enabled Agent Access in Setup; only Employee agents appear in that list [C3]. The admin already holds it (OPS-63), so it is not the gap | [C1], [C3] |
| Agent and topic descriptions | **Yes, they are the routing input.** Coworker routes on them alone [C1] | [C1] |
| A Setup list of callable agents | **Not documented.** The Coworker setup section lists Turn On, search data, user access and user mapping [C4]. The Turn On page's agent-related item is the Coworker admin permission set [C5]. The user access page says nothing about delegation [C6] | [C4], [C5], [C6] |
| Connected agents, agent-to-agent in Builder | **Documented for agents you own, not for Coworker.** In Multi-Agent Orchestration a connected subagent is "an entirely separate agent in your Salesforce org that your orchestrator agent can use like a subagent" [C8]. It is added from the orchestrator's Explorer panel (+, Connect Agent as Subagent), with the orchestrator in draft [C7]. Coworker's Search Agent "you can't modify", and changes break it [C1]. So adding `Customer_Summary` as a connected subagent of the Search Agent would mean modifying it, which the docs rule out. No page read says Coworker's delegation uses Multi-Agent Orchestration | [C1], [C7], [C8] |
| A newly activated version | **Needed for Multi-Agent Orchestration** for customers who were not in its pilot: create and activate a new version of an agent built in the new Builder [C7], [C9]. Not stated for Coworker's delegation | [C7], [C9] |
| Coworker Skills | **Not a callable-agent mechanism in the docs.** Trailhead says Skills are made "from successful conversations" and "combine instructions, context, agents, and tools into shareable workflows" [C10]. No page says a Skill makes an agent callable | [C10] |

## What the docs say is not supported

- Modifying the Search Agent: it is preconfigured and platform-managed, and changes break Coworker's search and
  reasoning [C1].
- Coworker's own answers as cards: they stay in markdown; only a delegated agent's custom Lightning type or HXL
  response is drawn as a card [C1].
- In Multi-Agent Orchestration (not stated for Coworker): orchestration across orgs, with non-Agentforce agents,
  file-based agents, more than one level of delegation, and Agentforce Voice; a connected subagent cannot be
  deactivated; timeouts are 120 seconds for the orchestrator and 30 for a connected subagent [C9].

## Ways tried

None ran. The order the card set, and where each stands:

| Way | Status | What it needs |
|---|---|---|
| (a) The OPS-63 summary question with the agent named | **Not tried: browser signed out.** The docs support it as the user lever [C1] | A Chrome session signed in to `connect-24h` |
| (b) Changed agent and topic descriptions on `Customer_Summary`, edited in Builder, republished and reactivated | **Not tried: browser signed out.** Nothing was changed | The same. A new active version also changes a second thing besides the descriptions [C7], so a result would not credit the descriptions alone |
| (c) `Customer_Summary` as a connected or callable agent of the Coworker Agent | **Not tried, and not documented for Coworker.** The Search Agent cannot be modified [C1]; whether Builder offers Connect Agent as Subagent on it was not seen | A look in Builder at `SearchAgent`; any step that edits, re-versions or deactivates it needs Ben's go |
| (d) A Setup setting the docs name | **None found.** The only Coworker toggle near agents is Agent Actions, which the docs tie to creating and updating records, not to delegation [C11] | Nothing to try |

No rows were written to a results file, because no turn ran. No capture was taken.

## Undo

Nothing to undo. Changed in `connect-24h`: nothing. No description edited, no version published or activated, no
connected-agent link, no setting, no grant, no chat. Read-only SOQL only (agent definitions, versions, one account
lookup, four session-object probes that failed as `INVALID_TYPE`). One Chrome tab was opened for the docs and the org's
record page, and closed.

## For Ben

- **Which way works: unknown.** None ran, because the Chrome session for `connect-24h` was signed out and this run may
  not sign in. To rerun, sign Chrome in to `connect-24h` (or say whether a CLI frontdoor login counts as signing in),
  then re-dispatch OPS-64. The org was made for about 24 hours, so it may expire first.
- **What the docs predict.** Coworker delegates only what it cannot do itself [C1]. A summary of a named account is
  something its CRM search can do, which matches OPS-63's 0 of 9. Naming the agent (way a) is the documented lever.
  Sharper descriptions (way b) are the only routing input, but they may not move a question Coworker can already
  answer; that is untested.
- **Cost in latency and fidelity: not measured.** The documented ceiling is a 90-second handoff timeout [C1]. OPS-63
  measured Coworker alone at 13.5 to 16.3 seconds for the summary, with 0 of 6 of our section labels.
- **FE-28's re-cut and F83.** Nothing changes yet. A card in Coworker still needs a delegation first, and none has been
  seen. Adding our agent "to Coworker" as a connected agent is not a documented step, so if way (a) also fails, the
  docs leave no further lever short of Salesforce changing the Search Agent.

## Sources

All read in a Chrome tab on 2026-11-15. Salesforce Help pages are named by title and article id, since their links
carry a query string.

- [C1] Search Agent and Agent Delegation in Agentforce Coworker (Agentforce Coworker guide):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-customize-delegate-agent.html
- [C2] Use Agentforce Coworker (Agentforce Coworker guide, section page):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-manage-experience-home.html
- [C3] Manage Employee Agent Access (Salesforce Help, article `ai.agent_manage_aea_access.htm`).
- [C4] Set Up Agentforce Coworker (Agentforce Coworker guide, section page):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-setup-home.html
- [C5] Turn On Agentforce Coworker (Agentforce Coworker guide):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-turn-on-infrastructure.html
- [C6] Add or Remove User Access in Agentforce Coworker (Agentforce Coworker guide):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-manage-user-access.html
- [C7] Connect an Agent as a Subagent (Salesforce Help, article `ai.agent_multi_orch_connect.htm`).
- [C8] Multi-Agent Orchestration (Salesforce Help, article `ai.agent_multi_orch.htm`; the Salesforce Admins post
  below links it as "Multi-Agent Orchestration (Beta)").
- [C9] Considerations and Limitations in Multi-Agent Solutions (Salesforce Help, article
  `ai.agent_multi_orch_consider.htm`).
- [C10] Trailhead, Quick Start: Agentforce Coworker, unit "Enable and Use Agentforce Coworker in Your CRM":
  https://trailhead.salesforce.com/content/learn/modules/quick-start-agentforce-coworker/explore-agentforce-coworker
- [C11] Search, Ask, and Update Records with Agentforce Coworker (Agentforce Coworker guide):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-navigate-the-experience.html
- Also opened, not cited for a fact: How to Set Up a Super Agent with Connected Subagents (Salesforce Admins, 2026-08-20),
  https://admin.salesforce.com/blog/2026/how-to-set-up-a-super-agent-with-connected-subagents, used only to find [C8];
  Agentforce Coworker Limits and Guidelines, which names no delegation limit beyond the Search Agent's 100 requests a
  minute; and Give Users Access to Agentforce (Default) (Salesforce Help, `ai.copilot_setup_user_access.htm`), which
  is about the retired default agent.
