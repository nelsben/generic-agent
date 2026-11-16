---
id: BE-44
title: FR2+: explorer long-text search — a SOSL proof in agent-probe first, then CONTAINS filters on long-text fields that match a hand query and refuse past the scan cap, with sorting and grouping on long text refused
domain: backend
tier: frontier
tier_reason: choice between SOSL and an Apex post-filter rests on an org proof; row caps and user mode in a production-classified org
status: blocked
blocked_by: [BE-43]
fixes: []
scope: [force-app/main/default/classes/ExploreQuery*, spikes/explorer-scale/sosl-proof.apex, spikes/explorer-scale/results/**, docs/research/fr2-explorer-long-text.md]
forbid: [force-app/main/default/classes/ExploreCatalog*, force-app/main/default/classes/ExplorePlan*, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/staticresources/**, mcp-door/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new ExploreQueryTest cases (CONTAINS on a long-text field returns the matching row, the scan-cap message, long-text ORDER BY refused) fail on main and pass after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

Ben gave the go for the explorer build line (BE-41 to BE-45) on 2026-11-15; it is recorded in the Approvals table. SOQL cannot filter long-text fields, and BE-31's SOSL attempt in user mode found nothing in agent-probe, so its prototype used an Apex post-filter with a 2,000-row scan cap. This card proves SOSL properly before choosing, then ships one long-text path with an honest cap. Covers ledger row F58 in docs/plans/feature-revision-2.md.

## Done when

- **Ben's go (2026-11-15):** part of the explorer build line BE-31 proposed (BE-41 to BE-45). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md (the long-text and SOSL findings), docs/research/fr2-explorer-grammar.md (BE-43), spikes/explorer-scale/prototype.apex (its post-filter) and the ExploreQuery classes. Load the skills salesforce-development:platform-soql-query, salesforce-development:platform-apex-anonymous-run, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- **SOSL proof first,** read-only anonymous Apex in agent-probe under spikes/explorer-scale/sosl-proof.apex: FIND on a word known to be in a seed-data long-text field (Description or a case comment), in user mode and in system mode, with the search index wait noted. Record what each returned as counts only. If user-mode SOSL finds the record, the card uses SOSL; if not, it keeps the post-filter and says why with the evidence
- A plan may put CONTAINS on a long-text field. On BE-31's two long-text questions and three more the worker writes, the explorer's rows match a hand query (written in the research page, run once, counts only). Past the scan cap the answer says it stopped at the cap and how many rows it scanned; it never claims a full count. User mode applies to every query, SOSL or SOQL
- ORDER BY and GROUP BY on a long-text field are refused by the planner before SOQL (BE-43's rule) and stay refused after this card; an Apex test covers each
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy. No security or red-team agent test. No record written by the proof. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Never publish or activate an agent
- docs/research/fr2-explorer-long-text.md gives the proof, the choice and the cap. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
