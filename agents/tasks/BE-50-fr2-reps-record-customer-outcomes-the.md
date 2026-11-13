---
id: BE-50
title: FR2: reps record customer outcomes — the outcome set joins the Customer_Summary_User group, and the doc says which outcome fields any holder can read
domain: backend
tier: standard
tier_reason: small, but it ends in a validate and quick deploy to agent-probe, which economy workers have not done here
status: queued
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
