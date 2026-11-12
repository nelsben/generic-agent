---
id: BE-8
title: Account_Brief agent routes account-named requests to the brief, relays action text with nothing added, and its test spec uses an account that exists
domain: backend
tier: standard
tier_reason: prompt and routing changes in one Agent Script file, proven by a live agent test
status: queued
fixes: [BE-7]
scope: [force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent, tests/agent/Account_Brief-testSpec.yaml, tests/test_agent_bundle.py]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.bundle-meta.xml]
red_test: python3 -m unittest tests.test_agent_bundle (add a test that the spec no longer contains 'Acme Corp' and that the off-topic case names an expected topic; fails before, passes after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

The first agent test run in experimental (8 cases) showed two real defects and two spec faults. Requests that name an account but read like a data question ('which deals are slipping', 'just the open deals for X') went to explore instead of account_brief, and the agent added its own sentence after a verbatim message. These must be fixed before the custom panel shows agent replies in our own UI.

## Done when

- Read docs/ARCHITECTURE.md, the .agent file and the test spec first. Org alias is `experimental`. Change no Apex
- Routing rule to implement in the router (agent_router) instructions and transition descriptions: a message that names one specific account (by name or by a pasted 001 Id) and asks anything about that account goes to account_brief, including narrow asks such as 'just the open deals for X' or 'what is going on with X and which deals are slipping'. A follow-up about the account already briefed also goes to account_brief. explore is for questions that do not name one account: org-wide counts, lists, totals, lookups. Keep the off-topic one-line reply
- Verbatim relay: in both subagents the reply is the action's message or answer text and nothing else, with no sentence before or after it, including on AMBIGUOUS, NOT_FOUND, EMPTY and ERROR. Tighten the instructions to get this; do not change the action outputs
- Keep the gate as it is: get_brief is available only when briefed_account_id is not empty, resolve_account sets the Id unconditionally, and a different account name must go through resolve_account again
- Test spec: replace 'Acme Corp' in the three cases that use it with an account that exists in experimental and has opportunities. Query for standard Developer Edition sample accounts first (Edge Communications, Burlington Textiles Corp of America, GenePoint) and use one if it has opportunities; otherwise use the most recently modified account with opportunities. Add a YAML comment at the top of the spec saying this name must exist in the target org. Keep 'Zzqxv Nonexistent Holdings' and the fake Id case. Keep 8 cases
- Off-topic case: the last run expected a blank topic and the org reported `topic_selector`. Set expectedTopic to whatever the org reports for the router on that case in your own run
- This card allows these org actions, at most 3 cycles: publish with `sf agent publish authoring-bundle -o experimental -n Account_Brief --skip-retrieve --json` (never without --skip-retrieve; if it still changes Account_Brief.bundle-meta.xml, restore that file with git checkout), `sf agent activate -o experimental -n Account_Brief`, then `sf agent test create --spec tests/agent/Account_Brief-testSpec.yaml --api-name Account_Brief_Test -o experimental --force-overwrite` and `sf agent test run --api-name Account_Brief_Test -o experimental --wait 10 --result-format json`. Delete any force-app/main/default/aiEvaluationDefinitions folder the create command writes; do not commit it. Each run spends credits, so do not exceed 3 cycles; if it is not green by then, hand back with the remaining failures
- Live probe OPS-6 (docs/research/agent-api.md, section Live probe) showed two more defects to fix here: (a) the agent rewrote the brief text (joined section labels to bodies, dropped '- ' bullets) and appended a closing question ('Would you like more details on ...?'); (b) a follow-up about the briefed account ('What about its open cases?') was answered from the conversation without calling get_brief. Instructions must make a follow-up about the briefed account call get_brief with the follow-up as userQuestion, and forbid any closing question or offer. Add one multi-turn check if the spec format supports conversation history; if it does not, say so in the hand-back and check it with one manual two-turn run through the generateAiAgentResponse action (the probe's Apex is in that doc), counted inside the 3-cycle limit
- Done means the last run shows: all 8 cases with the expected topic and expected actions, and for the not-found and explore cases a reply that is the action text with nothing added. In the hand-back give a per-case table (utterance, topic expected and actual, actions expected and actual, pass or fail) from the last run, and say which agent version is active at the end
- Gates pass: test and org. Quote the `validate-org:` line. Commit, do not push
