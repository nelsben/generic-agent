---
id: OPS-13
title: Agent review: the Account_Brief Agent Script agent, its test spec and its publish workflow, in docs/reviews/agent-review.md
domain: ops
tier: frontier
tier_reason: judgement-heavy review across a whole layer; a missed defect ships in a baseline others copy
status: merged
scope: [docs/reviews/agent-review.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**, docs/plans/**, docs/ARCHITECTURE.md]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

generic-agent is meant to be a gold-plated Agentforce baseline that gets passed around, and it was built from memory before Salesforce's own skills were installed. Before the roadmap continues, each layer gets an independent review against those skills so defects are found now. The review does not replace docs/plans/corrective-plan.md; it feeds it.

## Done when

- Review only. Change nothing but your lane's write-up. Do not fix code, do not deploy, publish, activate or deactivate anything, do not install plugins, do not use the Chrome browser tools. Read docs/ARCHITECTURE.md and <repo>/docs/plans/corrective-plan.md first (absolute path: the plan is not committed yet, so it is absent from your worktree) so you know the intent and what is already planned
- You are a second pair of eyes, not the author: do not assume the code is right because tests pass. Read every file in your lane fully. For each finding give file and line, what is wrong, a concrete failure scenario (input or state, then the wrong result), severity (blocker, should-fix, nit) and the fix you would make in one or two lines. Mark each finding verified (you read the code and can show the failure path) or suspected (plausible, not proven). Do not pad: a real short list beats a long speculative one
- Use the installed Salesforce skills as the standard and say which skill each finding rests on. Load skills with the Skill tool where available; if it is not, read the skill files under ~/.claude/plugins/cache/salesforce/<plugin>/<version>/skills/<skill>/ (SKILL.md and the references it names). Where a skill's rule conflicts with a deliberate choice recorded in docs/ARCHITECTURE.md (Apex only, no Flows; no prompt templates; status-based action responses instead of isSuccess/errorMessage), report it under 'Deliberate differences' with your opinion, not as a defect
- A plugin hook may refuse a raw `sf data query`, metadata retrieve, Apex test run or manifest command, or a shell command containing certain keywords, and suggest a skill or a plugin install. Load the named skill and retry; never install a plugin. Org access is read-only and limited to the org alias `experimental`; never run all local tests there
- Also list what the corrective plan already covers so the brain can dedupe: tag each finding 'new' or 'already planned (plan section N)'
- Write-up shape: a 5-10 line plain summary with a verdict (sound, sound with fixes, or needs rework), then findings ordered most severe first, then deliberate differences, then what you did not review and why. Under 200 lines. No client names, no content from reference/, no org Id, user Id or email. Gate passes: test. Commit your write-up, do not push
- Lane: force-app/main/default/aiAuthoringBundles/Account_Brief (script and bundle meta) on main, the same file on branch agent/backend/BE-8 (worktree ../generic-agent-BE-8, finished but unmerged; review the diff as the candidate next version), tests/agent/Account_Brief-testSpec.yaml on both, tests/test_agent_bundle.py, scripts/validate-org.sh, and the three invocable action classes the agent calls (read only, for the contract). Also read docs/research/agent-publish-failure.md and docs/research/salesforce-skills.md. Skills: agentforce-adlc agentforce-generate (its audit, health-check and common-pitfall review), agentforce-test, agentforce-architecture-analyze
- Run only read-only checks: the skill's local compile if its script runs on this machine (python3 is 3.15, python3.12 is also installed), and `sf agent validate authoring-bundle --json --api-name Account_Brief -o experimental`. Do not run preview, publish, activate, deactivate or `sf agent test create`. Quote the results
- Cover at least: routing (does every kind of message reach the right subagent, including a named account with a narrow question, a pronoun follow-up, a question naming no account, off-topic and ambiguous or duplicate account names), instructions that the model can ignore versus deterministic logic in the script, variable use and state between turns, action input and output bindings against the Apex signatures, whether every action has an outputs block, what the user sees when an action fails, guardrails and off-topic handling, and anything in the script that matches the skill's listed causes of an 'Internal Error' on publish
- Test spec: do the 8 cases cover each routing branch, are the expectations checkable, is multi-turn covered, and is its location right. Workflow: compare how this repo validates and publishes with the lifecycle the skill prescribes, and say whether BE-8 is safe to publish as the next version or needs changes first
- State plainly which of your conclusions rest on reading alone, since nothing was previewed or run live

## Review

Attempt 1 reviewed by Sonnet: 23 confirmed, 3 refuted (a wrong line number, an overstated required-flag match, a wrong skill sub-reference), 7 unverifiable. The worker fixed all three in attempt 2 and reconciled findings 1 and 4. Attempt 2 reviewed by Sonnet at 5fa349e: 11 confirmed, 0 refuted, 2 unverifiable (command history, and an untracked __pycache__ recreated by the gate run). Verdict sound with fixes; BE-8 not ready to publish. Blocker for BE-8: after a brief, Explore is bound to the briefed account, so org-wide questions may be scoped to it (suspected; the code path is verified). Should-fix: BE-8 step 6 may let the reply stop at "Resolved: <name>"; subagents have no reclassify transition; a failed resolve may leave get_brief available with no account; the test spec lacks AMBIGUOUS and multi-turn cases. The worker ran agentforce-architecture-analyze, which was outside the allowed checks; it stopped at auth preflight and nothing reached the org. sf 2.130.9 is first on PATH, ahead of 2.157.8.
