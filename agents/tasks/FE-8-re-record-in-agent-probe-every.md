---
id: FE-8
title: Re-record in agent-probe: every panel asset is recaptured on the seeded sample data, the two built-in agent slots are captured from the active version, and every caption says exactly what its image shows
domain: frontend
tier: frontier
tier_reason: live-browser capture with privacy masking, visual judgement and the built-in agent panel
status: merged
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

## Review

Two worker attempts and one fix by the brain. Accepted after one review pass and the brain's own reading of the fix.

- Attempt 1 recaptured all 13 assets in agent-probe. The capture kit now masks the running user's first and last name as whole words and checks every frame. The worker asked for an amend into force-app/** to fix the panel layout, which leaves about 139 px for the conversation. That was refused and cut as its own card, FE-10. The worker reported gate=fail when it meant the layout deliverable was unmet; the gate was green. The e2e/README.md amend was granted.
- Attempt 2 was docs only. It updated the e2e README Capture section, page 06 (agent-probe publish, 12 of 12, the case 7 quirk, limits), pages 03 and 08, and the README status rows. It also removed the second-hand plan-notes claims.
- Review of attempt 2 found 21 confirmed, 1 refuted and 2 unverifiable. The refuted row: page 06 still said "none of it is live" in the present tense. The reviewer also noted that the 8 of 8 lines did not say spec 2 is intermittent in agent-probe.
- Brain fix 705bb4a: page 06 now places the re-review's "not live" and "Not ready" in the first org, in the past tense. README, page 03 and page 08 now say the first agent-probe run passed 7 of 8 and that spec 2 has failed now and then since, cause not found.
- Of the two unverifiable rows, the first was the stray tests/__pycache__. A gate run recreated it after the commit, and it was removed before merge. The second was the GIF alt texts. The brain extracted the last frame of each GIF and read it: brief-flow ends on its headline, hotkey-open ends minimized to the utility bar, and explore-drill ends on the table. All three match their alt text.
- Images checked by eye: agent-brief, agent-explore, panel-brief, explore-answer and the three GIF end frames. Each shows "Sample Owner", "email hidden" and (555) phones, with no Ids or brand names. They do show the cramped panel layout, which FE-10 fixes and recaptures.
- Gates: test (72) and jest (36) pass at 705bb4a. check-docs passes: 29 pages, 0 broken. Privacy grep of the 327 added lines: 0 deny-list hits, 0 Salesforce-shaped Ids, 0 emails, 0 instance hosts, 0 query-string URLs, 0 home paths.
- Review of the fix (attempt 3): 15 confirmed, 0 refuted, 4 unverifiable. The unverifiable rows are the GIF frames (read by the brain, above), the capture run counts (no log in the tree), the first org's publish failure (recorded in docs/research), and an exhaustive count of 8 of 8 lines.
