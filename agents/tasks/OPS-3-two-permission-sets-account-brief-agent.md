---
id: OPS-3
title: Two permission sets: Account_Brief_Agent_Access (agent only) and Account_Brief_Data_Access (Apex classes and the memory object)
domain: ops
tier: economy
tier_reason: mechanical metadata with a clear spec
status: merged
scope: [force-app/main/default/permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml, force-app/main/default/permissionsets/Account_Brief_Data_Access.permissionset-meta.xml, tests/test_permission_sets.py]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/**, force-app/main/default/objects/**]
red_test: python3 -m unittest tests.test_permission_sets (absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 3
---
## Why

The operating pattern keeps agent-access permission sets separate from data-access ones, so who can talk to the agent is a different decision from what they can read. The engine is Apex only, so data access means the engine's classes plus the one object it writes. Sharing and field security still decide what each user sees, and the explorer runs in user mode. The agent is published in experimental before this card runs.

## Done when

- Account_Brief_Agent_Access.permissionset-meta.xml grants access to the Account_Brief agent and nothing else. Find the element the org accepts by retrieving an existing permission set from experimental that grants an agent, into a scratch dir outside the repo
- Account_Brief_Data_Access.permissionset-meta.xml grants classAccesses for every non-test Apex class in force-app/main/default/classes (list them at run time). It grants objectPermissions on Account_Brief_Session__c (read, create, edit; no delete, view-all or modify-all) and read+edit fieldPermissions on every non-required custom field of that object. No standard-object permissions and no <license>. If the Models API needs a user permission to be called from Apex, name it in the hand-back; do not add it
- tests/test_permission_sets.py (stdlib unittest) asserts: the agent set has no classAccesses or objectPermissions; the data set has no allowDelete, viewAllRecords or modifyAllRecords set to true; every non-test class in force-app appears in the data set
- Gates pass: test and org. Quote the `validate-org:` line

## Review

Brain read at e4bd1d3: agent set holds only agentAccesses for Account_Brief; data set grants 21 of 21 non-test classes and read/create/edit on Account_Brief_Session__c, with no user permissions and no license. Unverified: whether calling the Models API from Apex needs a separate user permission.
