# FR2: standard chat limits, measured in agent-probe (BE-32)

Run 2026-11-13 in `agent-probe`, as the signed-in System Administrator, against `Customer_Summary` version 2 (active).
No agent was published, activated or changed, nothing was deployed, no user was created, no setting was changed, and
the org this was first built in was not touched. Ids, session Ids, usernames and hostnames are left out. Covers ledger
row F66 in [feature-revision-2.md](../plans/feature-revision-2.md); OPS-41 (chapter 00, "Why custom") builds on it.

## Result

- **The answer-length ceiling was not reached.** Up to 5,811 characters, the longest answer any existing action can
  return, the agent relayed every explore table whole in 18 of 18 runs: every row, every column, the row-count footer
  and every opportunity name. There was no loss at the top of the range, so the ceiling is above it. Above 5.9k it is
  **unmeasured**: no existing action returns more, and a larger one needs an agent change (see
  [What a changed agent would add](#what-a-changed-agent-would-add)).
- **The cap is ours, not the platform's.** `ExploreAction` clips its own answer to 5,900 characters before the agent
  sees it. On the same question the panel's direct Apex path showed all 47 rows (7,365 to 7,438 characters) where the
  agent's action stopped at 36 of 47. The repo's "keep each action's answer under about 6,000 characters" rule
  ([06](../patterns/06-agent-routing-and-verbatim-relay.md)) has no measurement behind it, and this run did not find
  the limit it guards against.
- **The agent did not relay the brief verbatim.** In 6 of 6 brief runs no section went missing: all six section labels
  were present. But the layout changed every time. The direct action put each label on its own line (6 of 6) with 4
  bullet lines. The relayed reply had 1 of 6 labels on its own line, the others starting a line that carries body
  text, and 0 bullet lines. That is 22 lines down to 17 or 18, although the script tells the agent to keep every line
  break, label line and "- " bullet.
- **Turns are slow.** 13 to 36 seconds an agent turn, against 5 to 9 seconds for the same explore question on the
  direct path.
- **Cards and the panel, from public docs.** A card in Agentforce's own panel needs a custom Lightning type, an Apex
  action and `is_displayable`. The output config decides whether it shows, not the model. No public doc found
  documents a hotkey, resizing, a pop-out, conversation history or branding for the employee panel. Details and
  sources below.

## Method

**Which agent.** Two agents are active in `agent-probe`: `Account_Brief` (version 2) and `Customer_Summary` (version
2). This run used `Customer_Summary`, the bundle in the repo and the one BE-34 called.

**Three paths, one question each.** Every run is its own anonymous Apex transaction, run by
[run.py](../../spikes/standard-limits/run.py):

| Path | Script | What it measures |
|---|---|---|
| Action, direct | [explore-direct.apex](../../spikes/standard-limits/explore-direct.apex), [brief-direct.apex](../../spikes/standard-limits/brief-direct.apex) | What the agent's own action class returns for the question: `ExploreAction.explore` (the 5,900-character cap) or `CustomerSummaryGetAction.getBriefs` |
| Panel path | the same explore script | `CustomerSummaryPanelController.explore`, the Apex the panel calls: the rows the panel would show, and the same plain-text table rendered without the cap |
| Agent | [agent-turn.apex](../../spikes/standard-limits/agent-turn.apex) | One first turn on a new session through `Invocable.Action.createCustomAction('generateAiAgentResponse', 'Customer_Summary')`; the text inside the `{"type":"Text","value":...}` envelope, so JSON escaping is not counted |

No REST Agent API, client app or consumer key was used.

**What cannot be seen.** The action's output inside an agent turn is not visible from Apex. The invocable action's
describe lists two outputs, `agentResponse` and `sessionId`. Session tracing is off in `agent-probe`: the retrieved
`AgentforceSessionTracing` setting reads `agentforceSTDMEnabled` false, and a read-only Data Cloud query of the session
trace object failed. So "action returned" in the tables is the direct call on the same question, a proxy. Loss in
the relay is judged on the relay alone, not by pairing:

- Explore: the table's column count from its header, the number of table rows with that column count, the
  `(x of y rows)` footer, and how many of the org's 47 opportunity names appear in the reply.
- Brief: the six section labels the synthesis prompt requires (Account, Open deals, People & engagement, Service
  health, Deal history, Watch next): on a line of their own, at the start of a line, and anywhere. Also bullet lines
  and lines in all.

The scripts print counts and booleans only, never text, names or Ids. Results:
[results/](../../spikes/standard-limits/results/).

**Rungs.** The explorer's table grows with rows and columns. Six wordings, frozen after a calibration on the direct path
(no agent turns), land at about 1.7k, 2.4k, 3.1k, 4.7k, 5.6k and 5.8k characters. The last one asks for 11 columns of
all 47 opportunities and is clipped by the cap. The brief is one rung (2.3k to 2.9k); its prompt keeps it "well under
4,000 characters". The wordings are in [rungs.json](../../spikes/standard-limits/rungs.json).

## Measurements

### Explore: an action's table through the agent

Each rung, three runs per path. "Missing" is YES when the relay differs from the action on rows, footer, names
or columns.

| Rung | Run | Action returned (chars) | Action table rows | Action footer | Agent relayed (chars) | Relayed rows | Relayed footer | Opportunity names in relay | Columns kept | Missing | Turn time | Panel path rows | Panel path chars |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| e1 | 1 | 1,674 | 20 | 20 of 47 | 1,673 | 20 | 20 of 47 | 20 | 4 of 4 | none | 18.3 s | 20 of 47 | 1,658 |
| e1 | 2 | 1,674 | 20 | 20 of 47 | 1,674 | 20 | 20 of 47 | 20 | 4 of 4 | none | 15.8 s | 20 of 47 | 1,657 |
| e1 | 3 | 1,661 | 20 | 20 of 47 | 1,639 | 20 | 20 of 47 | 20 | 4 of 4 | none | 13.2 s | 20 of 47 | 1,688 |
| e2 | 1 | 2,463 | 30 | 30 of 47 | 2,419 | 30 | 30 of 47 | 30 | 4 of 4 | none | 17.4 s | 30 of 47 | 2,404 |
| e2 | 2 | 2,443 | 30 | 30 of 47 | 2,420 | 30 | 30 of 47 | 30 | 4 of 4 | none | 16.7 s | 30 of 47 | 2,447 |
| e2 | 3 | 2,463 | 30 | 30 of 47 | 2,432 | 30 | 30 of 47 | 30 | 4 of 4 | none | 18.1 s | 30 of 47 | 2,447 |
| e3 | 1 | 3,182 | 40 | 40 of 47 | 3,165 | 40 | 40 of 47 | 40 | 4 of 4 | none | 21.5 s | 40 of 47 | 3,150 |
| e3 | 2 | 3,141 | 40 | 40 of 47 | 3,141 | 40 | 40 of 47 | 40 | 4 of 4 | none | 17.0 s | 40 of 47 | 3,169 |
| e3 | 3 | 3,124 | 40 | 40 of 47 | 3,184 | 40 | 40 of 47 | 40 | 4 of 4 | none | 19.0 s | 40 of 47 | 3,108 |
| e4 | 1 | 4,732 | 47 | none | 4,704 | 47 | none | 47 | 5 of 5 | none | 17.6 s | 47 of 47 | 4,704 |
| e4 | 2 | 4,704 | 47 | none | 4,697 | 47 | none | 47 | 5 of 5 | none | 22.6 s | 47 of 47 | 4,704 |
| e4 | 3 | 4,732 | 47 | none | 4,704 | 47 | none | 47 | 5 of 5 | none | 23.7 s | 47 of 47 | 4,697 |
| e5 | 1 | 5,644 | 47 | none | 5,641 | 47 | none | 47 | 8 of 8 | none | 16.9 s | 47 of 47 | 5,625 |
| e5 | 2 | 5,618 | 47 | none | 5,543 | 47 | none | 47 | 8 of 8 | none | 20.0 s | 47 of 47 | 5,591 |
| e5 | 3 | 5,586 | 47 | none | 5,590 | 47 | none | 47 | 8 of 8 | none | 25.9 s | 47 of 47 | 5,618 |
| e6 | 1 | 5,800 | 36 | 36 of 47 | 5,778 | 36 | 36 of 47 | 36 | 11 of 11 | none | 32.1 s | 47 of 47 | 7,438 |
| e6 | 2 | 5,768 | 36 | 36 of 47 | 5,774 | 36 | 36 of 47 | 36 | 11 of 11 | none | 33.1 s | 47 of 47 | 7,365 |
| e6 | 3 | 5,811 | 36 | 36 of 47 | 5,761 | 36 | 36 of 47 | 36 | 11 of 11 | none | 27.6 s | 47 of 47 | 7,365 |

The character counts on the two sides differ by up to about 100. That is the explorer's prose line, written fresh by
the model on each run, not the table. No relayed table was turned into markdown, and no reply ended with a question.
The direct calls took 5 to 9 seconds each.

### Brief: one account summary through the agent

Runs 1 to 3 counted labels on their own line only. Runs 4 to 6 added the line-start, anywhere and bullet counts, to
tell a reformatted section from a dropped one.

| Run | Action returned (chars) | Lines | Labels on own line | Bullet lines | Agent relayed (chars) | Lines | Labels on own line | Labels at a line start | Bullet lines | Sections missing | Turn time |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2,587 | 21 | 6 of 6 | not counted | 2,371 | 18 | 1 of 6 | not counted | not counted | not counted | 30.8 s |
| 2 | 2,722 | 22 | 6 of 6 | not counted | 2,275 | 18 | 1 of 6 | not counted | not counted | not counted | 31.0 s |
| 3 | 2,536 | 22 | 6 of 6 | not counted | 2,769 | 17 | 1 of 6 | not counted | not counted | not counted | 33.4 s |
| 4 | 2,572 | 22 | 6 of 6 | 4 | 2,584 | 18 | 1 of 6 | 6 of 6 | 0 | none (6 of 6 labels present) | 36.3 s |
| 5 | 2,719 | 22 | 6 of 6 | 4 | 2,690 | 18 | 1 of 6 | 6 of 6 | 0 | none (6 of 6 labels present) | 35.0 s |
| 6 | 2,806 | 22 | 6 of 6 | 4 | 2,857 | 18 | 1 of 6 | 6 of 6 | 0 | none (6 of 6 labels present) | 32.0 s |

## Findings

1. **No ceiling up to 5.8k characters, for tables.** 18 of 18 explore relays were whole, with no trend toward loss at
   the top rungs. Whether the published reasoning limits bite above this is unmeasured. One troubleshooting article
   gives "LLM response ~2048 tokens" and "Action output ~65,000 characters", and the agent considerations say "Agent
   action outputs over 65,000 characters are truncated" (Salesforce Help knowledge article 005305511; Salesforce Help
   article `ai.copilot_considerations.htm`). Tokens were not counted here, so how close e6 came to 2,048 is unknown.
2. **The real cut in our own chat path is our own cap.** At e6 the agent path showed 36 of 47 rows because
   `ExploreAction` clipped them. The panel path showed 47 of 47. A custom surface does not need the cap; the agent does,
   by our own rule.
3. **Verbatim relay holds for tables and not for formatted prose.** The script's relay instruction kept every table row,
   but the brief's layout was rewritten in 6 of 6 runs: labels pulled up onto body lines and bullet markers dropped.
   The content was not checked word for word (the scripts print no text), so only the label and line counts are
   proven. Whether the reasoning model or the platform reformats is not visible from Apex. Either way, Agentforce's
   own chat decides the final layout of a text answer, and the action's author does not.
4. **Latency is the cost that grows.** Turn time rose with answer size: 13 to 18 s at 1.7k, 28 to 33 s at 5.8k. The
   direct path took 5 to 9 s at every size.

## Rich cards in the standard chat (public docs)

How our surfaces show structured answers instead is FE-18's work (the card contract) and is not repeated here.

| Claim | Source |
|---|---|
| A custom card is a Lightning Type Bundle (metadata type, API 64.0 and later). `schema.json` is required; `editor.json` (input) and `renderer.json` (output) are optional overrides. `renderer.json` can render one item or a whole collection | [Lightning types core guide](https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-core.html) |
| An Apex-based type points `lightning:type` at an Apex class. Output overrides are LWCs with the `lightning__AgentforceOutput` target, which takes at most one `sourceType` | [Apex types](https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-apex.html), [AgentforceOutput target](https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-agentforce-output.html) |
| Overrides work only for actions that use Apex classes as input or output | [Lightning types in Agentforce](https://developer.salesforce.com/docs/ai/agentforce/guide/lightning-types.html) |
| Surfaces: the employee agent in Lightning Experience, the service agent through Enhanced Chat v2, mobile (the Mobile SDK added support in May 2026) and Experience Builder (no `renderer.json`; no Apex-based types). No Slack folder is listed for LWC overrides; only the HXL widgets (Beta) reach Slackbot and MCP clients | [core guide](https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-core.html), [HXL rich UI](https://developer.salesforce.com/docs/platform/hxl/guide/hxl-rich-ui.html), release note `release-notes.rn_lt_mobile_metadata.htm` |
| **Who decides:** the action's output config. In Agent Script, `is_displayable` "Must be True to display output that uses a custom Lightning type", and `complex_data_type_name` names the type; in the builder, "Show in conversation" plus "Output Rendering". No doc found has the model choosing a card | [Agent Script actions reference](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html), [HXL action output](https://developer.salesforce.com/docs/platform/hxl/guide/agentforce-action-output.html) |
| A misnamed type falls back to plain text "with no error message"; an input card needs the phrase `user_input` in the subagent's instructions | [Developers blog, May 2026](https://developer.salesforce.com/blogs/2026/05/use-custom-lightning-types-in-agent-script-for-rich-agent-ui) |
| A card did not render in the builder's preview while the agent was a draft; Winter '27 fixes this from the week of September 21, 2026 | [Agent Script recipes](https://developer.salesforce.com/sample-apps/agent-script-recipes/action-configuration/custom-lightning-types), release note `release-notes.rn_agentforce_clt_preview_local.htm` |
| Renaming or deleting the Apex class behind a type is prohibited; changing a field's type or removing a field is breaking | [Apex types](https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-apex.html) |
| With "Show in conversation" on, a plain text value shows "in a grey code-style box"; off, the agent interprets it and markdown renders | Salesforce Help knowledge article 005232619 |

**Unproven:** which markdown the employee panel renders (no public doc found), whether a card list has a size limit
(none found), and the inner-class versus top-level-class rule for Apex types (the Apex types guide and the May 2026
blog disagree). The Salesforce Engineering post on a `render:` directive was seen as a search snippet only.

## The launcher and panel

| Claim | Evidence |
|---|---|
| An active agent appears in the Agentforce panel in Lightning Experience and the mobile app for users with access; several agents share an agent picker, oldest first, active versions only | Salesforce Help article `ai.agent_deploy_emp_lex.htm` |
| The panel is available in Lightning Experience, the Salesforce mobile app, the Field Service mobile app and Sales Cloud Everywhere | Salesforce Help article `ai.copilot_considerations.htm` |
| Admin control of the welcome screen: 3 to 20 static prompts of 5 to 50 characters, up to three shown at a time, plus dynamic prompts | Salesforce Help article `ai.customize_welcome_reco_for_aea.htm` |
| A custom LWC can open, close, reset or send an utterance to the panel (`lightning/accApi`), desktop only, and "The execute method does not return the agent's textual response to your component" | [ACC API](https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html) |
| Branding tokens and custom images exist for the embedded web SDK, which renders in an iframe, not for the Lightning Experience panel | [ACC SDK tokens](https://developer.salesforce.com/docs/platform/accsdk/guide/acc-sdk-customize-tokens.html) |
| In `agent-probe`, the retrieved agent settings are on/off switches only: `AgentPlatform` (on), `EinsteinCopilot` (`enableEinsteinGptCopilot` off), `AgentforceSessionTracing` (off), `AgentforcePlatformTracing` (off). None carries a panel size, layout, hotkey or branding field | read-only retrieve to a folder outside the repo, this run |
| The panel docks over a record page, and a long reply runs under a scroll-down button above the message box | [agent-brief.png](../assets/agent-brief.png), from the earlier run in [06](../patterns/06-agent-routing-and-verbatim-relay.md) |

**Unproven.** No public doc was found for these, and the panel was not opened in this run. The only browser session
available was signed in to the org this was first built in, which is not to be touched, and signing in to
`agent-probe` is not allowed.

- whether the launcher is a header icon or a utility-bar item (one community thread says utility bar; search snippet only)
- its width and height, and whether it resizes, pops out or goes full screen (full screen is documented for the
  Setup agent only, in beta, search snippet only)
- a keyboard shortcut to open it
- the user's own conversation history (Winter '27 lists resuming past chats for "Agentforce Coworker", a different
  product as far as the release notes show)
- per-surface branding beyond the agent's name

## Fair to the platform

The standard chat is the right choice when:

- **No code is the point.** Deploying an employee agent "is as easy as activating your agent" (Salesforce Help article
  `ai.agent_deploy_emp_lex.htm`). There is no LWC, Apex controller or test to maintain for the chat itself.
- **One agent should reach several channels.** The same employee agent runs in the Lightning Experience panel, Slack and
  the mobile app (Salesforce Help article `ai.agent_employee_agent_considerations.htm`), though Slack and mobile need
  extra authentication or licensing steps.
- **The platform's own updates are wanted.** Streaming, progress status and card rendering come with the client
  ([ACC getting started](https://developer.salesforce.com/docs/platform/accsdk/guide/acc-get-started.html)), and each
  release adds to it (for example the Winter '27 card preview fix above) with no work in the org.
- **There is no developer.** Admins build in Agentforce Builder and can create custom Lightning types in Setup
  ([Lightning types get started](https://developer.salesforce.com/docs/ai/agentforce/guide/lightning-types-get-started.html)).
- **Trust Layer features apply** without wiring: toxicity detection, prompt defense and audit logging (Salesforce Help
  article `ai.agent_employee_agent_considerations.htm`).
- **Answers are short.** Every relay measured here up to 5.8k characters kept its table whole.

## What a changed agent would add

Every answer above 5.9k characters needs an action that returns more. That means a changed `ExploreAction` (a larger
`MAX_CHARS`) or a throwaway action that returns a sized block, plus a publish of the agent, and FR2 plans no further
agent publish. That run would add:

- the 8k, 12k and 16k rungs the card names, so the ceiling is found rather than bounded
- where the documented ~2,048-token reply limit cuts a relayed table, and whether it shows as dropped rows, a summary
  or an error
- with session tracing on (a setting change under its own Approvals row), the action's real output in the same turn,
  instead of the direct-call proxy

## Open questions

- The ceiling above 5.9k characters (see above).
- Whether the brief's reformatting comes from the reasoning model or the platform, and whether any word changed (the
  scripts count labels and lines, not words).
- Whether a non-admin user sees the same relay. Every run here was as an admin.
- The panel's size, hotkey, history and branding (see "Unproven").

## Model use and data written

- **Agent turns:** 24 through `generateAiAgentResponse`: 18 explore turns (three per rung) and 6 brief turns. Each is
  a first turn on its own new session.
- **Direct calls:** 24 recorded runs: 18 explore runs, each making two explorer runs (the action, then the panel path),
  and 6 brief runs. Another 10 explore runs on the direct path were discarded: 5 whose debug line the runner first
  failed to read, and 5 calibration runs of an earlier wording. They made no agent turns and wrote nothing.
- **Session rows written:** the product's own `Customer_Summary_Session__c`. The running user's rows stayed at 1, and
  its brief count went from 42 to 54. That is 12 brief turns, 6 direct and 6 through the agent, appended to the one
  existing row. Explore writes nothing.
- No Data Cloud query returned data, no trace flag was set and nothing was deployed.

## Undo

Nothing to undo in the org. The only data written is the 12 brief turns appended to the running user's existing
`Customer_Summary_Session__c` row, which the product writes on every brief anyway. The settings retrieve went to a
temporary folder outside the repo.
