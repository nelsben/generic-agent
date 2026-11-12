---
id: OPS-45
title: FR2: page 07 becomes "Trust by design" — one screen with the rule (it sees what the rep sees), the named system-context exceptions and what each permission set grants, out of the chapter list; the failure behaviour lives in the chapters where it happens
domain: ops
tier: standard
tier_reason: shrinks a page into a reference that must match the code's markers and the chapters it points to
status: blocked
blocked_by: [OPS-38, OPS-40, BE-37, BE-26, BE-33, BE-35, FE-20]
fixes: []
scope: [docs/patterns/07-trust-access-and-failure.md, tests/test_pattern_07.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_07.py fails on main (page 07 is a full chapter with no "Trust by design" title and no list of system-context exceptions) and passes after
gate: test
budget: 2-attempts
spend: 4
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 07: "I again don't know if this is an entire chapter. I think this is more so design philosophy than anything else", "How we give access to records and permission sets is an implementation detail almost", and "making sure your agent runs in with sharing, except for things where it needs system context, like memory records ... I would align to that." Trust is principle 5, told once here and shown in each chapter. Covers ledger rows F85 to F87 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F85 to F87 and the decision that trust is a principle), docs/plans/fr2-design.md (principle 5), the current page 07, docs/research/fr2-trust-rule.md (BE-37) and the `// system-context:` markers in the Apex classes, docs/research/fr2-retire-ask-agent.md (FE-20), and patterns 01 and 03 as OPS-38 and OPS-40 left them
- Keep the file name (the sweep card settles final numbering and file names). The title becomes "Trust by design", and the page fits on about one screen. **One line:** it sees only what the rep sees, and when something fails the rep reads one plain sentence. **The rule:** with sharing and user mode everywhere; system context only for the product's own records, each named. **The exceptions:** a short table (what, why, the guard, the test), built from the markers and BE-37's page, so it matches the code. **Failures:** two or three lines that link to where each is shown (not found and a choice of accounts in pattern 01, the panel's fixed sentences in pattern 03); no diagram and no screenshots here. **Access in one step:** the permission set group, and in a short table what each set grants, as reference for a builder
- **Limits and open items, rechecked:** every item on today's page is closed (and by which card, for example BE-29 for N2 and N7, BE-33 and FE-20 for N11, FE-12 for the Id-shaped drill button), accepted with the reason, or "no card yet". The non-admin run stays "not yet proven" with a link to FE-5 until FE-5 has passed. tests/test_pattern_07.py checks the title, that the exceptions table names every class that carries a `// system-context:` marker, and that the page has no mermaid block. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
