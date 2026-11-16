---
id: OPS-64
title: Coworker calls Customer_Summary in connect-24h, or the page says exactly which ways were tried and why each failed
domain: ops
tier: frontier
tier_reason: open design question - how Coworker selects and calls other agents is undocumented in the repo and blocks FE-28 and F83
status: queued
scope: [docs/research/coworker-calls-our-agent.md, docs/research/fr2-coworker-spike.md, spikes/coworker/results/delegation-2.jsonl, docs/assets/coworker-delegated-*.png, docs/assets/MANIFEST.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json, spikes/agent-door/**, spikes/coworker/search/**, spikes/coworker/results/search.jsonl, docs/research/coworker-data-search.md, docs/research/custom-ui-calls-agent.md]
resources: [chrome-connect]
red_test: none
gate: test
budget: 2-attempts
spend: 15
---
## Why

Ben wants to test our agent being called by Coworker, and guesses the agent must be added to Coworker as a callable agent. OPS-63 measured 0 of 9 delegations with nothing changed, and FE-28's card-in-Coworker re-cut and the F83 decision both wait on whether Coworker can call our agent at all. This spike finds the documented mechanism and tries each way in the org, cheapest first.

## Done when

- Guard first, before any org step: compare `sf org display -o connect-24h --json` and `-o agent-probe --json` result.id and result.username and print only SAME or DIFFERENT for each; stop and hand back if either is SAME. Work only in connect-24h; never touch experimental or agent-probe.
- docs/research/coworker-calls-our-agent.md exists and answers, with a cited Salesforce doc for each claim (read the help pages in a Chrome tab, since plain fetches return 403; list each page in a Sources section with the date read): how Coworker (the org's SearchAgent, label Coworker Agent) chooses another agent; whether an agent must be added or granted to be callable (agent access permission sets, agent or topic descriptions, a Setup list of callable agents, connected agents or agent-to-agent in Agentforce Builder, Coworker Skills); and what the docs say is not supported.
- Ways tried in this order, stopping at the first that works plus one confirming way if cheap: (a) a question that names Customer Summary; (b) changed agent and topic descriptions on Customer_Summary, edited in the org only through Agentforce Builder (the repo bundle under force-app stays unchanged), then republished and reactivated; (c) adding Customer_Summary as a connected or callable agent of the Coworker Agent, if Builder or Setup offers it; (d) any Setup setting the docs name. A way the org does not offer is recorded as not offered, with what was seen.
- Each way tried gets 3 turns, each in a new Coworker chat on the Edge Communications record, using the same summary question as OPS-63 (spikes/coworker/delegation-notes.md). spikes/coworker/results/delegation-2.jsonl has one row per turn: way, turn, question id, delegated true/false, how that is known (the reasoning or plan panel, the answer's labels, or Customer_Summary session rows), seconds to full answer. No record Ids, session Ids, usernames or hostnames in the rows.
- If any way delegates: 3 more turns using BE-32's e2 and e4 questions, labels kept counted against the 6 panel labels, and 2 cropped captures docs/assets/coworker-delegated-*.png showing no Ids, usernames, URL bar or host, each added to docs/assets/MANIFEST.md.
- docs/research/fr2-coworker-spike.md: answer 3 and the Delegation section updated with one paragraph linking the new page and stating the result plainly; nothing claims more than was measured.
- The new page has an Undo section listing every org change (descriptions changed and their old text summarized, agent versions published, connected-agent links, settings) left in place until the org expires, and a For Ben section: which way works, what it costs in latency and fidelity, and what it means for FE-28's re-cut and F83.
- Rules: never enter credentials, sign in for Ben, or create users; never accept terms or enable a new Setup feature beyond the ways above (record it as needing Ben's go instead); a grant or step refused by the permission check is recorded and not retried or worked around; agent access grants to Coworker_Spike agents stay out of scope; no org Ids, record Ids, usernames, emails, hostnames or query-string URLs in any committed file.
- Gate passes: unit tests and bash scripts/check-docs.sh with 0 broken links.
