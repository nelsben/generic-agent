---
id: BE-57
title: Explorer catalog: a picklist value the question names reaches the model even when it is past the first 12 (q18)
domain: backend
tier: standard
status: merged
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

## Review

Brain review (2026-11-16). Two worker passes (haiku, an experiment from sonnet on a standard card; $0.14). The second pass was a brain-requested follow-up. The brain read the whole diff and made two doc-only hand fixes (5151ef5, da3d65d).

Findings:
- Describe now keeps every active picklist value, up to 500 per field, in describe order. The 6, 3 and 0 values-shown levels and the 6,000-character catalog cap are unchanged, and named values go first.
- A picklist value counts as named when either rule matches:
  - the old word rule: any question word of four letters or more, or its singular, inside the value;
  - the new whole-value rule: the whole value appears in the question as whole words, ignoring case.
- The worker's first pass replaced the old rule with the whole-value rule. That would have stopped 'closed deals' naming 'Closed Won' and 'Closed Lost', and 'technologies' naming 'Technology'. The brain sent it back, and both rules are now kept (ExploreCatalog.fieldText).
- New tests:
  - aNamedPicklistValuePastTheFirstTwelveIsShown: the last active Account.Industry value is shown when named. It fails on main and passes after.
  - closedDealsStillNamesTheClosedStages: pins the old rule.

Gate (mod): Python 393 tests, 4 skipped; validate-org pass. check-docs 82 pages, 0 broken.

Org: agent-probe only. ExploreCatalog and ExploreCatalogTest were validated with RunLocalTests and quick deployed, twice (once per pass). No record, user or setting was created. The worktree-local target org is unset.

Disclosed and accepted:
- The live q18 run (PASS, count 4) used the harness's current engine. That engine replays the BE-31 loop with the first explore prompt and the catalog built with no question, so it does not exercise the fix. The brain corrected the research note to say so. The deployed-path evidence is the Apex test; BE-45 reruns all 30 questions on the deployed explorer.
- closedDealsStillNamesTheClosedStages was not shown failing on the whole-value-only code.

Still open:
- A longer question can push the catalog to the 0-values level, where no picklist value is shown, named or not.

Privacy check over the branch's own diff (89 added lines): 0 denylist hits. The pattern hits are test annotations. No URL hosts.
