---
id: OPS-25
title: Org move: main is deployed to agent-probe, the sample data is seeded, Account_Brief is published and active there, and the Apex tests, the 12-case agent test, the two-turn check and the full e2e run are recorded
domain: ops
tier: frontier
tier_reason: org-changing deploy, publish and activation in a production-classified org, with stop conditions
status: merged
fixes: []
scope: [docs/research/org-migration.md]
forbid: [force-app/**, tests/**, e2e/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none
gate: test, org, agent
budget: 5-attempts
spend: 25
---
## Why

experimental returns 401 on every agent publish, and a fresh Developer Edition org (alias agent-probe) publishes the same minimal agent. Ben approved moving the baseline there. This card stands the whole baseline up in that org and writes the steps down, so standing it up in any fresh org is repeatable.

## Done when

- Before anything else, read docs/plans/gtm-burn-plan.md sections 'Approvals' and 'Phase 2', and do only what their lines approve. Then read docs/research/agent-publish-spike.md, docs/research/deploy-verify.md, docs/research/agent-api.md and docs/plans/corrective-plan.md (rules 1 to 4). Load these skills: salesforce-development:platform-metadata-deploy, salesforce-development:platform-data-manage, salesforce-development:platform-soql-query, agentforce-adlc:agentforce-generate and agentforce-adlc:agentforce-test. Verify every sf flag with --help before using it. Every sf agent command takes --json
- Facts from the session that created the org (checked read-only 2026-11-12). agent-probe is a Developer Edition org that counts as production (not a sandbox), with no trial end date. The CLI is signed in by web login (PlatformCLI) and it is not any project's default org, so pass -o agent-probe everywhere. The running user holds the Agentforce (Default), Data Cloud and Einstein Prompt Templates licenses, plus permission sets including CopilotSalesforceAdmin and GenieAdmin. There is no Einstein agent user. Data Cloud provisioning is not verified. The org has zero Accounts and no Apex, agents or bundles. A minimal employee agent published there (authoring API 200, v1 created Inactive, bundle named <Name>_1) with no agent user and no extra permission set. Activation, preview and non-admin access are untested there
- Never sign in, never log out, never create a user, and never run anything against experimental. The only org this card touches is agent-probe
- Preflight: classify agent-probe from `sf org list --skip-connection-status --json` as the deploy skill says, and record the edition and API version. Never print tokens, frontdoor URLs, org Ids or usernames. If the deploy gate hook refuses because the project has no default target org, run `sf config set target-org agent-probe` (project-local; .sf/ is git-ignored, never --global), and record that you did
- Deploy (production path, approved by the Approvals line 'Phase 2: migrate to the fresh Developer Edition org'): first `sf project deploy validate` of force-app without aiAuthoringBundles, with --test-level RunLocalTests, -o agent-probe, --wait 30 and --json. Then quick-deploy that validated job id, with CONFIRM_PROD=1 relaying Ben's approval. Run each step once. On failure, read the component and test failures, fix nothing in force-app, record them and stop. Record the test totals and org-wide coverage
- Assign Account_Brief_Agent_Access and Account_Brief_Data_Access to the running user only. Then run `bash scripts/seed-sample-data.sh` once with SF_TARGET_ORG=agent-probe and record the record counts per object by read-only aggregate queries
- Agent: run bash scripts/agent-check.sh (it validates against agent-probe). Then publish once: `sf agent publish authoring-bundle --api-name Account_Brief -o agent-probe --skip-retrieve --json`, with debug output going to a file outside the repo. After the publish, run `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`. Query the BotVersion rows, then activate the new version, passing the version explicitly if the flag exists. If the publish fails, record the real HTTP status and body, as agent-publish-spike.md did, and stop the agent steps. Do not retry the same call
- Tests, run once each against agent-probe: the 12-case spec tests/agent/Account_Brief-testSpec.yaml, run with the sf agent test commands the agentforce-test skill names (create the evaluation definition in the org if needed); the two-turn follow-up check through generateAiAgentResponse, as agent-api.md records it; and `SF_TARGET_ORG=agent-probe npm run test:e2e` (full run). Record every case's result. A failure caused by the new org's data or settings is recorded with its cause. Do not change tests/ or e2e/ to make a case pass; list the change it would need instead
- Write docs/research/org-migration.md. It covers what was done, in order, with each command's outcome; the deploy and test totals; the version table showing which version is active; the agent test table; the two-turn result; the e2e score; and 'Stand the baseline up in a fresh org' as numbered steps that worked tonight, or the exact blocker. Include no record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings
- Budget: at most about 40 model calls in the org. Write no data except the seed, the permission set assignments, the evaluation definition and what the agent and panel write themselves. Never install a plugin even if a hook suggests one
- Gate passes: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/agent-check.sh (both now target agent-probe); leave no tests/__pycache__/; git status --short is empty after your commit. In the hand-back, paste the read-only BotVersion query result so the brain can compare it with its own

## Review

Six attempts, one worker. Accepted after two review passes.

- Attempt 1 failed the deploy: Account_Brief_Agent_Access needs the Bot. The fix was a staged order, with Agent Access deployed after the publish.
- Attempt 2 failed AccountBriefMemoryTest on field access in a fresh org. Brain fix on main, #70: the test's own update runs in system mode.
- Attempt 3 failed the seed on BillingCountry, because the org has State and Country Picklists. Brain fix #72: full country and state names.
- Attempt 4 failed the seed with MALFORMED_ID on a same-file ParentId reference. Brain fix #74: the parent account moved to its own earlier plan entry, and the sample-data test now checks references in plan order.
- Attempt 5 seeded 107 records once, passed the 12-case agent test 12 of 12 and passed the two-turn check. e2e passed 7 of 8; spec 2 failed under the fresh org's Guidance Center walkthrough.
- The worker asked several times to edit data/** itself (amend forbid-=data/**). Each request was declined; the brain fixed the data on main instead.

Review of attempt 5: 19 confirmed, 1 refuted, 7 unverifiable. The refuted row: the doc and the hand-back called the walkthrough the settled cause ("not the panel"). Brain fix 9f38066 (attempt 6) states the cause as inference and adds the reviewer's timing finding: the Search button was focused right after Esc and gone 2.5 s later, so the walkthrough came up mid-test. FE-9 (#76, revised in #77) closes it with a locator handler; FE-8 waits on FE-9.

Review of attempt 6: 13 confirmed, 0 refuted, 6 unverifiable. The unverifiable rows are org-side results (agent test JSON, two-turn output, e2e artifacts, BotVersion rows) that leave nothing in the tree.

Stray tests/__pycache__: written about a second after each commit, so most likely by the verifier's gate run, not the worker. Removed before merge.

Gates: test (72), org (60 components, 150 Apex tests) and agent all pass at 9f38066. Privacy grep of the 404 added lines: 0 deny-list hits, 0 Salesforce-shaped Ids, 0 emails, 0 instance hosts, 0 query-string URLs, 0 home paths.

Loose end for BE-16: the spec's expectedActions uses superset matching, so case 7's extra resolve_account passes by design.
