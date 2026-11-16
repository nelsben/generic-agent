# FR2 explorer: EMPTY means the queries found nothing (BE-58)

FE-31 found the panel showed an "Empty" badge on a follow-up that the explorer answered from the
conversation history. DataExplorer.answer set EMPTY whenever no result set had a row, so an answer
that ran no query at all read as empty.

## Rule

Before: status is OK when any result set has a row; otherwise EMPTY. A text answer with no query
run was EMPTY.

After:
- OK when any result set has a row.
- OK when no query ran (r.resultSets is empty) and the answer text is not blank.
- EMPTY when at least one query ran and none returned a row.
- The blank-question path (EMPTY, NO_QUESTION_TEXT) and the ERROR paths are unchanged.

## Test impact

The card said only the 'answered without rows' assertion would change and that every other
existing assertion would stay unchanged. That was wrong. Under its own rule, four more existing
assertions in DataExplorerTest flip from EMPTY to OK, because each has a text answer and no
result set:

- aggregateOverTheRowCapIsFedBackAndCountsAsAQuery (the aggregate was refused, then answered in text)
- objectOutsideCatalogIsRejected (the plan named an unknown object, then answered in text)
- queryExceptionIsFedBackAndCountsAsAQuery (the database rejected the query, then answered in text)
- anUnclearPronounAfterASummaryIsAskedBackWithNoQuery (the FE-31 case: a follow-up answered from
  the summary context with no query)

The brain chose to keep the rule and update these four to expect OK, with messages saying no result
set came back and the model answered in text. contextAndHistoryReachThePrompt also flips to OK, with
a message saying no query ran. A new case, aQueryThatReturnsNoRowsThenAnAnswerIsEmpty, pins EMPTY
when a query runs, returns 0 rows and is followed by an answer. That case passes on the old code too,
since it pins behaviour the rule keeps, so the red run cannot show it.

## Files changed

- force-app/main/default/classes/DataExplorer.cls: the status line in answer(), and the class header
  comment on what EMPTY means.
- force-app/main/default/classes/DataExplorerTest.cls: the five assertions above, and the new case.
- force-app/main/default/classes/ExploreActionTest.cls: one more assertion that flips under the rule
  (cardsOverTheCapLeaveTheCardsOutputEmptyAndTheAnswerAsIs, a text answer with no query), now OK. The
  org validation found it; the brain added the file to the card's scope.
- docs/research/fr2-explorer-empty-status.md: this note.

Not changed: the LWC (customerSummaryConversation.js shows EMPTY as before), the prompt resource,
ExplorePlan, ExploreQuery, ExploreCatalog. The spikes/explorer-scale engine copies keep their own
status rule and are not changed.

## What OK no longer says

Before, OK meant a query returned rows. Now a text answer with no result set is OK too. That covers a
refused or rejected plan the model explains, and also a model that states a figure without running a
query. Whether data was read now shows only in the trail and the result sets, not in the status.

## Undo

Redeploy DataExplorer, DataExplorerTest and ExploreActionTest from the commit before the BE-58 commit
(adb4e97, which is main at the start of BE-58), with a RunLocalTests validate and quick deploy to
agent-probe. Those three classes are the only org-side change.
