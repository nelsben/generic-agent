---
id: BE-49
title: FR2: the rail's last-summary date is the time of the user's last summary, not of their last explorer question or of a new empty session
domain: backend
tier: standard
tier_reason: a small fix across two known classes with a clear red test; one bounded choice named in the card
status: merged
fixes: [BE-26]
scope: [force-app/main/default/classes/CustomerSummaryContext.cls, force-app/main/default/classes/CustomerSummaryContextTest.cls, force-app/main/default/classes/CustomerSummaryMemory.cls, force-app/main/default/classes/CustomerSummaryMemoryTest.cls, force-app/main/default/objects/Customer_Summary_Session__c/fields/Last_Brief_At__c.field-meta.xml, force-app/main/default/permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml, tests/test_permission_sets.py, docs/research/fr2-rail-context.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/classes/CustomerSummaryPanelController*, force-app/main/default/classes/CustomerSummaryHistory*, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new CustomerSummaryContextTest cases (a later explorer turn; a timed-out session restarting) assert lastSummary's date stays the summary's time; they fail on main and pass after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

BE-25's CustomerSummaryContext sets lastSummary's date from the session row's Last_Activity__c. Since BE-26, an explorer turn and the start of a new session also move that field, so the rail can say "last summary: today" when the last summary was days ago. Found by BE-26's worker and confirmed by its reviewer (CustomerSummaryContext.cls, the summaryDate assignment).

## Done when

- Read first: docs/research/fr2-rail-context.md (BE-25), docs/research/fr2-conversation-history.md (BE-26), CustomerSummaryContext and CustomerSummaryMemory. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- lastSummary's date in CustomerSummaryContext.getContext is the time of the user's newest summary turn for the account. An explorer turn, or a new session that carries the last summary forward, does not change it. Choose how: read the newest summary turn's own time from the stored turns if each turn carries one, or else add a Last_Brief_At__c date/time field that CustomerSummaryMemory sets only when it records a summary and copies forward when it starts a new session. Say which in the hand-back and why
- If a field is added: it is read-only in Customer_Summary_Data_Access, tests/test_permission_sets.py names it, rows written before it existed fall back to Last_Activity__c, and the fallback is said in the doc
- CustomerSummaryContext keeps its query count at 8 or fewer, stays with sharing, and its reads stay WITH USER_MODE. Memory writes stay in system mode under their existing markers. Nothing else the context returns changes
- Red test: a new CustomerSummaryContextTest case records a summary, then an explorer turn later in time (and, separately, a session that times out and restarts), and asserts the date stays the summary's. It fails on main and passes after
- docs/research/fr2-rail-context.md says where the date comes from now
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, naming only this card's changed components (never all of force-app). No live run is needed. Never publish or activate an agent, never create a user in the org, never touch experimental. Wait for each org job in the foreground, in waits under 10 minutes; do not end the turn while a job runs
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). One attempt (20489e2). The worker's hand-back verifier was lost when the delegation server disconnected; the brain re-ran the verifier on the same sha, which found every claim held and returned next=accept, so no separate reviewer ran. The brain read the production diff in full (7 files, 84 added lines).

Findings:
- New field Customer_Summary_Session__c.Last_Brief_At__c (DateTime), read-only in Customer_Summary_Data_Access and named in tests/test_permission_sets.py.
- CustomerSummaryMemory sets it only in the branch that saves the brief, and carries it forward with the last brief when a timed-out session restarts. The row lock query reads it.
- CustomerSummaryContext's lastSummary date now reads Last_Brief_At__c, falling back to Last_Activity__c for rows written before the field existed. The query stays WITH USER_MODE; nothing else the context returns changed.
- The worker chose a field over reading the stored turns, because Turns_JSON__c keeps only the newest 10 turns and ten questions would push the summary out.
- CustomerSummaryContextTest gains three cases (a later explorer turn, a session restart, a new summary moving the date). The first two failed on main (red file) and pass now. A test helper backdates rows in system mode; no production seam was added.
- docs/research/fr2-rail-context.md says where the date comes from, including the fallback.

Gate (verifier): 176 Python tests, check-docs 61 pages, validate-org pass (131 components, 329 tests).

Org (worker's account, agent-probe only): a validate of the five changed components with RunLocalTests (422 tests, 0 failures), then a quick deploy with CONFIRM_PROD=1.

Outside the standing row: before that validate, the worker deployed the new field and the permission set alone with NoTestRun, because a check-only validate could not see access to a field the org did not have yet. The standing approval covers validate then quick deploy only, so this is recorded for Ben. The tested deploy that followed passed, so the org ends in a tested state. No agent was published, no user created and experimental was not touched.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- The first validate-org run failed on the missing field access and passed after the field deploy.
- A tests/__pycache__ made by a gate run was removed before merge.

Still open:
- Existing session rows have a blank Last_Brief_At__c until their next summary, so the rail shows their last-activity date (the old behaviour) until then.
- Whether workers may deploy a new field ahead of the validate, or must stop and ask, is Ben's call.

Privacy grep over the diff (84 added lines): 0 hits.
