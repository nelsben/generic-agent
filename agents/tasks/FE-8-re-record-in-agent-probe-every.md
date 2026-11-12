---
id: FE-8
title: Re-record in agent-probe: every panel asset is recaptured on the seeded sample data, the two built-in agent slots are captured from the active version, and every caption says exactly what its image shows
domain: frontend
tier: frontier
tier_reason: live-browser capture with privacy masking, visual judgement and the built-in agent panel
status: queued
fixes: [FE-7]
scope: [docs/assets/**, e2e/capture/**, README.md, docs/patterns/**]
forbid: [force-app/**, tests/**, scripts/**, data/**, e2e/panel.spec.js, e2e/global-setup.js, e2e/support/**, playwright.config.js, playwright.capture.config.js, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none
gate: test, jest
budget: 2-attempts
spend: 40
---
## Why

The current assets came from experimental. They show a platform user's name as account owner and a real company's brand in the explorer rows. The built-in agent slots are empty because no current version could be activated there. After the move (OPS-25), agent-probe has made-up sample data and, if the publish worked, an active version with the current script. This card re-records everything there and makes each caption true.

## Done when

- Read first: docs/research/org-migration.md, docs/assets/MANIFEST.md, e2e/README.md (Capture section), e2e/capture/*.js, docs/patterns/01-route-gather-reduce.md, 02-ask-anything-explorer.md and 06-agent-routing-and-verbatim-relay.md, and README.md. If org-migration.md does not say that the e2e run passed in agent-probe, stop and hand back
- Run captures with SF_TARGET_ORG=agent-probe. Never sign in, log out, deploy, publish or activate; never touch experimental; never install a plugin even if a hook suggests one; never print tokens or frontdoor URLs. Keep the existing privacy machinery (masking, the 0.5 s checks, the 1 fps by-eye frame read). At most three full capture runs and about 40 model calls
- Framing fixes in e2e/capture: panel-brief.png shows the brief's headline sentence and the top of the sections. explore-answer.png shows the question, the one-line answer and the top of the table, or the caption says what it shows instead. brief-flow.gif ends on a settled frame that shows the headline
- Agent slots: if org-migration.md records an active version with the current script, capture agent-brief.png (the built-in Agentforce panel in the Account Brief app answering 'Brief me on Edge Communications') and agent-explore.png (an org-wide count question), with the same masking. Then add both back to MANIFEST.md and to page 06 with true captions. If there is no such version, or the panel cannot be driven within 30 minutes of effort, leave them out and say why in one sentence in MANIFEST.md
- No frame shows a real company brand, a platform-provisioned user's name, the running user's name, an email, a 15/18-character Id, a URL bar, a token or URL_Redacted. Read every PNG and every 1 fps frame plus the last frame of every GIF, and list what you read
- Update MANIFEST.md (status, pixel and file sizes). Make every caption and alt text in README.md and docs/patterns that names one of these assets say only what the image shows. Remove the page 06 sentence about missing screenshots if the slots are captured
- Gates pass: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and npm run test:unit; bash scripts/check-docs.sh reports 0 broken; leave no tests/__pycache__/; e2e/.auth/, test-results/, playwright-report/ and raw videos are not committed; git status --short is empty after your commit. Hand-back: each asset with its pixel and file size, and the test-results .last-run.json paths
