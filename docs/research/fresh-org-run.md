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
- **OPS-62 (2026-11-15, the connect-24h org): the clean install stopped at its first deploy step.** The org is not empty: it already held 200 Accounts, five other agents and about 70 Apex classes that this repo does not ship, so it is not a clean install either. The validate of the README's 13 source directories failed on compile errors in those org classes, so nothing was deployed. The seed (step 2) passed. See "Clean install in a new org (OPS-62, 2026-11-15)" below.
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

### Result

The install is not proven. The deploy validate failed, so no product component reached the org. The seed passed and was
the only org write. The failure is in the org's own Apex, not in this repo: the validate runs every local test, and the org's
existing classes do not compile. This run did not change force-app, data, or scripts, and did not change the test level.

Proposed fix (not applied; a human decision, outside this card): the org's pre-existing Apex must compile before a
RunLocalTests validate can pass. That means repairing or removing the other build's classes in this org, which the card
does not allow, or validating the product on its own tests with `--test-level RunSpecifiedTests`, which the card does not
allow either. Either way, the next run needs the owner's call first.

### Deviations

1. The deploy-gate hook refused the validate ("No target org is configured") until a project-local default was set. The
   worktree was given `sf config set target-org <org-alias>` (project-local, in the git-ignored `.sf/`, not `--global`), as
   in the OPS-28 and OPS-25 runs. It is unset after the run.
2. Step order: the seed ran after the failed validate, not in the README's order. The seed does not depend on the deploy,
   so it went ahead.
3. The validate failure is not a README step. Nothing was changed to get past it, and the test level stays `RunLocalTests`.

### What the next cards need

Nothing is ready. The product is not deployed, `Customer_Summary` is not published, and the permission set group is not
assigned. The seed data is in (107 records). The account the next cards should use, once the product is in, is Edge Communications: the README's hero
image and the seed guard both name it. No agent access check was run.
