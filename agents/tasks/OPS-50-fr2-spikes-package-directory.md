---
id: OPS-50
title: FR2: one package directory for spikes — sfdx-project.json gains the non-default directory 'spikes', its test allows it, and spikes/README.md says nothing under it is deployed by the quick start; no org step
domain: ops
tier: economy
tier_reason: one JSON entry, one changed assertion and a short README
status: merged
fixes: []
scope: [sfdx-project.json, tests/test_sfdx_project.py, spikes/README.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, e2e/**, agents/**, docs/**, README.md, .chassis-delegation.json, reference/**]
red_test: tests/test_sfdx_project.py test_package_directories expects a third entry (path 'spikes', default false); it fails before sfdx-project.json has the entry and passes after
gate: test
budget: 2-attempts
spend: 3
---
## Why

Feature revision 2 (FR2): the spikes keep their throwaway code under spikes/, outside the product. As first cut, three spikes (OPS-29, BE-21 and BE-22) each needed the same new line in sfdx-project.json and the same change to its exact-match test, and only one of them had those files in scope (finding 27 in docs/reviews/fr2-plan-review.md). This card makes that one change once, with no org step, so every spike after it only adds its own subfolder.

## Done when

- **Dispatched only after Ben's go for the FR2 burn** (docs/plans/feature-revision-2.md, 'Ben's to-do'): the card is parked until then, and the brain sets it to queued on his word. It has no org step and needs no row in the Approvals table of docs/plans/gtm-burn-plan.md. Read first: sfdx-project.json, tests/test_sfdx_project.py and docs/plans/fr2-design.md
- sfdx-project.json gains exactly one entry in packageDirectories, after mcp-door: path 'spikes' with default false. Nothing else in the file changes: the name, the namespace, the login URL, the API version and the replacements block stay as they are
- tests/test_sfdx_project.py: test_package_directories expects the three entries in order (force-app as the default, then mcp-door, then spikes), still as an exact comparison. No other test in the file changes
- spikes/README.md (it also makes the folder exist in git: the CLI can refuse a project that names a package directory missing on disk) says in plain words: what the folder is for (throwaway FR2 spike code, one subfolder per spike, named in that spike's card); that nothing under it is deployed by the README's quick start, by scripts/validate-org.sh or by a deploy of force-app; that a spike is deployed only by its own card, with `--source-dir spikes/<name>` and never the whole folder; that each spike's research page under docs/research/ ends with an 'Undo' list of what it left in the org; and that product code under force-app never refers to anything here
- Read scripts/validate-org.sh and scripts/agent-check.sh and say in the hand-back whether either reads the new directory (neither should; do not run either against an org from this card). Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests. No tests/__pycache__, and git status --short is empty after the commit
