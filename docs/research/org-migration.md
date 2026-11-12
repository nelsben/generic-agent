# Org move: main to agent-probe (OPS-25)

- Date: 2026-11-12, 05:30 to 05:45 UTC. Target org alias `agent-probe`.
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf` (the spike used 2.157.8).
- Approval: "Phase 2: migrate to the fresh Developer Edition org that publishes (deploy, publish,
  activate there)" in `docs/plans/gtm-burn-plan.md`, Approvals.
- Status words: verified (seen in a command result or an org query), unproven (inference, not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.

## Plain answer

- **Stopped at the deploy step, twice. Nothing was deployed, seeded, published or tested.**
  Both runs were check-only validates, so the org is unchanged.
- **Validate 1** (the card's scope, all of `force-app` except `aiAuthoringBundles`) failed on one
  component (verified):
  `PermissionSet Account_Brief_Agent_Access: In field: botDefinition - no Bot named Account_Brief found`.
- **Validate 2** (the brain's staged order: the same scope without `Account_Brief_Agent_Access`)
  passed all 59 components, but 1 of 150 Apex tests failed (verified):
  `AccountBriefMemoryTest.rowsPerUserAreCappedAndTheOldestGoFirst`:
  `System.DmlException: Operation failed due to fields being inaccessible on Sobject Account_Brief_Session__c`,
  at the test's own `update` of `Last_Activity__c` (line 203). The same 150 tests passed in
  `experimental` (`deploy-verify.md`). The likely cause is that the deploying user has no field
  access to the new object in a fresh org: `Account_Brief_Data_Access` grants it, but cannot be
  assigned before it is deployed. That is inference; why a plain `update` in a test checks field
  access at all was not established.
- BotDefinition had 0 rows before any step here (and still has), so the minimal probe agent that
  the creating session published is not in this org. Whether this org publishes Account_Brief is
  still unshown: the run never reached the publish.
- Validate 1's permission set grants access to the agent `Account_Brief`. A fresh org has no agent until
  the bundle is published. The agentforce-generate skill documents that publish needs the
  action targets in the org first: `deploy-reference.md` says to verify every Flow and Apex target
  exists before publishing, and `agent-metadata-and-lifecycle.md` says `sf agent validate` can
  pass while publish fails on missing action implementations (documented; not tried in this org).
  If that holds, `force-app` as one deploy cannot land in a fresh org before the agent exists, and
  the agent cannot publish before most of `force-app` is deployed.
- The card says to stop on a deploy failure without changing `force-app`. Every later step was
  skipped: the quick deploy, the permission set assignments, the seed, the publish, activation,
  the 12-case test, the two-turn check and e2e.
- The org is unchanged: 0 Accounts, 0 of our Apex classes, 0 agents, 0 BotVersions (verified
  at 05:44Z, after validate 2).
- The likely fix is a three-stage deploy: the object and the data access permission set first,
  then the rest, then the agent access permission set after the publish. It is under "Stand the
  baseline up in a fresh org", marked unproven.

## What was done, in order

| # | Step | Command (abridged) | Outcome |
|---|---|---|---|
| 1 | Read the Approvals and Phase 2 sections, the four research and plan pages, and loaded the five named skills | n/a | Phase 2 deploy, publish and activate in the new org are approved |
| 2 | Install | `npm ci` | ok |
| 3 | Classify the org | `sf org list --skip-connection-status --json` | Record found by alias: not scratch, not sandbox, not a Dev Hub, no trial expiry date, API 68.0, not the default org. Its instance host carries the Developer Edition markers that the deploy skill lists, so the skill's first-match rule would class it as Developer Edition (non-production). The card treats it as production, so the card's validate-then-quick-deploy path was used (verified) |
| 4 | Edition | `SELECT OrganizationType, IsSandbox, TrialExpirationDate FROM Organization` | `Developer Edition`, `IsSandbox` false, no trial end date (verified) |
| 5 | Starting state | `SELECT COUNT() FROM Account`; `SELECT DeveloperName FROM BotDefinition` | 0 Accounts, 0 agents (verified). The minimal agent the creating session published is not listed |
| 6 | Flags | `--help` on deploy validate and quick, org assign permset, agent publish and activate, agent test create, run and results | All flags used or planned exist; activate has `--version` |
| 7 | Default org | First validate attempt | Refused by the plugin's deploy-gate hook: "No target org is configured". Ran `sf config set target-org agent-probe` (project-local, `.sf/` is git-ignored, not `--global`) |
| 8 | Validate 1 (production path) | `sf project deploy validate --source-dir <every force-app folder except aiAuthoringBundles> --test-level RunLocalTests -o agent-probe --wait 30 --json` | **Failed.** 60 components, 59 passed, 1 error (above). 0 tests run and no coverage (verified with a read-only `sf project deploy report`). That the server skipped the tests because a component failed is inference |
| 9 | Quick deploy | not run | Skipped: no validated job to promote |
| 10 | Brain's decision, after the first hand-back: the staged order, split around the agent's own permission set | n/a | Same approval line; run each step once |
| 11 | Validate 2 (production path) | `sf project deploy validate --source-dir <applications, classes, flexipages, lwc, messageChannels, objects, staticresources, and permissionsets/Account_Brief_Data_Access.permissionset-meta.xml alone> --test-level RunLocalTests -o agent-probe --wait 30 --json` | **Failed.** 59 components, 59 passed, 0 errors. 150 Apex tests, 149 passed, 1 failed (verified, from the result and a read-only `sf project deploy report`). Server time 05:42:32 to 05:43:28Z, tests 44.8 s |
| 12 | Quick deploy, assignments, seed, publish, activate, agent access deploy, tests | not run | Skipped: a failed validation cannot be quick-deployed, and the card's stop rule applies |
| 13 | State check | read-only counts | 0 of our Apex classes, 0 Accounts, 0 BotDefinitions, 0 BotVersions at 05:44Z (verified) |

## Deploy and test totals

| Run | Status | Components | Passed | Errors | Apex tests run | Failures | Coverage of the validated classes |
|---|---|---|---|---|---|---|---|
| Validate 1, card scope, RunLocalTests | Failed | 60 | 59 | 1 | 0 | 0 | none (no tests ran) |
| Validate 2, without Agent Access, RunLocalTests | Failed | 59 | 59 | 0 | 150 | 1 | 97.6% (2022 of 2072 lines, 20 classes) |
| Quick deploy | not run | n/a | n/a | n/a | n/a | n/a | n/a |

- Org-wide coverage: the org holds no other Apex, so validate 2's 97.6% is what org-wide coverage
  would have been (inference from the validate result; nothing was deployed). No coverage warnings.
- Validate 1's component error, verbatim:
  `Error in Account_Brief_Agent_Access - In field: botDefinition - no Bot named Account_Brief found`.
- Validate 2's test failure, verbatim:
  `AccountBriefMemoryTest.rowsPerUserAreCappedAndTheOldestGoFirst`:
  `System.DmlException: Operation failed due to fields being inaccessible on Sobject Account_Brief_Session__c, check errors on Exception or Result!`
  Stack: `Class.AccountBriefMemoryTest.rowsPerUserAreCappedAndTheOldestGoFirst: line 203, column 1`.
  Line 203 is the test's own `update` of three `Account_Brief_Session__c` rows, setting
  `Last_Activity__c`. The test class is API 68.0, like the rest of `force-app`.

## Agent versions

`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber`,
run read-only at 05:38Z and again at 05:44Z: `totalSize` 0, no rows. No version is active,
because no agent exists. BotDefinition had 0 rows before any step of this card.

## Agent test (12 cases)

| Case | Utterance (short) | Result |
|---|---|---|
| 1 to 12 | `tests/agent/Account_Brief-testSpec.yaml` | not run: no agent, no deploy, no sample data |

## Two-turn check

Not run. It needs an active Account_Brief and the account Edge Communications.

## e2e

Not run. Global setup needs the account Edge Communications and the deployed panel.

## Stand the baseline up in a fresh org

**Steps that worked tonight:**

1. `sf org list --skip-connection-status --json`: find the alias and classify it from its record.
   Query `Organization` for `OrganizationType` and `IsSandbox`.
2. Set a project default org if the deploy gate refuses: `sf config set target-org <alias>`.
3. `npm ci`.

**The exact blocker:** in a fresh org, a deploy that carries our Apex tests fails before the
running user can be given field access to `Account_Brief_Session__c`:

- With the card's scope, `Account_Brief_Agent_Access` fails because the Bot `Account_Brief` does
  not exist yet (validate 1).
- Without that permission set, `AccountBriefMemoryTest.rowsPerUserAreCappedAndTheOldestGoFirst`
  fails with "fields being inaccessible on Sobject Account_Brief_Session__c" (validate 2).
- `scripts/validate-org.sh` (the `org` gate) uses the card's scope, so it fails in a fresh org
  until the agent is published there.

**The order that would likely work next (unproven; the first stage is new, so it needs the
brain's go):**

1. Validate and quick-deploy only `objects/` and
   `permissionsets/Account_Brief_Data_Access.permissionset-meta.xml`. This tests the field-access
   hypothesis: it carries no Apex, and the org holds none, so no tests should run.
2. Assign `Account_Brief_Data_Access` to the running user.
3. Validate with RunLocalTests and quick-deploy the rest except `aiAuthoringBundles` and
   `Account_Brief_Agent_Access` (validate 2's scope). If the test still fails with the
   permission set assigned, the hypothesis is wrong, and the test needs its own card.
4. Seed: `SF_TARGET_ORG=<alias> bash scripts/seed-sample-data.sh`, then count each object read-only.
5. `bash scripts/agent-check.sh`, then publish once:
   `sf agent publish authoring-bundle --api-name Account_Brief -o <alias> --skip-retrieve --json`.
   Then `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`.
6. Query `BotVersion`, then `sf agent activate --api-name Account_Brief --version <N> -o <alias> --json`.
7. Validate with RunLocalTests and quick-deploy `Account_Brief_Agent_Access`, then assign it.
   From here `scripts/validate-org.sh` can pass in that org.
8. The 12-case spec (`sf agent test create`, `run`, `results`), the two-turn
   `generateAiAgentResponse` check (`docs/research/agent-api.md`) and `npm run test:e2e`.

Publishing first, before any deploy, would avoid the agent access split but not the test
failure. The skill documents that publish fails without the Apex targets: `deploy-reference.md`
says to verify every Flow and Apex target exists before publishing, and
`agent-metadata-and-lifecycle.md` says `sf agent validate` can pass while publish fails on missing
action implementations. The gate's `agent-check.sh` passing here, with no Apex in the org, fits
that. So publish-first is not recommended; it is also untried.

Two source changes would make a single deploy land in a fresh org. Both are unproven and each
belongs to its own card: move the agent access grant out of the routine deploy, and make the
memory test's own setup DML independent of the running user's field access.

## Gate results

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 72 tests, OK.
- `bash scripts/agent-check.sh`: pass. Local compile clean (0 warnings), and
  `sf agent validate authoring-bundle` passed on agent-probe even though none of the Apex its
  actions call is in the org yet (verified).
- `bash scripts/validate-org.sh`: fail, with validate 1's component error (it uses the card's
  scope). Same result at the first hand-back and after validate 2.

## Cleanup

Nothing to clean up in the org. The only lasting local change is the project's default org
setting in `.sf/config.json` (git-ignored).
