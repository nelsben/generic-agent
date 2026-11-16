---
id: BE-45
title: FR2+: explorer after-evaluation — BE-31's 30 questions run three times on the rebuilt deployed explorer, compared with BE-41's baseline, with the spread stated and pattern 02's numbers ready for the workbook
domain: backend
tier: standard
tier_reason: runs an existing harness and compares numbers; no product code changes
status: merged
blocked_by: [BE-44, BE-57]
fixes: []
scope: [spikes/explorer-scale/results/**, docs/research/fr2-explorer-after.md]
forbid: [force-app/**, spikes/explorer-scale/questions.json, spikes/explorer-scale/harness.apex, spikes/explorer-scale/run.py, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (evaluation): the evidence is docs/research/fr2-explorer-after.md and spikes/explorer-scale/results/after-deployed-*.jsonl
gate: test
budget: 2-attempts
spend: 8
---
## Why

Ben gave the go for the explorer build line (BE-41 to BE-45) on 2026-11-15; it is recorded in the Approvals table. BE-31 ran each engine once, and its metered replay and deployed run disagreed on 5 of 30 questions, so one run cannot tell a gain from noise. BE-41 measured the spread before the build; this card measures it after BE-42 to BE-44 so pattern 02 can state what changed with honest error bars. Covers ledger rows F55, F58 and F59 in docs/plans/feature-revision-2.md.

## Done when

- **Ben's go (2026-11-15):** part of the explorer build line BE-31 proposed (BE-41 to BE-45). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md, docs/research/fr2-explorer-baseline.md (BE-41), docs/research/fr2-explorer-catalog.md, docs/research/fr2-explorer-grammar.md and docs/research/fr2-explorer-long-text.md, and spikes/explorer-scale/run.py and harness.apex. Load the skill salesforce-development:platform-apex-anonymous-run first
- Run BE-31's 30 questions (spikes/explorer-scale/questions.json, unchanged) three times on the deployed DataExplorer.explore with BE-31's harness unchanged, results in spikes/explorer-scale/results/after-deployed-<run>.jsonl, counts, statuses and limits only, no names and no Ids
- docs/research/fr2-explorer-after.md gives, per question and per category: passes out of 3 before (BE-41) and after; median and range of model calls, input tokens, CPU and heap; and which questions flipped between runs. A gain is called a gain only where after passes 3 of 3 and before passed at most 1 of 3; anything else is named as within the spread. It ends with five lines for pattern 02 ready for OPS-39 to paste, each with its n
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No deploy. No security or red-team agent test. Never publish or activate an agent. Read-only anonymous Apex only; each run leaves the usual debug log
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-16). One worker attempt (sonnet, standard tier, $0.52). The brain read the note and checked the result files against BE-43's record format, the harness's grade function, and the pass counts in each file.

Findings:
- The after numbers come from the deployed DataExplorer.explore (prompt Explore_v2, catalog built per question), called through BE-43's driver kept outside the repo, not run.py's current replay. The note says so.
- After: 28, 27 and 28 of 30. Before (BE-41): 20, 20 and 20. The brain recounted each result file: run 1 fails q19 and q27, run 2 fails q13, q24 and q27, run 3 fails q19 and q27.
- Seven gains by the card's rule (after 3 of 3, before at most 1 of 3): q09, q11, q15, q17, q25, q26 and q29. q13, q19 and q24 flip between runs; q27 fails every run, as before.
- BE-58 alone moves no verdict. The brain checked harness.apex: the grade compares the answer's number, groups or record set with an independent query, and reads the status only to fail on ERROR.
- Cost: median 2 model calls per question (exact), about 7,100 input tokens (estimated). CPU and heap rose about 2.7x and 6x because the catalog is built per question; the worst cases are 1,615 ms of 10,000 and about 255 KB of 6 MB.
- 25 of the 30 rows in run 1 differ from BE-43's single run in more than timing.

Gate (mod): Python 393 tests, 4 skipped. check-docs 86 pages, 0 broken.

Org: agent-probe only. Read-only anonymous Apex; no deploy, no record, user or setting created.

Disclosed and accepted:
- The gain cannot be split between BE-42, BE-43, BE-44 and BE-57: all were deployed before the runs.
- Whether the grader is right on q27 is still unchecked.
- Input tokens are an estimate, and BE-41 shows no calls or tokens for the deployed engine, so there is no before/after on those.
- Pattern line 1 names the catalog, grammar and long-text builds; BE-57 and BE-58 were also deployed.

Still open:
- q27 (fails every run) and the grader check on its date window.
- q19's superset and q24's flip.

Privacy check over the branch's own diff (197 added lines): 0 denylist hits, no pattern hits, no URL hosts.
