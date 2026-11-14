# FR2 captures (OPS-52)

The capture list for the `See it` part of every pattern page, written before any capture was taken, and then the
record of the run. Every still and GIF is taken through `e2e/capture/kit.js` and checked by
`e2e/capture/privacy.js` from the live org, on the sample account Edge Communications and the other seeded sample
records. Nothing is deployed, no setting or brand record is changed, and no record is inserted, edited or backdated
for a capture: where the org holds nothing to show, the capture shows the empty state.

Surfaces: the compact window (Cmd/Ctrl-K, 420 by 560 at the bottom right) and the right rail (Cmd/Ctrl-Shift-K or
Expand, 640 px wide at a 1440 px window, full height, over the page). Every still is the whole 1440 by 900 browser
viewport at CSS scale (1440x900 pixels): the page, not the browser, so no address bar. Every GIF is cut from the
recording of the same 1440 by 900 viewport and scaled to 900 px wide.

## The list

Written first. Pages 00, 06, 07 and 14 get no capture. Pages 04 and 09 get a text block and no image.

| Page | File | Surface | Viewport | What it shows | Alt text (draft) |
|---|---|---|---|---|---|
| 01 | `fr2-01-summary.gif` | compact window | 1440x900, GIF 900 wide | Cmd-K opens the window, "/brief Edge Communications" is typed and sent, the wait is cut, the summary arrives as cards | Cmd-K opens the compact window, a summary of Edge Communications is asked for, and it arrives as a summary card with section cards under it |
| 01 | `fr2-01-summary-compact.png` | compact window | 1440x900 | The summary in the window: the request, the summary card's headline and bullets, the first section cards | The compact window with a summary of Edge Communications: the summary card's headline and points, then folded section cards |
| 01 | `fr2-01-summary-rail.png` | right rail | 1440x900 | The same summary after Expand, beside the account's context column | The right rail with the same summary in its conversation column, beside the account's context column |
| 01 | `fr2-01-not-found.png` | compact window | 1440x900 | "/brief" of a name that matches no account, and the fixed not-found line | The compact window answering a summary request for an unknown account with the fixed line that asks for a fuller or different name |
| 01 | `fr2-01-several-matches.png` | compact window | 1440x900 | "/brief United Oil", which matches several accounts, and the choice buttons | The compact window answering a partial account name with a choice of the matching accounts |
| 02 | `fr2-02-explorer-compact.png` | compact window | 1440x900 | A whole-org question and its answer: a short lead and a table card | The compact window with a whole-org question about the largest open opportunities, a short answer and a table card of the rows |
| 02 | `fr2-02-explorer-rail.png` | right rail | 1440x900 | The same answer after Expand, the table card at rail width | The right rail with the same answer, its table card shown wider |
| 02 | `fr2-02-drill.gif` | compact window | 1440x900, GIF 900 wide | A click on a row of the table card opens its drill view, then the breadcrumb goes back | A click on the first opportunity in the table card opens its record view under a breadcrumb, and the breadcrumb returns to the answer |
| 03 | `fr2-03-hotkey.gif` | compact window, then right rail | 1440x900, GIF 900 wide | Cmd-K opens the window, a line is asked and answered without a model call, Minimize, Cmd-K again with the thread kept, Expand to the rail with the thread kept | Cmd-K opens the compact window, a request is answered, Minimize hides the window, Cmd-K brings it back with the same thread, and Expand moves that thread into the right rail |
| 03 | `fr2-compact-launcher.png` (retaken) | launcher | 1440x900 | The launcher at the bottom right, the window closed | The record page with the compact window closed and the launcher at the bottom right |
| 03 | `fr2-compact-open.png` (retaken) | compact window | 1440x900 | The window open after Cmd-K, empty state | The record page after Cmd-K: the compact window open at the bottom right in its empty state |
| 05 | `fr2-05-followup-compact.png` | compact window | 1440x900 | A follow-up question answered from the summary before it | The compact window with a follow-up question about the summary above it, answered from that summary |
| 05 | `fr2-05-followup-rail.png` | right rail | 1440x900 | The same thread in the rail | The right rail with the summary and the follow-up answer in its conversation column |
| 05 | `fr2-05-reopened-compact.png` | compact window | 1440x900 | History, then a past conversation reopened with its turns | The compact window with an earlier conversation about the account reopened from History, its turns back in the thread |
| 05 | `fr2-05-reopened-rail.png` | right rail | 1440x900 | The History list in the rail | The right rail with History open, listing earlier conversations about the account |
| 05 | `fr2-05-outcomes-rail.png` | right rail (context column only) | 1440x900 | The outcomes timeline with an entry opened, and the sentiment chart, or their empty lines | The right rail's context column with the account's outcome timeline, one entry opened, and the sentiment chart |
| 08 | `fr2-08-e2e-report.png` | none (the HTML report) | 800x900 at device scale 2 | The Playwright HTML report of a full e2e run | The Playwright HTML report of a full end-to-end run, with its pass and fail counts and its spec list |
| 10 | `brand-swap-before.png`, `brand-swap-after.png` | compact window (old frame) | reused | BE-24's before-and-after, reused and not retaken: a brand flip would change a record | (kept as on the page) |
| 11 | `fr2-11-mic-compact.png` | compact window | 1440x900 | The mic button in the composer, focused | The compact window's composer with the mic button focused beside the text box and Send |
| 11 | `fr2-11-mic-rail.png` | right rail | 1440x900 | The mic button in the rail's composer | The right rail's composer with the mic button focused |
| 11 | `fr2-11-mic-listening.png` | compact window | 1440x900 | Only if the recording state shows without a stubbed recognizer | (only if taken) |
| 12 | `fr2-rail-open.png`, `fr2-rail-context.png`, `fr2-rail.gif` (retaken) | right rail | 1440x900; rail crop 640x900; GIF 900 wide | The rail over the page with its context column; the rail alone; the move from the window to the rail | (kept from FE-15, checked against the new frames) |
| 12 | `fr2-history-timeline.png`, `fr2-history-sentiment.png` (retaken) | right rail | 1440x900 | The history timeline and the sentiment chart in the context column | The right rail with the history timeline in its context column; the same rail with the sentiment chart, a point focused |
| 13 | `fr2-action-draft.png` (retaken) | compact window | 1440x900 | A "Create a follow-up" draft card, Subject filled, Due marked Needed, Confirm off | The compact window with a task draft card: Subject filled, Due marked Needed and Confirm off |
| 13 | `fr2-action-draft-rail.png` | right rail | 1440x900 | The same draft card in the rail | The right rail with the same task draft card in its conversation column |
| README | `fr2-readme-hero.gif` | compact window, then right rail | 1440x900, GIF 900 wide | Cmd-K, the ask, the summary with cards, Expand to the rail | Cmd-K opens the compact window, a summary is asked for and arrives as cards, and Expand moves it into the right rail beside the account's context |
| README | `fr2-01-summary-compact.png`, `fr2-01-summary-rail.png` | one still per surface | 1440x900 | The two summary stills of page 01 | (as page 01) |

No result card on page 13: the Approvals row "FR2: e2e and agent tests that create a record" does not start with
"approved", so no draft is confirmed.

Page 09's text block is the unauthenticated call: a `tools/list` POST with no token to the server's URL, and its
HTTP 401 answer, labelled "not a real tool call".
