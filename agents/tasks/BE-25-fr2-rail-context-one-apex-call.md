---
id: BE-25
title: FR2: rail context — one Apex call returns open deals, recent activity (with synced emails, calls and case comments), open cases and the last summary for an account, in user mode, fast enough to prefetch when the rail opens
domain: backend
tier: frontier
tier_reason: user-mode reads across six objects with a live deploy and timing in a production-classified org
status: blocked
blocked_by: [OPS-30, BE-37, BE-24]
fixes: []
scope: [force-app/main/default/classes/CustomerSummaryContext*.cls, force-app/main/default/classes/CustomerSummaryContext*.cls-meta.xml, force-app/main/default/permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml, docs/research/fr2-rail-context.md, tests/test_permission_sets.py]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new CustomerSummaryContextTest fails on main (the class does not exist) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 12
---
## Why

Feature revision 2 (FR2): the large right rail shows prefetched context so a seller or service rep can act quickly. Ben named open deals, recent activity, cases and the last brief, with recent engagement (emails, phone calls and case comments synced to Salesforce) under recent activity. Covers ledger row F29 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md, docs/patterns/01-route-gather-reduce.md, docs/patterns/07-trust-access-and-failure.md (and principle 5 in docs/plans/fr2-design.md) and the CustomerSummary*Section classes (open deals, activity, calls, cases), CustomerSummaryMemory and the session object. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate, salesforce-development:platform-soql-query and salesforce-development:platform-metadata-deploy first
- Apex: a CustomerSummaryContext class with one @AuraEnabled(cacheable=true) method getContext(Id accountId) returning a DTO with: openDeals (name, stage, amount, close date, up to 5, soonest close first), recentActivity (up to 10 newest across Tasks, Events, EmailMessage on the account and its contacts, call Tasks, and CaseComments on the account's cases; each with kind, subject or a 140-character excerpt, date and who), openCases (number, subject, status, priority, up to 5), and lastSummary (date and the first lines of the running user's own newest stored summary, or none). Reuse the existing section queries where they fit rather than writing new ones
- Every query runs in user mode (WITH USER_MODE or AccessLevel.USER_MODE), so a user sees only what they can already see; a missing object or field (for example no EmailMessage access) leaves that list empty instead of failing. No record Ids are shown to people, but the DTO keeps Ids so the rail can open records. One call stays within 8 SOQL queries
- Tests with Assert.* cover each list, ordering and limits, the empty account, an account with no access (runAs a minimum-access user created in the test), and the missing-object path. Class access goes in the Customer_Summary data-access permission set only
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1; call getContext once through anonymous Apex for a sample account and record the elapsed time and list sizes (no Ids, no names) in docs/research/fr2-rail-context.md. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
