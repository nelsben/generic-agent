---
id: OPS-67
title: README and ARCHITECTURE diagrams restyled (6 blocks)
domain: ops
tier: standard
effort: medium
status: merged
scope: [README.md, docs/ARCHITECTURE.md, tests/test_readme_fr2.py, tests/test_architecture_doc.py]
forbid: [tests/pattern_shape.py, docs/patterns/_diagram-theme.md, docs/patterns/01-route-gather-reduce.md, docs/plans/**, docs/research/**, force-app/**, .chassis-delegation.json]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

Ben found the diagrams messy, hard to read and not customer facing. PR #302 set a new style, made its rules testable in tests/pattern_shape.py, and restyled docs/patterns/01-route-gather-reduce.md as the reference page; the other 22 diagrams still use the old %%{init}%% line and must be rewritten to match.

## Done when

- Read docs/patterns/_diagram-theme.md (snippets and rules) and docs/patterns/01-route-gather-reduce.md (the reference: its three diagrams and the numbered steps under its sequence diagram) before editing.
- Every mermaid block in the lane's pages opens with the sequence or flowchart snippet from _diagram-theme.md, word for word, and no longer carries %%{init: (pattern_shape.check_diagrams passes in its new-style branch for every block).
- Each sequence diagram is a rewrite for a customer reader, not a restyle: at most five lifelines named in plain business words (for example Sales rep, Customer Summary, Salesforce records, AI model, Memory), no box, messages of at most 32 characters, no message from a lifeline to itself, every message inside a phase rect opened by one 'Note over <one lifeline>: <Phase>' except the opening ask and the closing answer, each model call and its reply inside the coral rect rgba(244, 114, 82, 0.22) nested in its phase, phase tints taken in order from the table in _diagram-theme.md.
- Keep the existing phase names (the words after 'Note over ...:') unless the page's own test is updated in the same change; keep the diagram's meaning: no step that the old diagram showed may be dropped from the numbered prose under it, and class, object and prompt names that leave the diagram must still be named in those numbered steps.
- The numbered list under each sequence diagram names every new step number exactly once as (step N), (steps N and M) or (steps N to M); renumbering is done in that list and in every other reference to the page's step numbers anywhere in README.md and docs/ outside docs/plans/ and docs/research/ (grep for 'steps? [0-9]' and for links to the page).
- Every count or fact in a message label (for example '7 sections', 'six sections', token budgets) matches the old diagram or the code; do not invent numbers.
- Flowcharts use the flowchart snippet, flowchart TB or LR, only classDef lines copied from _diagram-theme.md, every subgraph classed zone, short node text, and no node placed last in the bottom-right corner when avoidable.
- Page tests in scope that asserted the old style (box counts, rect rgb(...) colours, the theme_line() equality) assert the new style instead (for README and ARCHITECTURE tests: call pattern_shape.check_diagrams(self, text, name) in place of the theme_line() comparison); no assertion is deleted without a replacement that checks the same intent.
- Do not edit tests/pattern_shape.py, docs/patterns/_diagram-theme.md or docs/patterns/01-route-gather-reduce.md.
- bash scripts/check-docs.sh reports 0 broken and the unit test suite passes.
- The hand-back lists, per diagram, old step count -> new step count and every prose step reference changed (file:line).

## Review

Brain review, 2026-11-17. Worker attempt 1 (sonnet) consistent; the brain added two commits.

- Read the whole diff: 6 blocks in README.md and docs/ARCHITECTURE.md now use the theme page snippets; step lists cover 1..N once; names that left the diagrams are in the steps. Privacy grep of the added lines: 0 hits.
- Brain fix 1: ARCHITECTURE phase tints now match page 01 (Reduce violet, Remember slate); two sentences about the diagram itself removed from the steps.
- Brain fix 2: the component flowchart (same block on both pages) was a tall, crossing layout with the AI model node under GitHub's pan and zoom buttons. Redrawn top-down: frames and other callers, one shared conversation node, the Apex zone, the AI model to the side. Viewed on GitHub (dark): reads in one pass, corner clear.
- Viewed every block on the pushed branch on GitHub. Gate green (unit suite, check-docs).
