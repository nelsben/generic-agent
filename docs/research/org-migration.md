# Org move: main to agent-probe (OPS-25)

- Date: 2026-11-12, 05:30 to 06:05 UTC. Target org alias `agent-probe`. Three attempts; this page
  records all three, and attempt 3 is the current state.
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf` (the spike used 2.157.8).
- Approval: "Phase 2: migrate to the fresh Developer Edition org that publishes (deploy, publish,
  activate there)" in `docs/plans/gtm-burn-plan.md`, Approvals. The staged order and the rerun
  were the brain's decisions on the same approval line.
- Status words: verified (seen in a command result or an org query), unproven (inference, not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.

## Plain answer

- **`main` is deployed to agent-probe, and Account_Brief is published and active there (v1,
  verified).** Both permission sets are deployed and assigned to the running user. The org
  evaluation definition `Account_Brief_Test` exists and points at `subjectVersion v1`.
- **The seed failed, so the org has no sample data (0 Accounts, 0 Opportunities, verified).** The
  org has State and Country Picklists turned on, and `data/sample/accounts.json` writes
  `BillingCountry` as `USA` and `UK`, which that picklist rejects. The fix is a data change in
  `data/sample/accounts.json` (`USA` to `United States`, `UK` to `United Kingdom`), a forbidden path
  for this card, so it was not made. See "Seed" below.
- **The 12-case agent test, the two-turn check and e2e were not run.** Each needs the account Edge
  Communications, and most cases need more seeded accounts. With no data they would only spend
  model calls on known failures. 0 model calls were made in the org.
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

Attempts 1 and 2 changed nothing in the org. Attempt 3 is rows 14 to 27.

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
| 27 | 12-case run, two-turn check, e2e | not run | No sample data; see below |

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

`SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` ran once. The tree import failed on
the Account file and wrote nothing (verified: 0 Accounts and 0 Opportunities afterwards). The
errors, per record reference:

- 12 records, `FIELD_INTEGRITY_EXCEPTION` on `BillingCountry`: "There's a problem with this
  country, even though it may appear correct. Please select a country/territory from the list of
  valid countries.: Billing Country". 11 of them carry `USA` (`AccQuill`, `AccUO1`, `AccF0` to
  `AccF8`) and 1 carries `UK` (`AccUO3`). `Singapore` was accepted (verified).
- 1 record, `MALFORMED_ID` on `ParentId`: "Parent Account ID: id value of incorrect type:
  @AccQuill" (`AccEdge`). `AccEdge`'s parent is `AccQuill`, one of the failed rows, so this is
  probably a knock-on error that goes away once `AccQuill` loads (unproven).

The org has State and Country Picklists turned on. `Account.BillingCountry` accepts the picklist
labels: `United States` and `United Kingdom` are valid, and every `BillingStateCode` the sample
uses exists in the picklist (verified from the Account describe). Whether other orgs that took
this file have the picklists off was not checked.

The fix is two value changes in `data/sample/accounts.json`: `"BillingCountry": "USA"` to
`"United States"` (12 rows) and `"UK"` to `"United Kingdom"` (1 row). Those labels are also valid
free text in an org without the picklists. `data/**` is forbidden for this card, so the change is
an amend for the brain. The seed was not retried with edited copies, because the card allows only
the seed as written.

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

| Case | Utterance (short) | Result |
|---|---|---|
| 1 to 12 | `tests/agent/Account_Brief-testSpec.yaml` | not run: no sample data (the seed failed) |

- The evaluation definition `Account_Brief_Test` is in the org, from the spec unchanged, with
  `subjectVersion v1`, the active version (verified). `sf agent test run --api-name
  Account_Brief_Test --wait 5 --result-format json -o agent-probe --json` can run it once the
  seed lands.
- Cases 1, 2, 6, 7, 8 and 9 name Edge Communications, and case 5 needs the three United Oil
  accounts. Without the seed those cases would fail on data, not on the agent.

## Two-turn check

Not run. It needs the account Edge Communications. The prepared check uses
`Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief')` with "Give me a
brief on Edge Communications", then a second turn on the returned session (`docs/research/agent-api.md`).

## e2e

Not run. Global setup needs the account Edge Communications.

## Stand the baseline up in a fresh org

**The order that worked (verified in agent-probe, attempt 3):**

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
   read-only. **Blocked here in agent-probe** (State and Country Picklists); it needs the
   `data/sample/accounts.json` change under "Seed" first. The steps after this one do not depend
   on the data, so they ran.
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

**Not yet shown (needs the seed):** `sf agent test run` and `results` for the 12 cases, the
two-turn `generateAiAgentResponse` check and `npm run test:e2e`.

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

Attempt 3, after the Agent Access deploy (verified):

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 72 tests, OK.
- `bash scripts/validate-org.sh`: pass (60 components, 150 tests). It failed in attempts 1 and 2
  with validate 1's error, because the Bot did not exist.
- `bash scripts/agent-check.sh`: pass. Local compile clean (0 warnings), org validate ok on
  agent-probe.

## Cleanup

- Nothing was rolled back. The org now holds `main` (60 components), the active Account_Brief v1,
  both permission set assignments and the evaluation definition `Account_Brief_Test`. No sample
  data.
- No data was written except what the card allows: the permission set assignments and the
  evaluation definition. The failed seed wrote nothing.
- The only lasting local change outside git is the project's default org setting in
  `.sf/config.json` (git-ignored).
