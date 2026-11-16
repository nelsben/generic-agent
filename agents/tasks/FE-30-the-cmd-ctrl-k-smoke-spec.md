---
id: FE-30
title: The Cmd/Ctrl-K smoke spec (e2e/panel.spec.js test 1) passes 10 of 10 smoke runs in agent-probe, with its intermittent failure reproduced and its cause named first
domain: frontend
tier: standard
status: queued
scope: [e2e/panel.spec.js, e2e/support/**, e2e/global-setup.js, force-app/main/default/lwc/customerSummaryPanel/**, docs/research/fresh-org-run.md, docs/research/fr2-hotkey-spec-flake.md]
forbid: [force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, data/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, reference/**, .chassis-delegation.json, sfdx-project.json, spikes/**, e2e/.auth/**]
resources: [org-live]
red_test: npm run test:e2e:smoke run 10 times in a row against agent-probe fails at least once on e2e/panel.spec.js test 1 before the fix, or the page records the 20-run attempt that could not reproduce it; after the fix 10 of 10 runs pass
gate: test, jest
budget: 2-attempts
spend: 10
---
## Why

The e2e smoke rung failed 1 of 11 in the clean-install ladder on the Cmd/Ctrl-K spec (FE-29, docs/research/fresh-org-run.md), and the same spec has been flaky in agent-probe. Its cause is not confirmed, and the README's "A clean install" row cannot flip while it is intermittent. Coworker is tabled and work is back on the generic agent's own panel (Ben, 2026-11-15, "Go and follow your recommendations as a default").

## Done when

- Read first: e2e/README.md, e2e/panel.spec.js (test 1 and its fixtures in e2e/support/), e2e/global-setup.js, the customerSummaryPanel LWC's hotkey listener and docs/research/fresh-org-run.md ('e2e smoke after the landing fix (FE-29, 2026-11-15)'). Load the skill experience-lwc:experience-lwc-generate before changing the LWC and salesforce-development:platform-metadata-deploy before any deploy
- Reproduce first: run the smoke suite (npm run test:e2e:smoke) up to 20 times in a row against agent-probe and record pass and fail counts per run. For each failure of test 1, read the Playwright trace and say what the page showed when the key was pressed (which page, whether the panel host and launcher were present, where focus was). Do not add a retry, a longer blanket timeout or a second key press to test 1: its comment says a retry would hide the defect it exists to catch
- Name the cause as one of: the test presses the key before the panel is ready (a test precondition), the panel's listener is attached late or lost (a product defect), or the page under test is not the expected one. Give the trace evidence. If 20 runs do not reproduce it, say so, change nothing in the LWC, and make only the precondition explicit (the test waits for a state the panel exposes when its listener is attached)
- Fix the named cause in the smallest place. A test-only fix waits on a real readiness signal, not on time. A product fix (customerSummaryPanel) keeps every existing Jest test passing, adds one Jest test for the changed behaviour, and is deployed to agent-probe by validate then quick deploy (the standing approval; CONFIRM_PROD=1 on the quick deploy, RunSpecifiedTests is not enough for a validate: use the README's test level)
- After the fix the smoke suite passes 10 of 10 consecutive runs in agent-probe, both hotkey projects (mac and windows) included; the counts are in the page
- Also fix the sign-in hint in e2e/global-setup.js so a timeout is reported as a timeout and not as a missing sf session (FE-29's disclosed item); the hint never prints a URL, host or username
- docs/research/fr2-hotkey-spec-flake.md records: the reproduction counts, the cause with its evidence, the fix, and the 10-run result. docs/research/fresh-org-run.md gains one line pointing at it. The README's clean-install row is not touched (README.md is forbidden); say in the hand-back that a ladder rerun in a fresh org is still needed to flip it
- Org rules: agent-probe only, with -o agent-probe on every sf command; first compare sf org display result.id for agent-probe and experimental and stop on SAME (print SAME or DIFFERENT only). Never touch experimental. Never create a user, sign in or out, enter credentials or accept consent. The e2e signs in through the existing sf session only. No test that creates or deletes a record. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file, image or the hand-back; e2e/.auth and test-results are never committed or printed
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/check-docs.sh (0 broken). Say in the hand-back how many model calls the runs spent. No tests/__pycache__, and git status --short is empty after the commit
