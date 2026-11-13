---
id: BE-26
title: FR2: conversation history — store each user's turns per account on the renamed session object, list past sessions for an account, and reopen one; the explorer's turns kept as well as the summary's; access re-checked on read; visibility own-only until Ben decides. Customer outcomes that outlive a conversation are BE-35
domain: backend
tier: frontier
tier_reason: changes a live object and the memory path every surface uses; a sharing decision sits inside it
status: merged
fixes: []
scope: [force-app/main/default/objects/Customer_Summary_Session__c/**, force-app/main/default/classes/CustomerSummaryHistory*.cls, force-app/main/default/classes/CustomerSummaryHistory*.cls-meta.xml, force-app/main/default/classes/CustomerSummaryMemory*.cls, force-app/main/default/classes/CustomerSummaryMemory*.cls-meta.xml, force-app/main/default/classes/CustomerSummaryPanelController.cls, force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls, force-app/main/default/permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml, docs/research/fr2-conversation-history.md, tests/test_permission_sets.py]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new CustomerSummaryHistoryTest fails on main (the class does not exist) and passes after
gate: test, jest, org
budget: 2-attempts
spend: 15
---
## Why

Feature revision 2 (FR2): every surface keeps conversation history, and the rail "show[s] that this customer has had this interaction through history". Who may see another rep's history is open (Q7); the default is own-only, built so a later setting can widen it. Ben's chapter notes on pattern 05 split memory in two: the conversation (this card) and customer outcomes that "persist against that customer" (BE-35). This card also closes two of pattern 05's limits: only the summary is remembered, not the explorer's turns, and memory outlives access (N6 in docs/reviews/apex-review-2.md). Covers ledger rows F19 (history), F32, F78 and F80 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F19, F32 and F74 to F81), docs/plans/fr2-design.md, docs/patterns/05-conversation-memory.md, docs/research/fr2-agent-memory.md (BE-34; follow its recommendation and say where you differ), docs/reviews/apex-review-2.md (N6), the session object (Customer_Summary_Session__c after BE-23) and CustomerSummaryMemory. Load the skills salesforce-development:platform-custom-field-generate, salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- Extend the existing session object rather than adding a new one: each session belongs to one user and one account, has a title (the first question, trimmed to 80 characters), a started and last-active time, a turn count and the turns JSON the memory class already keeps (keep its ring-buffer limit; say in the doc what it is). Add only the fields that are missing; keep the field-level security in the Customer_Summary data-access permission set
- Apex: CustomerSummaryHistory with @AuraEnabled methods listSessions(Id accountId, Integer limitSize) (newest first, default 10, max 50; title, last active, turn count, no turns) and getSession(Id sessionId) (turns in order). Both run in user mode and return only the running user's sessions (OwnerId = current user) by default; the filter sits in one place with a comment naming F32 so a later brand or permission setting can widen it. The memory writes stay in system context (reps have read-only access to the session object), marked `// system-context:` with that reason per BE-37 (ledger F87). The existing memory path keeps working: a new question continues the current session within its timeout, otherwise it starts a new one. **The explorer's turns are kept too:** its questions and answers are recorded in the session as the summary's are (today only the summary is), from the panel controller (the agent is not a way in, ledger F83), within the same ring-buffer limit. **Access re-checked on read (N6):** both methods return a session only while the running user can still read its account; a session for an account the user has lost is hidden, not deleted. The Customer_Summary data-access permission set grants the new class, and tests/test_permission_sets.py follows. Customer outcomes (summaries and actions that outlive the conversation) are BE-35's, not this card's
- Tests with Assert.* cover listing order and limits, the own-only filter (runAs a second user created in the test sees none of the first user's sessions), reopening a session, an explorer turn recorded and returned, a session hidden once its account is no longer readable, the session timeout starting a new session, and an account with no sessions
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Write docs/research/fr2-conversation-history.md: what is stored, for how long, who can see it and why (own-only; open question F32), the access re-check, and the governor cost. OPS-43 rewrites the pattern 05 page from it. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt (9d53ed9). The verifier found the report consistent; a reviewer then returned 21 confirmed, 0 refuted, 3 unverifiable. Every unverifiable row is an org fact or a gate the record did not show: the validate and quick deploy, the new Apex tests passing in the org, and the docs gate.

Approvals: F32/Q7 (who sees conversation history) is still open; this card builds the default, own-only, with the filter in one method so the answer changes one place.

Findings:
- Customer_Summary_Session__c gains Title__c (80 characters), Started__c and Turn_Count__c. The 10-turn ring limit stays.
- CustomerSummaryMemory keeps one session per rep and account. After 30 minutes idle the old row is re-keyed (key + '_' + its Id) and a new row takes the plain key; the last summary carries forward, so the rail's last-summary read keeps working. Turns carry a kind (summary or explorer); older rows are backfilled. Writes stay in system mode, each under a marker.
- New CustomerSummaryHistory, `with sharing`, every query WITH USER_MODE: listSessions (newest first, default 10, max 50, no turns) and getSession (turns in order; null when hidden). The own-only filter is one method naming F32. Account access is re-checked on every read; a session the user can no longer reach is hidden, never deleted.
- The panel's explore records an explorer turn only for an OK or EMPTY answer on an account; a failure there is logged and never breaks the answer.
- The data-access set grants the class and read-only access to the three new fields; the permission-set test follows.
- 8 history tests (including own-only with a second user given a manual share, so only the filter hides the row), plus memory and panel tests. docs/research/fr2-conversation-history.md says what is stored, for how long, who sees it and the governor cost.

Org: validate with RunLocalTests (376 tests, 0 failures) and quick deploy of this card's 20 components only, under the standing row. No live run, no user created in the org, nothing published.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook.
- The brain fast-forwarded the clean worktree to main before the worker started.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- The rail's last-summary date (CustomerSummaryContext) reads Last_Activity__c, which explorer turns and new sessions now move, so the date can show a later explorer turn. The amend added the path to scope, but the class is unchanged; a follow-up card fixes it.
- F32/Q7 stays Ben's: own-only is the default until he answers.

Privacy grep over the diff (921 added lines): 0 hits.
