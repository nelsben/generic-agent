# Asset manifest

Every screenshot and GIF the README and the pattern pages refer to. The image files are captured
from a real org with `npm run capture` (see [e2e/README.md](../../e2e/README.md#capture)). Every
file listed here is committed, and every image link in the pages resolves.

Pixel sizes are the file's own pixels (stills are taken at device scale 2). File sizes are in
KB of 1,024 bytes and MB of 1,048,576 bytes.

Pages 04 (model provider seam) and 09 (outside door, MCP) use diagrams only and have no slots.
Page 06 (agent routing) has two slots for the built-in Agentforce panel. They were captured in
the `agent-probe` org, where version 1 of Account_Brief, published from main with the current
script, is the active version (see [org-migration](../research/org-migration.md)).

| File | What it shows | Used by | Status | Pixel size | File size |
|---|---|---|---|---|---|
| `brief-flow.gif` | The panel opens, "/brief Edge Communications" is typed and sent, the brief arrives, and the GIF ends on a settled frame with the headline | [README](../../README.md), [01](../patterns/01-route-gather-reduce.md) | captured | 760x750 | 1.91 MB (12.0 s) |
| `panel-brief.png` | A finished brief scrolled to its headline sentence and the start of the summary; the sections are below, out of view | [01](../patterns/01-route-gather-reduce.md) | captured | 1520x1500 | 207 KB |
| `explore-answer.png` | The result table for an org-wide question: its caption, header row, first row and the top of the second; the question and one-line answer are above, out of view | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 198 KB |
| `explore-drill.gif` | Click a result row, the drill view opens, the breadcrumb goes back | [02](../patterns/02-ask-anything-explorer.md) | captured | 760x750 | 1011 KB (7.8 s) |
| `drill-view.png` | The drill view of one record | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 190 KB |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused, a question is typed, and Esc minimizes it | [03](../patterns/03-hotkey-panel.md) | captured | 760x750 | 1.37 MB (8.0 s) |
| `panel-sections-open.png` | The panel at 340 px wide with the Open deals section expanded | [03](../patterns/03-hotkey-panel.md) | captured | 1520x1500 | 216 KB |
| `memory-followup.png` | A follow-up question answered from the earlier brief | [05](../patterns/05-conversation-memory.md) | captured | 1520x1500 | 206 KB |
| `agent-brief.png` | The built-in Agentforce panel in the Account Brief app answering "Brief me on Edge Communications" | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | captured | 1520x1500 | 291 KB |
| `agent-explore.png` | The built-in Agentforce panel answering an org-wide count question | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | captured | 1520x1500 | 148 KB |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 189 KB |
| `ambiguous.png` | The AMBIGUOUS reply with its candidate lines | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 206 KB |
| `e2e-report.png` | The Playwright HTML report for a full run | [README](../../README.md), [03](../patterns/03-hotkey-panel.md), [08](../patterns/08-test-and-release-lifecycle.md) | captured | 1600x1800 | 267 KB |

Rules for every capture: no record Ids, org Ids, usernames, the running user's name, email
addresses, URL bars or URLs with query strings in view. Use the seeded sample data only.
