---
id: OPS-20
title: Deploy main to experimental and prove it: Apex tests green and the Playwright panel suite at 8 of 8
domain: ops
tier: standard
tier_reason: a scripted deploy and a test run with clear stop conditions
status: blocked
blocked_by: [FE-6]
fixes: []
scope: [docs/research/deploy-verify.md]
forbid: [force-app/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

BE-12, BE-13, FE-6 and BE-14 were only check-only validated, so the org is behind main and nothing captured there is evidence of main. This card makes the org match main and runs the live suite, so the capture and publish cards work on the real thing. It needs Ben's approval for a real deploy, recorded in docs/plans/gtm-burn-plan.md.

## Done when

- Before anything else read docs/plans/gtm-burn-plan.md, section 'Approvals'. If the line for real deploys to experimental does not say approved, stop and hand back saying so
- Load the skill salesforce-development:platform-metadata-deploy (or read its SKILL.md) and follow it. Confirm the target org alias is experimental and that it is a Developer Edition org, not production; stop if not
- Dry-run first, then a real deploy of force-app to experimental with RunSpecifiedTests naming the repo's Apex test classes (take the list from scripts/validate-org.sh). Exclude aiAuthoringBundles, exactly as scripts/validate-org.sh does: this card never deploys, publishes or activates the agent. Record the deploy job result (components, tests run, failures) in the results file
- Assign nothing and delete nothing. If the deploy fails, record the exact component errors, do not retry more than once after a real fix inside scope is impossible (you may not change source), and hand back
- Run `npm ci` then `npm run test:e2e` against experimental once. Record per-spec pass or fail. The target is 8 of 8. If a spec fails, re-run that spec once to rule out timing, then record what you saw with the failure screenshot path; do not edit specs or source
- Write docs/research/deploy-verify.md: date, the commit sha deployed, deploy result, Apex test counts, the e2e table, and a one-line verdict. No record Ids, org Ids, usernames, tokens or URLs with query strings
- Gate passes: python3 -m unittest discover -s tests with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/, no e2e/.auth/ or test-results/ in git; git status --short is empty after your commit. Never install a plugin even if a hook suggests one; never sign in; never print tokens or frontdoor URLs
