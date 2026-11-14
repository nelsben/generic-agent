---
id: FE-15
title: FR2: the right rail — a large Claude-like surface on Cmd/Ctrl-Shift-K that pushes the page left (or slides over it), with session history, open deals, recent activity, cases and the last summary beside the shared conversation; hover and minimize; expand from compact keeps the thread
domain: frontend
tier: frontier
tier_reason: new primary surface with page-level layout behaviour, speed budgets, e2e and GIF capture in a live org
status: merged
fixes: []
scope: [force-app/main/default/lwc/customerSummaryRail/**, force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/flexipages/**, force-app/main/default/applications/**, force-app/main/default/messageChannels/**, e2e/**, docs/patterns/12-right-rail.md, docs/assets/fr2-rail*, tests/test_app.py]
forbid: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest suite for customerSummaryRail fails on main (the component does not exist) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2): "a full experience that feels like Claude built into or overlaying Salesforce", hidden until a seller or service rep hits a key, then "pushes the content from the right-hand side of the screen to the left" (sliding over is acceptable if pushing is impossible), showing history and prefetched context, "comfortable, not too tight", "streamlined ... fast and feeling fluid". Covers ledger rows F19 (history in the rail), F24 (the large half), F25, F26, F27, F28, F29, F30, F31, F32 (display), F33, F34 and F35 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (all), docs/research/fr2-surfaces-spike.md (push vs slide-over, hover, minimize, hotkey, where the rail is mounted), docs/research/fr2-rail-context.md, docs/patterns/03-hotkey-panel.md and docs/patterns/05-conversation-memory.md. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate, salesforce-development:platform-flexipage-generate and salesforce-development:platform-metadata-deploy first
- A new LWC customerSummaryRail, mounted the way the spike recommended, opens on the hotkey docs/research/fr2-surfaces-spike.md recommends (Cmd/Ctrl-Shift-K unless the spike found a clash), on the launcher's expand and on the compact window's expand. It is 480 to 640 px wide, pushes the page left if the spike proved that works and otherwise slides over it with a soft shadow; the docs say which and why. It can be minimized to a slim edge tab and, if the spike found hover workable, opens on hover of that tab after a short delay. Esc closes; focus moves in and back. The rail header shows the brand logo, the agent name and the rail's key hint
- Layout: the shared customerSummaryConversation fills the main column; a context column or collapsible sections show open deals, recent activity (with emails, calls and case comments, each with its kind), open cases and the last summary from CustomerSummaryContext, and the sessions list that reopens a past conversation, which is FE-22's control shown open in the rail (do not build a second one). Context loads in parallel with opening (prefetch on hotkey press) and shows skeletons, never a blank block. Clicking a deal, case or activity opens that record. Expand from the compact window opens the rail on the same session with no lost turns. Use only existing sample data and outcomes written by real summaries. Never insert or backdate a record for a capture; show the empty state instead
- Speed and feel: the rail's first paint is under 300 ms after the key press and the context lists fill within 1.5 s on agent-probe with a warm cache in Playwright; record both numbers. Motion per fr2-design.md, reduced motion respected, comfortable spacing per the design brief. Everything themed by the --cs-* variables
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Jest covers the hotkey, open from expand with a session id, push vs overlay class, minimize and hover, each context list including empty and error states, sessions reopen, and zero jest-axe violations; LWS validation reports no blocked API. e2e: open by hotkey, open by expand with the thread intact, ask one question in the rail, and check each context section renders. Tag one spec for FE-21's smoke subset (the tag is in e2e/README.md). Paste the Playwright summary line in the hand-back. tests/test_app.py follows any change to the app or its utility bar. Write docs/patterns/12-right-rail.md (who it is for, how it opens, push or overlay and why, what it prefetches, speed budget, history visibility per F32). Capture docs/assets/fr2-rail-open.png, docs/assets/fr2-rail-context.png and a short docs/assets/fr2-rail.gif (open, ask, expand from compact) at 1440x900; read every GIF frame. Every still and GIF is taken through e2e/capture/kit.js. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Three attempts; the brain raised the budget from 2 to 3.
- Attempt 1 ($10.07): the worker stopped while its own validate-org job ran in the background, with no report (no-report). The brain resumed it to wait for the job and report.
- Attempt 2 (f7b1e47, $3.87): the verifier found the report consistent. A sonnet review returned 19 confirmed, 3 refuted and 7 unverifiable. Refuted: a "sticky account header" on narrow screens that was not built; a check-docs count of 68 (it is 69); and page 12's captions claiming all four context sections were visible in the stills. After one advisor call the brain raised the budget, granted the docs/ARCHITECTURE.md amend, and resumed the worker for docs-only fixes, with no force-app change, deploy, e2e, recapture or render check.
- Attempt 3 (c3b1340, ~$0.10): docs only. A sonnet review returned 19 confirmed, 0 refuted and 3 unverifiable. The unverifiable rows are the absence of job Ids in earlier commits (the brain's grep over the full branch diff found none), the GIF content (the brain read the stills and five sampled GIF frames), and the local gate-lease hook.

Findings:
- New LWC customerSummaryRail: a full-height sheet, clamp(480px, 46vw, 640px) wide, that slides over the page rather than pushing it. Push only works by moving Salesforce's private .viewport element (fr2-surfaces-spike).
- It opens three ways: Cmd/Ctrl-Shift-K, Expand in the compact window, and a new expand button beside the launcher on the corner side.
- One conversation instance moves between the compact window and the rail, so Expand keeps the session. The FE-22 History list shows open in the rail.
- The context column has Open deals, Recent activity (with kind badges), Open cases and Last summary, with skeletons while the hotkey prefetch loads. At 1040 px or less it folds under the conversation. There is no sticky header.
- Minimize leaves a 28 px edge tab. Hovering on it for 350 ms opens a peek, which slides back 400 ms after the pointer leaves.
- Esc closes the rail and returns focus to where it was. Reduced motion is honoured, and colours come from the --cs-* tokens.
- A context row opens its record through a cancelable railopenrecord event that the panel handles, because the stage the panel moves onto document.body is out of reach of the page's navigation. That body move predates FE-15.
- The utility bar flexipage turns expandEnabled on, and tests/test_app.py matches. Header icon buttons are 12 px apart for WCAG 2.2 target size.
- New docs/patterns/12-right-rail.md. Page 03 now says expandEnabled is on. MANIFEST has rows for the three captures, and ARCHITECTURE.md links page 12.
- New Jest suite for the rail, with jest-axe. e2e gains rail.spec.js. The e2e README now says 34 tests and 9 smoke tests.

Gate (verifier at c3b1340): 232 Python tests, 2 skipped; Jest 7 suites, 309 tests; validate-org pass (148 components, 425 tests). Reviewer: check-docs 69 pages, 0 broken.

Org (worker's account), under the standing deploy row: three scoped validate-with-RunLocalTests and quick-deploy pairs in agent-probe (rail, panel and flexipage, then two fix rounds for the rail and panel). The last validate ran 518 tests with 0 errors. No agent was published or activated. The worktree's .sf target-org was set for the deploy hook, then unset.

E2E and speed (worker's account): rail specs 1 to 6, panel specs and hotkey-platforms pass on mac and windows. Rail 1 failed once on a cold open after a deploy and then passed 3 of 3; page 12 notes it as a flake. Warm medians: first paint 14 ms (mac) and 12 ms (windows) against 300 ms; context filled 286 ms and 387 ms against 1.5 s.

Disclosed and accepted:
- Page 12's diagram is not render-checked. The brain told the worker not to run the Mermaid CDN check until Ben answers.
- The captures show seed data only ("Sample Owner", "email hidden"), with no Id, username, email or hostname. The brain read both stills and five GIF frames.
- The only Ids in the diff are synthetic test Ids (000000000001AAA form). The deploy job Ids from the hand-back are in no committed file.
- tests/test_pattern_12.py is left for OPS-48.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- Page 00 and tests/test_pattern_00.py describe the rail as planned and say not to claim it. They must be updated now that it is built (follow-up card).
- The conversation component's own View-record link may do nothing inside the body-mounted stage. This is untested and predates FE-15; it needs a follow-up card with one e2e click.
- The "Earlier summaries of <account>" heading still truncates (FE-26).

Privacy grep over the full branch diff (2,919 added lines): 0 denylist hits, no job Ids, no local paths.
