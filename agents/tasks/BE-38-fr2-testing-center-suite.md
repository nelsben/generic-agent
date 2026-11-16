---
id: BE-38
title: FR2: an Agentforce Testing Center suite for Customer Summary — a capped set of cases for the summary and the explorer through the optional agent, one script that recreates the test for the active version and prints counts, and a rung in the run
domain: backend
tier: frontier
tier_reason: creates and runs a Testing Center definition in a production-classified org, where each run spends model calls and runs real actions
status: merged
blocked_by: [BE-29, BE-30]
fixes: []
scope: [tests/agent/**, tests/test_agent_bundle.py, scripts/agent-test.sh, tests/test_agent_test_script.py, docs/research/fr2-testing-center.md]
forbid: [force-app/main/default/aiEvaluationDefinitions/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, mcp-door/**, spikes/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_agent_test_script.py fails on main (scripts/agent-test.sh does not exist and the spec has neither the case cap nor the new cases) and passes after
gate: test
budget: 2-attempts
spend: 8
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: "we have a really awesome opportunity to build out some really cool Agentforce Testing Center suite that we can incorporate into the run", and "how we communicate how to effectively test these agents as well as part of this bundle". Testing Center tests a registered agent (its spec names a BotDefinition), so the optional agent is the test bench: its actions call the same Apex services the panel and MCP call. It does not test the panel, the rail or cards; Playwright does. Covers ledger row F88 in docs/plans/feature-revision-2.md, and the version-pinning item (agent re-review N2) on page 08.

## Done when

- **Approval first:** read the row "FR2: create and run the functional Testing Center suite" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back. Read first: docs/plans/feature-revision-2.md (rows F88 to F92, the decision that the optional agent is the test bench, and the review of page 08's open items), docs/patterns/08-test-and-release-lifecycle.md, tests/agent/ (today's spec), docs/research/agent-iteration-1.md and docs/research/org-migration.md (how the last spec runs went). Load the skills agentforce-adlc:agentforce-test and salesforce-development:platform-metadata-deploy first
- **Settle the facts first** at the top of docs/research/fr2-testing-center.md, from Salesforce's public docs and the skill's references: what a test can assert (subagent, actions, outcome judged by a model, and any custom evaluation on an action's output), what one run costs in the org's generative AI usage, Salesforce's advice to run Testing Center in a sandbox and what that means for a Developer Edition org that has none (a scratch org, as OPS-28 uses, is one answer), and how a definition stays tied to one agent version
- **The suite,** at most 20 cases, in tests/agent/Customer_Summary-testSpec.yaml: a summary for a named account, not found, several matches, a follow-up that needs the first turn (conversation history), an org-wide explorer question, a question outside the agent's job, and one case per error status BE-29 added. Each case has an expected outcome in plain words; use subagent and action checks where they apply. No write actions: no case asks to create, change or delete a record. A summary still records what it always records (its session row and, after BE-35, a customer outcome), so the cases use one existing sample-data account (data/sample/accounts.json, which scripts/seed-sample-data.sh loads into agent-probe and into OPS-28's scratch org), named in the research page and not the one the demos use; create no new records; record in the research page what one run writes. The agent is not republished in this card: a case that fails because the agent's script lags behind the Apex is a finding for Ben, not a fix
- **scripts/agent-test.sh** creates or updates the test definition for the active version of the optional agent (its developer name comes from docs/research/fr2-rename-go.md: Customer_Summary on GO, Account_Brief on NO-GO), runs it, and prints one line per assertion type with pass and fail counts (leaving out the known false failure of the subagent check on cases that set no subagent), and the version it ran against. A run leaves git status unchanged (any file the CLI writes goes to a temporary folder, and nothing is written under force-app), so OPS-28 can run it in a scratch org. It prints and writes no record Ids, usernames, job Ids or hostnames. tests/test_agent_bundle.py today pins the 16-case spec: update it to the new spec in the same change. **No definition in force-app:** the script builds the test definition from the YAML at run time, outside force-app (for example in a temporary project folder), so validate-org.sh and the README's quick start never deploy a test that needs the agent. tests/test_agent_test_script.py checks the spec's shape, the case cap, that no case uses a write action, and the script's flags. Run it once in agent-probe and record the counts in the research page
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- **Security cases:** do not write or run any. Record in the research page what a security suite would cover and that it needs a non-production org and Ben's go. Never publish, activate or deactivate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-16). One worker attempt (opus, frontier tier, $6.13 including one advisor call), two reviewer passes (sonnet), and one brain commit (37aa25a) that records a second run. The brain read the diff and the research page, ran the committed script once against the org, and counted the rows it wrote.

Findings:
- Suite: tests/agent/Customer_Summary-testSpec.yaml has 16 cases (cap 20). They cover summary, not found, several matches, follow-ups, five org-wide explorer questions, off-topic, and the two BE-29 error texts replayed as history. No write action and no security case. Summary cases use one non-demo sample account, Gallowglass Textiles.
- scripts/agent-test.sh looks up the active version, builds the definition in a temporary folder (never force-app) pinned to that version, runs it, and prints counts per assertion type, one line per failed check by case number, and the version. Every sf call passes -o. Exit codes: 0 pass, 1 an assertion failed, 2 bad arguments, 3 an org step failed or timed out. It echoes no Ids, usernames, hosts or job Ids; a fake-sf test feeds invented ones and checks none reach the output.
- First run (worker): 46 of 47 on Customer_Summary v2; one outcome check failed and the run did not name the case.
- Second run (brain, at the committed script, overwriting the existing definition): 47 of 47, exit 0, git status unchanged. The failed-case lines did not print, so they are proven against the fake sf only.
- Writes per run: six Customer_Outcome__c rows on Gallowglass Textiles. The session row is reused (the brain counted Gallowglass 6 to 12, org outcomes 123 to 129, sessions 20 to 20). This is approved under BE-38's row and the standing row for tests that create their own records.

Reviewer refutations, resolved:
- Hand-back said check-docs saw 87 pages: 88 at the sha, 0 broken (hand-back text only).
- Hand-back said four explorer cases: the spec and the research page say five (hand-back text only).
- tests/__pycache__ existed (gitignored, uncommitted): removed before merge.

Gate (mod verify at 37aa25a): Python 409 tests, 4 skipped. check-docs 88 pages, 0 broken.

Org: agent-probe only. Two Testing Center runs. The Customer_Summary_Test AiEvaluationDefinition was created, then overwritten. No deploy, publish, activation, user or setting change.

Disclosed and accepted:
- The .agent's resolve_account output descriptions still omit ERROR (the instructions handle it). This is a one-line fix at the next publish; it is Ben's call.
- The two BE-29 error cases test the reply after an error given as history, not the error itself.
- The per-case failure lines have never printed against the real org.

Follow-up outside this card's scope (brain docs PR after merge): README Status rows, pattern 08's "not run in this build" text and open items, and ledger row F88. scripts/ladder.sh needs no change: its skip branch fires only when the script is missing.

Privacy check over the branch's own diff: 0 denylist hits. The pattern hits are a test docstring and an invented fixture (example.com host, placeholder Id).
