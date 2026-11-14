---
id: OPS-35
title: FR2: build review — an architecture, frontend and security review of everything FR2 shipped, with Playwright checks on every surface, each ledger row traced to evidence, and fixes listed as new cards
domain: ops
tier: frontier
tier_reason: independent cross-cutting review of the whole revision in a live org
status: merged
fixes: []
scope: [docs/reviews/fr2-build-review.md, docs/assets/fr2-review-*.png, e2e/review/**]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (review): the evidence is docs/reviews/fr2-build-review.md and its screenshots
gate: test
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2): the original goal still stands, "testing, playwright screenshots with frontend validation, architecture reviews", and Ben wants it "streamlined ... fast and feeling fluid". Before the README is rewritten, an independent review checks the built product against the plan and the design. Covers ledger rows F31 and F43 in docs/plans/feature-revision-2.md, and checks every other row.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", do the static review only (code, tests and docs), run nothing in the org and say so in the hand-back. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/ARCHITECTURE.md, docs/patterns/*.md, and every docs/research/fr2-*.md. Load the skills experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-apex-generate (review mode) first
- Trace: for each ledger row F01 to F93, a line saying where it shipped (file, test, screenshot or doc) or why not (tabled, open, parked), and whether the shipped thing matches Ben's words. A row with no evidence is a finding. A row whose card has not merged yet reads 'not landed' with the card id: that is a line in the table, not a finding
- Frontend validation in agent-probe with Playwright at 1440x900 and 1280x720: compact window and rail open by hotkey and by click, expand keeps the thread, voice button present and labelled (and hidden when the API is stubbed out), quick actions, the rail's context sections, the outcomes timeline and the sentiment chart, a draft card (through Confirm only if the row "FR2: e2e and agent tests that create a record" in the Approvals table of docs/plans/gtm-burn-plan.md starts with "approved", removing the task and its outcome afterwards; otherwise to Cancel, with no record written), history reopen, brand variables applied (override a --cs-* variable in the page from the test and see it change; no org record is changed), jest-axe and an axe scan of each surface open on a record page, reduced motion honoured, and the speed budgets re-measured. Screenshots under docs/assets/fr2-review-*.png; read each one. Every still and GIF is taken through e2e/capture/kit.js. Review scripts under e2e/review/ are not named `*.spec.js`, so the e2e suite never picks them up
- Architecture and security: every query and DML in the FR2 Apex runs in user mode, apart from the system-context uses BE-37's test names; no aiplatform reference at compile time outside the seam; no lwc:inner-html; no hard-coded brand value in components; draft never writes; commit never shares a transaction with a callout; one service behind each skill for the compact window, the rail and MCP (one line if the MCP door is not renamed yet: OPS-31 waits on its own approval); history visibility as F32 says; the privacy grep of the whole tree (Ids, emails, hostnames, query-string URLs, home paths, consumer keys) is clean. Run the full e2e suite and bash scripts/agent-check.sh and record the counts. Write the counts with their date into the review page: OPS-36's proof table takes them from there. The security part is a code review: run no agent test (no `sf agent test`, no Testing Center run) and no security, injection or red-team probe of any kind against the org
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Write docs/reviews/fr2-build-review.md: verdict, the trace table, findings ranked by severity with file and line, the measured numbers, for each finding a proposed card title, and one 'Left in agent-probe' table built from the 'Undo' list of every docs/research/fr2-*.md page. Do not fix code in this card. Org, agent-probe only, read-only apart from the product's own session and outcome rows and the test records the e2e suite creates and removes (a read-only step needs no Approvals row); never deploy, publish, create a user or touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Three attempts.
- Attempt 1: $6.99. Its sonnet review returned 31 confirmed, 3 refuted and 11 unverifiable. The brain called the advisor once before resuming.
- Attempt 2 (1a6e7fa): $1.51. Its sonnet review returned 17 confirmed, 1 refuted and 4 unverifiable, and the budget was spent. The refuted row was a line-range citation on line 169.
- The budget was raised to three, and the worker was resumed with a bounded fix. The advisor was skipped because the fix was a line-number correction.
- Attempt 3 (c051ad8): about $0.06. It corrected line 169 to cite :77-96 (axeScan) and :360-373 (spec 8). Its sonnet review returned 8 confirmed, 0 refuted and 2 unverifiable.

Findings:
- New docs/reviews/fr2-build-review.md is the FR2 build review. Its verdict is "Ready with fixes".
- Medium findings:
  - M1: a rep's conversation text (Turns_JSON__c) can be read by the role hierarchy through reports and the API.
  - M2: the no-speech note squeezes the composer.
  - M3: the undo token is unsigned.
  - M4: the drill specs are flaky.
  - M5: the suite's axe scan runs at 1440x900 only, and target size at 1280x720 is unchecked.
- Low findings L1 to L12, including 15 of 26 undo-able actions by the `^#.*undo` rule (L12).
- Nine stills, docs/assets/fr2-review-*.png. A new review-only Playwright config and spec, e2e/review/fr2-review.review.js, with 9 of 9 review checks passing.
- Measured on agent-probe: the e2e first run was 38 passed, 3 failed and 1 skipped of 42. Jest 381. Edge outcomes rose from 66 to 78 during the run. The org holds 16 sessions and 90 outcomes.

Gate (verifier at c051ad8): Python 310 tests, 3 skipped (the branch is based on ea2d7ab). Worker: check-docs 72 pages, 0 broken.

Disclosed and accepted:
- The brain opened all nine stills. They show seed data only ("Sample Owner", "email hidden", 555 numbers, example.com, "Developer Edition"), with no address bar, Id, username, email or hostname.
- The review read main at ea2d7ab. That base predates OPS-43 (page 05) and OPS-48 (pages 09 to 14 and the index), so the title notes and L3 may be stale. The page's Limits says so. No card is cut from L3.
- No Mermaid render check was run (OPS-61 holds it, and it is parked).
- The org checks stopped at Cancel and created no records apart from the outcome rows that summaries write.
- A tests/__pycache__ made by the gate runs was removed before each review and before merge.

Still open:
- NEW-8 for Ben: M1 (who can read conversation text) and M3 (sign the undo token).
- M2, M4, M5 and the L-items fold into OPS-36 or new cards, as Ben picks.
- The Edge Communications outcome rows (now 78) remain for Ben's call on deleting them or scheduling the purge job.

Privacy check over the full branch diff at c051ad8 (755 added lines, PNGs excluded): 0 denylist hits. The only matches are the org alias, which main already carries, and the Playwright package name. No URLs, Ids, local paths or job Ids.
