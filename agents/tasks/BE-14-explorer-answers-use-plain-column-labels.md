---
id: BE-14
title: Explorer answers use plain column labels, so the agent's reply no longer shows URL_Redacted in table headers
domain: backend
tier: standard
tier_reason: bounded label change with a clear rule and tests
status: queued
fixes: []
scope: [force-app/main/default/classes/Explore*.cls, force-app/main/default/classes/DataExplorer*.cls, force-app/main/default/staticresources/AgentPrompt_Explore.resource]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/lwc/**, force-app/main/default/permissionsets/**, force-app/main/default/classes/AccountBrief*.cls, tests/**, scripts/**, docs/**, agents/**, .chassis-delegation.json, reference/**]
red_test: a new Apex test asserting no dotted field path in the explorer answer text fails on main and passes after, via bash scripts/validate-org.sh
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

In the Studio preview (docs/research/studio-preview.md, case 11) the agent's reply to an explorer question showed the table headers Account.Name and Owner.Name as URL_Redacted. The cause is not established, but dotted field paths look like web addresses to a redaction layer. No screenshot or GIF can ship with that text in it.

## Done when

- Read docs/research/studio-preview.md (case 11), ExploreAction.cls and DataExplorer.cls, and find where the answer text and its table headers are built. First establish from the code whether the dotted headers come from Apex (field paths used as headers) or only from the model's prose; say which in the hand-back
- Every table header and field name that Apex writes into the explorer's answer text, or passes to the model as a column name, is a plain label with no dot: Account.Name becomes Account, Owner.Name becomes Owner, and other parent paths follow the same rule (the parent's label; add the field label only when it is not Name, e.g. Account Industry). Two columns never get the same label
- The Explore prompt (staticresources/AgentPrompt_Explore.resource) tells the model to use the given column labels and never write a dotted field path or anything shaped like a web address in its answer
- The panel's result table and drill view still work: they key on the same values as before or are updated in the same change. Structured data returned to the panel keeps real field paths where code needs them
- Apex tests prove no dotted path appears in the answer text for a query with parent fields, and that labels are unique. They use Assert.*
- No invocable signature, label or description changes. Gates pass: python3 -m unittest discover -s tests, npm run test:unit and bash scripts/validate-org.sh (check-only)
- Hard limits: never publish, activate, deactivate, deploy for real or delete anything in the org; never install a plugin even if a hook suggests one. Run Python with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/, and git status --short is empty when you report
