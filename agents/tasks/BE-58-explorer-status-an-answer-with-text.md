---
id: BE-58
title: Explorer status: an answer with text and no queries is OK, not EMPTY
domain: backend
tier: standard
status: merged
blocked_by: [BE-44]
fixes: []
scope: [force-app/main/default/classes/DataExplorer.cls, force-app/main/default/classes/DataExplorerTest.cls, docs/research/fr2-explorer-empty-status.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/classes/ExplorePlan*, force-app/main/default/classes/ExploreQuery*, force-app/main/default/classes/ExploreCatalog*, force-app/main/default/staticresources/**, spikes/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, e2e/**, mcp-door/**]
resources: [org-live]
red_test: sf apex run test --class-names DataExplorerTest against agent-probe: the changed 'answered without rows' assertion and the new zero-row case fail before the code change on the first, pass after both
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

FE-31 found the panel shows an "Empty" badge on a follow-up the explorer answered from the conversation history. DataExplorer.answer sets EMPTY whenever no result set has a row, so an answer that ran no query at all reads as empty. EMPTY should mean the queries found nothing.

## Done when

- DataExplorer.answer sets the status to OK when the model gives non-blank answer text and no query ran (r.resultSets is empty); EMPTY when at least one query ran and none returned a row; OK when any result set has a row. The blank-question path (status EMPTY, NO_QUESTION_TEXT) is unchanged, and ERROR paths are unchanged
- DataExplorerTest: the contextAndHistoryReachThePrompt assertion ('answered without rows') now expects OK, with its message changed to say no query ran; a new case pins EMPTY when a query ran and returned 0 rows (use the existing script and fixture helpers, and only records the test itself inserts); every other existing assertion still passes unchanged
- The class header comment at DataExplorer.cls line 12 says what EMPTY means after this change
- No LWC, prompt resource, ExplorePlan, ExploreQuery or ExploreCatalog file changes. The panel's existing EMPTY handling (customerSummaryConversation.js showMessage) is left alone; the hand-back says whether that line still reads right with the new rule
- docs/research/fr2-explorer-empty-status.md (new, short): the rule before and after, the files changed, and an Undo section (redeploy DataExplorer and DataExplorerTest from the commit before this one). It notes that the spikes/explorer-scale engine copies keep their own status rule and are not changed
- Deploy to agent-probe only: validate with RunLocalTests, then quick deploy (CONFIRM_PROD=1) of the two classes. Set a worktree-local target-org for the deploy hook and unset it before hand-back. No record is created or deleted outside Apex tests; no Id, username, email, hostname, deploy job Id or local path is written

## Review

Brain review (2026-11-16). Two worker passes (haiku, an experiment from sonnet on a standard card; $0.11). The first pass stopped on a real contradiction in the card and changed nothing; the brain chose to keep the card's rule. The brain read the whole diff and made one doc-only hand fix (0768187).

Findings:
- DataExplorer.answer: OK when any result set has a row, or when no result set exists and the answer text is not blank. EMPTY when at least one query ran and none returned a row. The blank-question EMPTY and the ERROR paths are unchanged.
- The card said only one existing assertion would change. That was the brain's error: under the card's own rule four more DataExplorerTest assertions flip to OK (a refused aggregate, an object outside the catalog, a rejected query, and the FE-31 pronoun follow-up), plus one in ExploreActionTest that the org validation found. ExploreActionTest was added to scope by a disclosed amendment.
- New test aQueryThatReturnsNoRowsThenAnAnswerIsEmpty pins EMPTY for a query that returns 0 rows. It passes on the old code too, since the rule keeps that behaviour.
- Red: the changed DataExplorerTest, validated against the old org code, failed 5 assertions (Expected OK, Actual EMPTY).

Gate (mod verify at 0768187): Python 393 tests, 4 skipped; validate-org pass (215 components, 472 tests). check-docs 86 pages, 0 broken.

Org: agent-probe only. DataExplorer, DataExplorerTest and ExploreActionTest were validated with RunLocalTests (565 tests, 0 failures) and quick deployed. One earlier validation hit an Apex CPU limit in ExploreCatalogTest.perCallCatalogStaysUnderTheCapOnTheBe31Questions; it passed on the rerun. No record, user or setting was created. The worktree-local target org is unset.

Disclosed and accepted:
- OK no longer means rows were read. A model that states a figure without running a query now gets OK; only the trail and the result sets show whether data was read. The research note says so.
- The panel's Empty line in customerSummaryConversation.js was not looked at.

Still open:
- The ExploreCatalogTest CPU-limit failure, seen once. If it recurs it needs its own card.

Privacy check over the branch's own diff (83 added lines before the doc fix): 0 denylist hits. The pattern hit is a test annotation. No URL hosts.
