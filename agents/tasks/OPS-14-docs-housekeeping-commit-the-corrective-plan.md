---
id: OPS-14
title: Docs housekeeping: commit the corrective plan (updated for the reviews) and the telemetry write-up, scrub org and agent Ids, ignore jsconfig.json
domain: ops
tier: standard
tier_reason: mostly mechanical, but the plan rewrite needs care to keep its rules and structure
status: merged
fixes: []
scope: [docs/plans/corrective-plan.md, docs/research/telemetry-off.md, docs/research/agent-publish-failure.md, .gitignore]
forbid: [force-app/**, scripts/**, tests/**, agents/**, reference/**, .chassis-delegation.json, docs/reviews/**, docs/ARCHITECTURE.md]
red_test: none (docs only)
gate: test
budget: 2-attempts
spend: 10
---
## Why

Two working docs sit untracked in the main checkout, so workers can only read them by absolute path: the corrective plan and the telemetry write-up. The plan is also out of date now that the plugins are installed and three peer reviews have landed. One committed research doc still carries the org Id and an agent Id. The LWC review recommends ignoring the editor-generated jsconfig.json.

## Done when

- Copy <repo>/docs/plans/corrective-plan.md and <repo>/docs/research/telemetry-off.md (untracked in the main checkout, absent from your worktree) into the same paths in your worktree, then commit them. Read both before committing; neither may contain an API key, access token, email address, org Id or user Id. If one does, remove it and say so in your hand-back
- docs/research/agent-publish-failure.md no longer contains the org Id (starts 00D) or the agent Id (starts 0Xx). Replace them with '<org id>' and '<agent id>'. `grep -nE '00D[A-Za-z0-9]{12,15}|0Xx[A-Za-z0-9]{12,15}' -r docs` prints nothing
- corrective-plan.md is updated, keeping its structure and its four rules. Step 2 is marked done (plugins salesforce-development, agentforce-adlc, experience-lwc and integration installed on 2026-11-11; Python is 3.15). Add a short section 'Peer review (2026-11-11)' linking docs/reviews/apex-review.md, lwc-review.md and agent-review.md (all sound with fixes) and naming the follow-up cards: BE-9 (agent fixes on top of BE-8, plus scripts/agent-check.sh), BE-10 (Apex top six plus bulk and multi-request tests) and FE-3 (LWC fixes plus Jest). Step 1a now runs its Studio preview against BE-9's script, using the branch list BE-9 hands back. BE-8 is superseded by BE-9, which contains its commits. Step 3's agent-workflow card and LWC test card are covered by BE-9 and FE-3, the test-spec move is closed (the skill does not require it), and the docs scrub is this card. The Apex hygiene card stays and also takes the Apex review findings 7 to 10 and its nits. Note under 'Waiting on Ben' that /opt/homebrew/bin/sf (2.130.9, an npm global under Homebrew's node) shadows /usr/local/bin/sf (2.157.8) on PATH, and remove the plugin-install item. Remove the line saying the file is untracked
- .gitignore gains the line **/lwc/jsconfig.json, and `git check-ignore force-app/main/default/lwc/jsconfig.json` succeeds
- Docs only: change no code, script, test, card or config file. No client names and no content from reference/. Gate passes: `python3 -m unittest discover -s tests`, run with PYTHONDONTWRITEBYTECODE=1, leaving no tests/__pycache__/. `git status --short` is empty when you report

## Review

Brain read the diff: plan updated as specified, Ids scrubbed (also in agent-api.md under a disclosed amend), jsconfig ignored, telemetry doc and plan committed with no secrets or personal data. The brain added one commit: the agent and jest gates in .chassis-delegation.json, needed by BE-9 and FE-3.
