---
id: OPS-52
title: FR2: captures and the See it part of every page — an exact capture list per page and per surface, every still and GIF taken through the capture kit from the live org, each with alt text; no deploy and no settings change
domain: ops
tier: frontier
tier_reason: a capture run against a live org across three surfaces, where every image must be read for private data before it is committed
status: merged
fixes: []
scope: [e2e/capture/**, docs/assets/**, docs/patterns/**, docs/research/fr2-captures.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, agents/**, docs/plans/**, docs/reviews/**, docs/ARCHITECTURE.md, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (captures): before this card the 'See it' parts link FR1 images of a panel that no longer exists; after, every image a pattern page links is listed in docs/research/fr2-captures.md and in docs/assets/MANIFEST.md, and bash scripts/check-docs.sh reports 0 broken
gate: test
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): Ben asked for "playwright screenshots with frontend validation" and, with the new surfaces, "in the see it section, we want to record or highlight and capture images for each see it" (ledger F43 and F57). As first cut the README card owned every capture, with the org lock, a brand flip in the org and no list of what to take (findings 10 and 23 in docs/reviews/fr2-plan-review.md). This card takes the captures on their own, from a list written first, and changes nothing in the org.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", take no capture and hand back. When it is approved: use existing seed-data accounts, say in the hand-back which ones, and record how many session and outcome rows the run wrote
- Read first: docs/plans/fr2-design.md ('Surfaces' and 'Pattern page shape'), docs/patterns/README.md (the index) and the 'See it' part of every page it lists, e2e/README.md, e2e/capture/kit.js, e2e/capture/privacy.js, the capture scripts under e2e/capture/ and docs/assets/MANIFEST.md. Load the skill experience-lwc:experience-accessibility-validate (for alt text) first
- **Write the list first.** docs/research/fr2-captures.md starts as the capture list, before any capture is taken: for each page, each file with its surface (compact window, right rail), viewport, what it shows and its alt text. At least: 01, a summary with its cards in the compact window and in the rail, a GIF of the ask and the answer arriving, and the not-found and several-matches lines; 02, an explorer answer with a table card on both surfaces and a drill GIF; 03, a GIF of the hotkey opening the compact window, minimize, and expand to the rail with the thread kept; 05, a follow-up answered from context, a past session reopened, and the outcomes timeline with the sentiment chart; 08, the end-to-end report; 10, BE-24's before-and-after captures, reused and not retaken; 11, the mic button in the composer (the recording state only if it shows without a stubbed recognizer; if not, the page says it is checked by hand); 12, the rail pushing the page, with its side column; 13, a draft card, and a result card only if the row "FR2: e2e and agent tests that create a record" starts with "approved" (the task and its outcome are removed afterwards); and for the README, one hero GIF (hotkey, ask, a summary with cards, expand to the rail) and one still per surface. Pages 00, 06, 07 and 14 get no capture. Pages 04 and 09 get a text block and no image: on 09 it is the unauthenticated call, labelled 'not a real tool call'
- **Capture.** Every still and GIF is taken through e2e/capture/kit.js and checked with e2e/capture/privacy.js; new capture scripts go under e2e/capture/ and old ones that drive a surface that no longer exists are removed. Look at every PNG and at one frame per second of every GIF before committing it: reject any that shows the running user's name, a username, an email, an Id, a URL bar, an error toast or a raw API name. Use only existing sample data and outcomes written by real summaries. Never insert or backdate a record for a capture; show the empty state instead. No deploy, no settings change, no brand flip and no record edit in the org: the brand before-and-after is BE-24's capture
- **The pages.** Only the 'See it' part of each page under docs/patterns/ changes: it links the new captures with their alt text, one per surface where the pattern runs on both, and a GIF where something moves. Nothing else on a page changes, and every page's own test and tests/test_pattern_pages.py still pass. New files are named docs/assets/fr2-*.png or fr2-*.gif. Never delete or rename an image that README.md, docs/ARCHITECTURE.md or a page under docs/research/ or docs/reviews/ still links: list those in the research page under 'Old, still linked', for OPS-36 to replace in the README. An old image nothing links any more may be removed
- docs/assets/MANIFEST.md lists every image with what it shows, the page that uses it, its pixel size and its file size. docs/research/fr2-captures.md ends as the record: the final list with each file's page, surface, viewport and alt text, the date of the run, the rows the run wrote, anything that could not be captured and why, and an 'Undo' list of what the run left in agent-probe. OPS-36 takes the README's images from this page by file name
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only: read-only apart from the product's own session and outcome rows, and the one task under its own row as above. Never deploy, publish or activate anything, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Three attempts.
- Attempt 1 (5a2f6c5 on 63034eb): $9.11. Its sonnet review returned 26 confirmed, 1 refuted and 7 unverifiable. The refuted row was a hand-back number, not the work: the red count was given as 6 unlisted images, but the commits show 17, then 9. The brain skipped the advisor because the fix was one number and one docs file.
- Amends: the brain granted e2e/README.md. It declined README.md, which OPS-36 owns, and declined tests/**, so the old FR1 frames the chapter tests pin stay for a follow-up card.
- Attempt 2 (aa2059e): $0.28. It rewrote e2e/README.md's Capture section and wrote red-2.txt over git-archive exports: 17 unlisted at 69bb1b2, 9 at 63034eb and 0 at 5a2f6c5. Its sonnet review returned 15 confirmed, 2 refuted and 3 unverifiable, and the budget was spent. The two refuted rows were README sentences: only script 13 fails the run when it cannot frame a turn, and script 10's model call was left off the list of writers. The brain checked both against the scripts, raised the budget to three and skipped the advisor for a two-sentence wording fix.
- Attempt 3 (f62e9b4): about $0.00. It fixed both sentences. Its sonnet review returned 9 confirmed, 0 refuted and 0 unverifiable.

Findings:
- 28 images added or retaken under docs/assets: the fr2-01, fr2-02 and fr2-05 stills, fr2-03-hotkey.gif, fr2-08-e2e-report.png, the fr2-11 mic stills, the action-draft stills (window and rail), and the compact, history and rail stills. Also fr2-rail.gif and the README hero fr2-readme-hero.gif.
- The See it parts of pages 01, 02, 03, 05, 08, 09, 11, 12 and 13 link the new captures. Page 09's See it part is a text block with `<my-domain>` and `<org-path>` placeholders.
- docs/assets/MANIFEST.md and docs/research/fr2-captures.md list every capture, with old frames still linked under "Old, still linked".
- Capture scripts 13 to 17 added; the utility-panel scripts 01 to 04 and 08 removed. e2e/README.md's Capture section names the new scripts, the model calls (four in all: two from 13, one from 15, one from 10), and which scripts check the framing.

Gate (verifier at f62e9b4): Python 341 tests, 4 skipped. Worker and reviewer: check-docs 73 pages, 0 broken.

Org (worker's account, attempt 1 only): no deploy. Customer_Outcome__c rows went from 90 to 104 (14 added by the summary captures and the e2e run). Session rows stayed at 16 and Task rows at 11. About 22 model calls. The action cards stopped at Cancel; no record was created.

Disclosed and accepted:
- The brain opened all 22 PNGs and contact sheets of the 5 GIFs: seed data only ("Sample Owner", "email hidden", 555 numbers, example.com), no address bar, no Id, username, email or hostname.
- The e2e report still shows a run cut by its 560 s limit: 30 passed, 12 not run. Page 08 says so.
- No "Listening" still for page 11 (the state did not show without a stub; the page says it is checked by hand). No result card on page 13 (creating a record is not approved).
- The diagrams were not render-checked. The brain told the worker not to run the Mermaid CDN check; OPS-61 (parked) holds it.
- The 10-rail script's header still says nothing is written to the org; its question does write a session row. The README is right; the header comment is stale.
- A tests/__pycache__ made by the gate runs was removed before each review and before merge.

Still open:
- README.md links (OPS-36): the hero GIF fr2-readme-hero.gif and one still per surface, fr2-01-summary-compact.png and fr2-01-summary-rail.png. After that, the old brief-flow.gif and e2e-report.png links can go.
- The old FR1 frames pinned by test_pattern_01, 02, 03 and 05 (not-found.png, ambiguous.png, explore-answer.png, explore-drill.gif, drill-view.png, hotkey-open.gif, panel-sections-open.png). A card that owns tests/ can drop them, and let page 05 link the FE-19 history stills.
- Rendering issues seen in the new frames: an "EMPTY" badge on the follow-up card, the rail table cutting off its Close column, the chip row clipped ("Create a foll"), History open by default in the rail, and no focus ring on the rail mic.
- The 10-rail header comment.

Privacy check over the full branch diff at f62e9b4 (891 added lines, images excluded): 0 denylist hits; no URLs other than the placeholder MCP path, no Ids, local paths or job Ids.
