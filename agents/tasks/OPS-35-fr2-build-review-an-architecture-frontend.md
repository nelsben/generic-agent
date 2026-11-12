---
id: OPS-35
title: FR2: build review — an architecture, frontend and security review of everything FR2 shipped, with Playwright checks on every surface, each ledger row traced to evidence, and fixes listed as new cards
domain: ops
tier: frontier
tier_reason: independent cross-cutting review of the whole revision in a live org
status: blocked
blocked_by: [FE-13, FE-14, FE-15, BE-28, OPS-31]
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

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/ARCHITECTURE.md, docs/patterns/*.md, and every docs/research/fr2-*.md. Load the skills experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate, salesforce-development:platform-apex-generate (review mode) and agentforce-adlc:agentforce-test first
- Trace: for each ledger row F01 to F43, a line saying where it shipped (file, test, screenshot or doc) or why not (tabled, open, parked), and whether the shipped thing matches Ben's words. A row with no evidence is a finding
- Frontend validation in agent-probe with Playwright at 1440x900 and 1280x720: compact window and rail open by hotkey and by click, expand keeps the thread, voice button present and labelled (and hidden when the API is stubbed out), quick actions, a draft card and Cancel (no record written), history reopen, brand variables applied (switch a colour at run time in the test and see it change), jest-axe and an axe scan of each surface open on a record page, reduced motion honoured, and the speed budgets re-measured. Screenshots under docs/assets/fr2-review-*.png; read each one
- Architecture and security: every query and DML in the FR2 Apex runs in user mode; no aiplatform reference at compile time outside the seam; no lwc:inner-html; no hard-coded brand value in components; draft never writes; commit never shares a transaction with a callout; one service behind each skill for panel, agent and MCP; history visibility as F32 says; the privacy grep of the whole tree (Ids, emails, hostnames, query-string URLs, home paths, consumer keys) is clean. Run the full e2e suite and bash scripts/agent-check.sh and record the counts
- Write docs/reviews/fr2-build-review.md: verdict, the trace table, findings ranked by severity with file and line, the measured numbers, and for each finding a proposed card title. Do not fix code in this card. Org, agent-probe only, read-only apart from the test records the e2e suite creates and removes; never deploy, publish, create a user or touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
