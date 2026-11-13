---
id: BE-34
title: FR2: agent memory discovery — what Agentforce's Agent Memory (and Data 360's agentic memory) covers against the product's customer history, where they overlap, where ours must stay, and how long an agent conversation keeps its variables
domain: backend
tier: frontier
tier_reason: a platform feature decision the memory design rests on, checked against docs and a production-classified org
status: merged
fixes: []
scope: [spikes/agent-memory/**, docs/research/fr2-agent-memory.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (discovery): the evidence is docs/research/fr2-agent-memory.md
gate: test
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 05: "Agentforce just released Agentforce Memories ... we need to research what Agentforce Memories are to see if that impacts our design at all. Maybe it's partial coverage". He wants to be sure the feature "doesn't supersede our ability to store briefs and have context and history for an agent when the rep opens up the conversation". Public write-ups describe Agent Memory as per user and per agent, set in Agent Script, capped at about 50 memories per user per agent, with user controls and an org-wide off switch, and separate from Data 360's agentic memory; each of those must be checked against Salesforce's own docs. Covers ledger rows F74 and F79 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: spikes in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back
- Read first: docs/plans/feature-revision-2.md (rows F74 to F80), docs/plans/fr2-design.md, docs/patterns/05-conversation-memory.md and 06-agent-routing-and-verbatim-relay.md, and the cards BE-26 and BE-35. Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-d360-analyze and salesforce-development:platform-capability-search first
- From Salesforce's help, release notes and developer docs (cite each), answer: what Agent Memory stores and who owns it (user, agent, account?); how it is turned on and what it needs (Agent Script, edition, Data 360, licences, cost); its limits (how many memories, retention, deletion, user controls, the org-wide switch); whether memories can be queried, reported on or read from Apex; whether they apply when an agent is called through the Agent API or reached from a channel, and whether anything reaches our own surfaces or the MCP door, which do not use the agent (ledger F83); and how Data 360's agentic memory differs
- Check in agent-probe, read-only: whether the feature and its org-wide setting are present. Do not turn it on, change the agent, publish or activate. If proving a point needs the agent changed, write the exact Agent Script change and the test to run as a proposal only (BE-28 is parked)
- Measure how long an agent conversation keeps its variables (pattern 05's open item) from anonymous Apex with the generateAiAgentResponse invocable action (never the REST Agent API, a client app or a consumer key): the same session after 1, 5, 15 and 30 minutes, printing only kept or lost. No deploy. The only data written is the product's own session rows; record how many
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-agent-memory.md ends with a table: each need from F75 to F78 (customer outcomes that persist against the account, reusable past summaries, sentiment over time, context when the rep opens a conversation) against Agent Memory, Data 360 agentic memory and our design, marked covered, partial or not covered, and a recommendation: what we keep, what we hand to the platform, and any change to BE-26, BE-35 or the optional agent (OPS-44). Never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Three attempts; the brain raised the budget from 2 to 3 for the last one (the brief records 3-attempts).

Attempt 1 stopped on an API authentication error after the org runs, with no hand-back (verdict no-report); the brain resumed the same worker, which finished as attempt 2 at 35e9c95. Attempt 2 review: 13 confirmed, 1 refuted, 7 unverifiable. The refuted row: the page called the 30-minute session "the oldest of eight sessions open at once", but its own timeline puts the four wasted first-pass sessions earlier. Attempt 3 (70d90df) rewrote only that bullet: the 30-minute session was the first of the four measured sessions to start, eight were open at once and the four first-pass sessions were older still; start times only, no Ids. The first attempt-3 review refuted only a clean-tree claim, on an untracked tests/__pycache__ created after the commit by a later gate run; the brain removed it, re-ran the verifier at the same sha and a fresh review gave 13 confirmed, 0 refuted, 5 unverifiable.

The brain read the page and both spike files. Findings:
- Agent Memory is per user and per agent (50 per agent plus a 50-item user-level pool, oldest replaced), not keyed to an account, on in Agent Script with `context: memory: enabled: True` (lower-case `true` fails to compile).
- It works only inside the agent, so the panel, the rail and the MCP door never get it. Data 360's agentic memory is a separate product, and Data 360 is off in agent-probe.
- agent-probe lists four memory actions at v68 (two at v66); the CoworkerMemory describe returns NOT_FOUND; the org-wide switch's state is unknown.
- An agent session kept its context at 1, 5 and 15 idle minutes and lost it at 30: one sample, cause unproven.
- Recommendation: keep BE-26 and BE-35 unchanged; Agent Memory only as a later opt-in proposal on the optional agent under its own Approvals row; nothing on Data 360 in FR2.

Org: read-only checks plus 12 agent turns from anonymous Apex (4 wasted on a debug-log parsing slip, 8 measured). Rows written: Customer_Summary_Session__c 0 created, 1 updated (the Edge Communications row, brief count 31 to 42). Nothing deployed, published, activated or switched on.

Disclosed and accepted:
- No help.salesforce.com or developer.salesforce.com page body was read; those facts come from search snippets and are labelled so on the page. Help articles are cited by article name.
- The worker opened and closed one Chrome tab of its own.
- The red file is red-1.txt for all attempts (CHASSIS_ATTEMPT was unset after the resume).

Still open:
- Calling the memory actions from Apex is untried.
- "Kept" does not prove briefed_account_id itself was read; only a session trace would, and traces need Data 360.
- The 30-minute loss is one sample, with session age and the number of open sessions not separated from idle time.

Privacy grep over the full diff (343 added lines): 0 hits.
