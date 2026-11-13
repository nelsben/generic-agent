# Asset manifest

Every screenshot and GIF the README and the pattern pages refer to. The image files are captured
from a real org with `npm run capture` (see [e2e/README.md](../../e2e/README.md#capture)). Every
file listed here is committed, and every image link in the pages resolves.

Pixel sizes are the file's own pixels (stills are taken at device scale 2). File sizes are in
KB of 1,024 bytes and MB of 1,048,576 bytes.

Pages 04 (model provider seam) and 09 (outside door, MCP) use diagrams only and have no slots.
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
| `brief-flow.gif` | The panel opens, "/brief Edge Communications" is typed and sent, a spinner shows, and the GIF ends on a settled frame with the headline, the "Full summary" toggle and the Account, Open deals and Service health rows | [README](../../README.md), [01](../patterns/01-route-gather-reduce.md) | captured | 760x750 | 1.83 MB (12.0 s) |
| `panel-brief.png` | A finished brief under the one-row bar: the request, the headline, the collapsed "Full summary" toggle and the first three section rows (Account, Open deals, Service health) | [01](../patterns/01-route-gather-reduce.md) | captured | 1520x1500 | 206 KB |
| `explore-answer.png` | The plain question "Which 5 open opportunities have the largest amounts?", a two-sentence answer over four lines (the total, the top opportunity, Juniper Project B, then the stages and close dates), and the result table's caption, its plain Name, Amount and Stage headers with no Id column, and its first two rows | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 222 KB |
| `explore-drill.gif` | The answer to "Which 5 open opportunities have the largest amounts?" with the table's first two rows; a click on the first row shows a spinner, then the drill view of Juniper Project B; the breadcrumb goes back to the conversation, which shows the end of the answer and the table's first three rows | [02](../patterns/02-ask-anything-explorer.md) | captured | 760x750 | 1.09 MB (7.8 s) |
| `drill-view.png` | The drill view of Juniper Project B, the top row of "Which 5 open opportunities have the largest amounts?", under its breadcrumb, with plain field labels and no Id field | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 190 KB |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused, a question is typed, and Esc minimizes it | [03](../patterns/03-hotkey-panel.md) | captured | 760x750 | 1.56 MB (8.3 s) |
| `panel-sections-open.png` | The panel at 340 px wide with the Open deals section expanded under the one-row bar | [03](../patterns/03-hotkey-panel.md) | captured | 1520x1500 | 256 KB |
| `memory-followup.png` | A follow-up question answered from the earlier brief, then four suggested follow-ups | [05](../patterns/05-conversation-memory.md) | captured | 1520x1500 | 232 KB |
| `agent-brief.png` | Version 2 of the agent in the built-in Agentforce panel in the Account Brief app, answering "Brief me on Edge Communications" | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 288 KB |
| `agent-explore.png` | Version 2 of the agent in the built-in Agentforce panel, answering an org-wide count question | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 153 KB |
| `panel-ask-agent.png` | "Ask the agent" in the custom panel on the Edge Communications page: the question "What are the open deals at this account?" at the top of the conversation and the start of the agent's reply ("Five open deals totaling $634,180 with two overdue opportunities requiring immediate attention." and the Open deals paragraph), with no built-in panel open | [03](../patterns/03-hotkey-panel.md), [06](../patterns/06-agent-routing-and-verbatim-relay.md) | retired, still linked | 1520x1500 | 241 KB |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account, "Try a fuller or different account name." | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 187 KB |
| `ambiguous.png` | The AMBIGUOUS reply with its three candidate buttons | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 207 KB |
| `e2e-report.png` | The Playwright HTML report for a full run: 8 of 8 passed, 3.1 minutes | [README](../../README.md), [03](../patterns/03-hotkey-panel.md), [08](../patterns/08-test-and-release-lifecycle.md) | captured | 1600x1800 | 274 KB |
| `brand-swap-before.png` | The open panel on Edge Communications with the shipped Default brand record: the plain blue logo mark and "Customer Summary" at the start of the bar, the blue Summarize button, and the empty state "Ask anything about Your Company's data" | [10](../patterns/10-brand-and-theming.md) | captured | 1520x1500 | 184 KB |
| `brand-swap-after.png` | The same panel with the record swapped to the made-up Northwind Health: the green N monogram and "Northwind Assist" in Georgia, the green Summarize button, the pale green panel, Verdana text and the empty state "Ask anything about Northwind Health's data"; the utility title still reads "Customer Summary" | [10](../patterns/10-brand-and-theming.md) | captured | 1520x1500 | 185 KB |
| `fr2-conversation-core.png` | FE-12: the whole window on Edge Communications with the panel open on the new conversation component in its empty state: the brand bar and its "Summarize" button (named "Summarize Edge Communications"), the Sections and Earlier summaries accordions, "Ask Customer Summary about Edge Communications", a suggestion, the Summarize, Open deals and Recent activity chips, and the composer ("Ask or /brief an account" on one line) with the mic and the disabled Send on the surface colour | FE-12 hand-back (no page yet) | captured | 1440x900 | 185 KB |
| `fr2-spike-mirrored-bar.png` | OPS-29 spike: the bottom 200 px of a record page with the utility bar mirrored, "Phone (softphone stand-in)" and "Surface Spike" at the bottom right and the "Ask Customer Summary ⌘K" launcher just above them | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x200 | 34 KB |
| `fr2-spike-launcher.png` | OPS-29 spike: a record page in the FR2 Surface Spike app, the utility bar at the default left with the softphone stand-in, and the launcher at the bottom right | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 171 KB |
| `fr2-spike-compact.png` | OPS-29 spike: the 420 px compact window opened by Cmd-K above the launcher | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 137 KB |
| `fr2-spike-rail-sheet.png` | OPS-29 spike: the 480 px right rail as a slide-over sheet with a backdrop, opened by Cmd-Shift-K | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 127 KB |
| `fr2-spike-rail-push.png` | OPS-29 spike: the rail pushing the page, the header and the record reflowed into the left 960 px (an undocumented hack) | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 161 KB |
| `fr2-spike-rail-min.png` | OPS-29 spike: the rail minimized to a "Customer Summary" strip on the right edge, the page back at full width | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 175 KB |
| `fr2-spike-rail-hover.png` | OPS-29 spike: hovering the strip slides the rail back over the page without a backdrop | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 132 KB |
| `fr2-spike-lightning-shortcuts.png` | OPS-29 spike: Lightning's own Keyboard Shortcuts dialog (Mac, standard navigation), which has no K shortcut | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 231 KB |
| `fr2-spike-app-page.png` | OPS-29 spike: the spike's app page with the probe counting one Cmd-K and one Cmd-Shift-K, and the launcher at the bottom right; the opportunity list card is hidden because it shows an owner alias | [fr2-surfaces-spike](../research/fr2-surfaces-spike.md) | captured | 1440x900 | 75 KB |

The `fr2-spike-*.png` stills are whole-window captures kept at CSS scale (1440x900), not device
scale 2. They come from `e2e/capture/07-surface-spike.capture.js`, which a plain `npm run capture`
skips; see its header. `fr2-conversation-core.png` is the same kind of whole-window CSS-scale still,
from `e2e/capture/08-conversation-core.capture.js` (no model call).

Rules for every capture: no record Ids, org Ids, usernames, the running user's name, email
addresses, URL bars or URLs with query strings in view. Use the seeded sample data only.
