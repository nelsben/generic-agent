---
id: BE-32
title: FR2: standard chat limits, measured in agent-probe — the answer-length ceiling where Agentforce's own chat starts compressing or dropping sections, what its launcher and panel allow, and what the public docs say; the evidence behind "why custom"
domain: backend
tier: frontier
tier_reason: measurements of model behaviour in a production-classified org, with claims the whole GTM story will rest on
status: merged
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

- **Approval first:** read the row "FR2: spikes in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back
- Read first: docs/plans/feature-revision-2.md (ledger rows F60 to F66), docs/plans/fr2-design.md ('Operating principles'), docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/research/agent-iteration-1.md and docs/research/panel-agent-1.md (how the panel already calls the agent through the API). Load the skills agentforce-adlc:agentforce-generate, agentforce-adlc:agentforce-observe, salesforce-development:platform-apex-anonymous-run and salesforce-development:platform-capability-search first
- **The answer-length ceiling:** measure where the active agent in agent-probe stops relaying an action's answer whole. Send questions whose correct answers grow (for example about 2, 4, 6, 8, 12 and 16 thousand characters), from anonymous Apex in spikes/standard-limits with the generateAiAgentResponse invocable action (never the REST Agent API, a client app or a consumer key) (and not the panel's "Ask the agent" client, which FE-20 removes), three runs each. Record for each run the characters the action returned, the characters relayed, and whether any section went missing. Compare with the same answers through the panel's direct Apex path. If no existing action can return a sized answer, use only what can be measured without changing or publishing the agent, and say what a measurement with a changed agent would add (no further agent publish is planned in FR2)
- **Rich cards in the standard chat:** from public Salesforce docs, what custom Lightning types and response formats need to show a card in Agentforce's own panel, who decides whether it shows, and the known limits. Point to FE-18 for what our surfaces do instead; do not repeat its work
- **The launcher and panel:** from public docs and a look in agent-probe (read-only), where the standard launcher lives, its sizes, whether it has a hotkey, history, layout control and per-surface branding, and what a customer can change. Every claim cites a doc link or a measured run; anything else is marked unproven
- **Fair to the platform:** list where the standard chat is the right choice (for example no custom code to maintain, the platform's own updates, orgs without developers)
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-standard-limits.md gives the method, every measurement in a table, the findings and the open questions. The prototype in spikes/standard-limits/ runs as anonymous Apex or a read-only script (no deploy; the only data written is the product's own session rows, and the page records how many). It prints sizes and pass or fail only, no names and no Ids. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Two attempts.

Attempt 1 (983c711): 18 confirmed, 1 refuted, 7 unverifiable. The refuted row: "the direct path took 5 to 9 s" held for the explore rungs only; the brief took 22 to 25 s direct. Attempt 2 (8e259cd) fixed the three timing lines and nothing else: 8 confirmed, 0 refuted, 1 unverifiable. The brain checked every timing line against results/direct.jsonl and agent.jsonl.

Findings:
- No answer-length ceiling up to 5,811 characters, the most any existing action returns: 18 of 18 explore relays kept every row, column, footer and name. Above 5.9k it is unmeasured.
- The only cut seen is our own: ExploreAction's 5,900-character cap showed 36 of 47 rows through the agent, where the panel's direct path showed 47 of 47.
- The agent reformatted the brief in 6 of 6 runs (1 of 6 labels on its own line, against 6 of 6 from the action; 0 bullet lines against 4 in runs 4 to 6), despite the script's verbatim instruction. No section was seen missing; words were not compared.
- Agent turns: 13 to 33 s for explore, 31 to 36 s for the brief, against 5 to 9 s and 22 to 25 s on the direct path.
- Cards in the standard chat need a custom Lightning type, an Apex action and is_displayable; the output config decides, not the model (public docs).

Org: read-only anonymous Apex and a settings retrieve to a folder outside the repo; nothing deployed, published, activated or changed, no user created. Data written: 12 brief turns appended to the running user's existing Customer_Summary_Session__c row (42 to 54), which the product writes on every brief.

Disclosed and accepted:
- The 8k, 12k and 16k rungs were not run: they need a changed action and an agent publish, which FR2 does not plan. The page says what that run would add.
- The standard panel was not opened in a browser (the only signed-in session was the do-not-touch org); its size, hotkey, history and branding are marked unproven.
- Session tracing is off in agent-probe, so the direct call on the same question stands in for the action's output inside an agent turn.
- Public-docs claims were not re-fetched by the reviewer; Help articles are cited by id.
- Rounding: the explore table note gives the panel path as 4.8 to 5.8 s; the slowest run is 5,899 ms (5.9 s). It changes no finding.

Still open:
- The ceiling above 5.9k characters and where the documented ~2,048-token reply limit bites.
- Whether any word of the brief changed in the relay, and whether the model or the platform reformats.
- Whether a non-admin user sees the same relay.
- The repo's "keep each action's answer under about 6,000 characters" rule (pattern 06) has no measurement behind it; OPS-41 should cite this page, not the rule.

Privacy grep over the full diff (751 added lines): 0 hits.
