# FR2 panel rendering fixes (FE-31)

Fixes for M2, M5, L5, L7, L8 and OPS-52's new frames. Line numbers are in the files at this commit.

## Fixes

| Item | Fix | File |
| --- | --- | --- |
| M2 composer with no speech API | The voice host takes class `cs-voice-unsupported` when there is no recognizer; the host is then `flex-basis: 100%` and `order: 3`, and the composer row wraps, so the note sits on its own line below the textarea and the textarea keeps its width | customerSummaryVoiceInput.js `connectedCallback`; customerSummaryVoiceInput.css `:host(.cs-voice-unsupported)`; customerSummaryConversation.css `.abp-composer-row` |
| L5 chips | The quick-action row wraps (`abp-quick-row_wrap`, `flex-wrap: wrap`, no `overflow-x`) | customerSummaryConversation.css `.abp-quick-row`; customerSummaryConversation.html footer |
| Table last column | The table's box is always a Tab stop (`tabindex=0`, was off when rows linked), `role=region`, named by the card title or its type | customerSummaryCard.js `wrapTabindex`; customerSummaryCard.html `.cs-table-wrap` |
| Mic focus ring | 2 px ink outline drawn inside the button (`outline-offset: -4px`) so no ancestor's overflow clips it; surface-coloured while recording | customerSummaryVoiceInput.css `button:focus-visible` |
| M5 header targets | Expand and Minimize are `lightning-button-icon` variant `container`, size `x-small` (a 24 px square) instead of bare 16 px; `.cs-expand` and `.cs-minimize` also have a 1.5 rem minimum | customerSummaryPanel.html header buttons; customerSummaryPanel.css `.cs-expand, .cs-minimize` |
| L7 palette | The voice component's fallbacks are the conversation's `#0176d3` family | customerSummaryVoiceInput.css |
| L8 agent name | `agentName` defaults to empty; the permission message reads "Microphone permission is needed to listen." with no name and "<name> needs microphone permission to listen." with one; the conversation still passes its name | customerSummaryVoiceInput.js `handleError` |

## Not fixed

- The "Empty" badge on a follow-up answer. The card is not the cause: a text card carries whatever status Apex gives it. `DataExplorer.answer` sets the status to EMPTY whenever no query returned a row (`DataExplorer.cls` line 249, and line 137 for a blank question), even when the model answered from the conversation history with text. The fix belongs in Apex (an answer with text and no queries is OK), which this card forbids. The label was not changed.
- The Close column cut off in the rail: the card's own table box now scrolls and is keyboard reachable. If the rail itself clips the card (customerSummaryRail is forbidden here), that is a separate fix.
- ESLint: the repo has no eslint config and eslint is not a dependency, so `npx eslint` cannot run. Nothing was added.

## Counts

See the hand-back for the final Jest and e2e counts; Jest: all suites pass (388 tests).
New Jest cases: 5 in the voice bundle, 2 in the conversation, and the card's table case now pins tabindex, role and name.
New e2e: spec 11 (chips inside the row at 420 px) and spec 12 (axe at 1280x720: compact window and draft card).

## Undo

Redeploy these bundles from the commit before this one on main:
customerSummaryConversation, customerSummaryVoiceInput, customerSummaryCard, customerSummaryPanel
(`sf project deploy start` is not used; follow the validate then quick deploy path, agent-probe only).
