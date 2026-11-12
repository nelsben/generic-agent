# Corrective plan (logged 2026-11-11)

For whoever orchestrates next. Read this, then the four research write-ups it points to.

## Status (2026-11-11, end of the overnight run)

Finished tonight:
- FE-6 (Esc keeps focus, brief lines carry a drillable Id), BE-13 and BE-14 (explorer date
  handling and plain column labels) are merged.
- OPS-20: `main` deployed for real to `experimental`: 60 components, 150 of 150 Apex tests, and the
  Playwright panel suite 8 of 8 on the first run as an admin user (`docs/research/deploy-verify.md`).
  The org matches `main` outside the agent bundle.
- OPS-21: the publish spike. Every agent create from the CLI in `experimental` returns
  `401 "Error saving or updating agent graph"`; the CLI's `404` is its HTTP library resending.
  The CLI publish, a new throwaway agent and Studio's Commit Version all failed. No version 2
  exists and version 1 is still active (`docs/research/agent-publish-spike.md`). The morning notes
  in `gtm-burn-plan.md` add that a minimal agent publishes in a fresh Developer Edition org.
- OPS-16, OPS-17 and OPS-18: the re-reviews. Apex: ready with fixes, no blockers. Panel: ready
  with fixes, no blockers. Agent: not ready, one blocker (version 1 live, nothing publishable).
- FE-7: 11 of the 13 planned screenshots and GIFs captured. The two built-in panel shots were
  dropped, because no version with the current script is active.
- OPS-19 and OPS-22: the README and nine pattern pages, then a final truth, asset, link,
  diagram and privacy pass over them.

Still open:
- Publishing in `experimental` (Ben's Salesforce case). Phase 2 moves to a fresh org, where the
  agent is to be published, activated and tested.
- The 12-case agent test run and the two-turn check: not run, because they need the fixed
  version active. The org's test definition pins version 1 (agent-review-2 N2).
- A run as a non-admin user (FE-5), a real MCP tool call, the panel calling the registered agent,
  and a clean install from the README's five-minute steps.
- The should-fix findings: apex-review-2 N1 to N4, lwc-review-2 N1 to N5, agent-review-2 N2 to N6,
  plus earlier agent findings 6 and 12 and panel items 6 and 14f.
- Real record Ids remain in `tests/agent/Account_Brief-testSpec.yaml` and the matching assertions
  in `tests/test_agent_bundle.py`, and one in `docs/research/salesforce-mcp.md`. Those files were
  outside the final pass's reach.

## Where things stand

- `main` holds: the Apex engine, the Account_Brief agent (version 1, active in `experimental`),
  the custom panel, two permission sets, the Account Brief app with the panel in its utility bar
  (deployed), and research in `docs/research/` (salesforce-mcp, agent-api, agent-publish-failure,
  salesforce-skills).
- BE-8 and BE-9 (agent routing, verbatim relay, review fixes, `scripts/agent-check.sh`) are
  merged (PR #27). The script is not yet publishable; BE-11 fixes the Studio preview defects.
- Proven live: the panel can call the registered agent from Apex (`generateAiAgentResponse`,
  two turns, 14-18 s each, reply is `{"type":"Text","value":...}`); a Developer Edition org can
  create a custom MCP server; our public Apex actions and the Employee-type agent are both
  offered as MCP tools.

## What went wrong, and the rules that follow

1. We built the agent from memory and skipped Salesforce's documented lifecycle (compile, validate,
   live preview of every routing branch, then publish). Rule: follow the lifecycle in
   `docs/research/salesforce-skills.md` for every agent change; preview before publish.
2. When publish failed we retried and changed variables blindly (CLI update, deactivate). Rule:
   on a platform error, read the tool's code and log first (`~/.sf/sf-<date>.log`), state a
   hypothesis and the one test that decides it, then act. No repeated retries.
3. Workers were told how the platform works by the brain's memory. Rule: briefs for Salesforce
   work name the relevant sf-skills files to read (listed in the skills write-up, section
   Recommendation (b)), and verify flag spellings with `--help`.
4. Outages and installs are the owner's call. Rule: deactivating the agent, installing plugins,
   updating tools, creating extra agents and posting publicly all need Ben's go first.

## Ordered work

### 1. Unblock the publish (blocks BE-9 and everything agent-facing)
Do not retry the CLI publish; it cannot succeed (see agent-publish-failure.md).
a. Browser test (needs the Chrome extension connected and Ben logged into `experimental`):
   open Agentforce Studio for Account_Brief, paste BE-9's script into the draft (use the branch
   list BE-9 hands back), validate, run a live preview of each routing branch, commit a new
   version. Do not activate until the
   preview is clean. Record the exact error text if it fails.
b. If Studio fails too, ask Ben before each of these, in this order: delete the
   `Account_Brief_Test` evaluation definition (it pins version 1) and retry; first-publish a
   copy under another name to see whether publishing works at all (leaves an extra agent to
   remove); comment on forcedotcom/cli issue 3634. No support case is possible on Developer Edition.
c. Also check the skills' "Internal Error on publish" causes: the agent's access user, a missing
   `outputs:` block, structural drift.
d. Once a version is live: activate, run the 8-case agent test and the two-turn follow-up check
   through `generateAiAgentResponse`, then merge BE-9 (which contains BE-8's commits) with the merge tool.

Status 2026-11-11 (evening): step 1a ran. Studio accepted BE-9's script only after two fixes,
and the live preview found two more defects (explore answers counts without calling
`explore_data`; after a brief, an org-wide question routes to the brief). BE-9 is merged as the
base; BE-11 carries all four fixes. Nothing was committed, published or activated in Studio; the
Version 2 draft holds BE-9 plus the two Studio fixes, and version 1 is still active. The local
gate (`scripts/agent-check.sh`) did not catch any of the four, so a Studio save plus a live
preview of each branch stays mandatory before publish. Next: preview BE-11's exact bytes in
Studio, then Ben's go for 1d.

### 2. Adopt the Salesforce skills (done 2026-11-11)
The plugins `salesforce-development`, `agentforce-adlc`, `experience-lwc` and `integration` are
installed (2026-11-11). Python is 3.15, so the agent skill's local compiler is available (it needed 3.10+).
Workers still get named skill files in their briefs, not the plugins.

### 3. Fix the workflow gaps (cards to cut; standard tier unless noted)
- Agent workflow card: covered by BE-9 (scripts/agent-check.sh: local compile, validate, preview
  checklist; `aiAuthoringBundles` out of the routine org gate deploy). The test-spec move is
  closed: the skill does not require it.
- LWC test card: covered by FE-3 (LWC fixes plus Jest setup and tests for `accountBriefPanel`).
- Apex hygiene card (economy): replace legacy `System.assert*` in AccountBriefMemoryTest, add a
  permission-set description, decide on a TestDataFactory, add a Code Analyzer step now that the
  plugin is installed. It also takes the Apex review findings 7 to 10 and its nits (findings 11 to
  18). Keep our status-based action responses; that difference is deliberate.
- Docs scrub: this was OPS-14 (org and agent Ids removed, plan and telemetry write-up committed).

### 4. Build the outside door: MCP (after step 1, since one tool is the agent)
Card: custom server with tools `resolve_account`, `get_account_brief`, `ask_account_brief`;
a dedicated External Client App (scopes `mcp_api`, `refresh_token`); description overrides so
agent-facing wording does not reach MCP clients; retrieve and commit the `McpServerDefinition`.
Use the API quirks recorded in salesforce-mcp.md (add without a name, then rename;
`apex-<Class>` source Id). Ben does the OAuth sign-in from Claude or Postman; then measure a
real tool call, including whether `public` methods run and how long a brief takes.

### 5. Panel talks to the registered agent (after step 1)
Card: `@AuraEnabled` wrapper over `generateAiAgentResponse` with a test seam (the action
reportedly cannot run in Apex tests), unwrap the JSON envelope, hold the session Id in the
panel, show progress for the 14-18 s wait. Replaces the "Ask the agent" hand-off to the
built-in panel.

### 6. Still unverified
- The panel in the live utility bar: Cmd/Ctrl-K, focus trap, 340px layout (browser check).
- Everything as a non-admin user: Models API from Apex, the agent action, MCP tools.
- Agent API from outside Salesforce for an Employee-type agent (low priority if MCP's
  agent-as-tool works).
- Session lifetime and tool-call timeouts.

## Peer review (2026-11-11)
Three peer reviews landed, all with the verdict sound with fixes:
- [docs/reviews/apex-review.md](../reviews/apex-review.md)
- [docs/reviews/lwc-review.md](../reviews/lwc-review.md)
- [docs/reviews/agent-review.md](../reviews/agent-review.md)

Follow-up cards:
- BE-9: agent fixes on top of BE-8, plus `scripts/agent-check.sh`. Supersedes BE-8 and contains its commits.
- BE-10: the Apex top six findings, plus bulk and multi-request tests.
- FE-3: the LWC fixes plus Jest.

## Waiting on Ben
- Create the non-admin user `experimental-enduser` for FE-5.
- Go to commit, publish and activate once BE-11's bytes preview clean in Studio.
- Optional: `git push origin --delete agent/ops/OPS-1`.
