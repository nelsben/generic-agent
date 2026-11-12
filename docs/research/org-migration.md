# Org move: main to agent-probe (OPS-25)

- Date: 2026-11-12, 05:30 to 05:40 UTC. Target org alias `agent-probe`.
- CLI: `@salesforce/cli` 2.158.7 at `/usr/local/bin/sf` (the spike used 2.157.8).
- Approval: "Phase 2: migrate to the fresh Developer Edition org that publishes (deploy, publish,
  activate there)" in `docs/plans/gtm-burn-plan.md`, Approvals.
- Status words: verified (seen in a command result or an org query), unproven (inference, not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.

## Plain answer

- **Stopped at the first org step. Nothing was deployed, seeded, published or tested.** The
  check-only validate of `force-app` failed on one component (verified):
  `PermissionSet Account_Brief_Agent_Access: In field: botDefinition - no Bot named Account_Brief found`.
- The permission set grants access to the agent `Account_Brief`. A fresh org has no agent until
  the bundle is published, and the bundle cannot publish before the Apex its actions call is
  deployed. So `force-app` as one deploy cannot land in a fresh org: the order is circular.
- The card says to stop on a deploy failure without changing `force-app`. Every later step was
  skipped: the quick deploy, the permission set assignments, the seed, the publish, activation,
  the 12-case test, the two-turn check and e2e.
- The org is unchanged: 0 Accounts, 0 of our Apex classes, 0 agents, 0 BotVersions (verified
  afterwards). The validate was check-only and saves nothing.
- The likely fix is to split the deploy in two, around the publish. It is listed under "Stand the
  baseline up in a fresh org", marked unproven, because it changes the card's deploy scope.

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
| 8 | Validate (production path) | `sf project deploy validate --source-dir <every force-app folder except aiAuthoringBundles> --test-level RunLocalTests -o agent-probe --wait 30 --json` | **Failed.** 60 components, 59 passed, 1 error (above). 0 tests run and no coverage (verified with a read-only `sf project deploy report`). That the server skipped the tests because a component failed is inference |
| 9 | Quick deploy | not run | Skipped: no validated job to promote |
| 10 | Assign `Account_Brief_Agent_Access` and `Account_Brief_Data_Access` | not run | Skipped: neither permission set exists in the org |
| 11 | `SF_TARGET_ORG=agent-probe bash scripts/seed-sample-data.sh` | not run | Skipped (card stop rule) |
| 12 | `bash scripts/agent-check.sh`, publish, `git checkout` of the bundle, BotVersion query, activate | not run as a card step | Skipped (card stop rule). The gate below runs `agent-check.sh`, which is read-only |
| 13 | 12-case spec, two-turn check, `npm run test:e2e` | not run | Skipped: no deploy, no data, no agent |

## Deploy and test totals

| Run | Status | Components | Passed | Errors | Apex tests run | Failures | Org-wide coverage |
|---|---|---|---|---|---|---|---|
| Validate, RunLocalTests | Failed | 60 | 59 | 1 | 0 | 0 | none (no tests ran) |
| Quick deploy | not run | n/a | n/a | n/a | n/a | n/a | n/a |

The one component error, verbatim:
`Error in Account_Brief_Agent_Access - In field: botDefinition - no Bot named Account_Brief found`.

## Agent versions

`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion ORDER BY BotDefinition.DeveloperName, VersionNumber`,
run read-only at 05:38Z after the stop: `totalSize` 0, no rows. No version is active, because no
agent exists.

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

**The exact blocker:** `sf project deploy validate` of all of `force-app` except
`aiAuthoringBundles` fails in any org without the agent, because
`Account_Brief_Agent_Access` grants access to a Bot named `Account_Brief` that does not exist yet.
`scripts/validate-org.sh` (the `org` gate) uses the same scope, so it fails in a fresh org for the
same reason until the agent is published there.

**The order that would likely work (unproven; it changes the card's deploy scope, so it needs the
brain's go):**

1. Validate with RunLocalTests and quick-deploy everything except `aiAuthoringBundles` and
   `permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml`. `--source-dir` accepts single
   files, so pass the other folders plus the Data Access file alone.
2. Assign `Account_Brief_Data_Access` to the running user.
3. Seed: `SF_TARGET_ORG=<alias> bash scripts/seed-sample-data.sh`, then count each object read-only.
4. `bash scripts/agent-check.sh`, then publish once:
   `sf agent publish authoring-bundle --api-name Account_Brief -o <alias> --skip-retrieve --json`.
   Then `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`.
5. Query `BotVersion`, then `sf agent activate --api-name Account_Brief --version <N> -o <alias> --json`.
6. Validate with RunLocalTests and quick-deploy `Account_Brief_Agent_Access`, then assign it.
   From here `scripts/validate-org.sh` can pass in that org.
7. The 12-case spec (`sf agent test create`, `run`, `results`), the two-turn
   `generateAiAgentResponse` check (`docs/research/agent-api.md`) and `npm run test:e2e`.

An alternative that keeps one deploy, also unproven: move the agent access grant out of
`force-app`'s routine deploy (for example into its own package directory deployed after publish).
That is a source change and belongs to its own card.

## Gate results at this commit

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`: 72 tests, OK.
- `bash scripts/agent-check.sh`: pass. Local compile clean (0 warnings), and
  `sf agent validate authoring-bundle` passed on agent-probe even though none of the Apex its
  actions call is in the org yet (verified).
- `bash scripts/validate-org.sh`: fail, with the same component error as step 8.

## Cleanup

Nothing to clean up in the org. The only lasting local change is the project's default org
setting in `.sf/config.json` (git-ignored).
