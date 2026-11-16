---
id: BE-41
title: FR2+: explorer baseline — the 30 BE-31 questions run three times on the deployed explorer, with pass counts, spread and per-question medians recorded before any explorer build
domain: backend
tier: standard
tier_reason: reruns an existing harness with fixed questions and grading; no design choices
status: merged
fixes: []
scope: [spikes/explorer-scale/results/**, docs/research/fr2-explorer-baseline.md]
forbid: [force-app/**, mcp-door/**, data/**, tests/**, e2e/**, agents/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json, spikes/explorer-scale/questions.json, spikes/explorer-scale/harness.apex]
resources: [org-live]
red_test: none (discovery): the evidence is docs/research/fr2-explorer-baseline.md and the baseline result files
gate: test
budget: 2-attempts
spend: 8
---
## Why

Ben gave the go for the explorer build line (BE-41 to BE-45) on 2026-11-15; it is recorded in the Approvals table. BE-31 ran each of its 30 questions once per engine, and the metered replay and the deployed explorer disagreed on 5 of 30, so its 27 against 23 or 20 cannot separate engines. Before the explorer build (BE-42 to BE-44) changes anything, the deployed explorer needs a baseline of three runs. Covers ledger rows F55, F58 and F59 in docs/plans/feature-revision-2.md.

## Done when

- **Ben's go (2026-11-15):** this card and BE-42 to BE-45 are the explorer build line BE-31 proposed (docs/research/fr2-explorer-scale.md, 'Proposed build cards'). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md whole, spikes/explorer-scale/ (run.py, harness.apex, engine-real.apex, engine-current.apex, questions.json) and docs/patterns/02-ask-anything-explorer.md. Load the skills salesforce-development:platform-soql-query and salesforce-development:platform-apex-anonymous-run first
- Reuse BE-31's harness, questions and grading unchanged: no question, reference or grading rule changes. Run all 30 questions three times on the deployed DataExplorer.explore (engine real) and three times on the metered replay (engine current), one anonymous Apex transaction per question, read-only
- Results go to spikes/explorer-scale/results/baseline-<engine>-<run>.jsonl in BE-31's record format (counts, statuses and limits only: no names, no Ids, no answer text)
- docs/research/fr2-explorer-baseline.md records, per engine: the pass count of each run, the spread, per-question medians of model calls, input tokens, CPU and heap next to BE-31's, every question that failed in all three runs with its named cause, and the questions whose result changed between runs
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No deploy, no record written, no security or red-team agent test. A read-only step (a query, a describe, a list) needs no row
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). Say in the hand-back how many model calls the runs spent. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-15). One attempt (81d9757), sonnet, standard tier. The worker paused while its runs finished, which the mod logged as no-report; after the real hand-back the brain re-ran the verifier on 81d9757, which judged it consistent and accepted it. The brain read the page and recounted the result files.

Findings:
- All 180 transactions finished: 30 questions, three runs, two engines, read-only anonymous Apex in agent-probe. BE-31's harness, questions and grading are unchanged.
- The deployed explorer passed 20, 20 and 20 of 30 (BE-31's single run: 20). The count is steady but the set is not: q09, q16, q19 and q20 changed result between runs.
- The metered replay passed 17, 21 and 22 (BE-31's single run: 23), a spread of 5, with 8 questions changing result.
- So the two engines cannot be told apart, and the build is judged against 20 for the deployed explorer. A gain has to clear a spread of about 5.
- Eight questions failed in all three deployed runs: q25 and q26 (long text cannot be filtered), q29 (the object is outside the catalog), q11, q15 and q17 (the grammar cannot express them), q24 (the last table is the wrong object) and q27 (its second query returns 0 rows; cause not established, and the page says so).
- Limits are far from binding: worst CPU 373 ms, worst heap about 80 KB.
- The brain's recount from the six result files matches the page: passes 20, 20, 20 and 17, 21, 22; 271 replay model calls.

Gate (worker and mod): Python 390 tests, 4 skipped; check-docs 0 broken.

Org: agent-probe only, read-only. Nothing deployed and no record written. The replay spent 271 model calls; the deployed engine's calls cannot be counted from outside it and are not estimated.

Disclosed and accepted:
- run.py writes to a fixed file name that would have overwritten BE-31's results, so the worker drove it through a wrapper kept outside the repo. run.py is unchanged.

Still open:
- q27's cause (BE-31 flagged its date window against the reference).
- The deployed engine's model calls and tokens are not visible from the harness.

Privacy check over the full branch diff (316 added lines): 0 denylist hits, no pattern hits, no URL hosts. The result rows hold counts, statuses and limits only.
