---
id: FE-21
title: FR2: the front-end test run a builder can trust — the intermittent spec 2 found and fixed, both hotkey branches (Mac and Windows keys) run, and a quick smoke subset for every front-end change
domain: frontend
tier: standard
tier_reason: e2e reliability work in a real browser against a live org, where a false failure teaches people to ignore the suite
status: merged
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

## Review

Brain review (2026-11-14). One attempt (1a7772d). The verifier found the report consistent and returned next=accept, so no separate reviewer ran. The brain read the config and script changes and the diff stat (9 files, 241 added lines).

Findings:
- playwright.config.js replaces the single chromium project with two: `mac` runs every spec with the panel reading a Mac (Cmd-K), and `windows` runs only specs tagged @hotkey reading Windows (Ctrl-K). e2e/support/panel.js sets the page's platform strings in an init script through a `platform` fixture option, so either branch runs on any machine. No other config named the old project.
- New e2e/hotkey-platforms.spec.js: the platform key opens the window and the launcher names it; the other platform's key, and the Shift and Alt forms, do nothing; on the Mac branch Ctrl-K in a text field is left alone. Specs 1 and 10 also run on `windows`.
- `npm run test:e2e:smoke` runs the @smoke tag: 7 tests, one per surface, no model calls, 1.3 min. The full suite stays the release check.
- gotoAccount waits until the page is 6 s old before a test starts, and a failing test attaches the console log and uncaught errors beside the screenshot. Tracing stays off.
- e2e/README.md gains the run times, the model-call table, one line per spec and how to read the HTML report. docs/research/fr2-front-end-tests.md records the runs.
- No force-app change and no deploy.

Spec 2: 20 of 20 passed before the change and 20 of 20 after, so its failure was not reproduced. The worker found a likely cause instead: on the record page, focus drops to the body about 3 s after load (4 of 5 runs of the new text-field test), and spec 2 anchors on the Search button the same way. With the 6 s wait the text-field test went from 1 of 5 to 6 of 6. What drops the focus is not identified; the panel was closed, so no component finding was raised.

Runs (worker's account): full suite final 25 passed, 1 skipped (the Mac-only test on `windows`), 6.8 min; smoke 7 passed, 1.3 min. The first full run, before the wait, failed the new text-field test and spec 7.

Gate (verifier): 176 Python tests, 264 Jest, check-docs 61 pages.

Org writes, under the approved live-checks row: seed-account Customer_Outcome__c rows went from 21 to 31 and Customer_Summary_Session__c rows from 4 to 5. Nothing was deleted, deployed or published, and no user was created.

Disclosed and accepted:
- The run figures are the worker's account; nothing in git shows them.
- Spec 2's cause is probable, not proven.
- The 6 s wait adds about 6 s to every test that opens a record page.
- A tests/__pycache__ made by a gate run was removed before merge.

Still open:
- Spec 7 ("record heading has focus") failed once in this card's runs and in FE-22's; its cause is not named.
- What takes focus from the record page about 3 s after load is unknown; it may be Lightning itself.
- Outcome rows from test runs keep growing on the seed account (31 now); deleting them or scheduling the purge job is Ben's call.

Privacy grep over the diff (241 added lines): 0 hits, and no URL added.
