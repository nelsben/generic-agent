# Org move: main to agent-probe (OPS-25)

- Date: 2026-11-12, 05:30 to 06:30 UTC. Target org alias `agent-probe`. Five attempts; this page
  records all five, and attempt 5 is the current state.
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf` (the spike used 2.157.8).
- Approval: "Phase 2: migrate to the fresh Developer Edition org that publishes (deploy, publish,
  activate there)" in `docs/plans/gtm-burn-plan.md`, Approvals. The staged order and the rerun
  were the brain's decisions on the same approval line.
- Status words: verified (seen in a command result or an org query), unproven (inference, not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.
- The README quick-start run as written (OPS-28) is recorded in [fresh-org-run.md](fresh-org-run.md).

## Plain answer

> This page records the move, when version 1 was the active version. Version 2 is now active in
> agent-probe; see [agent-iteration-1.md](agent-iteration-1.md).

- **`main` is deployed to agent-probe, and Account_Brief is published and active there (v1,
  verified).** Both permission sets are deployed and assigned to the running user. The org
  evaluation definition `Account_Brief_Test` exists and points at `subjectVersion v1`.
- **The sample data is in (attempt 5, verified).** The seed imported 107 records: 14 Accounts,
  14 Contacts, 47 Opportunities, 7 OpportunityContactRoles, 11 Tasks, 6 Events and 8 Cases. It took
  two data fixes on `main`:
  - PR #72: `BillingCountry` and `BillingState` as names, because the org has State and Country
    Picklists on (attempt 3's errors).
  - PR #74: Quillfeather Group moved to `data/sample/account-parents.json`, an earlier plan entry,
    because `sf data import tree` does not resolve a reference to a record in the same file
    (attempt 4's error). `tests/test_sample_data.py` now checks for that.
- **Agent test: 12 of 12 cases pass, 36 of 36 assertions (verified).** The quality ratings are 5
  on nine cases, 4 on cases 2 and 6, and 3 on case 1. Case 7 called `resolve_account` before
  `get_brief` where the spec expects `get_brief` alone, and the runner still scored it PASS.
- **Two-turn check: both turns pass (verified).** Turn 2 reused turn 1's session and answered
  about Edge Communications' open cases without the account being named.
- **e2e: 7 of 8 pass; spec 2 fails (verified).** Its anchor, the global header's Search button,
  was not found after Esc. At that moment the page showed the fresh org's "Guidance Center" panel
  and its "Meet the new Guidance Center" pop-up, and the header's buttons were not in the
  accessibility tree. The failure screenshot shows that walkthrough over a dimmed page. The likely
  cause is the fresh org's first-run pop-up (inference: what opened it, and whether a key the test
  pressed did, is unproven). See "e2e".
- **Model calls in the org: about 21 agent or panel turns, plus 12 grader ratings** (1 turn in
  attempt 3; 12 test cases, 2 two-turn turns and 6 e2e panel calls in attempt 5). That is within
  the budget of about 40 even with the grader counted.
- The memory test that failed validate 2 was fixed in `main` by PR #70 (the brain): the test's own
  setup `update` is now `Database.update(..., true, AccessLevel.SYSTEM_MODE)`. With that change,
  validate 3 passed 150 of 150 Apex tests (verified).
- All three gates pass on agent-probe: unit tests, `validate-org.sh` and `agent-check.sh`
  (verified). `validate-org.sh` uses the card's full scope and now passes because the agent exists.
- BotDefinition had 0 rows before the publish. The minimal probe agent the creating session
  published was never in this org. This org's first agent publish, Account_Brief, returned HTTP
  200 on every call (verified).
- Classification conflict, kept from attempt 1: the org record's host carries the Developer Edition
  markers the deploy skill lists, so the skill would class it as non-production. The card treats it
  as production, so every deploy went validate, then quick deploy with `CONFIRM_PROD=1`.

## What was done, in order

Attempts 1 and 2 changed nothing in the org. Attempt 3 is rows 14 to 28, attempt 4 rows 29 to 33,
attempt 5 rows 34 to 41.

| # | Step | Command (abridged) | Outcome |
|---|---|---|---|
| 1 | Read the Approvals and Phase 2 sections, the four research and plan pages, and loaded the five named skills | n/a | Phase 2 deploy, publish and activate in the new org are approved |
| 2 | Install | `npm ci` | ok |
| 3 | Classify the org | `sf org list --skip-connection-status --json` | Record found by alias: not scratch, not sandbox, not a Dev Hub, no trial expiry date, API 68.0, not the default org. Developer Edition host markers (see the conflict above). The card's production path was used (verified) |
| 4 | Edition | `SELECT OrganizationType, IsSandbox, TrialExpirationDate FROM Organization` | `Developer Edition`, `IsSandbox` false, no trial end date (verified) |
| 5 | Starting state | `SELECT COUNT() FROM Account`; `SELECT DeveloperName FROM BotDefinition` | 0 Accounts, 0 agents (verified) |
| 6 | Flags | `--help` on deploy validate and quick, org assign permset, agent publish and activate, agent test create, run and results | All flags used exist; activate has `--version` |
| 7 | Default org | First validate attempt | Refused by the plugin's deploy-gate hook: "No target org is configured". Ran `sf config set target-org agent-probe` (project-local, `.sf/` is git-ignored, not `--global`) |
| 8 | Validate 1 (attempt 1, the card's scope) | `sf project deploy validate --source-dir <every force-app folder except aiAuthoringBundles> --test-level RunLocalTests -o agent-probe --wait 30 --json` | **Failed.** 60 components, 59 passed, 1 error: `Account_Brief_Agent_Access - In field: botDefinition - no Bot named Account_Brief found`. 0 tests ran |
| 9 | Brain's decision: the staged order, split around the agent's own permission set | n/a | Run each step once |
| 10 | Validate 2 (attempt 2, without `Account_Brief_Agent_Access`) | same, with `applications, classes, flexipages, lwc, messageChannels, objects, staticresources` and `permissionsets/Account_Brief_Data_Access.permissionset-meta.xml` | **Failed.** 59 of 59 components, 150 tests, 1 failure: `AccountBriefMemoryTest.rowsPerUserAreCappedAndTheOldestGoFirst`, `System.DmlException: Operation failed due to fields being inaccessible on Sobject Account_Brief_Session__c`, at the test's own `update` (line 203) |
| 11 | State check | read-only counts | 0 of our Apex classes, 0 Accounts, 0 BotDefinitions, 0 BotVersions at 05:44Z (verified) |
| 12 | Brain's decision: do not deploy the object and Data Access first (that permission set grants five Apex classes and the app, so it cannot land before them). Fix the test instead | PR #70 | The worktree was rebased onto `main` with #70; budget raised to 3 attempts (PR #71) |
| 13 | Attempt 3 starts | n/a | Same staged order, once more |
| 14 | Validate 3 (validate 2's scope, with #70) | same command as row 10 | **Succeeded.** 59 of 59 components, 150 of 150 tests, 0 failures. Server time 05:48:52 to 05:50:26Z, tests 76.9 s (verified) |
| 15 | Quick deploy | `CONFIRM_PROD=1 sf project deploy quick --job-id <validate 3> -o agent-probe --wait 30 --json` | **Succeeded.** 59 components deployed, completed 05:51:15Z (verified) |
| 16 | Assign data access | `sf org assign permset --name Account_Brief_Data_Access -o agent-probe --json` | 1 success, 0 failures (verified) |
| 17 | Seed | `SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` | **Failed:** "Data Import failed". 0 records written (verified: 0 Accounts, 0 Opportunities afterwards). Not retried; see "Seed" |
| 18 | Agent gate | `bash scripts/agent-check.sh` | pass: local compile clean, org validate ok |
| 19 | Capture check | `sf agent validate authoring-bundle --api-name Account_Brief -o agent-probe --json`, with the spike's fetch capture preload | compile 200; the capture works |
| 20 | Publish (once) | `SF_LOG_LEVEL=debug PUBLISH_CAPTURE_FILE=<scratch> NODE_OPTIONS="--require <scratch>/fetch-capture.cjs" sf agent publish authoring-bundle --api-name Account_Brief -o agent-probe --skip-retrieve --json` | **Succeeded.** `POST /ai-agent/v1.1/authoring/scripts` 200 twice, then `POST /ai-agent/v1.1/authoring/agents` 200 after 7.9 s. Result `success` true, `botDeveloperName` `Account_Brief`. Finished about 05:55:05Z (verified) |
| 21 | Restore the bundle | `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief`; `git status` | Publish's temporary `<target>` removed; tree clean |
| 22 | Agent and versions | `SELECT DeveloperName, Type, AgentType FROM BotDefinition`; the BotVersion query below | `Account_Brief`, `InternalCopilot`, `AgentforceEmployeeAgent`. v1, `Inactive` (verified) |
| 23 | Activate | `sf agent activate --api-name Account_Brief --version 1 -o agent-probe --json` | success, version 1. BotVersion v1 `Active` (verified) |
| 24 | Validate agent access | `sf project deploy validate --source-dir force-app/main/default/permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml --test-level RunLocalTests -o agent-probe --wait 30 --json` | **Succeeded.** 1 component, 150 of 150 tests, completed 05:58:13Z (verified) |
| 25 | Quick deploy, then assign | `CONFIRM_PROD=1 sf project deploy quick --job-id <row 24> ...`; `sf org assign permset --name Account_Brief_Agent_Access -o agent-probe --json` | Deployed 1 of 1, completed 05:58:25Z; assignment 1 success, 0 failures (verified) |
| 26 | Evaluation definition | `sf agent test create --json --spec tests/agent/Account_Brief-testSpec.yaml --api-name Account_Brief_Test --test-runner testing-center -o agent-probe` | Created (legacy `AiEvaluationDefinition`, the CLI default). A read-only retrieve to a scratch folder shows `subjectName Account_Brief`, `subjectType AGENT`, `subjectVersion v1`, the active version (verified). The CLI also wrote the definition into `force-app/main/default/aiEvaluationDefinitions/`; that untracked file was deleted, so the tree stays clean |
| 27 | Two-turn check, turn 1 only | `sf apex run --file <scratch>/turn1.apex -o agent-probe --json` (`generateAiAgentResponse`, "Give me a brief on Edge Communications") | success, 6.2 s, the resolver's no-match reply (verified). 1 model call. Turn 2 not run |
| 28 | 12-case run, e2e | not run | No sample data; see below |
| 29 | Brain's decision: the amend is declined, the data is fixed on `main` instead | PR #72 | `BillingCountry` to `United States` and `United Kingdom`, all twelve `BillingState` codes to state names. Worktree rebased; budget raised to 4 attempts (PR #73). No redeploy, republish or reactivation |
| 30 | Starting state | `SELECT COUNT() FROM Account` | 0 (verified) |
| 31 | Seed, attempt 4 | `SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` (06:09:32 to 06:09:34Z) | **Failed:** "Data Import failed", 1 error: `MALFORMED_ID` on `ParentId` for reference `AccEdge`. No country or state errors (verified). Not retried |
| 32 | Counts | `SELECT COUNT() FROM <object>` for Account, Contact, Opportunity, OpportunityContactRole, Task, Event and Case | 0 each (verified) |
| 33 | 12-case run, two-turn check, e2e | not run | Stopped by the attempt-4 rule for a failed seed |
| 34 | Brain's fix | PR #74 | Quillfeather Group in `data/sample/account-parents.json`, the first plan entry, `saveRefs` true; the unit test checks references against earlier plan entries only. Worktree rebased; budget 5 attempts. No redeploy, republish or reactivation |
| 35 | Starting state | `SELECT COUNT() FROM Account` | 0 (verified) |
| 36 | Seed, attempt 5 | `SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` (06:19:35 to 06:19:42Z) | **Passed:** "107 records imported into agent-probe" (verified) |
| 37 | Counts | `SELECT COUNT() FROM <object>`, and a read of the Edge Communications and United Oil accounts | Account 14, Contact 14, Opportunity 47, OpportunityContactRole 7, Task 11, Event 6, Case 8: 107, the same as the records in the eight files. Edge Communications is in Austin with parent Quillfeather Group; the three United Oil accounts are there with cities New York, Singapore and none (verified) |
| 38 | 12-case run | `sf agent test run --api-name Account_Brief_Test --test-runner testing-center --wait 4 --result-format json -o agent-probe --json` (06:20:18 to 06:22:37Z on the server) | `COMPLETED`, 12 of 12 cases, 36 of 36 assertions PASS (verified). See "Agent test" |
| 39 | Two-turn check | `sf apex run` twice: turn 1, then turn 2 with turn 1's session | Both `isSuccess` true; same session; turn 2 answered about the right account (verified). See "Two-turn check" |
| 40 | e2e | `SF_TARGET_ORG=agent-probe npm run test:e2e` (06:24:04 to 06:27:21Z) | 7 passed, 1 failed (spec 2), 3.3 min (verified). See "e2e" |
| 41 | Gates, tree | the three gate commands; `git status --short` | All pass; no `aiEvaluationDefinitions` written this time; tree clean (verified) |

## Deploy and test totals

| Run | Status | Components | Passed | Errors | Apex tests run | Failures | Coverage |
|---|---|---|---|---|---|---|---|
| Validate 1, card scope | Failed | 60 | 59 | 1 | 0 | 0 | none (no tests ran) |
| Validate 2, without Agent Access | Failed | 59 | 59 | 0 | 150 | 1 | 97.6% (2022 of 2072 lines, 20 classes) |
| Validate 3, validate 2's scope with #70 | Succeeded | 59 | 59 | 0 | 150 | 0 | 97.6% (2022 of 2072 lines) |
| Quick deploy of validate 3 | Succeeded | 59 | 59 | 0 | (from validate 3) | 0 | n/a |
| Validate 4, `Account_Brief_Agent_Access` alone | Succeeded | 1 | 1 | 0 | 150 | 0 | 97.6% |
| Quick deploy of validate 4 | Succeeded | 1 | 1 | 0 | (from validate 4) | 0 | n/a |

- Org-wide coverage is 97.6%: the org holds no other Apex (inference from the starting state,
  which had none of our classes and no data). No coverage warnings.
- The #70 change, in `force-app/main/default/classes/AccountBriefMemoryTest.cls`: the test's
  setup update of three `Account_Brief_Session__c` rows runs as
  `Database.update(new List<Account_Brief_Session__c>{...}, true, AccessLevel.SYSTEM_MODE)`, so it
  no longer depends on the deploying user's field access to a brand-new object.

## Seed

### Attempt 5 (with PR #72 and PR #74)

`SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` ran once, after a read-only check
that the org had 0 Accounts, and passed: "107 records imported into agent-probe" (verified).

| Object | Count after the seed | Records in `data/sample/` |
|---|---|---|
| Account | 14 | 1 in `account-parents.json`, 13 in `accounts.json` |
| Contact | 14 | 14 |
| Opportunity | 47 | 47 |
| OpportunityContactRole | 7 | 7 |
| Task | 11 | 11 |
| Event | 6 | 6 |
| Case | 8 | 8 |

Edge Communications has billing city Austin and parent Quillfeather Group, so the parent link
resolved (verified).

### Attempt 4 (with PR #72)

`SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` ran once, after a read-only check
that the org had 0 Accounts. It failed on the Account file and wrote nothing (verified: 0 records
in Account, Contact, Opportunity, OpportunityContactRole, Task, Event and Case afterwards).

- The only error: `MALFORMED_ID` on `ParentId` for reference `AccEdge` (Edge Communications):
  "Parent Account ID: id value of incorrect type: @AccQuill" (verified). The country and state
  errors are gone, so #72 fixed those.
- Cause: `AccEdge` has `"ParentId": "@AccQuill"`, and `AccQuill` (Quillfeather Group) is in the
  same file, `accounts.json`. `sf data import tree --help` says records with lookups to records in
  another file must be listed after that file. A reference to a record in the same file is not
  resolved; it is sent as the literal text `@AccQuill`. So the attempt-3 `ParentId` error was
  this, not a knock-on error from `AccQuill` failing, as attempt 3 guessed (the guess was marked
  unproven).
- Why the unit tests pass: `tests/test_sample_data.py`,
  `test_plan_parses_and_every_reference_resolves`, accepts a reference to any record defined
  earlier in the record order, including one earlier in the same file. The import only accepts
  one saved by an earlier plan entry.
- Fix proposed here, and made by the brain as PR #74 (it worked in attempt 5): move the
  `AccQuill` record into its own file, for example `data/sample/account-parents.json`, and list it
  in `data/sample/sample-data-plan.json` as an `Account` entry with `saveRefs` true, before the
  `accounts.json` entry. Nothing in `tests/`, `e2e/` or `force-app` uses the parent link, so
  dropping `ParentId` from `AccEdge` would also work, but it loses the parent in the sample.
- The test change that would catch this, proposed here and made by the brain in PR #74: in that
  test, check each `@reference` against the references saved by earlier plan entries only, not
  against earlier records in the same file.

### Attempt 3 (before PR #72)

`SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` ran once. The tree import failed on
the Account file and wrote nothing (verified: 0 Accounts and 0 Opportunities afterwards). The
errors, per record reference:

- 12 records, `FIELD_INTEGRITY_EXCEPTION` on `BillingCountry`: "There's a problem with this
  country, even though it may appear correct. Please select a country/territory from the list of
  valid countries.: Billing Country". 11 of them carry `USA` (`AccQuill`, `AccUO1`, `AccF0` to
  `AccF8`) and 1 carries `UK` (`AccUO3`). `Singapore` was accepted (verified).
- 1 record, `MALFORMED_ID` on `ParentId`: "Parent Account ID: id value of incorrect type:
  @AccQuill" (`AccEdge`). Attempt 3 guessed this was a knock-on error from `AccQuill` failing;
  attempt 4 showed it is not (see above).

The org has State and Country Picklists turned on. `Account.BillingCountry` accepts the picklist
labels: `United States` and `United Kingdom` are valid, and every `BillingStateCode` the sample
uses exists in the picklist (verified from the Account describe). Whether other orgs that took
this file have the picklists off was not checked.

The likely fix is in `data/sample/accounts.json` alone (unproven: the import stopped on the first
file, so the other seed files never ran):

- `"BillingCountry": "USA"` to `"United States"` (12 rows) and `"UK"` to `"United Kingdom"`
  (1 row). This is the error the org reported.
- Probably also `BillingState` from the two-letter code to the state name (`"TX"` to `"Texas"`,
  12 rows). The file writes codes into the text field `BillingState`, and with the picklists on
  that field takes the state's integration value, which defaults to the name, not the code
  (unproven: each record reported only its country error, so a state error could be hidden).
- Names in both fields are also valid free text in an org without the picklists. No other file
  under `data/sample/` has a country or state field, and no unit test, e2e spec or Apex test
  asserts `USA`, `UK` or a state code (verified by search). `tests/test_sample_data.py` checks
  names and cities only.

`data/**` is forbidden for this card, so the change was an amend for the brain, who made it on
`main` as PR #72. The seed was not retried with edited copies, because the card allows only the
seed as written.

## Agent versions

`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber`,
read-only:

| When | totalSize | Agent | Version | Number | Status | Last modified |
|---|---|---|---|---|---|---|
| 05:38Z and 05:44Z (attempts 1 and 2) | 0 | n/a | n/a | n/a | n/a | n/a |
| After the publish | 1 | Account_Brief | v1 | 1 | Inactive | 2026-11-12T05:54:44Z |
| After activation | 1 | Account_Brief | v1 | 1 | **Active** | 2026-11-12T05:55:35Z |

BotDefinition had 0 rows before the publish.

## Agent test (12 cases)

Attempt 5, one run of `Account_Brief_Test` (the spec unchanged, `subjectVersion v1`, the active
version) against Account_Brief v1. Each case has three assertions: topic, action sequence and a
graded reply (1 to 5). All results verified from the run's JSON.

| Case | Utterance (short) | Topic | Actions | Reply rating | Result |
|---|---|---|---|---|---|
| 1 | Give me a brief on Edge Communications | account_brief | resolve_account, get_brief | 3 | PASS |
| 2 | What is going on with Edge Communications, and which deals are slipping? | account_brief | resolve_account, get_brief | 4 | PASS |
| 3 | Brief me on Zzqxv Nonexistent Holdings | account_brief | resolve_account | 5 | PASS |
| 4 | Brief me on a pasted Id that matches nothing | account_brief | resolve_account | 5 | PASS |
| 5 | Brief me on United Oil | account_brief | resolve_account | 5 | PASS |
| 6 | Just the open deals for Edge Communications | account_brief | resolve_account, get_brief | 4 | PASS |
| 7 | What about their open cases? (after an Edge brief) | account_brief | resolve_account, get_brief (spec: get_brief) | 5 | PASS |
| 8 | Show me their open cases (after a no-match) | account_brief | resolve_account | 5 | PASS |
| 9 | How many open opportunities are there in the whole org? (after an Edge brief) | explore | explore_data | 5 | PASS |
| 10 | How many open opportunities are there? | explore | explore_data | 5 | PASS |
| 11 | List the five largest open opportunities | explore | explore_data | 5 | PASS |
| 12 | What is the weather in Paris today? | topic_selector | none | 5 | PASS |

Score: 12 of 12 cases, 36 of 36 assertions. No case failed, so there are no failure causes to
give. Notes on the passes:

- Case 1 rated 3: the grader said the reply is a full brief but "does not explicitly resolve the
  account", though the action trace shows `resolve_account` ran first. The spec only asks that
  the reply is not just "Resolved: Edge Communications", and it is not; the grader seems to have
  wanted the resolution stated in the text.
- Cases 2 and 6 rated 4: the grader marked the extra brief sections as beyond what was asked.
  Case 6's reply says "Not requested" for the account section and still includes others.
- Case 7: the spec expects `get_brief` alone; the agent called `resolve_account` again before
  `get_brief`, and the runner scored the action assertion PASS anyway. So this runner's
  `actions_assertion` does not enforce an exact sequence (verified for this case only).
- Case 5 relayed the resolver's three lines verbatim, with each account's 18-character Id.
- Cases 9 and 10 both counted 36 open opportunities org-wide.

## Two-turn check

The check uses `Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief')`
with "Give me a brief on Edge Communications", then a second turn in a separate execution that
passes turn 1's `sessionId` with "What about their open cases?" (`docs/research/agent-api.md`).
The session Id was kept in a scratch file, never printed, and deleted afterwards.

Attempt 5 (with the seed), both turns (verified):

| Turn | Result |
|---|---|
| 1 | `isSuccess` true, no errors, 32588 ms, a session was returned. Reply 2916 characters, a full brief of Edge Communications. It starts: "A $125,540 support plan renewal and a $9,000 router refresh are both overdue, and a high-priority escalated case reports that the core router drops BGP sessions under load." |
| 2 | `isSuccess` true, no errors, 9260 ms, the same session Id came back. The reply is a brief limited to service health, without the account being named: "Five open cases with one high-priority escalation. The core router is dropping BGP sessions under load and has been escalated. Four additional cases are open ..." **Pass** |

Attempt 3 (no data), turn 1 only: `isSuccess` true, 6182 ms, the resolver's reply `No account
matches "Edge Communications". Try the full name or open the account and ask again.` (verified).

## e2e

Attempt 5, one full run: `SF_TARGET_ORG=agent-probe npm run test:e2e`, 06:24:04 to 06:27:21Z,
8 specs, 1 worker. `SF_E2E_ORG`, which would override the alias, was unset (verified). **7 passed, 1 failed** (verified). Not run in attempts 3 and 4 (no data).

| Spec | Result |
|---|---|
| 1. Cmd/Ctrl-K before the utility was ever opened | pass (7.2 s) |
| 2. Esc returns focus; Tab can leave | **fail** (27.3 s) |
| 3. Brief: headline, collapsed accordions, live region | pass (29.3 s) |
| 4. Composer pinned at 340x480, newest answer in view | pass (38.4 s) |
| 5. Latest wins | pass (13.7 s) |
| 6. Typing enables Send; Enter sends | pass (5.8 s) |
| 7. Drill and breadcrumb | pass (32.8 s) |
| 8. axe in the brief and drill states | pass (29.9 s) |

Spec 2's failure, verbatim: `focus returned to the element focused before the hotkey, and stayed
there`, `expect(locator).toBeFocused() failed`, locator
`getByRole('button', { name: 'Search', exact: true }).first()`, `element(s) not found`, at
`e2e/support/panel.js:116` from `e2e/panel.spec.js:85`, the first step ("Esc from the composer").

Cause:

- The anchor was found and focused before the hotkey (lines 80 and 81 passed), and the panel
  closed on Esc (line 84 passed). Then the Search button was no longer in the page.
- The page snapshot at the failure shows two fresh-org dialogs over the record page: "Guidance
  Center" (with "Just so you know" and "Selected for You") and "Meet the new Guidance Center",
  an admin onboarding pop-up with "Close", "Dismiss", "Focus me" and "Next". The global header's
  list items are still there but none exposes a button, so the dialogs probably hid the header
  from the accessibility tree (verified from the snapshot; the cause is inference).
- The failure screenshot (`test-failed-1.png`, git-ignored) confirms it: the Guidance Center panel
  is open on the right, the blue "Meet the new Guidance Center" walkthrough ("Step 1 of 2",
  Dismiss and Next) sits over the record page, and the rest of the page, header search box
  included, is dimmed behind an overlay (verified from the screenshot).
- The Search button was focused right after Esc (the first check in `expectFocusStays`,
  `e2e/support/panel.js`, passed) and was gone by the end of its 2.5 s wait. So the walkthrough came
  up during those 2.5 s.
- The likely cause is the org's first-run Guidance Center walkthrough covering the page, and the
  panel's focus return worked up to that moment. Both are inference. What opened the walkthrough is
  unproven: it may appear on its own some seconds after a page loads, or a key the test pressed
  (Cmd/Ctrl-K, Esc) may open it. A fix that only checks once at page load may miss a late one.
- Fix options, not made here: dismiss the Guidance Center pop-up once in agent-probe as the test
  user (a UI click that stores a user preference), or have the e2e setup close a Guidance Center
  dialog if one is open (an `e2e/` change, out of scope; listed, not made). Spec 2 makes no model
  calls, so re-running it alone costs nothing; it was not re-run, to keep to one full run.

Model calls: the README puts a full run at about seven. Specs 3, 4, 5, 7 and 8 make 1, 2, 1, 1
and 1. Spec 7 found a drillable brief line, so neither 7 nor 8 needed the extra question: 6 in
all (inference from the README's table and the passes).

## Stand the baseline up in a fresh org

**The order that worked (verified in agent-probe: steps 1 to 4 and 6 to 9 in attempt 3, step 5
in attempt 5, steps 10 to 12 in attempt 5):**

1. `sf org list --skip-connection-status --json`: find the alias and classify it from its record.
   Query `Organization` for `OrganizationType` and `IsSandbox`. If the deploy gate refuses with
   "No target org is configured", run `sf config set target-org <alias>` (project-local).
2. `npm ci`.
3. Validate everything except `aiAuthoringBundles` and
   `permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml`, with RunLocalTests:
   `sf project deploy validate --source-dir <applications> <classes> <flexipages> <lwc> <messageChannels> <objects> <staticresources> <permissionsets/Account_Brief_Data_Access.permissionset-meta.xml> --test-level RunLocalTests -o <alias> --wait 30 --json`.
   Then `CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o <alias> --wait 30 --json`.
   This needs PR #70 in the source.
4. `sf org assign permset --name Account_Brief_Data_Access -o <alias> --json`.
5. Seed: `SF_TARGET_ORG=<alias> bash scripts/seed-sample-data.sh`, then count each object
   read-only. This needs PR #72 (country and state names) and PR #74 (the parent account in its
   own, earlier plan entry). Steps 6 to 9 do not depend on the data, so the seed only has to land
   before step 10. In agent-probe it ran after step 9.
6. `bash scripts/agent-check.sh`, then publish once:
   `sf agent publish authoring-bundle --api-name Account_Brief -o <alias> --skip-retrieve --json`.
   Then `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`.
7. Query `BotVersion` (above), then `sf agent activate --api-name Account_Brief --version <N> -o <alias> --json`.
8. Validate `permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml` alone with
   RunLocalTests, quick-deploy it, then `sf org assign permset --name Account_Brief_Agent_Access -o <alias> --json`.
   From here `scripts/validate-org.sh` passes in that org.
9. `sf agent test create --json --spec tests/agent/Account_Brief-testSpec.yaml --api-name Account_Brief_Test -o <alias>`,
   then delete the file it writes under `force-app/main/default/aiEvaluationDefinitions/`. Check
   that the org definition's `subjectVersion` is the active version.

10. `sf agent test run --api-name Account_Brief_Test --test-runner testing-center --wait 4 --result-format json -o <alias> --json`.
    12 of 12 passed here.
11. The two-turn `generateAiAgentResponse` check (turn 1, then turn 2 with turn 1's
    `sessionId`). Both passed here.
12. `SF_TARGET_ORG=<alias> npm run test:e2e`. 7 of 8 passed here. In a fresh org, first dismiss
    the "Meet the new Guidance Center" pop-up as the test user, or spec 2 can fail on it
    (unproven; see "e2e").
13. The gates: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`,
    `bash scripts/validate-org.sh`, `bash scripts/agent-check.sh`.

**Not yet shown:** spec 2 passing in a fresh org.

**What did not work, and why:**

- One deploy of all of `force-app` (minus the bundle): `Account_Brief_Agent_Access` names the Bot
  `Account_Brief`, which does not exist until the publish (validate 1).
- Without that permission set but before #70: the memory test's own `update` needed field access
  the deploying user does not have on a new object (validate 2).
- Deploying the object and `Account_Brief_Data_Access` first was rejected before it ran: that
  permission set grants five Apex classes and the app, so it cannot deploy before them.
- Publishing before any deploy was not tried. The agentforce-generate skill documents that
  publish needs the Apex action targets in the org first (`deploy-reference.md`,
  `agent-metadata-and-lifecycle.md`).

## Gate results

Attempt 5, after the seed, the agent test, the two-turn check and e2e (verified):

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 72 tests, OK.
- `bash scripts/validate-org.sh`: pass (60 components, 150 tests).
- `bash scripts/agent-check.sh`: pass.
- None of the three gates runs e2e, so spec 2's failure does not show in them.

Attempt 4, after the failed seed, with the same results as attempt 3 (verified): 72 unit tests
OK, `validate-org.sh` pass (60 components, 150 tests), `agent-check.sh` pass.

Attempt 3, after the Agent Access deploy (verified):

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 72 tests, OK.
- `bash scripts/validate-org.sh`: pass (60 components, 150 tests). It failed in attempts 1 and 2
  with validate 1's error, because the Bot did not exist.
- `bash scripts/agent-check.sh`: pass. Local compile clean (0 warnings), org validate ok on
  agent-probe.

## Cleanup

- Nothing was rolled back. The org now holds `main` (60 components), the active Account_Brief v1,
  both permission set assignments, the evaluation definition `Account_Brief_Test` and the 107
  sample records.
- No data was written except what the card allows: the seed, the permission set assignments, the
  evaluation definition, and what the agent and the panel stored for their own turns (brief
  memory rows). The two failed seeds wrote nothing.
- e2e left `test-results/` and `playwright-report/` in the worktree; both are git-ignored.
- The only lasting local change outside git is the project's default org setting in
  `.sf/config.json` (git-ignored).

## e2e after FE-9

Red: `SF_TARGET_ORG=agent-probe npx playwright test -g "2\. Esc"` (the card's `^2\.` matches no spec,
because Playwright greps the full title path). Spec 2 failed at the first step, "Esc from the composer":
`focus returned to the element focused before the hotkey, and stayed there`, `expect(locator).toBeFocused()
failed`, locator `getByRole('button', { name: 'Search', exact: true }).first()`, `Expected: focused`,
`Received: inactive`, at `e2e/support/panel.js:116` (after the 2.5 s wait). The failure screenshot shows
the Edge Communications record page, normal and undimmed, with no walkthrough and no Guidance Center
panel; the snapshot lists the Search button, so it was found but not focused.

Change (`e2e/support/panel.js`, `Panel.gotoAccount` only): before the first goto it registers
`page.addLocatorHandler` for a dialog containing "Meet the new Guidance Center", which clicks that
dialog's button named exactly "Dismiss". With no walkthrough the handler never runs and adds no wait.
The Dismiss name comes from OPS-25's failure snapshot; it was not seen again in this session.

What was observed, plainly:

- The walkthrough did not appear in any run in this session. The handler never fired in the instrumented
  runs (a temporary log, removed). So the handler is unproven against a real walkthrough.
- Spec 2 failed once with the handler in place, the same Search-not-focused error, again with no
  walkthrough. The page held two hidden dialogs at that time (an error dialog and a start-of-dialog
  region) and focus was no longer on Search; what took it was not identified. Spec 2 then passed in
  5 further runs (3 of them instrumented). So spec 2 is intermittent here, and the walkthrough is
  not shown to be its only cause.
- Whether Dismiss keeps the walkthrough away on the next run: not run (no walkthrough was shown to dismiss).

Green: one full `SF_TARGET_ORG=agent-probe npm run test:e2e` run, **8 passed (3.1 m)**, spec 2 in 10.4 s.
One full run only; no repeat, so the intermittent spec 2 is not ruled out.

