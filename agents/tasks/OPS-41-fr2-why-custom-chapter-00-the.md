---
id: OPS-41
title: FR2: "why custom" as chapter 00 — the case for bringing our own surfaces and cards instead of only Agentforce's standard chat, for the teams who sell and build it, with the architecture of the why and every claim backed by a measurement or a public doc
domain: ops
tier: frontier
tier_reason: the argument the whole GTM story rests on, written for sellers and architects at once, and fair to the platform
status: merged
fixes: []
scope: [docs/patterns/00-why-custom.md, tests/test_pattern_00.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_pattern_00.py fails on main (the page does not exist) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's note on the hotkey panel and every surface: "really articulate the why behind us bringing in a custom architecture and view to all of these panels and going custom instead of standard Salesforce and Agentforce". His reasons: the standard launcher "doesn't scale", "there's soft limits for how many characters", and "teams decelerate when trying to incorporate lightning cards into the responses". It is "a note that we need to make sure we communicate to our teams", with "the architecture of the why". On pattern 06 he added: "this is agent force, it's just a different skinned version of it". Covers ledger rows F66 and F84 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (F60 to F66 and the decision on where "why custom" lives), docs/plans/fr2-design.md ('Operating principles', 'Pattern page shape', 'Diagrams'), docs/research/fr2-standard-limits.md (BE-32), docs/research/fr2-card-architecture.md (FE-18), docs/patterns/01-route-gather-reduce.md as OPS-38 left it (match its voice and its theme block from docs/patterns/_diagram-theme.md), docs/patterns/03-hotkey-panel.md and 06-agent-routing-and-verbatim-relay.md, docs/research/fr2-card-contract-apex.md (BE-39), the conversation component as FE-22 left it, and the generic restatement in fr2-design.md ('Lessons from a reviewed build'). Cite that source only as "a production Agentforce build we reviewed", never by name, client, agent or class
- Follow the page shape with its exact H2 headings in its order; page 00 has no 'See it', 'Why you can trust it', 'How it scales' or 'Adopt it' part (the exemption fr2-design.md names). **Header:** "Why custom" and one line: this is Agentforce (the same platform, models and trust layer), with surfaces and cards we control. It is a different skin, not a rival, and the page never argues about whether it counts as Agentforce. **The business problem**, in plain words a seller can repeat: the agent rewrites a formatted answer's layout even when told to keep it (BE-32: 6 of 6 summaries lost their label lines); teams cap their own actions to stay under a limit nobody has measured (ours stops at 5,900 characters, so the agent showed 36 of 47 rows where our panel showed 47); each agent turn is slower (BE-32: 13 to 33 s against 5 to 9 s on the direct path for the same question); a card in the standard chat needs a custom Lightning type, an Apex action and the right output setting, and a misnamed type falls back to plain text with no error, so teams spend build cycles on cards; every follow-up becomes a new build (link pattern 02). Each point carries its number from BE-32 or a public doc link. State each limit plainly with its number, or "not measured" with BE-32's reason. Never use a number from the reviewed build, and use no adjectives about the platform
- **The architecture of the why:** two short diagrams per fr2-design.md 'Diagrams' (autonumber, phase blocks, one accent colour for model calls). First, the standard path: launcher, the agent's model step re-writes the action's answer (where the layout is rewritten and the turn slows), a card only if the action's output setting names a Lightning type. Second, ours: the surface calls the Apex services directly, the answer and its cards come from one typed contract as built (BE-39 in Apex, FE-22 in the conversation; describe what was built, not what FE-18 proposed) and render every time. MCP uses the same services: say exactly what an MCP client receives, from docs/research/fr2-card-contract-apex.md. Numbered steps under each diagram use the same numbers
- **What BE-32 found (merged 2026-11-13), and how to say it:** the agent relayed every table whole up to 5,811 characters, the most any existing action returns, in 18 of 18 runs; above 5.9k it is unmeasured. Never claim a measured character ceiling or that long answers are cut by the platform: the only cut seen was our own cap. Where the standard launcher lives, its size, a hotkey, history and branding are unproven (no public doc, not opened in a browser): say only what our surfaces add, and mark anything about the launcher as unproven. Each figure links docs/research/fr2-standard-limits.md
- **What changes for a team:** no caps tuned to an unmeasured limit, cards that always render, follow-ups without new builds, one place to brand. **When the standard chat fits:** a short section from BE-32's list. Keep it: it is what makes the page fair. **Limits and open items**, each named in plain words with the card that has it by id or "no card yet", never a link to a card file (for example the custom code a customer now maintains). Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven
- **Page rules (fr2-design.md 'Pattern page shape'):** the H1 is the title with no number. The H2 headings are the exact strings listed there, in that order, less the parts it exempts this page from; a part of this page's own is an extra H2 between them, and the page's test lists it. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md), the one place that is changed when a run passes. It names roles, not people. A limit names the open item in plain words (it may give a card id) and never links a card file
- **Why not Coworker (added by the brain, 2026-11-13):** one short paragraph, no new H2, that links docs/research/fr2-coworker-spike.md. Say three things and no more: Salesforce documents no in-org call to Agentforce Coworker and no way to place its UI in our page; the documented extension model is the other way round (our agent, and its Lightning type cards, can show inside Coworker's UI through delegation, not Coworker's UI inside ours); and whether an agent may be a way in when the door is Coworker is Ben's decision under ledger F83, which stands. Quote no price, licence or edition from the spike page; link it instead
- Every diagram renders on GitHub; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back. tests/test_pattern_00.py calls the shared helper tests/pattern_shape.py (from OPS-38), passing the parts page 00 has, and adds its own checks: that every number in the business problem has a link on the same line, and (from an env-var word list, never committed) that no reference-guide name appears. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Two attempts.
- Attempt 1 (3688009, $1.97): the verifier found the report consistent. A sonnet review returned 14 confirmed, 1 refuted and 4 unverifiable. The refuted row: the page presented the right-hand rail as built, but the rail is FE-15 and still queued. The brain resumed the worker to fix it.
- Attempt 2 (4d5aed9, $0.42): the page and its test only. A sonnet review returned 12 confirmed, 0 refuted and 3 unverifiable. The unverifiable rows are the check-docs count (the brain then ran it: 66 pages, 0 broken), the worker's account of rewriting red-2.txt, and the GitHub render.

Findings:
- docs/patterns/00-why-custom.md is the "why custom" chapter in the shared chapter shape. It makes the case for our own surfaces and cards and draws the two paths.
- Built surfaces named as built: the compact window on Cmd-K or Ctrl-K, with past conversations behind its History button and one place to brand, and the MCP door. The rail is named only as planned (FE-15), in the Ask step, the measured part, the Do-not-say column and a new Limits item. The compact window's expand stays off until the rail ships.
- The diagram's participant is "Compact window"; its 9 messages match steps 1 to 9. The shared init line is untouched.
- The Say / Do not say table keeps "the standard panel has no hotkey or history" as do-not-say (unproven).
- The page says "the product owner's decision", not a person's name.
- tests/test_pattern_00.py runs pattern_shape.check_page plus page checks; attempt 2 adds two: Limits names FE-15, and neither the architecture steps nor the Say column mention the rail.

Gate (verifier at 4d5aed9): 204 Python tests, 2 skipped. Brain: check-docs 66 pages, 0 broken.

Disclosed and accepted:
- Card item not met: "Every diagram renders on GitHub; check each with the render check". The brain told the worker not to run the Mermaid CDN render check until Ben says whether loading Mermaid from a CDN in Chromium is allowed. The page's Limits list says the diagrams have not been render-checked.
- The guide-word test skips when PATTERN_GUIDE_WORDS is unset (the skips). The brain's denylist grep over the diff found no hits, and "landscape", "confidential" and "proprietary" do not appear. The only URLs are three public Salesforce developer docs pages with no query string.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- When FE-15 merges, page 00 should describe the rail as built (for OPS-40 or OPS-36), and OPS-48 should check page 14's rail wording.
- A GitHub light and dark render check of the Mermaid blocks, owed by OPS-36.

Privacy grep over the diff (408 added lines): 0 hits.
