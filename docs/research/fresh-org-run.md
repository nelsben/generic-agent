# The README quick-start, run as written (OPS-28)

- Date: 2026-11-15, 00:29 to 00:42 UTC (the evening of 2026-11-14 local). The org is the existing test org,
  written `<org-alias>` below, a Developer Edition org that already held the build. Every `sf` command named it with
  `-o`; no other org was touched.
- CLI: `@salesforce/cli` 2.158.7. Playwright 1.64.1. The worktree was at the tip of `main` after OPS-36 (the FR2
  README).
- Decision: a scratch org could not be created (see "Earlier attempt: a scratch org"), and Ben decided to run the
  quick start against the test org instead. Deploys there go validate, then quick deploy, under the standing row
  "Production-classified deploys" in [gtm-burn-plan.md](../plans/gtm-burn-plan.md), Approvals.
- Status words: verified (seen in a command result or an org query), unproven (not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.

## Plain answer

- **Every command in "See it in 5 minutes" ran against a real org and did what it says (verified).** The deploy
  validated 149 of 149 components with 518 of 518 Apex tests and quick-deployed 149 of 149. The seed and the group
  assign found their work already done and changed nothing. The ladder passed every rung, the e2e smoke run
  included: 11 of 11.
- **This is not a clean install.** The org already had the build, the sample data, the group assignment and the
  published agent. The README's Status rows "A clean install from 'See it in 5 minutes'" and "Runs without the
  agent" stay **not yet proven**.
- **Runs without the agent: not testable here.** The org's agent stays published and active, and no agent was
  deactivated, deleted or unpublished.
- **OPS-62 (2026-11-15, the connect-24h org), attempt 4: the README as written deploys and publishes in a new Developer Edition org, but the e2e smoke rung fails.** The org was not empty: it already held 200 Accounts, five other agents and about 70 org Apex classes from the orgfarm template, so this is a new org with no prior Customer Summary build, not an empty org. `sf project deploy start` with the 13 source directories deployed 149 of 149 components with no tests required (the Developer Edition path). The group, the publish and activation, the agent access set and the ladder checks passed, except the e2e smoke rung, which fails in its frontdoor step (see the attempt 4 section). Earlier attempts found that the production validate path fails in a new org, because 12 tests need the group, which the README gives after the deploy. See the OPS-62 sections at the end.
- **One README fix:** the ladder line now says to set `SF_TARGET_ORG` (deviation 2).

## Steps, as typed

| # | README step | Command as typed | Result |
|---|---|---|---|
| 1 | Classify the org | `sf org list --skip-connection-status --json`; `SELECT OrganizationType, IsSandbox FROM Organization` | Not scratch, not sandbox, not a Dev Hub, no trial date; Developer Edition host markers; `Developer Edition`, `IsSandbox` false (verified). Deployed as production, as the approval says |
| 2 | 1. Deploy the metadata | `sf project deploy validate -o <org-alias>` with the README's 13 `--source-dir` lines, `--test-level RunLocalTests --wait 30 --json` | **Passed** (00:29 to 00:33): 149 of 149 components, 518 of 518 tests, 0 errors (verified) |
| 3 | 1. (quick deploy) | `CONFIRM_PROD=1 sf project deploy quick --job-id <id> -o <org-alias> --wait 30 --json` | **Passed** (00:33 to 00:34): 149 of 149 components deployed, 0 errors (verified) |
| 4 | 2. Load the sample data | `SF_TARGET_ORG=<org-alias> bash scripts/seed-sample-data.sh` | **Stopped by its own guard**, exit 1: "already has an Account named Edge Communications; nothing was imported" (verified). The script makes one read-only query first and imports only when that account is absent, so a second run cannot duplicate the 107 records |
| 5 | 3. Grant access | `sf org assign permset -o <org-alias> -n Customer_Summary_User` (with `--json`) | **Already assigned**: exit 1, 0 successes, 1 failure "Duplicate PermissionSetAssignment" (verified). Nothing changed |
| 6 | 4. Open it | `sf org open -o <org-alias>` | Not run by hand: it signs a browser in, which this run may not do. The e2e smoke run in row 8 stands in: it opens the Customer Summary app and an account, and presses the hotkeys |
| 7 | Agent appendix check | `SELECT COUNT() FROM PermissionSet WHERE Name = 'CopilotSalesforceUser'` | 1: the standard set exists in this org (verified). Not assigned: the quick start does not ask for it |
| 8 | Then run the checks | `SF_TARGET_ORG=<org-alias> SF_E2E_ORG=<org-alias> npm run ladder` | **Passed** (00:34 to 00:41), every rung; the lines are below (verified) |

The ladder's lines, as printed:

```
ladder: python         passed (2s): Ran 390 tests in 1.336s
ladder: jest           passed (5s): Tests: 381 passed, 381 total
ladder: scan           passed (4s): reported 415 violation(s); skipped the pmd, cpd and sfge engines (the Apex rules): they need Java. Installing Java 11 or later turns them on.
ladder: org-check      passed (282s): pass (150 components, 425 tests)
ladder: drift          passed (13s): in sync (the org matches main for the types checked)
ladder: e2e-smoke      passed (112s): 11 passed (1.9m)
ladder: no rung failed
```

The org-check validates 150 components where the quick start deploys 149: it also takes the agent's own permission
set, which validates here because the agent exists. In an org with no agent published that set would fail to
validate (unproven here; [org-migration.md](org-migration.md), row 8, saw it before the first publish). The full
e2e suite was not run; the ladder runs the smoke subset.

## Deviations

| # | Command as written | What happened | Change |
|---|---|---|---|
| 1 | `sf project deploy start -o <org-alias> ...` (step 1) | Not run: the org is classed as production, so the approval is validate, then quick deploy. The README already gives that path for such an org, and it passed (rows 2 and 3) | None in the README |
| 2 | `npm run ladder` | It runs, but every org rung and the e2e read `SF_TARGET_ORG` and fall back to the test org, so a reader with another org would check the wrong one | The README's line now reads `SF_TARGET_ORG=<org-alias> npm run ladder` |
| 3 | The first deploy command, before any README step | The Salesforce plugin's deploy hook refused it: "No target org is configured" | `sf config set target-org <org-alias>` in the worktree only (project-local), unset after the run. Not a README step: the hook belongs to the agent tooling, not the CLI |
| 4 | `sf org assign permset ... -n Customer_Summary_User` again | exit 1, "Duplicate PermissionSetAssignment" | None: it means already assigned |

## Not proven by this run

- A clean install: the org was not new.
- Runs without the agent: the org's agent stays published.
- The optional agent track (publish, activation, the agent's permission set, a preview turn): already in the org,
  not run again. The Testing Center suite was not run: `scripts/agent-test.sh` does not exist.
- The full e2e suite, and a run as a user who is not an admin.

## Earlier attempt: a scratch org (2026-11-14)

At 22:19 UTC, `sf org create scratch --definition-file config/project-scratch-def.json --target-dev-hub my-devhub
--alias ga-scratch --duration-days 7 --wait 9 --json` failed after about 1 s with `STORAGE_LIMIT_EXCEEDED`, "storage
limit exceeded" (verified). The Dev Hub's `DataStorageMB` was 0 of 5 remaining, and its scratch limits were fine:
`ActiveScratchOrgs` 3 of 3 and `DailyScratchOrgs` 6 of 6 remaining. No scratch org was created. The definition,
[config/project-scratch-def.json](../../config/project-scratch-def.json), is kept for a rerun once the hub has room:
edition Developer, features `EnableSetPasswordInApi` and `Einstein1AIPlatform`, and the Lightning desktop, agent
platform and Einstein generative AI settings on.

## Clean install in a new org (OPS-62, 2026-11-15)

- Date and times (UTC): 2026-11-15. The org guard ran at about 21:17. The validate ran 21:19:51 to 21:20:33. The seed ran
  21:20:59 to 21:21:07. The run stopped at about 21:22, after the failed validate.
- CLI: `@salesforce/cli` 2.158.7. Node 26.13.0 (`npm ci` installed the worktree's dependencies first, exit 0).
- Org guard: the two `sf org display` results differ (SAME or DIFFERENT only; values not written here). Take no org step
  on SAME; the run went ahead on DIFFERENT (verified).
- Org state before the run (read-only counts, verified): 200 Accounts, 5 agent definitions (`BotDefinition`), and about
  70 non-namespaced Apex classes. The org is a Developer Edition org with no Customer Summary product, no `Customer_Summary`
  agent, and no "Edge Communications" account. It is not empty, which the card assumed it was. This is a finding, not
  something this run changed.
- Classification: the host carries the orgfarm and Developer Edition markers, with no future trial date. The card treats the
  org as production, so deploys go validate, then quick deploy. Same as the OPS-28 run.
- Scope of the run: the org guard, the classification, the README's deploy validate, the seed and this record. The other
  README steps were blocked by the validate failure.

### Steps, as typed

| # | README step | Command as typed | Result | Minutes |
|---|---|---|---|---|
| 0 | Org guard | `sf org display -o <org-alias> --json` for the org and for `agent-probe`, compared in a shell expression | DIFFERENT (verified) | under 0.1 |
| 1 | Classify | `sf org list --skip-connection-status --json`; `SELECT OrganizationType, IsSandbox FROM Organization` | Developer Edition, not sandbox, not scratch, not a Dev Hub; treated as production (verified) | under 0.1 |
| 2 | Starting state | `SELECT COUNT() FROM Account`; `SELECT DeveloperName FROM BotDefinition`; `SELECT COUNT() FROM ApexClass WHERE NamespacePrefix = null` | 200, 5, 70: not empty (verified) | under 0.1 |
| 3 | 1. Deploy the metadata (validate) | `sf project deploy validate -o <org-alias>` with the README's 13 `--source-dir` lines, `--test-level RunLocalTests --wait 9 --json` | **Failed** (21:19:51 to 21:20:33, 0.7 min). Compile errors in org classes, "Variable does not exist", with the dependent classes marked invalid and needing recompilation. The repo's classes do not include the failing names (checked for AgentActionsTest, AgentCaseActions and the others). 0 components deployed (verified) | 0.7 |
| 4 | 1. (quick deploy) | not run | Blocked: nothing validated | 0 |
| 5 | 2. Load the sample data | `SF_TARGET_ORG=<org-alias> bash scripts/seed-sample-data.sh` | **Passed** (21:20:59 to 21:21:07): "107 records imported" (verified) | 0.1 |
| 6 | 3. Grant access | `sf org assign permset -o <org-alias> -n Customer_Summary_User` | Not run: the permission set group is not in the org | 0 |
| 7 | 4. Open it | `sf org open -o <org-alias>` | Not run: needs the deployed app and a browser sign-in | 0 |
| 8 | Agent (publish, activate) | `sf agent publish` and `sf agent activate` for `Customer_Summary` | Not run: the agent comes from the deploy | 0 |
| 9 | Then run the checks | `SF_TARGET_ORG=<org-alias> SF_E2E_ORG=<org-alias> npm run ladder` | Not run: the org rungs need the deployed product | 0 |

Counts: components 0 of 149 deployed; Apex tests not counted (the validate failed before a count was read); records
seeded 107; ladder rungs 0 of 6 run. Total time for the steps run: about 1 minute, plus the guard and the classification.

### Attempt 1 result

The install is not proven. The deploy validate failed, so no product component reached the org. The seed passed and was
the only org write. The failure is in the org's own Apex, not in this repo: the validate runs every local test, and the org's
existing classes do not compile. This run did not change force-app, data, or scripts, and did not change the test level.

Attempt 2 (below) took the coordinator's option: validate with `--test-level RunSpecifiedTests` over the 31 test
classes. It did not get through either. The other option, repairing or removing the other build's classes in this org,
is outside this card.

### Attempt 2 (2026-11-15, after the coordinator instruction)

- Times (UTC): the validate ran 21:26:41 to 21:27:14. A diagnostic validate with one test class ran from 21:27:58, and its
  client timed out at about 21:41 (`--wait 9`; no job result read). The seed re-run was 21:42:04 to 21:42:05.
- Validate, as typed: `sf project deploy validate -o <org-alias>` with the same 13 `--source-dir` lines,
  `--test-level RunSpecifiedTests --tests <the 31 names of the *Test.cls files under force-app>`. The test names are the
  test classes the README's repo holds, found with `find force-app -name '*Test.cls'`. `--tests` takes one flag followed by
  all the names; a repeated `--tests` flag is refused by the CLI.
- Result: **Failed** (verified). 149 of 149 components validated with 0 component errors. Every Apex class in the deploy got a
  coverage error: "Test coverage of selected Apex Class is 0%, at least 75% test coverage is required".
- Correction (added in attempt 3): the "0 tests ran" statement above was wrong. The tests did run. The brain reran this
  validate and read the deploy report: 413 of 425 tests passed and 12 failed, all on field access (see attempt 3). The
  attempt-2 job's own report, read by this run, showed 0 tests total; that reading is not explained by anything in this
  run's output, and it is recorded here rather than dropped.
- Diagnostic: the same validate with one test class (`CustomerSummaryTest`) did not finish within `--wait 9`. The client
  timed out. The job result was not read, so the test count for that run is unknown.
- Seed, the README step 2 re-run as written: **stopped by its own guard**, exit 1: "already has an Account named Edge
  Communications; nothing was imported" (verified). The records from attempt 1 are in.
- Not run, because no validated job with test results exists: the quick deploy, the permission set group assignment, the
  open, the agent publish and activation, the ladder and the e2e. The coordinator's rule says record the error class and
  stop, which is what this run did.
- Error classes to record: a RunLocalTests validate fails on compile errors in the org's own classes (attempt 1). A
  RunSpecifiedTests validate over the 31 test classes reaches the tests and fails 12 of 425 on field access (the brain's
  rerun; see attempt 3). The 0% coverage lines above came from this run's job report, which did not show the test results.

### Attempt 3 (2026-11-15, after coordinator instruction 2)

- Times (UTC): the NoTestRun validate was refused at 21:56:20. The RunSpecifiedTests validate ran 21:56:28 to 21:56:43.
- Step 1 as the coordinator set it: validate and quick deploy of `objects`, the two permission set files and
  `permissionsetgroups`, with no Apex. Result: **blocked** (verified).
  - `sf project deploy validate --test-level NoTestRun` is refused by the CLI: the allowed levels are RunAllTestsInOrg,
    RunLocalTests, RunSpecifiedTests and RunRelevantTests.
  - With `--test-level RunSpecifiedTests --tests CustomerSummaryTest` (the fallback the coordinator named), the validate
    failed: "Error in Customer_Summary_Data_Access - In field: apexClass - no ApexClass named BrandSettings found". 0
    components deployed.
  - Why: `Customer_Summary_Data_Access` grants 12 Apex classes, which the org does not have yet, and it is one of the two
    permission sets in `Customer_Summary_User`. `Customer_Summary_Outcome_Access` grants no Apex classes; it grants
    `Customer_Outcome__c.Related_Record_Id__c`. `Customer_Summary_Data_Access` grants `Customer_Summary_Session__c.Session_Key__c`.
  - So the permission set group cannot deploy before the Apex, and the Apex cannot deploy without passing tests. The tests
    need the group for field access. That is a loop, not a step order.
- Steps 2 to 4 (group assignment, full validate with --async and report polling, quick deploy, the rest of the README)
  were not run. The org was not changed in this attempt: nothing was deployed and no permission was assigned.
- Main finding for the next card (the brain's rerun, recorded here as reported): the README's order fails in a new org.
  The 12 failures are on field access: `No such column 'Related_Record_Id__c' on entity 'Customer_Outcome__c'` (5),
  `No such column 'Session_Key__c' on entity 'Customer_Summary_Session__c'` (3), and 4 assertion or no-rows failures in
  CustomerSummaryContextTest, CustomerSummaryActionsTest and CustomerSummaryActionUpdatesTest. The admin did not hold the group
  when the tests ran.
- Options for the brain (not applied; each changes force-app, the group, or the test level, which this card does not allow):
  (a) assign `Customer_Summary_Outcome_Access` directly to the admin (it has no Apex, so it can deploy first) and see whether
  that clears the field failures; this is a single permission set, not the group, so it is a deviation from the README;
  (b) change `Customer_Summary_Data_Access` so it does not grant the Apex classes until they deploy, which is a force-app change;
  (c) run the full validate with the test failures accepted, which Salesforce does not allow for an Apex deploy.

### Attempt 4 (2026-11-15, after coordinator instruction 3)

Instruction 3 uses the README's step 1 as written, `sf project deploy start`, because the org is classified as a
non-production Developer Edition org (the orgfarm host, no trial date, not scratch, not a sandbox, not a Dev Hub). A
Developer Edition deploy runs no Apex tests, so the 12 field-access tests from attempt 3 do not block it.

| # | README step | Command as typed (with `<org-alias>`) | Result (UTC) | Minutes |
|---|---|---|---|---|
| 1a | 1. Deploy (dry run) | `sf project deploy start -o <org-alias>` with the README's 13 `--source-dir` lines, `--dry-run --wait 9 --json` | **Succeeded**, 149 of 149 components, 0 errors, no tests (21:59:23 to 21:59:45, verified) | 0.4 |
| 1b | 1. Deploy | the same command without `--dry-run`, `--wait 9 --json` | **Succeeded**, 149 of 149 components, 0 errors (22:00:13 to 22:00:39, verified) | 0.5 |
| 2 | 2. Load the sample data | not re-run in this attempt; it passed in attempt 1 and its guard stopped the re-run in attempt 2 | Done in attempt 1: 107 records | 0 |
| 3 | 3. Grant access | `sf org assign permset -o <org-alias> -n Customer_Summary_User --json` | **Succeeded**: 1 success, 0 failures (22:00:46 to 22:00:49, verified) | 0.1 |
| 4 | 4. Open it | `sf org open -o <org-alias>` | Not run as typed: it opens a browser. A one-off check of the frontdoor (the same call with `--url-only`, printing only the landing path and title) reached the Lightning Home page (verified) | 0 |
| 5 | Agent: publish | `sf agent publish authoring-bundle --api-name Customer_Summary -o <org-alias> --skip-retrieve --json` | **Succeeded**: `success` true, `botDeveloperName` Customer_Summary (22:01:10 to 22:01:29, verified). Activation then reported version 1 (step 6) | 0.3 |
| 6 | Agent: activate | `sf agent activate --api-name Customer_Summary --version 1 -o <org-alias> --json` | **Succeeded**: version 1 (22:01:55 to 22:01:58, verified) | 0.1 |
| 7 | Agent: restore the bundle | `git checkout -- force-app/main/default/aiAuthoringBundles/Customer_Summary` | Done; the tree was clean after the publish | 0 |
| 8 | Agent: access set | `sf project deploy start -o <org-alias> --source-dir .../Customer_Summary_Agent_Access.permissionset-meta.xml`, then `sf org assign permset -o <org-alias> -n Customer_Summary_Agent_Access` | **Succeeded**: deployed 1 of 1; assigned, 1 success, 0 failures (verified) | 0.2 |
| 8b | Agent access set's optional standard set | `CopilotSalesforceUser` | Not checked in this attempt (the appendix says its name is unconfirmed) | 0 |
| 9 | Then run the checks: ladder | `SF_TARGET_ORG=<org-alias> SF_E2E_ORG=<org-alias> npm run ladder` (22:02:24 to 22:08) | python passed (390 tests); jest passed (381 of 381); scan passed (415 violations reported; pmd, cpd and sfge skipped, they need Java); **org-check passed** in 237 s (150 components, 425 tests); **drift passed** (in sync); **e2e-smoke failed** in 66 s (see below); stopped at the first failure, so no rung after e2e-smoke ran | 7 |
| 10 | e2e (smoke) rerun | `SF_TARGET_ORG=<org-alias> SF_E2E_ORG=<org-alias> npm run test:e2e:smoke` (22:08:43 to 22:09:48) | **Failed**: the same error as the ladder's e2e-smoke rung | 1 |

Ladder counts: 6 rungs run, 5 passed, 1 failed (e2e-smoke). Components 149 of 149 deployed. Apex tests: the org-check ran
425 tests and passed. Records seeded: 107 (attempt 1).

**The e2e failure.** Global setup in `e2e/global-setup.js` calls `sf org open --url-only`, opens the URL in a fresh
headless browser, and waits for the page path to start with `/lightning/`. The sf call and the Account lookup both work
when run by hand (verified with a one-off check that prints only status and counts). A one-off browser check of the same
frontdoor, printing only the landing path and the page title, reached `/lightning` with the title "Home | Salesforce"
(verified). `/lightning` does not start with `/lightning/`, so the wait times out, and the setup throws the login hint.
The likely cause is that this path check is too strict for a new org's landing page; a fix has not been made or tested. The
card does not allow edits under `e2e/`, so nothing was changed. Proposed fix (for the next card): accept the path
`/lightning` as well as `/lightning/...`.

### Final result (attempt 4)

- The deploy (step 1), the group (step 3), the agent publish and activation, and the agent access set all passed, with
  the README order as written.
- The ladder passed its python, jest, scan, org-check and drift rungs. The e2e smoke rung failed (above), so the run is
  not proven and the README row stays "Not yet proven".
- The org was not empty before the run, so the result is "a new org with no prior Customer Summary build", not an empty org.

### Deviations

1. The deploy-gate hook refused the validate ("No target org is configured") until a project-local default was set. The
   worktree was given `sf config set target-org <org-alias>` (project-local, in the git-ignored `.sf/`, not `--global`), as
   in the OPS-28 and OPS-25 runs. It is unset after the run.
2. Step order: the seed ran after the failed validate, not in the README's order. The seed does not depend on the deploy,
   so it went ahead.
3. The validate failure is not a README step. Nothing was changed to get past it.
4. Attempt 2 validated with `--test-level RunSpecifiedTests` over the 31 test classes, not `RunLocalTests`, on the
   coordinator's instruction. The README's deploy line stays as written: this run did not prove it wrong for a clean org.
5. The project-local default org was set again for attempts 2 and 3 and unset after each run (same method as deviation 1).
6. Attempt 3's NoTestRun validate was refused by the CLI, so the fallback RunSpecifiedTests with one test class was used, as the
   coordinator allowed. That validate failed on the permission set's Apex references (attempt 3).
7. Attempt 4 used `sf project deploy start`, the README's step 1 as written, on the coordinator's instruction 3 (the Developer
   Edition classification). No change to the README.
8. The project-local default org was set again for attempt 4 and unset after the e2e rerun.

### What the next cards need

Product, agent and permission sets are in (attempt 4). The e2e smoke rung fails on the frontdoor path check in
`e2e/global-setup.js` (see attempt 4), so the next card needs that fixed before the e2e can be proven. The seed data is in (107 records). The account the next cards should use, once the product is in, is Edge Communications: the README's hero
image and the seed guard both name it. No agent access check was run.

## e2e smoke after the landing fix (FE-29, 2026-11-15)

The landing fix: `e2e/global-setup.js` now accepts a landing path of exactly `/lightning` as well as any path starting with
`/lightning/`. No wait time changed.

Red first (`.delegation/FE-29/red-1.txt`, before the change): `SF_TARGET_ORG=connect-24h SF_E2E_ORG=connect-24h npm run test:e2e:smoke`
ended in global setup with the one-line sign-in hint. The `try` around the frontdoor `goto` and the `/lightning/` wait rethrows every
error as that hint, so the timeout was hidden behind it. The sf CLI session itself was fine (the org open and the account query both
succeeded when run directly).

Results, in order:

- `npm run test:e2e:smoke` after the fix: 11 passed, 0 failed (exit 0). Sign-in reached Lightning in the new org.
- The unit gate (`python3 -m unittest discover -s tests`, run under the `gate-mac` lease): 390 tests, OK (skipped=4).
- `SF_TARGET_ORG=connect-24h SF_E2E_ORG=connect-24h npm run ladder`:
  - python: passed (390 tests)
  - jest: passed (381 of 381)
  - scan: passed (415 violations reported; the PMD, CPD and SFGE Apex engines were skipped because they need Java)
  - org-check: passed (check-only validate, 150 components, 425 tests)
  - drift: passed (in sync with main for the types checked)
  - e2e-smoke: **failed**, 1 failed and 10 passed (3.4 minutes). The failing spec is
    `e2e/panel.spec.js:98`, "Cmd/Ctrl-K before the window was ever opened opens it in the bottom right corner and focuses the composer".
    It timed out after 60 seconds waiting for the Edge Communications "Summarize" button inside the panel stage to attach.
    Likely cause, not confirmed: the panel did not show the account record when the hotkey spec ran, so its precondition never
    held. The sign-in itself passed. This card does not fix the spec.
  - The ladder stopped at the first failure, so the rungs after e2e-smoke did not run.

The smoke was green once (11 of 11) and red once in the ladder (10 of 11), so the hotkey spec is intermittent in this org. A rerun
is needed before the e2e can be called proven.

Verdict: the README's "A clean install" row stays Not yet proven. The e2e-smoke rung failed (the hotkey spec above).
The org was not empty: it carries the orgfarm template data, as in the OPS-62 run.
