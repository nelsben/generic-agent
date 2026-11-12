---
id: FE-10
title: The panel's answers get the room: the pinned bar above the conversation is at most 80 CSS px, so at 340x480 the scroll box shows a brief's headline and its first section headers together; deployed to agent-probe and every asset recaptured
domain: frontend
tier: frontier
tier_reason: UI layout judgement, a production-classified deploy, and a full privacy-masked recapture read by eye
status: blocked
blocked_by: [BE-16]
fixes: []
scope: [force-app/main/default/lwc/accountBriefPanel/**, e2e/panel.spec.js, e2e/support/panel.js, e2e/capture/**, e2e/README.md, docs/assets/**, README.md, docs/patterns/**]
forbid: [force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, tests/**, scripts/**, data/**, agents/**, docs/plans/**, docs/research/**, .chassis-delegation.json, reference/**, playwright.config.js, playwright.capture.config.js]
resources: [org-live]
red_test: the new e2e assertion (pinned bar at most 80 CSS px, scroll box at least 240 CSS px at 340x480 after one brief) fails on the current panel in agent-probe
gate: test, jest, org
budget: 2-attempts
spend: 40
---
## Why

FE-8 found that in the 340x480 utility panel the pinned bar takes about 185 CSS px: the Brief button, "Ask the agent", "Sections: all" and "Earlier briefs", each on its own row. The conversation box is left with about 139 px. A brief's headline and its sections can't be on screen together, and an explore answer can't show its question and its table at once. A GTM-ready panel has to show the answer. This is also the last recording pass, after BE-16 changes the agent, so every asset ends up matching the final build.

## Done when

- Read first: force-app/main/default/lwc/accountBriefPanel/ (html, css, js and __tests__), e2e/panel.spec.js, e2e/support/panel.js, e2e/README.md, e2e/capture/*.js, docs/assets/MANIFEST.md, and the FE-8 notes in docs/research/org-migration.md and the FE-8 card's Review section
- Layout: Brief and Ask the agent sit on one row. If both labels do not fit at 340 px, the Brief button's visible label may shorten, but its accessible name stays 'Brief <Account name>', because e2e finds it by that name. 'Sections' and 'Earlier briefs' no longer take a full row each. Either they share one compact row, or they move to the top of the scroll box and scroll away. Record which in the hand-back, with the reason. Their behaviour is unchanged: the include chips and the history list still work, are keyboard-reachable and are announced
- Measured: with the panel open at 340x480 on Edge Communications, after one brief, the area from the panel header's bottom edge to the top of the scroll box is at most 80 CSS px, and the scroll box is at least 240 CSS px tall. An e2e assertion in e2e/panel.spec.js checks both numbers. Spec 4's pinned-composer check still passes
- Jest: the existing tests pass, and new ones cover the changed bar. npm run test:unit passes
- Deploy only force-app/main/default/lwc/accountBriefPanel to agent-probe. The org is production-classified, so validate first (RunLocalTests), then quick deploy, with CONFIRM_PROD=1 relaying Ben's standing approval for agent-probe deploys. Never publish or activate an agent, never sign in or log out, and never touch experimental
- e2e: one full npm run test:e2e in agent-probe passes all specs, axe spec 8 included. If spec 2 flakes on focus, as FE-9 recorded, rerun it once and report both results
- Recapture every asset in docs/assets/ with npm run capture (SF_TARGET_ORG=agent-probe), at most three full runs: the panel PNGs and GIFs, e2e-report.png and the two agent slots, so they match the build after BE-16. panel-brief.png shows the headline and at least the first two section headers. explore-answer.png shows the question, the one-line answer and the table header. Keep all the privacy machinery: masking, the 0.5 s checks, the all-frames checks and the 1 fps by-eye frame read. Read every PNG and GIF frame by eye, and list in the hand-back what each one shows
- MANIFEST.md, README.md and docs/patterns/** captions and alt text match the new images exactly. Any sentence about the 139 px framing limit is removed
- About 40 model calls at most. No Ids, usernames, emails, hostnames or tokens in any file or image
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
