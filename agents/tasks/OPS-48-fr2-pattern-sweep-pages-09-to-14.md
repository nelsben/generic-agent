---
id: OPS-48
title: FR2: the pattern sweep — pages 09 to 13 in the full page shape, page 14 kept a placeholder, one index page that fixes every title and the reading order, the access step in every Adopt it part, and one test over every page
domain: ops
tier: frontier
tier_reason: five pages rewritten to one shape from the work of ten build cards, plus the index and the test every later page change answers to
status: merged
fixes: []
scope: [docs/patterns/**, tests/test_pattern_pages.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, docs/ARCHITECTURE.md, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_pages.py fails before this card (there is no docs/patterns/README.md index, and pages 09 to 13 do not have the eight parts) and passes after
gate: test
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2): Ben asked for a repo that reads "like a gtm business driven outcome workbook thats easy to ready and consume for each architecture pattern". Chapters 00 to 08 each have a card that leaves them in final form. Pages 09 to 14 were written by build cards as they went, or not at all since FR1, and no card left them in the workbook shape, fixed the titles and reading order, or put the access step in each page (ledger F86; findings 7, 33, 35 and 62 in docs/reviews/fr2-plan-review.md). This card is that sweep.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md ('Pattern page shape' and 'Diagrams', with the exemptions it lists), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice), docs/patterns/_diagram-theme.md (the theme block and the render check), tests/pattern_shape.py, every page under docs/patterns/ with its own test, and the research pages behind pages 09 to 13: docs/research/mcp-door-runbook.md, docs/research/fr2-agent-publish.md (OPS-51), docs/research/fr2-surfaces-spike.md (OPS-29), docs/research/fr2-rail-context.md (BE-25), docs/research/fr2-action-cards.md (FE-14), docs/research/fr2-actions-spike.md (BE-22), docs/research/fr2-customer-outcomes.md (BE-35) and docs/research/fr2-card-contract-apex.md (BE-39)
- **The index:** a new docs/patterns/README.md lists pages 00 to 14 once each, in reading order, with the page's final title (its H1, copied exactly), one line on what it gives a seller or a service rep, and its kind: chapter, appendix (06), principles page (07) or placeholder (14). File names are final and are not changed. The README and docs/ARCHITECTURE.md copy their pattern lists from this page (OPS-36 and OPS-49)
- **Pages 09 to 13 follow the full page shape**, with its exact H2 headings in its order ('The business problem', 'The architecture in a few steps', 'How it works', 'See it', 'Why you can trust it', 'How it scales', 'Adopt it', 'Limits and open items'): the theme block copied from docs/patterns/_diagram-theme.md, `autonumber` on every sequence diagram, numbered steps under each diagram that use the same numbers, and a trust part that opens with the two trust lines fr2-design.md 'Pattern page shape' fixes: one starting 'Runs as the signed-in user:' and one starting 'System context:', which names each system-context use on this path with its reason, or says 'none on this path'. Each page keeps the facts its build card wrote and gains what the shape needs. Leave the captures in each 'See it' part as the build cards left them: OPS-52 retakes them
- **Page by page.** 09 (the outside door): the tools are Apex actions and the optional agent is not a tool; it says which names the door runs under in the org today (the old names until OPS-31 has merged; read docs/research/mcp-door-runbook.md to see which), its 'See it' part is a text block, and every open item on the page is closed with the card that closed it or named with the card that has it. 10 (brand): the swap in five steps, with BE-24's before-and-after captures. 11 (voice): the privacy line that Chrome sends audio to Google to transcribe it, and what is checked by hand. 12 (the right rail): shows the outcomes timeline and the sentiment chart from FE-19, and links chapter 00 for why the surface is custom. 13 (write actions): rewritten around the draft and result cards from docs/research/fr2-action-cards.md, with the draft-then-confirm rule, Undo for updates only, and what the end-to-end test proves under its Approvals row. 14 (embedded): stays a labelled placeholder, exempt from the shape, and links chapter 00
- **The access step (ledger F86):** every page that has an 'Adopt it' part has one step that grants access by assigning the one permission set group, in the same words on every page. Add it to pages 01 to 08 only where a chapter card left it out, and change nothing else on those pages apart from the way-back line. **The way-back line:** every page from 00 to 14 ends with one line that links the index and the repo's README. Every chapter's own test still passes unchanged
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- tests/test_pattern_pages.py: one table lists every page from 00 to 14 with the parts it has and the extra H2 parts it adds (filled from each chapter's own test, so the two agree), and the test runs the shared helper tests/pattern_shape.py over each row. It also checks that the index lists every docs/patterns/NN-*.md file exactly once with a title equal to that page's H1, that every page with an 'Adopt it' part names the permission set group, that every page ends with the way-back line, and that no page links a file under agents/tasks/. Do not edit tests/pattern_shape.py or any chapter's own test; if the helper cannot express a page, hand back
- Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven. The lessons from a production Agentforce build we reviewed are in fr2-design.md ('Lessons from a reviewed build'): use only that text, cite the source only as "a production Agentforce build we reviewed", and never name it, its author or its client. Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Three attempts.
- Attempt 1 (20ea01c): $5.67, including one advisor call at $1.75. Its sonnet review returned 18 confirmed, 3 refuted and 3 unverifiable.
- The brain then called the advisor once before resuming. Page 09 still stated run status in its trust and Limits parts. Two hand-back sentences misdescribed page 12.
- Attempt 2 (9bd37df): $0.32. Its sonnet review returned 17 confirmed, 1 refuted and 3 unverifiable, and the budget was spent.
- The brain checked the one refuted row by hand. It refutes the hand-back's wording, not the page: the hand-back said page 13 names CustomerOutcomes' text "read, set and delete".
- Page 13's System-context line names the set and the delete. Those are the two markers on the action path (CustomerOutcomes.cls lines 185 and 226).
- The text read (line 409) belongs to the view path, and page 12 names it. The page is right.
- The budget was raised to three. A hand-back-only correction changed no sha, so the brain re-judged the commit with a verify run ($0.59). That review saw only the report line and refuted two card items: four page 09 limits said "No card yet", and the render check was not run.
- The brain cut OPS-61 (parked until Ben answers on loading Mermaid from a CDN) to hold the render check. The advisor was called once.
- Attempt 3 (60edb45): $0.46. The render-check limit on pages 09 to 13 now names OPS-61. Its sonnet review returned 24 confirmed, 0 refuted and 3 unverifiable.

Findings:
- New docs/patterns/README.md is the index. It lists pages 00 to 14 once each in number order, with the page's H1, its kind and one line on what it gives a seller or a service rep.
- Pages 09 to 13 are rewritten in the full page shape: the theme line, `autonumber`, numbered steps matching the arrows, both trust lines and the access step. Limits name cards by id.
  - 09: the tools are Apex actions, and the agent is not a tool. It names the CustomerSummaryMcp names in the org today. The first real tool call is an open item under OPS-53 (parked), and run status is linked to the README's Status table.
  - 10: a five-step swap, with a step that places the history timeline and the sentiment chart on the Account record page.
  - 11: the privacy line, and the mic in the composer.
  - 12: the history timeline and the sentiment chart (labels only), with the chart crowding as an open item.
  - 13: the draft and result cards, the draft-then-confirm rule, and Undo for updates only. The two-action limit is noted for the door and agents; the panel keeps six.
- 14 stays a labelled placeholder, with its rail wording updated for FE-19 and FE-27.
- Every page from 00 to 14 ends with the way-back line. On pages 00 to 08 nothing else changed.
- New tests/test_pattern_pages.py runs the shared shape helper over every page. It also checks the index against each H1, the group in every Adopt it part, the way-back line, and that no page links a card file. tests/pattern_shape.py and the chapter tests are unchanged.

Gate (verifier at 60edb45): Python 341 tests, 4 skipped. Brain: check-docs 72 pages, 0 broken.

Disclosed and accepted:
- The diagrams on pages 09 to 13 are not render-checked. The brain told the worker not to run the Mermaid CDN check until Ben answers, so the card's render-check item is unmet. Each page's Limits says so and names OPS-61 (parked).
- Eleven open items on pages 09 to 13 still say "No card yet", which fr2-design.md 'Pattern page shape' allows. The card's stricter wording (every item named with a card) is not met.
- Page 07 words its access step differently from the other pages ("Grant access in one step: ..."). The card forbids other edits to pages 01 to 08, so it was left as it is.
- Page 05's limit "The swap guide does not list the record-page step yet" is now stale, because page 10 has the step. The card allowed only the way-back line on page 05.
- The captures in pages 12 and 13 are named by file but not embedded. OPS-52 retakes and links them.
- A tests/__pycache__ made by the gate runs was removed before each review and before merge.

Still open:
- The render check for pages 09 to 13 (OPS-61, parked on Ben's answer on loading Mermaid from a CDN).
- Page 05's stale swap-guide limit, and page 07's access-step wording (fold into OPS-36 or OPS-52).
- README and ARCHITECTURE copy their pattern lists from the new index (OPS-36 and OPS-49).

Privacy check over the full branch diff at 60edb45 (784 added lines): 0 denylist hits; no URLs, Ids, local paths, org alias or job Ids.
