---
id: OPS-12
title: LWC review: the accountBriefPanel component, its app and utility bar, in docs/reviews/lwc-review.md
domain: ops
tier: frontier
tier_reason: judgement-heavy review across a whole layer; a missed defect ships in a baseline others copy
status: merged
scope: [docs/reviews/lwc-review.md]
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
- Lane: every file in force-app/main/default/lwc/accountBriefPanel, the Apex methods it calls (read only, for the contract), force-app/main/default/applications/Account_Brief.app-meta.xml and force-app/main/default/flexipages/Account_Brief_UtilityBar.flexipage-meta.xml. Skills: experience-lwc experience-lwc-generate (its scoring), experience-accessibility-validate, experience-lwc-security-validate, experience-lds-best-practices-apply, experience-lwc-base-components-integrate; salesforce-development platform-flexipage-generate and platform-custom-application-generate
- Cover at least: the Cmd/Ctrl-K hotkey (listener scope, cleanup on disconnect, conflicts with browser or Salesforce shortcuts, behaviour when focus is in an input), focus management and focus trap, keyboard-only use, screen-reader labels and live regions for loading and results, colour contrast and SLDS usage versus hand-rolled CSS, layout at the 340 by 480 utility panel size, loading, empty and error states, stale or racing responses when a second request starts before the first returns, how model output is rendered (any innerHTML or lwc:dom manual, link handling), Lightning Web Security issues, and error surfacing from Apex
- Tests and config: there are no Jest tests today and .forceignore ignores __tests__; list the test cases you would require, most valuable first. Note the component apiVersion (64.0 versus project 68.0), targets and exposure in the js-meta.xml, and the untracked force-app/main/default/lwc/jsconfig.json (say whether it should be ignored, committed or deleted)
- Give the experience-lwc-generate score with how you applied it, and the accessibility findings with their WCAG criterion

## Review

Brain read the hand-back. Attempt 1 had 2 claims refuted (it said all seven skills were loaded with the Skill tool when only three were, and that the tree was clean); the worker fixed both in attempt 2. A Sonnet reviewer checked attempt 2 at 921bc37: 17 confirmed, 1 refuted, 5 unverifiable. The one refuted row was an untracked tests/__pycache__/ left by the verifier's gate run, not part of the commit; accepted by hand. Verdict sound with fixes, 120/165, 14 findings. Top items: eager=false on the utility item may leave Cmd/Ctrl-K inactive until first open (suspected blocker, needs a live check); the one-request guard is bypassed by the candidate, related and message-channel paths; the RecordPage target allows a second live instance; no aria-live region; focus lost on Esc, close and drill; raw Apex exception text reaches the user. Add jsconfig.json to .gitignore.
