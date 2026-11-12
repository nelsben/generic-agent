---
id: FE-5
title: Run the Playwright panel suite as a non-admin front-end user and add the access checks
domain: frontend
tier: standard
tier_reason: extends a working harness with a second user and a few access specs
status: queued
fixes: []
scope: [e2e/**]
forbid: [force-app/**, tests/**, scripts/**, docs/**, reference/**, agents/**, .chassis-delegation.json, jest.config.js, playwright.config.js, package.json, package-lock.json]
red_test: SF_E2E_ORG=experimental-enduser npx playwright test e2e/enduser: the folder does not exist before; after, the access specs run and report pass or a documented finding
gate: test, jest
budget: 2-attempts
spend: 10
---
## Why

Everything so far has been exercised as the org admin, and the corrective plan lists "everything as a non-admin user" as unverified. A user holding only our two permission sets is who the panel is built for: user-mode queries, the fixed error text and the Activity section's access rules only show their real behaviour there. Ben creates and signs in the user; this card points the FE-4 suite at it and adds the access checks.

## Done when

- Prerequisite done by Ben, not the worker: a Standard User in experimental holding only Account_Brief_Agent_Access and Account_Brief_Data_Access (plus whatever licence the org requires), signed into the sf CLI as alias experimental-enduser. If `sf org display -o experimental-enduser` fails, stop and hand back gate=fail saying so; never create a user, reset a password or sign in
- The FE-4 suite runs unchanged with SF_E2E_ORG=experimental-enduser, and the hand-back has the pass/fail table for that user next to FE-4's admin results
- New specs under e2e/enduser/ (run only when SF_E2E_ORG is not the admin alias, or by a tag) prove: the panel loads in the Account Brief app for this user; a brief of an account the user can read renders; the data explorer answers an org-wide question with only records the user can see (compare a count against `sf data query -o experimental-enduser`, not the admin); a failure shows the fixed line "I couldn't finish that right now. Try again in a minute." and never raw exception text
- Find out and record in e2e/README.md which Account and Task records the user can see under the org's sharing settings, read with `sf data query -o experimental-enduser`, so the specs pick accounts that exist for this user; no hard-coded Ids
- Panel or permission-set defects found are findings in the hand-back for a follow-up card, not fixed here
- Gates pass: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` and `npm run test:unit`. Leave no tests/__pycache__/ and `git status --short` empty when you report
- Hard limits as FE-4: no deploy, publish or activate, no permission-set or sharing change, no user creation, no password entry, no plugin installs, no Chrome browser tools; the session URL and ids are never printed or committed
