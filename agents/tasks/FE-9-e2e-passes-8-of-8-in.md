---
id: FE-9
title: e2e passes 8 of 8 in agent-probe: opening the account page closes the Guidance Center first-run walkthrough when one is shown
domain: frontend
tier: standard
tier_reason: one small helper change, found by reading live markup in one org
status: blocked
blocked_by: [OPS-25]
fixes: []
scope: [e2e/support/panel.js, e2e/README.md, docs/research/org-migration.md]
forbid: [force-app/**, tests/**, scripts/**, data/**, e2e/panel.spec.js, e2e/global-setup.js, e2e/capture/**, docs/assets/**, README.md, docs/patterns/**, agents/**, docs/plans/**, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: npx playwright test -g "^2\." against agent-probe fails at spec 2 (Search button not found under the Guidance Center walkthrough)
gate: test, jest
budget: 2-attempts
spend: 10
---
## Why

OPS-25's e2e run in agent-probe passed 7 of 8. Spec 2 failed because the fresh org's "Meet the new Guidance Center" walkthrough covered the page, so the Search button it returns focus to was not found. FE-8 recaptures every image through the same Panel.gotoAccount, so the walkthrough would also end up in the screenshots. FE-8 needs a green e2e run recorded before it starts.

## Done when

- Read first: e2e/support/panel.js, e2e/panel.spec.js (spec 2), e2e/capture/kit.js (it calls Panel.gotoAccount), e2e/README.md, and the e2e section of docs/research/org-migration.md
- Red, recorded before any change: in agent-probe, `npx playwright test -g "^2\\."` (SF_TARGET_ORG=agent-probe) fails. Record its error line, and what the failure screenshot shows, in words only. If spec 2 passes before the change, record that, skip the code change and go to the full run
- Panel.gotoAccount closes the walkthrough after the record page has loaded and before the panel-ready checks. It closes it only when one is shown, using the walkthrough's own close or dismiss control. It finds that control by role and accessible name, as seen in agent-probe, and a short comment above the step names the walkthrough. When no walkthrough is shown, the step adds at most about 5 s and does nothing
- The only org-side effect is the e2e user closing the walkthrough. No setting changes, no deploy, publish or activation, no sign-in or logout, nothing run against experimental. No tokens or frontdoor URLs are printed. No org Ids, record Ids, usernames or instance hostnames go in any file
- Green: one full `npm run test:e2e` run in agent-probe passes 8 of 8. Allow at most two full runs, plus the red run, and about 15 model calls in total
- docs/research/org-migration.md gets a short section at its end, "e2e after FE-9", with the red result, the change and the green 8 of 8 run. It edits nothing above that section
- e2e/README.md says, in a line, that a fresh org's Guidance Center walkthrough is closed on page load and why
- The test and jest gates pass
