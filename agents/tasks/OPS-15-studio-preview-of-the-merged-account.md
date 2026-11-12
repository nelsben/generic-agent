---
id: OPS-15
title: Studio preview of the merged Account_Brief agent (sha256 prefix fb0fc27d): save the draft, validate, live-preview every routing branch, record the results
domain: ops
tier: standard
tier_reason: careful browser observation and recording against a spec; no design
status: merged
fixes: []
scope: [docs/research/studio-preview.md]
forbid: [force-app/**, tests/**, scripts/**, agents/**, docs/plans/**, docs/reviews/**, .chassis-delegation.json, reference/**]
resources: [chrome-studio]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

BE-11 fixed four defects that only Agentforce Studio found. The local gate cannot see Studio's validation or runtime behaviour, so the corrective plan requires a Studio save and a live preview of each branch before Ben decides on commit, publish and activate. This card produces that evidence. It changes nothing that is live in the org.

## Done when

- Read docs/plans/corrective-plan.md (step 1), docs/research/salesforce-skills.md (lifecycle, plus the section 'What the local agent gate cannot see') and tests/agent/Account_Brief-testSpec.yaml first. Load the anthropic-skills:chrome-browser skill before the first browser call, and the agentforce-adlc:agentforce-generate skill for Studio and preview behaviour
- The bytes you paste are force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent on origin/main. Its sha256 starts fb0fc27d; check with shasum -a 256 before pasting and stop if it differs
- Use the Claude in Chrome extension. Ben is already signed in to the org `experimental` in Chrome. Call tabs_context_mcp, open your own new tab, and close it when you finish. Never sign in, never enter credentials, and if the session has expired stop and report it
- In Agentforce Studio, open the agent Account_Brief and its existing draft, Version 2 (Draft). Replace the draft's script with the file's exact bytes and save. Record Studio's validation result. If Studio rejects it, copy the exact error text into the results and stop. Do not edit the script to make it pass
- Run a live preview (Studio's preview pane) of every utterance in tests/agent/Account_Brief-testSpec.yaml, in order and in the conversations the spec implies (a follow-up shares the conversation of the turn before it; start a fresh conversation where the spec starts a new case). For each, record the utterance, the subagent it reached, the actions shown (with their inputs where Studio shows them), the reply, and pass or fail against the spec's expectations
- Answer these three questions with evidence from the preview's trace or action view: (a) does the explore_data action's `question` input equal the user's message word for word; (b) is explore's before_reasoning run of explore_data shown as an action, which the spec's expectedActions explore_data depends on; (c) on a new turn, does the conversation re-enter the router (agent_router) or stay in the subagent that answered the previous turn. Also say whether 'NOT_FOUND, then a follow-up' relays NOT_FOUND again without calling get_brief on Edge Communications
- Hard limits: never click Commit Version, Publish, Activate, Deactivate or delete, never create another agent or version, and never change org settings or data. Saving the existing draft is the only write allowed. Do not paste session ids, record Ids, tokens or URLs with query strings into the results: write record Ids as <id..last6>. Never trigger a browser dialog; if one blocks the page, stop and report it
- Write the results to docs/research/studio-preview.md: the date, the sha256 prefix, the validation result, a table of utterance, subagent, actions, reply excerpt (at most 200 characters) and pass/fail, the answers to (a), (b) and (c), and a one-line verdict (clean or not clean, and why). If a turn fails, record what you saw and continue with the next case. Do not try fixes
- The gate passes: `python3 -m unittest discover -s tests`, run with PYTHONDONTWRITEBYTECODE=1. Leave no tests/__pycache__/ behind, and `git status --short` is empty after your commit

## Review

No reviewer pass (docs-only card, observation in a live browser). Result: Studio saved the fb0fc27d script into Version 2 (Draft) with 0 errors and 1 warning (resolve_account missing input knownAccountId); all 12 spec utterances behaved as expected. (a) question equals the user message; (b) the before_reasoning run shows as an action; (c) every turn re-enters the router. Open: case 11's reply is not a byte-for-byte relay (table headers Account.Name and Owner.Name came back as URL_Redacted); cause not established. Nothing was committed, published or activated.
