---
id: OPS-36
title: FR2: the README as a GTM workbook for Customer Summary — repositioned as a branded, swappable accelerator with three surfaces, voice and actions, linking the captures OPS-52 took; a Status table every page links; a quick start that does not need the agent
domain: ops
tier: frontier
tier_reason: the public face of the repo, written for a seller and an architect at once, with every claim tied to a tracked source
status: merged
fixes: []
scope: [README.md, tests/test_readme_fr2.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/patterns/**, docs/assets/**, docs/ARCHITECTURE.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_readme_fr2.py fails on main (the README says Account Brief, has no FR2 surfaces, no principles section and no 'Runs without the agent' status row) and passes after
gate: test
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): the repo is now an accelerator other teams "take ... to other users, other use cases", that a seller can "grab ... spin up" and swap for a prospect, with one branded agent "consumed by MCP" and surfaces that "aren't competing". The README must read like a GTM, outcome-driven workbook for each pattern, as Ben asked for the original burn. Covers ledger rows F01, F02, F04, F06, F14 (privacy line), F28, F34 and F43 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/reviews/fr2-build-review.md (its open findings are listed in the README's limits, not hidden; its e2e and agent-check counts, with their date, go in the proof table), docs/ARCHITECTURE.md as OPS-49 left it, docs/patterns/README.md (the index OPS-48 wrote) and every page it lists, docs/research/fr2-quick-start-change.md (OPS-44), docs/research/fr2-captures.md (OPS-52: the captures by file name), docs/research/fr2-ladder.md (OPS-46: the ladder's output) and docs/assets/MANIFEST.md. Load the skill experience-lwc:experience-accessibility-validate (for alt text) first
- README.md: opens with the outcome for a seller and a service rep in two sentences and a hero GIF; then who it is for, the three surfaces (compact, rail, embedded as a labelled placeholder) and when to use each, the skills (summary, ask anything, act), voice with the one-line privacy note that Chrome sends audio to Google to transcribe it, the brand swap in five steps linking pattern 10, the MCP door's status, the quick start, the pattern workbook table (each pattern's business outcome, what it proves, its page), the proof table with today's test counts, and limits. Uses 'Customer Summary' throughout; old names appear only where a historical doc is linked. The workbook table follows the index page docs/patterns/README.md: the same titles in the same order. The proof table links docs/reviews/fr2-build-review.md. The headings 'See it in 5 minutes' and 'Status' keep those exact words, because pages and cards link them. The quick start deploys every folder under force-app/main/default except the agent bundle, and tests/test_readme_fr2.py compares the folders the quick start names with the folders on disk. The MCP line follows page 09: if page 09 says the org still runs the door under the old names (OPS-31 waits on its own approval), the README says so too
- **Status table:** under the 'Status' heading, the table keeps its other rows up to date and has one row for each claim a page may link, with these first cells: 'A run as a non-admin user', 'A real MCP tool call', 'A clean install from "See it in 5 minutes"', 'Runs without the agent', 'The microphone in Chrome' and 'VoiceOver'. A row reads 'not yet proven' unless a tracked file in this repo records the run that proves it. This card changes no row on its own judgement; OPS-28 and OPS-53 change rows later
- Diagrams: Mermaid sequence diagrams for ask-from-the-rail, a write action with draft and confirm, and the MCP door; a component diagram of the shared core and its three frames. Each follows fr2-design.md 'Diagrams' and copies the theme block from docs/patterns/_diagram-theme.md. They render on GitHub: use the render check written up in that file (the one the chapter cards use) and say so in the hand-back
- Images: link the captures OPS-52 took (docs/research/fr2-captures.md lists them by file name), each with alt text. Add, change or remove no file under docs/assets/. Run nothing in the org: this card has no org access
- Counts in the proof table come from tracked files, each with its date and a link: docs/reviews/fr2-build-review.md for the e2e and agent-check counts, and docs/research/fr2-ladder.md for the ladder. Run no e2e suite here. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
- **Ways in (ledger F82 to F84):** the README never presents the built-in Agentforce panel or "Ask the agent" as a way in. The pattern list drops 06 from the patterns and lists it as an optional appendix; the diagram has no built-in panel edge. The quick start no longer needs an agent publish: move it to the appendix as an optional step, as docs/research/fr2-quick-start-change.md (OPS-44) sets out; the Status row 'Runs without the agent' reads 'not yet proven' until OPS-28's run passes. Say it plainly: this is Agentforce, with its own surfaces
- **Why custom (ledger F66):** the README's first screen has a short "Why not just the standard chat?" with two or three lines and a link to docs/patterns/00-why-custom.md (OPS-41) (OPS-49 links it from ARCHITECTURE.md). Chapter 00 comes first in the README's list of patterns
- **Design principles (ledger F85 to F87):** a short README section lists the five principles in fr2-design.md, one line each. Trust is principle 5 and links page 07 ("Trust by design", OPS-45), not a chapter: the pattern list shows 07 as a reference page, not a pattern. Granting access is one line in the quick start (assign the group); the Status row 'A run as a non-admin user' reads 'not yet proven' until FE-5 has passed. Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven
- **Step 4 (OPS-30):** the README's step 4 says the group deploy and its assignment are not part of the recorded run in agent-probe. That is now stale: OPS-30 deployed the group `Customer_Summary_User` and assigned it to the admin (docs/research/fr2-rename-org.md). Say so, and link that page
- **Testing (ledger F88 to F92):** the proof table adds the ladder's one-line-per-rung output from docs/research/fr2-ladder.md (OPS-46), and the Testing Center counts only if docs/research/fr2-testing-center.md exists (BE-38 waits on its own approval); if it does not, that row reads 'not run in this build', and the quick start ends with "run the checks: npm run ladder"

## Review

Brain review (2026-11-14). One attempt (46fac35, $3.59).
- Its sonnet review returned 30 confirmed, 1 refuted and 3 unverifiable. The refuted row was the hand-back's wording, not the README: the hand-back said outside evidence is cited only as "a production Agentforce build we reviewed", but the README cites no outside build at all, which the card allows.
- Nothing in the README needed to change, so the brain did not resume the worker and skipped the advisor. It re-judged the same commit with a verify run ($0.36), which returned 13 confirmed, 0 refuted and 3 unverifiable.

Findings:
- README.md is rewritten as the FR2 workbook for Customer Summary. It opens with the outcome for a seller and a service rep and the hero GIF fr2-readme-hero.gif, and says "This is Agentforce, with its own surfaces".
- "Why not just the standard chat?" links chapter 00.
- Three surfaces: the compact window and the right rail each have a still (fr2-01-summary-compact.png, fr2-01-summary-rail.png), and the embedded surface is a labelled placeholder linking page 14.
- The skills: Summary ("Up to 4 model calls"), Ask anything (eight curated objects), and Act (draft, then Confirm).
- Voice, with the line that Chrome sends the audio to Google's servers to transcribe it.
- The brand swap in five steps, linking page 10.
- The MCP door follows page 09: it runs under the Customer Summary names, the first door is still active, and the runbook's undo section and the Status table are linked.
- The five design principles, with trust linking page 07.
- Three sequence diagrams (ask from the rail, a write action as draft then Confirm, the MCP door) and one component flowchart. Each has the shared theme line, and each sequence diagram uses autonumber. No diagram has a built-in panel edge.
- "See it in 5 minutes" deploys every metadata folder on disk except the agent bundle. The worker found that OPS-44's list left out customMetadata, genAiPromptTemplates, reportTypes and the outcome permission set. It also loads 107 sample records, assigns Customer_Summary_User in one line, says OPS-30 assigned the group to the admin, and ends with "Then run the checks: npm run ladder".
- The workbook table has 15 rows copied from docs/patterns/README.md (titles, order and kind).
- The Proof table has dated counts from fr2-build-review.md and the ladder lines from fr2-ladder.md, copied verbatim. The Testing Center row reads "not run in this build", and the e2e report still is described as a run cut at 560 s (30 passed, 12 not run).
- The Status table has the six claim rows, each "Not yet proven".
- Limits: M1 to M5, L1 to L12, the render check not run (OPS-61), OPS-54, the unbuilt embedded surface, BE-28 and the voice browser limits.
- The old brief-flow.gif and e2e-report.png links are gone.
- New tests/test_readme_fr2.py has 33 tests (red: 30 failures before the change). It checks the workbook against the index, the quick-start folders against disk, the Status rows, the diagrams' theme and autonumber, and that the old name appears nowhere, including in alt text.

Gate (verifier at 46fac35): Python 390 tests, 4 skipped. Worker and reviewer: check-docs 74 pages, 0 broken.

Org: none. This card had no org access.

Disclosed and accepted:
- The diagrams are not render-checked. The brain told the worker not to run the Mermaid CDN check; the README's limits say so, and OPS-61 (parked) holds it.
- The brain opened the hero GIF's frames and both stills when OPS-52 merged; the alt text matches.
- docs/assets/MANIFEST.md and docs/research/fr2-captures.md still list README.md under "Old, still linked" for brief-flow.gif and e2e-report.png. Both files are outside this card's scope.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- The render check for the README's four diagrams (OPS-61).
- Update the "Old, still linked" rows in MANIFEST.md and fr2-captures.md now that the README no longer links the old frames.
- The clean-install and runs-without-the-agent Status rows wait on OPS-28.
- docs/research/fr2-quick-start-change.md's folder list is narrower than the README's.

Privacy check over the full branch diff (793 added lines): 0 denylist hits; no URLs, Ids, org alias, emails or local paths (the one "/Users/" hit is the test's own assertion that the README has none).
