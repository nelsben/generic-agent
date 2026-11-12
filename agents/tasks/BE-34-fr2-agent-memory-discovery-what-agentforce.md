---
id: BE-34
title: FR2: agent memory discovery — what Agentforce's Agent Memory (and Data 360's agentic memory) covers against the product's customer history, where they overlap, where ours must stay, and how long an agent conversation keeps its variables
domain: backend
tier: frontier
tier_reason: a platform feature decision the memory design rests on, checked against docs and a production-classified org
status: queued
blocked_by: []
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

- **Dispatched only after Ben's go on the FR2 spikes** (the Approvals table in docs/plans/gtm-burn-plan.md). Read first: docs/plans/feature-revision-2.md (rows F74 to F80), docs/plans/fr2-design.md, docs/patterns/05-conversation-memory.md and 06-agent-routing-and-verbatim-relay.md, and the cards BE-26 and BE-35. Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-d360-analyze and salesforce-development:platform-capability-search first
- From Salesforce's help, release notes and developer docs (cite each), answer: what Agent Memory stores and who owns it (user, agent, account?); how it is turned on and what it needs (Agent Script, edition, Data 360, licences, cost); its limits (how many memories, retention, deletion, user controls, the org-wide switch); whether memories can be queried, reported on or read from Apex; whether they apply when an agent is called through the Agent API as the panel does, and in the MCP door; and how Data 360's agentic memory differs
- Check in agent-probe, read-only: whether the feature and its org-wide setting are present. Do not turn it on, change the agent, publish or activate. If proving a point needs the agent changed, write the exact Agent Script change and the test to run, for BE-28's one publish
- Measure how long an agent conversation keeps its variables (pattern 05's open item) through the Agent API: the same session after 1, 5, 15 and 30 minutes, printing only kept or lost
- docs/research/fr2-agent-memory.md ends with a table: each need from F75 to F78 (customer outcomes that persist against the account, reusable past summaries, sentiment over time, context when the rep opens a conversation) against Agent Memory, Data 360 agentic memory and our design, marked covered, partial or not covered, and a recommendation: what we keep, what we hand to the platform, and any change to BE-26, BE-35 or BE-28. Never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
