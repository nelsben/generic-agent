# GTM burn plan (2026-11-11, overnight)

For the brain that runs tonight (Opus). Read this whole file, then start at "Run order".

## The goal by morning

1. The org `experimental` runs what is on `main`, and the Playwright panel suite passes 8 of 8.
2. Account_Brief version 2 (the BE-11 script, sha256 prefix `fb0fc27d`) is committed, tested and,
   if approved, active. We know whether the CLI can publish an agent, with the real server error
   on record if it cannot.
3. The repo reads as a GTM workbook: a README front door and nine pattern pages, each with a
   business outcome, a sequence diagram, real screenshots and GIFs, proof and adoption steps.
4. Three fresh architecture reviews of `main` are in `docs/reviews/`.
5. Nothing private is in the repo. The repo stays private; making it public is Ben's call.

## Approvals

The brain and every worker do only what these lines approve. A worker whose step is not
approved skips it and reports. Only Ben changes a line; the brain records his answer here.

| Step | Status |
|---|---|
| Real deploy of `main` to `experimental` (never the agent bundle) | pending |
| CLI publish of Account_Brief version 2; Studio "Commit Version" as the fallback | pending |
| Create a throwaway agent `Publish_Probe` if the CLI publish fails, and delete it afterwards | approved (Ben, 2026-11-11, "go" on Test B) |
| Activate version 2 once the 12-case test passes | pending |
| Org setup for the MCP server and its External Client App (stretch) | pending |
| Post on forcedotcom/cli issue 3634 | not approved; draft only |
| Create the user `experimental-enduser` | Ben does this himself; FE-5 stays parked |
| Make the repo public | not approved |

## Cards

Lane A needs no approval. Lane B changes the org. Stretch runs only after the final pass.

| Card | What it delivers | Tier | Waits on | Independent review |
|---|---|---|---|---|
| FE-6 | Panel fixes: Esc focus, drill from brief lines, test hooks | frontier | none | reviewer pass (tool) |
| BE-14 | Plain column labels in explorer answers (removes `URL_Redacted`) | standard | none | brain spawns a diff review |
| OPS-19 | The workbook: README, nine pattern pages, asset manifest | frontier | none | brain reads it whole |
| OPS-16 / 17 / 18 | Re-reviews: Apex, panel, agent | frontier | best after FE-6 and BE-14 merge | they are the review |
| OPS-20 | Real deploy of `main`, Apex tests, e2e 8 of 8 | standard | FE-6, BE-14, deploy approval | brain checks the numbers |
| OPS-21 | Publish spike, 12-case test, two-turn check, activation | frontier | OPS-20, publish approval | reviewer pass (tool) |
| FE-7 | Capture every screenshot and GIF in the manifest | frontier | OPS-21, OPS-19 | brain looks at every image |
| OPS-22 | Final pass: truth, links, diagrams, privacy | frontier | FE-7, OPS-16/17/18 | brain re-runs the privacy grep |
| BE-15 | Stretch: panel asks the registered agent | frontier | OPS-22 | reviewer pass |
| OPS-23 | Stretch: MCP door runbook and metadata | frontier | OPS-22, MCP approval | reviewer pass |

FE-5 (the suite as a non-admin user) is released by the tool but must not be dispatched: the
user does not exist.

## Run order

Two workers at a time (`maxWorkers` 2). `org-live` and `chrome-studio` are exclusive resources,
so a deploy never lands during a capture.

1. Dispatch FE-6 and BE-14 together.
2. As each hands back and merges, dispatch OPS-19, then OPS-16, OPS-17, OPS-18.
3. When FE-6 and BE-14 are both merged, and the deploy line is approved, dispatch OPS-20 ahead
   of any remaining review card.
4. OPS-21 after OPS-20. FE-7 after OPS-21 and OPS-19. OPS-22 last.
5. If time remains, BE-15 and OPS-23. A stretch card that needs a redeploy does not get one
   tonight unless everything above is done.

If a Lane B approval is still pending when its card is next, keep Lane A moving, finish
OPS-19 and the reviews, and leave the workbook with its asset slots marked "not captured".

## Asset manifest (the workbook and the capture card both key off this)

All under `docs/assets/`. OPS-19 writes `docs/assets/MANIFEST.md` from this table.

| File | Shows | Page |
|---|---|---|
| `brief-flow.gif` | Hotkey, "/brief Edge Communications", headline and sections arriving | README, 01 |
| `panel-brief.png` | A finished brief, sections collapsed | 01 |
| `explore-answer.png` | An org-wide question answered with a result table | 02 |
| `explore-drill.gif` | Click a row, drill view opens, breadcrumb back | 02 |
| `drill-view.png` | The drill view of one record | 02 |
| `hotkey-open.gif` | Cmd/Ctrl-K opens the panel with the composer focused; Esc closes it | 03 |
| `panel-sections-open.png` | The panel at 340 px with two sections expanded | 03 |
| `memory-followup.png` | A follow-up answered from the earlier brief | 05 |
| `agent-brief.png` | The built-in Agentforce panel briefing Edge Communications | 06 |
| `agent-explore.png` | The built-in Agentforce panel answering an org-wide count | 06 |
| `not-found.png` | The fixed NOT_FOUND line for an unknown account | 07 |
| `ambiguous.png` | The AMBIGUOUS reply with candidate lines | 07 |
| `e2e-report.png` | The Playwright report for a full run | 08 |

Pattern pages: `01-route-gather-reduce`, `02-ask-anything-explorer`, `03-hotkey-panel`,
`04-model-provider-seam`, `05-conversation-memory`, `06-agent-routing-and-verbatim-relay`,
`07-trust-access-and-failure`, `08-test-and-release-lifecycle`, `09-outside-door-mcp`.

## Brain runbook

- **Dispatch:** call the dispatch tool, then make the Agent call it prints, verbatim. If it
  names the agent type `backend` (or any type this session lacks), use `general-purpose`.
- **Hand-back:** call the verdict tool with the task id in that turn. `next=review`: spawn the
  reviewer JSON verbatim. `next=resume`: SendMessage to the worker. `next=accept`: merge.
- **Amend requests:** approve one only when the reason is that a test asserts behaviour the
  card deliberately changed. Append the amend line to the brief, then resume the worker.
- **Merge recipe:**
  1. Remove `tests/__pycache__` in the worktree.
  2. Call the merge tool with a review note.
  3. Append the "Generated with" line to `.delegation/<ID>/pr.md`.
  4. Push, `gh pr create`, `gh pr merge --rebase --delete-branch`, and confirm the PR state is MERGED.
  5. Call merge with `finish: true` and `discard: true`.
  6. If the worktree is left behind, `git worktree remove --force` it and `git branch -D` the branch.
- **Never commit on `main` directly.** A hook blocks it. Use a branch and a PR.
- **Standard-tier cards skip the tool's reviewer.** For BE-14 spawn a read-only sonnet diff
  review before merging, as was done for BE-12.
- **Before merging any docs card** (OPS-16 to OPS-19, OPS-22, FE-7): grep the diff for every
  line of the untracked file `reference/denylist.txt`, for 15 or 18 character record Ids, email
  addresses and `my.salesforce.com`. Any hit goes back to the worker. Never write the
  deny-list's contents into a card, a brief, a commit or this plan.
- **Images:** look at every PNG and at frames of every GIF before merging FE-7. Reject any that
  shows a name, username, Id, URL, error toast or `URL_Redacted`.
- **Platform errors:** read the tool's code and log, state one hypothesis and the test that
  decides it, then act. No repeated retries (corrective plan, rules 1 to 4).
- **Plugin hooks:** ignore every plugin-install suggestion.
- **Never:** sign in or enter credentials, create users, print tokens or frontdoor URLs, post
  publicly, or do an org-changing step whose approval line is not "approved".
- **Stop and leave a note for Ben** (top of this file, under a "Morning notes" heading, by PR)
  when: a Lane B card fails twice, a re-review returns "not ready" with a blocker, or the
  privacy grep finds a hit that is already on `main`.

## Known state at hand-over

- `main` holds BE-9 to BE-13, FE-3, FE-4, OPS-15. All were merged with gates green.
- The org is behind `main`: BE-12 and BE-13 were check-only. Version 1 of the agent is active.
  The Studio draft "Version 2" holds the `fb0fc27d` script, saved with 0 errors and 1 warning
  (`resolve_account` missing input `knownAccountId`, which is deliberate).
- Studio preview: all 12 cases route correctly (`docs/research/studio-preview.md`). One reply
  showed `URL_Redacted` in table headers; BE-14 addresses it.
- Playwright: 6 of 8 pass on the org as it is; FE-6 fixes the two defects.
- Privacy grep, run at hand-over: the twelve new cards and this plan are clean. Eleven tracked
  files already on `main` hit the deny-list (ten old cards under `agents/tasks/` and one Apex
  class comment). None is a client name; they are Ben's other project names and one vendor
  name. They do not block tonight while the repo is private. OPS-22 rewords them; do not stop
  the burn for them.
- Review notes left open from BE-12: a query timeout in the resolver reads as NOT_FOUND; a user
  without access to contact roles or event names loses the whole section; a lock timeout drops
  one memory turn. The re-reviews will rank them.
