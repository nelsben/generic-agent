---
id: OPS-40
title: FR2: pattern 03 as a workbook chapter — the hotkey panel told as the way in a rep actually uses (snap in, hide, switch chats), with numbered colour sequence diagrams, numbered steps that match, and each limit linked to its card
domain: ops
tier: frontier
tier_reason: a chapter written for a business reader and an architect at once, from Ben's own notes
status: blocked
blocked_by: [OPS-38, FE-12, FE-13, FE-16, FE-17, FE-18]
fixes: []
scope: [docs/patterns/03-hotkey-panel.md, tests/test_pattern_03.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_03.py fails on main (pattern 03 has no business problem, no architecture steps, no autonumber) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 03. He likes it "for the most part": "being able to snap in, hide, display different chats brings us a level of visibility that that might not actually exist there today", and "I don't think anybody is dying to use the Astro button". He asked that "limits and open items are covered", to "think about the hotkey panel and other items we should add later", and that "the how it works also needs auto number with numbered suggestions down below". A further note asked that every answer be "richly formatted" in cards (F65), so the page drops "plain text only" for what FE-12 and FE-18 built. Covers ledger rows F60 to F65 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F60 to F65, and the decision that the hotkey panel is the way in we lead with), docs/plans/fr2-design.md ('Surfaces', 'Pattern page shape' and 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current pattern 03 page as FE-12 and FE-13 left it, docs/research/fr2-panel-proof.md (FE-16) and docs/research/fr2-panel-later.md (FE-17)
- Follow the page shape. **Header:** the compact window's name and one line on what it gives a rep. **The business problem:** the agent sits behind a button reps do not reach for, so it goes unused; here it is one key away on any page in the app, snaps in, hides without losing the thread, and switches between past chats. Name Agentforce's own panel neutrally, as the built-in door that stays supported. **The architecture in steps:** open, ask, answer, switch or hide, close
- **How it works:** split the one long diagram into phases per fr2-design.md 'Diagrams' (autonumber, a shaded block per phase with a Note: open, ask through Apex, ask the agent, driven by another component, close; one accent colour for the model and agent calls). The numbered steps under it use the same numbers, one numbered item per step or per run of steps ("steps 4 to 7"), so a reader can follow a number from the picture to the words. Every diagram renders on GitHub; check each with gh api markdown (read-only) and say so in the hand-back
- **Why you can trust it** and **how it scales:** each claim links to a Jest test, an e2e test, a review or the FE-16 proof page. **Limits and open items:** each links to its card (FE-5, FE-16, FE-17's proposed cards) or says "no card yet"; what FE-12, FE-13 and FE-16 closed moves out of the list. **What comes later:** the top of FE-17's ranked list, marked plainly as not built
- Leave the See it images and their alt text as they are; OPS-36 recaptures them per surface. Uses Customer Summary names throughout. tests/test_pattern_03.py checks the parts and headings in order, that every mermaid sequence diagram starts with autonumber, and that the numbered steps under each diagram cover its numbers. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
