---
id: OPS-44
title: FR2: pattern 06 becomes a short appendix — the registered Agentforce agent as an optional add-on for teams that want it in an Agentforce channel, not a way in we promote; the README's quick start no longer needs an agent publish
domain: ops
tier: frontier
tier_reason: repositions a chapter and simplifies the quick start every new reader runs, without overstating what was proven
status: merged
fixes: []
scope: [docs/patterns/06-agent-routing-and-verbatim-relay.md, tests/test_pattern_06.py, docs/research/fr2-quick-start-change.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_06.py fails on main (pattern 06 is a full chapter that promotes the built-in panel and "Ask the agent") and passes after
gate: test
budget: 2-attempts
spend: 5
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 06: "I don't think we want to promote using the default agent force pop-out panel ... I don't think there's anything important about using it. If you decide to use number 6, that means you're not using any of the other avenues", "I'd propose that we drop this", and "this is agent force, it's just a different skinned version of it". The agent itself stays, renamed by BE-23 and published once by OPS-51, for teams that want it in an Agentforce channel; nothing in the product should depend on it, and OPS-28 proves that. Covers ledger rows F82 to F84 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F82 to F84 and the decision on ways in), docs/plans/fr2-design.md ('The product', 'Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current pattern 06 page as FE-20 left it, docs/research/fr2-retire-ask-agent.md (FE-20), docs/research/fr2-rename-org.md (OPS-30), docs/research/fr2-agent-publish.md (OPS-51) and docs/research/fr2-agent-memory.md (BE-34)
- The file name is final. Page 06 is a short appendix: fr2-design.md exempts it from the full page shape. The title becomes "Appendix: the Agentforce agent (optional)". **One line:** the product is Agentforce with its own surfaces; the registered agent is there for a team that wants the same skills in an Agentforce channel. **When you would add it:** a channel that only a registered agent can reach, Agent Memory (from BE-34's findings), or the platform's agent testing and session traces (the Testing Center suite, BE-38, uses the agent as its test bench; BE-38 waits on its own approval, so say the suite is part of this build only if docs/research/fr2-testing-center.md exists). Say plainly that none of our surfaces or MCP use it. For "the product runs without it", link the README's Status table (the 'Status' heading in README.md) instead of saying on the page whether it is proven
- **How it works,** short: the router, resolve then summarize, the explorer step, verbatim relay. One diagram per fr2-design.md 'Diagrams' (autonumber, phase blocks, one accent colour for model calls) with the numbered steps under it using the same numbers. No built-in panel screenshots; no "Ask the agent"
- **Adopt it,** as optional steps: publish and activate (link pattern 08), assign the agent's own permission set, and the checks. Write the quick-start change OPS-36 should make to docs/research/fr2-quick-start-change.md: the agent publish moves out of the README's required steps into this appendix, so name the steps to delete, the steps this appendix now holds and the one line that replaces them. Do not edit README.md
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **Limits and open items, rechecked:** every item on today's page is closed (and by which card), dropped with the button or the built-in panel (say so), accepted with the reason, or "no card yet"; never link a card file. tests/test_pattern_06.py calls the shared helper tests/pattern_shape.py (from OPS-38), passing the parts this appendix has, and adds its own checks: the appendix title, and that the page does not contain "Ask the agent" or a link to the built-in panel screenshots. Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Two attempts.
- Attempt 1 (315fac4): the verifier found the report consistent. A sonnet review returned 16 confirmed, 1 refuted and 3 unverifiable. The refuted row: Adopt-it step 4 said `CopilotSalesforceUser` is needed "for Lightning". Agent-review-2 says only that the panel also needs it, and page 07 says the name is unconfirmed. The brain granted an amend (scope+=docs/patterns/_diagram-theme.md), limited to the first paragraph of its Render check section, and resumed the worker.
- Attempt 2 (fc7b0d0): two docs files changed, 8 insertions and 4 deletions. A sonnet review returned 12 confirmed, 0 refuted, 2 unverifiable. The unverifiable rows are the Mermaid output itself and the check-docs count.

Findings:
- Page 06 is now a short appendix, "Appendix: the Agentforce agent (optional)", with How it works, When you would add it, Adopt it, and Limits and open items. Our own surfaces are the only ways in; the registered agent is an optional add-on (ledger rows F82 to F84).
- Adopt-it step 4 now says only that the panel also needs `CopilotSalesforceUser` (agent-review-2, N5). It keeps page 07's warning that the name has not been confirmed in an org and links page 07.
- New docs/research/fr2-quick-start-change.md tells OPS-36 what moves out of the README quick start, what to delete and change, the one line that replaces them, and what is left for OPS-36 to decide. README.md is not edited here.
- New tests/test_pattern_06.py checks the appendix shape and its diagram.
- _diagram-theme.md: only the first paragraph of Render check changed. It records a local run of Mermaid 11.4.1 in Playwright's Chromium: FAIL on the broken sample's second block, ok on its first, and ok on every diagram on pages 01 and 06. It says this is not a GitHub render and that GitHub light and dark are unchecked. The init snippet is byte-identical; the diff has no `init:` line.

Gate (verifier at fc7b0d0): 198 Python tests, 1 skipped. Worker: check-docs 66 pages, 0 broken.

Disclosed and accepted:
- The render check loads Mermaid from a CDN in Chromium. The session's permission policy refused it twice for OPS-38's worker. OPS-44's worker ran it in attempt 1. Whether this is allowed is put to Ben; the brain will not direct a worker to run it until he answers.
- The guide-word test skips when PATTERN_GUIDE_WORDS is unset (the 1 skip). The brain's denylist grep over the diff found no hits, and the words "landscape", "confidential" and "proprietary" do not appear in it.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- The "For the next card that tries" paragraph on _diagram-theme.md still asks for the run that has now been done. It was left alone because the amend was limited to the first paragraph.
- A GitHub light and dark render check of every Mermaid block, owed by OPS-36.
- docs/assets/MANIFEST.md has stale rows (agent-brief.png, agent-explore.png, panel-ask-agent.png), for OPS-36, OPS-48 or OPS-52.
- OPS-36 applies the quick-start change to README.md.

Privacy grep over the diff (337 added lines): 0 hits.
