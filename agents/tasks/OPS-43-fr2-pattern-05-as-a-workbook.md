---
id: OPS-43
title: FR2: pattern 05 as a workbook chapter — memory and customer history told as two memories (the conversation, and outcomes that persist against the customer), how Agentforce's Agent Memory fits, a restyled numbered diagram, and every limit rechecked and linked
domain: ops
tier: frontier
tier_reason: a chapter that positions the product against a new platform feature, written for a business reader and an architect at once
status: blocked
blocked_by: [OPS-38, BE-34, BE-26, BE-35, BE-36, FE-19]
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

- Read first: docs/plans/feature-revision-2.md (rows F74 to F81 and the decisions on customer outcomes), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), the current pattern 05 page, and docs/research/fr2-conversation-history.md (BE-26), fr2-agent-memory.md (BE-34), fr2-customer-outcomes.md (BE-35) and fr2-sentiment.md (BE-36)
- Follow the page shape; the title becomes "Memory and customer history". **Header** and one line: the product remembers what it did for each customer, and every rep starts from that. **The business problem:** a summary that is generated and lost is paid for and forgotten; reps repeat themselves; nobody sees how a customer is trending. **Two memories:** the conversation (short, own-only, per session) and customer outcomes (durable, against the account, kept by type, shown to others without what only the author could read). **Agentforce's Agent Memory:** what it is and how it fits, from BE-34's table, fair to the platform; say plainly what it covers and what our outcomes keep. **The architecture in steps:** a skill finishes, it records an outcome, the next conversation starts with the outcome context, the next summary says what changed, the rail shows the timeline and the trend
- **How it works:** diagrams per fr2-design.md 'Diagrams' (autonumber, phase blocks for write, read and reuse, one accent colour for model calls), with the numbered steps under each using the same numbers. Every diagram renders on GitHub; check each with gh api markdown (read-only) and say so in the hand-back
- **See it:** leave image links to OPS-36, but name the captures FE-19 made. **Limits and open items, rechecked:** go through every item on today's page and every limit BE-26, BE-34, BE-35 and BE-36 recorded. For each, say whether it is closed (and by which card), still open with a card, accepted with the reason, or "no card yet". tests/test_pattern_05.py checks the parts in order, that every mermaid sequence diagram starts with autonumber, and that an Agent Memory section exists. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
