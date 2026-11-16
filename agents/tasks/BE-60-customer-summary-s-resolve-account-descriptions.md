---
id: BE-60
title: Customer_Summary's resolve_account descriptions name the ERROR status; new version published and activated in agent-probe, Testing Center suite rerun on it
domain: backend
tier: standard
status: merged
fixes: []
scope: [force-app/main/default/aiAuthoringBundles/Customer_Summary/**, tests/test_agent_bundle.py, docs/research/fr2-agent-v3.md, README.md]
forbid: [docs/plans/**, agents/**, .chassis-delegation.json, reference/**, mcp-door/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, data/**, tests/agent/**, scripts/**, sfdx-project.json]
resources: [org-live]
red_test: the new test in tests/test_agent_bundle.py that requires ERROR in every resolve_account status list fails on main and passes after
gate: test
budget: 2-attempts
spend: 10
---
## Why

BE-38 found the agent's script lags the Apex: resolve_account returns ERROR when the account search fails (BE-29), and the instructions handle it, but the action's output descriptions list only RESOLVED, AMBIGUOUS and NOT_FOUND. Ben said on 2026-11-16 "yes, fix the description", which needs a publish and an activation of a new version.

## Done when

- Approval first: read the row "FR2+: fix the `resolve_account` output descriptions" in docs/plans/gtm-burn-plan.md on origin/main. If its status does not start with "approved", change nothing in the org and hand back. Read docs/research/fr2-agent-publish.md (how version 2 was published and activated, and its Undo) and docs/research/fr2-testing-center.md first. Load the skill agentforce-adlc:agentforce-generate before editing the .agent file.
- The .agent file in force-app/main/default/aiAuthoringBundles/Customer_Summary/ names ERROR wherever resolve_account's status values are listed (the action description and the status output description): RESOLVED, AMBIGUOUS, NOT_FOUND or ERROR, with ERROR meaning the account search failed and the agent says so instead of claiming nothing was found. No other wording in the agent changes.
- tests/test_agent_bundle.py gains a test that every place in the .agent listing resolve_account's status values names all four, which fails on main and passes after.
- bash scripts/agent-check.sh passes (local compile with 0 warnings, and the org validate).
- Publish and activate in agent-probe only: record the active version first (read-only). sf agent publish authoring-bundle --api-name Customer_Summary -o agent-probe --json, then sf agent activate --api-name Customer_Summary --version <new> -o agent-probe --json. Then a check after activation: one turn from Apex or sf agent preview that asks for a summary of Gallowglass Textiles answers with a summary. If that check fails, reactivate version 2 at once and hand back with what failed.
- Rerun the Testing Center suite on the new version: bash scripts/agent-test.sh --org agent-probe. Record the counts and the version it ran against. A failed check is reported by case number, not fixed in this card.
- docs/research/fr2-agent-v3.md records: the change, the version numbers before and after, publish and activate results and times, the check after activation, the suite counts, what the runs wrote (count Customer_Outcome__c on Gallowglass Textiles before and after, read-only), and an Undo section (reactivate version 2). The README Status row "The optional agent published and active" names the new version and date.
- Org rules: agent-probe only, -o agent-probe on every sf command; never touch experimental; never deactivate without activating the previous version in the same step; no destructive deploy; no user, sign-in or credential; no security cases. No Ids, usernames, hostnames or URLs in any file. Unset any worktree-local target-org before handing back.
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__; git status --short empty after the commit.

## Review

Brain review (2026-11-16). One worker attempt (sonnet, standard tier, $0.58). The mod verified the hand-back as consistent and returned next=accept. The brain read the whole diff.

Findings:
- `Customer_Summary.agent`: only the `resolve_account` action description and its `status` output description changed; both now name ERROR, and the status description says to report a failed search rather than claim nothing was found. The `message` output description was left as is (it is not a status list).
- Red: the new test in tests/test_agent_bundle.py found ERROR missing on main and passes after. It pins exactly two status lists in the resolve_account block.
- Org (agent-probe only, under the Approvals row for this fix): agent-check passed (compile 0 warnings, org validate). Published version 3, activated it (version 2 kept inactive for rollback). One turn from Apex for a Gallowglass Textiles summary succeeded, so no rollback.
- Testing Center suite on version 3: 47 of 47 assertions on 16 cases.
- Writes: Customer_Outcome__c on Gallowglass Textiles went 12 to 19 (one from the check turn, six from the suite), covered by the approval row and the standing row for tests that create their own records.
- The publish retrieved metadata into the worktree (bundle meta reformatted, three Apex files touched, two new folders); the worker restored or removed all of it before the commit. No Apex was deployed by this card.
- Research page fr2-agent-v3.md with versions, times, counts and an Undo (reactivate version 2); the README Status row names version 3.

Gate (worker): Python 410 tests, 4 skipped; check-docs 89 pages, 0 broken.

Privacy check over the branch's own diff: 0 denylist hits, 0 pattern hits.
