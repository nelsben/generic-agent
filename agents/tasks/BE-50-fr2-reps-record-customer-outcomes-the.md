---
id: BE-50
title: FR2: reps record customer outcomes — the outcome set joins the Customer_Summary_User group, and the doc says which outcome fields any holder can read
domain: backend
tier: standard
tier_reason: small, but it ends in a validate and quick deploy to agent-probe, which economy workers have not done here
status: merged
fixes: [BE-35]
scope: [force-app/main/default/permissionsetgroups/Customer_Summary_User.permissionsetgroup-meta.xml, force-app/main/default/objects/Customer_Outcome__c/fields/Sentiment_Score__c.field-meta.xml, tests/test_permission_sets.py, docs/research/fr2-customer-outcomes.md]
forbid: [force-app/main/default/permissionsets/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, scripts/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_permission_sets (the new assertion that the group holds the outcome set fails before the group file changes)
gate: test, org
budget: 2-attempts
spend: 8
---
## Why

BE-35 built customer outcomes but put their access in a separate permission set, Customer_Summary_Outcome_Access, which is not in the Customer_Summary_User group, so only the developer user records outcomes today. Its review also found that any holder of the set can read the skill, surface, model, score and record link through the API, a list view or the report type, while the doc names only the record link, and Sentiment_Score__c's field description contradicts what view() shows.

## Done when

- force-app/main/default/permissionsetgroups/Customer_Summary_User.permissionsetgroup-meta.xml lists Customer_Summary_Outcome_Access next to Customer_Summary_Data_Access, and tests/test_permission_sets.py asserts the group holds both sets and nothing else.
- Customer_Summary_Outcome_Access itself is unchanged: no field or object permission is added or removed.
- docs/research/fr2-customer-outcomes.md's field-access section says which outcome fields any holder of the set can read outside our surfaces (record link, skill, surface, model, sentiment score and label, type, expiry), through the API, a list view and the report type. It says our surfaces (view()) show other reps only the type, date, fixed phrase and sentiment label. The paragraph that says reps need both sets now says the group grants both.
- Sentiment_Score__c's field description no longer says it is shown to anyone who can see the account; it says what view() actually does: other reps' panel views hide it, and holders of the set can read it through the API.
- The group and the field are validated with RunLocalTests and quick deployed to agent-probe with CONFIRM_PROD=1, using only this card's changed components (--source-dir or --metadata on those paths, never all of force-app). The hand-back gives the test count and failures.
- No permission set assignment, group assignment or user is created or removed in any org; the developer user's existing direct assignment of the outcome set is left as is. No outcome row is written and the retention batch is neither run nor scheduled.
- PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh pass.

## Review

Brain review (2026-11-14). One attempt (f180639). The verifier found the report consistent and returned next=accept, so no separate reviewer ran. The brain read the full diff (5 files, 24 added lines).

Findings:
- Customer_Summary_User now holds Customer_Summary_Outcome_Access next to Customer_Summary_Data_Access, and its description says so (shortened to fit the 255-character limit). Customer_Summary_Outcome_Access itself is unchanged.
- tests/test_permission_sets.py asserts the group holds both sets and nothing else. tests/test_access_group.py, which pinned the group to the data set alone, was amended into scope and now expects both sets.
- Sentiment_Score__c's description no longer says it is shown to anyone who can see the account: other reps' panel views hide it, and holders of the outcome set can read it through the API.
- docs/research/fr2-customer-outcomes.md names the outcome fields any holder of the set can read outside our surfaces, through the API and a list view; the report type leaves out the record link. It says what view() shows other reps (type, date, fixed phrase, sentiment label), that the group grants both sets, and its stale live-check setup line is corrected.

Gate (worker and verifier): 176 Python tests, check-docs 61 pages, validate-org pass (129 components, 326 tests).

Org (worker's account): a validate of the group and the field only, with RunLocalTests (419 tests, 0 failures), then a quick deploy under the standing row. The first validate failed on the group description's length and was re-run after the fix. No assignment, group or user was created or removed, no outcome row was written, and the retention batch was neither run nor scheduled.

Effect: every holder of the Customer_Summary_User group in agent-probe now records an outcome with each summary and can save answers. The developer user's direct assignment of the outcome set from BE-35 is left as is.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- Who sees customer outcomes is still built to the default and remains Ben's call; the doc now says exactly what a holder can read.
- The purge job is not scheduled (Ben's go).
- The developer user's direct outcome-set assignment is now redundant with the group; removing it is optional.

Privacy grep over the diff (24 added lines): 0 hits.
