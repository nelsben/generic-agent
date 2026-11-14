---
id: OPS-43
title: FR2: pattern 05 as a workbook chapter — memory and customer history told as two memories (the conversation, and outcomes that persist against the customer), how Agentforce's Agent Memory fits, a restyled numbered diagram, and every limit rechecked
domain: ops
tier: frontier
tier_reason: a chapter that positions the product against a new platform feature, written for a business reader and an architect at once
status: merged
fixes: []
scope: [docs/patterns/05-conversation-memory.md, tests/test_pattern_05.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_05.py fails on main (pattern 05 has no customer outcomes, no Agent Memory section and no autonumber) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 05: research whether Agentforce's memory feature "impacts our design at all"; store memory and history "in a more agnostic way", where a summary or a created task is "an outcome that has happened that should persist against that customer"; "show a graph of change in customer sentiment over time"; keep "context and history for an agent when the rep opens up the conversation". The same diagram notes as every chapter, and "limits and open items should be rechecked and verified". Covers ledger rows F74 to F81 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F74 to F81 and the decisions on customer outcomes), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current pattern 05 page, and docs/research/fr2-conversation-history.md (BE-26), fr2-agent-memory.md (BE-34), fr2-customer-outcomes.md (BE-35) and fr2-sentiment.md (BE-36). Also docs/research/fr2-trust-rule.md (BE-37), for the reason behind each system-context use
- Follow the page shape, with its exact H2 headings in its order ('The business problem', 'The architecture in a few steps', 'How it works', 'See it', 'Why you can trust it', 'How it scales', 'Adopt it', 'Limits and open items'). The title becomes "Memory and customer history". **Header** and one line: the product remembers what it did for each customer, and every rep starts from that. **The business problem:** a summary that is generated and lost is paid for and forgotten; reps repeat themselves; nobody sees how a customer is trending. **Two memories:** the conversation (short, own-only, per session) and customer outcomes (durable, against the account, kept by type, shown to others without what only the author could read). **Agentforce's Agent Memory:** what it is and how it fits, from BE-34's table, fair to the platform; say plainly what it covers and what our outcomes keep. **The architecture in a few steps:** a skill finishes, it records an outcome, the next conversation starts with the outcome context, the next summary says what changed, the rail shows the timeline and the trend
- **How it works:** diagrams per fr2-design.md 'Diagrams' (autonumber, phase blocks for write, read and reuse, one accent colour for model calls), with the numbered steps under each using the same numbers. Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **See it:** leave image links to OPS-52, but name the captures FE-19 made. **Why you can trust it** opens with the two trust lines fr2-design.md 'Pattern page shape' fixes: one starting 'Runs as the signed-in user:' and one starting 'System context:', which names each system-context use on this path with its reason, or says 'none on this path' (the session store and the outcome store are the system-context uses here; take each reason from docs/research/fr2-trust-rule.md). **How it scales:** retention by type, the purge job and what the rows cost to keep, from BE-35's page. **Adopt it** has one line on the record-page target: the timeline and the sentiment chart (FE-19) can be placed on a record page, and placing them is a step in the swap guide, not something the quick start does. **Limits and open items, rechecked:** go through every item on today's page and every limit BE-26, BE-34, BE-35 and BE-36 recorded. For each, say whether it is closed (and by which card), still open with a card, accepted with the reason, or "no card yet". tests/test_pattern_05.py calls the shared helper tests/pattern_shape.py (from OPS-38), passing the parts this page has and the extra parts it adds; the helper checks the headings in order, autonumber on every mermaid sequence diagram, the theme block and the two trust lines, and adds its own check that an Agent Memory section exists. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
- **What BE-34 found (merged 2026-11-13):** docs/research/fr2-agent-memory.md measured the agent session: context kept at 1, 5 and 15 idle minutes and lost at 30, on one sample with the cause unproven (session age and the number of open sessions are not separated from idle time). Fill pattern 05's "has not been measured" line with exactly that, hedged the same way. Agent Memory is per user and per agent, not keyed to an account, and never reaches the panel, the rail or MCP: say so in one line and point to the research page, without claiming it replaces BE-26 or BE-35

## Review

Brain review (2026-11-14). Two attempts: attempt 1 at $3.23, attempt 2 (59f5175) at $0.57. Attempt 1's sonnet review returned 22 confirmed, 1 refuted and 5 unverifiable: Limits left out BE-34's limits, and one inference was stated as fact. The advisor was called once before the resume. It asked for a complete pass over all four research pages, the claim fixed in place, and "not tested" wording. Attempt 2's sonnet review returned 17 confirmed, 0 refuted and 1 unverifiable.

Findings:
- docs/patterns/05-conversation-memory.md is now the "Memory and customer history" workbook chapter. It has the fixed H2 parts plus two extra H2s, "Two memories" and "Agentforce's Agent Memory".
- One sequence diagram has 20 numbered messages in three phases: Write, Read and Reuse.
- The Agent Memory section says the claim that it never reaches the panel, the rail or MCP is reasoned from the design, not tested, and gives the basis: Agent Memory lives in a registered agent's runtime, and our surfaces call Apex services. BE-34's opt-in check would test it.
- Limits and open items were rechecked against BE-26, BE-34, BE-35 and BE-36. Each source limit maps to a bullet with a status word: Accepted, Open, Parked with BE-28, or No card yet. Three small items were left out on purpose (the CoworkerMemory store question, BE-36's single no-score reply, and BE-35's SOQL counts, since the page states none). The worker gave reasons, and the review confirmed them.
- New tests/test_pattern_05.py checks the page shape, the phases, the trust lines, the basis wording and the Limits phrases. Red evidence: red-2.txt, 24 tests, 2 failures.

Gate (verifier at 59f5175): Python 334 tests, 4 skipped. Brain: check-docs 71 pages, 0 broken.

Disclosed and accepted:
- The diagram is not render-checked. The brain told the worker not to run the Mermaid CDN check until Ben answers, so the card's render-check item is unmet. The Limits section says so. That instruction is the review's one unverifiable row.
- OPS-35's worktree was cut before this page merged. Its build review reads the old page 05.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- The render check for page 05's diagram, after Ben's answer on loading Mermaid from a CDN.
- The e2e README's model-call counts predate the fourth model call (BE-36). No card yet; fold into OPS-48 or OPS-36.
- README and ARCHITECTURE titles for page 05 (fold into OPS-36 or OPS-48).

Privacy check over the full branch diff (666 added lines): 0 denylist hits; no URLs, Ids, local paths or job Ids.
