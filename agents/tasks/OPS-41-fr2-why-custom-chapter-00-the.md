---
id: OPS-41
title: FR2: "why custom" as chapter 00 — the case for bringing our own surfaces and cards instead of only Agentforce's standard chat, for the teams who sell and build it, with the architecture of the why and every claim backed by a measurement or a public doc
domain: ops
tier: frontier
tier_reason: the argument the whole GTM story rests on, written for sellers and architects at once, and fair to the platform
status: blocked
blocked_by: [OPS-38, BE-32, FE-18]
fixes: []
scope: [docs/patterns/00-why-custom.md, tests/test_pattern_00.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_00.py fails on main (the page does not exist) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's note on the hotkey panel and every surface: "really articulate the why behind us bringing in a custom architecture and view to all of these panels and going custom instead of standard Salesforce and Agentforce". His reasons: the standard launcher "doesn't scale", "there's soft limits for how many characters", and "teams decelerate when trying to incorporate lightning cards into the responses". It is "a note that we need to make sure we communicate to our teams", with "the architecture of the why". On pattern 06 he added: "this is agent force, it's just a different skinned version of it". Covers ledger rows F66 and F84 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (F60 to F66 and the decision on where "why custom" lives), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape', 'Diagrams'), docs/research/fr2-standard-limits.md (BE-32), docs/research/fr2-card-architecture.md (FE-18), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), docs/patterns/03-hotkey-panel.md and 06-agent-routing-and-verbatim-relay.md, and the brain's generic restatement at .delegation/fr2/operating-pattern.md. Cite that source only as "a production Agentforce build we reviewed", never by name, client, agent or class
- Follow the page shape. **Header:** "Why custom" and one line: this is Agentforce (the same platform, models and trust layer), with surfaces and cards we control. It is a different skin, not a rival, and the page never argues about whether it counts as Agentforce. **The business problem**, in plain words a seller can repeat: the standard launcher is easy to miss and fixed in place, so reps do not use it; long answers get quietly shortened past a soft character ceiling, so lists are cut to fit; cards in the standard chat show only some of the time, so teams spend build cycles on them and then fall back to text; every follow-up becomes a new build (link pattern 02). Each point carries its number from BE-32 or a public doc link. Say it respectfully: what we gain, not what is wrong with the platform
- **The architecture of the why:** two short diagrams per fr2-design.md 'Diagrams' (autonumber, phase blocks, one accent colour for model calls). First, the standard path: launcher, the agent's model step re-writes the action's answer (where the ceiling bites), a card only if the model chooses one. Second, ours: the surface calls the Apex services directly, the answer and its cards come from one typed contract (FE-18) and render every time, and MCP uses the same services. Numbered steps under each diagram use the same numbers
- **What changes for a team:** fewer caps tuned to a ceiling, cards that always render, follow-ups without new builds, one place to brand. **When standard is the right choice**, from BE-32's list. **Limits and open items**, each linked to a card or "no card yet" (for example the custom code a customer now maintains)
- Every diagram renders on GitHub; check each with gh api markdown (read-only) and say so in the hand-back. tests/test_pattern_00.py checks the parts in order, that every mermaid sequence diagram starts with autonumber, that every number in the business problem has a link on the same line, and (from an env-var word list, never committed) that no reference-guide name appears. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
