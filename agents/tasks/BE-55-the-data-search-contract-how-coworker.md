---
id: BE-55
title: The data search contract: how Coworker and our panel find CRM data, measured on 8 fixed questions with an answer key, plus a guarantee table
domain: backend
tier: standard
status: queued
scope: [docs/research/coworker-data-search.md, spikes/coworker/search/**, spikes/coworker/results/search.jsonl]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json, docs/research/fr2-coworker-spike.md, docs/research/coworker-calls-our-agent.md, docs/research/custom-ui-calls-agent.md, spikes/agent-door/**, spikes/coworker/results/delegation-2.jsonl, docs/assets/**]
resources: [chrome-connect]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

Ben wants to guarantee how the search functionality for data works before the remaining Coworker and panel cards are fixed. OPS-63 showed Coworker's tables were whole on two questions but slow and label-free, and nobody has written down which search method, index, objects, fields, record access and freshness Coworker uses, or how that compares with our panel's explore. This card measures both against an answer key and says what is guaranteed, documented or unknown.

## Done when

- Guard first, before any org step: compare `sf org display -o connect-24h --json` and `-o agent-probe --json` result.id and result.username and print only SAME or DIFFERENT for each; stop and hand back if either is SAME. Work only in connect-24h.
- docs/research/coworker-data-search.md explains, citing a Salesforce doc for each claim (help pages read in a Chrome tab; plain fetches return 403; a Sources section with the date read): which search methods Coworker uses over CRM data (keyword or SOSL search, semantic or vector retrieval, SOQL-like queries, record-page context), what index backs each and how it is built, which objects and fields are searchable and how that is configured, whether results respect the running user's record sharing and field-level security, and how fresh the index is.
- spikes/coworker/search/questions.md fixes 8 questions about seed data on or around the Edge Communications account (at least: one count, one list with a filter, one date range, one cross-object, one free-text match in a description or subject, one field the user cannot see or a record outside sharing if the seed allows, and two the panel already answers). spikes/coworker/search/answer-key.soql holds the read-only SOQL that gives each answer, and the page states each expected answer as counts or labels, never record Ids.
- Each question runs once in a new Coworker chat and once through our panel's explore path called read-only from anonymous Apex (no DML). spikes/coworker/results/search.jsonl has one row per run: question id, door (coworker or panel), correct true/false/partial, rows expected and returned, seconds, and a short note. No record Ids, session Ids, usernames or hostnames.
- Freshness test: change one non-key field on one seed record (for example a Case subject or an Opportunity next step), ask Coworker the matching question at about 0, 5 and 15 minutes, record when the new value appears, then revert the field to its original value and confirm the revert by query. The change and revert are listed in an Undo section.
- A guarantee table: one row per property (methods, objects, fields, sharing, FLS, freshness, completeness on lists, latency), with columns Coworker and panel, each cell marked measured, documented or unknown plus the evidence. A Proposed regression tests section names the checks a later card could automate, with the question ids they reuse.
- Rules: no credentials, sign-ins or user creation; the only DML is the single freshness edit and its revert; a step refused by the permission check is recorded and not worked around; no org Ids, record Ids, usernames, emails, hostnames or query-string URLs in committed files.
- Gate passes: unit tests and bash scripts/check-docs.sh with 0 broken links.
