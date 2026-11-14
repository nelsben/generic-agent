# The README quick-start in a new scratch org (OPS-28)

- Date: 2026-11-14, 22:19 UTC. Dev Hub `my-devhub`, named on every command that touches a hub. Planned
  scratch org alias `ga-scratch`.
- CLI: `@salesforce/cli` 2.158.7.
- Approval: "Run the README quick-start end to end in a brand-new org: first a scratch org created from the
  `my-devhub` Dev Hub" in [gtm-burn-plan.md](../plans/gtm-burn-plan.md), Approvals ("Both: scratch now, DE
  later").
- Status words: verified (seen in a command result), unproven (not run).
- No record Ids, org Ids, job Ids, usernames, hostnames or URLs are written here.

## Plain answer

**Blocked before the first README step: no scratch org was created.** The Dev Hub refused the create with
`STORAGE_LIMIT_EXCEEDED` because its own data storage is full (verified). No README step ran, nothing was
deployed anywhere, and the README's Status rows "A clean install from 'See it in 5 minutes'" and "Runs without
the agent" are unchanged. The run needs data storage freed in `my-devhub`, or another approved Dev Hub; both are
outside this card's rules (it may only read the hub).

## What was done, in order

| # | Step | Command (abridged) | Outcome |
|---|---|---|---|
| 1 | Install | `npm ci` | ok |
| 2 | Scratch capacity | `sf org list limits -o my-devhub --json` | `ActiveScratchOrgs` 3 of 3 remaining, `DailyScratchOrgs` 6 of 6 remaining (verified) |
| 3 | Alias free | `sf org list --skip-connection-status --json` | no org under `ga-scratch` (verified) |
| 4 | Definition | wrote [config/project-scratch-def.json](../../config/project-scratch-def.json): edition Developer, features `EnableSetPasswordInApi` and `Einstein1AIPlatform`, settings `lightningExperienceSettings.enableS1DesktopEnabled`, `agentPlatformSettings.enableAgentPlatform` and `einsteinGptSettings.enableEinsteinGptPlatform`, each true | valid JSON |
| 5 | Create | `sf org create scratch --definition-file config/project-scratch-def.json --target-dev-hub my-devhub --alias ga-scratch --duration-days 7 --wait 9 --json` | **Failed** after about 1 s: `STORAGE_LIMIT_EXCEEDED`, "storage limit exceeded", exit 1 (verified). No org under `ga-scratch` afterwards (verified) |
| 6 | Why | the same limits read as row 2 | `DataStorageMB`: max 5, remaining 0 (verified). `FileStorageMB` 20 of 20 remaining |
| 7 | What fills it | `GET /limits/recordCount` and `SELECT COUNT() FROM ScratchOrgInfo`, both read-only on `my-devhub` | The largest counted data object is the custom `Detected_Signal__c` (917 rows); `ScratchOrgInfo` holds 14 rows. The other large counts are setup and log objects (permission rows, the audit trail, login history). Which rows to delete is the hub owner's decision (unproven which rows count most toward the 5 MB) |

The create failed when the hub tried to write the new org's `ScratchOrgInfo` row, which counts against the hub's
data storage (inference from the error and row 6).

## Deviations

None in the README: the run stopped before its first step. The blocker is the Dev Hub's storage, not a step as
written.

## What it needs to go on

One of these, each an owner's decision:

- Free data storage in `my-devhub` (for example old `ScratchOrgInfo` rows of expired orgs, or rows of
  `Detected_Signal__c` the hub no longer needs), then rerun from row 5.
- Approve another Dev Hub for this run. The `experimental` hubs stay excluded.
- Go straight to the later Developer Edition run (`ga-fresh` in the Approvals row), which needs no Dev Hub.

Not run, so still unproven: every step of "See it in 5 minutes", the e2e suite in a new org, the run without the
agent, the optional agent track (publish, activation, the agent's permission set and one preview turn), and
whether `CopilotSalesforceUser` exists in a new org. The Testing Center suite would have been skipped in any case:
`scripts/agent-test.sh` does not exist.
