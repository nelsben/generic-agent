---
id: BE-31
title: FR2: explorer discovery — what it takes for the ask-anything explorer to reach any object and any combination of data safely; measured options, a recommendation and the build cards it would need
domain: backend
tier: frontier
tier_reason: design research across security, governor limits and model behaviour, with measurements in a production-classified org
status: queued
fixes: []
scope: [spikes/explorer-scale/**, docs/research/fr2-explorer-scale.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (discovery): the evidence is docs/research/fr2-explorer-scale.md with its measurements and spikes/explorer-scale/
gate: test
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 02. Follow-ups must scale "to any object, any combination of data" so customers are not in "an endless scale of agentic capability scaling for something as simple as a follow-up question". He asked to "make sure cards are cut for that discovery". Today the explorer has an 8-object curated catalog, AND-only filters, one-level parent paths, no filters on long text and up to 5 model calls a question. Covers ledger rows F55, F58 and F59 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: spikes in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back
- Read first: docs/plans/feature-revision-2.md (rows F54 to F59), docs/plans/fr2-design.md ('Operating principles'), docs/patterns/02-ask-anything-explorer.md, docs/patterns/07-trust-access-and-failure.md (and principle 5 in docs/plans/fr2-design.md), the Explore* and DataExplorer classes and AgentPrompt_Explore. Load the skills salesforce-development:platform-soql-query, salesforce-development:platform-apex-generate and salesforce-development:platform-capability-search first
- Answer each question with evidence, not opinion:
  1. **Catalog:** curated list vs a describe-driven catalog with an admin allow and deny list (for example custom metadata), including custom and industry objects. What a user must never reach (encrypted, sensitive and system fields), and how the catalog stays small enough for the prompt as objects grow (for example sending only the objects relevant to the question).
  2. **Combinations:** OR and grouped filters, two-level parent paths, filters on long-text fields (which SOQL cannot filter directly), child subqueries and semi-joins ("accounts with an open case and no activity in 30 days"), and multi-step questions that chain queries. How each is still built from catalog paths with bound values only.
  3. **Limits:** queries, rows, CPU, heap and callout time per question as the catalog grows. Model calls and tokens per question.
  4. **Honest comparison:** what Data Cloud, the standard Agentforce data actions and a report would do for the same questions, from public Salesforce docs, without claiming parity.
- Measure: a prototype in spikes/explorer-scale/ that runs as anonymous Apex or check-only in agent-probe (no deploy, no data change). Run a set of 30 questions across single objects, parents, children, OR, semi-joins and chained steps, on the current explorer and the prototype. Record pass or fail, model calls and limits used, printing no names and no Ids
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-explorer-scale.md gives the results, a recommendation, the risks, and a list of proposed build cards (title, scope, the done-when in three lines). The brain cuts the cards from that list. Never deploy, publish or activate, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
