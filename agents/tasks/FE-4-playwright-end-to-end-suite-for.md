---
id: FE-4
title: Playwright end-to-end suite for the Account Brief panel, run in the experimental org as a signed-in user
domain: frontend
tier: frontier
tier_reason: Lightning shadow DOM, utility bar timing and session-secret handling in a live org; brittle if done naively
status: merged
fixes: []
scope: [e2e/**, playwright.config.js, package.json, package-lock.json, .gitignore]
forbid: [force-app/**, tests/**, scripts/**, docs/**, reference/**, agents/**, .chassis-delegation.json, jest.config.js]
red_test: npm run test:e2e: the script does not exist on main; after, the suite runs and every spec reports pass or a documented panel finding
gate: test, jest
budget: 2-attempts
spend: 25
---
## Why

The panel's Jest tests stub every Lightning base component and the utility bar API, so FE-3 left a list of checks only a real browser can make: the hotkey before the panel has ever been opened, Esc returning focus, the 340x480 layout, screen-reader announcements, latest-wins and the base components' real events. Ben wants these tested the way a front-end user meets them. This card builds the Playwright harness and the panel journeys against the deployed panel in `experimental`.

## Done when

- Read first: docs/reviews/lwc-review.md, agents/tasks/FE-3-accountbriefpanel-fix-the-lwc-review-findings.md (its Review section lists the live checks), the panel bundle force-app/main/default/lwc/accountBriefPanel/, and the experience-lwc skills experience-lwc-runtime-observe and experience-accessibility-validate (SKILL.md under ~/.claude/plugins/cache/salesforce/experience-lwc/<version>/skills/)
- @playwright/test is a pinned devDependency (exact version, no caret), Chromium only. `npm run test:e2e` runs the suite from e2e/ with playwright.config.js at the repo root, workers 1, fullyParallel false, and timeouts long enough for a brief (the model call takes 15-30 s). `npm run test:unit` (Jest) still finds only the LWC __tests__ and still passes
- Sign-in uses the sf CLI session the developer already has, never a password: a global setup asks `/usr/local/bin/sf org open --url-only --json -o ${SF_E2E_ORG:-experimental}` (verify the flags with --help) for a one-time frontdoor URL, opens it outside any traced context, and saves storageState to e2e/.auth/ . The URL and any session id are never printed, logged, written to a report, trace, screenshot name or committed file. e2e/.auth/, test-results/ and playwright-report/ are in .gitignore. If the CLI session is missing or expired the setup fails with one line telling the developer to run `sf org login web -a <alias>`; it never tries to sign in itself
- Each test starts from the Account Brief app (find its URL from force-app/main/default/applications/Account_Brief.app-meta.xml) on the record page of the account Edge Communications, looked up by name at run time (no hard-coded Ids), with the browser viewport at desktop size and the utility panel at its configured 340x480
- Specs cover, one test each: (1) Cmd/Ctrl-K on a freshly loaded page, before the utility was ever opened, opens the panel and focuses the composer; (2) Esc from the composer and from a button minimizes the utility and returns focus to the page element focused before Cmd/Ctrl-K, and Tab can leave the panel; (3) a brief of the current account renders with headline and collapsed accordions, and the live region (role=status) reads 'Loading brief for ...' then 'Brief ready: ...'; (4) after two or three answers the composer stays pinned in the 340x480 panel, the body scrolls and the newest answer is in view; (5) a second question sent before the first answers: only the second answer renders and the spinner stops when it lands; (6) typing in the composer enables Send without blur, and Enter sends; (7) a drill into a section opens the record view, and a breadcrumb click returns without navigating to '#'; (8) an @sa11y or axe accessibility check of the open panel in each state of (3) and (7) has no violations, or each violation is listed in the hand-back
- Locators reach into Lightning shadow DOM with Playwright's built-in piercing (getByRole, getByLabel, data attributes the panel already has); no XPath, no fixed sleeps, no coordinates. If a check needs a test hook the panel lacks, do not add one: list it in the hand-back
- The suite makes at most about eight model calls per full run (briefs and questions), says so in e2e/README.md together with how to run it, the SF_E2E_ORG alias variable, and what it needs (a deployed panel, a signed-in sf CLI session)
- Run the suite once against experimental. Hand back a table of every spec: pass or fail, and for each failure the observed behaviour, a screenshot path under test-results/, and whether it is a panel defect or a test problem. Panel defects are findings for a follow-up card, not fixed here: force-app/** is forbidden
- Gates pass: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` and `npm run test:unit`. Leave no tests/__pycache__/ and `git status --short` empty when you report
- Hard limits: no deploy of any kind, no publish or activate, no change to org data or setup other than what the panel itself writes when used (brief memory rows), no password entry, no user or account creation, no plugin installs, no Chrome browser tools (Playwright's own Chromium only)

## Review

Sonnet review, attempt 2 at 148c65b: 17 confirmed, 0 refuted, 7 unverifiable. Suite result against experimental: 6 of 8 specs pass. The two failures are panel defects for a follow-up card: Esc does not keep focus on the element focused before the hotkey (the platform's minimize moves it after the panel restores it), and no brief section line can be drilled because the section Apex writes no record Id into lines. Missing test hooks are listed in e2e/README.md.
