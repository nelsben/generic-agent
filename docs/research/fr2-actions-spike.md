# FR2: write actions without the agent, measured in agent-probe (BE-22)

Run 2026-11-13 in `agent-probe`, as the signed-in System Administrator, on the sample account Edge Communications.
Nothing was deployed, published or activated, no user was created, no setting was changed, and the org this was first
built in was not touched. Every write ran inside a savepoint and was rolled back, and no existing record was updated.
Ids, usernames and hostnames are left out. Covers ledger rows F15, F16, F17 and F18 in
[feature-revision-2.md](../plans/feature-revision-2.md). `BE-27` builds what this page recommends, and `FE-14` builds
the cards.

## Result

- **One model call drafts an action.** The prototype sent a typed or spoken sentence through one Models API call
  (the seam's model) and got back the action and its fields as JSON. The draft step then built the draft in Apex
  without writing anything.
  - **Right action:** 27 of 28 runs.
  - **Speed:** the model call took a median of 2.3 seconds (1.8 to 4.7). The draft step took 0.02 to 0.17 seconds.
  - **Cost:** about 960 input tokens and 76 output tokens per draft. That is about a tenth of the input of one
    explorer question (10,078 input tokens, from [fr2-explorer-scale.md](fr2-explorer-scale.md)).
  - **Against the agent:** one agent turn took 13 to 33 seconds in [fr2-standard-limits.md](fr2-standard-limits.md).
- **Confirm is fast and needs no model.** Each of the six actions was rebuilt from its draft JSON and written with
  `AccessLevel.USER_MODE` in a median of 0.09 to 0.30 seconds per action (one run took 1.2 seconds). That is one DML
  statement and one query each. An update was undone
  from the previous values its draft carried in about 0.08 seconds. All 21 writes saved, and the rollback left
  nothing in the org.
- **A Confirm write and a model call cannot share a transaction.** After one insert, the model call threw
  `CalloutException` ("Can't perform callout because of pending uncommitted changes"). So the draft call and the
  Confirm call must be separate server calls.
- **`commit` cannot be a method name.** It is a reserved word in Apex: `Integer commit(Integer x)` fails to compile
  with "Unexpected token 'commit'". `commitDraft`, `draft` and `undo` all compile. `BE-27`'s card names a method
  `commit(draft)`, so it has to use another name.
- **The model fills a person the request did not name.** When a request named nobody, the model still put words in
  `contact`, and those words matched no contact on the account. This happened in all 5 action drafts with no named
  person, despite a rule against inventing values. What the words were was not recorded (where their shape was
  recorded, they were two words). The draft step caught it: the field came back unresolved for the user to fill or
  clear, and nothing was guessed. The draft step has to check every value the model returns.
- **Every sentence pays for one model call, unless a pre-check stops it.** A question took one model call (2.2 to 3.2
  seconds) before it could go to the explorer. "Create a follow-up" came back as "not an action" in 1 of 3 runs. A
  fixed pre-check that skips filler words and tests the first word against a verb list sorted all 9 requests right,
  offline. Matching a verb anywhere in the text sorted the question wrong, because it contains "open". A chip makes
  no model call at all.
- **Recommendation:** one Apex service, `CustomerSummaryActions`, with two doors.
  - The panel reaches it through `@AuraEnabled` methods.
  - MCP clients reach it through two invocable actions, one for the draft and one for Confirm.
  - The draft is built on the server. Confirm rebuilds it from its input and writes it in user mode.
  - A result card links to the record.
  - The class and method plan is [below](#class-and-method-plan).

## Questions 1 to 3: dropped

The card first asked three questions about running actions through the registered agent. Ledger F83 makes the agent
no way in, so no action runs through it. Those questions were not run, and no `sf agent preview` was needed. This
page answers question 4: what an Apex router costs, and how fast it is, when it uses the `AgentLlm` seam's model and
builds the draft without the agent.

## Method

Every run is its own anonymous Apex transaction, run by [run.py](../../spikes/actions/run.py). The shared prototype
is [router.apex](../../spikes/actions/router.apex): the shape `CustomerSummaryActions` takes, written as anonymous
Apex so nothing is deployed.

| Mode | Script | What it does |
|---|---|---|
| `draft` | [draft-run.apex](../../spikes/actions/draft-run.apex) | One model call for one request from [requests.json](../../spikes/actions/requests.json), then the draft step. No DML and no savepoint. |
| `commit` | [commit-run.apex](../../spikes/actions/commit-run.apex) | No callout. Inside one savepoint: a draft for each action, built from the fields a chip or an edited draft card sends. Each draft is serialized as the panel would receive it, then committed from that JSON in user mode. The two updates are then undone. Last, it checks where each Log a Call shape lands, rolls back and counts what is left. |
| `callout` | [callout-after-dml.apex](../../spikes/actions/callout-after-dml.apex) | One insert inside a savepoint, then a model call, then a rollback. |
| `names` | inside run.py | Compiles a method named `commit`, `commitDraft`, `draft` and `undo`. |
| `precheck` | inside run.py | No org call. Runs the filler-skipping, first-word verb check on each request in `requests.json`. |

- **The model call.** `router.apex` calls `aiplatform.ModelsAPI` itself, with `AgentLlmModelsApi.MODEL`, so it can read
  token counts from the response. That is the same model, through the same API, that `AgentLlm.complete` uses.
  - `AgentLlm.complete` was not called because it needs an `AgentPrompt_<Name>` static resource in the org, and none
    exists for actions yet. Deploying one would leave it in the org.
  - The seam's own overhead is not measured. From its source, that is one cached static-resource query, the
    placeholder fill and the length cap.
- **The prompt.** It is about 1,500 characters: the six actions, their fields, the "none" rule and the reply shape,
  with today's date and the account's name. It is kept in `systemPrompt()` and `userPrompt()` in `router.apex`. The
  build card moves it to a prompt file.
- **The draft step.** It resolves a person or a deal by name among the account's contacts or open opportunities, in
  user mode. It checks each field with the running user's describe (creatable, or updatable for an update) and checks
  picklist values. It also lists required fields that are missing. A name that matches no record, or more than one,
  becomes an unresolved field. Nothing is guessed.
- **The update rule.** The card forbids updating an existing record. So `commit-run.apex` inserts a throwaway contact
  and a throwaway opportunity inside the savepoint and updates only those.
- **What is recorded.** The runner writes counts, timings, booleans, dates and codes to
  [results/](../../spikes/actions/results/). No names, Ids or record text are recorded. "model ms" is wall time
  around the Models API call inside Apex. "wall ms" is the whole `sf apex run`, including the CLI's own start-up, and
  is not a panel number.

## Measurements

### Draft from a sentence

Three passes over nine requests, plus one first trial of the task request: 28 runs, 28 model calls.

| Request (id) | Expected | Right action | Date right | Draft ready | Model ms, median (range) | Input / output tokens | Draft ms |
|---|---|---|---|---|---|---|---|
| "Create a follow-up task to send Marlowe the pricing sheet next Tuesday, high priority" (task) | create_task | 4/4 | 4/4 (next Tuesday) | 4/4 | 2,242 (2,217-2,347) | 960 / 83 | 162 |
| "Set up a meeting with Tessaly tomorrow at 2pm for 30 minutes to review the renewal" (event) | create_event | 3/3 | 3/3 (tomorrow 14:00) | 3/3 | 2,316 (2,223-2,356) | 963 / 85 | 145 |
| "Log a call with Percival: he confirmed budget for the router refresh" (call) | log_call | 3/3 | n/a | 3/3 | 2,178 (2,111-2,636) | 956 / 72 | 168 |
| "Update Isolde's title to VP of Network Operations" (contact) | update_contact | 3/3 | n/a | 3/3 | 3,094 (1,935-4,743) | 952 / 60 | 80 |
| "Open a high priority case: their fiber link drops every night around midnight" (case) | create_case | 3/3 | n/a | 0/3 (contact unresolved) | 3,164 (2,125-3,209) | 955 / 83 | 120 |
| "Push the close date on the Core Router Refresh to the end of next month and set the next step to legal review" (opp) | update_opportunity | 3/3 | 3/3 (last day of next month) | 3/3 | 2,137 (2,082-2,342) | 965 / 81 | 111 |
| "Which of their open deals close this quarter?" (question) | none | 3/3 | n/a | n/a | 2,615 (2,198-3,167) | 950 / 35 | 0 |
| "Create a follow-up" (bare) | create_task, subject and due date missing | 2/3 (1 came back none) | n/a | 0/2, missing subject and due date | 1,929 (1,809-3,165) | 946 / 52 | 103 |
| "uh remind me to call ambrose back on friday about the spare parts thing" (spoken) | create_task | 3/3 | today, a Friday, in 3/3 | 3/3 | 2,471 (2,163-2,788) | 957 / 76 | 141 |
| **All 28** | | **27/28** | **10/10** | | **2,279 (1,809-4,743)** | **956 / 76** | |

- **No writes:** every draft run made 0 DML statements and 1 query, the name lookup. The draft step's CPU median
  was 116 ms, most of it describe calls. The build card should cache describe once per transaction.
- **Missing fields:** for "Create a follow-up" the model and the draft step listed the same missing fields, the
  subject and the due date.
- **The unnamed person:** in the case request and in "Create a follow-up", the model put a value in `contact` though
  the request named nobody. Where the shape was recorded, it was two words. The draft step found no matching contact
  and marked the field unresolved, so the case draft was not ready to confirm.
  - The prompt should say to leave out a key the request does not give.
  - The draft step should treat an unresolved optional field as one the user can clear.
- **"on friday" said on a Friday** gave today's date in 3 of 3 runs. That is defensible, and the draft card shows the
  date for the user to change.
- **Draft size:** a draft serializes to 360 to 740 characters of JSON, small enough for an invocable action's text
  output.
- **Wall time:** each run took 3.1 to 6.2 seconds from the CLI, median 4.0 seconds. Most of the time outside the
  model is the CLI starting up and compiling a 450-line anonymous script. The panel does not pay that.

### Confirm in user mode

Three runs of `commit-run.apex`, with no model call. Each action was drafted from fields, serialized, then committed
from the JSON. "Commit ms" includes rebuilding and re-checking the draft.

| Action | Object written | Draft ms, median | Draft JSON (chars) | Commit ms, median (range) | DML / SOQL in commit | Undo ms, median | Saved |
|---|---|---|---|---|---|---|---|
| create_task | Task | 170 (first describe of the run) | 681 | 295 (289-320) | 1 / 1 | n/a | 3/3 |
| create_event | Event | 83 | 652 | 216 (208-226) | 1 / 1 | n/a | 3/3 |
| log_call as an Event (the F17 default) | Event | 81 | 691 | 196 (195-223) | 1 / 1 | n/a | 3/3 |
| log_call as a Task | Task | 98 | 735 | 240 (229-262) | 1 / 1 | n/a | 3/3 |
| update_contact (Title) | Contact | 23 | 358 | 86 (85-104) | 1 / 1 | 85 | 3/3 |
| create_case | Case | 67 | 526 | 251 (222-288) | 1 / 1 | n/a | 3/3 |
| update_opportunity (NextStep, CloseDate) | Opportunity | 37 | 515 | 134 (116-1,191) | 1 / 1 | 78 | 3/3 |

- **Rollback:** after each run's rollback, 0 records with the spike's subjects or names were left.
- **Admin only:** every write here ran as an admin, so a user-mode refusal (no edit right, a hidden field) was not
  seen. `BE-27`'s tests cover that with a minimum-access user created in the test.

### Two rules for the build

| Probe | Result |
|---|---|
| Insert one Task, then call the model, in one transaction | `CalloutException`: "Can't perform callout because of pending uncommitted changes related to a process, flow, or Apex operation." The model call never ran. |
| A method named `commit` | Fails to compile: "Unexpected token 'commit'". `commitDraft`, `draft` and `undo` compile. |

## Recommendation

One service, `CustomerSummaryActions`, holds every rule. Each door is a thin wrapper that passes through.

### How each door reaches the service

- **The panel**
  - It calls `@AuraEnabled` methods, none of them cacheable: `draftAction` for a chip or an edited draft,
    `draftFromText` for typed or spoken words, `commitAction` for Confirm and `undoAction` for Undo.
  - Put them on `CustomerSummaryPanelController`. Its header promises that it is the panel's only Apex door.
    `BE-27`'s scope lists only `CustomerSummaryAction*` classes, so `BE-27` needs that file added to its scope.
  - If that is not wanted, the fallback is a `CustomerSummaryActionsController` inside `BE-27`'s current scope. The
    panel would then have two Apex doors.
- **An MCP client**
  - The server definition binds one invocable class per tool (`aa:apex-<Class>`), so the service gets two invocable
    classes.
  - **The invocables are a draft and commit pair: not one per action, and not one router.**
    - One per action would mean six to twelve classes and tools, each repeating the same checks.
    - One router that drafts and writes in one call would leave no gap for the client's approval prompt between
      seeing the draft and writing it.
    - Two classes match the two steps every action already has. The action name travels in the input.
  - `draft_action` returns a draft and writes nothing. `commit_action` takes the draft back and writes it.
  - Invocable variables cannot be a map, so the input and the draft cross as JSON text. The panel uses the same JSON,
    so both doors send one shape.
  - The tools go into the server definition only after Ben says MCP may write (open in the ledger; the default is
    read-only). Then `draft_action` is marked read-only, and `commit_action` is marked not read-only and destructive,
    because it can change existing fields.
  - A team's own agent can call the same two invocables.

### Where the draft is built

- **On the server, in `CustomerSummaryActions.draft`.** It makes no DML and no callout.
  - It resolves people and deals by name inside the account, in user mode. Two or more matches come back as choices
    on the field, and none comes back as an unresolved field.
  - It checks each field against the running user's describe and picklists. It applies the action's allow-list and
    defaults, and it lists what is missing.
- **From words, in `draftFromText`.** It first runs the verb pre-check ([below](#keeping-not-an-action-cheap)) and
  returns "not an action" with no model call on a miss. Otherwise it makes one `AgentLlm.complete('ActionDraft', ...)`
  call, then calls `draft` with what the model returned. The model gives words and dates; Apex gives Ids and labels. This is pattern 01's rule
  that data comes from code.
- **From a chip, in `draftAction`.** A chip, a slash command or an edited draft card calls `draft` directly, with no
  model call. Edit sends the changed input back through `draftAction`, which takes about 0.1 to 0.2 seconds, so the
  checks show before Confirm.

### How Confirm commits

- `commitAction` (or `commit_action`) sends the draft JSON back to `CustomerSummaryActions.commitDraft`.
- `commitDraft` rebuilds the draft from its input, inside its own transaction. That repeats the name lookup, the
  allow-list and the describe checks. A changed draft can therefore write nothing the user could not write by hand.
- It then writes with `Database.insert` or `Database.update` and `AccessLevel.USER_MODE`, so CRUD, field-level
  security and sharing apply. A refusal comes back as a plain-English line.
- There is no model call in this transaction, because the probe above shows a callout after DML fails.
- After a successful write, it records one Action outcome on the account through `CustomerOutcomes.record` (`BE-35`).
  A failed outcome write is logged and does not undo the action.
- For an update, it returns an undo token that carries the previous values. That is the `previous` map the
  prototype's draft already carries, undone in about 0.08 seconds. `undo` restores them in user mode under the same
  allow-list, within 15 seconds.

### How the result is shown

- `commitDraft` returns a result with the status, the record Id, a label and a link path, plus an undo token for an
  update.
- Next to it comes `BE-39`'s action result card (and an action draft card from `draft`), as JSON text for the
  invocables.
- In the panel, `FE-14` renders the draft card with Confirm, Edit and Cancel, then the result card with the record
  link and, for an update, Undo.
- Over MCP, the client shows the same card's plain-text fallback. The client's own tool-approval prompt is the
  Confirm. The server cannot prove a person confirmed, which is why `commitDraft` re-checks everything in user mode.

### Keeping "not an action" cheap

- Without a pre-check, every typed or spoken sentence that `draftFromText` sees costs one model call, about 2.3
  seconds, before a question can go to the explorer, which takes 5 to 9 seconds.
- The baseline is to classify every sentence. Each question then pays 2.2 to 3.2 seconds before the explorer starts.
- To keep questions from paying it, `draftFromText` runs a fixed pre-check before its model call. The panel
  (`FE-14`) always calls `draftFromText`, so the check belongs inside it, not in the panel.
  - It skips filler words (uh, um, so, ok, hey, please, can, could, would, you, I, need, to, want, let's).
  - It tests the first remaining word against a verb list in `CustomerSummaryActionCatalog` (create, add, schedule,
    set, book, log, remind, update, change, open, push, move, make).
  - If the word is not on the list, `draftFromText` returns "not an action" with no model call, and the text goes to
    the explorer.
- **Measured offline (`run.py precheck`, no org call):** the check sorted 9 of 9 requests right. The two lists were
  written with these nine requests in view, so this is a consistency check, not a held-out test. The spoken request
  starts with filler, and its first real word is "remind". Matching a verb anywhere in the text instead sorted the
  question wrong, because the question contains "open".
- **What a miss costs:** an action request whose first word is not on the list goes to the explorer, so no draft is
  made at all. That is worse than one extra model call. Nine requests are too few to call the list proven, so
  `BE-27`'s tests should pin it with more phrasings.
- A model "not an action" on a real action ("Create a follow-up", 1 run in 3) has the same result: no draft.
- Chips and slash commands skip the model entirely.

## Class and method plan

| Class | Kind | Methods and members |
|---|---|---|
| `CustomerSummaryActions` | Service, `with sharing` | `draft(String actionType, Id accountId, Map<String, Object> input)` returns `Draft`, with no DML and no callout. `draftFromText(Id accountId, String text)` returns `Draft`, or `Draft` with status `NOT_AN_ACTION`: the verb pre-check first, returning `NOT_AN_ACTION` with no model call on a miss; otherwise one `AgentLlm.complete` call, then `draft`. `commitDraft(Draft draft)` returns `Result`: it rebuilds, writes in user mode, then calls `CustomerOutcomes.record`. `undo(String undoToken)` returns `Result`, for updates within 15 seconds. The constant `LOG_CALL_AS = 'Event'` carries a comment naming F17 (see below). |
| `CustomerSummaryActions.Draft` | Inner class | `status` (READY, NEEDS_INPUT, NOT_AN_ACTION, REFUSED), `action`, `accountId`, `targetId`, `targetLabel`, `inputJson`, `fields` (a list of `Field`), `missing`, `warnings` and `cardJson`. The map input travels as `inputJson`, because `JSON.deserialize` cannot fill an `Object`-typed member (the prototype hit this). |
| `CustomerSummaryActions.Field` | Inner class | `api`, `label`, `value`, `required`, `missing`, and `choices` (label and Id) when a name matched more than one record. |
| `CustomerSummaryActions.Result` | Inner class | `status`, `recordId`, `label`, `linkPath`, `undoToken`, `message` and `cardJson`. |
| `CustomerSummaryActionCatalog` | Data, no queries | For each of the six actions: the target object, create or update, the required inputs, the allow-listed fields and the defaults. Also the filler-word list and the action-verb list for the pre-check. |
| `CustomerSummaryActionResolver` | Helper, `with sharing` | `contacts(Id accountId, String words)` and `openOpportunities(Id accountId, String words)`, in user mode. Each returns 0, 1 or several matches. |
| `CustomerSummaryActionDraftAction` | `@InvocableMethod`, MCP `draft_action` | Inputs: `accountId`, `actionType` (optional), `text` (optional) and `inputJson` (optional). Outputs: `status`, `draftJson`, `cardJson` and `message`. |
| `CustomerSummaryActionCommitAction` | `@InvocableMethod`, MCP `commit_action` | Inputs: `draftJson`. Outputs: `status`, `recordId`, `label`, `linkPath`, `undoToken`, `cardJson` and `message`. |
| `CustomerSummaryPanelController` | Existing `@AuraEnabled` door | `draftAction(String actionType, Id accountId, String inputJson)`, `draftFromText(Id accountId, String text)`, `commitAction(String draftJson)` and `undoAction(String undoToken)`. They pass through, and their errors become the fixed line as the class does today. This needs the scope change above. |
| `AnswerCard` | `BE-39` builders | `actionDraft(CustomerSummaryActions.Draft)` and `actionResult(CustomerSummaryActions.Result)`. |
| `AgentPrompt_ActionDraft` | Prompt file | The prompt from `router.apex`, plus "leave out a key the request does not give". |
| Tests | `CustomerSummaryActionsTest` and one test per new class | As `BE-27` lists. |

**Where this differs from the build cards:**

| Card says | Plan says | Why |
|---|---|---|
| `commit(draft)` (`BE-27`) | `commitDraft(draft)` | `commit` does not compile. |
| `draftAction` and `commitAction` with no class named | On `CustomerSummaryPanelController` | That class is the panel's only Apex door. |

`draft`, `draftFromText`, `undo`, `draftAction` and `commitAction` keep the names `BE-27` and `FE-14` use.

## Log a Call: Ben's decision, not made here

Ben said Log a Call "is synonymous with create an event" (F17). Salesforce's own Log a Call saves a completed Task.
The ledger's default is an Event, held in one constant. This spike describes both and makes no choice.

| | A completed Task (what Salesforce's Log a Call saves) | An Event (Ben's words, the current default) |
|---|---|---|
| What the org shows | The `LogACall` quick action's describe targets Task. `TaskSubtype` offers Call. Neither the Apex describe nor a `FieldDefinition` query (both as admin) lists a `Type` field on Task in this org, so "type Call" here means `TaskSubtype` Call. | `EventSubtype` offers only Event. |
| What the spike wrote | `Status` Completed, `TaskSubtype` Call, due today: `IsClosed` true. | 15 minutes ending now: `EndDateTime` at or before now. |
| Where it lands on the account (queried) | `ActivityHistories`, with `ActivitySubtype` Call, in 3 of 3 runs. | `ActivityHistories`, with `ActivitySubtype` Event, in 3 of 3 runs. |
| How the activity timeline shows it (unverified: not seen on screen, and no Salesforce doc was opened in this run) | Under past activity, with the call icon, as a logged call. | Under past activity, with the calendar icon, as a meeting. It also sits on the user's calendar at that time. |
| Reports (not checked in a report here) | Counts as a call in activity reports that filter on the Call subtype. | Counts as an event, not a call. |
| Fits when | Calls are logged after they happen, and call counts matter. | Calls are booked ahead, or reps want them on the calendar. |

For contrast, the spike's create_task (due in four days) and create_event (tomorrow) landed in `OpenActivities`, the
upcoming part of the timeline, in 3 of 3 runs. Switching from one to the other is the one constant in `BE-27`; the
draft card shows which object will be written either way.

## Cost

- **Per typed or spoken action:** one Models API call of about 960 input and 76 output tokens.
- **Per chip, Edit, Confirm or Undo:** no model call.
- **Per question:** with the verb pre-check, no extra call when the first word is not on the list. Without it, one
  call of about 950 input and 35 output tokens and 2.2 to 3.2 seconds.
- **For comparison:** one explorer question uses about 10,078 input tokens and 3 model calls (median, BE-31). The
  standard agent adds its own reasoning calls to every turn (BE-32).
- **No credit price is given here.** Models API calls count against the org's generative AI usage. A price per call
  was not found in a source this run opened, as in [salesforce-mcp.md](salesforce-mcp.md), so this page counts tokens
  and calls.

## Open items

- **A user-mode refusal, seen live.** Every run was as an admin. `BE-27`'s tests use a minimum-access user created in
  the test.
- **The panel's round trip.** Only the server side was timed. An Aura call adds network time that the CLI cannot show.
- **The MCP path, run end to end.** It comes from the server definition and the docs. The door is still read-only,
  and the MCP sign-in is Ben's.
- **The undo token.** It carries the previous values unsigned, as `BE-27` specifies. A changed token can do only what
  the user could do by an update, but a changed timestamp can stretch the 15 seconds. Signing it would need a key kept
  in the org.
- **The verb pre-check** was checked offline on nine requests only (see above). A miss means no draft, so it needs
  many more phrasings in `BE-27`'s tests.

## Model use and data written

- **Model calls:** 28 through the Models API, one per draft run. The two callout probe runs made none, because each
  threw first. In all, 26,772 input tokens and 2,036 output tokens.
- **Commit runs:** four, not three. The first run's activity line had keys that clashed with other keys, so its rows
  were deleted from `commit.jsonl` and the run was repeated. That first run still wrote 7 actions, 2 throwaways and
  2 undos, and printed a count of 0 after its rollback.
- **Records:** across the four commit runs, 28 action writes, 8 throwaway inserts and 8 undos, all inside savepoints.
  All were rolled back, and the count after each rollback was 0. The tables above use the three kept runs (21 writes).
- **Callout probe:** run twice, because the first run's message check was wrong and the second prints the message.
  Each inserted one throwaway Task inside a savepoint, threw before the model call, rolled back and counted 0.
- **Read-only runs:** the inventory script took four tries: two failed to compile, one failed at run time after its
  reads, and one succeeded. It read the sample account's contact and open-deal names, the picklists and the
  `LogACall` describe. One `FieldDefinition` query checked Task's fields.
- **Compile-only runs:** the `names` probe ran four compiles and wrote nothing.
- Nothing was deployed, and no trace flag was set.

## Undo

Nothing to undo in the org. Every write was rolled back inside its own run, and nothing was deployed, published,
activated or assigned. Each anonymous Apex run leaves a debug log in the org, as any `sf apex run` does. The logs age
out on their own, or an admin can delete them under Setup, Debug Logs. If the org's generative AI audit trail is on,
the 28 model calls are recorded there like any other Models API call. This run did not check whether it is on.

- **Repo:** delete `spikes/actions/` and this page.
- **Local only:** the red file `.delegation/BE-22/red-1.txt` in the BE-22 worktree, which is git-ignored.
