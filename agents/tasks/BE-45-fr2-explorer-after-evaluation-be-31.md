---
id: BE-45
title: FR2+: explorer after-evaluation — BE-31's 30 questions run three times on the rebuilt deployed explorer, compared with BE-41's baseline, with the spread stated and pattern 02's numbers ready for the workbook
domain: backend
tier: standard
tier_reason: runs an existing harness and compares numbers; no product code changes
status: parked
blocked_by: [BE-44]
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

Parked for Ben's go (the explorer build line BE-41 to BE-45). BE-31 ran each engine once, and its metered replay and deployed run disagreed on 5 of 30 questions, so one run cannot tell a gain from noise. BE-41 measured the spread before the build; this card measures it after BE-42 to BE-44 so pattern 02 can state what changed with honest error bars. Covers ledger rows F55, F58 and F59 in docs/plans/feature-revision-2.md.

## Done when

- **Parked for Ben's go:** part of the explorer build line BE-31 proposed (BE-41 to BE-45). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md, docs/research/fr2-explorer-baseline.md (BE-41), docs/research/fr2-explorer-catalog.md, docs/research/fr2-explorer-grammar.md and docs/research/fr2-explorer-long-text.md, and spikes/explorer-scale/run.py and harness.apex. Load the skill salesforce-development:platform-apex-anonymous-run first
- Run BE-31's 30 questions (spikes/explorer-scale/questions.json, unchanged) three times on the deployed DataExplorer.explore with BE-31's harness unchanged, results in spikes/explorer-scale/results/after-deployed-<run>.jsonl, counts, statuses and limits only, no names and no Ids
- docs/research/fr2-explorer-after.md gives, per question and per category: passes out of 3 before (BE-41) and after; median and range of model calls, input tokens, CPU and heap; and which questions flipped between runs. A gain is called a gain only where after passes 3 of 3 and before passed at most 1 of 3; anything else is named as within the spread. It ends with five lines for pattern 02 ready for OPS-39 to paste, each with its n
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No deploy. No security or red-team agent test. Never publish or activate an agent. Read-only anonymous Apex only; each run leaves the usual debug log
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
