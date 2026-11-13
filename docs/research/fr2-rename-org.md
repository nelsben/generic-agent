# FR2 rename in agent-probe: deploy Customer Summary, assign the group, prove the panel (OPS-30)

- Date: 2026-11-13, 02:02 to 02:26 UTC (the evening of 2026-11-12 local). Org `agent-probe`
  (Developer Edition, `IsSandbox` false). This covers FR2 ledger rows F03 and F07 in
  [feature-revision-2.md](../plans/feature-revision-2.md).
- CLI: `@salesforce/cli` 2.158.7. Playwright 1.64.1. Every `sf` command ran with `-o agent-probe`.
- Verdict read first: [fr2-rename-go.md](fr2-rename-go.md) says **GO**, so the agent bundle carries
  the new name `Customer_Summary` too.
- Approvals ([gtm-burn-plan.md](../plans/gtm-burn-plan.md), Approvals table), both "approved":
  - The standing row "Production-classified deploys to `agent-probe`". It covers the validate and
    the quick deploy.
  - "FR2: live checks in `agent-probe` that spend model calls ..., and assigning the user group to
    the admin". It covers the group assignment and the e2e model calls.
- Status words: verified (seen in a command result, an org query or a screenshot), unproven
  (inference).
- No record Ids, org Ids, job Ids, usernames or hostnames are written here.

## Plain answer

- **Customer Summary runs end to end in agent-probe under the new names (verified).**
  - All of `force-app`, the agent bundle included as source, validated with RunLocalTests and
    quick-deployed: 62 of 62 components, 251 of 251 Apex tests.
  - The permission set group `Customer_Summary_User` is assigned to the signed-in admin.
  - Clicking the Customer Summary app's utility item opens the panel at 340x480.
  - `npm run test:e2e` passed in full on the second run: **8 passed (2.8m)**. The first run had
    7 passed and spec 2 failed on focus (see "e2e").
- **One fix was needed, because of the rename (verified).** The first validate failed 4 methods of
  the old, org-only `AccountBriefTest`. The fix gives the new code its own synthesis prompt,
  `AgentPrompt_SummarySynthesis`. See "The fix".
- **Nothing was published or activated.** The agent versions are the same before and after
  (verified). The agent publish, its activation and the agent proof are OPS-51's.
- **The old Account Brief metadata is untouched (verified),** and so are its assignments. Removing
  it needs Ben's go (OPS-54). See "What stays in the org".

## What was done, in order

| # | Step | Command (abridged) | Start to end (UTC) | Outcome |
|---|---|---|---|---|
| 1 | Read | the card's five pages; loaded platform-metadata-deploy | n/a | GO; both Approvals rows start with "approved" |
| 2 | Install | `npm ci` | n/a | ok |
| 3 | Org and state | `sf org list --skip-connection-status --json`; `sf data query` (read-only) | 02:03 | Not scratch, not sandbox, not a Dev Hub, no trial date. Developer Edition. See "Before and after" |
| 4 | Default org | `sf config set target-org agent-probe` (project-local, `.sf/` is git-ignored) | n/a | As in [org-migration.md](org-migration.md), so the deploy gate finds a target |
| 5 | Red | `SF_TARGET_ORG=agent-probe npm run test:e2e` | 02:02:04 to 02:14:46 | **8 failed**, each at `expect(locator('c-customer-summary-panel')).toBeAttached()` after 90 s: the app and panel did not exist yet |
| 6 | Validate 1 | `sf project deploy validate --source-dir force-app --test-level RunLocalTests -o agent-probe --wait 4 --json` | 02:04:33 to 02:07:00 | **Failed.** 62 of 62 components, 251 tests, **4 failures**, all in `AccountBriefTest`. See "The fix" |
| 7 | Fix | rename the synthesis prompt; commit | n/a | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests` 108 OK, `npm run test:unit` 41 passed |
| 8 | Validate 2 | the same command | 02:15:50 to 02:17:42 | **Succeeded.** 62 of 62 components, 251 of 251 tests, 0 failures, tests 93.3 s, no coverage warnings |
| 9 | Quick deploy | `CONFIRM_PROD=1 sf project deploy quick --job-id <validate 2> -o agent-probe --wait 10 --json` | 02:18:01 to 02:18:13 | **Succeeded.** 62 of 62 components |
| 10 | Group | `SELECT DeveloperName, Status FROM PermissionSetGroup` (read-only) | 02:18 | `Customer_Summary_User` status `Updated` |
| 11 | Assign | `sf org assign permset --name Customer_Summary_User -o agent-probe --json` | 02:18 | 1 success, 0 failures. Assigned to the signed-in admin only |
| 12 | After state | the queries in "Before and after" (read-only) | 02:18 | The old metadata and its assignments are unchanged; agent versions unchanged |
| 13 | e2e, run 1 | `SF_TARGET_ORG=agent-probe npm run test:e2e` | 02:18:57 to 02:22:14 | **7 passed, 1 failed** (spec 2, focus), 3.3 min |
| 14 | e2e, run 2 | the same command, once | 02:22:25 to 02:25:13 | **8 passed (2.8m)** |
| 15 | Utility item | a one-off Playwright script in the session's scratch folder, using the suite's saved session | 02:25:24 to 02:25:29 | **Pass.** See "The utility item opens the panel" |
| 16 | Gates | the four gate commands; `git status --short` | n/a | See "Gates" |

Elapsed, from the first validate to the passing e2e run: about 21 minutes, 10 of them the fix and
the second validate. The red run took 12.7 minutes, because each of the 8 specs waited 90 s for a
panel that did not exist.

## The fix

The card allows a fix under `force-app/` only when the deploy fails because of the rename. This
one does.

**The failure, verbatim (validate 1):**

- `AccountBriefTest.allSourcesByDefaultInRegistryOrder`: `System.AssertException: Assertion
  Failed: synthesis runs last` (line 97).
- `AccountBriefTest.emptySourcesSkipPreReduceAndGiveEmpty`: `System.NullPointerException:
  Attempt to de-reference a null object` (line 163).
- `AccountBriefTest.includeFiltersAndSkipsEngagement`: the same null pointer (line 146).
- `AccountBriefTest.someErrorSectionsStillGiveAnOkBrief`: `Assertion Failed: Instance expected to
  be a non null value: the model still writes the brief` (line 379).

**The cause (verified from the test's source at commit `7e881b9^`):**

- `AccountBriefTest` exists only in the org now. Its model stub finds the synthesis call by the
  text "final account brief" in the system prompt.
- The old `AccountBrief` and the new `CustomerSummary` both loaded the same static resource,
  `AgentPrompt_BriefSynthesis`.
- BE-23 reworded that resource to "final account summary". Deploying it would change the prompt
  the old code reads, and the old test no longer finds its synthesis call.
- Rewording it back would fail `tests/test_fr2_rename.py`, and the old test cannot be changed.

**The change (commit `9d3ff0f`):**

- `force-app/main/default/staticresources/AgentPrompt_BriefSynthesis.resource` and its
  `-meta.xml` are renamed to `AgentPrompt_SummarySynthesis`, with the content unchanged.
- `force-app/main/default/classes/CustomerSummary.cls`: `SYNTHESIS_PROMPT` is now
  `'SummarySynthesis'`.
- `force-app/main/default/classes/AgentLlmTest.cls`: `everyBriefPromptHasBothParts` checks
  `SummarySynthesis` in place of `BriefSynthesis`.

With it, the deploy leaves the org's `AgentPrompt_BriefSynthesis` as it was (last modified
2026-11-12T05:50:59Z before and after). So the old agent's live prompt is not changed either.
Validate 2 passed all 251 tests.

**Left for the docs owner (not changed here, outside this card's scope):** `docs/ARCHITECTURE.md`
and `docs/patterns/01-route-gather-reduce.md` and `04-model-provider-seam.md` still name
`BriefSynthesis` as the synthesis prompt. The task card BE-29 lists
`force-app/main/default/staticresources/AgentPrompt_BriefSynthesis.resource` in its scope; the file
is now `AgentPrompt_SummarySynthesis.resource`.

**The same trap remains for later cards (inference).** The old classes in the org still share
`AgentPrompt_BriefEngagement`, `AgentPrompt_BriefDealHistory`, `AgentPrompt_Explore` and the
unprefixed classes (`AgentLlm*`, `Explore*`, `DataExplorer`) with the new code. A later change to
any of these can break an old test in RunLocalTests the same way.

## e2e

Each run: `SF_TARGET_ORG=agent-probe npm run test:e2e`, 8 specs, 1 worker. `SF_E2E_ORG` was unset.

| Spec | Red (before the deploy) | Run 1 | Run 2 |
|---|---|---|---|
| 1. Cmd/Ctrl-K before the utility was ever opened | fail (1.6 m) | pass (5.2 s) | pass (4.4 s) |
| 2. Esc returns focus; Tab can leave | fail (1.6 m) | **fail** (27.0 s) | pass (9.7 s) |
| 3. Brief: headline, collapsed accordions, live region | fail (1.5 m) | pass (33.0 s) | pass (28.5 s) |
| 4. Composer pinned at 340x480, newest answer in view | fail (1.6 m) | pass (39.1 s) | pass (38.1 s) |
| 5. Latest wins | fail (1.6 m) | pass (12.8 s) | pass (11.1 s) |
| 6. Typing enables Send; Enter sends | fail (1.6 m) | pass (5.8 s) | pass (5.7 s) |
| 7. Drill and breadcrumb | fail (1.5 m) | pass (33.2 s) | pass (30.0 s) |
| 8. axe in the brief and drill states | fail (1.6 m) | pass (31.1 s) | pass (31.2 s) |
| Summary line | `8 failed` | `1 failed`, `7 passed (3.3m)` | **`8 passed (2.8m)`** |

- **Red:** every spec failed at `e2e/support/panel.js:68`,
  `expect(locator('c-customer-summary-panel')).toBeAttached()`, "element(s) not found", after
  90 s. The Customer Summary app and its panel were not in the org yet (verified by the failure;
  the app was listed afterwards, not before).
- **Run 1, spec 2:** `focus returned to the element focused before the hotkey, and stayed there`,
  `expect(locator).toBeFocused() failed`, locator
  `getByRole('button', { name: 'Search', exact: true }).first()`, `Received: inactive`.
  - The failure screenshot shows the Edge Communications record page in the Customer Summary app,
    with a docked "Welcome to Data Cloud!" pop-up (Minimize, Pop-out, Close, "See Documentation")
    open at the lower right (verified from the screenshot).
  - So a first-run org pop-up probably took focus from the Search button (inference). It is not
    the "Meet the new Guidance Center" walkthrough that `Panel.gotoAccount` dismisses. This is
    the same intermittent spec 2 recorded in [org-migration.md](org-migration.md#e2e-after-fe-9),
    not a rename failure, so no fix was made.
- **Run 2:** 8 passed. Rerun once, as the card allows.
- **Model calls:** about 6 per full run (the e2e README's table), so about 12 for the two runs.
  The red run made none: no spec reached the panel.
- **Data written:** `Customer_Summary_Session__c` holds 1 row after the runs (the panel's brief
  memory for its own turns). `Account_Brief_Session__c` still holds 3.

## The utility item opens the panel

No e2e spec clicks the utility item (spec 1 opens the panel with the hotkey). So a one-off
Playwright script, kept in the session's scratch folder and not in the repo, reused the suite's
saved session (`e2e/.auth/`) and checked it, after run 2 (verified):

1. The Customer Summary app loads, and the panel host is attached (2.4 s).
2. The Edge Communications record page loads, and the utility item "Customer Summary" is visible
   (3.3 s). The composer is hidden: the utility has not been opened.
3. A click on the utility item shows the composer (3.4 s), in a dialog of 340x480.
4. The panel offers "Summarize Edge Communications" for the page's account (4.8 s).

No model call: nothing was sent.

## Before and after

All read-only `sf data query` and `sf org list metadata` calls.

| Item | Before (02:03) | After (02:18 to 02:25) |
|---|---|---|
| BotVersion `Account_Brief` | v1 Inactive, v2 Active, both last modified 2026-11-12T07:51:53Z | the same |
| BotVersion `Customer_Summary` | v1 Active, last modified 2026-11-13T01:28:53Z | the same |
| ApexClass `AccountBrief%` | 28 | 28 |
| ApexClass `CustomerSummary%` | 0 | 26 |
| StaticResource `AgentPrompt_%` | `BriefDealHistory`, `BriefEngagement`, `BriefSynthesis` (all 2026-11-12T05:50:59Z), `Explore` | the same four, unchanged, plus `SummarySynthesis` |
| PermissionSet | `Account_Brief_Data_Access`, `Account_Brief_Agent_Access` | the same, plus `Customer_Summary_Data_Access` and `Customer_Summary_Agent_Access` |
| PermissionSetGroup | `Account_Brief_User` | the same, plus `Customer_Summary_User` (status `Updated`) |
| Assignments of these sets and groups | `Account_Brief_Data_Access`, `Account_Brief_Agent_Access`, group `Account_Brief_User` | the same three, plus group `Customer_Summary_User` |
| App menu (`AppMenuItem`) | `Account_Brief`, `AccountBriefMcpClient` | the same, plus `Customer_Summary` ("Customer Summary") |
| `Account_Brief_Session__c` rows | 3 | 3 |
| `Customer_Summary_Session__c` rows | (no object) | 1 |
| AiAuthoringBundle (list metadata) | `Account_Brief_1`, `Account_Brief_2`, `Customer_Summary_1` (per [fr2-rename-go.md](fr2-rename-go.md)) | `Account_Brief_1`, `Account_Brief_2`, `Customer_Summary_1`, **`Customer_Summary_2`** |

- The quick deploy put the agent bundle into the org as source. The org now lists a
  `Customer_Summary_2` authoring bundle. BotVersion still has only v1, so nothing was published or
  activated (verified).
- That `Customer_Summary_2` is the draft made by this source deploy is an inference from the
  before and after lists. OPS-51's publish should make version 2 from it; that is unproven.
- Only the admin's one new group assignment was added. No assignment was removed, and no user
  was created.

## What stays in the org (old metadata)

The rename deploys new components beside the old ones and removes nothing. The full list of what
stays is in [fr2-rename-go.md](fr2-rename-go.md#after-the-rename-fr2-org-card). Removing any of it
needs Ben's go: the Approvals row "FR2: remove old Account Brief metadata, ..." is "not approved;
needs Ben's go", and its card is OPS-54.

**Classes and tests that now exist only in the org (verified: 28 `AccountBrief%` ApexClass rows,
none of them in the repo):**

- 15 classes: `AccountBrief`, `AccountBriefActivitySection`, `AccountBriefAgentClient`,
  `AccountBriefCallsSection`, `AccountBriefCasesSection`, `AccountBriefContactsSection`,
  `AccountBriefDealHistorySection`, `AccountBriefGetAction`, `AccountBriefMemory`,
  `AccountBriefOpenDealsSection`, `AccountBriefPanelController`, `AccountBriefProfileSection`,
  `AccountBriefResolver`, `AccountBriefSection`, `AccountBriefSource`.
- 13 test classes: `AccountBriefTest`, `AccountBriefSectionErrorTest`,
  `AccountBriefAgentClientTest`, and `AccountBrief<X>Test` for `ActivitySection`, `CallsSection`,
  `CasesSection`, `ContactsSection`, `DealHistorySection`, `Memory`, `OpenDealsSection`,
  `PanelController`, `ProfileSection` and `Resolver`.
- The static resource `AgentPrompt_BriefSynthesis`, which the old `AccountBrief` still reads.
- **RunLocalTests runs these 13 old test classes in every later deploy** to agent-probe, until
  OPS-54 removes them. OPS-54 waits on its own row in the Approvals table.
  - RunLocalTests ran 169 tests in BE-21 (before the new classes) and 251 here. So about 82 are the
    new `CustomerSummary*` tests (inference: it assumes the shared tests did not change).
- `AccountBriefResolver` and `AccountBriefGetAction` stay pinned by agent versions: Account_Brief
  v1 and v2 and Customer_Summary v1 all target them ([fr2-rename-go.md](fr2-rename-go.md)).

## Gates

On the final commit:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 108 tests, OK.
- `npm run test:unit`: 41 passed.
- `bash scripts/validate-org.sh`: pass.
- `bash scripts/check-docs.sh`: 0 broken.
- `git status --short`: empty; no `tests/__pycache__`.

## Undo

Nothing here has been undone, and every step below is Ben's call. None has been run.

- The `Customer_Summary_User` assignment: `sf org unassign permset --name Customer_Summary_User -o agent-probe`.
- The 62 deployed components: a destructive deploy, which needs its own Approvals row. The old
  Account Brief metadata does not depend on them.
- Local only, outside git: command outputs, the failure screenshots and the utility-item script
  are in the session's scratch folder. `.sf/config.json` (git-ignored) sets `target-org
  agent-probe` for this worktree.
