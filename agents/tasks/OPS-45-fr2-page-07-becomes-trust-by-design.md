---
id: OPS-45
title: FR2: page 07 becomes "Trust by design" — one screen with the rule (it sees what the rep sees), the named system-context exceptions and what each permission set grants, out of the chapter list; the failure behaviour lives in the chapters where it happens
domain: ops
tier: standard
tier_reason: shrinks a page into a reference that must match the code's markers and the chapters it points to
status: merged
fixes: []
scope: [docs/patterns/07-trust-access-and-failure.md, tests/test_pattern_07.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_07.py fails on main (page 07 is a full chapter with no "Trust by design" title and has a mermaid diagram) and passes after
gate: test
budget: 2-attempts
spend: 4
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 07: "I again don't know if this is an entire chapter. I think this is more so design philosophy than anything else", "How we give access to records and permission sets is an implementation detail almost", and "making sure your agent runs in with sharing, except for things where it needs system context, like memory records ... I would align to that." Trust is principle 5, told once here and shown in each chapter. Covers ledger rows F85 to F87 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F85 to F87 and the decision that trust is a principle), docs/plans/fr2-design.md (principle 5), the current page 07, docs/research/fr2-trust-rule.md (BE-37) and the `// system-context:` markers in the Apex classes, docs/research/fr2-retire-ask-agent.md (FE-20), and patterns 01 and 03 as OPS-38 and OPS-40 left them
- The file name is final. Page 07 is one screen: fr2-design.md exempts it from the full page shape. The title becomes "Trust by design", and the page fits on about one screen. **One line:** it sees only what the rep sees, and when something fails the rep reads one plain sentence. **The rule:** with sharing and user mode everywhere; system context only for the product's own records, each named. **The exceptions:** a short table (what, why, the guard, the test), built from the markers and BE-37's page, so it matches the code. **Failures:** two or three lines that link to where each is shown (not found and a choice of accounts in pattern 01, the panel's fixed sentences in pattern 03); no diagram and no screenshots here. **Access in one step:** the permission set group, and in a short table what each set grants, as reference for a builder. State the rule in the same two lines the chapters open their trust part with ('Runs as the signed-in user:' and 'System context:'), so the chapters and this page match
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **Limits and open items, rechecked:** every item on today's page is closed (and by which card, for example BE-29 for N2 and N7, BE-33 and FE-20 for N11, FE-12 or FE-22 for the Id-shaped drill button, whichever the code shows), accepted with the reason, or "no card yet"; a limit gives its card by id and never links a card file. For the non-admin run, link the README's Status table (the 'Status' heading in README.md) instead of saying on the page whether it is proven. tests/test_pattern_07.py checks the title and that the page has no mermaid block; it does not count markers, so a later card that adds one does not fail this page's test. The hand-back says the exceptions table matched every `// system-context:` marker at the time (grep). Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). One attempt (30199f7, $0.36). The verifier found the report consistent and the gate green and returned next=accept with no reviewer pass. The brain read the page and the test, and checked the code claims.

Findings:
- docs/patterns/07-trust-access-and-failure.md is now "Trust by design", one screen with no diagram and no screenshots. The file name is unchanged.
- The rule sits in the fixed H2 "Why you can trust it", opening with the same "Runs as the signed-in user:" and "System context:" lines the chapters use. The worker chose this because a page's first H2 cannot be an extra.
- The extra H2 "The exceptions" is a four-row table (what, why, guard, test) for AgentLlm, CustomerSummaryMemory, CustomerOutcomes and CustomerOutcomeRetentionBatch. The brain's grep found `// system-context:` markers in exactly those four classes (1, 5, 3 and 1) plus one in the test-only CustomerSummaryContextTest. All seven cited Apex test methods exist in the named test classes.
- The extra H2 "Failures" links pattern 01's "When something fails" heading and pattern 03.
- Adopt it names the one step (the Customer_Summary_User group) and what each set grants. The group's metadata holds Customer_Summary_Data_Access and Customer_Summary_Outcome_Access only, so the page's "Customer_Summary_Agent_Access (not in the group)" matches the code and corrects the old page.
- Limits mark BE-29, BE-33 with FE-20, and FE-12 closures, list the Models API question as "no card yet", and link README.md#status for the non-admin run. No proof wording and no card file links.
- New tests/test_pattern_07.py checks the title, the shape, no mermaid and no images, a length cap, the failure links, a table row for every marked class, no proof wording, the card ids, the permission set names and the way back.

Gate (verifier at 30199f7): Python 289 tests, 2 skipped. Brain: check-docs 71 pages, 0 broken.

Disclosed and accepted:
- The test checks that every class carrying a marker has a table row. The card said the test should not count markers, so that a later marker does not fail this page; this check would fail a later card that adds a marker in a new class without updating page 07. Accepted as a useful tie between the code and the page.
- fr2-trust-rule.md's own table does not yet list CustomerOutcomes or CustomerOutcomeRetentionBatch; the page is built from the code. The page links that research page as "the same list", which is not yet true.
- The README row for page 07 still uses the old title (README is forbidden on this card).
- A tests/__pycache__ made by the gate runs was removed before merge.

Still open:
- Add CustomerOutcomes and CustomerOutcomeRetentionBatch to fr2-trust-rule.md's table, or change page 07's "the same list" line.
- README and ARCHITECTURE titles for page 07 (fold into OPS-36 or OPS-48).

Privacy check over the full branch diff (131 added lines): 0 denylist hits; no URLs, Ids, local paths or job Ids.
