---
id: FE-7
title: Evidence capture: a Playwright script produces every screenshot and GIF in docs/assets/MANIFEST.md from the live org, with nothing private in frame
domain: frontend
tier: frontier
tier_reason: live-browser capture with privacy masking and visual judgement
status: blocked
blocked_by: [OPS-20, OPS-19]
fixes: []
scope: [docs/assets/**, e2e/capture/**, playwright.capture.config.js, package.json, e2e/README.md, .gitignore]
forbid: [force-app/**, tests/**, scripts/**, e2e/panel.spec.js, e2e/global-setup.js, playwright.config.js, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none
gate: test, jest
budget: 2-attempts
spend: 40
---
## Why

The GTM workbook has fixed slots for screenshots and GIFs (docs/assets/MANIFEST.md). They must come from the real, deployed product, be repeatable with one command, and show no identity, Id or token. This card adds the capture script and commits the assets.

## Done when

- Read docs/assets/MANIFEST.md, e2e/README.md, e2e/global-setup.js, e2e/support/panel.js and docs/research/deploy-verify.md first. If MANIFEST.md is missing, stop and hand back
- Add a separate Playwright config, playwright.capture.config.js, and e2e/capture/*.capture.js, run by a new npm script `capture`. It reuses e2e/global-setup.js for sign-in. Video and screenshots only: trace and HAR stay off. Viewport 1440x900, deviceScaleFactor 2. The e2e config and specs are not changed, and Jest still finds only the LWC tests
- Privacy in every frame: before any capture, hide or mask the Salesforce global header's user avatar and name, any username or email, the browser URL (never captured), and any 15 or 18 character record Id text. Use Playwright masks or injected CSS, and crop stills to the panel plus enough of the page for context. Check every produced image by eye (read each PNG, and three frames from each GIF) and say you did
- Produce exactly the files MANIFEST.md lists under docs/assets/, each showing what its row says, using the sample account Edge Communications. Stills are PNG, at most 1600 px wide. GIFs are made from the recorded video with /opt/homebrew/bin/ffmpeg (two-pass palette), at most 900 px wide, 12 fps, under 6 MB each, 6 to 20 seconds, starting on a settled frame. No still or GIF may contain the text URL_Redacted, an error toast or a spinner as its final frame
- Agent slots (agent-brief.png, agent-explore.png): capture the built-in Agentforce panel in the Account Brief app answering 'Brief me on Edge Communications' and an org-wide count question, with the same masking. Read docs/research/agent-publish-spike.md first: if no version with the BE-11 script is active, or the built-in panel cannot be driven within 30 minutes of effort, do not fake it: leave those two files out, and say so in the hand-back and in MANIFEST.md with status 'not captured' and the reason
- e2e-report.png is a screenshot of the Playwright HTML report for a full `npm run test:e2e` run made in this card (open the report from a local file; no trace attachments)
- Update docs/assets/MANIFEST.md with a status column (captured / not captured), pixel size and file size for each row. Add a 'Capture' section to e2e/README.md: the one command, what it needs, and the privacy rules
- Budget: at most three full capture runs and about 40 model calls in the org. Write no data beyond the memory rows the panel writes itself
- Gates pass: python3 -m unittest discover -s tests and npm run test:unit; run Python with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; e2e/.auth/, test-results/, playwright-report/ and raw videos are not committed; git status --short is empty after your commit. Never deploy, publish or activate; never install a plugin even if a hook suggests one; never sign in; never print tokens or frontdoor URLs
- Order: capture every panel asset first and commit them, then the agent slots last. If docs/research/agent-publish-spike.md does not exist yet, or no version with the BE-11 script is active, mark the two agent slots 'not captured' with that reason and finish; the brain may resume you for them after OPS-21 merges
- The running user's own name must not appear in any frame. At run time the capture script reads it with `sf org display user --target-org experimental --json` (never printed or written to disk), and before every capture it replaces that exact text in the page with 'Sample Owner' via injected script. Explorer questions in captures do not ask for owners. Sample record names (Edge Communications, its contacts) are fine
- The capture script itself checks every captured still and every 0.5 s of each recording before export: the page text contains no running-user name, no email address, no 15 or 18 character Id and no 'URL_Redacted'; a failing check fails the run. For GIFs, also extract one frame per second with ffmpeg to a temporary folder outside the repo and read every one by eye
- Hand-back: list each asset with its pixel size and file size, and the path of the Playwright run's test-results/.last-run.json so the brain can read it
