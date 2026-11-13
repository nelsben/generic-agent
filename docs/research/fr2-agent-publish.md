# FR2: publish and activate the renamed agent, Customer_Summary v2 (OPS-51)

- Date: 2026-11-13, 06:50 to 06:56 UTC. Org `agent-probe` (not scratch, not a sandbox, not a Dev
  Hub, no trial date). Every `sf` command ran with `-o agent-probe`.
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf`. Local compiler `@sf-agentscript/agentforce`
  2.9.27 (npm), through `scripts/agent-check.sh`.
- Read first: [fr2-rename-go.md](fr2-rename-go.md) (BE-21: **GO**),
  [fr2-rename-org.md](fr2-rename-org.md) (OPS-30: the renamed `force-app` is deployed),
  [agent-publish-spike.md](agent-publish-spike.md), [agent-publish-failure.md](agent-publish-failure.md)
  and [agent-iteration-1.md](agent-iteration-1.md).
- Approvals ([gtm-burn-plan.md](../plans/gtm-burn-plan.md), Approvals table):
  - "FR2: publish and activate a copy of the agent as `Customer_Summary` ... then the renamed agent
    (OPS-51) ...": **approved**. Ben's condition is the stop rule: if the publish meets the old
    "Error saving or updating agent graph" friction, stop.
  - "FR2: create and run the functional Testing Center suite ...": pending, so no spec run.
  - "FR2: live checks in `agent-probe` that spend model calls ...": **approved**. It covers the one
    proof turn.
  - "FR2: if the rename is NO-GO, one publish of `Account_Brief` ...": not needed, because the
    verdict was GO.
- Status words: verified (seen in a command result, a capture or an org query), unproven (inference).
- No record Ids, org Ids, session Ids, job Ids, usernames or hostnames are written here.

## Plain answer

- **Path: GO, published and activated (verified).** One publish of the `Customer_Summary` bundle in
  `force-app` added **version 2** to the existing `Customer_Summary` agent. One activation made v2
  the active version.
- **The active version calls the renamed classes (verified).** Customer_Summary v2's actions call
  `CustomerSummaryResolver`, `CustomerSummaryGetAction` and `ExploreAction`. All three are classes
  the repo has today.
- **The old friction did not occur.** The versions call,
  `POST /einstein/ai-agent/v1.1/authoring/agents/<agent id>/versions`, returned **200 after 7.3 s**
  (verified in the capture). This is the first time the versions route is shown working for
  `Customer_Summary` (BE-21 had only exercised the create route).
- **One publish attempt was used** of the two allowed. No retry, no diagnosis needed.
- **Proof:** one `generateAiAgentResponse` turn from anonymous Apex against the active version
  answered with a full summary of Edge Communications (verified). It updated 1 existing
  `Customer_Summary_Session__c` row and created none. It wrote 0 outcome rows: no outcome object
  exists in the org yet.
- **Nothing else changed.** Account_Brief v1 (Inactive) and v2 (Active) have the same status and
  last-modified time as before. Customer_Summary v1 went Inactive, as a side effect of activating
  v2: an agent has one active version. Nothing was deactivated, deleted or deployed by hand.
- **Elapsed:** about 6 minutes from the first read-only listing (06:50Z) to the proof's end
  (06:55:21Z). The publish took 22 s and the activation 4 s.

## What was done, in order

| # | Step | Command (abridged) | Start to end (UTC) | Outcome |
|---|---|---|---|---|
| 1 | Approvals and pages | read the Approvals table and the five pages above; loaded agentforce-generate and platform-metadata-deploy | n/a | GO; the publish row and the live-checks row start with "approved" |
| 2 | Install | `npm ci` | n/a | ok |
| 3 | Org class | `sf org list --skip-connection-status --json` (local read) | 06:50 | `agent-probe`: not scratch, not sandbox, not a Dev Hub, no trial date |
| 4 | Red: versions before | BotVersion query (below), read-only | 06:50 | Account_Brief v1 Inactive, v2 Active; Customer_Summary v1 Active |
| 5 | Red: actions before | `sf project retrieve start --metadata GenAiPlannerBundle:Customer_Summary_v1 --target-metadata-dir <scratch> --unzip`, read-only, outside the repo | 06:50 | v1's actions call `AccountBriefResolver`, `AccountBriefGetAction` and `ExploreAction` (the red evidence) |
| 6 | Classes present | `sf data query` ApexClass by name, read-only | 06:52 | `CustomerSummaryResolver`, `CustomerSummaryGetAction`, `ExploreAction` Active and valid |
| 7 | Gate before publish | `bash scripts/agent-check.sh` | 06:50:58 to 06:51:01 | pass: local compile ok (0 warnings), org validate ok |
| 8 | (not an attempt) | the publish line wrapped in `timeout 280` | 06:52:45 | The shell has no `timeout` command: exit 127, `command not found: timeout`. The CLI never started (no capture line written), so no call reached the org |
| 9 | **Publish, attempt 1** | `SF_LOG_LEVEL=debug PUBLISH_CAPTURE_FILE=<scratch> NODE_OPTIONS="--require <scratch>/fetch-capture.cjs" sf agent publish authoring-bundle --api-name Customer_Summary -o agent-probe --skip-retrieve --json`, from the worktree | 06:53:05 to 06:53:27 | **Succeeded.** `success` true, `botDeveloperName` `Customer_Summary`, 3 deployed, 0 retrieved. Capture below |
| 10 | Tree check | `git status --short`; `git checkout -- force-app/main/default/aiAuthoringBundles/Customer_Summary` | 06:53 | The publish left the bundle `-meta.xml` reformatted (the same one element on four lines, no `<target>` line). Restored; tree clean |
| 11 | Versions after publish | BotVersion query | 06:53 | Customer_Summary v2 Inactive (last modified 06:53:11Z); the rest unchanged |
| 12 | **Activate** | `sf agent activate --api-name Customer_Summary --version 2 -o agent-probe --json` | 06:53:48 to 06:53:52 | `success` true, version 2 |
| 13 | Versions after activation | BotVersion query | 06:53 | Customer_Summary v2 **Active**, v1 Inactive; Account_Brief unchanged |
| 14 | Read-only confirmation | retrieve `GenAiPlannerBundle:Customer_Summary_v2` to scratch; `sf org list metadata` for four agent types | 06:54 | See "Read-only confirmation" |
| 15 | Session rows before | `sf data query` counts, read-only | 06:54 | `Customer_Summary_Session__c` 1 row (last modified 06:43:10Z); `Account_Brief_Session__c` 3 rows |
| 16 | **Proof turn** | `sf apex run --file <scratch>/turn1.apex -o agent-probe --json` | 06:54:47 to 06:55:21 | Pass. See "Proof" |
| 17 | Session rows after | the same counts, plus rows modified since 06:54:00Z | 06:55 | See "Proof" |
| 18 | Gates | see "Gates" | n/a | pass |

### The publish capture (attempt 1)

The preload is the one described in [agent-publish-spike.md](agent-publish-spike.md): status,
timing and body of each call to the Agent authoring API, never request headers. Paths only:

| Time (UTC) | Call | Status | Time taken |
|---|---|---|---|
| 06:53:08 | `POST /einstein/ai-agent/v1.1/authoring/scripts` (compile) | 200 | 874 ms |
| 06:53:08 | `POST /einstein/ai-agent/v1.1/authoring/scripts` (compile) | 200 | 478 ms |
| 06:53:16 | `POST /einstein/ai-agent/v1.1/authoring/agents/<agent id>/versions` | **200** | **7334 ms** |

There was no 401, no 404 resend and no `fetch failed`. The CLI then deployed the bundle with its
`<target>` and removed the target again (3 components deployed).

## Agent versions

`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber`,
read-only:

| When | Agent | Version | Status | Last modified |
|---|---|---|---|---|
| Before (06:50Z) | Account_Brief | v1 | Inactive | 2026-11-12T07:51:53Z |
| Before (06:50Z) | Account_Brief | v2 | Active | 2026-11-12T07:51:53Z |
| Before (06:50Z) | Customer_Summary | v1 | Active | 2026-11-13T01:28:53Z |
| After the publish | Customer_Summary | v2 | Inactive | 2026-11-13T06:53:11Z |
| After the activation | Account_Brief | v1 | Inactive | 2026-11-12T07:51:53Z (unchanged) |
| After the activation | Account_Brief | v2 | **Active** | 2026-11-12T07:51:53Z (unchanged) |
| After the activation | Customer_Summary | v1 | Inactive | 2026-11-13T06:53:51Z |
| After the activation | Customer_Summary | v2 | **Active** | 2026-11-13T06:53:51Z |

**Active now:** `Customer_Summary` v2, and (unchanged, a separate agent) `Account_Brief` v2.

## Read-only confirmation

Each version's actions were read from its `GenAiPlannerBundle`, retrieved to a scratch folder
outside the repo (`localActions`: the action name and its `invocationTarget`).

| Agent and version | Status | Action | Apex class it calls | In the repo today? |
|---|---|---|---|---|
| Customer_Summary v2 | **Active** | `resolve_account` | `CustomerSummaryResolver` | yes |
| Customer_Summary v2 | **Active** | `get_brief` | `CustomerSummaryGetAction` | yes |
| Customer_Summary v2 | **Active** | `explore_data` | `ExploreAction` | yes |
| Customer_Summary v1 | Inactive | `resolve_account` | `AccountBriefResolver` | no, an old AccountBrief* class |
| Customer_Summary v1 | Inactive | `get_brief` | `AccountBriefGetAction` | no, an old AccountBrief* class |
| Customer_Summary v1 | Inactive | `explore_data` | `ExploreAction` | yes |
| Account_Brief v2 | Active | `resolve_account` | `AccountBriefResolver` | no, an old AccountBrief* class |
| Account_Brief v2 | Active | `get_brief` | `AccountBriefGetAction` | no, an old AccountBrief* class |
| Account_Brief v2 | Active | `explore_data` | `ExploreAction` | yes |

The action names (`resolve_account`, `get_brief`, `explore_data`) are the ones in the `.agent`
file; only their targets changed.

Agent metadata the org lists after the run (`sf org list metadata`, read-only):

- Bot and AiAgentDefinition: `Account_Brief`, `Customer_Summary`.
- GenAiPlannerBundle: `Account_Brief_v1`, `Account_Brief_v2`, `Customer_Summary_v1`,
  **`Customer_Summary_v2`** (new).
- AiAuthoringBundle: `Account_Brief_1`, `Account_Brief_2`, `Customer_Summary_1`,
  `Customer_Summary_2`. `Customer_Summary_2` was already listed after OPS-30's deploy; this publish
  locked it to v2 (inference from the lifecycle the skill documents; no `_3` draft is listed).

## Proof

The Testing Center row is pending, so the proof is the live-checks route: one turn from anonymous
Apex, `Invocable.Action.createCustomAction('generateAiAgentResponse', 'Customer_Summary')` with
`userMessage` "Give me a summary of Edge Communications" (the pattern in
[agent-api.md](agent-api.md)). The script printed only whether a session came back, never its Id,
and the raw run output was deleted after reading.

- **Answered:** `isSuccess` true, 0 errors, 33557 ms, a session came back (verified).
- **Which account:** Edge Communications, an existing seed-data account. The reply is 3458
  characters, a full summary. It starts: "Two overdue deals and a high-priority escalated router
  case demand immediate attention." and goes on with the account's profile (verified).
- **Session rows:** `Customer_Summary_Session__c` still holds 1 row. 0 were created and 1 was
  updated: the Edge Communications row, last modified 06:55:18Z, inside the turn's window (verified).
  `Account_Brief_Session__c` still holds 3 rows, last modified 01:29:41Z, so the old code did not
  run (verified).
  - That the update came from the new `CustomerSummaryGetAction` is an inference from the object it
    wrote and the time. Other cards also write to this org.
- **Outcome rows:** 0. No outcome object exists in the org yet (an `EntityDefinition` search for
  `%Outcome%` found none, verified).
- Model calls: this one turn.

## What later cards need to know

- **OPS-44 (the appendix page):** the agent publish works in agent-probe: `Customer_Summary` v2
  published with the CLI in 22 s and activated in 4 s, so the appendix can describe publish and
  activate as an optional step that is shown to work, with this page as the proof.
- **OPS-31 (the MCP door):** the active agent is `Customer_Summary` v2 and it calls
  `CustomerSummaryResolver`, `CustomerSummaryGetAction` and `ExploreAction`. Those are the Apex
  actions the new server's tools should name; the agent itself is not a tool.
- **OPS-54 (removing leftovers):** `AccountBriefResolver` and `AccountBriefGetAction` are still
  referenced by Account_Brief v1 and v2 (v2 still Active) and by the now Inactive Customer_Summary
  v1, so per [fr2-rename-go.md](fr2-rename-go.md) they stay pinned until those versions are gone.
  The org also reports `AccountBriefGetAction` as not valid (`IsValid` false), which only means it
  is due for a recompile.

## Gates

On the final commit:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: OK.
- `bash scripts/agent-check.sh`: pass (local compile ok, 0 warnings; org validate ok).
- `bash scripts/check-docs.sh`: 0 broken.
- `git status --short`: empty; no `tests/__pycache__`.

## Undo

Everything this card left in agent-probe, and how to remove it. None of these steps has been run,
and each is Ben's call. Deactivating or deleting an agent needs its own Approvals row.

1. **Customer_Summary v2 is the active version.** To go back to v1 (the spike version on the old
   classes): `sf agent activate --api-name Customer_Summary --version 1 -o agent-probe --json`.
   That makes v1 active and v2 Inactive. To take the agent offline instead:
   `sf agent deactivate --api-name Customer_Summary -o agent-probe --json`.
2. **The new version's metadata:** BotVersion v2 of `Customer_Summary`, AiAgentDefinitionVersion
   `Customer_Summary#2`, GenAiPlannerBundle `Customer_Summary_v2` and the authoring bundle
   `Customer_Summary_2`, now locked to v2. A published version cannot be deleted through the CLI
   or the Metadata API (the skill's lifecycle reference, "Delete"). To remove it, remove the whole
   agent in Setup under Agentforce Agents, after step 1's deactivate.
3. **Customer_Summary v1 is now Inactive** (a side effect of step 12). To restore the state before
   this card, run step 1's activate of version 1.
4. **One updated `Customer_Summary_Session__c` row** (Edge Communications). No row was created.
   Nothing to remove: the row existed before, and the panel writes it the same way.
5. **Model calls:** one turn. Nothing to undo.

Account_Brief and its versions were not touched, so they need nothing.

Local only, outside git: the publish capture, the command outputs, the retrieved planner bundles
and the proof script are in the session's scratch folder. The red evidence is in the worktree's
git-ignored `.delegation/OPS-51/red-1.txt`.
