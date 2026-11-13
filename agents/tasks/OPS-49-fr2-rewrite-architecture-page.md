---
id: OPS-49
title: FR2: docs/ARCHITECTURE.md rewritten for Customer Summary — three ways in and the optional agent, one service behind each skill, the card contract, the trust rule with each system-context use, and the pattern list from the index
domain: ops
tier: standard
tier_reason: one page rewritten from research pages and an index that already exist
status: blocked
blocked_by: [OPS-48]
fixes: []
scope: [docs/ARCHITECTURE.md, tests/test_architecture_doc.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/patterns/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_architecture_doc.py fails before this card (the page has no link to chapter 00 or page 14, still shows the agent as a way in, and its pattern list does not match docs/patterns/README.md) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2): docs/ARCHITECTURE.md is the one page that shows how the whole product fits together, and every chapter links it. The rename (BE-23) changes its names, but no card rewrote it for what FR2 built: three surfaces, the card contract, customer outcomes, the trust rule and an agent that is now optional (finding 7 in docs/reviews/fr2-plan-review.md).

## Done when

- Read first: docs/plans/fr2-design.md, docs/patterns/README.md (the index OPS-48 wrote) and every page it lists, docs/patterns/_diagram-theme.md, the current docs/ARCHITECTURE.md, and the research pages docs/research/fr2-trust-rule.md (BE-37), docs/research/fr2-card-contract-apex.md (BE-39), docs/research/fr2-card-architecture.md (FE-18), docs/research/fr2-rail-context.md (BE-25), docs/research/fr2-conversation-history.md (BE-26), docs/research/fr2-customer-outcomes.md (BE-35), docs/research/fr2-model-door.md (BE-33) and docs/research/fr2-agent-publish.md (OPS-51)
- Rewrite docs/ARCHITECTURE.md under the Customer Summary names: what the product is in three sentences; the three ways in (the compact window, the right rail, and the outside door over MCP, whose tools are Apex actions) and the optional agent as an add-on and test bench, never as a way in; one Apex service behind each skill (summary, ask anything, act) and every way in calling it; the card contract every surface reads; the two memories (conversation history and customer outcomes); the model door; and brand settings. Each part is a few plain lines and a link to its pattern page
- One component diagram of the shared conversation core and its frames, and one sequence diagram of a question from a surface to an answer with cards. Both follow fr2-design.md 'Diagrams' and copy the theme block from docs/patterns/_diagram-theme.md; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back
- **Trust:** a part that says what runs as the signed-in user and lists each system-context use with its reason, taken from docs/research/fr2-trust-rule.md and no wider than that page. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md). It names roles, not people, and links no card file
- **The pattern list** is copied from docs/patterns/README.md: the same titles in the same order, with 06 shown as an appendix, 07 as a principles page and 14 as a placeholder. The page links chapter 00 (why custom) near the top and page 14 where it names the embedded surface. Old names appear only as link text that points at a historical page
- tests/test_architecture_doc.py checks that every page in the index is linked exactly once with its title, that chapter 00 and page 14 are linked, that the page does not present the built-in panel or "Ask the agent" as a way in, that each sequence diagram starts with autonumber and carries the theme block, and that every system-context use named in docs/research/fr2-trust-rule.md appears on the page. Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
