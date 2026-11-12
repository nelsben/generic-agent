---
id: OPS-39
title: FR2: pattern 02 as a workbook chapter — the ask-anything explorer told as "a follow-up is never a new build", with numbered colour sequence diagrams, the scale-out path from the discovery, and each limit linked to its card
domain: ops
tier: frontier
tier_reason: the chapter that carries the product's core operating principle, written for a business reader and an architect at once
status: blocked
blocked_by: [OPS-38, BE-30, BE-31, FE-20]
fixes: []
scope: [docs/patterns/02-ask-anything-explorer.md, tests/test_pattern_02.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_02.py fails on main (pattern 02 has no business outcome on follow-ups, no autonumber, no principle) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 02. The business outcome: in a typical Agentforce build, "each follow-up question needs to be a flow, repurposed or rebuilt with context shoved back through". That means "endless build cycles, and hours that our customer isn't counting on", while Claude "can do all of these things already". Here, follow-ups to the summary work "organically" and scale "to any object, any combination of data", "a core operating principle". The page also gets the diagram style, a See it on each surface, and limits as cards. Covers ledger rows F54 to F59 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F54 to F59, and any later pattern 02 rows), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape' and 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current pattern 02 page, docs/research/fr2-follow-ups.md (BE-30), docs/research/fr2-explorer-scale.md (BE-31) and docs/research/fr2-retire-ask-agent.md (FE-20)
- Follow the page shape. **Header:** "Ask anything" and one line on what it gives a rep. **The business outcome:** the build-a-flow-per-follow-up problem in plain words: the summary, then a new flow or action for each next question, context passed back by hand, build cycles and hours nobody planned. Then what changes: the rep asks the next question in their own words and gets an answer from the same context, with no new build. **The operating principle:** "a follow-up is never a new build", as fr2-design.md states it. **The architecture in steps:** plan, check, run in the user's access, correct, answer, drill
- **How it works:** a sequence diagram per fr2-design.md 'Diagrams' (autonumber, phase blocks, one accent colour for model calls), with a second, short diagram for a follow-up after a summary (the summary context going in, BE-30). The numbered steps under each diagram use the same numbers. Every diagram renders on GitHub; check each with gh api markdown (read-only) and say so in the hand-back
- **How it scales:** what works today (the catalog, the caps, user mode, the live follow-up result from BE-30) and the scale-out path BE-31 recommends, marked plainly as not yet built, with its proposed cards. Never claim "any object" as done before it is. **Why you can trust it:** each claim links to a test, a review or a recorded run. **Limits and open items:** each links to its card (BE-30, FE-12, BE-31's proposed cards, FE-5; an agent-only item says it moved to the optional appendix, OPS-44) or says "no card yet"
- Leave the See it images and their alt text as they are; OPS-36 recaptures them per surface. Uses Customer Summary names throughout. tests/test_pattern_02.py checks the parts and headings in order, that every mermaid sequence diagram starts with autonumber, and that the principle line is present. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
