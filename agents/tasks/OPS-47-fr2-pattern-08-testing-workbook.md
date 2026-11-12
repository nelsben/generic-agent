---
id: OPS-47
title: FR2: pattern 08 as a testing workbook — how to test an AI feature on Salesforce for people who have never written a test, the ladder in one command, Testing Center, Playwright and the Apex tests, each with a first test to copy, and every open item rechecked
domain: ops
tier: frontier
tier_reason: teaches a practice to readers new to it, so it has to be plain, encouraging and exact about what each check proves
status: blocked
blocked_by: [OPS-38, OPS-46, BE-38, FE-21, FE-20, OPS-44]
fixes: []
scope: [docs/patterns/08-test-and-release-lifecycle.md, tests/test_pattern_08.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_08.py fails on main (pattern 08 has no Testing Center section, no first-test walkthroughs and no autonumber) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: a Testing Center suite "that we can incorporate into the run", "playwright tests for testing front-end changes", the Apex test classes "to like prove that this thing works well", "how we communicate how to effectively test these agents", and "testing adoption, I think, is really important because we're going to be bringing some of these programmatic testing concepts to Salesforce users who haven't historically done this type of testing. Meaningful and valuable. ... not like a ... review board where you have to go and present everything and you're going to get graded." Covers ledger rows F88 to F92 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F88 to F92, the decisions on the test bench and on tone, and the review of page 08's open items), docs/plans/fr2-design.md ('Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current page 08, docs/research/fr2-testing-center.md (BE-38), docs/research/fr2-front-end-tests.md (FE-21), e2e/README.md and scripts/ladder.sh (OPS-46)
- Follow the page shape; the title becomes "Testing an AI feature on Salesforce". **Tone:** tests are a builder's everyday tool that catches a broken change before a rep sees it. No grades, scores out of a letter, sign-off boards or review language. **The business problem:** an AI feature shipped on a demo that worked once breaks quietly after a prompt edit, a renamed field or a new agent version. **The architecture in steps:** the ladder, each rung in one line with what it catches, how long it takes and whether it spends model calls; the agent rungs (compile, preview, publish, activate, Testing Center) are an optional track for teams that use the agent, and publish and activate keep their steps because pattern 06's appendix links them
- **How it works:** the ladder as a sequence diagram per fr2-design.md 'Diagrams' (autonumber, a shaded block per track, one accent colour for model calls), with the numbered steps under it using the same numbers. Every diagram renders on GitHub; check each with gh api markdown (read-only) and say so in the hand-back
- **Each kind of test, with a first test to copy:** Apex tests (a stubbed model, so no test spends a model call), Jest for components (including the accessibility check), Playwright in a real Chromium browser for what a rep sees (one line: Chromium is the open-source browser behind Chrome, which Playwright drives like a person would), and Testing Center for the agent (what it asserts, what a run costs, where Salesforce advises running it). For each: what it proves, the command, and a short annotated example from this repo. **Turn a bad answer into a test:** when a rep reports a wrong answer, add the case to the right layer. **What the tests prove:** a short table by area (summary, explorer, panel, memory, access) naming the test files, written from the files at the time; no unit test counts them
- **Salesforce's own tools:** link the public docs for Testing Center, Code Analyzer, the Apex test runner and the Agentforce DX commands, as what this page builds on. **See it:** leave image links to OPS-36; name the Testing Center counts from BE-38 as a table, not a screenshot. **Limits and open items, rechecked:** go through the review of page 08's open items in the plan; each is closed (and by which card), accepted with the reason, or "no card yet". tests/test_pattern_08.py checks the parts in order, that every mermaid sequence diagram starts with autonumber, that a Testing Center section and a first-test section exist, and that the page has none of the grading words graded, grade, scorecard or sign-off (matched as whole words, so "upgrade" passes). Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
