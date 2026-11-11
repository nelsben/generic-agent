---
id: BE-7
title: Account_Brief Employee agent in Agent Script with three Apex actions (resolve, brief, explore), a resolve-then-brief gate, verbatim relay and an sf agent test spec
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/aiAuthoringBundles/Account_Brief/**, tests/agent/Account_Brief-testSpec.yaml, tests/test_agent_bundle.py]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/**]
red_test: python3 -m unittest tests.test_agent_bundle (absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

This is the route layer: a small Agent Script agent that calls the Apex engine directly (no Flows, no prompt templates). It has two paths. The curated brief has a strict resolve-before-brief gate. Open exploration answers any data question through the safe explorer. Both relay their answers verbatim. The Apex engine is deployed to the experimental org before this card runs; the brain publishes the agent after merge.

## Done when

- force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent and Account_Brief.bundle-meta.xml exist. bundle-meta is exactly `<?xml version="1.0" encoding="UTF-8"?>` + `<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata"><bundleType>AGENT</bundleType></AiAuthoringBundle>` (no <target>). Syntax reference (read only; copy no names or prose): /Users/bennelsen/Documents/generic-agent/reference/examples/experimental/aiAuthoringBundles/Plesio_AgentScript_1/
- config: developer_name "Account_Brief", agent_label "Account Brief", agent_type "AgentforceEmployeeAgent". Mutable string variables: briefed_account_id, briefed_account_name, last_status. start_agent routes to two subagents: `account_brief` (a brief, summary or 'what's going on' for an account) and `explore` (any other question about CRM data). Requests about anything else get one fixed line saying what the agent does
- Actions, with input and output names copied exactly from the classes on main: resolve_account (apex://AccountBriefResolver, message is_displayable True), get_brief (apex://AccountBriefGetAction, answer is_displayable True), explore_data (apex://ExploreAction, answer is_displayable True; pass contextRecordId = @variables.briefed_account_id when set). After a RESOLVED resolve, set briefed_account_id/name; set last_status after every action
- account_brief rules: a new account name goes through resolve_account first, with the user's words copied character for character. AMBIGUOUS or NOT_FOUND: relay message verbatim and call nothing else; when the user picks, re-resolve with the Id from the list. RESOLVED: call get_brief with the stored Id. A follow-up on the same account calls get_brief again with the same Id and the follow-up as userQuestion. Pass include only when the user asks for specific areas, using the keys in the action's description
- explore rules: pass the user's question unchanged; relay answer verbatim; never invent data; never offer filters or exports the action doesn't provide
- tests/agent/Account_Brief-testSpec.yaml is a valid `sf agent test create` spec (subjectType AGENT, subjectName Account_Brief) with 8 single-utterance cases using generic names: brief by name; follow-up; gibberish name; pasted 001 Id; 'just the open deals for <name>'; two explore questions (a count and a list); one off-topic
- tests/test_agent_bundle.py (stdlib unittest) asserts that bundle-meta has no <target>, the .agent names all three apex targets, and the spec has 8 `utterance:` lines
- Gates pass: test and org. If the org gate doesn't cover aiAuthoringBundles, also run the bundle validate subcommand from `sf agent --help` against experimental and quote it. Do not publish

## Review

Brain read of the .agent at aacec10: router plus two subagents; get_brief is gated on briefed_account_id, and a failed resolve clears it. Bundle validated against the org by the worker (sf agent validate authoring-bundle). Known gap: a second account name relies on instructions to re-resolve.
