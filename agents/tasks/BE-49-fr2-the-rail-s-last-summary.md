---
id: BE-49
title: FR2: the rail's last-summary date is the time of the user's last summary, not of their last explorer question or of a new empty session
domain: backend
tier: standard
tier_reason: a small fix across two known classes with a clear red test; one bounded choice named in the card
status: queued
fixes: [BE-26]
scope: [force-app/main/default/classes/CustomerSummaryContext.cls, force-app/main/default/classes/CustomerSummaryContextTest.cls, force-app/main/default/classes/CustomerSummaryMemory.cls, force-app/main/default/classes/CustomerSummaryMemoryTest.cls, force-app/main/default/objects/Customer_Summary_Session__c/fields/Last_Brief_At__c.field-meta.xml, force-app/main/default/permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml, tests/test_permission_sets.py, docs/research/fr2-rail-context.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/classes/CustomerSummaryPanelController*, force-app/main/default/classes/CustomerSummaryHistory*, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new CustomerSummaryContextTest cases (a later explorer turn; a timed-out session restarting) assert lastSummary's date stays the summary's time; they fail on main and pass after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

BE-25's CustomerSummaryContext sets lastSummary's date from the session row's Last_Activity__c. Since BE-26, an explorer turn and the start of a new session also move that field, so the rail can say "last summary: today" when the last summary was days ago. Found by BE-26's worker and confirmed by its reviewer (CustomerSummaryContext.cls, the summaryDate assignment).

## Done when

- Read first: docs/research/fr2-rail-context.md (BE-25), docs/research/fr2-conversation-history.md (BE-26), CustomerSummaryContext and CustomerSummaryMemory. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- lastSummary's date in CustomerSummaryContext.getContext is the time of the user's newest summary turn for the account. An explorer turn, or a new session that carries the last summary forward, does not change it. Choose how: read the newest summary turn's own time from the stored turns if each turn carries one, or else add a Last_Brief_At__c date/time field that CustomerSummaryMemory sets only when it records a summary and copies forward when it starts a new session. Say which in the hand-back and why
- If a field is added: it is read-only in Customer_Summary_Data_Access, tests/test_permission_sets.py names it, rows written before it existed fall back to Last_Activity__c, and the fallback is said in the doc
- CustomerSummaryContext keeps its query count at 8 or fewer, stays with sharing, and its reads stay WITH USER_MODE. Memory writes stay in system mode under their existing markers. Nothing else the context returns changes
- Red test: a new CustomerSummaryContextTest case records a summary, then an explorer turn later in time (and, separately, a session that times out and restarts), and asserts the date stays the summary's. It fails on main and passes after
- docs/research/fr2-rail-context.md says where the date comes from now
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, naming only this card's changed components (never all of force-app). No live run is needed. Never publish or activate an agent, never create a user in the org, never touch experimental. Wait for each org job in the foreground, in waits under 10 minutes; do not end the turn while a job runs
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
