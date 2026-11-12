---
id: OPS-34
title: FR2 (PARKED, tabled by Ben): demo data and industry scenarios, and one command vs an in-org setup page for the brand swap
domain: ops
tier: standard
tier_reason: an options paper with no org work
status: parked
blocked_by: [BE-24]
fixes: []
scope: [docs/research/fr2-later-options.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: none (options paper): the evidence is docs/research/fr2-later-options.md
gate: test
budget: 2-attempts
spend: 5
---
## Why

Feature revision 2 (FR2): Ben tabled two follow-ons so they are not lost: demo data and industry prospect scenarios, possibly "different GitHub repos with different options to ... populate different industry scenarios"; and whether the brand swap is one command or a setup page in the org. Covers ledger rows F10 and F11 in docs/plans/feature-revision-2.md.

## Done when

- PARKED: do not dispatch until Ben says go in chat. When he does, the brain splits this into concrete cards
- Read first: docs/plans/feature-revision-2.md (rows F10 and F11) and docs/patterns/10-brand-and-theming.md
- Write docs/research/fr2-later-options.md comparing (a) industry data packs in this repo vs separate repos per industry, with what each pack holds (accounts, contacts, deals, cases, activity, brand settings) and how a seller loads it; and (b) a one-command swap script vs an in-org setup page vs editing the record by hand, with effort and risk for each, and a recommendation for Ben. No org changes and no new repos
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
