---
id: OPS-60
title: FR2: page 00 names the right rail as built (FE-15 merged) — steps, Say column and Limits say what ships, and its test checks the rail is described as built
domain: ops
tier: standard
tier_reason: two-file docs and test edit with every wording decision named in the card
effort: low
effort_reason: mechanical docs edit against a merged source page
status: queued
fixes: [OPS-41]
scope: [docs/patterns/00-why-custom.md, tests/test_pattern_00.py]
forbid: [force-app/**, e2e/**, scripts/**, agents/**, docs/plans/**, docs/patterns/12-right-rail.md, docs/patterns/03-hotkey-panel.md, docs/patterns/_diagram-theme.md, docs/ARCHITECTURE.md, docs/assets/**, README.md, .chassis-delegation.json, reference/**]
red_test: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_pattern_00 — the new test that page 00 links 12-right-rail.md and names the rail in the Say column fails on main and passes after
gate: test
budget: 2-attempts
spend: 10
---
## Why

OPS-41 wrote page 00 while the rail was still queued, so the page and tests/test_pattern_00.py call the rail planned, list "there is a rail" as do-not-say, and say the compact window's expand stays off. FE-15 merged the rail (customerSummaryRail, page 12) with expand on, so page 00 now understates the product and its test pins the stale claim.

## Done when

- docs/patterns/00-why-custom.md names the right rail as built, in plain words that match docs/patterns/12-right-rail.md: a full-height sheet that slides over the page (not pushing it), opened by Cmd/Ctrl-Shift-K, by Expand in the compact window, or by the expand button beside the launcher; the same conversation moves between the compact window and the rail, so the thread is kept; the rail shows Open deals, Recent activity, Open cases and Last summary beside the conversation. It links page 12.
- Every sentence that calls the rail planned, queued or FE-15's future work is gone: the Ask step (near line 155), the paragraph near line 207, the Do-not-say cell near line 216, and the Limits item near line 261. The sentence that the compact window's expand stays off is gone, since expand is on.
- The Say / Do not say table gains one Say row about the rail that page 12 supports (for example that a rep can expand the same conversation into a larger rail with the account's deals, activity, cases and last summary beside it). "The standard panel has no hotkey or history" stays do-not-say. No Say cell claims the rail pushes the page, has a sticky header, or has been tested with a screen reader.
- Limits keeps only true items. If page 12 lists rail limits (for example its diagram not render-checked, rail spec 1's cold-open flake), page 00 may point to page 12 for them rather than repeating them.
- The page's Mermaid diagram is unchanged unless a participant or step text calls the rail planned; if a step is changed, the numbered steps under the diagram still match its messages one for one, and the shared init line is byte-identical.
- tests/test_pattern_00.py: test_limits_name_the_rail_as_planned_under_fe_15 and test_never_presents_the_rail_as_built_in_the_steps_or_the_say_column are replaced by tests that the page links 12-right-rail.md, names the rail in the Say column, and contains none of the words "planned" or "FE-15" within the same sentence as "rail". pattern_shape.check_page still runs and passes.
- PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes, and bash scripts/check-docs.sh reports 0 broken links; the hand-back gives both counts.
- Do not run the Mermaid CDN render check (the product owner has not said whether loading Mermaid from a CDN is allowed). No org, deploy or e2e run is needed or allowed.
- No person's name, Id, username, email, hostname, local path or client name is added.
