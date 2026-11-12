---
id: OPS-26
title: Access in one step: a permission set group grants the agent and the panel, and the setup steps name it
domain: ops
tier: standard
tier_reason: one metadata file, one test and two doc paragraphs, plus a small deploy
status: blocked
blocked_by: [FE-8]
fixes: []
scope: [force-app/main/default/permissionsetgroups/**, tests/test_access_group.py, README.md, docs/patterns/07-trust-access-and-failure.md]
forbid: [force-app/main/default/permissionsets/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, e2e/**, scripts/**, docs/plans/**, docs/reviews/**, docs/research/**, agents/**, .chassis-delegation.json, reference/**, .sf/**]
resources: [org-live]
red_test: tests/test_access_group.py fails on main (no group file) and passes after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

Agent re-review N5: access needs two custom permission sets plus a standard Agentforce one, nothing groups them, and no setup step says to assign both. A missing set can make every agent turn fail. One group and one written setup step make the baseline adoptable.

## Done when

- Before anything else, read docs/reviews/agent-review-2.md N5 and 'Security and access', both permission sets under force-app/main/default/permissionsets/, docs/patterns/07-trust-access-and-failure.md, docs/research/org-migration.md and docs/plans/gtm-burn-plan.md sections 'Approvals' and 'Phase 2'. Load the skills salesforce-development:platform-permission-set-generate and salesforce-development:platform-metadata-deploy. Verify every sf flag with --help
- Add force-app/main/default/permissionsetgroups/Account_Brief_User.permissionsetgroup-meta.xml holding Account_Brief_Agent_Access and Account_Brief_Data_Access, with a description saying what it grants. Do not add a standard permission set to the group; name the standard Agentforce user permission set the panel needs (agent-review-2 cites CopilotSalesforceUser) in the setup step instead, and say whether the org-migration run confirmed it
- Add tests/test_access_group.py: the group file parses, names exactly those two sets, and both set files exist
- README.md and docs/patterns/07-trust-access-and-failure.md: one 'Give a user access' step naming the group and the standard set, replacing any wording that says to assign the two sets one by one. Mark non-admin use as not yet proven (FE-5 is parked until Ben creates the end user)
- Org, agent-probe only, per the Approvals line 'Phase 2: cut and work new agent or design iteration cards in the new org': deploy the group with `sf project deploy validate` (RunLocalTests, scope the permissionsetgroups folder) then quick deploy with CONFIRM_PROD=1, once each. Assign the group to the running user (it already has both sets; record that the assignment succeeded). Confirm with a read-only query that the group's status is Updated, printing no Ids
- Never touch experimental, never sign in or out, never create users, never install a plugin even if a hook suggests one
- Gates pass: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/validate-org.sh; leave no tests/__pycache__/; git status --short is empty after your commit
