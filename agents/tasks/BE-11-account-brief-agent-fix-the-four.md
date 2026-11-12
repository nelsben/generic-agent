---
id: BE-11
title: Account_Brief agent: fix the four Studio preview defects (contextRecordId type, briefed-account set, explore skips its action, router sends org-wide questions to the brief)
domain: backend
tier: frontier
tier_reason: Agent Script runtime semantics and routing precedence; local gate cannot catch Studio behaviour
status: merged
scope: [force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent, tests/test_agent_bundle.py, tests/agent/Account_Brief-testSpec.yaml, docs/research/salesforce-skills.md]
forbid: [force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/permissionsets/**, force-app/main/default/flexipages/**, force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.bundle-meta.xml, scripts/**, reference/**, agents/**, .chassis-delegation.json]
red_test: python3 -m unittest tests.test_agent_bundle: new assertions (contextRecordId declared as object with complex_data_type_name lightning__recordIdType; resolve_account sets briefed_account_id and briefed_account_name unconditionally, with no if/else on @outputs.status; explore_data runs deterministically; router sends an account-less org-wide question to explore) fail on main after BE-9 and pass after
gate: test, agent
budget: 2-attempts
spend: 25
---
## Why

The first live Studio preview of BE-9's script (2026-11-11) found defects the local gate cannot see. Studio rejects the contextRecordId input type. The brief never runs because a conditional post-action set never fires. The explore subagent answers count questions without calling explore_data (it said 32 open opportunities twice; the org has 36). After a brief, an org-wide question is answered about the briefed account. Two of these fixes are already proven in Studio; this card puts them in the repo and fixes the other two.

## Done when

- Read first, in the agentforce-adlc agentforce-generate skill (load with the Skill tool, else read SKILL.md and its references under ~/.claude/plugins/cache/): agent-script-core-language.md, complex-data-types.md, production-gotchas.md, optimization-pattern-2-deterministic-logic.md. Do not describe platform behaviour from memory; cite the reference file in a code comment or the hand-back for each fix
- Fix 1 (proven in Studio): in the explore subagent's explore_data inputs, contextRecordId is declared `object` with `description: "The Id of the record the user has open, if any."`, `complex_data_type_name: "lightning__recordIdType"` and `is_required: False`, replacing `string`. Studio backend validation rejects both `string` and `id` for an Apex Id invocable input
- Fix 2 (proven in Studio): in account_brief's reasoning binding for resolve_account, the `if @outputs.status == "RESOLVED":` / `else:` block is replaced by unconditional `set @variables.briefed_account_id = @outputs.accountId` and `set @variables.briefed_account_name = @outputs.accountName`. The conditional form never set the variables at runtime. This is safe because AccountBriefResolver returns blank accountId and accountName unless RESOLVED, so NOT_FOUND and AMBIGUOUS clear the briefed account
- Fix 3: the explore subagent can no longer answer a data question without calling explore_data. Use the deterministic pattern from optimization-pattern-2-deterministic-logic.md. Find in the references how a deterministic run receives the user's message (the trace shows `__user_input__`) rather than guessing; if the references do not settle it, say so in the hand-back and choose the most constrained option the references do document. The reply stays the action's text verbatim
- Fix 4: router precedence. A message that names no account and asks an org-wide count, list or comparison (e.g. "How many open opportunities are there?") routes to explore even when an account has been briefed earlier in the conversation. A follow-up that refers to the briefed account ("their open cases", "what about them") still routes to account_brief. State the rule in the router instructions in that order
- Optional, decide and say which: declare `knownAccountId` (AccountBriefResolver's optional String input) on resolve_account so Studio's missing-input warning goes away, bound to @variables.briefed_account_id if the references support that
- tests/test_agent_bundle.py: change the assertion that expects `contextRecordId: string` (about line 232) and the related contextRecordId assertions to the object form; add assertions for fixes 2 to 4. tests/agent/Account_Brief-testSpec.yaml gains cases: org-wide count after a brief routes to explore and calls explore_data; NOT_FOUND then a follow-up does not brief an earlier account
- docs/research/salesforce-skills.md gains a short note: the local gate (compile plus org validate in scripts/agent-check.sh) passed both the rejected `string` form and the conditional set; Studio backend validation and a live preview are still required before publish
- Every existing behaviour the preview passed stays the same: verbatim brief relay, AMBIGUOUS reply text and candidate lines, the off-topic line "I can brief you on an account or answer questions about your CRM data.", NOT_FOUND relay, follow-up "their open cases" calls get_brief with include=cases and no resolve, switching accounts resolves then briefs the new one
- Gates pass: `python3 -m unittest discover -s tests` and `bash scripts/agent-check.sh` (it uses /usr/local/bin/sf; put /usr/local/bin first on PATH). Run Python with PYTHONDONTWRITEBYTECODE=1 and leave no tests/__pycache__/. `git status --short` is empty when you report. Hand back the final .agent file's sha256 prefix so the brain can paste exactly those bytes into Studio
- Hard limits: no deploy, no publish, no activate, no Studio or Chrome browser tools, no `sf agent preview` (it crashes for employee agents), no Apex changes. Do not install plugins; if a hook suggests one, load the named skill instead

## Review

Sonnet review, attempt 1 at c4b7481: 20 confirmed, 0 refuted, 3 unverifiable. Open, Studio-only: (a) explore_data's question equals the user message (`@system_variables.user_input` compiles to `system.input_text`); (b) the before_reasoning run is reported as an action; (c) whether a new turn re-enters the router or resumes the subagent. Also needs a preview or test run: NOT_FOUND then a follow-up relays NOT_FOUND again. The .agent sha256 prefix is fb0fc27d.
