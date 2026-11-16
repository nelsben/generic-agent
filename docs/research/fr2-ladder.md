# FR2: the test ladder in one command (OPS-46)

Run on 2026-11-14 against `agent-probe`, from a worktree cut at `db19e81` (main). Hostnames, usernames
and Ids are not in this page. The org rungs are read-only: a check-only validate and a retrieve of
`force-app` types to a temporary folder outside the repo, deleted afterwards.

## Approvals

- "FR2: live checks in `agent-probe`" is approved (Ben, 2026-11-12). The ladder's rungs reach no model:
  the smoke subset makes no model call, and the agent suite was not run. The run wrote no session rows and
  no outcome rows (0 and 0) and used no sample-data account.
- "FR2: create and run the functional Testing Center suite" (BE-38) is pending Ben's go and
  `scripts/agent-test.sh` does not exist, so the Testing Center rung printed its skip line.

## How to run it

```bash
npm run ladder                      # python, jest, scan, org-check, drift, e2e-smoke
npm run ladder -- --agent           # adds agent-compile, then agent-suite when it is built and approved
npm run ladder -- --full            # the full e2e suite in place of the smoke subset
npm run ladder -- --continue        # carry on after a failed rung (the default stops at the first)
```

One line per rung. A failed rung also prints the last lines of its output. The exit status is 1 when a
rung failed.

## What each rung runs

| Rung | Command | Reads or writes the org |
|---|---|---|
| python | `python3 -m unittest discover -s tests` | no |
| jest | `npm run test:unit` | no |
| scan | `scripts/apex-scan.sh` (Code Analyzer; reports, never gates) | no |
| org-check | `scripts/validate-org.sh` (check-only validate, our own Apex tests) | validates, saves nothing |
| drift | `scripts/org-drift.sh` | read-only retrieve |
| e2e-smoke | `npm run test:e2e:smoke` | reads, as the signed-in user |
| agent-compile | `scripts/agent-check.sh` (local compile, `sf agent validate authoring-bundle`) | read-only |
| agent-suite | `scripts/agent-test.sh` | not built |

## The code scan without Java

This machine has no Java. `apex-scan.sh` now runs the engines that need none (eslint, regex, retire-js,
flow) on all of `force-app`, and prints that it skipped the pmd, cpd and sfge engines (the Apex rules)
and that installing Java 11 or later turns them on. With Java 11 or later it runs every Recommended rule on
the Apex classes, as before. It reports and does not gate.

## The drift check

`org-drift.sh` builds a manifest from main's `force-app`, cuts it to an allow-list of types, retrieves it
from the org into a temporary project, and compares file by file. It prints counts by type and names, and
exits 0 (in sync), 2 (differs) or 1 (could not run). What it leaves out, on purpose:

- Any type that can carry a consumer key or a secret (client apps, connected apps, MCP servers,
  credentials): they are not on the allow-list, so they are never asked for.
- The agent bundle, which has its own check (`agent-check.sh`).
- Components that exist only in the org: the manifest comes from main, so it says "main's components, as the
  org has them", not "everything in the org".
- Defaults the org fills in or drops when it returns XML (for example `trackTrending`, `externalId` false,
  an auto-number starting at 1), the order of elements, a static resource's file extension, and the Jest
  tests under `__tests__`.

## Run 1: `npm run ladder -- --continue`

```
ladder: python         passed (1s): Ran 241 tests in 1.208s
ladder: jest           passed (4s): Tests: 265 passed, 265 total
ladder: scan           passed (4s): reported 254 violation(s); skipped the pmd, cpd and sfge engines (the Apex rules): they need Java. Installing Java 11 or later turns them on.
ladder: org-check      passed (242s): pass (147 components, 425 tests)
ladder: drift          failed (exit 2, 15s): differs
ladder:                  | org-drift: differs
ladder:                  | changed in the org: 2
ladder:                  |   FlexiPage: 1
ladder:                  |     Customer_Summary_UtilityBar
ladder:                  |   LightningComponentBundle: 1
ladder:                  |     customerSummaryPanel
ladder: e2e-smoke      failed (exit 1, 70s): 2 failed 5 passed (1.2m)
ladder:                  |   2 failed
ladder:                  |     [mac] › e2e/panel.spec.js:98:1 › 1. @smoke @hotkey Cmd/Ctrl-K before the window was ever opened opens it in the bottom right corner and focuses the composer
ladder:                  |     [windows] › e2e/panel.spec.js:98:1 › 1. @smoke @hotkey Cmd/Ctrl-K before the window was ever opened opens it in the bottom right corner and focuses the composer
ladder:                  |   5 passed (1.2m)
ladder: FAILED
```

## Run 2: `npm run ladder -- --agent --continue`

The first four rungs gave the same lines (the org-check took 637 s this time: another validate was
queued in the org). The rest:

```
ladder: drift          failed (exit 2, 8s): differs; changed in the org: 2
ladder: e2e-smoke      failed (exit 1, 69s): 2 failed 5 passed (1.1m)
ladder: agent-compile  passed (2s): pass
ladder: agent-suite    skipped: agent suite not built
ladder: FAILED
```

## Reading these two runs

The drift line and the smoke failure of spec 1 are expected, and they come from one cause outside this
card: `agent-probe` already carries FE-15's unmerged rail work (the panel bundle and the utility bar page
with the expand button), and the worktree is cut from main, which does not have it yet. They are not
ladder defects, and they go away when FE-15 merges and the org and main agree. The other rungs passed.

## Undo

Not recorded on this page. The work deployed to `agent-probe` or ran there, but the page lists nothing to remove.
