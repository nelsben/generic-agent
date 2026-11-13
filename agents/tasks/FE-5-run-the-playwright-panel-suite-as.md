---
id: FE-5
title: Run the Playwright panel suite as a non-admin front-end user and add the access checks
domain: frontend
tier: standard
tier_reason: extends a working harness with a second user and a few access specs
status: parked
blocked_by: [OPS-30, FE-14, FE-15, FE-19, BE-33]
fixes: []
scope: [e2e/**]
forbid: [force-app/**, tests/**, scripts/**, docs/**, reference/**, agents/**, .chassis-delegation.json, jest.config.js, playwright.config.js, package.json, package-lock.json]
resources: [org-live]
red_test: SF_E2E_ORG=agent-probe-enduser npx playwright test e2e/enduser: the folder does not exist before; after, the access specs run and report pass or a documented finding
gate: test, jest
budget: 2-attempts
spend: 10
---
## Why

Everything so far has been exercised as the org admin, and the corrective plan lists "everything as a non-admin user" as unverified. A user holding only our two permission sets is who the panel is built for: user-mode queries, the fixed error text and the Activity section's access rules only show their real behaviour there. Ben creates and signs in the user; this card points the FE-4 suite at it and adds the access checks.

## Done when

- Prerequisite done by Ben, not the worker: a Standard User in agent-probe holding only the Customer_Summary_User permission set group, the name BE-23 gave it (plus whatever licence the org requires), signed into the sf CLI as alias agent-probe-enduser; never experimental. Check the alias with `sf alias list`. Never print `sf org display` output: it carries the access token, the username and the host. If the alias is missing, or the first `sf data query -o agent-probe-enduser` fails, stop and hand back gate=fail saying so; never create a user, reset a password or sign in
- The full e2e suite as FE-21 left it runs unchanged with SF_E2E_ORG=agent-probe-enduser, and the hand-back has the pass/fail table for that user next to the admin results. Paste the Playwright summary line in the hand-back, one line for each run
- New specs under e2e/enduser/ (run only when SF_E2E_ORG is not the admin alias, or by a tag) prove: the compact window opens in the Customer Summary app for this user, and so does the rail; a summary of an account the user can read renders; the data explorer answers an org-wide question with only records the user can see (compare a count against `sf data query -o agent-probe-enduser`, not the admin); a write request shows a draft card, and Cancel leaves nothing written (never press Confirm in this card); an outcome another user wrote shows its type, date and sentiment label and no text (use one that the admin's earlier runs left on a sample account; if there is none, say so and skip, never insert one); the built-in Agentforce panel, if it shows at all, does not offer our agent; a failure shows the fixed line "I couldn't finish that right now. Try again in a minute." and never raw exception text; and a summary and an explorer answer both come back with model text, which proves the group alone lets a rep read the prompt files and make the model call (N11 and the open item on page 07, ledger F86). If any of these fails, the hand-back names the missing permission or the defect as a finding
- Find out and record in e2e/README.md which Account and Task records the user can see under the org's sharing settings, read with `sf data query -o agent-probe-enduser`, so the specs pick accounts that exist for this user; no hard-coded Ids
- Panel or permission-set defects found are findings in the hand-back for a follow-up card, not fixed here
- Gates pass: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` and `npm run test:unit`. Leave no tests/__pycache__/ and `git status --short` empty when you report
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Hard limits as FE-4: no deploy, publish or activate, no permission-set or sharing change, no user creation, no password entry, no plugin installs, no Chrome browser tools; the session URL and ids are never printed or committed. This card spends model calls and writes the product's own session and outcome rows as that user: run it only if the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md starts with "approved"; otherwise hand back
