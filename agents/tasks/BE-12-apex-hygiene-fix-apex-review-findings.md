---
id: BE-12
title: Apex hygiene: fix Apex review findings 7-18, move AccountBriefMemoryTest to Assert.*, describe both permission sets
domain: backend
tier: standard
tier_reason: twelve bounded review findings with named lines; plan said economy but the race and sharing fixes need more than haiku
status: merged
fixes: []
scope: [force-app/main/default/classes/**, force-app/main/default/permissionsets/**, scripts/apex-scan.sh]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/lwc/**, force-app/main/default/flexipages/**, e2e/**, tests/**, docs/**, reference/**, agents/**, .chassis-delegation.json, scripts/validate-org.sh, scripts/agent-check.sh, package.json, package-lock.json, playwright.config.js]
red_test: the new Apex tests for findings 7, 8, 11, 13, 14 and 15 fail on main and pass after, via bash scripts/validate-org.sh
gate: test, org
budget: 2-attempts
spend: 15
---
## Why

The Apex peer review (docs/reviews/apex-review.md) left findings 7-18 after BE-10 fixed 1-6. They cover swallowed exceptions, a dead Flow action, a memory-write race, an over-broad permission set and smaller contract gaps. They need fixing before the engine is exposed through MCP and to non-admin users (corrective plan steps 3, 4 and 6).

## Done when

- Read docs/reviews/apex-review.md fully first; findings 7-18 and the Permission sets section are this card's work (1-6 are done, see agents/tasks/BE-10-*.md Review). Read the salesforce-development skills platform-apex-generate, platform-apex-test-generate, platform-soql-query and platform-permission-set-generate (load with the Skill tool where available, else read SKILL.md under ~/.claude/plugins/cache/salesforce/salesforce-development/<version>/skills/)
- Finding 7: every section query states its access mode explicitly (USER_MODE unless the review's justified exception applies), and each catch block keeps the cause: the exception type reaches the section's ERROR result or a debug log line, never silently dropped. A test proves a section's error carries its cause
- Finding 8: a date-only value compared with a Datetime field is converted in the running user's time zone, not midnight GMT. A test proves it
- Finding 9: Account_Brief_Data_Access grants only what the engine actually uses. List in the hand-back each grant removed and why it is unused. Do not remove access the panel controller, the agent actions or AccountBriefMemory need
- Finding 10: the dead recordFromFlow invocable on AccountBriefMemory is removed with its tests; no other invocable is removed
- Finding 11: memory writes no longer race (pick upsert on a unique key or FOR UPDATE, and say which in the hand-back), and stored rows per user and account are capped. Tests prove both
- Finding 12: both permission sets have a one-sentence <description>
- Findings 13-14: the provider seam caps output length and turns every model error into the seam's own error result; prompts are cached so one transaction loads each prompt at most once. Tests prove both
- Finding 15: AccountBriefPanelController.drill catches every exception and returns a fixed user-facing message, not the raw exception text. A test proves it
- Finding 16: the missing null guard is added, and callout=true is set on the invocables that make callouts
- Finding 17: the resolver's partial-name search avoids the leading wildcard where the review says it can; if a leading wildcard must stay for a case, say why in a code comment
- Finding 18: the small hygiene items are done, or each skipped one is named in the hand-back with a reason
- AccountBriefMemoryTest uses Assert.* everywhere, with no System.assert*. Every new test uses Assert.*
- Decided, not left to you: no TestDataFactory class in this card; status-based action responses stay (a deliberate difference); no invocable label, description, input or output name changes, because the agent's bindings depend on them; leave the resolver's NOT_FOUND wording alone (BE-11 is changing the agent that relays it)
- Code Analyzer: if `sf code-analyzer run --help` already works, add scripts/apex-scan.sh that runs it on force-app/main/default/classes and prints the violations, and report its findings in the hand-back without fixing beyond findings 7-18. If the command is not installed, add nothing and say so. Never install a plugin
- Gates pass: `python3 -m unittest discover -s tests` and `bash scripts/validate-org.sh` (check-only deploy plus specified tests in org experimental). Run Python with PYTHONDONTWRITEBYTECODE=1 and leave no tests/__pycache__/. `git status --short` is empty when you report
- Hard limits: no real deploy, only check-only. Do not touch the agent bundle, the LWC, e2e/ or the Python tests. Do not use the Chrome browser tools, never run all local tests in the org, never create users or records in the org. A plugin hook may refuse a raw command or suggest a plugin install: load the named skill and retry; never install a plugin

## Review

Independent sonnet diff review at 6f33ee9 (read-only): no blockers. Should-fix, left for a follow-up card: a date-only value on a Datetime field with >, <=, or IN is bound at local midnight, so "through March 31" undercounts (ExplorePlan, ExploreQuery). Notes: any QueryException in the resolver or visibleAccount reads as NOT_FOUND, including a timeout; OpportunityContactRole and Who.Name are now USER_MODE, so a user without access loses the whole section as ERROR; a FOR UPDATE lock timeout drops the memory turn (logged); the AccountBriefMemory class grant is no longer needed. Clean: permission set entry points, memory retry and cap, cause never reaches the user or prompts, output cap, recordFromFlow removal, invocable names. The narrowed permission set is not yet tested as a real non-admin user (FE-5).
