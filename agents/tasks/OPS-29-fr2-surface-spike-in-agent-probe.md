---
id: OPS-29
title: FR2: surface spike in agent-probe — which utility-bar corner, whether a custom rail can push the page left, both hotkeys, the launcher and the mic, proven with a throwaway spike app
domain: ops
tier: frontier
tier_reason: live-org spike with judgement on Lightning layout limits, hotkeys and LWS behaviour
status: parked
fixes: []
scope: [spikes/surface/**, sfdx-project.json, tests/test_sfdx_project.py, docs/research/fr2-surfaces-spike.md, docs/assets/fr2-spike-*.png, docs/assets/MANIFEST.md, e2e/capture/**]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none (spike: research page and throwaway spike package; tests/test_sfdx_project.py is widened to allow the spikes entry)
gate: test
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2) puts Customer Summary on a compact window and a large right rail. Ben wants a spike to decide the corner (without competing with a call-centre softphone in the utility bar), whether the rail can push page content left or must slide over, and two hotkeys that Chrome on Mac does not reserve. Covers ledger rows F20, F21, F25, F26, F30, F35 and the mic part of F13/F14 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/patterns/03-hotkey-panel.md, the accountBriefPanel LWC (its hotkey and focus code) and force-app/main/default/flexipages/Account_Brief_UtilityBar.flexipage-meta.xml. Load the skills experience-lwc:experience-lwc-generate, salesforce-development:platform-flexipage-generate, salesforce-development:platform-custom-application-generate and salesforce-development:platform-metadata-deploy before writing metadata or running sf commands
- Spike code lives only under spikes/surface/. Add one non-default package directory with path 'spikes' to sfdx-project.json (the way mcp-door is added), so every FR2 spike can live in its own subfolder of spikes/, and widen tests/test_sfdx_project.py's exact package-directory check to allow it. It holds one throwaway LWC (surfaceSpike) and its own Lightning app 'FR2 Surface Spike' with its own utility bar, so the demo app and its utility bar are not changed. Nothing in force-app/ changes
- Corner: find out from Salesforce docs and the live org whether utility bar items or the bar can sit on the right, where an Open CTI or Service Cloud Voice softphone sits in the utility bar and how items stack with it, and whether a floating launcher fixed to the bottom right (position fixed from a utility-bar background component or the utility item) works and does not cover the softphone. Recommend bottom left or bottom right, with the evidence
- Rail: try, in this order, and record what works, with a screenshot of each that works: (a) a component that pushes the record page content left (for example a docked utility panel, the console's split view, a record page template with a collapsible right column, or any documented way); (b) a sheet fixed to the right edge that slides over the page with a backdrop; (c) a hover-over and a minimized state. Say plainly whether pushing is possible for a custom LWC, and which option the rail card should build
- Hotkeys: prove in Chrome on Mac (Playwright's Chromium in agent-probe, plus the published Chrome and Lightning shortcut lists for Windows) that Cmd/Ctrl-K and Cmd/Ctrl-Shift-K reach a document keydown listener in the spike component on a record page and an app page, are not reserved by Chrome on Mac, and collide with no Lightning keyboard shortcut. If one fails, pick a replacement that passes the same checks and record why
- Launcher: show that a visible launcher with the key hint (for example 'Ask Customer Summary ⌘K') can sit in the chosen corner and that the hidden-until-pressed behaviour works
- Mic: in the deployed spike component, record whether window.SpeechRecognition or webkitSpeechRecognition exists under Lightning Web Security, and what start() does in Playwright's Chromium (with and without the fake media flags). Record whether automated Chromium can produce any transcript; expected: it cannot, so voice is tested with Jest plus a manual check
- Org, agent-probe only, under the standing approval for production-classified deploys: validate the spikes/surface package with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Assign nothing to other users, never sign in or out, never create a user, never touch experimental. Leave the spike app deployed and list it in the research page under 'Undo' (removal is Ben's call)
- Write docs/research/fr2-surfaces-spike.md: each question, what was tried, the evidence, the recommendation for the compact corner, the rail mode (push or slide over, plus hover and minimize), the two hotkeys and the mic test approach. Screenshots go in docs/assets/fr2-spike-*.png through the e2e/capture kit with its privacy machinery, read by eye, with MANIFEST.md rows
- No record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings in any file or image. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
