---
id: OPS-5
title: Agent API research: calling the Account_Brief agent programmatically and getting its replies back, written to docs/research/agent-api.md
domain: ops
tier: standard
tier_reason: reading and summarising documentation with sources; no code
status: merged
scope: [docs/research/agent-api.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**]
resources: [chrome]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

generic-agent is meant to be a gold-plated, reusable Agentforce baseline: one Apex engine (three invocable actions: AccountBriefResolver, AccountBriefGetAction, ExploreAction) with several doors. A custom panel and a registered Employee agent (Account_Brief) exist. Before designing the outside doors we need documented facts, not memory, about how Salesforce exposes actions and agents to outside callers. The brain will read and summarize the write-up, so it must be accurate, sourced and short.

## Done when

- Read docs/ARCHITECTURE.md first so you know the engine, the three invocable actions and the Account_Brief agent
- Research only; change nothing but your one output file. No deploys, no org writes, no setup changes. Read-only org probes against the org alias `experimental` are allowed (sf data query, sf org list metadata-types, sf org list metadata, describe calls) to check what is enabled there; say what each probe showed
- Sources: official Salesforce documentation first (developer.salesforce.com, help.salesforce.com, architect.salesforce.com, official Salesforce GitHub orgs and npm packages), then Salesforce blogs and release notes. Community posts only when nothing official exists, and label them
- WebFetch gets HTTP 403 from developer.salesforce.com. Do not retry it there. Use the Chrome browser tools instead: load them with one ToolSearch call (select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__get_page_text,mcp__claude-in-chrome__find,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__tabs_close_mcp,mcp__claude-in-chrome__browser_batch), navigate, and read with get_page_text. get_page_text drops code samples (they show as a bare language name); when a sample matters, read it with read_page on that element. Follow each guide's next-page links until they loop so you read the whole guide, and list every page you read. Close every tab you opened before handing back
- In the browser: read only. Do not sign in anywhere, do not submit forms, do not accept cookie or consent banners beyond declining non-essential, do not download files
- Every fact in the write-up carries its source URL and one status word: documented (official page says it), verified (you saw it in the experimental org) or unverified (community source or inference). Never fill a gap from memory; write 'not found' with what you searched
- The write-up starts with a 5-10 line plain answer to the lane's question, then: a facts table (fact, status, source), availability (GA, beta or pilot; editions, licences, API version), setup steps in order, the metadata types involved and whether they deploy from source with sf, limits and costs, open questions, and a recommendation for generic-agent with the smallest first step. Keep it under 250 lines. No client names, no confidential material, no content from reference/
- Gate passes: test. Commit, do not push
- Answer: can a caller start a session with our Account_Brief agent, send messages and read its replies programmatically, from (a) outside Salesforce and (b) Apex or an LWC inside the same org, and what does each need
- Cover the Agent API itself: endpoints, session lifecycle (start, send, end), synchronous versus streaming, the reply structure (plain text, rich or Lightning Type results, citations), how context variables and a record Id are passed, and auth (External Client App, client credentials, scopes)
- Cover agent-type support precisely: which agent types the Agent API supports and whether an Employee agent (AgentforceEmployeeAgent) is one of them; quote the sentence and URL that decides it. If Employee agents are excluded, say which type would be needed and what changes that implies
- Cover in-org invocation alternatives: an invocable action or Apex class that invokes an agent, ConnectApi classes, Flow agent actions, calling the Agent API from Apex through a Named Credential; for each, whether it returns the agent's reply to the caller
- Cover limits and cost: timeouts, rate limits, how requests are metered or billed, session expiry
- Probe experimental read-only: confirm the Account_Brief BotDefinition, its type and active version, and any existing External Client Apps or connected apps relevant to the Agent API
- Recommendation: the smallest path for a custom LWC panel to hold a conversation with Account_Brief and render the reply itself, with the setup it needs, or a plain statement that it is not possible for this agent type

## Review

Brain read docs/research/agent-api.md at 0c2af15: each claim carries a status and a source; org probes were read-only and the agent action was listed, not invoked. Open before any build: whether generateAiAgentResponse returns a reply for Account_Brief as the calling user, and whether Agent API start-session accepts an Employee-type agent. Help-article details are from search summaries and marked unverified. The write-up names other apps and credentials in the org; scrub before the repo is shared.
