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

## The record

Run on 2026-11-14 against the `agent-probe` org, from the worktree cut after OPS-48 merged. The capture scripts are
`e2e/capture/09-compact`, `10-rail`, `11-action-draft`, `12-history`, `13-summary-memory`, `14-resolver`,
`15-explorer`, `16-hotkey`, `17-voice` and `05-report` (the e2e report). The utility-panel scripts `01-hotkey`,
`02-resolver`, `03-brief`, `04-explore` and `08-conversation-core` were removed: their frames show a window the
product no longer has. Every PNG was opened and every GIF looked at one frame a second, for names, usernames,
emails, Ids, an address bar, an error toast or a raw API name; none showed one. The owner shows as "Sample Owner"
and emails as "email hidden", from `privacy.js`.

Accounts used: Edge Communications (the summary, the follow-up, History, the rail, the draft card, the mic), the
three United Oil & Gas accounts (the several-matches line, by name only), and the org's open opportunities (the
whole-org question). "Zephyr Quartz Holdings" matches no account.

### The final list

The alt text is the text on the page. Every still is 1440x900 at CSS scale unless the size says otherwise; every
GIF is 900x563.

| Page | File | Surface | Size | Alt text |
|---|---|---|---|---|
| 01 | `fr2-01-summary.gif` | compact window | 900x563 | Cmd-K opens the compact window on the Edge Communications record page, "/brief Edge Communications" is typed and sent, three dots show while it works (the wait is cut), and the summary arrives as a summary card headed "Edge Communications' support renewal is overdue and a high-priority escalated case is disrupting core BGP routing." |
| 01 | `fr2-01-summary-compact.png` | compact window | 1440x900 | The compact window at the bottom right of the Edge Communications record page: the request "/brief Edge Communications", then the summary card with its headline about the overdue support renewal and the escalated BGP case, and the account summary under it, starting with Account and Open deals, above the quick chips and the composer |
| 01 | `fr2-01-summary-rail.png` | right rail | 1440x900 | The same summary after Expand, in the right rail over the page: the request and the summary card in the conversation column, the account summary in larger type, and beside it the "About Edge Communications" column with Open deals (5) and Recent activity (10) |
| 01 | `fr2-01-not-found.png` | compact window | 1440x900 | The compact window after "/brief Zephyr Quartz Holdings": a card marked NOT FOUND that reads "No account matches "Zephyr Quartz Holdings". Try a fuller or different account name." |
| 01 | `fr2-01-several-matches.png` | compact window | 1440x900 | The compact window after "/brief United Oil": "Several accounts match "United Oil". Which one?" and three buttons, United Oil & Gas Corp. — New York, United Oil & Gas, Singapore — Singapore and United Oil & Gas, UK — no city |
| 02 | `fr2-02-explorer-compact.png` | compact window | 1440x900 | The compact window with the scope set to Whole org: the question "Which 5 open opportunities have the largest amounts?", a short answer, "The largest open opportunity is Juniper Project B at $293,920. These are the top 5 by amount.", and a table card that the narrow window shows as one block per row: Juniper Project B with its Amount, Account, Stage and Close Date, then the start of Fernhollow Project C |
| 02 | `fr2-02-explorer-rail.png` | right rail | 1440x900 | The same answer after Expand, in the right rail: the table card as a table with Name, Amount, Account, Stage and Close columns and five rows from Juniper Project B to United Oil Singapore Terminal Link (the Close column is cut at the rail's edge), "Showing 5 of 36 rows", and a folded "Ran 1 query" trail |
| 02 | `fr2-02-drill.gif` | compact window | 900x563 | In the compact window, a click on Juniper Project B in the table card opens its drill view under the breadcrumb "Conversation > Juniper Project B", with Stage, Amount, Close Date, Probability, Forecast Category, Account and Owner, and a click on Conversation goes back to the answer |
| 03 | `fr2-03-hotkey.gif` | compact window, then right rail | 900x563 | Cmd-K opens the compact window, "/brief Zephyr Quartz Holdings" is typed and answered at once with the NOT FOUND card, Minimize hides the window and the launcher comes back, Cmd-K opens it again with the same thread, and Expand moves that thread into the right rail beside the "About Edge Communications" column |
| 03 | `fr2-compact-launcher.png` | launcher | 1440x900 | The Edge Communications record page with the compact window closed: the launcher "Ask Customer Summary ⌘K" at the bottom right, above the utility bar |
| 03 | `fr2-compact-open.png` | compact window | 1440x900 | The same page after Cmd-K: the 420 by 560 window at the bottom right with Expand and Minimize, the brand row with History and Summarize, the empty state with two suggested questions, the quick chips and the focused composer |
| 05 | `fr2-05-followup-compact.png` | compact window | 1440x900 | The compact window with the follow-up "In one sentence, what is the main risk in that summary?" answered from the summary above it: "The main risk is that the support renewal at $125,540 is overdue and a high-priority escalated case is disrupting core BGP routing, which could jeopardize the renewal conversation.", then an Ask next card with four suggested questions |
| 05 | `fr2-05-followup-rail.png` | right rail | 1440x900 | The same thread after Expand, in the right rail: the summary's folded section cards, then the follow-up and its answer and the Ask next card in the conversation column, beside the "About Edge Communications" column |
| 05 | `fr2-05-reopened-compact.png` | compact window | 1440x900 | The compact window after History: an earlier conversation about the account reopened, its turns back in the thread, two Summary requests and their answers, the first "The support plan renewal is nine days overdue and a high-priority BGP outage has been escalated for two days." |
| 05 | `fr2-05-reopened-rail.png` | right rail | 1440x900 | The right rail with History open: "Earlier conversations about Edge Communications", each row a first question, a date and a turn count, with New conversation above them |
| 05 | `fr2-05-outcomes-rail.png` | right rail (context column) | 1440x900 | The right rail with History open in the conversation column and the context column scrolled to the account's outcomes: the History timeline, newest first, each entry a date, a Summary link and a sentiment label, Concerned or At risk, with "Show 75 more" under it, then the "Sentiment over time" chart, labels only, with its points on the At risk and Concerned rows |
| 08 | `fr2-08-e2e-report.png` | none (the HTML report) | 1600x1800 (800x900, device scale 2) | The Playwright HTML report of the end-to-end run: All 30, Passed 30, Failed 0, Flaky 0, Skipped 12, a total time of 9.3 minutes, an Errors box with the two "Timed out waiting 560s" lines, then the spec files a11y-snapshot.spec.js, conversation-actions.spec.js and conversation-fr2.spec.js with their passed tests, each tagged mac and some smoke |
| 11 | `fr2-11-mic-compact.png` | compact window | 1440x900 | The compact window in its empty state with the mic button focused, a ring round it, between the composer and Send |
| 11 | `fr2-11-mic-rail.png` | right rail | 1440x900 | The right rail with History open and the empty state, and the mic button between the composer and Send at the foot of the conversation column |
| 12 | `fr2-rail-open.png` | right rail | 1440x900 | The Edge Communications record page with the rail open over its right side, 640 px wide and full height: the header with the agent name and ⌘⇧K, History open above one answered question, "How many open opportunities does this account have?", and its table card in the main column, and the context column with Open deals (5) and Recent activity (10) |
| 12 | `fr2-rail-context.png` | right rail (crop) | 640x900 | The rail alone, 640 by 900: the conversation beside the "About Edge Communications" column, showing Open deals with five deals and Recent activity cut off at its fifth row |
| 12 | `fr2-rail.gif` | compact window, then right rail | 900x563 | Cmd-K opens the compact window, a question is typed and answered, then Expand moves the same thread into the rail and the account's context fills beside it |
| 12 | `fr2-history-timeline.png` | right rail (context column) | 1440x900 | The rail with its context column scrolled to History: the timeline, newest first, each entry a date, a Summary link and a sentiment label, At risk or Concerned, with Show more under it, and the start of the sentiment chart below |
| 12 | `fr2-history-sentiment.png` | right rail (context column) | 1440x900 | The same rail with a point of the "Sentiment over time" chart focused: the chart is labels only, its points on the At risk and Concerned rows, and the focused point's text shows under it |
| 13 | `fr2-action-draft.png` | compact window | 1440x900 | The compact window after the "Create a follow-up" chip: a "Create a task" draft card marked NEEDS INPUT, Subject filled with "Send the renewal quote", Due outlined in red and marked "Needed", Contact empty, Related to Edge Communications, Priority Normal, and Confirm greyed out beside Edit and Cancel |
| 13 | `fr2-action-draft-rail.png` | right rail | 1440x900 | The same draft card in the right rail's conversation column, beside the "About Edge Communications" column: Subject filled, Due marked "Needed", Confirm off |
| 04 | none | none | text block | The `TRY` lines of `scripts/prompt-try.apex` (already on the page, not retaken) |
| 09 | none | none | text block | The unauthenticated `tools/list` call and its HTTP 401, labelled "not a real tool call", taken at 21:31Z |
| 10 | `brand-swap-before.png`, `brand-swap-after.png` | compact window (old frame) | reused | BE-24's pair, kept as on the page |
| README | `fr2-readme-hero.gif` | compact window, then right rail | 900x563 | Cmd-K opens the compact window, a summary of Edge Communications is asked for and arrives as a summary card, and Expand moves it into the right rail beside the account's context (pending the README amend) |
| README | `fr2-01-summary-compact.png`, `fr2-01-summary-rail.png` | one still per surface | 1440x900 | As on page 01 (pending the README amend) |

### Rows written

The model calls write the product's own session and outcome rows; nothing else was written.

Counted with `sf data query -o agent-probe` before the first capture and after the last one (after the full e2e run
that the report shows):

| Object | Before | After | Change |
|---|---|---|---|
| `Customer_Summary_Session__c` | 16 | 16 | none added; the runs wrote turns to sessions that already existed (5 sessions changed today) |
| `Customer_Outcome__c` | 90 | 104 | 14 added by the answered turns of the captures and the e2e run |
| `Task` | 11 | 11 | none: every draft stopped at Cancel |

Model calls: the summary-and-follow-up script ran five times while its framing was fixed (about 10 calls),
`15-explorer` and `10-rail` made one each, and the full e2e run made about ten. No other script calls the model.

The e2e run behind `fr2-08-e2e-report.png` had a 560 s global limit, so it stopped after 30 of its 42 tests, all 30
passed; the 12 that did not run show as skipped in the report, and page 08 says so.

### What could not be captured, and why

- **Page 13's result card.** The Approvals row "FR2: e2e and agent tests that create a record" is not approved, so
  every draft was stopped at Cancel ("Cancelled. Nothing was saved.") and Confirm was never clicked.
- **Page 11's recording state** (`fr2-11-mic-listening.png`). With no stubbed recognizer, Enter on the mic showed no
  "Listening" status, no pressed state and no error within three seconds, so there is no still, and page 11 says the
  recording state is checked by hand.
- **The rail pushing the page.** The rail slides over the page; it does not push it, so page 12 shows it over the
  page and says so.
- **Page 10.** BE-24's before-and-after pair is reused, not retaken: a brand flip would change a record.
- **The README.** `README.md` is outside this card's scope. `fr2-readme-hero.gif` and the two surface stills
  (`fr2-01-summary-compact.png`, `fr2-01-summary-rail.png`) are taken; the hand-back asks for an amend to link them.
- **Mermaid.** The diagrams on the pages were not render-checked against the CDN; OPS-61 (parked) has that check.

What the frames show that a later card may want to look at: the follow-up answer's card shows an "EMPTY" badge in
the compact window; the rail's table card cuts its Close column at the rail's edge; the chip row is clipped at the
window's edge; History opens by default when the rail opens; the mic in the rail shows no visible focus ring.

### Old, still linked

Kept for OPS-36, which removes them once nothing links them; the full list is in
[MANIFEST.md](../assets/MANIFEST.md#old-still-linked). `README.md` links `brief-flow.gif` and `e2e-report.png`;
`docs/research/` links `agent-brief.png`, `panel-ask-agent.png`, the `fr2-cards-*` and the `fr2-spike-*` frames;
`docs/reviews/fr2-plan-review.md` links the FE-15 rail frames, retaken in place. Pages 01, 02 and 03 still link
old frames because their tests name them: page 01 links `not-found.png` and `ambiguous.png` outside `See it`, page
02 keeps `explore-answer.png`, `explore-drill.gif` and `drill-view.png`, and page 03 keeps `hotkey-open.gif` and
`panel-sections-open.png`, both under "Earlier frames" after the FR2 ones. No image was deleted or
renamed.

### Undo

- The session and outcome rows the model calls wrote (counted above) are the product's own rows, written the way
  any use of the panel writes them. To remove them, delete the 14 `Customer_Outcome__c` rows created on 2026-11-14
  after 90 were counted (the newest 14 by `CreatedDate`). No session row was added; the turns written to existing
  sessions are part of those sessions' history and can stay.
- No Task, Account, Opportunity or other record was created, edited or backdated; no deploy, setting or brand
  change was made. Nothing else to undo.
- To undo the files, revert this card's commit: it adds the `fr2-01-*`, `fr2-02-*`, `fr2-03-*`, `fr2-05-*`,
  `fr2-08-*`, `fr2-11-*`, `fr2-action-draft-rail` and `fr2-readme-hero` files, retakes eight FR2 frames in place,
  and changes only the `See it` parts of the pages.
