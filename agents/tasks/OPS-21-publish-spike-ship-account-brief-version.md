---
id: OPS-21
title: Publish spike: ship Account_Brief version 2 from the CLI with the real server error captured, fall back in a fixed order, then test and activate
domain: ops
tier: frontier
tier_reason: platform diagnosis with org-changing steps and stop conditions
status: blocked
blocked_by: [OPS-20]
fixes: []
scope: [docs/research/agent-publish-spike.md]
forbid: [force-app/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live, chrome-studio]
red_test: none
gate: test, agent
budget: 2-attempts
spend: 25
---
## Why

We must be able to deploy agents from the CLI. Every failed publish so far re-sent a script identical to version 1 and the CLI hid the server's real error. Main now holds a changed script that Studio accepts and that previewed correctly (docs/research/studio-preview.md), so one instrumented attempt decides whether the failure was 'nothing changed', and a fixed fallback order gets version 2 live tonight either way.

## Done when

- Before anything else read docs/plans/gtm-burn-plan.md section 'Approvals' and do only what its lines approve; a step whose line does not say approved is skipped and reported. Then read docs/research/agent-publish-failure.md, docs/research/studio-preview.md, docs/research/salesforce-skills.md, docs/plans/corrective-plan.md (rules 1 to 4), and load the skills agentforce-adlc:agentforce-generate and agentforce-adlc:agentforce-test. Verify every sf flag with --help before using it
- Rule for the whole card: one attempt per step. On an error, read the CLI log (~/.sf/sf-<date>.log) and the code path named in agent-publish-failure.md, write down the server's real status and body, and move to the next step. Never retry the same call unchanged
- Step 1, CLI publish: run bash scripts/agent-check.sh, confirm the .agent sha256 starts fb0fc27d, then run the CLI publish of the Account_Brief authoring bundle to experimental once, with debug output on (for example SF_LOG_LEVEL=debug or --dev-debug; confirm with --help) written to a file outside the repo. Capture the real HTTP status and response body of the versions call, with tokens and Ids removed. If it succeeds, a version 2 exists and version 1 is still active
- Step 2, only if step 1 fails: first-publish a throwaway copy under the API name Publish_Probe from a temporary folder outside the repo, once, with the same capture. Whatever the result, if a Publish_Probe agent now exists and the approvals allow deleting it, delete it and confirm it is gone; otherwise report that it must be removed by hand
- Step 3, only if step 1 fails: commit version 2 from Agentforce Studio using the Claude in Chrome extension (load anthropic-skills:chrome-browser first; Ben is signed in; open your own tab and close it). The Version 2 draft already holds these bytes. Click Commit Version and record the exact result text. Then, to finish the spike, make a one-line comment-only change in a temporary copy and try the CLI publish once more to learn whether the CLI can publish a version 3; if it creates a version 3, leave it inactive and say so
- Step 4, when a version 2 exists: run the 12-case spec tests/agent/Account_Brief-testSpec.yaml against version 2 with the sf agent test commands the agentforce-test skill names, and run the two-turn follow-up check through generateAiAgentResponse the way docs/research/agent-api.md records. If the existing evaluation definition pins version 1 and has to be updated to do this, that is allowed. Record every case's result
- Step 5, activation: only if the approvals line for activation says approved, and every case passes except differences already recorded in studio-preview.md, activate version 2 and confirm version 1 is inactive and version 2 active. If any case fails for a new reason, do not activate. Never deactivate the agent without activating a version in the same step
- Write docs/research/agent-publish-spike.md: what was tried in order, the real server status and body for each failure, which hypothesis in agent-publish-failure.md the evidence supports, the final org state (versions and which is active), the test table, and 'how to ship an agent change from the CLI' as numbered steps that worked tonight, or the exact blocker. Draft, but do not post, a comment for forcedotcom/cli issue 3634 at the end of the file if the CLI still fails. No record Ids, org Ids, usernames, tokens or URLs with query strings
- Gate passes: python3 -m unittest discover -s tests and bash scripts/agent-check.sh; run Python with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; git status --short is empty after your commit. If the publish retrieves or rewrites files under force-app, restore them before committing. Never install a plugin even if a hook suggests one; never sign in; never trigger a browser dialog
