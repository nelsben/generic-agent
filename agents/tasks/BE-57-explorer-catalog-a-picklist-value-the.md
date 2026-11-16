---
id: BE-57
title: Explorer catalog: a picklist value the question names reaches the model even when it is past the first 12 (q18)
domain: backend
tier: standard
status: queued
fixes: [BE-42]
scope: [force-app/main/default/classes/ExploreCatalog.cls, force-app/main/default/classes/ExploreCatalogTest.cls, docs/research/fr2-explorer-catalog.md, spikes/explorer-scale/results/be57-q18.jsonl]
forbid: [force-app/main/default/classes/ExplorePlan*, force-app/main/default/classes/ExploreQuery*, force-app/main/default/classes/DataExplorer*, force-app/main/default/staticresources/**, force-app/main/default/customMetadata/**, force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, spikes/explorer-scale/questions.json, spikes/explorer-scale/harness.apex, spikes/explorer-scale/run.py, mcp-door/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: ExploreCatalogTest: a new test describes Account.Industry (more than 12 active values in every org) with a question naming the value that comes last in describe order, and asserts that value appears in describeForPrompt's text; it fails on main and passes after (bash scripts/validate-org.sh runs it)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

BE-43 found q18's cause: ExploreCatalog.cls:706-708 keeps only the first 12 active picklist values at describe time, before the question's named values are ranked first, so 'Technology' (one of Account.Industry's 32 values) never reaches the model and the count comes out 3, not 4. This is a BE-42 defect; the explorer line approval (2026-11-15) and the full-burn go cover the fix and its deploy.

## Done when

- At describe time ExploreCatalog keeps every active picklist value (cap the stored list at 500 per field to bound heap, and say so in a comment); the 6/3/0 values-shown levels and the MAX_PROMPT_CHARS = 6000 cap are unchanged, and the values the question names are still put first, so a named value is shown whenever any value of that field is shown
- A named value is matched case-insensitively against the whole value (the existing matching rule if there is one; if not, a whole-word, case-insensitive match). The page says which
- The new ExploreCatalogTest case (Account.Industry, the value last in describe order named in the question) fails on main and passes after; the existing ExploreCatalogTest cases still pass; the prompt text stays at or under 6000 characters for every existing test question
- Deployed to agent-probe only: sf project deploy validate --source-dir <the two classes> --test-level RunLocalTests -o agent-probe, then CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o agent-probe. A worktree-local target org may be set for the deploy hook and is unset before hand-back
- One live run of q18 alone through the existing harness (spikes/explorer-scale, read its README or run.py for how to run one question; do not change the harness) records its pass or fail, model calls and catalog characters in spikes/explorer-scale/results/be57-q18.jsonl. The full 30-question rerun is BE-45's, not this card's
- docs/research/fr2-explorer-catalog.md gains a short 'q18 fix (BE-57)' part: the cause BE-43 found, the change, the test, the one live result, and an Undo line (redeploy ExploreCatalog from the previous main commit)
- Nothing creates, edits or deletes a record; no Id, job Id, username, email, hostname or local path in any committed file; gates PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh pass; no tests/__pycache__
