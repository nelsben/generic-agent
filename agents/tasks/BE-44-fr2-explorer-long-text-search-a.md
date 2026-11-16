---
id: BE-44
title: FR2+: explorer long-text search — a SOSL proof in agent-probe first, then CONTAINS filters on long-text fields that match a hand query and refuse past the scan cap, with sorting and grouping on long text refused
domain: backend
tier: frontier
tier_reason: choice between SOSL and an Apex post-filter rests on an org proof; row caps and user mode in a production-classified org
status: merged
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

## Review

Brain review (2026-11-16). One worker attempt (opus, frontier tier, $2.97) and one reviewer pass (21 confirmed, 0 refuted, 4 unverifiable). The brain read the ExploreQuery search code. It asked the reviewer to check injection and user mode specifically; both are confirmed.

Findings:
- A read-only proof in agent-probe (spikes/explorer-scale/sosl-proof.apex, counts only) shows user-mode SOSL finds the seed data's long text. Search alone gives wrong counts: it matches any field and stems words (Event "pricing" returned 2 records, 1 holding the word in Description; Event "renewal" returned 1 through its Subject where the right count is 0), and it matches words, not substrings (renew found nothing, renew* found the record).
- So the exact path stays the one path. Up to 2,000 candidate rows, BE-43's scan and Apex match run unchanged and no search runs.
- Past 2,000 rows, where BE-43 refused, a search in user mode narrows the candidates. The same query then re-runs with the found Ids bound (Id IN :bN) in user mode, and the Apex match confirms each row. The trail ends in "(narrowed by search)".
- It refuses with a row-cap message when the search reaches 2,000 records, when no searchable word is left, when the field is on a parent record, or when the object can't be searched.
- The SOSL text is a built string, not a bind. The value is split on anything that is not a letter or digit, words under 2 characters and AND, OR and NOT are dropped, and the code adds the trailing *. So no quote, backslash, brace or other SOSL reserved character from the value reaches the search. A test pins a hostile value.
- ORDER BY and GROUP BY on long text are still refused by the planner, with one new test each.
- Five long-text questions, run once each through the deployed explorer, all matched their hand counts. The seed data is small, so all five took the scan path.

Gate (mod, at 62f0ee7): Python 393 tests, 4 skipped; validate-org pass, 215 components, 469 tests.

Org: agent-probe only. The worker validated with RunLocalTests and quick deployed ExploreQuery and ExploreQueryTest before review. No record, user or setting was created. The worktree-local target org is unset.

Disclosed and accepted:
- The search path has not run end to end in agent-probe; the proof checked search, re-read and match on the five values and got the hand counts.
- Past 2,000 rows, CONTAINS matches only words and word starts, and can miss records saved too recently to be indexed. The answer text does not say so; only the trail shows search was used.
- A common word can fill the 2,000-record search cap and make a question refuse even when few rows hold it.
- The parent-path and unsearchable-object refusals have no test.
- The red evidence is a compile failure (the new members do not exist on main), not assertion failures.

Still open:
- Saying in the answer when search narrowed a long-text match.
- An end-to-end run of the search path on an org with more than 2,000 candidate rows.

Privacy check over the branch's own diff (435 added lines): 0 denylist hits. The pattern hits are test annotations. No URL hosts.
