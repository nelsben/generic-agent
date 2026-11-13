# FR2 rename go/no-go: publish a copy of the agent as Customer_Summary (BE-21)

- Date: 2026-11-13, 01:23 to 01:31 UTC (the evening of 2026-11-12 local). Org `agent-probe`
  (Developer Edition, `IsSandbox` false, API 68.0). This covers FR2 ledger rows F03 and F07 in
  [feature-revision-2.md](../plans/feature-revision-2.md).
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf` (`@salesforce/agents` 2.3.3). Local compiler:
  `@sf-agentscript/agentforce` 2.9.27 (npm), from the agentforce-generate skill.
- Approvals ([gtm-burn-plan.md](../plans/gtm-burn-plan.md), Approvals table), all "approved":
  - "FR2: spikes in `agent-probe`".
  - "FR2: publish and activate a copy of the agent as `Customer_Summary` (BE-21) ...".
  - The standing row "Production-classified deploys to `agent-probe`".
  - "FR2: live checks in `agent-probe` that spend model calls ...". This covers the one preview turn.
- Status words: verified (seen in a command result or an org query), unproven (inference).
- No record Ids, org Ids, job Ids, session Ids, usernames or hostnames are written here.

## Plain answer

- **GO.** The renamed copy published and activated, and its one preview turn returned a full summary
  of a sample account (verified).
  - `Customer_Summary`, label "Customer Summary", is published to agent-probe from
    `spikes/rename/`. Its version 1 is Active (verified).
  - `sf agent preview` through the published agent answered "Give me a summary of Edge
    Communications" with a full summary (verified).
  - The publish's create call, `POST /einstein/ai-agent/v1.1/authoring/agents`, returned HTTP 200
    after 5.4 s (verified in the capture).
  - The earlier "Error saving or updating agent graph" failure did not occur.
- **Account_Brief was not touched.** Its v2 is still Active and v1 Inactive, with the same
  last-modified time as before the run (verified before and after).
- **One new snag, on the client side, not the server:** the first publish attempt stopped before it
  reached the server. The CLI looks for the bundle only in the default package directory
  (`force-app`), so a bundle in `spikes/` cannot be published from this project.
  - The second attempt published from a temporary project outside the repo, whose default package
    directory held byte-identical copies of the two bundle files. It succeeded.
  - The renamed agent in OPS-51 will live in `force-app`, the default package directory, so this
    snag does not apply to it (inference from the code below).
- **Elapsed time:** about 4.5 minutes, from the start of the validate (01:25:21Z) to the end of the
  preview (01:29:54Z). The validate's 169 Apex tests take 81 s of that.
- **Two publish attempts were used, the card's maximum.** Attempt 1 never sent a create call.
- So the internal rename (BE-23, OPS-30) can go ahead with the agent bundle included, and OPS-51
  can publish the renamed agent by the path below.

## What this means for the rename cards

- **The name `Customer_Summary` is now taken in agent-probe by this spike's agent.**
  - OPS-51's publish of the renamed bundle will find this BotDefinition. It will call
    `POST .../authoring/agents/<id>/versions` and add version 2 to this agent, not create a new one.
  - This run exercised only the create call (`/authoring/agents`). The versions call is shown
    working in agent-probe for Account_Brief v2 ([agent-iteration-1.md](agent-iteration-1.md)), but
    not for `Customer_Summary` (unproven here).
- **Two bundles with one name (untested risk).** After BE-23, `force-app` and `spikes/rename` would
  both hold a bundle named `Customer_Summary`.
  - Publish looks only in `force-app`, so it would take the right one.
  - `sf agent validate authoring-bundle --api-name Customer_Summary` and `scripts/agent-check.sh`
    search every package directory, and could pick the spike copy or fail. This is not tested.
  - The simplest fix is for BE-23 to delete the repo folder `spikes/rename/` in the same change.
    That deletes files in git only, not anything in the org.
- **The old Apex stays pinned.** The skill's lifecycle reference says the org blocks deleting a
  backing Apex class while any authoring-bundle version references it.
  - Customer_Summary v1 targets `AccountBriefResolver`, `AccountBriefGetAction` and `ExploreAction`.
    Account_Brief v1 and v2 target the same classes.
  - So OPS-54 cannot remove the old `AccountBrief*` action classes while this version or the old
    agent exists, even after OPS-51 publishes a version on the new classes (inference from the
    reference; not tried).

## What was done, in order

| # | Step | Command (abridged) | Start to end (UTC) | Outcome |
|---|---|---|---|---|
| 1 | Approvals | read the Approvals table in `docs/plans/gtm-burn-plan.md` | n/a | The four rows above start with "approved" |
| 2 | Install, skills | `npm ci`; loaded agentforce-generate, agentforce-test, platform-metadata-deploy | n/a | ok |
| 3 | Org and state | `sf data query` Organization, BotVersion and BotDefinition (read-only) | 01:23 | Developer Edition, not a sandbox. Account_Brief v1 Inactive, v2 Active. 0 BotDefinitions named `Customer_Summary` |
| 4 | Spike bundle | copy `force-app/.../Account_Brief/` to `spikes/rename/main/default/aiAuthoringBundles/Customer_Summary/`, renaming both files; change `developer_name` and `agent_label` only | n/a | A 2-line diff against `Account_Brief.agent`. Actions still target `apex://AccountBriefResolver`, `apex://AccountBriefGetAction` and `apex://ExploreAction` |
| 5 | Local compile | `node <skill>/scripts/index-agent.mjs spikes/rename/.../Customer_Summary.agent` | n/a | exit 0, 0 diagnostics |
| 6 | Org validate of the bundle | `sf agent validate authoring-bundle --api-name Customer_Summary -o agent-probe --json` | n/a | `success` true. Compile finds bundles in every package directory |
| 7 | Commit | `git commit` of `spikes/rename/` | n/a | before any org write, because publish edits the `-meta.xml` |
| 8 | Deploy, validate | `sf project deploy validate --source-dir spikes/rename --test-level RunLocalTests -o agent-probe --wait 4 --json` | 01:25:21 to 01:26:42 | **Succeeded.** 1 of 1 component, 169 of 169 tests, 0 failures |
| 9 | Deploy, quick | `CONFIRM_PROD=1 sf project deploy quick --job-id <row 8> -o agent-probe --wait 10 --json` | 01:26:55 to 01:27:03 | **Succeeded.** 1 component deployed |
| 10 | Publish, attempt 1 | `SF_LOG_LEVEL=debug PUBLISH_CAPTURE_FILE=<scratch> NODE_OPTIONS="--require <scratch>/fetch-capture.cjs" sf agent publish authoring-bundle --api-name Customer_Summary -o agent-probe --skip-retrieve --json`, from the worktree | 01:27:34 to 01:27:37 | **Failed on the client.** `CannotFindBundle`: "Cannot find an authoring bundle in .../force-app that matches Customer_Summary". The capture shows `POST .../authoring/scripts` 200 twice and no create call. Queried afterwards: 0 BotDefinitions named `Customer_Summary` |
| 11 | Diagnosis | read `@salesforce/agents` 2.3.3 `lib/agents/scriptAgentPublisher.js` | n/a | See "Why attempt 1 failed" |
| 12 | Publish, attempt 2 | the same command, run from a temporary project outside the repo whose only, default package directory is `spikes/rename`, holding byte-identical copies (sha256 checked) | 01:28:18 to 01:28:33 | **Succeeded.** `success` true, `botDeveloperName` `Customer_Summary`, 3 components deployed. Capture: `scripts` 200 (808 ms), `scripts` 200 (267 ms), `POST .../authoring/agents` **200 (5382 ms)** |
| 13 | Versions | the BotVersion query below (read-only) | 01:28 | Customer_Summary v1 Inactive. Account_Brief unchanged |
| 14 | Activate | `sf agent activate --api-name Customer_Summary --version 1 -o agent-probe --json` | 01:28:51 to 01:28:54 | `success` true, version 1. BotVersion: Customer_Summary v1 Active; Account_Brief v2 still Active |
| 15 | Preview | `sf agent preview start --api-name Customer_Summary -o agent-probe --json`, then `send` with "Give me a summary of Edge Communications", then `end` | 01:29:02 to 01:29:54 (the send took 32 s) | **Pass.** One `Inform` message, 2844 characters, a full summary. See "Preview" |
| 16 | Inventory | `git grep`; `sf org list metadata`, `sf data query` counts (read-only) | 01:30 | The tables below |
| 17 | Gates | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`; `bash scripts/check-docs.sh` | n/a | See "Gates" |

The worktree's `spikes/rename/` bundle was never changed by a publish. Attempt 1 failed before its
`<target>` write, and attempt 2 wrote and removed its `<target>` line in the temporary project's copy
(its `-meta.xml` read back as `<bundleType>AGENT</bundleType>` only).

## Why attempt 1 failed

This is verified from the code of `@salesforce/agents` 2.3.3 in CLI 2.158.7.

- `ScriptAgent` finds the bundle to compile by searching every package directory. That is why
  `sf agent validate authoring-bundle` and the publish's two compile calls worked from `spikes/`.
- `ScriptAgentPublisher`'s constructor then calls `validateDeveloperName()`. That searches only
  `this.project.getDefaultPackage().path`, here `force-app`, and throws `CannotFindBundle` when the
  bundle is not there.
  - It does this before `publishAgentJson()` runs, so the create call is never sent.
- The publisher needs the bundle's local folder to write, deploy and remove the `<target>` line
  after the create.
- So with this CLI, a bundle outside the default package directory can be validated and compiled
  but not published. The workaround is a project in which the bundle's package directory is the
  default one.
- This is a different class of failure from the old org's 401 "Error saving or updating agent graph"
  ([agent-publish-spike.md](agent-publish-spike.md)). No server call failed.

## Agent versions

`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber`,
read-only:

| When | Agent | Version | Status | Last modified |
|---|---|---|---|---|
| Before (01:23Z) | Account_Brief | v1 | Inactive | 2026-11-12T07:51:53Z |
| Before (01:23Z) | Account_Brief | v2 | Active | 2026-11-12T07:51:53Z |
| After the publish | Customer_Summary | v1 | Inactive | 2026-11-13T01:28:24Z |
| After the activation | Account_Brief | v1 | Inactive | 2026-11-12T07:51:53Z (unchanged) |
| After the activation | Account_Brief | v2 | **Active** | 2026-11-12T07:51:53Z (unchanged) |
| After the activation | Customer_Summary | v1 | **Active** | 2026-11-13T01:28:53Z |

BotDefinition after the publish: `Account_Brief` (label "Account Brief") and `Customer_Summary`
(label "Customer Summary"). Both are `InternalCopilot` and `AgentforceEmployeeAgent`.

## Preview

One session through the published, active agent (`--api-name`, so live actions). The session Id was
kept in a scratch file, never printed, and deleted after `end`.

- Utterance: "Give me a summary of Edge Communications".
- Reply: one `Inform` message, 2844 characters. It is the same shape the panel and Account_Brief
  produce: a headline, then Account, Open deals, People & engagement and the further sections.
- It starts: "Two open deals are overdue, including the $125,540 support plan renewal that closed
  November 9, and a high-priority BGP issue has been escalated after one day."
- So the resolve-then-summary path ran through the renamed agent: `AccountBriefResolver`, then
  `AccountBriefGetAction` (inference from the reply; the trace was not read).
- Model calls: this one turn.
- Data written: one existing `Account_Brief_Session__c` row was updated, and none was created.
  - 0 rows were created since 01:29Z, and 1 row was modified: the Edge Communications row, at
    01:29:41Z, inside the send's window (verified).
  - That this preview made the update is an inference from the account and the time. Other cards
    also write to this org.

## The publish path that worked (for the rename card to repeat)

For OPS-51, the bundle is under `force-app` (the default package directory), so the temporary
project in step 5 is not needed. Run every command with `-o <alias>` and `--json`.

1. Read the Approvals row for the publish.
2. Run the local compile: `node <agentforce-generate skill>/scripts/index-agent.mjs <bundle>.agent`.
   It must show 0 errors.
3. Validate the bundle in the org: `sf agent validate authoring-bundle --api-name <Name> -o <alias> --json`.
4. Commit, so the publish's `-meta.xml` edit cannot mix with work.
5. Deploy the bundle (81 s + 8 s here):
   - `sf project deploy validate --source-dir <bundle's package path> --test-level RunLocalTests -o <alias> --wait 4 --json`
   - then `CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o <alias> --wait 10 --json`.
   - For a bundle outside the default package directory, publish from a temporary project whose
     default package directory holds byte-identical copies of the bundle, and check the sha256 of
     both files.
6. Publish once, with the capture (15 s here):
   `SF_LOG_LEVEL=debug PUBLISH_CAPTURE_FILE=<scratch>/x.jsonl NODE_OPTIONS="--require <scratch>/fetch-capture.cjs" sf agent publish authoring-bundle --api-name <Name> -o <alias> --skip-retrieve --json`.
   - `--skip-retrieve` keeps Bot and AiAgentDefinition metadata out of the project.
   - The capture is the preload described in [agent-publish-spike.md](agent-publish-spike.md). It
     records the real status and body, which the CLI otherwise hides.
7. Run `git status --short`. If the bundle's `-meta.xml` kept a `<target>` line, run
   `git checkout -- <bundle folder>`.
8. Query BotVersion for the new version number. Then run
   `sf agent activate --api-name <Name> --version <N> -o <alias> --json` (3 s here). Without
   `--version`, `--json` activates the latest version.
9. Query BotVersion again, and confirm every other agent's Active version is unchanged.
10. Preview one turn: `sf agent preview start --api-name <Name>`, `send --session-id <id> --utterance "<summary question>"`,
    `end --session-id <id>` (about 50 s here). Keep the session Id out of files.

If the create call returns 401 "Error saving or updating agent graph", or the publish stalls, stop.
That is Ben's stop condition (F07). Record the capture, and do not retry the same call.

## Account Brief API names in the repo

Counted with `git grep -l -I -E 'Account_Brief|AccountBrief|accountBrief|account-brief|ACCOUNT_BRIEF'`
plus `git ls-files` for the names in paths, before this page was added. A case-insensitive
`account[_-]?brief` search finds the same 194 files. The count excludes `spikes/rename/`. A file counts once if
the name is in its path, its content or both.

**194 files in all:**

- 83 metadata files
- 13 code and config files outside the metadata
- 34 docs pages
- 64 card files under `agents/`

Every metadata file that holds the name in its content also carries it in its own path. No other
metadata file (for example `ExploreAction`) refers to an Account Brief name.

### Metadata, by type (83 files)

| Metadata type | Components | Files |
|---|---|---|
| ApexClass | 26 classes: 14 (`AccountBrief`, `AccountBriefActivitySection`, `AccountBriefCallsSection`, `AccountBriefCasesSection`, `AccountBriefContactsSection`, `AccountBriefDealHistorySection`, `AccountBriefGetAction`, `AccountBriefMemory`, `AccountBriefOpenDealsSection`, `AccountBriefPanelController`, `AccountBriefProfileSection`, `AccountBriefResolver`, `AccountBriefSection`, `AccountBriefSource`) and 12 tests (`AccountBriefTest`, `AccountBriefSectionErrorTest` and a `...Test` for 10 of the 14) | 52 (`.cls` and `.cls-meta.xml`) |
| CustomObject and CustomField | `Account_Brief_Session__c` and its 9 fields | 10 |
| LightningComponentBundle | `accountBriefPanel` (4 bundle files and 4 Jest files under `__tests__`) | 8 |
| PermissionSet | `Account_Brief_Agent_Access`, `Account_Brief_Data_Access` | 2 |
| PermissionSetGroup | `Account_Brief_User` | 1 |
| AiAuthoringBundle | `Account_Brief` (`.agent` and `.bundle-meta.xml`) | 2 |
| CustomApplication | `Account_Brief` | 1 |
| FlexiPage (utility bar) | `Account_Brief_UtilityBar` | 1 |
| LightningMessageChannel | `AccountBriefOpen` | 1 |
| ExternalClientApplication and its three settings types (global OAuth set, OAuth policies, OAuth settings), in `mcp-door/` | `AccountBriefMcpClient` | 4 |
| McpServerDefinition, in `mcp-door/` | `AccountBriefMcp` | 1 |

### Outside the metadata (13 code and config files)

| Area | Files |
|---|---|
| `tests/` | 6: `tests/agent/Account_Brief-testSpec.yaml`, `test_access_group.py`, `test_agent_bundle.py`, `test_app.py`, `test_mcp_door.py`, `test_permission_sets.py` |
| `e2e/` | 4: `README.md`, `panel.spec.js`, `support/env.js`, `support/panel.js` |
| `scripts/` | 1: `agent-check.sh` (`BUNDLE_NAME="Account_Brief"` and the validate's `--api-name`) |
| Root config | 2: `jest.config.js`, `sfdx-project.json` (the replacement's path to `AccountBriefMcpClient.eca-meta.xml`) |

The most frequent names in these files are `Account_Brief` (19), `Account_Brief_Agent_Access` (6),
`AccountBriefResolver` (6) and `accountBriefPanel` (5).

### Docs and cards (98 files)

| Area | Files |
|---|---|
| `docs/research/` | 13 |
| `docs/patterns/` | 8 |
| `docs/reviews/` | 7 |
| `docs/plans/` | 3 |
| `README.md`, `docs/ARCHITECTURE.md`, `docs/assets/MANIFEST.md` | 3 |
| `agents/` (task cards) | 64 |

## What a full rename leaves behind in agent-probe

A rename deploys new components under the new names. It removes nothing, so everything below stays
in the org next to the renamed copies. Read-only checks at 01:30Z (`sf org list metadata` and
`sf data query` counts):

| Item | What is in the org now |
|---|---|
| The old agent | Bot and AiAgentDefinition `Account_Brief`; versions v1 (Inactive) and v2 (Active); planner bundles `Account_Brief_v1` and `Account_Brief_v2`; authoring bundles `Account_Brief_1` and `Account_Brief_2` |
| Its evaluation definition | AiEvaluationDefinition `Account_Brief_Test` |
| Apex | 28 ApexClass rows named `AccountBrief%`: the repo's 26, plus `AccountBriefAgentClient` and `AccountBriefAgentClientTest`. Those two are no longer in the repo (FE-20 retired "Ask the agent") but are still deployed |
| The session object | CustomObject `Account_Brief_Session__c`, with 3 rows |
| Permission sets and group | PermissionSet `Account_Brief_Agent_Access` and `Account_Brief_Data_Access` (2 assignments between them); PermissionSetGroup `Account_Brief_User` (1 assignment) |
| The message channel | LightningMessageChannel `AccountBriefOpen` |
| The panel | LightningComponentBundle `accountBriefPanel` |
| The utility bar and app | FlexiPage `Account_Brief_UtilityBar`, CustomApplication `Account_Brief` |
| The MCP door | ExternalClientApplication `AccountBriefMcpClient` and McpServerDefinition `AccountBriefMcp`. Both are listed in the org. The server is Active per [mcp-door-runbook.md](mcp-door-runbook.md); its status was not re-checked in this run |

**Removing any of these is a destructive change and needs Ben's go.** The Approvals row "FR2:
remove old Account Brief metadata, the old agent, or the old MCP server and app from `agent-probe`"
is "not approved; needs Ben's go", and its card is OPS-54.

- Until then, the old Apex classes and their tests stay deployed and run in every RunLocalTests
  deploy. A later card must keep the signatures they use.
- The old agent cannot simply be deleted while a version is Active. It would be deactivated first,
  which is also Ben's call. Per the skill's lifecycle reference, a published agent is then deleted
  in Setup, not by a destructive deploy.
- The old action classes are referenced by every Account_Brief version and by Customer_Summary v1.
  See "What this means for the rename cards".
- The 3 session rows go with the object, so they need the same go.

## Gates

On the final commit:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 101 tests, OK.
- `bash scripts/check-docs.sh`: 39 pages, 0 broken.
- `git status --short`: empty.

## Undo

Everything this card left in agent-probe, and how to remove it. Every removal is Ben's call. Each
one either deactivates an agent or deletes it, which needs its own Approvals row. None of the Undo
steps has been run, so each is unproven in this org.

Nothing here has to be removed before BE-23 and OPS-30. But keep the agent if OPS-51 is to publish
the renamed bundle as this agent's version 2 (see "What this means for the rename cards"). If the
agent is removed first, OPS-51's publish becomes a create.

What the org lists for this card (`sf org list metadata`, read-only, after the run):

- Bot `Customer_Summary` and AiAgentDefinition `Customer_Summary`
- AiAgentDefinitionVersion `Customer_Summary#1`, which is BotVersion v1
- GenAiPlannerBundle `Customer_Summary_v1`
- AiAuthoringBundle `Customer_Summary_1`

No GenAiPlugin or GenAiFunction carries the name. The quick deploy's unversioned
`Customer_Summary` bundle is not listed separately after the publish.

1. **The active Customer_Summary version.**
   - Run `sf agent deactivate --api-name Customer_Summary -o agent-probe --json`. The command and
     its flags exist in CLI 2.158.7, and the skill documents it (`salesforce-cli-for-agents.md`,
     section 6).
   - Account_Brief is a separate agent and is not affected.
2. **The agent and everything in the list above.**
   - The skill's lifecycle reference (`agent-metadata-and-lifecycle.md`, "Delete") says a published
     agent cannot be deleted through the CLI or the Metadata API, because of circular dependencies.
     Use Setup under Agentforce Agents, after step 1.
   - `sf project delete source --metadata AiAuthoringBundle:<name>` is documented only for a
     bundle that was never published, so it does not apply here.
3. **One modified `Account_Brief_Session__c` row.** The Edge Communications row was updated, and no
   row was created. There is nothing to remove: the row existed before, and the panel writes it the
   same way.
4. **Model calls.** One preview turn. Nothing to undo.

Local only, outside git: the publish capture, the command outputs and the temporary publish project
are in the session's scratch folder. The preview traces are in the worktree's git-ignored `.sfdx/`.
`.sf/config.json` (git-ignored) sets `target-org agent-probe` for this worktree.
