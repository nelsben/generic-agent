---
id: BE-32
title: FR2: standard chat limits, measured in agent-probe — the answer-length ceiling where Agentforce's own chat starts compressing or dropping sections, what its launcher and panel allow, and what the public docs say; the evidence behind "why custom"
domain: backend
tier: frontier
tier_reason: measurements of model behaviour in a production-classified org, with claims the whole GTM story will rest on
status: parked
blocked_by: []
fixes: []
scope: [spikes/standard-limits/**, docs/research/fr2-standard-limits.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (spike): the evidence is docs/research/fr2-standard-limits.md with its measurements and spikes/standard-limits/
gate: test
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2), Ben's note on why the product brings its own surfaces instead of standard Salesforce and Agentforce: the standard launcher "doesn't scale", "there's soft limits for how many characters", and "teams decelerate when trying to incorporate lightning cards into the responses". The page that says so (OPS-41) must rest on measured evidence and public docs, not opinion. Covers ledger row F66 in docs/plans/feature-revision-2.md.

## Done when

- **Dispatched only after Ben's go on the FR2 spikes** (the Approvals table in docs/plans/gtm-burn-plan.md). Read first: docs/plans/feature-revision-2.md (F60 to F66), the brain's generic restatement at .delegation/fr2/operating-pattern.md ('Limits of the standard Agentforce chat'; never name or quote its source), docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/research/agent-iteration-1.md and docs/research/panel-agent-1.md (how the panel already calls the agent through the API). Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-observe, salesforce-development:platform-apex-anonymous-run and salesforce-development:platform-capability-search first
- **The answer-length ceiling:** measure where the active agent in agent-probe stops relaying an action's answer whole. Send questions whose correct answers grow (for example about 2, 4, 6, 8, 12 and 16 thousand characters), through the Agent API from a caller in spikes/standard-limits (not the panel's "Ask the agent" client, which FE-20 removes), three runs each. Record for each run the characters the action returned, the characters relayed, and whether any section went missing. Compare with the same answers through the panel's direct Apex path. If no existing action can return a sized answer, use only what can be measured without changing or publishing the agent, and say what a measurement with a changed agent would add (no further agent publish is planned in FR2)
- **Rich cards in the standard chat:** from public Salesforce docs, what custom Lightning types and response formats need to show a card in Agentforce's own panel, who decides whether it shows, and the known limits. Point to FE-18 for what our surfaces do instead; do not repeat its work
- **The launcher and panel:** from public docs and a look in agent-probe (read-only), where the standard launcher lives, its sizes, whether it has a hotkey, history, layout control and per-surface branding, and what a customer can change. Every claim cites a doc link or a measured run; anything else is marked unproven
- **Fair to the platform:** list where the standard chat is the right choice (for example no custom code to maintain, the platform's own updates, orgs without developers)
- docs/research/fr2-standard-limits.md gives the method, every measurement in a table, the findings and the open questions. The prototype in spikes/standard-limits/ runs as anonymous Apex or a read-only script (no deploy, no data change). It prints sizes and pass or fail only, no names and no Ids. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
