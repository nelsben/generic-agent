---
id: OPS-37
title: FR2: adversarial plan review — check that every piece of Ben's FR2 feedback is carried by a card, and attack the cards' order, scope, safety and design before any build starts
domain: ops
tier: frontier
tier_reason: adversarial reasoning across the whole plan, the design and Ben's own words
status: queued
fixes: []
scope: [docs/reviews/fr2-plan-review.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: none (review): the evidence is docs/reviews/fr2-plan-review.md
gate: test
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2): Ben asked that the FR2 cards be tagged "so we can do an adversarial review against the cards once the plan is complete". This review runs before the builds so dropped feedback, bad ordering and unsafe steps are caught while they are cheap. Covers ledger row F40 in docs/plans/feature-revision-2.md. Runs on Ben's word.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/plans/gtm-burn-plan.md (the Approvals table), every agents/tasks/*.md whose title starts with 'FR2' plus BE-20 and OPS-28, and docs/patterns/*.md. The brain places Ben's verbatim FR2 messages at .delegation/fr2/feedback-verbatim.md in the worktree; it is gitignored: read it, never commit it, and never copy a client or reference-app name from it into any file
- Coverage: split the verbatim messages into single asks and answers, and for each one name the ledger row and the card done-when line that carries it. An ask with no carrying line, a ledger row whose card does not actually do it, or a card that does something Ben did not ask for is a finding
- Attack the plan: the blockedBy graph (cycles, a card that needs another's output but is not blocked by it, cards that could run sooner), scope and forbid overlaps between cards that could run at the same time, every org action against the Approvals table and the safety rules in the cards (users, sign-in, experimental, publishes, destructive changes, records written), whether each red test can really fail first, whether the spikes answer what later cards assume, the design brief against the cards (any card that contradicts it), and the open questions (F17, F32) and how each card behaves until Ben answers
- Write docs/reviews/fr2-plan-review.md: verdict, the coverage table, findings ranked by severity naming the card and line, and the exact card edits proposed. Do not edit cards or the plan. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
