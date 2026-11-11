---
id: OPS-11
title: Apex review: engine, actions, memory, explorer, tests and the two permission sets, in docs/reviews/apex-review.md
domain: ops
tier: frontier
tier_reason: judgement-heavy review across a whole layer; a missed defect ships in a baseline others copy
status: merged
scope: [docs/reviews/apex-review.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**, docs/plans/**, docs/ARCHITECTURE.md]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

generic-agent is meant to be a gold-plated Agentforce baseline that gets passed around, and it was built from memory before Salesforce's own skills were installed. Before the roadmap continues, each layer gets an independent review against those skills so defects are found now. The review does not replace docs/plans/corrective-plan.md; it feeds it.

## Done when

- Review only. Change nothing but your lane's write-up. Do not fix code, do not deploy, publish, activate or deactivate anything, do not install plugins, do not use the Chrome browser tools. Read docs/ARCHITECTURE.md and /Users/bennelsen/Documents/generic-agent/docs/plans/corrective-plan.md first (absolute path: the plan is not committed yet, so it is absent from your worktree) so you know the intent and what is already planned
- You are a second pair of eyes, not the author: do not assume the code is right because tests pass. Read every file in your lane fully. For each finding give file and line, what is wrong, a concrete failure scenario (input or state, then the wrong result), severity (blocker, should-fix, nit) and the fix you would make in one or two lines. Mark each finding verified (you read the code and can show the failure path) or suspected (plausible, not proven). Do not pad: a real short list beats a long speculative one
- Use the installed Salesforce skills as the standard and say which skill each finding rests on. Load skills with the Skill tool where available; if it is not, read the skill files under ~/.claude/plugins/cache/salesforce/<plugin>/<version>/skills/<skill>/ (SKILL.md and the references it names). Where a skill's rule conflicts with a deliberate choice recorded in docs/ARCHITECTURE.md (Apex only, no Flows; no prompt templates; status-based action responses instead of isSuccess/errorMessage), report it under 'Deliberate differences' with your opinion, not as a defect
- A plugin hook may refuse a raw `sf data query`, metadata retrieve, Apex test run or manifest command, or a shell command containing certain keywords, and suggest a skill or a plugin install. Load the named skill and retry; never install a plugin. Org access is read-only and limited to the org alias `experimental`; never run all local tests there
- Also list what the corrective plan already covers so the brain can dedupe: tag each finding 'new' or 'already planned (plan section N)'
- Write-up shape: a 5-10 line plain summary with a verdict (sound, sound with fixes, or needs rework), then findings ordered most severe first, then deliberate differences, then what you did not review and why. Under 200 lines. No client names, no content from reference/, no org Id, user Id or email. Gate passes: test. Commit your write-up, do not push
- Lane: every file in force-app/main/default/classes (production and test), force-app/main/default/objects, and force-app/main/default/permissionsets. Skills: salesforce-development platform-apex-generate (its review mode and scoring), platform-apex-test-generate, platform-soql-query, platform-permission-set-generate
- Cover at least: sharing and user-mode enforcement on every query and DML (CRUD and field security), SOQL injection in the data explorer's generated queries and the strength of its guards, bulk safety and governor limits (queries or DML in loops, callout and CPU limits across the gather step), the provider seam around the Models API (timeouts, error handling, what a failed or empty model reply does), invocable action contracts (labels, descriptions, input validation, what an agent sees on failure), the session memory object (one row per user and account, concurrent updates, growth), and null or empty handling
- Tests: do they assert behaviour or only coverage; negative and bulk cases; legacy System.assert* calls; test data built inline versus a factory; any test that depends on org data. Give the score from the skill's rubric if it has one and say how you applied it
- Permission sets: least privilege, missing descriptions, anything granted that the engine does not use, and whether a non-admin user holding both sets could actually run a brief (state verified or unverified)

## Review

Brain read the hand-back; a Sonnet reviewer checked it against f425b47: 26 claims confirmed, 0 refuted, 7 unverifiable (platform-limit behaviour, plan tags, Code Analyzer run). Verdict sound with fixes: 10 should-fix, 8 nits. Top items: all-ERROR brief reported as EMPTY; Activity section reads Task in SYSTEM_MODE; multi-request invocation breaks on callout after DML; uncapped aggregate rows; resolver SOQL per pasted Id; explorer drops result sets at the turn cap. Fixing the permission-set finding also requires changing tests/test_permission_sets.py.
