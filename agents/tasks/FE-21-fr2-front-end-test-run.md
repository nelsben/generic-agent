---
id: FE-21
title: FR2: the front-end test run a builder can trust — the intermittent spec 2 found and fixed, both hotkey branches (Mac and Windows keys) run, and a quick smoke subset for every front-end change
domain: frontend
tier: standard
tier_reason: e2e reliability work in a real browser against a live org, where a false failure teaches people to ignore the suite
status: blocked
blocked_by: [FE-16]
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
- **Spec 2:** run it 20 times in agent-probe, with screenshots and console logs on failure (tracing stays off: a trace keeps the session and the host), find the cause and fix it in the spec or its helpers (if the cause is in the component, record it as a finding and do not change force-app). Record the before and after pass rates
- **Both hotkey branches:** the hotkey specs run on the Mac branch (Meta) and the Windows branch (Control) in one run, whatever machine runs them, for example by a project per platform in playwright.config.js. The keys come from docs/research/fr2-surfaces-spike.md. On a Mac, Ctrl-K inside a text field is left alone, and a spec proves it
- **A smoke subset:** a tag and an npm script (for example npm run test:e2e:smoke) that runs one spec per surface in under two minutes, for a builder checking a front-end change; the full suite stays the release check. Update e2e/README.md: what each spec proves in one plain line, the run time, the model calls each run spends, and how to read the HTML report
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-front-end-tests.md records the spec 2 cause, the run counts and times. Org, agent-probe only, read-only apart from records the suite creates and removes; never deploy, publish or activate, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/check-docs.sh (0 broken); run the full e2e suite once and the smoke subset once, all passing. Paste the Playwright summary line in the hand-back, one line for each run. No record Ids, usernames or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
