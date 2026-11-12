# Asset manifest

Every screenshot and GIF the README and the pattern pages refer to. The image files are captured
from a real org with `npm run capture` (see [e2e/README.md](../../e2e/README.md#capture)). Every
file listed here is committed, and every image link in the pages resolves.

Pixel sizes are the file's own pixels (stills are taken at device scale 2).

Pages 04 (model provider seam) and 09 (outside door, MCP) use diagrams only and have no slots.
Page 06 (agent routing) has no slots either: its two planned shots of the built-in Agentforce
panel were removed, because no agent version with the current script is active. Only version 1
is active, and publishing a newer version fails with a server 401 (see
[agent-publish-spike](../research/agent-publish-spike.md)). Add them back once a version with that
script is active.

| File | What it must show | Used by | Status | Pixel size | File size |
|---|---|---|---|---|---|
| `brief-flow.gif` | Press Cmd/Ctrl-K, type "/brief Edge Communications", and the headline and sections arrive | [README](../../README.md), [01](../patterns/01-route-gather-reduce.md) | captured | 760x750 | 2.16 MB (14.2 s) |
| `panel-brief.png` | A finished brief with its sections collapsed | [01](../patterns/01-route-gather-reduce.md) | captured | 1520x1500 | 194 KB |
| `explore-answer.png` | An org-wide question answered with a result table | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 189 KB |
| `explore-drill.gif` | Click a result row, the drill view opens, the breadcrumb goes back | [02](../patterns/02-ask-anything-explorer.md) | captured | 760x750 | 892 KB (7.7 s) |
| `drill-view.png` | The drill view of one record | [02](../patterns/02-ask-anything-explorer.md) | captured | 1520x1500 | 194 KB |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused, and Esc closes it | [03](../patterns/03-hotkey-panel.md) | captured | 760x750 | 1.19 MB (8.4 s) |
| `panel-sections-open.png` | The panel at 340 px wide with two brief sections expanded | [03](../patterns/03-hotkey-panel.md) | captured | 1520x1500 | 205 KB |
| `memory-followup.png` | A follow-up question answered from the earlier brief | [05](../patterns/05-conversation-memory.md) | captured | 1520x1500 | 220 KB |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 179 KB |
| `ambiguous.png` | The AMBIGUOUS reply with its candidate lines | [07](../patterns/07-trust-access-and-failure.md) | captured | 1520x1500 | 198 KB |
| `e2e-report.png` | The Playwright HTML report for a full run | [README](../../README.md), [03](../patterns/03-hotkey-panel.md), [08](../patterns/08-test-and-release-lifecycle.md) | captured | 1600x1800 | 265 KB |

Rules for every capture: no record Ids, org Ids, usernames, email addresses or URLs with query
strings in view. Use the Salesforce demo accounts only.
