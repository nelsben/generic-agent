# Account Brief: a reusable Agentforce baseline

**One keystroke in Salesforce gives a rep a sourced account brief or an answer about their CRM
data, using only the records that rep is allowed to see.**

![A rep presses Cmd-K, types "/brief Edge Communications", and the headline and sections arrive in the panel](docs/assets/brief-flow.gif)

This repo is a working Salesforce DX project. It holds an Agentforce Employee agent, a Lightning
utility-bar panel, and the Apex behind both. Each part is written up as a pattern you can copy
into your own org. Everything under the agent is Apex. There are no Flows and no prompt template
metadata: prompts are plain-text static resources.

## What you get

| # | Pattern | Business outcome | Page |
|---|---|---|---|
| 1 | Route, gather, reduce | A full account brief in one ask. Every fact comes from the CRM, and the model only writes it up. | [01](docs/patterns/01-route-gather-reduce.md) |
| 2 | Ask-anything explorer | Org-wide questions answered with a table, and rows open to their related records. The model never writes SOQL. | [02](docs/patterns/02-ask-anything-explorer.md) |
| 3 | Hotkey panel | Cmd/Ctrl-K from any page in the app. No tab switching and no lost place. | [03](docs/patterns/03-hotkey-panel.md) |
| 4 | Model provider seam | One class decides which model runs. You can swap it without touching the features. | [04](docs/patterns/04-model-provider-seam.md) |
| 5 | Conversation memory | Follow-ups work, and earlier briefs of an account are listed when you come back. | [05](docs/patterns/05-conversation-memory.md) |
| 6 | Agent routing and verbatim relay | The built-in Agentforce panel gives the same answers as the custom panel, word for word. | [06](docs/patterns/06-agent-routing-and-verbatim-relay.md) |
| 7 | Trust, access and failure | Users see only what they can already see. Failures read as one plain sentence, never a stack trace. | [07](docs/patterns/07-trust-access-and-failure.md) |
| 8 | Test and release lifecycle | Every change passes local, org and agent checks before anyone relies on it. | [08](docs/patterns/08-test-and-release-lifecycle.md) |
| 9 | Outside door (MCP) | Tools outside Salesforce can call the same actions under the same rules. Designed, not yet proven. | [09](docs/patterns/09-outside-door-mcp.md) |

## System map

```mermaid
flowchart LR
    U(["Rep in Lightning"]) --> P["accountBriefPanel<br/>utility bar, Cmd/Ctrl-K"]
    U --> AG["Account_Brief agent<br/>built-in Agentforce panel"]
    X["MCP client<br/>not yet proven"] -.-> ACT
    P --> C["AccountBriefPanelController"]
    AG --> ACT["Invocable actions<br/>AccountBriefResolver<br/>AccountBriefGetAction<br/>ExploreAction"]
    C --> B["AccountBrief<br/>7 sources, 2 pre-reduces, synthesis"]
    ACT --> B
    C --> DX["DataExplorer<br/>JSON plan, ExploreQuery"]
    ACT --> DX
    B --> L["AgentLlm"]
    DX --> L
    L --> M["Salesforce Models API"]
    B --> D[("CRM records<br/>USER_MODE")]
    DX --> D
    B --> MEM[("Account_Brief_Session__c<br/>AccountBriefMemory")]
```

The panel calls Apex directly, so it answers in one request. The agent reaches the same Apex
through invocable actions. Both paths share one engine, one model door and one access rule.

## See it in 5 minutes

You need an org with Einstein generative AI and Agentforce turned on, the Salesforce CLI
signed in to it, and at least one Account with some contacts, deals and cases.

1. Deploy the metadata. Leave the agent bundle out: it has its own lifecycle (see the note below).

   ```sh
   sf project deploy start -o <org-alias> \
     --source-dir force-app/main/default/classes \
     --source-dir force-app/main/default/lwc \
     --source-dir force-app/main/default/staticresources \
     --source-dir force-app/main/default/objects \
     --source-dir force-app/main/default/messageChannels \
     --source-dir force-app/main/default/flexipages \
     --source-dir force-app/main/default/applications \
     --source-dir force-app/main/default/permissionsets
   ```

2. Assign the two permission sets to yourself:

   ```sh
   sf org assign permset -o <org-alias> -n Account_Brief_Data_Access -n Account_Brief_Agent_Access
   ```

3. Open the org with `sf org open -o <org-alias>` and pick **Account Brief** in the App Launcher.
4. Press **Cmd-K** on a Mac or **Ctrl-K** elsewhere. Type `/brief <account name>` and press Enter.
   Any other text is a question for the explorer, such as "How many open opportunities are there?".

The agent in the built-in Agentforce panel needs one more step: save, preview and publish the
`Account_Brief` bundle in Agentforce Studio. The CLI publish fails today with a server error
([agent-publish-failure.md](docs/research/agent-publish-failure.md)). The panel path above does
not depend on it.

## How it is tested

| Layer | What it checks | Command |
|---|---|---|
| Python | Metadata shape: agent script rules, permission sets, the app, the gate scripts | `python3 -m unittest discover -s tests` |
| Apex | Engine, sections, resolver, memory, explorer, model door and controller. No test calls a model. | `bash scripts/validate-org.sh`: a check-only deploy that runs every `*Test` class and saves nothing |
| Jest | The panel: hotkey, latest request wins, focus, live region, drill, axe | `npm run test:unit` |
| Playwright | The panel in a real org, 8 specs | `npm run test:e2e` (see [e2e/README.md](e2e/README.md)) |
| Agent compile | The Agent Script compiles locally and validates in the org | `bash scripts/agent-check.sh` |
| Agent test spec | 12 utterances with expected routes and outcomes | [Account_Brief-testSpec.yaml](tests/agent/Account_Brief-testSpec.yaml): `sf agent test create --spec <file> --api-name <test-name> -o <org-alias>`, then `sf agent test run --api-name <test-name> --wait 5 --json -o <org-alias>` on an active version |
| Studio preview | Every spec case run live against the draft agent | Recorded in [studio-preview.md](docs/research/studio-preview.md) |

The method behind the layers is in [08: Test and release lifecycle](docs/patterns/08-test-and-release-lifecycle.md).

## Repo map

| Path | What is there |
|---|---|
| `force-app/main/default/aiAuthoringBundles/Account_Brief/` | The agent, in Agent Script |
| `force-app/main/default/classes/` | All Apex: the brief engine and its 7 sections, the explorer, the model door, memory, the panel controller, and a test class for each |
| `force-app/main/default/lwc/accountBriefPanel/` | The utility-bar panel and its Jest tests |
| `force-app/main/default/staticresources/` | The four prompts (`AgentPrompt_*`) |
| `force-app/main/default/objects/Account_Brief_Session__c/` | The memory object |
| `force-app/main/default/permissionsets/` | `Account_Brief_Data_Access` and `Account_Brief_Agent_Access` |
| `force-app/main/default/applications/`, `flexipages/`, `messageChannels/` | The app, its utility bar and the `AccountBriefOpen` channel |
| `tests/` | Python metadata tests and the agent test spec |
| `e2e/` | The Playwright suite |
| `scripts/` | The gates: `validate-org.sh`, `agent-check.sh`, `apex-scan.sh` |
| `docs/patterns/` | The nine pattern pages |
| `docs/ARCHITECTURE.md` | The engineer reference: class map, how to add a source or a provider, rules |
| `docs/reviews/`, `docs/research/` | The code reviews and recorded platform probes this README points to |

## Status

| Item | Status | Evidence |
|---|---|---|
| Brief engine, explorer, memory, controller | Proven by Apex tests | The `*Test.cls` classes in `force-app/main/default/classes/`, run by `scripts/validate-org.sh` |
| Panel behaviour | Proven by Jest | [accountBriefPanel.test.js](force-app/main/default/lwc/accountBriefPanel/__tests__/accountBriefPanel.test.js) |
| Agent routing, 12 cases | Proven in Studio preview against the draft | [studio-preview.md](docs/research/studio-preview.md) |
| Calling the agent from Apex | Proven by a two-turn probe | [agent-api.md](docs/research/agent-api.md) |
| An MCP server lists and adds the actions as tools | Proven by a probe | [salesforce-mcp.md](docs/research/salesforce-mcp.md) |
| Panel in a real org | Partly proven: 6 of 8 specs passed before the Esc focus and brief-line drill fixes | [e2e/README.md](e2e/README.md) |
| A run as a non-admin user | **Not yet proven** | Only Apex `runAs` tests so far; see [07](docs/patterns/07-trust-access-and-failure.md) |
| A real MCP tool call | **Not yet proven** | See [09](docs/patterns/09-outside-door-mcp.md) |
| The panel calling the registered agent | **Not yet proven**, not built | See [06](docs/patterns/06-agent-routing-and-verbatim-relay.md) |
| Agent version 2 published and active | **Not yet proven** | The CLI publish fails; see [agent-publish-failure.md](docs/research/agent-publish-failure.md) |
| Agent test spec run in the org | **Not yet proven** | Written and shape-tested in Python; it needs an active version |
