---
id: OPS-47
title: FR2: pattern 08 as a testing workbook — how to test an AI feature on Salesforce for people who have never written a test, the ladder in one command, Testing Center, Playwright and the Apex tests, each with a first test to copy, and every open item rechecked
domain: ops
tier: frontier
tier_reason: teaches a practice to readers new to it, so it has to be plain, encouraging and exact about what each check proves
status: merged
fixes: []
scope: [docs/patterns/08-test-and-release-lifecycle.md, tests/test_pattern_08.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_08.py fails on main (pattern 08 has no Testing Center section, no first-test walkthroughs and no autonumber) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: a Testing Center suite "that we can incorporate into the run", "playwright tests for testing front-end changes", the Apex test classes "to like prove that this thing works well", "how we communicate how to effectively test these agents", and "testing adoption, I think, is really important because we're going to be bringing some of these programmatic testing concepts to Salesforce users who haven't historically done this type of testing." Row F92 is withdrawn (speech-to-text); its open-items review stays under F80. Covers ledger rows F88 to F92 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F88 to F92, the decisions on the test bench and on writing for teams new to testing, and the review of page 08's open items), docs/plans/fr2-design.md ('Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current page 08, docs/research/fr2-testing-center.md (BE-38; read it only if it exists: BE-38 waits on its own approval), docs/research/fr2-front-end-tests.md (FE-21), e2e/README.md, scripts/ladder.sh and docs/research/fr2-ladder.md (OPS-46)
- Follow the page shape, with its exact H2 headings in its order ('The business problem', 'The architecture in a few steps', 'How it works', 'See it', 'Why you can trust it', 'How it scales', 'Adopt it', 'Limits and open items'). The title becomes "Testing an AI feature on Salesforce". **Reader:** a Salesforce admin or developer who has never written an automated test. Tests are an everyday tool that catches a broken change before a rep sees it; plain words, no testing jargon left unexplained. **The business problem:** an AI feature shipped on a demo that worked once breaks quietly after a prompt edit, a renamed field or a new agent version. **The architecture in a few steps:** the ladder, each rung in one line with what it catches, how long it takes and whether it spends model calls; the agent rungs (compile, preview, publish, activate, Testing Center) are an optional track for teams that use the agent, and publish and activate keep their steps because pattern 06's appendix links them. If scripts/agent-test.sh does not exist (BE-38 waits on its own approval), the Testing Center part explains what the suite would assert and says plainly that it is not run in this build, with no counts
- **How it works:** the ladder as a sequence diagram per fr2-design.md 'Diagrams' (autonumber, a shaded block per track, one accent colour for model calls), with the numbered steps under it using the same numbers. Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back
- **Each kind of test, with a first test to copy:** Apex tests (a stubbed model, so no test spends a model call), Jest for components (including the accessibility check), Playwright in a real Chromium browser for what a rep sees (one line: Chromium is the open-source browser behind Chrome, which Playwright drives like a person would), and Testing Center for the agent (what it asserts, what a run costs, where Salesforce advises running it). For each: what it proves, the command, and a short annotated example from this repo. **Turn a bad answer into a test:** when a rep reports a wrong answer, add the case to the right layer. **What the tests prove:** a short table by area (summary, explorer, panel, memory, access) naming the test files, written from the files at the time; no unit test counts them
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **Adopt it:** link the public docs for Testing Center, Code Analyzer, the Apex test runner and the Agentforce DX commands. **See it:** leave image links to OPS-52; show the ladder's output from docs/research/fr2-ladder.md as a text block, and the Testing Center counts from BE-38 as a table, not a screenshot, only if the suite ran. **Why you can trust it** opens with the two trust lines fr2-design.md 'Pattern page shape' fixes: one starting 'Runs as the signed-in user:' and one starting 'System context:', which names each system-context use on this path with its reason, or says 'none on this path', and holds the 'What the tests prove' table. **How it scales:** what each rung costs in time and model calls as the suite grows. **Limits and open items, rechecked:** go through the review of page 08's open items in the plan; each is closed (and by which card), accepted with the reason, or "no card yet"; never link a card file. tests/test_pattern_08.py calls the shared helper tests/pattern_shape.py (from OPS-38), passing the parts this page has and the extra parts it adds; the helper checks the headings in order, autonumber on every mermaid sequence diagram, the theme block and the two trust lines, and adds its own checks: a Testing Center section and a first-test section exist. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Three attempts; the brain raised the budget from 2 to 3.
- Attempt 1 (cedc7a7, $2.37): the verifier found the report consistent. A sonnet review returned 16 confirmed, 2 refuted and 3 unverifiable. Refuted: a Jest caption called threeRows a top-of-file helper (it is inside its own describe block), and a Limits item pointed to "step 9", which is a different diagram step. After one advisor call the brain resumed the worker with both rows, the page 06 step fix (granted as an amend), a cut of an unsourced sentence about Testing Center credits, and a "simplified from" label on the Apex example.
- Attempt 2 (c7455a7, $0.27): a sonnet review returned 8 confirmed, 1 refuted and 3 unverifiable. Refuted: the new Limits line counted "four" doc links where Adopt it has six. The miscount came from the brain's resume instruction. After a second advisor call the brain raised the budget and resumed for a one-line fix that drops the count.
- Attempt 3 (e173433, ~$0.00): a sonnet review returned 10 confirmed, 0 refuted and 2 unverifiable (check-docs, which the brain then ran: 70 pages, 0 broken; and the render check, which was not run).

Findings:
- docs/patterns/08-test-and-release-lifecycle.md is now "Testing an AI feature on Salesforce", for a reader who has never written a test. It has the eight fixed parts plus "Each kind of test, with a first test to copy" and "Turn a bad answer into a test".
- One 19-step ladder diagram: an "Every change" track and "The optional agent" track, coral for model calls; the steps under it reuse the numbers. Publish and activate keep their sf agent commands.
- Apex (simplified from CustomerSummaryTest, with AgentLlm's stub), Jest (toBeAccessible), Playwright (spec 6, @smoke) and one real case from the Testing Center spec. Testing Center is described as not run in this build, with no counts, since scripts/agent-test.sh does not exist.
- See it shows Run 1 of OPS-46's ladder and says both recorded runs were taken while the rail was deployed but not merged; no clean rerun is claimed.
- The "What the tests prove" table links only files that exist. Limits rechecks every item from the plan's review of page 08.
- docs/patterns/06-agent-routing-and-verbatim-relay.md: "step 7" is now "step 17" (one line).
- New tests/test_pattern_08.py: 18 tests, 16 of them red on main's page.

Gate (verifier at e173433): 260 Python tests, 2 skipped. Brain: check-docs 70 pages, 0 broken.

Disclosed and accepted:
- The diagram is not render-checked; the brain told the worker not to run the Mermaid CDN check until the product owner answers. The page lists it under Limits.
- The six public Salesforce doc links came from search results and were not opened (the docs site refuses automated fetches); the page says so under Limits. The brain read the raw URLs: none carries a query string.
- "Salesforce advises running Testing Center in a sandbox" rests on the plan's own uncited line.
- A tests/__pycache__ made by the gate runs was removed before each review and before merge.

Still open:
- For OPS-36: open the six doc links and the sandbox advice in a browser; GitHub light and dark render of the diagram.
- docs/assets/MANIFEST.md still lists page 08 as a user of e2e-report.png (OPS-52 or OPS-36).
- README.md and docs/ARCHITECTURE.md still give page 08's old title, "Test and release lifecycle" (OPS-36).
- A ladder rerun on main after FE-15.

Privacy grep over the diff (569 added lines): 0 denylist hits; the only @ matches are code annotations and test tags.
