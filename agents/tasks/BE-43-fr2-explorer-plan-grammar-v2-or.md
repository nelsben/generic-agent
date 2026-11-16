---
id: BE-43
title: FR2+: explorer plan grammar v2 — OR and grouped filters, two-level parent paths, child subqueries, semi-joins and chained steps, each built from catalog paths with bound values only and every platform rule BE-31 measured refused by the planner
domain: backend
tier: frontier
tier_reason: widens the query shapes the live explorer can build; injection safety and platform rules in a production-classified org
status: blocked
blocked_by: [BE-42]
fixes: []
scope: [force-app/main/default/classes/ExplorePlan*, force-app/main/default/classes/ExploreQuery*, force-app/main/default/classes/DataExplorer*, force-app/main/default/staticresources/AgentPrompt_Explore*, spikes/explorer-scale/results/**, docs/research/fr2-explorer-grammar.md]
forbid: [force-app/main/default/classes/ExploreCatalog*, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/customMetadata/**, mcp-door/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new ExplorePlanTest and ExploreQueryTest cases (an OR filter, a two-level parent path, a semi-join, the three-semi-join refusal, the long-text ORDER BY refusal, the injection bind) fail on main and pass after
gate: test, org
budget: 2-attempts
spend: 15
---
## Why

Ben gave the go for the explorer build line (BE-41 to BE-45) on 2026-11-15; it is recorded in the Approvals table. Today's plan grammar allows AND-only filters and one-level parent paths, so follow-ups like "accounts with an open case and no activity in 30 days" fail. BE-31's prototype built every shape the card named from catalog paths with bound values and measured the platform rules that a planner must refuse before SOQL. Covers ledger row F58 in docs/plans/feature-revision-2.md.

A measured case from BE-30 (docs/research/fr2-follow-ups.md, 2026-11-13): "who there have we not called?" after a summary of a seed account failed 3 of 3 live runs, because the plan language has no anti-join. BE-30 did not add one; it waits for this card.

## Done when

- **Ben's go (2026-11-15):** part of the explorer build line BE-31 proposed (BE-41 to BE-45). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md ('Combinations', 'Limits', 'Risks'), docs/research/fr2-explorer-catalog.md (BE-42), spikes/explorer-scale/prototype.apex (its grammar), spikes/explorer-scale/rejections.apex and spikes/explorer-scale/soql-rules.apex, and the ExplorePlan, ExploreQuery and DataExplorer classes with their tests. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-soql-query, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- The plan grammar accepts OR and grouped filters, parent paths up to two levels, child subqueries and semi-joins or anti-joins, and chained steps where a later step filters on an earlier step's Ids; every object and field name is checked against BE-42's catalog for the running user, every value is bound, and no model text is ever concatenated into SOQL
- The planner refuses, with a fixed INVALID line the model can act on, each rule BE-31 measured: more than 2 semi-joins, a semi-join that is not at the top level, a Task or Event inner select, and ORDER BY or GROUP BY on a long-text field (which ends the transaction with an exception Apex cannot catch). Each is an Apex test
- Every shape in spikes/explorer-scale/rejections.apex becomes an Apex test with the same expected outcome (44 checks), and one injection test shows a hostile value (quotes, a closing parenthesis, a second clause) reaches the query as a bind and changes no SOQL text
- Prompt file: list every class and surface that reads AgentPrompt_Explore (or the resource BE-42 added) before changing it. If anything besides DataExplorer reads it, add a new static resource whose name starts with AgentPrompt_Explore (so it stays in scope) instead of editing the shared one (the OPS-30 lesson), and say which in the hand-back. Chained steps keep the explorer's existing cap on model calls per question; say the cap in the hand-back
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Never publish or activate an agent
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1; run BE-31's 30 questions once on the deployed explorer and record pass count per category (single object, parent, child, OR, semi-join, chained), model calls, input tokens, CPU and heap next to BE-41's baseline and BE-42's run. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
