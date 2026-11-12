---
id: OPS-36
title: FR2: the README as a GTM workbook for Customer Summary — repositioned as a branded, swappable accelerator with three surfaces, voice and actions; every screenshot, GIF and sequence diagram recaptured; Ben's page notes applied
domain: ops
tier: frontier
tier_reason: the public face of the repo, with live captures and Ben's page notes to judge
status: blocked
blocked_by: [OPS-35, OPS-32, OPS-31, BE-28, OPS-38]
fixes: []
scope: [README.md, docs/ARCHITECTURE.md, docs/assets/**, docs/patterns/**, e2e/capture/**, tests/test_readme_fr2.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (docs and assets): before the card the README says Account Brief and has no FR2 surfaces; after, a test in tests/test_readme_fr2.py checks the sections, the privacy line, the diagrams and that every linked asset exists
gate: test
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2): the repo is now an accelerator other teams "take ... to other users, other use cases", that a seller can "grab ... spin up" and swap for a prospect, with one branded agent "consumed by MCP" and surfaces that "aren't competing". The README must read like a GTM, outcome-driven workbook for each pattern, as Ben asked for the original burn. Covers ledger rows F01, F02, F04, F06, F14 (privacy line), F28, F34, F42 and F43 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (including every F42 note Ben has added by dispatch time; each one is applied or answered in the review note), docs/plans/fr2-design.md, docs/reviews/fr2-build-review.md (its open findings are listed in the README's limits, not hidden), docs/ARCHITECTURE.md and docs/patterns/*.md. Load the skill experience-lwc:experience-accessibility-validate (for alt text) first
- README.md: opens with the outcome for a seller and a service rep in two sentences and a hero GIF; then who it is for, the three surfaces (compact, rail, embedded as a labelled placeholder) and when to use each, the skills (summary, ask anything, act), voice with the one-line privacy note that Chrome sends audio to Google to transcribe it, the brand swap in five steps linking pattern 10, the MCP door's status, the quick start, the pattern workbook table (each pattern's business outcome, what it proves, its page), the proof table with today's test counts, and limits. Uses 'Customer Summary' throughout; old names appear only where a historical doc is linked
- Diagrams: Mermaid sequence diagrams for ask-from-the-rail, a write action with draft and confirm, and the MCP door; a component diagram of the shared core and its three frames. They render on GitHub (check with the GitHub markdown API or a local Mermaid render)
- Assets: recapture in agent-probe with Playwright at 1440x900 the hero GIF, the compact window, the rail with context, a draft card, the brand swap before and after, and voice in its recording state (stubbed recognizer); read every GIF frame; old assets that no page links are removed. Alt text on every image
- Run the full e2e suite and bash scripts/agent-check.sh once more and put the counts in the proof table. Org, agent-probe only, read-only apart from records the e2e suite creates and removes; never deploy, publish, create a user or touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
- Pattern pages: only their image links and alt text change here, to point at the recaptured assets. Their text and diagrams belong to the chapter cards (OPS-38 for pattern 01). Every diagram the README adds follows fr2-design.md 'Diagrams' and copies the theme block from docs/patterns/_diagram-theme.md
- See it on every pattern page (ledger F57, fr2-design.md 'Pattern page shape'): for each pattern, capture it on each surface where it runs (compact window, rail, Agentforce's panel; the MCP door as a client transcript image), a GIF where something moves, read every frame, and set alt text. The pattern pages' See it sections link these captures
