---
id: OPS-22
title: Final GTM pass: the workbook matches tonight's evidence, every link, image and diagram works, and nothing private is in the repo
domain: ops
tier: frontier
tier_reason: final truth and privacy check of the public face of the repo
status: blocked
blocked_by: [FE-7, OPS-16, OPS-17, OPS-18]
release_note: the brain may set this card queued if FE-7 cannot run tonight
fixes: []
scope: [README.md, docs/patterns/**, docs/ARCHITECTURE.md, docs/assets/MANIFEST.md, docs/plans/corrective-plan.md, scripts/check-docs.sh, docs/research/agent-api.md, docs/research/agent-publish-failure.md, tests/test_agent_bundle.py, force-app/main/default/classes/AccountBriefCallsSection.cls, agents/tasks/BE-2-three-flex-prompt-templates-for-the.md, agents/tasks/BE-3-deals-open-deals-with-who-s.md, agents/tasks/BE-4-people-and-engagement-contacts-task-activity.md, agents/tasks/BE-5-account-profile-and-service-health-cases.md, agents/tasks/BE-7-account-brief-employee-agent-in-agent.md, agents/tasks/CRO-2-ask-anything-drill-into-anything-a.md, agents/tasks/FE-1-custom-panel-cmd-ctrl-k-utility.md, agents/tasks/OPS-6-live-probe-call-the-account-brief.md, agents/tasks/OPS-7-live-probe-create-an-inactive-custom.md, agents/tasks/OPS-9-find-why-sf-agent-publish-authoring.md]
forbid: [force-app/**, tests/**, e2e/**, agents/**, docs/reviews/**, docs/research/**, docs/plans/gtm-burn-plan.md, .chassis-delegation.json]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

The workbook was written before the deploy, the publish spike, the captures and the re-reviews finished. This last pass makes every claim match what actually happened tonight and checks the repo the way a first-time visitor on GitHub would see it.

## Done when

- Read README.md, every docs/patterns page, docs/assets/MANIFEST.md, docs/research/deploy-verify.md, docs/research/agent-publish-spike.md, docs/research/studio-preview.md and the three docs/reviews/*-review-2.md files first
- Truth pass: every 'proven' statement in README.md and the pattern pages points at a test, a review or a recorded run that exists and says what the page claims. Update the README status table and each page's 'Why you can trust it' and 'Limits and open items' from tonight's results: the e2e score, the agent test results, whether the CLI publish worked, which agent version is active, each re-review's verdict and its open blockers or should-fix findings. Anything not run stays under 'Not yet proven'
- Asset pass: every image link resolves to a committed file; a slot whose asset is 'not captured' in MANIFEST.md is removed from its page and replaced by one honest sentence. Read every PNG and three frames of every GIF and confirm no name, email, username, record Id, URL bar, token or the text URL_Redacted is visible; list what you checked
- Link and diagram pass: every relative link in README.md and docs/ resolves (write a small check, do not add it to the repo unless it is under scripts/check-docs.sh and under 40 lines); every Mermaid block parses with `npx --yes @mermaid-js/mermaid-cli@11` writing to a temporary folder outside the repo
- Privacy pass over the whole tracked tree (git ls-files): no Salesforce record or org Ids (15 or 18 character Ids starting 001, 003, 005, 006, 00D, 0Xx and similar, except the obvious fake 001000000000000AAA), no email addresses or usernames, no tokens, no URLs with query strings, no my.salesforce.com hostnames. Also grep the tracked tree for every line of the untracked file /Users/bennelsen/Documents/generic-agent/reference/denylist.txt (the main checkout; read that one file for this purpose only, never quote it) and report only the count of hits and their file paths
- Read-through as a business reader: the README makes sense top to bottom without opening another file, and each pattern page's first screen says the outcome in plain words. Fix wording that fails that test. Do not add claims
- docs/plans/corrective-plan.md: add a dated status block saying what tonight finished and what is still open
- Gate passes: python3 -m unittest discover -s tests with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; git status --short is empty after your commit. Never touch the org, never install a plugin even if a hook suggests one. In the hand-back list anything you could not fix inside scope
- Scrub, inside the extra scope files only: reword each deny-list hit and replace each real org-specific Id with an obvious fake (for example 001000000000000AAA, 0Xx000000000000AAA). Change only comments and prose; in tests/test_agent_bundle.py change only Id literals and keep the tests passing. Comment-only change in AccountBriefCallsSection.cls; do not deploy. If the Assets pass finds a slot 'captured' whose file is missing, treat it as 'not captured'
