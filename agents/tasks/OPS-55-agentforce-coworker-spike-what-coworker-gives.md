---
id: OPS-55
title: Agentforce Coworker spike — what Coworker gives for free against what Customer Summary builds, and three sourced answers: can our UI call it headless, can its UI be embedded in ours, can our actions, MCP door and cards run inside it; a feature map, a recommendation and Ben's decisions
domain: ops
tier: frontier
tier_reason: a build-or-adopt architecture decision across every surface, from product docs that are new and partly unverifiable
status: merged
scope: [docs/research/fr2-coworker-spike.md, spikes/coworker/**]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json, package.json]
red_test: none
gate: test
budget: 2-attempts
spend: 8
---
## Why

Ben (2026-11-13, in chat) asked for a spike on Agentforce Coworker: he sees it as a standalone app, tab and SKU, and "there are some things we get for free with coworker that we'd have to build". He asked whether Coworker can be called from our custom components and whether we can build our own UI around it. The answer decides how much of the FR2 build (panel, rail, history, voice, write actions, cards) is worth building against adopting.

## Done when

- Read first, because the repo has already proved much of what this page compares against: docs/plans/feature-revision-2.md (the ledger, and row F83: the agent is not a way in), docs/plans/fr2-design.md ('Operating principles'), docs/research/agent-api.md, docs/research/salesforce-mcp.md, docs/research/fr2-standard-limits.md (BE-32: what the standard Agentforce chat does to a layout and how slow an agent turn is), docs/research/fr2-surfaces-spike.md (OPS-29), docs/research/fr2-actions-spike.md (BE-22), docs/research/fr2-explorer-scale.md (BE-31) and the README. Load the skill salesforce-development:platform-capability-search first
- **Sourcing rule:** a capability counts as Coworker's only if the source names Agentforce Coworker. General Agentforce features (custom Lightning types, the Agent API, the beta microfrontend embed, Agent Script, MCP) are labelled 'general Agentforce, not confirmed for Coworker' unless a Coworker source says they apply. Prefer Salesforce's own pages (the product page, Help, developer docs, release notes, the pricing page, press releases); mark every third-party source 'secondary'. If a Salesforce site refuses an automated fetch, say so and mark the figure 'unverified (search summary)'. Give each source its title, its URL without a query string, and the date read (2026-11-13 or later). Date every licence, price and availability fact, because they change
- **What Coworker is:** its surfaces (the app, the tab, Slack, Teams, desktop, mobile), how it is licensed and enabled, which editions and orgs can have it (say whether a Developer Edition can), what it depends on (Data 360, indexing, Flex Credits), what it indexes and searches, and whose access its answers run under (sharing, field-level security)
- **Three separate answers, each one of yes, no or undocumented, each with its source:** (1) Headless call: can our own LWC or Apex send Coworker a message and get its answer, so our UI sits on Coworker's engine (an API, a Connect or Apex class, an invocable, an LWC module). (2) Embed: can Coworker's own UI be placed inside our page, panel or utility item, opened from our hotkey with the record as context, or themed with a brand. (3) Extend: can our Apex actions (the summary, the explorer, the BE-22 draft and commit pair), our MCP door and our cards run inside Coworker's UI, and what it takes (custom actions, skills, MCP servers, custom Lightning types). 'Undocumented' is a valid answer; never turn silence into yes or no
- **Feature map:** one row for each thing Customer Summary has built or plans in FR2 (the sourced account summary, the ask-anything explorer with drill-down, conversation history a rep can return to, customer outcomes and sentiment, voice input, write actions with draft, Confirm and Undo, rich cards, the Cmd/Ctrl-K compact window, the rail, brand theming, the MCP door, user-mode access with no stack traces, the model seam and prompt files). Each row says: free with Coworker, partly covered or not covered, with the source, and what we would lose or have to rebuild by adopting it. Add the rows that go the other way: what Coworker has that we have not planned
- **Read-only check of agent-probe (no org-live lock, no Approvals row needed):** with `-o agent-probe` on every `sf` command, using queries, describes and metadata lists only, record whether a Coworker app, tab, permission set, permission set licence, agent (BotDefinition) or Setup entry exists there. Print names and counts only, no Ids. If an agent record exists, say whether it is one the Agent API path in docs/research/agent-api.md could open a session against, from its type and status alone: do not open a session. If nothing exists, the page says so and the org part stops there. Save the output as spikes/coworker/results/inventory.jsonl
- **Never, in this card:** enable Coworker or any Setup feature, assign a licence or permission set, accept terms, send Coworker or any agent a message, open an agent session, deploy, publish, activate, create or change a record, create a user, sign in or out, or contact Salesforce. Never touch `experimental` or use it as a Dev Hub. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file. No client or customer names from outside the public sources
- **Ledger F83:** a headless call to Coworker makes an agent the way in, which F83 ruled out and BE-32 measured as slow. State that plainly as a decision for Ben. Do not recommend around it and do not treat F83 as settled either way
- docs/research/fr2-coworker-spike.md gives, in this order: the answer to Ben's two questions in five lines; what Coworker is; the three answers; the feature map; the agent-probe check; two or three options (for example: stay custom, Coworker as a surface with our engine plugged in, both) with what each costs, what it drops from the FR2 plan and which queued cards it would change; a recommendation; what stays unproven; a 'For Ben' list of every step that needs his go (enabling Coworker, a licence, accepting terms, a live message, a prototype deploy) with what each would prove; and proposed follow-up cards (title, scope, the done-when in three lines). The brain cuts cards from that list
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken; run it on the committed tree). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt.

- Attempt 1 (87c1100): 26 confirmed, 0 refuted, 9 unverifiable. Every unverifiable row is a fact from a live Salesforce web page, or a fetch event, that the reviewer could not re-read. The repo facts, the ledger figures, the BE-32 timings and the inventory output were all checked against files.

The brain read the whole page and the inventory script. Findings:
- Both of Ben's questions come back undocumented. No source names an API, Connect class, invocable or LWC module that sends Coworker a message from inside the org, and no source covers placing Coworker's UI in our page, opening it from our hotkey or theming it.
- The one programmatic door Salesforce names is the Coworker MCP server, for outside clients such as Claude and ChatGPT. Whether Apex in the same org can be its client is undocumented.
- Our actions reach Coworker only through an agent (`Customer_Summary`). Ledger F83 ruled out the agent as a way in, and reopening it for Coworker is Ben's decision.
- Free with Coworker: history, Teams, iOS and desktop apps, search over Slack, Google and Microsoft 365, Skills, and record updates with Confirm. Not covered: the fixed sourced summary, outcomes and sentiment, the hotkey window, the rail and the model seam. Voice, brand theming and Undo are undocumented.
- Recommendation: stay custom (option A) while F83 stands; if Ben reopens F83, add Coworker as an extra door (option C), not as the surface (option B).
- agent-probe holds nothing Coworker: 0 permission sets, groups, licences, apps, tabs or metadata types. The four `Coworker*` sharing objects look like platform schema and do not show Coworker is on. Whether Setup offers Coworker there cannot be read by query.

Org: read-only. The inventory script runs queries and metadata lists only, each with `-o agent-probe`. Nothing was enabled, assigned, deployed, published or sent.

Disclosed and accepted:
- "Read" means a fetch tool's reading of the page, not the raw page. Exact text was asked for only on the pricing page and the Trailhead unit.
- The Coworker developer guide refused every fetch (403), so every fact from it is a search-engine summary and is marked unverified. The Admins blog was not used.
- The licence and price ($50 per user per month, 30 MB of indexing) are as the pricing page read on 2026-11-13.

Still open:
- Beta or GA in Lightning: the sources conflict.
- Whether an ordinary Developer Edition can turn Coworker on.
- Whether Coworker hands off to a custom Employee agent built in Agent Script, how faithfully it relays the reply, and how long a turn takes.
- Whether a delegated agent's custom Lightning type renders in Coworker.
- The page's nine "For Ben" steps each need Ben's go; none was taken. Its five proposed follow-ups are not cut.

Privacy grep over the full diff (473 added lines): 0 hits.
