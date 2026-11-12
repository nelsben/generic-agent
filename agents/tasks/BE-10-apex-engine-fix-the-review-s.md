---
id: BE-10
title: Apex engine: fix the review's top six correctness and access findings, and add multi-request and bulk tests
domain: backend
tier: frontier
tier_reason: transaction-order and sharing fixes across the engine; subtle governor and security behaviour
status: merged
fixes: []
scope: [force-app/main/default/classes/AccountBrief*.cls, force-app/main/default/classes/AccountBrief*.cls-meta.xml, force-app/main/default/classes/DataExplorer*.cls, force-app/main/default/classes/DataExplorer*.cls-meta.xml, force-app/main/default/classes/Explore*.cls, force-app/main/default/classes/Explore*.cls-meta.xml]
forbid: [force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/lwc/**, force-app/main/default/permissionsets/**, force-app/main/default/flexipages/**, docs/**, reference/**, agents/**, .chassis-delegation.json, tests/**, scripts/**]
red_test: the new Apex tests (all-ERROR brief, restricted-user Task, three-request invocation, aggregate cap, one-query resolver, turn-cap result sets, 251-record bulk) fail on main and pass after, via bash scripts/validate-org.sh
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

The Apex peer review (docs/reviews/apex-review.md, merged in PR #21) found six should-fix defects in the engine. Among them: a brief where every section fails is reported as EMPTY; the Activity section reads Task in SYSTEM_MODE; and an invocation carrying several requests breaks on a callout after DML. No test sends more than one request or more than 251 records, which is how these slipped through. This card fixes those six and adds the missing tests. The review's other findings stay with the Apex hygiene card already in corrective plan step 3.

## Done when

- Read docs/reviews/apex-review.md fully first; findings 1-6 and the Tests section are this card's work. Read the salesforce-development skills platform-apex-generate, platform-apex-test-generate and platform-soql-query (load them with the Skill tool where available, else read SKILL.md and the references it names under ~/.claude/plugins/cache/salesforce/salesforce-development/<version>/skills/)
- Finding 1 is fixed: when every requested section returns ERROR, AccountBrief.run reports ERROR with the fixed ERROR text, not EMPTY. A test proves it
- Finding 2 is fixed: the Activity section reads Task in USER_MODE like the other sections, or the review's justified alternative if user mode cannot work for Task. Explain the choice in a code comment and in your hand-back. A test running as a restricted user (System.runAs) proves a Task the user cannot see is not in the brief
- Finding 3 is fixed: an invocation of AccountBriefGetAction with several requests no longer makes a callout after DML in the same transaction. Fix it by deferring every memory write until after all model callouts in the invocation, not by making requests asynchronous. A test sends three requests in one invocation, with the model callout mocked as the existing tests do, and asserts three answers
- Finding 4 is fixed: every aggregate query the explorer builds carries a row cap, so no generated query can exceed the 50,000-row limit. A test proves the cap is applied
- Finding 5 is fixed: the resolver looks up all pasted Ids in one query, not one query per Id. A test with more Ids than the old loop could afford asserts one SOQL query is used (Limits.getQueries)
- Finding 6 is fixed: when the explorer hits its turn cap, the result sets it already has reach the action output with a note that the cap was hit, not only ERROR text. A test proves it
- There is a bulk test that runs a brief over an account with at least 251 related records in the largest section, and it stays within governor limits
- Status-based action responses stay as they are (a deliberate difference recorded in docs/ARCHITECTURE.md). No invocable signature, label or description changes, because the agent's bindings depend on them. New tests use Assert.* (not System.assert*)
- Gates pass: `python3 -m unittest discover -s tests` and `bash scripts/validate-org.sh` (check-only deploy plus specified tests in org `experimental`). Run Python with PYTHONDONTWRITEBYTECODE=1 and leave no tests/__pycache__/. `git status --short` is empty when you report
- Hard limits: no real deploy, only check-only. Do not touch the agent, the panel controller or the LWC. Do not install plugins, do not use the Chrome browser tools, and never run all local tests in the org. A plugin hook may refuse a raw command or suggest a plugin install: load the named skill and retry; never install a plugin

## Review

Sonnet review, attempt 1 at e6c074b: 19 confirmed, 0 refuted, 4 unverifiable. Deliberate deviation: aggregates whose only function is COUNT(Id) skip the 10,000-row pre-count (measured: they cost 1 row per result row), so "how many X" still works on large objects. Open: about 15 queries per brief, so many requests in one invocation could reach the 100-query limit (three tested); recordAll is all-or-none (caught).
