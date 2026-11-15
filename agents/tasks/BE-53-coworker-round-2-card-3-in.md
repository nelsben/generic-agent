---
id: BE-53
title: Coworker round 2, card 3: in connect-24h the Search Agent door and one ConnectApi.Search.findAndGroup call are tried and read in full, so answer 1 reads yes or no with evidence
domain: backend
tier: standard
status: merged
scope: [spikes/coworker/apex/**, spikes/coworker/results/headless.jsonl, docs/research/fr2-coworker-spike.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, docs/assets/**, README.md, spikes/coworker/main/**, spikes/coworker/results/delegation.jsonl, spikes/coworker/results/cards.jsonl, spikes/cards/**, spikes/actions/**, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json]
red_test: none
gate: test
budget: 2-attempts
spend: 15
---
## Why

BE-47 and BE-52 left answer 1 (can our code call Coworker headlessly) at not proven: agent-probe has no Search Agent, and the one findAndGroup run returned a CLI status of 1 whose detail was never read. With Coworker turned on in connect-24h by OPS-63, the Search Agent should exist and door 2 can be run and read once. This is a spike and changes no product surface.

## Done when

- **Org guard first, before any other step.** Run `sf org display -o connect-24h --json` and `sf org display -o agent-probe --json` and compare `result.id` and `result.username` in a shell expression that prints only SAME or DIFFERENT, never the values. If connect-24h does not resolve, or either value is the same, take no org step, say so in the hand-back and stop
- Read first: docs/research/fr2-coworker-spike.md sections 'Headless door probe (BE-47)' and 'Delegation, measured' (OPS-63's result in connect-24h), spikes/coworker/apex/*.apex, spikes/coworker/results/headless.jsonl, and the Approvals row 'FR2+: Agentforce Coworker live steps' in docs/plans/gtm-burn-plan.md (approved for connect-24h; it names the agent invocable and the search API from anonymous Apex). Load the skills salesforce-development:platform-apex-anonymous-run and salesforce-development:platform-soql-query first
- **Org rules.** Only `connect-24h`, with `-o connect-24h` on every `sf` command; the one exception is the guard's read-only `sf org display -o agent-probe`. Never touch agent-probe, experimental, experimental-web or my-devhub otherwise. No DML, no deploy, no grant, no record or user created, no sign-in, no connected app or External Client App (so the Coworker MCP door stays untried: say so). Foreground waits under 10 minutes, no background jobs
- **Door 1.** A read-only BotDefinition query for Search in the developer name or label. If a Search Agent exists, one turn to it through the `generateAiAgentResponse` invocable from anonymous Apex (adapt spikes/coworker/apex/door1-control-customer-summary.apex into a new door1-search-agent.apex) asking for the seed account's open cases; record status, reply length, whether it names the account, and seconds. End the session if the API offers an end call; otherwise list it under Undo. If no Search Agent exists, record that, and whether Coworker was on (OPS-63's result)
- **Door 2.** Run `sf apex run -o connect-24h --file spikes/coworker/apex/door2-connectapi-search.apex --json` once and read the whole JSON result (compiled, success, compileProblem, exceptionMessage, line and column, and the debug log lines the script prints). If it fails, diagnose once from that output, fix the script once and rerun once. Before writing any output to a file, check that it carries no record name other than the seed account's and no Id; if the script's errMsg could carry one, replace it with the exception type and a short paraphrase. If findAndGroup returns results, also try `answer(String q)` once in the same way
- **Record.** Update spikes/coworker/results/headless.jsonl with one new row per door tried in connect-24h (keep the agent-probe rows, add an org field naming the alias), and the page's 'Headless door probe' section with a connect-24h table. Set answer 1 at the top of the page, the feature map row and For Ben item 8 to yes, no or not proven from this evidence, naming what answered. Any working door would make Coworker a way in from our code, which is F83 and Ben's decision: say so and build nothing on it
- No org Ids, record Ids, job Ids, session Ids, usernames, emails, hostnames or URLs with a query string in any file. Workers may read docs/plans/** and run scripts/check-docs.sh but edit neither
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. End with the [[report]] line

## Review

Brain review (2026-11-15). One attempt (71c7d57), sonnet, standard tier, $0.59. The mod judged it consistent and accepted it without a reviewer pass; the brain read the diff itself.

Findings:
- Door 1 (the org's SearchAgent, label "Coworker Agent", via generateAiAgentResponse): one turn asking for the seed account's open cases aborted. The debug log stops before invoke() returns, with no catchable exception, no session and no reply, in about 2 seconds. A rerun with step markers matched. Not diagnosed. The control turn, the same script aimed at Customer_Summary, answered in 14 s (1,271 characters, names the account, session returned).
- Door 2: BE-52's CLI status 1 was a compile error in our script (a variable named json shadowed the JSON class). After the fix, ConnectApi.Search.findAndGroup(String) returned 2 result groups (keys resultGroups, metadata, queryInfo): search results, not Coworker's Ask. ConnectApi.Search.answer(String) threw System.NoAccessException; the message was not copied.
- Door 3 (Coworker MCP server): not tried; it needs a connected app or External Client App and a sign-in.
- Answer 1 on the spike page stays "not proven". headless.jsonl gains five connect-24h rows and an org field on every row.
- New script door2-connectapi-answer.apex; door1-search-agent.apex prints result lines only.

Gate (worker, gate-mac lane): Python 390 tests, 4 skipped; check-docs 0 broken. Mod: green.

Org: read-only SOQL and anonymous Apex agent turns in connect-24h. No deploy, grant or description change. Up to two agent sessions are left open (listed in the page's Undo section).

Disclosed and accepted:
- Door 2's script was edited twice, not once (the compile fix, then the result key), and run three times.
- The Customer_Summary control and one debug-print check ran from uncommitted scratch scripts.
- The scripts print the seed account's name and the raw exception message into the debug log only; nothing of that went into a file.

Still open:
- Why the SearchAgent turn aborts before returning.
- Which permission answer(String) needs.
- Any working door is F83 and Ben's call.

Privacy check over the full branch diff (95 added lines): 0 denylist hits, no pattern hits, no URL hosts.
