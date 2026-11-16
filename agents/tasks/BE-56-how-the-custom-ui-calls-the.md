---
id: BE-56
title: How the custom UI calls the agent: a cited options table and a working multi-turn Apex+LWC door prototype in spikes/agent-door, measured on 3 two-turn conversations
domain: backend
tier: standard
effort: high
effort_reason: cross-cutting - Apex session handling, LWC, deploy and a recommendation across five doors
status: merged
scope: [spikes/agent-door/**, docs/research/custom-ui-calls-agent.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json, docs/research/fr2-coworker-spike.md, docs/research/coworker-calls-our-agent.md, docs/research/coworker-data-search.md, spikes/coworker/**, docs/assets/**, sfdx-project.json]
red_test: npx sfdx-lwc-jest -- --roots spikes/agent-door (fails now: no such folder; passes with the prototype's Jest tests)
gate: test
budget: 2-attempts
spend: 10
---
## Why

Ben wants to cut in how our custom UI could call the agent. Today the panel bypasses Agentforce through Apex and a Named Credential, BE-15 (agent-backed panel) is parked, and BE-53 showed the invocable generateAiAgentResponse path answers Customer_Summary in about 14 s but kept no multi-turn session. This card compares every door, prototypes the cheapest one with session handling, and recommends a path tied to BE-15 and BE-32's numbers.

## Done when

- Guard first, before any org step: compare `sf org display -o connect-24h --json` and `-o agent-probe --json` result.id and result.username and print only SAME or DIFFERENT for each; stop and hand back if either is SAME. Deploy and run only in connect-24h.
- docs/research/custom-ui-calls-agent.md has an options table, each row cited to a Salesforce doc (read in a Chrome tab if plain fetches return 403; a Sources section with the date read): the Apex invocable generateAiAgentResponse (BE-53's control path); the Agent API (needs an External Client App and OAuth: documented only, no app or credential is created); any LWC or Lightning API to open or drive the standard Agentforce panel; Embedded Messaging / Enhanced Chat; Coworker (BE-53's doors). Columns: how it is called, multi-turn support, auth, what it costs to set up, latency if measured, and limits.
- spikes/agent-door/ holds an @AuraEnabled Apex class (with sharing, user-mode reads, no system-context exception) that sends a message to Customer_Summary through the invocable action, keeps the returned session id so a second turn continues the same session, and ends the session; an Apex test class for it using a stub or mock where the platform cannot run the agent in tests; and an LWC (two turns plus an End button) with Jest tests that pass under `npx sfdx-lwc-jest -- --roots spikes/agent-door`.
- Deployed to connect-24h with `sf project deploy start --source-dir spikes/agent-door -o connect-24h` and RunSpecifiedTests over the new test class only (never RunLocalTests: the org's template classes do not compile). sfdx-project.json stays unchanged.
- 3 two-turn conversations on the Edge Communications account run through the deployed Apex (anonymous Apex calling the class, or the LWC on a page if one can be added without new metadata outside scope). The page records per turn: seconds, whether turn 2 used turn 1's context (asks a follow-up that only makes sense with it), reply length, and whether the session ended. No session Ids, record Ids, usernames or hostnames in the page.
- A Recommendation section: which door the custom panel should use for agent turns, what that means for BE-15 (parked) and how its latency compares with BE-32's measured panel and agent numbers already in the repo; plus what needs Ben's go (an External Client App for the Agent API, any connected app).
- An Undo section lists everything deployed to connect-24h and any agent sessions left open; the spike stays deployed until the org expires.
- Rules: no credentials, sign-ins, user creation, connected apps or External Client Apps; a step refused by the permission check is recorded and not worked around; no org Ids, record Ids, usernames, emails, hostnames or query-string URLs in committed files.
- Gate passes: unit tests and bash scripts/check-docs.sh with 0 broken links.

## Review

Brain review (2026-11-15). One attempt (7b6c9b5), sonnet, standard tier at high effort, $2.47. The mod judged it consistent and accepted it without a reviewer pass; the brain read the diff and checked the app metadata and the scratchpad cleanup.

Findings:
- docs/research/custom-ui-calls-agent.md: a five-door table (Apex invocable, Agent API, lightning/accApi on the standard panel, Embedded Messaging, Coworker), each row cited, Sources dated 2026-11-15. The Recommendation is the Apex invocable behind @AuraEnabled for the panel's agent turns. It needs no app or credential, and it is what BE-20 already ships for "Ask the agent".
- spikes/agent-door: AgentDoorController (with sharing, a WITH USER_MODE read, a gateway seam for tests, no system-context code), 6 Apex tests (6 of 6 pass in the org), the agentDoor LWC with 5 Jest tests, the two-turns script, and the External Client App Agent_Door_Spike (authorization code with PKCE, secret optional and never fetched; scopes Api, RefreshToken, Chatbot, SFApiPlatform).
- Measured, invocable: 3 two-turn conversations on the seed account. Turn 2 continued the same session and used turn 1's context in 3 of 3. First turns took 11 to 31 s, follow-ups 9 to 13 s.
- Measured, Agent API, with Ben's sign-in: 2 two-turn conversations, all HTTP 200, turn 2 used context in both, and both sessions were ended through the API. First turns took 14 and 32 s, follow-ups 10 and 30 s. An employee agent worked through the Agent API with a user-bound token, which agent-api.md had left open.
- Finding: no in-org call ends an agent session. The prototype's endSession says so (endedOnPlatform=false). Only the Agent API's end call ends one.
- The accApi row quotes the doc: execute() does not return the agent's reply to the component, so that door cannot feed our own cards.

Gate (worker, gate-mac lane): Python 390 tests, 4 skipped; Jest 5 tests; check-docs 0 broken. Mod: green.

Org: 7 components and the LWC deployed to connect-24h with RunSpecifiedTests over AgentDoorControllerTest only, plus one External Client App (Ben's go, 2026-11-15). Six invocable sessions are left to expire on the platform's timer: three from the measured runs and three from an inline pilot. The two Agent API sessions were ended.

Disclosed and accepted:
- The deploy-gate hook needed a target org. A worktree-local target-org was set with the brain's approval, then unset; the brain confirmed it is unset.
- The ECA's contact email is a placeholder in the repo. The admin's address was swapped in for the deploy and restored before the commit.
- The consumer key was retrieved into the scratchpad only. The brain confirmed the committed global OAuth settings file has no key, and that the token and retrieved key files are gone. A stray sed printed a link holding the org Id into the worker's transcript, not into any file.
- The LWC was not placed on a page; the conversations ran through the deployed class from anonymous Apex.

Still open:
- How long the platform's session timer runs before an invocable session expires.
- Whether a production build of the panel should hold sessions this way, or move to the Agent API for its end call. The Agent API needs an app and a held token per user.

Privacy check over the full branch diff (711 added lines): 0 denylist hits. The pattern hits are @IsTest annotations. The URL hosts are localhost:1717 (the OAuth callback), the standard soap.sforce.com metadata namespace and developer.salesforce.com docs.
