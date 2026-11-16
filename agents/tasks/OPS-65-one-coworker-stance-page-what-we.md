---
id: OPS-65
title: One Coworker stance page: what we tried, what the docs say, what follows, and Coworker tabled in the plan with next steps back on the generic agent
domain: ops
tier: standard
status: blocked
blocked_by: [OPS-64]
scope: [docs/research/coworker-stance.md, docs/research/fr2-coworker-spike.md, docs/plans/gtm-burn-plan.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/patterns/**, README.md, e2e/**, mcp-door/**, reference/**, spikes/**, docs/assets/**, .chassis-delegation.json]
red_test: none
gate: test
budget: 2-attempts
spend: 6
---
## Why

Ben is tabling Coworker (2026-11-15) and wants one page in the repo that states our stance, so a later return to Coworker starts from findings rather than from scratch. The findings are spread over six cards and three research pages. The plan also needs to say Coworker is tabled and point the next steps back at the generic agent's own experience and connectivity work, in agent-probe.

## Done when

- Docs only. No org is touched, no browser is opened and nothing new is measured: every number and doc claim comes from pages and result files already in the repo (docs/research/fr2-coworker-spike.md, coworker-calls-our-agent.md, custom-ui-calls-agent.md, fresh-org-run.md, spikes/coworker/results/*.jsonl, spikes/coworker/delegation-notes.md).
- docs/research/coworker-stance.md opens with the stance in under 120 words, as Ben put it on 2026-11-15: Coworker is a good fit when Salesforce is the source of truth and Coworker is the primary agent embedded in the CRM; it gives no option to work with other tools, to be driven from a custom UI, or to be used inline from our own app page; so for this repo's scope Coworker is tabled and the build returns to the generic agent's own experience and connectivity features. Each of the three 'no option' claims is then backed by a measured result or a cited doc, and where the evidence is only 'not found' or 'not tried' the page says that and does not say 'impossible'.
- A 'What we tried' table, one row per attempt, with card id, what was tried, result with its number, and where the evidence lives: OPS-63 (0 of 9 delegated; explore tables whole at 30 of 30 and 47 of 47; 31 to 33 s on the 47-row answer; 0 of 6 labels), BE-52 and BE-53 (the three headless doors), FE-24 and FE-28 (our card in Coworker: renderer rejected, no turn ran), OPS-64 (docs on how Coworker picks agents, plus whatever its live turns measured, read from the merged page and delegation-2.jsonl), BE-56 (custom UI doors; the standard-panel LWC API returns no reply text), OPS-62 (what turning Coworker on needed in a new org, licences included).
- A 'What the docs say' section restating the cited claims already in the repo with their source labels and read dates (reuse the existing Sources entries by link to the pages that hold them; add no new uncited claim), and a 'Not tried, and why' list that includes BE-55 (the data search contract, parked when Coworker was tabled) and the Coworker MCP server.
- A 'When to come back' section: the concrete changes that would reopen this (for example a documented API or component to call Coworker's Ask, a way to register an agent with Coworker, custom card rendering accepted, an MCP door we can sign in to), and for each the first card to cut. Ledger item F83 is named as still Ben's decision, recorded as tabled, not decided.
- docs/research/fr2-coworker-spike.md gains one line at the top pointing to the stance page as the summary. docs/plans/gtm-burn-plan.md gains a short dated 'Coworker tabled (2026-11-15)' entry linking the stance page, and a 'Next, back on the generic agent' list that only reorders or points at items the plan and agents/tasks already hold (name them by id), states that work returns to the agent-probe org, and that connect-24h expires about 2026-11-16 so nothing in it is relied on. If the plan file's structure makes a placement unclear, add the entry as a new section at the end and say so in the report.
- No client names, org Ids, record Ids, usernames, emails, hostnames or query-string URLs anywhere. Plain, short sentences; the page reads top to bottom for someone who has seen none of the cards.
- Gate passes: unit tests and bash scripts/check-docs.sh with 0 broken links.
