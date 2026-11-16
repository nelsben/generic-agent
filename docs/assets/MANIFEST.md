# Asset manifest

Every screenshot and GIF the README and the pattern pages refer to. The image files are captured
from a real org with `npm run capture` (see [e2e/README.md](../../e2e/README.md#capture)). Every
file listed here is committed, and every image link in the pages resolves.

Pixel sizes are the file's own pixels (stills are taken at device scale 2). File sizes are in
KB of 1,024 bytes and MB of 1,048,576 bytes.

Pages 04 (model provider seam) and 09 (outside door, MCP) show a text block in `See it` and no image; page 09's
block is the unauthenticated call, labelled "not a real tool call".
Page 06 (agent routing) has two slots for the built-in Agentforce panel. They were captured in
the `agent-probe` org, where version 2 of Account_Brief, published from main with the current
script, is the active version (see [agent-iteration-1](../research/agent-iteration-1.md)).
`panel-ask-agent.png` shows the same agent answering inside the custom panel, through "Ask the
agent", in the same org (see [panel-agent-1](../research/panel-agent-1.md)).

FR2 retired `agent-brief.png`, `agent-explore.png` and `panel-ask-agent.png`: the built-in panel and
"Ask the agent" are no longer ways in, and their capture scripts are deleted. The files stay, and
the pages still link them, until the chapter cards and `OPS-36` rewrite those pages.

| File | What it shows | Used by | Status | Pixel size | File size |
|---|---|---|---|---|---|
| `fr2-readme-hero.gif` | Cmd-K opens the compact window on Edge Communications, "/brief Edge Communications" is typed and sent, the wait is cut, the summary arrives as a summary card, then Expand moves the thread into the rail, its context column shows skeletons and fills | README (pending its amend: README.md is outside OPS-52's scope) | captured by OPS-52, 2026-11-14 | 900x563 | 2.66 MB (13.8 s) |
| `fr2-01-summary.gif` | The same ask as the hero GIF, ending on the summary card in the compact window | [01](../patterns/01-route-gather-reduce.md) | captured by OPS-52, 2026-11-14 | 900x563 | 1.42 MB (9.6 s) |
| `fr2-01-summary-compact.png` | The compact window with "/brief Edge Communications" and the summary card: the headline about the overdue support renewal and the escalated BGP case, then the account summary (Account, Open deals) | [01](../patterns/01-route-gather-reduce.md), README (pending) | captured by OPS-52, 2026-11-14 | 1440x900 | 192 KB |
| `fr2-01-summary-rail.png` | The same summary in the right rail's conversation column, beside the "About Edge Communications" column | [01](../patterns/01-route-gather-reduce.md), README (pending) | captured by OPS-52, 2026-11-14 | 1440x900 | 287 KB |
| `fr2-01-not-found.png` | The compact window after "/brief Zephyr Quartz Holdings": the NOT FOUND card, "No account matches "Zephyr Quartz Holdings". Try a fuller or different account name." | [01](../patterns/01-route-gather-reduce.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 160 KB |
| `fr2-01-several-matches.png` | The compact window after "/brief United Oil": "Several accounts match "United Oil". Which one?" and three account buttons | [01](../patterns/01-route-gather-reduce.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 168 KB |
| `fr2-02-explorer-compact.png` | The compact window, scope Whole org: "Which 5 open opportunities have the largest amounts?", a two-sentence lead and the table card stacked one block per row | [02](../patterns/02-ask-anything-explorer.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 175 KB |
| `fr2-02-explorer-rail.png` | The same answer in the rail: the table card as a table of five rows (the Close column cut at the edge), "Showing 5 of 36 rows" and a folded "Ran 1 query" trail | [02](../patterns/02-ask-anything-explorer.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 258 KB |
| `fr2-02-drill.gif` | In the compact window, a click on Juniper Project B opens its drill view under "Conversation > Juniper Project B"; Conversation goes back to the answer | [02](../patterns/02-ask-anything-explorer.md) | captured by OPS-52, 2026-11-14 | 900x563 | 1007 KB (8.2 s) |
| `fr2-03-hotkey.gif` | Cmd-K opens the compact window, "/brief Zephyr Quartz Holdings" is answered by the resolver, Minimize, Cmd-K brings back the same thread, Expand moves it into the rail | [03](../patterns/03-hotkey-panel.md) | captured by OPS-52, 2026-11-14 | 900x563 | 2.66 MB (13.0 s) |
| `fr2-05-followup-compact.png` | The compact window with "In one sentence, what is the main risk in that summary?" answered from the summary above it, and an Ask next card with four questions | [05](../patterns/05-conversation-memory.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 178 KB |
| `fr2-05-followup-rail.png` | The same thread in the rail: the summary's folded section cards, the follow-up, its answer and Ask next | [05](../patterns/05-conversation-memory.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 242 KB |
| `fr2-05-reopened-compact.png` | The compact window with an earlier conversation reopened from History: two Summary turns and their answers | [05](../patterns/05-conversation-memory.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 176 KB |
| `fr2-05-reopened-rail.png` | The rail with History open: "Earlier conversations about Edge Communications", each with a first question, a date and a turn count | [05](../patterns/05-conversation-memory.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 252 KB |
| `fr2-05-outcomes-rail.png` | The rail with its context column at the account's outcomes: the History timeline (five entries, "Show 75 more") and the labels-only "Sentiment over time" chart | [05](../patterns/05-conversation-memory.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 237 KB |
| `fr2-08-e2e-report.png` | The Playwright HTML report of a full e2e run against the test org, cut at its 560 s limit: Passed 30, Failed 0, Skipped 12, the two timeout lines, then the first spec files | [08](../patterns/08-test-and-release-lifecycle.md) | captured by OPS-52, 2026-11-14 | 1600x1800 (800x900 at device scale 2) | 283 KB |
| `fr2-11-mic-compact.png` | The compact window in its empty state with the mic button focused between the composer and Send | [11](../patterns/11-voice-input.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 170 KB |
| `fr2-11-mic-rail.png` | The rail with History open and the empty state, the mic button between the composer and Send | [11](../patterns/11-voice-input.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 253 KB |
| `fr2-action-draft-rail.png` | The rail with the same "Create a task" draft card in its conversation column: Subject filled, Due marked "Needed", Confirm off | [13](../patterns/13-write-actions.md) | captured by OPS-52, 2026-11-14 | 1440x900 | 221 KB |
| `fr2-history-timeline.png` | FE-19: the rail with its context column scrolled to the History timeline, newest first, and the start of the sentiment chart | [12](../patterns/12-right-rail.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 236 KB |
| `fr2-history-sentiment.png` | FE-19: the same rail with a point of the labels-only "Sentiment over time" chart focused and its text under the chart | [12](../patterns/12-right-rail.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 241 KB |
| `brief-flow.gif` | The panel opens, "/brief Edge Communications" is typed and sent, a spinner shows, and the GIF ends on a settled frame with the headline, the "Full summary" toggle and the Account, Open deals and Service health rows | [README](../../README.md) | captured, old utility-panel frame; old, no longer linked by the README, for OPS-36 | 760x750 | 1.83 MB (12.0 s) |
| `panel-brief.png` | A finished brief under the one-row bar: the request, the headline, the collapsed "Full summary" toggle and the first three section rows (Account, Open deals, Service health) | none (page 01 shows the FR2 frames) | old utility-panel frame, unlinked, kept | 1520x1500 | 206 KB |
| `explore-answer.png` | The plain question "Which 5 open opportunities have the largest amounts?", a two-sentence answer over four lines (the total, the top opportunity, Juniper Project B, then the stages and close dates), and the result table's caption, its plain Name, Amount and Stage headers with no Id column, and its first two rows | [02](../patterns/02-ask-anything-explorer.md) | captured, old utility-panel frame; kept beside the FR2 frames because page 02's test names it | 1520x1500 | 222 KB |
| `explore-drill.gif` | The answer to "Which 5 open opportunities have the largest amounts?" with the table's first two rows; a click on the first row shows a spinner, then the drill view of Juniper Project B; the breadcrumb goes back to the conversation, which shows the end of the answer and the table's first three rows | [02](../patterns/02-ask-anything-explorer.md) | captured, old utility-panel frame; kept beside the FR2 frames because page 02's test names it | 760x750 | 1.09 MB (7.8 s) |
| `drill-view.png` | The drill view of Juniper Project B, the top row of "Which 5 open opportunities have the largest amounts?", under its breadcrumb, with plain field labels and no Id field | [02](../patterns/02-ask-anything-explorer.md) | captured, old utility-panel frame; kept beside the FR2 frames because page 02's test names it | 1520x1500 | 190 KB |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused, a question is typed, and Esc minimizes it | [03](../patterns/03-hotkey-panel.md) | captured, old utility-panel frame; kept beside the FR2 frames because page 03's test names it | 760x750 | 1.56 MB (8.3 s) |
| `panel-sections-open.png` | The panel at 340 px wide with the Open deals section expanded under the one-row bar | [03](../patterns/03-hotkey-panel.md) | captured, old utility-panel frame; kept beside the FR2 frames because page 03's test names it | 1520x1500 | 256 KB |
| `memory-followup.png` | A follow-up question answered from the earlier brief, then four suggested follow-ups | none (page 05 shows the FR2 frames) | old utility-panel frame, unlinked, kept | 1520x1500 | 232 KB |
| `agent-brief.png` | Version 2 of the agent in the built-in Agentforce panel in the Account Brief app, answering "Brief me on Edge Communications" | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 288 KB |
| `agent-explore.png` | Version 2 of the agent in the built-in Agentforce panel, answering an org-wide count question | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 153 KB |
| `panel-ask-agent.png` | "Ask the agent" in the custom panel on the Edge Communications page: the question "What are the open deals at this account?" at the top of the conversation and the start of the agent's reply ("Five open deals totaling $634,180 with two overdue opportunities requiring immediate attention." and the Open deals paragraph), with no built-in panel open | [03](../patterns/03-hotkey-panel.md), [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 241 KB |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account, "Try a fuller or different account name." | [01](../patterns/01-route-gather-reduce.md) (When something fails) | captured, old utility-panel frame; page 01's test names it outside See it | 1520x1500 | 187 KB |
| `ambiguous.png` | The AMBIGUOUS reply with its three candidate buttons | [01](../patterns/01-route-gather-reduce.md) (When something fails) | captured, old utility-panel frame; page 01's test names it outside See it | 1520x1500 | 207 KB |
| `e2e-report.png` | The Playwright HTML report for a full run: 8 of 8 passed, 3.1 minutes | [README](../../README.md) | captured; old, no longer linked by the README, for OPS-36; page 08 shows `fr2-08-e2e-report.png` | 1600x1800 | 274 KB |
| `brand-swap-before.png` | The open panel on Edge Communications with the shipped Default brand record: the plain blue logo mark and "Customer Summary" at the start of the bar, the blue Summarize button, and the empty state "Ask anything about Your Company's data" | [10](../patterns/10-brand-and-theming.md) | captured, old utility-panel frame | 1520x1500 | 184 KB |
| `brand-swap-after.png` | The same panel with the record swapped to the made-up Northwind Health: the green N monogram and "Northwind Assist" in Georgia, the green Summarize button, the pale green panel, Verdana text and the empty state "Ask anything about Northwind Health's data"; the utility title still reads "Customer Summary" | [10](../patterns/10-brand-and-theming.md) | captured, old utility-panel frame | 1520x1500 | 185 KB |
| `fr2-conversation-core.png` | FE-12: the whole window on Edge Communications with the panel open on the new conversation component in its empty state: the brand bar and its "Summarize" button (named "Summarize Edge Communications"), the Sections and Earlier summaries accordions, "Ask Customer Summary about Edge Communications", a suggestion, the Summarize, Open deals and Recent activity chips, and the composer ("Ask or /brief an account" on one line) with the mic and the disabled Send on the surface colour | none | captured; its script `08-conversation-core` removed by OPS-52; unlinked, kept | 1440x900 | 185 KB |
| `fr2-compact-launcher.png` | FE-13: the whole window on Edge Communications with the compact window closed: the launcher at the bottom right, its logo, "Ask Customer Summary" and the ⌘K key hint, over the Activity column, above the utility bar at its default left alignment | [03](../patterns/03-hotkey-panel.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 170 KB |
| `fr2-compact-open.png` | FE-13: the same page after Cmd-K: the 420x560 compact window in the bottom right corner with Expand and Minimize, the brand bar with History and Summarize, the Sections and Earlier summaries rows, the empty state with two suggestions, the quick chips, the scope chip and the focused composer with the mic; the launcher has scaled away | [03](../patterns/03-hotkey-panel.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 168 KB |
| `fr2-rail-open.png` | FE-15: the whole window on Edge Communications with the right rail open over the right of the page, 640 px wide and full height: the header with the logo, "Customer Summary" and the ⌘⇧K hint, the conversation with History open above one answered question and its table card, and the context column with Open deals (5) and Recent activity (10) | [12](../patterns/12-right-rail.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 256 KB |
| `fr2-rail-context.png` | FE-15: the rail alone, cropped from the same page: the conversation beside the "About Edge Communications" column with Open deals and Recent activity (cut off at its fifth row) | [12](../patterns/12-right-rail.md) | retaken by OPS-52, 2026-11-14 | 640x900 | 145 KB |
| `fr2-rail.gif` | FE-15: Cmd-K opens the compact window, a question about open opportunities is typed and answered, then Expand moves the same thread into the rail, the context column shows skeletons and fills with Open deals and Recent activity | [12](../patterns/12-right-rail.md) | retaken by OPS-52, 2026-11-14 | 900x563 | 2.17 MB (12.8 s) |
| `fr2-action-draft.png` | FE-14: the whole window on Edge Communications with the compact window open on a "Create a follow-up" turn: the draft card "Create a task" (Task · create, NEEDS INPUT) inside the turn, Subject filled, Due empty with its red border and "Needed", Contact empty, Related to Edge Communications as a link, Priority Normal, Description empty, and Confirm (off), Edit and Cancel; the quick chips with Create a follow-up and Log a call, the scope chip and the composer below. No result still: a result needs a saved record, and record-creating e2e runs are not approved | [13](../patterns/13-write-actions.md), [fr2-action-cards](../research/fr2-action-cards.md) | retaken by OPS-52, 2026-11-14 | 1440x900 | 163 KB |
| `fr2-spike-mirrored-bar.png` | OPS-29 spike: the bottom 200 px of a record page with the utility bar mirrored, "Phone (softphone stand-in)" and "Surface Spike" at the bottom right and the "Ask Customer Summary ⌘K" launcher just above them | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x200 | 34 KB |
| `fr2-spike-launcher.png` | OPS-29 spike: a record page in the FR2 Surface Spike app, the utility bar at the default left with the softphone stand-in, and the launcher at the bottom right | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 171 KB |
| `fr2-spike-compact.png` | OPS-29 spike: the 420 px compact window opened by Cmd-K above the launcher | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 137 KB |
| `fr2-spike-rail-sheet.png` | OPS-29 spike: the 480 px right rail as a slide-over sheet with a backdrop, opened by Cmd-Shift-K | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 127 KB |
| `fr2-spike-rail-push.png` | OPS-29 spike: the rail pushing the page, the header and the record reflowed into the left 960 px (an undocumented hack) | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 161 KB |
| `fr2-spike-rail-min.png` | OPS-29 spike: the rail minimized to a "Customer Summary" strip on the right edge, the page back at full width | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 175 KB |
| `fr2-spike-rail-hover.png` | OPS-29 spike: hovering the strip slides the rail back over the page without a backdrop | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 132 KB |
| `fr2-spike-lightning-shortcuts.png` | OPS-29 spike: Lightning's own Keyboard Shortcuts dialog (Mac, standard navigation), which has no K shortcut | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 231 KB |
| `fr2-spike-app-page.png` | OPS-29 spike: the spike's app page with the probe counting one Cmd-K and one Cmd-Shift-K, and the launcher at the bottom right; the opportunity list card is hidden because it shows an owner alias | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 75 KB |
| `fr2-cards-340-summary.png` | FE-18 spike: the summary group at 340 px (compact): the summary card with its headline, bold and italic runs and two bullets; the Open deals section folded; the Calls section folded with its error rule and Error badge; the Open pipeline metric with 212 as the hero; the Recent activity timeline | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 728x1590 | 123 KB |
| `fr2-cards-640-summary.png` | FE-18 spike: the same summary group at 640 px (rail): the metric figures side by side and the timeline on one line per item | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 1328x1262 | 129 KB |
| `fr2-cards-340-explorer.png` | FE-18 spike: the explorer group at 340 px: the answer with a record link and inline code; the 4-column result table stacked, 5 rows then "Show 1 more" under "Showing 6 of 212 rows"; the "Showing 50 of 212 rows" note; the trail folded; the Ask next chips; the comparison stacked by field; a record card with related chips; a list of records with its count | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 728x3648 | 299 KB |
| `fr2-cards-640-explorer.png` | FE-18 spike: the same explorer group at 640 px: the result table and the comparison as real tables, the list on one line per record | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 1328x2496 | 258 KB |
| `fr2-cards-340-actions.png` | FE-18 spike: the actions group at 340 px: the ambiguous-account choice with its Choose one badge; the Create a task draft (Needs input, two contact choices, Priority "Needed", Confirm, Edit and Cancel); the Task created result; the error card; and the three fallbacks (unknown type, newer version, a broken card) shown as their plain text | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 728x2360 | 177 KB |
| `fr2-cards-640-actions.png` | FE-18 spike: the same actions group at 640 px | [fr2-card-architecture](../research/fr2-card-architecture.md) | captured | 1328x2046 | 182 KB |
| `coworker-delegated-explore.png` | OPS-64: Coworker in `connect-24h` after "Use the Customer Summary agent to list the 30 opportunities with the earliest close dates, with their name, stage and amount.": the thinking step "Heard back from Customer Summary", then the relayed table, rows 1 to 9 of 30 (#, Opportunity, Stage, Amount, Close Date). Cropped by hand from a Chrome screenshot: no URL bar, header or user name | [coworker-calls-our-agent](../research/coworker-calls-our-agent.md) | captured by OPS-64, 2026-11-15 | 1288x937 | 307 KB |
| `coworker-delegated-summary.png` | OPS-64: the same Coworker chat area for a delegated Edge Communications summary, scrolled past the Account paragraph: the last opportunity cards, then People & Engagement, Service Health and Deal History as bold lead-ins, and the top priorities. Cropped by hand: no URL bar, header or user name | [coworker-calls-our-agent](../research/coworker-calls-our-agent.md) | captured by OPS-64, 2026-11-15 | 1372x874 | 363 KB |

The `fr2-spike-*.png` stills are whole-window captures kept at CSS scale (1440x900), not device
scale 2. They come from `e2e/capture/07-surface-spike.capture.js`, which a plain `npm run capture`
skips; see its header. `fr2-conversation-core.png` is the same kind of whole-window CSS-scale still,
from `e2e/capture/08-conversation-core.capture.js` (no model call).
`fr2-compact-launcher.png` and `fr2-compact-open.png` are whole-window CSS-scale stills too, from
`e2e/capture/09-compact.capture.js` (no model call). So is every still OPS-52 took (the `fr2-01-*`,
`fr2-02-*`, `fr2-05-*` and `fr2-11-*` stills and the retaken FE-13, FE-14, FE-15 and FE-19 stills),
except `fr2-rail-context.png` (the rail alone, 640x900) and `fr2-08-e2e-report.png` (device scale 2).
OPS-52's GIFs are cut from the same 1440x900 viewport and scaled to 900x563. The record of that run
is [fr2-captures.md](../research/fr2-captures.md). `08-conversation-core.capture.js`, which wrote
`fr2-conversation-core.png`, was removed by OPS-52 with the other utility-panel scripts.
The `fr2-cards-*.png` stills are device-scale 2 crops of one gallery column each (364 or 664 CSS px
wide, as tall as the group), not whole-window stills. They come from
`spikes/cards/__tests__/cards.capture.js`, run with its own config (see its header), not from
`npm run capture`; the cards are the spike's fixtures, with no model call and no org data.

Rows marked "old utility-panel frame" were captured before FE-13, when the conversation sat in
the 340x480 utility panel above the utility bar. Since FE-13 it is in the 420x560 compact window
at the bottom right (`fr2-compact-open.png`); the content inside is the same, the frame is not.
Their capture scripts were removed by OPS-52; the files stay while something links them.

## Old, still linked

For OPS-36: old frames that a file outside the pattern pages still links, so OPS-52 kept them.

| File | Linked from |
|---|---|
| `agent-brief.png` | [fr2-standard-limits](../research/fr2-standard-limits.md) |
| `panel-ask-agent.png` | [panel-agent-1](../research/panel-agent-1.md) |
| `fr2-rail-open.png`, `fr2-rail-context.png`, `fr2-rail.gif` | [fr2-plan-review](../reviews/fr2-plan-review.md) (retaken in place, so the review now shows the new frames) |
| `fr2-cards-*.png` | [fr2-card-architecture](../research/fr2-card-architecture.md) |
| `fr2-spike-*.png` | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) |

Page 01 still links `not-found.png` and `ambiguous.png` outside `See it`, page 02 links `explore-answer.png`,
`explore-drill.gif` and `drill-view.png`, and page 03 links `hotkey-open.gif` and `panel-sections-open.png`,
because those pages' tests name them; OPS-52's hand-back asks for an amend to let the tests drop them.
`panel-brief.png`, `memory-followup.png` and `fr2-conversation-core.png` are linked by no page, research note
or review any more (only by task cards and the burn plan), and are kept.

Rules for every capture: no record Ids, org Ids, usernames, the running user's name, email
addresses, URL bars or URLs with query strings in view. Use the seeded sample data only.
