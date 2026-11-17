---
id: OPS-70
title: Pattern pages 09 to 13 diagrams restyled (6 blocks)
domain: ops
tier: standard
effort: medium
status: merged
scope: [docs/patterns/09-outside-door-mcp.md, docs/patterns/10-brand-and-theming.md, docs/patterns/11-voice-input.md, docs/patterns/12-right-rail.md, docs/patterns/13-write-actions.md, tests/test_pattern_pages.py]
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

Brain review, 2026-11-17. Worker attempt 1 (sonnet) consistent, accepted as handed back.

- Read the whole diff: the six sequence blocks on pages 09 to 13 use the theme page snippet; step lists renumbered and cover 1..N once (page 09: 10 and 10; page 10: 7; page 11: 10; page 12: 15; page 13: 19); class and prompt names moved into the steps. No test changes were needed. Privacy grep of the added lines: 0 hits.
- Viewed every block on the pushed branch on GitHub (dark): phases, coral model calls and step badges read cleanly; the last badge on page 10 sits next to the pan and zoom buttons but is not covered.
- Gate green (unit suite, check-docs).
