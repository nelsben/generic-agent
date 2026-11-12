---
id: OPS-37
title: FR2: adversarial plan review — check that every piece of Ben's FR2 feedback is carried by a card, and attack the cards' order, scope, safety and design before any build starts
domain: ops
tier: frontier
tier_reason: adversarial reasoning across the whole plan, the design and Ben's own words
status: merged
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

## Review

Brain-authored review page, verified by the tool at `fc204a9` (branch, scope, files and the test gate held: 100 tests OK) and then read by an independent reviewer: 13 claims confirmed, 0 refuted, 7 unverifiable.

What the reviewer confirmed by script: the change is one file; 69 findings (10 blockers, 34 major, 25 minor); every quoted citation matches its line at `98dd6c7` (115 of 115, and 12 of 12 path-form citations); both columns of the Numbers table; the 177-row coverage tally; the repo facts behind blocker 1; the gate and org-rule gaps; the unordered card pairs; the Approvals-table readings; the link check (37 pages, 0 broken).

What stays unverifiable from inside the worktree, and how each is closed:

- How the tool treats `blocked`, `parked` and unknown status words. The follow-on holds change records dry-run dispatches that show it.
- Whether the coverage table is faithful to Ben's words. The verbatim copy is kept outside the repo by design; the brain read it against the table.
- That nothing in an org changed and no `sf` command ran. True of this session; nothing in the tree can show it.
- The facts about this Mac's own configuration. They are labelled **machine** in the page.
- That no client or reference-app name appears. The brain's denylist check over the added lines returned 0.
- The missing `red=` field. The card's red test is "none (review)".
- `tests/__pycache__` after the commit. The tool's own gate run made it; removed before merge.

No card, plan or Approvals row is changed by this card. The holds and the card edits follow as their own changes.
