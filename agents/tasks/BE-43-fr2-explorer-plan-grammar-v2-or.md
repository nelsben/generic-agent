---
id: BE-43
title: FR2+: explorer plan grammar v2 — OR and grouped filters, two-level parent paths, child subqueries, semi-joins and chained steps, each built from catalog paths with bound values only and every platform rule BE-31 measured refused by the planner
domain: backend
tier: frontier
tier_reason: widens the query shapes the live explorer can build; injection safety and platform rules in a production-classified org
status: merged
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

## Review

Brain review (2026-11-15). One worker attempt (opus, frontier tier, $11.22) and one reviewer pass (19 confirmed, 0 refuted, 6 unverifiable). The brain read the DataExplorer diff. It asked the reviewer to check value binding and user mode specifically, and both checks are confirmed.

Findings:
- Plan grammar v2:
  - where trees with and, or and not (at most 4 groups deep, 20 conditions);
  - two-level parent paths;
  - NOT IN and CONTAINS;
  - semi-joins and anti-joins (at most 2, top level only, never on Task, Event or the same object, the right side checked against the lookup's referenceTo);
  - child lists (the cell is the child row count), HAVING and chained steps.
- Every value is bound, never concatenated. That covers OR groups, NOT IN, IN lists, step Id lists, date ranges, HAVING, and CONTAINS with its wildcards escaped. Only catalog paths, fixed operators and the rebuilt date literals reach the SOQL text. A test pins a hostile value in an OR group.
- Every query still runs in user mode, through the three USER_MODE calls in ExploreQuery. Semi-joins and child lists are sub-selects in the same string.
- The prompt is a new resource, AgentPrompt_Explore_v2, which DataExplorer reads. The shared AgentPrompt_Explore and its other readers are unchanged. The caps stay at 5 model calls and 4 queries per question.
- Result:
  - One live run on the deployed explorer passed 27 of 30. BE-41 scored 20, 20 and 20, and BE-42 scored 22.
  - q11, q15 and q17 now pass.
  - q18, q19 and q27 fail.
  - The run used 69 model calls (84 in BE-42), with median CPU 642 ms and median heap about 241 KB.
- q18's cause is found. ExploreCatalog keeps only the first 12 picklist values at describe time, before the question's named values are ranked first, so 'Technology' never reaches the model. BE-57 fixes this BE-42 defect.

Gate (mod, at 30aac31): Python 390 tests, 4 skipped; validate-org pass, 215 components, 463 tests.

Org: agent-probe only. The worker ran two validates with RunLocalTests, each followed by a quick deploy, before review. It deployed only the changed classes and the new prompt resource. No record, user, agent version or setting was created. A worktree-local target org was set for the deploy hook and then unset. The brain confirmed it is unset.

Disclosed and accepted:
- This is one run, not three. BE-45 runs the after-evaluation, after BE-44 and BE-57.
- Four rejection cases differ from the prototype in wording or test data only (case 2, 30, 32 and 37). Each outcome matches.
- No test sends a hostile CONTAINS or HAVING value. The code binds both, but only the OR-group case has a hostile-value test.
- The diagnostic re-ask for q18 is not kept in the repo. The causes of q19 and q27 are not established.
- CONTAINS on long text is an Apex post-filter: top level only, no aggregates, refused past 2,000 rows. Its heap risk is noted on the page.

Still open:
- q19 and q27.
- A hostile-value test for CONTAINS and HAVING.

Privacy check over the branch's own diff (1,584 added lines): 0 denylist hits. The pattern hits are test annotations. The only URL host is the standard metadata namespace.
