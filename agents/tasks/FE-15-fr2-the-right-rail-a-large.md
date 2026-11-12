---
id: FE-15
title: FR2: the right rail — a large Claude-like surface on Cmd/Ctrl-Shift-K that pushes the page left (or slides over it), with session history, open deals, recent activity, cases and the last summary beside the shared conversation; hover and minimize; expand from compact keeps the thread
domain: frontend
tier: frontier
tier_reason: new primary surface with page-level layout behaviour, speed budgets, e2e and GIF capture in a live org
status: blocked
blocked_by: [FE-12, FE-13, OPS-29, BE-25, BE-26]
fixes: []
scope: [force-app/main/default/lwc/customerSummaryRail/**, force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/flexipages/**, force-app/main/default/applications/**, force-app/main/default/messageChannels/**, e2e/**, docs/patterns/12-right-rail.md, docs/assets/fr2-rail*]
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
- A new LWC customerSummaryRail, mounted the way the spike recommended, opens on Cmd/Ctrl-Shift-K, on the launcher's expand and on the compact window's expand. It is 480 to 640 px wide, pushes the page left if the spike proved that works and otherwise slides over it with a soft shadow; the docs say which and why. It can be minimized to a slim edge tab and, if the spike found hover workable, opens on hover of that tab after a short delay. Esc closes; focus moves in and back
- Layout: the shared customerSummaryConversation fills the main column; a context column or collapsible sections show open deals, recent activity (with emails, calls and case comments, each with its kind), open cases and the last summary from CustomerSummaryContext, and a sessions list from CustomerSummaryHistory that reopens a past conversation. Context loads in parallel with opening (prefetch on hotkey press) and shows skeletons, never a blank block. Clicking a deal, case or activity opens that record. Expand from the compact window opens the rail on the same session with no lost turns
- Speed and feel: the rail's first paint is under 300 ms after the key press and the context lists fill within 1.5 s on agent-probe with a warm cache in Playwright; record both numbers. Motion per fr2-design.md, reduced motion respected, comfortable spacing per the design brief. Everything themed by the --cs-* variables
- Jest covers the hotkey, open from expand with a session id, push vs overlay class, minimize and hover, each context list including empty and error states, sessions reopen, and zero jest-axe violations; LWS validation reports no blocked API. e2e: open by hotkey, open by expand with the thread intact, ask one question in the rail, and check each context section renders. Write docs/patterns/12-right-rail.md (who it is for, how it opens, push or overlay and why, what it prefetches, speed budget, history visibility per F32). Capture docs/assets/fr2-rail-open.png, docs/assets/fr2-rail-context.png and a short docs/assets/fr2-rail.gif (open, ask, expand from compact) at 1440x900; read every GIF frame. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
