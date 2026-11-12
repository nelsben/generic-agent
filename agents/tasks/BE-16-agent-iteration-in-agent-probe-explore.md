---
id: BE-16
title: Agent iteration in agent-probe: explore follow-ups keep the previous question, NOT_FOUND stops pointing at an unbound input, and the spec covers the missing branches
domain: backend
tier: frontier
tier_reason: Apex plus agent script change shipped through publish, activate, test and rollback in a live org
status: merged
fixes: []
scope: [force-app/main/default/classes/ExploreAction.cls, force-app/main/default/classes/ExploreActionTest.cls, force-app/main/default/classes/AccountBriefResolver.cls, force-app/main/default/classes/AccountBriefResolverTest.cls, force-app/main/default/aiAuthoringBundles/Account_Brief/**, tests/test_agent_bundle.py, tests/agent/Account_Brief-testSpec.yaml, docs/research/agent-iteration-1.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/permissionsets/**, force-app/main/default/classes/DataExplorer.cls, e2e/**, scripts/**, README.md, docs/patterns/**, docs/plans/**, docs/reviews/**, agents/**, .chassis-delegation.json, reference/**, .sf/**]
resources: [org-live]
red_test: the new ExploreActionTest and AccountBriefResolverTest methods and the new tests/test_agent_bundle.py assertions fail on main and pass after
gate: test, org, agent
budget: 2-attempts
spend: 25
---
## Why

Agent re-review findings N3, N6 and earlier findings 6, 7 and 12 are the should-fix items left on the agent once a version can be published. Fixing them in the new org proves the iterate loop (change, deploy, publish, activate, test, roll back if worse) end to end, which the baseline promises.

## Done when

- Before anything else, read docs/reviews/agent-review-2.md (findings 6, 7, 12 and N3, N4, N6, plus 'Shipping an agent change safely'), docs/research/org-migration.md, docs/plans/gtm-burn-plan.md sections 'Approvals' and 'Phase 2', and docs/plans/corrective-plan.md rules 1 to 4. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate, salesforce-development:platform-metadata-deploy, agentforce-adlc:agentforce-generate and agentforce-adlc:agentforce-test. Verify every sf flag with --help; every sf agent command takes --json. If org-migration.md does not show an active published version in agent-probe, stop and hand back
- N3, Apex: ExploreAction takes an optional history input (the previous explore question and answer as one string, empty allowed) and passes it to DataExplorer, which already accepts history. ExploreActionTest covers both with and without history. No other Apex changes behaviour
- N3, script: the Account_Brief script keeps the last explore question and answer in a variable, binds it to the new history input, and clears it when a brief starts. Router rule 4 (pronoun follow-ups go to the briefed account) applies only when the previous reply came from account_brief. tests/test_agent_bundle.py asserts the binding and the narrowed rule
- Finding 12: the resolver's NOT_FOUND message no longer tells the user to open the account and ask again (knownAccountId is not bound in the script); it asks for a fuller or different account name instead. AccountBriefResolverTest asserts the new text. The Apex label at AccountBriefResolver.cls that still says 'character for character' is reworded to match the script ('without the rest of the request')
- Spec (tests/agent/Account_Brief-testSpec.yaml): add cases for an explore follow-up ('How many open opportunities are there?' then 'Which close this quarter?'), a pronoun follow-up after an org-wide count that must stay in explore, a list pick after AMBIGUOUS, and a second account that resolves after a brief (the brief must be about the second account). Case 11's outcome says the table rows are relayed unchanged. Remove expectedTopic topic_selector from the off-topic case. Keep the existing cases' meaning; tests/test_agent_bundle.py stays in step with the spec
- Org, agent-probe only, per the Approvals line 'Phase 2: cut and work new agent or design iteration cards in the new org': deploy the changed Apex with `sf project deploy validate` (RunLocalTests, without aiAuthoringBundles) then quick deploy with CONFIRM_PROD=1, once each. Run bash scripts/agent-check.sh, then publish once with --skip-retrieve, `git checkout` the bundle folder, query BotVersion, and activate the new version explicitly. Record which version was active before
- Test the new version: recreate or update the evaluation definition so its subject version is the new one (check it), run the whole spec once, and run the two-turn follow-up check as org-migration.md records it. If the new version passes fewer spec cases than the previous version did in org-migration.md, reactivate the previous version, record that, and hand back. Never retry a failed publish with the same call
- Preview the three reclassify paths out of explore (N4) once each and record whether a discarded explore_data step appears in the trace; change nothing for N4 in this card, only record it
- Write docs/research/agent-iteration-1.md: each change and the finding it closes, commands and outcomes in order, the version table before and after, the spec table (case, result, judge note), the two-turn result and the N4 trace notes. No record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings
- Budget: at most about 40 model calls in the org. Write no data except the evaluation definition and what the agent writes itself. Never touch experimental, never sign in or out, never create users, never install a plugin even if a hook suggests one
- Gates pass: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/agent-check.sh; leave no tests/__pycache__/; git status --short is empty after your commit. In the hand-back paste the read-only BotVersion query result

## Review

Accepted after one attempt and one review pass: 28 confirmed, 0 refuted, 10 unverifiable.

- What changed:
  - N3: ExploreAction takes and returns a history item, and the script keeps it in explore_history. Router rule 4 now applies only after an account_brief reply.
  - Finding 12: the not-found and blank-name messages are reworded.
  - The spec gains four cases, reaching 16. Case 11's wording changes and expectedTopic is removed from the off-topic case.
- The org steps ran in agent-probe:
  - The Apex was validated and quick-deployed once each.
  - Publish took two calls. The first was rejected for a 276-character variable description and created no version. The second used a changed bundle, and a unit test now enforces the 255-character limit.
  - v2 was activated explicitly.
  - The evaluation definition was recreated on v2, and the spec passed 16 of 16. Case 12's topic FAILURE is the runner's false failure once expectedTopic is removed.
  - The two-turn check passed.
- The brain checked the version state with a read-only BotVersion query: v1 Inactive, v2 Active.
- The 10 unverifiable rows are org-side results (deploy jobs, spec run, two-turn, preview traces, N4) that leave nothing in the tree. The BotVersion row is now checked.
- Left for FE-10, which owns docs/patterns: page 06 line 143 still quotes the old not-found text. The pattern pages should also say v2 is active in agent-probe.
- Not proven: explore history on the published v2. It was checked only in a preview of the local bundle, which differs from v2 by one shortened description. Testing Center cannot fill the history input, so spec case 14 does not exercise it.
- Gates: test (83), org (60 components, 154 Apex tests) and agent all pass at b1aa3e0. Privacy grep of the 457 added lines found nothing: no deny-list hits, Salesforce-shaped Ids, emails, instance hosts, query-string URLs or home paths.
