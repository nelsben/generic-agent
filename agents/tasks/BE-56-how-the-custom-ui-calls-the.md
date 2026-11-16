---
id: BE-56
title: How the custom UI calls the agent: a cited options table and a working multi-turn Apex+LWC door prototype in spikes/agent-door, measured on 3 two-turn conversations
domain: backend
tier: standard
effort: high
effort_reason: cross-cutting - Apex session handling, LWC, deploy and a recommendation across five doors
status: queued
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
