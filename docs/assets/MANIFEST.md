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
| `agent-brief.png` | Version 2 of the agent in the built-in Agentforce panel in the Account Brief app, answering "Brief me on Edge Communications" | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | captured | 1520x1500 | 288 KB |
| `agent-explore.png` | Version 2 of the agent in the built-in Agentforce panel, answering an org-wide count question | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | captured | 1520x1500 | 153 KB |
| `panel-ask-agent.png` | "Ask the agent" in the custom panel on the Edge Communications page: the question "What are the open deals at this account?" at the top of the conversation and the start of the agent's reply ("Five open deals totaling $634,180 with two overdue opportunities requiring immediate attention." and the Open deals paragraph), with no built-in panel open | [03](../patterns/03-hotkey-panel.md), [06](../patterns/06-agent-routing-and-verbatim-relay.md) | captured | 1520x1500 | 241 KB |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account, "Try a fuller or different account name." | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 187 KB |
| `ambiguous.png` | The AMBIGUOUS reply with its three candidate buttons | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 207 KB |
| `e2e-report.png` | The Playwright HTML report for a full run: 8 of 8 passed, 3.1 minutes | [README](../../README.md), [03](../patterns/03-hotkey-panel.md), [08](../patterns/08-test-and-release-lifecycle.md) | captured | 1600x1800 | 274 KB |

Rules for every capture: no record Ids, org Ids, usernames, the running user's name, email
addresses, URL bars or URLs with query strings in view. Use the seeded sample data only.
