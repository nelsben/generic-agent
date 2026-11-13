---
id: BE-37
title: FR2: the trust rule as a test — every Apex class with sharing, every CRM read and write in an explicit access mode, and each system-context use named in the code with its reason, so no later card can quietly add one
domain: backend
tier: standard
tier_reason: a static check over every Apex class plus small, behaviour-preserving access-mode edits, deployed to a production-classified org
status: blocked
blocked_by: [OPS-30]
fixes: []
scope: [tests/test_trust_rule.py, force-app/main/default/classes/*.cls, docs/research/fr2-trust-rule.md]
forbid: [force-app/main/default/classes/*Test.cls, force-app/main/default/lwc/**, force-app/main/default/objects/**, force-app/main/default/permissionsets/**, force-app/main/default/permissionsetgroups/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_trust_rule.py fails on main (the session memory writes and the prompt-file read run in an implicit mode with no named reason) and passes after
gate: test, org
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 07: "making sure your agent runs in with sharing, except for things where it needs system context, like memory records, seems to make sense. I would align to that." Principle 5 in docs/plans/fr2-design.md states the rule; this card makes it a test, so every later card is held to it by the unit-test gate. Covers ledger row F87 in docs/plans/feature-revision-2.md, and the explicit-mode half of N11 in docs/reviews/apex-review-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F85 to F87 and the decision that trust is a principle), docs/plans/fr2-design.md (principle 5), docs/patterns/07-trust-access-and-failure.md, docs/reviews/apex-review-2.md (N11 and the notes on access modes) and tests/test_permission_sets.py (match its style). Load the skills salesforce-development:platform-apex-generate and salesforce-development:platform-metadata-deploy first
- **The marker:** a system-context use carries a comment `// system-context: <reason>` on the line above the class declaration, the statement, or the method that holds it, with a reason of at least five words that says why the user's own access is not enough (for example "a rep's own session rows; reps have read-only access to the object")
- **tests/test_trust_rule.py** reads every non-test class under force-app/main/default/classes/ and fails, naming file and line, when: a top-level class is not `with sharing` and has no marker; an inline query has neither `WITH USER_MODE` nor `WITH SYSTEM_MODE`; a Database.query, queryWithBinds, countQuery or getQueryLocator call passes no AccessLevel; a DML statement has neither `as user` nor `as system` (or, for Database methods, an AccessLevel); or anything in system mode has no marker covering it. Unit tests inside the file prove each rule against small inline Apex samples, so the parser is tested, not just run
- **Make the code pass with no change in behaviour,** except to move a read or write of CRM data to user mode where it was implicit. The product's own records (the session memory today) and the prompt-file read stay in system mode with a marker; the agent-definition query goes with FE-20 (if it is still there, mark it and say so). Every Apex test still passes
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-trust-rule.md lists every marker (class, method, reason), every statement whose mode changed and why, and how a later card adds an exception (the marker, plus a test proving the guard around it). OPS-45 builds its list of exceptions from this page and the markers. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
