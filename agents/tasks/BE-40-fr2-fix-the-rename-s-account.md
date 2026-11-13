---
id: BE-40
title: FR2: fix the rename's "account summaryed" slip — it reads "account briefed" again in the agent, its spec and the bundle test, and a test keeps the broken form out
domain: backend
tier: economy
tier_reason: a seven-line text fix with an exact list of lines and one grep test
status: blocked
blocked_by: [OPS-30]
fixes: [BE-23]
scope: [force-app/main/default/aiAuthoringBundles/Customer_Summary/Customer_Summary.agent, tests/agent/Customer_Summary-testSpec.yaml, tests/test_agent_bundle.py, tests/test_fr2_rename.py]
forbid: [force-app/main/default/classes/**, force-app/main/default/lwc/**, mcp-door/**, spikes/**, scripts/**, docs/**, README.md, agents/**, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: the new test in tests/test_fr2_rename.py fails on main (git grep finds 'summaryed' in the agent, the spec and the bundle test) and passes after
gate: test
budget: 2-attempts
spend: 3
---
## Why

BE-23's mechanical rename turned "account briefed" into "account summaryed" in seven places, two of them in the agent's model-facing instructions. The agent keeps "brief" as a verb elsewhere (briefed_account_id, "brief you on"), so the fix restores "briefed". OPS-51 publishes this bundle, so the fix lands first.

## Done when

- Every 'account summaryed' reads 'account briefed' again: force-app/main/default/aiAuthoringBundles/Customer_Summary/Customer_Summary.agent (the explore subagent's instructions and its reclassify description), tests/agent/Customer_Summary-testSpec.yaml (four expectedOutcome lines) and tests/test_agent_bundle.py (the two asserts on the explore text). Change no other word in those files
- tests/test_fr2_rename.py gains one test: `git grep -i -E 'summaryed|summarys\b'` outside docs/research, docs/reviews, docs/plans and agents finds nothing. It fails before the fix and passes after
- `git grep -n -i summaryed` in the repo finds nothing outside docs/research, docs/reviews, docs/plans and agents
- Local compile of Customer_Summary.agent with the agentforce-generate skill's index-agent.mjs shows 0 errors. No org call of any kind: no deploy, validate, publish or preview
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
