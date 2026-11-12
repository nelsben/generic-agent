# Asset manifest

Every screenshot and GIF the README and the pattern pages refer to. The image files are captured
from a real org and added later. Until a file is captured, its image link in the page does not
resolve.

Status is one of: `not captured`, `captured`. Capture sets a row to `captured`. The final pass
removes any slot that is still `not captured`, together with its line in the page.

Pages 04 (model provider seam) and 09 (outside door, MCP) use diagrams only and have no slots.

| File | What it must show | Used by | Status |
|---|---|---|---|
| `brief-flow.gif` | Press Cmd/Ctrl-K, type "/brief Edge Communications", and the headline and sections arrive | [README](../../README.md), [01](../patterns/01-route-gather-reduce.md) | not captured |
| `panel-brief.png` | A finished brief with its sections collapsed | [01](../patterns/01-route-gather-reduce.md) | not captured |
| `explore-answer.png` | An org-wide question answered with a result table | [02](../patterns/02-ask-anything-explorer.md) | not captured |
| `explore-drill.gif` | Click a result row, the drill view opens, the breadcrumb goes back | [02](../patterns/02-ask-anything-explorer.md) | not captured |
| `drill-view.png` | The drill view of one record | [02](../patterns/02-ask-anything-explorer.md) | not captured |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused, and Esc closes it | [03](../patterns/03-hotkey-panel.md) | not captured |
| `panel-sections-open.png` | The panel at 340 px wide with two brief sections expanded | [03](../patterns/03-hotkey-panel.md) | not captured |
| `memory-followup.png` | A follow-up question answered from the earlier brief | [05](../patterns/05-conversation-memory.md) | not captured |
| `agent-brief.png` | The built-in Agentforce panel briefing Edge Communications | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | not captured |
| `agent-explore.png` | The built-in Agentforce panel answering an org-wide count | [06](../patterns/06-agent-routing-and-verbatim-relay.md) | not captured |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account | [07](../patterns/07-trust-access-and-failure.md) | not captured |
| `ambiguous.png` | The AMBIGUOUS reply with its candidate lines | [07](../patterns/07-trust-access-and-failure.md) | not captured |
| `e2e-report.png` | The Playwright HTML report for a full run | [08](../patterns/08-test-and-release-lifecycle.md) | not captured |

Rules for every capture: no record Ids, org Ids, usernames, email addresses or URLs with query
strings in view. Use the Salesforce demo accounts only.
