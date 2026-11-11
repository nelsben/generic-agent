---
id: OPS-4
title: MCP research: how Salesforce exposes Apex invocable actions and Agentforce agents to outside MCP clients, written to docs/research/salesforce-mcp.md
domain: ops
tier: standard
tier_reason: reading and summarising documentation with sources; no code
status: merged
scope: [docs/research/salesforce-mcp.md]
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
- Answer: what does Salesforce offer for MCP today (hosted MCP servers, Agentforce MCP support, the Salesforce DX MCP server, anything else), and which of them lets an outside MCP client such as Claude call our three invocable Apex actions with the calling user's own permissions
- Cover: what can be exposed as an MCP tool (invocable Apex, Flows, prompt templates, Agentforce actions, a whole agent, SOQL or record APIs); how a tool is registered and named; how authentication works (External Client App, OAuth flows, per-user versus integration user) and whether sharing and field security apply as the calling user; the server URL shape and how a client connects
- Cover the reverse direction in a short section: an Agentforce agent consuming outside MCP servers, and whether that matters for this baseline
- Cover whether a registered Agentforce agent (ours is an Employee agent, type AgentforceEmployeeAgent) can itself be called as an MCP tool, or only its actions
- Probe experimental read-only for MCP-related metadata types and settings and report what exists
- Recommendation: the exact smallest set of metadata and setup steps to make AccountBriefGetAction callable over MCP, and what of that can live in the repo as source

## Review

Brain read docs/research/salesforce-mcp.md at 7abaeea: every claim carries a status (documented, verified, unverified, not found) and a source; org probes were read-only. Open before any build: whether public invocable methods list under APEX_ACTION, whether an Employee-type agent lists under PLATFORM_AGENT, and whether Developer Edition runs a custom hosted server end to end.
