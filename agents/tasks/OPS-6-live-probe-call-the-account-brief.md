---
id: OPS-6
title: Live probe: call the Account_Brief agent from Apex through its generateAiAgentResponse action, two turns, and record what came back in docs/research/agent-api.md
domain: ops
tier: standard
tier_reason: small live probe with judgment about what the results prove; one doc file
status: merged
scope: [docs/research/agent-api.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**]
red_test: none
gate: test
budget: 2-attempts
spend: 6
---
## Why

The custom panel should be able to hold a conversation with the registered Account_Brief agent and render the reply itself. Research says the per-agent invocable action generateAiAgentResponse does this from Apex, but nobody has called it; parameter names come from unverified summaries. One cheap live call settles whether this door exists before any build card is written.

## Done when

- Read docs/research/agent-api.md and docs/ARCHITECTURE.md first. Org alias is `experimental`. Change only docs/research/agent-api.md in the repo; keep every script and raw output in a scratch folder outside the repo (mktemp -d)
- This card lifts the earlier read-only rule for exactly this: at most 4 invocations of the Account_Brief agent action through `sf apex run -o experimental -f <file>` (each one spends credits and the brief writes one Account_Brief_Session__c row; leave those rows). No deploys, no metadata changes, no other DML, no setup changes, no browser. If something needs more than 4 invocations, stop and report
- Step 1, free: describe the action with `sf api request rest /services/data/v68.0/actions/custom/generateAiAgentResponse/Account_Brief -o experimental` and record the real input and output parameter names and types. Use those names; do not guess from the doc
- Step 2: pick the account at run time with `SELECT Id, Name FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity) ORDER BY LastModifiedDate DESC LIMIT 1`. Do not use 'Acme'; it does not exist in this org
- Step 3, turn 1: anonymous Apex using Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief'), user message `Give me a brief on <that account name>`. Print with System.debug(LoggingLevel.ERROR, ...): isSuccess, errors, every output parameter, elapsed milliseconds, Limits.getCallouts() and Limits.getDmlStatements()
- Step 4, turn 2: a SEPARATE sf apex run execution that passes the session Id from turn 1 as a literal, user message `What about its open cases?` (the account is deliberately not named). Print the same fields
- Step 5: after turn 1, query the newest Account_Brief_Session__c (Id, CreatedById, CreatedDate, and its account lookup) and compare CreatedById to the running user's Id from `sf org display user -o experimental`. This is a partial check of user context only
- Pass means all three: turn 1 returns a non-empty reply about the picked account; a session Id comes back; turn 2 returns a reply about the same account without it being named. Report each of the three separately as pass or fail. A failed call is a valid finding: record the exact error text and stop, do not work around it and do not try the Agent REST API
- Add a section `## Live probe (generateAiAgentResponse)` to docs/research/agent-api.md with: the action describe result (parameter names and types), the Apex used for turn 1 (short), the three pass/fail lines, timings, callout and DML counts, the reply length and its first 300 characters for each turn with the account name replaced by `<account>`, whether the reply was the action's text verbatim or had extra sentences added by the agent, and the CreatedById comparison. Mark each line verified
- Update the doc's Plain answer, Open questions and Recommendation to match what the probe showed. State plainly what is still unverified: behaviour for a non-admin user, whether the action can run inside an Apex test, session lifetime
- Scrub: remove every name of another app, agent or credential in the org from this file (the two External Client App names, the second agent, the Named Credential names). Replace with generic words such as 'two existing External Client Apps', 'a second, inactive agent', 'five Named Credentials for other services'. `grep -i plesio docs/research/agent-api.md` must print nothing. Keep the Account_Brief Ids
- No client names, no content from reference/. Keep the file under 250 lines. Gate passes: test. Commit, do not push

## Review

Brain read the live-probe section at 38496a8: describe gives userMessage/sessionId in, agentResponse/sessionId out; two turns passed (reply, session Id, follow-up kept the account). Findings that feed later cards: agentResponse is a JSON envelope {"type":"Text","value":...}; the agent rewrites action text lightly and appends a closing question; turn 2 answered from conversation without calling get_brief; 14-18 s per turn. Ran as admin only; non-admin, Apex-test support and session lifetime remain unverified. Scrub confirmed (no other app names; account and owner masked).
