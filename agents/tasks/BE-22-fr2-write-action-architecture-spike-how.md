---
id: BE-22
title: FR2: write-action architecture spike — how a request to create a task or update a record becomes a draft the user confirms, the same way from the panel and MCP
domain: backend
tier: frontier
tier_reason: architecture decision across panel, agent and MCP doors from live-org probes
status: merged
fixes: []
scope: [spikes/actions/**, docs/research/fr2-actions-spike.md]
forbid: [sfdx-project.json, tests/**, force-app/**, mcp-door/**, spikes/surface/**, spikes/rename/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none (spike: research page and optional throwaway spike package)
gate: test
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2) lets a seller create follow-ups and update records by voice or chat, with a draft and a Confirm before anything is written. The panel's own Apex router builds the draft (ledger F83: the agent is not a way in); this spike settles its cost, its latency and the class plan. Covers ledger rows F15, F16 and F18 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: spikes in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back
- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md (section 'Write actions'), docs/research/agent-api.md, docs/research/panel-agent-1.md (from BE-20), docs/patterns/04-model-provider-seam.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, and CustomerSummaryPanelController. Load the skills agentforce-adlc:agentforce-generate, salesforce-development:platform-apex-generate and salesforce-development:platform-apex-anonymous-run before running anything
- Answer, with evidence from agent-probe (anonymous Apex and sf agent preview only; no deploy to force-app): (1) to (3) are dropped (ledger F83: the agent is not a way in, so no action runs through it); (4) the cost and latency of an Apex router that classifies the request with the AgentLlm seam and builds the draft directly, without the agent
- Recommend one architecture for the six first actions (create task, create event, log a call, update contact, create case, update opportunity), stating how the panel and an MCP client each reach the same Apex service, where the draft is built, how Confirm commits it in user mode, and how the result is shown. Name the Apex classes and methods the build card should create
- Record the decision Ben has not made yet, without making it: Salesforce's Log a Call saves a completed Task, while Ben called it 'synonymous with create an event'. Describe both and what each looks like in the activity timeline
- Throwaway code, if any, lives in spikes/actions/ (inside the non-default 'spikes' package directory OPS-50 added; deploy it with --source-dir spikes/actions). Deploys of it to agent-probe use the standing approval (validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1). Never publish or activate an agent, run every write inside a savepoint and roll it back, never update an existing record, write no test class that reads org data, never sign in or out, never create a user, never touch experimental
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Write docs/research/fr2-actions-spike.md: the questions, the evidence, timings, the recommendation and the class and method plan. No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit. The page ends with an 'Undo' list of everything this card left in agent-probe and how to remove each item

## Review

Brain review (2026-11-13). Three attempts; the brain raised the budget from 2 to 3 for the last one (the brief records 3-attempts).

- Attempt 1 (6b4a56b): 18 confirmed, 5 refuted, 4 unverifiable. Refuted: the draft-step time (pooled with prebuilt drafts), "every draft run made 1 query", the draft JSON size, a proposed prompt rule the prompt already had, and "one agent turn takes 13 to 33 s" (that is the explore turn; a brief turn took 31 to 36 s).
- Attempt 2 (7cf461a): 43 confirmed, 1 refuted, 5 unverifiable. It fixed all five rows, committed the read-only inventory (results/inventory.jsonl), and scoped the CPU figure. Refuted: "1,509 characters, matching promptChars". That was one request's combined prompt.
- Attempt 3 (9ccbdc9): 17 confirmed, 0 refuted, 1 unverifiable. The system prompt is 1,384 characters, and with each request's user prompt 1,482 to 1,573. The reviewer rebuilt all 28 runs and matched every promptChars value.

Findings (agent-probe, anonymous Apex, every write rolled back):
- One Models API call per sentence picked the right action in 27 of 28 runs and got the date right in 10 of 10. The call took a median of 2.3 s, with about 956 tokens in and 76 out.
- The draft step took 78 to 194 ms (median 140) and made 0 DML.
- Confirm writes in user mode in a median of 0.09 to 0.30 s per action. Undo took about 0.08 s.
- A model call after DML in the same transaction throws CalloutException, so draft and Confirm are separate server calls.
- `commit` is reserved in Apex, so the method is `commitDraft`.
- With no contact named, the model still filled `contact` despite a prompt rule against it. The draft step's resolve check marked it unresolved and guessed nothing.
- Recommendation: a CustomerSummaryActions service (draft, draftFromText, commitDraft, undo). The panel reaches it through @AuraEnabled methods on CustomerSummaryPanelController, and MCP through a draft_action and commit_action pair.

Disclosed and accepted:
- The Method section says the prompt is "about 1,500 characters"; measured, it is about 1,460.
- Four commit runs, the first discarded after a key clash. The callout probe ran twice and the first inventory script was not committed. Only the kept runs are in git.
- Every run was as an admin, so no user-mode refusal was observed. The panel round trip was not measured.
- The verb pre-check is offline Python in run.py, checked only against the nine requests it was written from. It is not a held-out test.

Still open:
- Log a Call as a completed Task or an Event is Ben's decision (default Event). How each looks in the timeline is unverified.
- Whether MCP may write is Ben's decision; the two invocables wait for it.
- BE-27 needs CustomerSummaryPanelController in scope, commitDraft, and the two-request rule. It must also pin the pre-check with many more phrasings.

Privacy grep over the full diff: 0 hits. The results files hold counts, statuses, field names and picklist values only.
