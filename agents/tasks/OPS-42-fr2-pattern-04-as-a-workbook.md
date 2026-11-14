---
id: OPS-42
title: FR2: pattern 04 as a workbook chapter — "API first" for prompts told plainly (why the Models API instead of prompt templates, the trade-off, when a template still fits), a restyled numbered diagram, limits named with their cards, and a builder's guide to changing context and tuning prompts
domain: ops
tier: frontier
tier_reason: a chapter that argues a design choice to business readers and teaches builders a new way of working, from Ben's own notes
status: merged
fixes: []
scope: [docs/patterns/04-model-provider-seam.md, docs/guides/models-api-prompts.md, tests/test_pattern_04.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_04.py fails on main (pattern 04 has no business problem on prompt templates, no autonumber, and the guide does not exist) and passes after
gate: test
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 04. Prompt templates "require a lot of overhead"; the Models API lets a team "accelerate very fast and not be hung up on prompt template details". It "doesn't offer a UI, which is a kind of a trade-off". An "API-first approach of models API makes the most sense, especially since it's easier to vibe out" with Claude or another AI app, while teams that need a template can still use one. He wants that conversation on the page, a better numbered diagram, limits explored with cards, and a guide on "how to update context for your prompt call out", "what it means to use the models API, how to use it, how to tune your prompt", "since we're taking away prompt templates". Covers ledger rows F67 to F73 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F67 to F73 and the decision on prompt templates), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape', 'Diagrams'), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), docs/research/fr2-model-door.md (BE-33), docs/research/fr2-summary-accuracy.md (BE-29), docs/research/fr2-sentiment.md (BE-36: one focused call through the door) and the AgentLlm classes and prompt files as BE-33 left them
- **The chapter**, following the page shape, with its exact H2 headings in its order ('The business problem', 'The architecture in a few steps', 'How it works', 'See it', 'Why you can trust it', 'How it scales', 'Adopt it', 'Limits and open items'); 'The decision' is this page's own extra part. **Header:** the pattern's name and one line: every model call through one door, prompts as files a team can change in minutes. **The business problem:** prompt templates add a build layer (the builder UI, versions, merge fields, activation) and what the builder sees is not the whole request that reaches the model; teams slow down. Use BE-33's research for exactly what the trust layer and template resolution do, so nothing is overstated. **The decision:** API first, as fr2-design.md principle 3 states it, with the trade-off said plainly (no point-and-click UI; prompts live in files and code) and **when a template still fits** (an admin team that edits prompts without deploys, a governance rule, an existing template library), with the per-prompt switch from BE-33 as the way to use one. If docs/research/fr2-model-door.md says BE-33 stopped at the tested seam (no live template run), say exactly that: the switch is tested with a stub, not against a live template. **The architecture in a few steps:** name a prompt, load its settings, fill it, send it, cap and check, return
- **How it works:** the diagram restyled per fr2-design.md 'Diagrams' (autonumber; phase blocks for prepare, call and return; one accent colour for the model call; both sources shown, the static resource path and the opt-in template path). The numbered steps under it use the same numbers. Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back
- **See it:** the output of scripts/prompt-try.apex for one prompt, as a text block with names and Ids removed. No image: that is this page's exemption in fr2-design.md
- **The builder's guide**, docs/guides/models-api-prompts.md, linked from the chapter's Adopt it: what the Models API is and how a call is made here; where a prompt's context comes from (the gather step) and how to add or change it (a field, a section, a cap) with a worked example; how to tune a prompt (the system and user parts, the tone line, rules, examples, length, the model) and try it in a minute with scripts/prompt-try.apex and the prompt trace; how to check accuracy (BE-29's check); what each call costs in usage; how to switch one prompt to a template and back; and how to work on prompts with Claude or another AI app (paste the file, the trace and a failing answer, ask for a change, try it)
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **Prompt name (OPS-30):** the summary's synthesis prompt is now the static resource `AgentPrompt_SummarySynthesis`, not `AgentPrompt_BriefSynthesis`, which stays in the org only for the old code (docs/research/fr2-rename-org.md, "The fix"). Write the new name wherever this page names the synthesis prompt
- **Why you can trust it** opens with the two trust lines fr2-design.md 'Pattern page shape' fixes: one starting 'Runs as the signed-in user:' and one starting 'System context:', which names each system-context use on this path with its reason, or says 'none on this path'. In it and in **How it scales**, each claim links to a test, a review or a recorded run. **Limits and open items:** each named in plain words with the card that has it by id (BE-33, BE-29) or "no card yet", never a link to a card file, including what BE-33 leaves open. Uses Customer Summary names throughout. tests/test_pattern_04.py calls the shared helper tests/pattern_shape.py (from OPS-38), passing the parts this page has and the extra parts it adds; the helper checks the headings in order, autonumber on every mermaid sequence diagram, the theme block and the two trust lines, and adds its own checks: that the decision and "when a template still fits" are present, and that the guide exists with its sections and is linked. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Two attempts.
- Attempt 1 (939f4a8, $4.34 with one advisor call): the verifier found the report consistent. A sonnet review returned 21 confirmed, 1 refuted and 4 unverifiable. The refuted row: the page said only the summary's own cap marks a cut, but ExploreAction.composeRows ends an over-long answer on "...". Two clauses had no repo source: "the platform adds its own generation settings" and the guide's "before the Trust Layer masks anything". The brain resumed the worker to fix all three.
- Attempt 2 (08072ba, $1.27): the page and the guide only. A sonnet review returned 16 confirmed, 0 refuted and 2 unverifiable. The unverifiable rows are the red run's scratchpad setup and the advisor line.

Findings:
- docs/patterns/04-model-provider-seam.md is rewritten to the shared chapter shape, "Model provider seam". It has the eight fixed parts, with an extra part, "The decision", after The business problem. The decision is API first (fr2-design principle 3), with the no-UI trade-off, "When a template still fits", and the per-prompt Source__c switch.
- The page says the template switch was run live once as an admin and set back (BE-33). The rep case is open (FE-5).
- Its 13-step diagram uses the shared theme. It has Prepare, Call and Return phases, one coral block around the model call, and the two sources as alt branches. The steps under it cite the same numbers.
- The page names three answer cuts, feature by feature. The door cuts at max tokens times 4 characters with no marker (AgentLlm). The summary cuts over 5,900 characters and adds its "Cut short" marker. The explorer cuts over 5,900 characters and ends on "...".
- Business problem: the template call carries the application name and the maximum length beside the template. When masking is on in Setup, the Trust Layer masks personal and payment data and scores toxicity on both paths, as fr2-model-door.md records.
- "System context:" names one use, the Agent_Prompt_Setting__mdt read. All 25 cited test names exist, and the numbers (six setting records, token limits, caps, the 90 s sentiment budget) match the code.
- New docs/guides/models-api-prompts.md, "Working with Models API prompts", has nine sections in the card's order. Its worked example, adding Opportunity.Type to deal history, is marked "Example, not shipped code". It links both ways with the chapter.
- New tests/test_pattern_04.py runs pattern_shape.check_page plus 15 page-specific checks.

Gate (verifier at 08072ba): 202 Python tests, 1 skipped. The reviewer ran check-docs: 66 pages, 0 broken.

Org (worker's account), under the approved live-checks row: one run of the unmodified scripts/prompt-try.apex in agent-probe (BriefDealHistory, sample 1). It made 1 model call and wrote no record (12 sessions before and after), with no deploy and no setting change. Its TRY| lines are the See it block. The brain read the pasted reply: it has no Id, account name or person name, only seed-data deal amounts and generic deal descriptions.

Disclosed and accepted:
- In attempt 1 the worker ran the Mermaid render check from _diagram-theme.md, which loads Mermaid from a CDN in Chromium. It printed FAIL on the broken sample and ok on pages 04 and 01 and on the theme example. The permission policy refused the same script twice for OPS-38. Whether workers may run it is put to Ben; until he answers the brain does not direct it.
- The guide-word test skips when PATTERN_GUIDE_WORDS is unset (the 1 skip). The brain's denylist grep over the diff found no hits, and "landscape", "confidential" and "proprietary" do not appear.
- The summary's cut falls back to the last space when no sentence or line end is found; the page leaves out that edge.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- docs/research/fr2-model-door.md and the scripts/summary-accuracy.apex header still say four setting records and 3 model calls per summary; the tree has six and 4.
- _diagram-theme.md's "For the next card that tries" paragraph still asks for the run that has now been done.
- A GitHub light and dark render check of the Mermaid blocks, owed by OPS-36.

Privacy grep over the diff (692 added lines): 0 hits.
