---
id: OPS-21
title: Publish spike: ship Account_Brief version 2 from the CLI with the real server error captured, fall back in a fixed order, then test and activate
domain: ops
tier: frontier
tier_reason: platform diagnosis with org-changing steps and stop conditions
status: merged
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
- Recipe from a sibling project that publishes Agent Script agents from the CLI (version 1 only; it has never republished over an active agent either):
  - Publish does everything itself: it compiles the script, calls the authoring API (which creates the version), writes a temporary `<target>` line into the bundle -meta.xml, deploys the bundle, then removes the line. Never `sf project deploy start` the bundle.
  - Before step 1, check that the bundle -meta.xml holds only `<bundleType>AGENT</bundleType>` with no `<target>` line, and that .forceignore does not cover the bundle (both were clean at hand-over).
  - Run `sf agent validate authoring-bundle --api-name Account_Brief -o experimental --json` before publishing. Publish with `--skip-retrieve`; confirm the flag with --help.
  - After any failed publish, run `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`.
  - `sf agent activate --api-name Account_Brief -o experimental --json` with no version activates the LATEST version. Query the versions first and pass the version explicitly if the flag exists, so an activation can never land on the wrong version.
  - Their leading hypothesis for our 404: the open Studio "Version 2" draft blocks a CLI create-version. Record whether step 1 fails with that draft present. If it fails, step 3 (committing that draft from Studio) is also the test of this hypothesis: after the commit, step 3's CLI attempt runs with no draft open.
- This card runs before the real deploy (OPS-20), while Ben is awake to help. So the org's Apex is behind main: BE-12, BE-13 and BE-14 are not deployed, and no invocable signature changed. Case 11's headers may still show dotted paths or URL_Redacted; record it as expected, not a new failure. Before step 1, read the latest message from the brain in your hand-off, if any, for recipe notes from the sibling project
- Rule for the whole card: one attempt per step. On an error, read the CLI log (~/.sf/sf-<date>.log) and the code path named in agent-publish-failure.md, write down the server's real status and body, and move to the next step. Never retry the same call unchanged
- Step 1, CLI publish: run bash scripts/agent-check.sh, confirm the .agent sha256 starts fb0fc27d, then run the CLI publish of the Account_Brief authoring bundle to experimental once, with debug output on (for example SF_LOG_LEVEL=debug or --dev-debug; confirm with --help) written to a file outside the repo. Capture the real HTTP status and response body of the versions call, with tokens and Ids removed. If it succeeds, a version 2 exists and version 1 is still active
- Step 2, only if step 1 fails: first-publish a throwaway copy under the API name Publish_Probe from a temporary folder outside the repo, once, with the same capture. Whatever the result, if a Publish_Probe agent now exists and the approvals allow deleting it, delete it with a destructive deploy (load salesforce-development:platform-destructive-deploy) whose manifest lists only components whose API names start with Publish_Probe, put that manifest in the results file, and confirm by query that nothing named Publish_Probe remains and Account_Brief is untouched; otherwise report that it must be removed by hand
- Step 3, only if step 1 fails: commit version 2 from Agentforce Studio using the Claude in Chrome extension (load anthropic-skills:chrome-browser first; Ben is signed in; open your own tab and close it). The Version 2 draft already holds these bytes. Click Commit Version and record the exact result text. Then, to finish the spike, make a one-line comment-only change in a temporary copy and try the CLI publish once more to learn whether the CLI can publish a version 3; if it creates a version 3, leave it inactive and say so
- Step 4, when a version 2 exists: run the 12-case spec (if sf agent test cannot target an inactive version, say so and run it right after step 5's activation instead) tests/agent/Account_Brief-testSpec.yaml against version 2 with the sf agent test commands the agentforce-test skill names, and run the two-turn follow-up check through generateAiAgentResponse the way docs/research/agent-api.md records. If the existing evaluation definition pins version 1 and has to be updated to do this, update it in the org only; do not change tests/ in the repo. Record every case's result
- Step 5, activation: only if the approvals line for activation says approved, and every case passes except differences already recorded in studio-preview.md, activate version 2 and confirm version 1 is inactive and version 2 active. Then run the two-turn follow-up check through generateAiAgentResponse (it only reaches the active version, so it runs here, not in step 4) and three spec cases by hand. If any fails, reactivate version 1 at once, confirm it is active, and record why. Write the rollback command you would use into the file before you activate. If any case fails for a new reason, do not activate. Never deactivate the agent without activating a version in the same step
- Write docs/research/agent-publish-spike.md: what was tried in order, the real server status and body for each failure, which hypothesis in agent-publish-failure.md the evidence supports, the final org state (versions and which is active), the test table, and 'how to ship an agent change from the CLI' as numbered steps that worked tonight, or the exact blocker. Draft, but do not post, a comment for forcedotcom/cli issue 3634 at the end of the file if the CLI still fails. No record Ids, org Ids, usernames, tokens or URLs with query strings
- Gate passes: python3 -m unittest discover -s tests and bash scripts/agent-check.sh; run Python with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; git status --short is empty after your commit. If the publish retrieves or rewrites files under force-app, restore them before committing. Never install a plugin even if a hook suggests one; never sign in; never trigger a browser dialog
- Every sf agent command takes --json (a hook refuses it without). Hand-back: paste the read-only query result that shows each Account_Brief version and which is active, so the brain can compare it with its own query

## Review

Sonnet review attempt 2: 15 confirmed, 0 refuted, 4 unverifiable. Brain check: the deny-list, email, host and record-Id grep of agent-publish-spike.md finds 0 hits. Version 1 is still active. After the merge, the brain ran the doc's next test 1: Ben signed in with the stock CLI app as experimental-web, and one publish failed with the same TypeError "fetch failed" (exit 10). That makes the JWT-scope lead unlikely. The JWT auth file was restored afterwards.
