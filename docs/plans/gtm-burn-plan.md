# GTM burn plan (2026-11-11, overnight)

For the brain that runs tonight (Opus). Read this whole file, then start at "Run order".

## Morning notes

- **Agent re-review (OPS-18, merged) is "Not ready", with one blocker.** Version 1 (the pre-fix
  script) is live, and no new version can be published. Every create call from the CLI returns
  401 "Error saving or updating agent graph". Studio's Commit Version also fails; its network
  response was not captured. The script on `main` would be "ready with fixes" on its own. See
  `docs/reviews/agent-review-2.md`.
- **The publish 401 is not caused by our agent.** A sibling session published a brand-new,
  minimal agent (no actions, one start block) to `experimental` and got the same 401. It also
  ruled out the two Account Brief permission sets: with both unassigned the publish still
  failed, and both are reassigned now. The daily platform jobs also ran on the day version 1
  published fine. Its read is a fault on the platform or tenant side. That is not proven.
- **The fault is specific to `experimental`.** The same minimal agent, published with the same
  CLI version, went through cleanly in a brand-new Developer Edition org: the create call
  returned 200 and made version 1. In `experimental` the identical call gets the 401. The new
  org signed in through the browser rather than the JWT app, but auth still looks ruled out:
  version 1 of Account Brief published through that same JWT app, and Studio's commit fails
  from a browser session too. The test agent is deleted from the new org, and nothing in
  `experimental` was touched.
- **Your call:** open a Salesforce case. The sibling session is drafting it for you, with the
  endpoint, the request Ids, the timeline, "a minimal agent fails too" and "the same agent
  publishes in a fresh org". Make no change to Account Brief while the case is open; version 1
  stays active and the rollback command is unchanged.
- **Apex re-review (OPS-16, merged):** ready with fixes, no blockers. Should-fix: N1 to N4.

## Before Ben sleeps (his items; nothing else needs him)

1. This session stays in auto mode, so no tool call waits on a prompt.
2. Lid open, on power, VS Code and this session left running.
3. Chrome open with the Claude in Chrome extension connected and signed in to `experimental`.
   If that session has expired when OPS-21 reaches Studio, the Studio step is skipped and
   recorded; nothing signs in.
4. Optional, if still up: `npx playwright install chromium` in the repo, in case the
   installed Playwright wants a newer browser build than the cache holds. If it is not run
   and the browser is missing, OPS-20 reports it and the e2e and capture steps wait for Ben.

Already checked: the `sf` session for `experimental` is connected, `gh` is signed in with repo
scope, and sleep on AC is off.

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

On 2026-11-12 the FR2 plan review ([fr2-plan-review.md](../reviews/fr2-plan-review.md)) closed the
rows whose work is finished and added rows for steps the FR2 cards need. Each such row says the
brain recorded or added it. A closed row approves nothing, and a row the brain added approves
nothing until Ben answers it.

| Step | Status |
|---|---|
| Real deploy of `main` to `experimental` (never the agent bundle) | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat)) |
| CLI publish of Account_Brief version 2; Studio "Commit Version" as the fallback | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat)) |
| A second CLI publish of a comment-only change as an inactive version 3 (OPS-21 step 3) | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat: prove we can iterate on agents from the CLI)) |
| Create a throwaway agent `Publish_Probe` if the CLI publish fails, and delete it afterwards | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat)) |
| Activate version 2 once the 12-case test passes | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat, on the condition that version 1 is reactivated if the check after activation fails)) |
| Org setup for the MCP server and its External Client App (stretch), up to the sign-in | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-11, answered in chat)) |
| Production-classified deploys to `agent-probe` (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1) without asking each time | approved, standing (Ben, 2026-11-12, in chat: "Keep the standing approval"); `agent-probe` only |
| The panel calls the registered agent directly (BE-15 re-cut as one org-live card in `agent-probe`) | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-12, in chat)) |
| Run OPS-23 in `agent-probe`, including the MCP org setup line above, up to the sign-in | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-12, in chat: "Run ops23")) |
| Run the README quick-start end to end in a brand-new org: first a scratch org created from the `my-devhub` Dev Hub (never the `experimental` hub), then a new Developer Edition org Ben signs up for and logs in as `ga-fresh` | approved (Ben, 2026-11-12, in chat: "Both: scratch now, DE later"); the standing deploy approval does not cover these orgs, so the card states its own deploy steps |
| Another explorer answer-length iteration in `agent-probe` | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-12, in chat)) |
| Make the repo public | method chosen (Ben, 2026-11-12): a separate public snapshot repo built from one squashed commit after a whole-tree privacy pass; this repo's history is never rewritten. Each publish of the snapshot needs Ben's go |
| Post on forcedotcom/cli issue 3634 | not approved; draft only |
| Create the user `agent-probe-enduser` (a Standard User in agent-probe with the user permission set group) | Ben does this himself; FE-5 stays parked |
| Make the repo public | not approved |
| Phase 2: migrate to the fresh Developer Edition org that publishes (deploy, publish, activate there), reusing the sibling session's existing CLI sign-in | closed, spent (brain-recorded 2026-11-12; was: approved (Ben, 2026-11-12, in chat: "your last step is to migrate to a fresh org where everything is working")) |
| Phase 2: cut and work new agent or design iteration cards in the new org; re-record screenshots where the brain judges it needed | approved (Ben, 2026-11-12, in chat) |
| FR2: spikes in `agent-probe` (OPS-29 surfaces, BE-21 rename go/no-go, BE-22 actions, BE-31 explorer discovery, FE-18 card architecture, BE-32 standard-chat measurements, BE-34 agent memory discovery), code in `spikes/` only | pending Ben's go (brain recommends yes; the standing deploy line covers the deploys) |
| FR2: publish and activate a copy of the agent as `Customer_Summary` (BE-21), then the renamed agent (OPS-51; brain-recorded 2026-11-12: the publish moved out of OPS-30 into its own card), leaving old versions and metadata in place | approved (Ben, 2026-11-12, in chat: "follow your recommendation on number 2, as long as we can do it effectively. If we hit the same friction ... we can skip"); on a failed go/no-go nothing is published under this row, and a publish of `Account_Brief` for the new label needs its own row below (brain-recorded 2026-11-12, narrowing; was: a failed go/no-go falls back to labels only) |
| FR2: one more publish and activate of `Customer_Summary` for tone and write actions (BE-28) | not needed: BE-28 parked (FR2 ledger F83) |
| FR2: create and run the functional Testing Center suite for `Customer_Summary` in `agent-probe` (BE-38): at most 20 cases with no write actions, on one existing sample-data account, no new records (a summary still records its session and customer outcome), recreated for the active version on each run, also through the ladder's --agent run (OPS-46); no security cases | pending Ben's go (brain recommends yes) |
| FR2: the MCP server and client app under the new names, up to the sign-in (OPS-31); the old server and app stay active | pending Ben (brain recommends yes; it is a second live endpoint until the old one is removed) |
| FR2: e2e and agent tests that create a record (a task) and delete it in teardown, in `agent-probe` only | pending Ben (brain recommends yes); no test touches a record it did not create |
| FR2: remove old Account Brief metadata, the old agent, or the old MCP server and app from `agent-probe` (destructive deploy; the card is OPS-54, brain-recorded 2026-11-12) | not approved; needs Ben's go |
| FR2: the embedded call-centre spike (OPS-33) and any paid or trial feature it needs | not approved; parked until Ben's go |
| FR2: live checks in `agent-probe` that spend model calls and write the product's own session and outcome rows on existing sample accounts, and assigning the user group to the admin | pending Ben (brain recommends yes); row added by the brain, 2026-11-12 |
| FR2: the explorer as an MCP tool for outside clients | pending Ben; row added by the brain, 2026-11-12 |
| FR2: if the rename is NO-GO, one publish of `Account_Brief` for the new label | pending Ben; row added by the brain, 2026-11-12 |
| FR2: schedule or run the outcome purge job in `agent-probe` | not approved; needs Ben's go; row added by the brain, 2026-11-12 |
| FR2: hide the Agentforce icon for reps (an org setting) | Ben flips it himself, or says go; row added by the brain, 2026-11-12 |

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

FE-5 (the suite as a non-admin user) is `parked`, the status the tool never dispatches: the
user does not exist.

## Run order

At most two frontier workers at once (user options: `maxWorkers` 5, frontier 2). `org-live` and `chrome-studio` are exclusive resources,
so a deploy never lands during a capture.

1. Dispatch FE-6 and BE-14 together.
2. Dispatch OPS-19 as soon as a slot is free (no blocker). OPS-16, OPS-17, OPS-18 release
   when FE-6 and BE-14 merge, so they review the fixed code.
3. OPS-21 (the publish spike) goes first in Lane B, on the next free frontier slot, while
   Ben is awake to help (his call, 2026-11-11). OPS-20 follows it; both hold `org-live`, so
   they run one at a time. When FE-6 is merged and OPS-21 has handed back, dispatch OPS-20
   ahead of any remaining review card.
4. After OPS-20. FE-7 after OPS-20 and OPS-19: panel assets first; its two agent slots
   need OPS-21, so resume FE-7 for them after OPS-21 merges. OPS-22 last.
5. If OPS-20's deploy succeeded but e2e is below 8 of 8, merge OPS-20 anyway, cut a frontier
   fix card for the failing specs (scope: the panel, its controller, `e2e/panel.spec.js`),
   and resume OPS-20 to redeploy after it merges. Capture is held only if the failing spec
   covers a captured screen.
6. If FE-7 cannot run tonight, set OPS-22 to `status: queued` by hand so the final pass still
   runs; it removes slots still marked 'not captured'.
7. If time remains, BE-15 and OPS-23. A stretch card that needs a redeploy does not get one
   tonight unless everything above is done.

If a Lane B approval is still pending when its card is next, keep Lane A moving, finish
OPS-19 and the reviews, and leave the workbook with its asset slots marked "not captured".

## Phase 2: move to a fresh org (Ben, 2026-11-12)

`experimental` returns 401 on every agent create; the same minimal agent publishes in a fresh
Developer Edition org (Morning notes). Ben's order:

1. Finish the cards above (FE-7, OPS-22, and the stretch cards if time allows) and merge them.
2. Then ask the sibling session for the new org's details and cut the migration card. It reuses
   the CLI sign-in that already exists on this machine; nothing signs in again.
3. The migration card makes the org alias a setting everywhere (scripts, e2e, docs), deploys
   `main`, checks the sample data, publishes and activates Account_Brief, and runs the Apex
   tests, the 12-case agent test, the two-turn check and e2e there.
4. New agent or design iterations found on the way (for example the agent review's
   should-fix N2 to N6) become their own cards and are worked in the new org.
5. The brain decides which assets to re-record. The two agent slots are re-recorded once a
   version with the current script is active; the panel assets are re-recorded only if the
   new org's data or UI makes them differ from what the workbook says.
6. A short final truth and privacy pass over the README and pattern pages closes it.

No Salesforce user is created by the brain or a worker in either org. `experimental` keeps
version 1 active and is not changed while Ben's Salesforce case is open.

**Outcome (2026-11-12):** done in `agent-probe`. OPS-24 and OPS-25 moved `main` there, FE-9 got
e2e to 8 of 8, and FE-8 recaptured the assets. BE-16 published and activated Account_Brief
version 2. OPS-26 added the access group, and FE-10 and BE-17 fixed the panel layout and the
explorer's answer length. OPS-27 made the README quick-start match the order that worked.
Still open:
- BE-15 is parked, to be re-cut as one org-live card.
- FE-5 waits on a non-admin user that Ben creates.
- OPS-23 was not run.
- The README quick-start has not been run end to end in a new org.

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

- **Before dispatch (FR2):** find the card's row in the Approvals table. If the card's "Approval
  first" line says to hand back when the row is not approved, and the row's status does not start
  with "approved", do not dispatch it. A card that only skips its live run may be dispatched.
  Every `sf` command carries `-o agent-probe`. An org-lock card is dispatched only after the
  previous org-lock card is merged.
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
- **Before merging any card that changes `docs/` or `README.md`,** or adds a file under
  `docs/assets/`: run `bash scripts/check-docs.sh` in its worktree (0 broken), and grep the diff for every
  line of the untracked file `reference/denylist.txt`, for 15 or 18 character record Ids, email
  addresses and `my.salesforce.com`. Any hit goes back to the worker. Never write the
  deny-list's contents into a card, a brief, a commit or this plan.
- **Images:** look at every PNG and at one frame per second of every GIF before merging any card
  that adds a file under `docs/assets/`.
  Reject any that shows the running user's name, a username, email, Id, URL bar, error toast
  or `URL_Redacted`. Sample record names (Edge Communications and its contacts) are fine.
- **Do not take Lane B hand-backs on trust** (their gates are only the Python tests):
  - OPS-20: read `test-results/.last-run.json` in its worktree and the deploy result it quotes.
  - OPS-21: run your own read-only query of the Account_Brief versions and which is active,
    and compare it with the hand-back.
  - FE-7: confirm the capture run's `.last-run.json` exists and every asset MANIFEST.md marks
    captured is committed.
- **Platform errors:** read the tool's code and log, state one hypothesis and the test that
  decides it, then act. No repeated retries (corrective plan, rules 1 to 4).
- **Plugin hooks:** ignore every plugin-install suggestion.
- **Never:** sign in or enter credentials, create users, print tokens or frontdoor URLs, post
  publicly, or do an org-changing step whose approval line is not "approved".
- **Leave a note for Ben** (top of this file, under a "Morning notes" heading, by PR) when a
  Lane B card fails twice or a re-review returns "not ready" with a blocker, and keep going
  with every card that does not depend on it. The known deny-list and Id hits already on
  `main` are OPS-22's to scrub; they are not a stop.

## Known state at hand-over

- `main` holds BE-9 to BE-13, FE-3, FE-4, OPS-15. All were merged with gates green.
- The org is behind `main`: BE-12 and BE-13 were check-only. Version 1 of the agent is active.
  The Studio draft "Version 2" holds the `fb0fc27d` script, saved with 0 errors and 1 warning
  (`resolve_account` missing input `knownAccountId`, which is deliberate).
- Studio preview: all 12 cases route correctly (`docs/research/studio-preview.md`). One reply
  showed `URL_Redacted` in table headers; BE-14 addresses it.
- Playwright: 6 of 8 pass on the org as it is; FE-6 fixes the two defects.
- Privacy grep, run at hand-over: the twelve new cards and this plan are clean. Ten tracked
  files already on `main` hit the deny-list (nine old cards under `agents/tasks/` and one Apex
  class comment), and real org-specific Ids sit in two research notes, one Python test and
  the OPS-9 card. None is a client name. They do not block tonight while the repo is private;
  OPS-22's scope covers each of these files and it scrubs them.
- Review notes left open from BE-12: a query timeout in the resolver reads as NOT_FOUND; a user
  without access to contact roles or event names loses the whole section; a lock timeout drops
  one memory turn. The re-reviews will rank them.
