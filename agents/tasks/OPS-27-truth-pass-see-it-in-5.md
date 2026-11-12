---
id: OPS-27
title: Truth pass: "See it in 5 minutes" follows the order that worked in agent-probe, the proof table says exactly what a fresh org proved, and the superseded research pages say so at the top
domain: ops
tier: standard
tier_reason: docs-only truth pass against named evidence pages
status: merged
fixes: []
scope: [README.md, docs/patterns/**, docs/research/org-migration.md, docs/research/agent-publish-spike.md]
forbid: [force-app/**, e2e/**, tests/**, scripts/**, data/**, agents/**, docs/assets/**, docs/plans/**, docs/reviews/**, docs/research/agent-iteration-1.md, docs/research/deploy-verify.md, reference/**, .chassis-delegation.json]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

The repo has to read as GTM-ready. Its quick-start still deploys every permission set before the agent exists, which fails in a fresh org (org-migration.md records why). Its proof table still says main was only deployed to the org it was built in, even though main now runs in agent-probe with version 2 active. Two research pages read as current when they describe the first org or version 1.

## Done when

- Read first: README.md (all of it), docs/research/org-migration.md (especially 'Stand the baseline up in a fresh org' and 'Plain answer'), docs/research/agent-iteration-1.md, docs/research/agent-publish-spike.md (its top section), docs/research/deploy-verify.md and docs/patterns/08-test-and-release-lifecycle.md
- README 'See it in 5 minutes' matches the verified order in org-migration.md 'Stand the baseline up in a fresh org'. At least: Account_Brief_Agent_Access is deployed only after the agent is published (it needs the Bot), and the group Account_Brief_User is assigned only after both sets exist. The sample-data seed command is given if data/sample has a plan (check the file names). Publish and activate are one step that links to page 08 for the full lifecycle. A note covers orgs the CLI classifies as production: validate with RunLocalTests, then quick deploy. Keep it short enough to read in 5 minutes. Every command names files that exist in the repo, and every sf flag used is checked with `sf <command> --help` (read-only)
- README proof table: the row 'A clean install from "See it in 5 minutes"' states what is true. Main was stood up in a fresh org (agent-probe) following the order in org-migration.md, and needed two sample-data fixes on the way (PR #72 and #74). The README's steps as now written have not been run end to end in a new org. Keep it marked not fully proven, with links to the evidence. The row 'Real deploy of main to the org' also names agent-probe, with the numbers those pages record (do not invent any)
- docs/research/org-migration.md gets a two-line note at the top of 'Plain answer'. It says the page records the move (version 1 active then), that version 2 is now active, and links agent-iteration-1.md. docs/research/agent-publish-spike.md gets a two-line note at its top: it records the org this was first built in, and the agent-probe state is in org-migration.md and agent-iteration-1.md. Change nothing else in those two pages
- Grep README.md and docs/patterns/** for sentences that still present the first org, version 1 or the alias `experimental` as the current state, and fix each one to match agent-iteration-1.md and org-migration.md. List every changed sentence in the hand-back (old and new). Historical sentences that say 'in the org this was first built in' stay
- No org Ids, record Ids, usernames, emails, instance hostnames or URLs with query strings. Do not name the alias `experimental` in new text; say 'the org this was first built in'. Never run an sf command that changes an org, never sign in or out
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes, and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit

## Review

Accepted on the verifier's verdict, with no review pass. The brain read the whole diff.

- README "See it in 5 minutes" now follows the order that worked in agent-probe:
  - step 1 deploys the metadata without the agent or Account_Brief_Agent_Access, then assigns the data set;
  - step 2 runs the sample-data seed (scripts/seed-sample-data.sh, 107 records);
  - step 3 publishes and activates;
  - step 4 deploys Agent Access and the group, then assigns the group;
  - step 5 opens the panel.
- What was recorded: the group deploy and assignment in step 4 are not part of the recorded run, and the README says so.
- Proof table:
  - The clean-install row is "Not fully proven". Main was stood up in agent-probe in the recorded order, with two sample-data fixes (#72, #74), but the README steps as written have not been run end to end.
  - The real-deploy row names both orgs.
- org-migration.md and agent-publish-spike.md each get a two-line note at the top pointing to the current state. Page 06 says version 2 is active.
- Brain fix 139ce7a: the production note no longer claims a plain deploy is refused (only a plugin hook refuses it). It now says to validate and then quick deploy, as the recorded run did.
- Gates: test (86) passes, and check-docs reports 30 pages, 0 broken. Privacy grep of the 65 added lines found no deny-list hits, Ids, emails, hosts, query-string URLs, home paths or mentions of the first org's alias.
