---
id: FE-21
title: FR2: the front-end test run a builder can trust — the intermittent spec 2 found and fixed, both hotkey branches (Mac and Windows keys) run, and a quick smoke subset for every front-end change
domain: frontend
tier: standard
tier_reason: e2e reliability work in a real browser against a live org, where a false failure teaches people to ignore the suite
status: blocked
blocked_by: [FE-12, FE-13, FE-20]
fixes: []
scope: [e2e/**, playwright.config.js, package.json, docs/research/fr2-front-end-tests.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: an e2e spec that runs the hotkey on the Windows branch (Ctrl) fails on main (the suite only runs the branch of the machine it is on) and passes after
gate: test, jest
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: "playwright tests for testing front-end changes", and "testing adoption, I think, is really important". A suite that fails now and then for no reason teaches people to ignore it. Covers ledger row F89 in docs/plans/feature-revision-2.md, and two open items on page 08: spec 2 fails now and then (docs/research/org-migration.md), and the suite runs only one of the two hotkey branches (N11 in docs/reviews/lwc-review-2.md).

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F88 to F92 and the review of page 08's open items), e2e/README.md, docs/research/org-migration.md (spec 2's runs), docs/reviews/lwc-review-2.md (N11) and docs/patterns/08-test-and-release-lifecycle.md. Load the skills experience-lwc:experience-lwc-generate and experience-lwc:experience-accessibility-validate first
- **Spec 2:** run it 20 times in agent-probe, with Playwright traces on failure, find the cause and fix it in the spec or its helpers (if the cause is in the component, record it as a finding and do not change force-app). Record the before and after pass rates
- **Both hotkey branches:** the hotkey specs run on the Mac branch (Meta) and the Windows branch (Control) in one run, whatever machine runs them, for example by a project per platform in playwright.config.js
- **A smoke subset:** a tag and an npm script (for example npm run test:e2e:smoke) that runs one spec per surface in under two minutes, for a builder checking a front-end change; the full suite stays the release check. Update e2e/README.md: what each spec proves in one plain line, the run time, the model calls each run spends, and how to read the HTML report
- docs/research/fr2-front-end-tests.md records the spec 2 cause, the run counts and times. Org, agent-probe only, read-only apart from records the suite creates and removes; never deploy, publish or activate, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and npm run test:unit; run the full e2e suite once and the smoke subset once, all passing. No record Ids, usernames or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
