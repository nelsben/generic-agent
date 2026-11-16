---
id: BE-58
title: Explorer status: an answer with text and no queries is OK, not EMPTY
domain: backend
tier: standard
status: blocked
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
