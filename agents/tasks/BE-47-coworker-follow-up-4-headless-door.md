---
id: BE-47
title: Coworker follow-up 4: headless door probe — from Apex in an org with Coworker on, try each door the docs name (the agent invocable against the Search Agent, the Enterprise Search API, the Coworker MCP server) and record yes or no with the evidence
domain: backend
tier: standard
status: blocked
blocked_by: [OPS-58]
fixes: []
scope: [spikes/coworker/**, docs/research/fr2-coworker-spike.md]
forbid: [force-app/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, mcp-door/**, e2e/**, data/**, spikes/cards/**, spikes/actions/**]
resources: [org-live]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

Ben's first Coworker question was whether our components can call Coworker. The guide documents no in-org door for Ask, but it names a platform-managed Search Agent that appears in the agent list, an Enterprise Search API under Connect API limits, and a Coworker MCP server for outside clients (docs/research/fr2-coworker-spike.md, with OPS-57's reading of their docs). This card tries each one once from Apex, so answer 1 on the page reads yes or no from evidence instead of from the docs' silence.

## Done when

- Read first: docs/research/fr2-coworker-spike.md in full (with OPS-57's sections on the Enterprise Search API, the Coworker MCP server and the Search Agent, and OPS-58's 'Delegation, measured'), docs/research/agent-api.md (how the in-org invocable `generateAiAgentResponse` was called for Account_Brief: inputs, outputs, the JSON envelope) and docs/research/salesforce-mcp.md. Load the skills salesforce-development:platform-apex-anonymous-run and salesforce-development:platform-soql-query first
- **Approval first.** Read the row 'FR2+: Agentforce Coworker live steps' in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with 'approved', or it does not name running the agent invocable and any search API from anonymous Apex, do no live step: write on the page that the probe waits on that row, and hand back. When approved, work only in the org alias the row names, the same org OPS-58 used
- **Org rules.** `-o <alias>` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, enter credentials, or accept consent. Never create a connected app, External Client App, Named Credential or auth provider, and never retrieve, print or commit a consumer key, secret, token or session Id. No deploy at all: anonymous Apex and read-only queries only, and every anonymous Apex script is checked into spikes/coworker/ before it runs. No Ids, usernames, emails, hostnames or query-string URLs in any file
- **Door 1, the Search Agent through the invocable.** Find the Search Agent by a read-only BotDefinition query (record its type and status, not its Id in any file). From anonymous Apex, call the invocable the way agent-api.md did for Account_Brief, against the Search Agent, with one plain question about one existing seed-data account. Record the outcome: an answer (its length and whether it names the account), or the exact error type and message with any Id removed. Then the same call against `Customer_Summary` once, as the control
- **Door 2, the Enterprise Search API.** If OPS-57 found an Apex `ConnectApi` class or a REST path that same-org Apex may call without a new app or secret, call it once from anonymous Apex with a search term from the seed data, and record the status and how many results and whether a summary came back. If it needs anything this card may not create, record 'not tried: needs <thing>'
- **Door 3, the Coworker MCP server.** Only if OPS-57 found that an in-org caller can reach it with no new app, secret or sign-in, make one tools-list call and record the status. Otherwise record 'not tried: needs <thing>' from OPS-57's reading. Never sign in
- **Results.** Write spikes/coworker/results/headless.jsonl (one line per door try: door, target, status, error type or answer length, seconds, date; no Ids) and keep the scripts in spikes/coworker/. On the page, answer 1 at the top and the headless table read yes, no, or not tried for each door, with the evidence and the reason. If a door works, add what the panel would need to use it (an @AuraEnabled wrapper, the user context it runs as, the latency) as a proposal for Ben, and say plainly that using it makes Coworker a way in, which is F83 and Ben's decision. Update 'What stays unproven' and 'For Ben'
- **Undo.** Nothing is deployed or granted by this card. The page's Undo section says so, and lists any session the invocable opened and whether it was ended
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. The hand-back gives the yes, no or not-tried for each door and the evidence
