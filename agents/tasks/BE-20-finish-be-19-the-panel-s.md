---
id: BE-20
title: Finish BE-19: the panel's "Ask the agent" calls the Account_Brief agent directly in agent-probe, from the stopped attempt's work (Jest 50/50 done); deploy, e2e, docs and asset
domain: backend
tier: frontier
tier_reason: live deploy, e2e and agent spec in the org plus recapture, continuing Apex-to-agent work with a seam
status: merged
fixes: []
scope: [force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, force-app/main/default/classes/AccountBriefAgentClient.cls, force-app/main/default/classes/AccountBriefAgentClient.cls-meta.xml, force-app/main/default/classes/AccountBriefAgentClientTest.cls, force-app/main/default/classes/AccountBriefAgentClientTest.cls-meta.xml, force-app/main/default/lwc/accountBriefPanel/**, force-app/main/default/permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml, e2e/panel.spec.js, e2e/support/**, e2e/capture/**, e2e/README.md, docs/assets/**, docs/patterns/03-hotkey-panel.md, docs/patterns/06-agent-routing-and-verbatim-relay.md, docs/research/panel-agent-1.md, README.md, tests/**]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/staticresources/**, force-app/main/default/permissionsetgroups/**, data/**, agents/**, docs/plans/**, docs/reviews/**, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new Playwright agent round-trip step in e2e/panel.spec.js fails against main's panel in agent-probe (the button hands off to the built-in panel) and passes after the deploy; the new Apex and Jest tests from the work in progress fail on main and pass
gate: test, jest, org
budget: 2-attempts
spend: 35
---
## Why

BE-19's worker was stopped by an interrupt after the probe, the red tests, the Apex client and the LWC change (Jest 50/50), just before the org validate. The mod cannot resume it (its ledger marks the stopped attempt live and its unchanged branch as merged), so this card continues the same work from the committed work-in-progress. Ben confirmed the panel should call the agent directly and that this card should finish now, with a light touch on the panel because a redesign follows.

## Done when

- Start from the work-in-progress commit this worktree is cut from (BE-19's stopped attempt). Read agents/tasks/BE-19-the-panel-s-ask-the-agent.md: its Done when is this card's Done when, with the changes below. Read .delegation/BE-19/red-1.txt if present, git log -1 and git show --stat first; build on that work, do not start over. Load the skills that card names before writing code or running sf commands
- Re-check the work in progress against BE-19's Apex, LWC and permissions lines; finish what is missing. Before deploying, re-run the probe once (one generateAiAgentResponse call plus one session-reuse call as the signed-in admin through anonymous Apex) and record the result shape, timing and permission in docs/research/panel-agent-1.md; if it fails, stop and hand back gate=fail with the evidence
- Light touch on the panel: the LWC change is limited to the direct agent call, the multi-turn session, the screen-reader progress state and latest-wins. No layout, position, size or styling changes, because a redesign follows
- Org, agent-probe only, under the Approvals lines 'The panel calls the registered agent directly' and 'Production-classified deploys to agent-probe ... standing': validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental
- e2e, agent spec, docs and asset exactly as BE-19's Done when says: red then green agent round-trip step, npm run test:e2e 9 of 9, the Account_Brief agent spec once after e2e (16 of 16 replies and actions), README.md and patterns 03 and 06 describe the direct call with the sequence diagram updated, new docs/assets/panel-ask-agent.png (or GIF) read by eye, MANIFEST.md rows and alt text updated, every other asset byte-identical unless it shows the hand-off
- No record Ids, org Ids, usernames, emails, tokens, session Ids, instance hostnames or URLs with query strings in any file or image. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

# BE-20 hand check (attempt 2 report, sha 2676985)

Accepted after a hand check.

- The verifier's "9 uncommitted paths" were only `tests/__pycache__` left by the gate. After removing it, the tree is clean at 2676985.
- Gates rerun by the brain at 2676985: unit tests OK, Jest 50 of 50, validate-org pass (63 components, 172 tests, agent-probe check-only), check-docs 33 pages and 0 broken.
- The attempt-1 report was refuted only on files= (it listed paths against main, not against its base e3f9851). The attempt-2 report lists the 12 paths that differ from e3f9851; the brain confirmed them with git diff.
- Worker's reported org facts: validate with RunLocalTests then quick deploy with CONFIRM_PROD=1 in agent-probe; spec 9 green; e2e 9 of 9; no publish or activate; no permission set change.
- The agent spec scored 15 of 16 on topics and on replies, not the 16 of 16 the card asked for. The topics miss is the known off-topic false failure (case 12). The replies miss is case 14 (N3, Testing Center does not set explore_history), the same answer an earlier run passed. This is accepted as a known limit, not a regression.
- Privacy grep of the 986 added lines: denylist 0, emails 0, query-string URLs 0, home paths 0. One Id-shaped match is a synthetic test constant (`0Xx000000000001AAA`); two host matches are the standard SOAP metadata namespace.
- `docs/assets/panel-ask-agent.png` was read by eye. It shows sample data only, with emails hidden and the owner shown as "Sample Owner".
- Follow-ups:
  - The reply contains the line "Account Not requested.", relayed verbatim from the brief. FR2 cards FE-12 and BE-28 touch this path.
  - Use by a non-admin user is unproven.
  - How a relayed explorer table reads in the panel was not checked.
- Review (attempt 2): 14 confirmed, 1 refuted, 5 unverifiable. The refuted row is the agent-spec target above (16 of 16 not met). The docs report it honestly. The brain accepts it as the known N3 and case-12 limit. The unverifiable rows are the org run facts (probe timings, deploy job, e2e 9 of 9). The brain's own validate-org (172 tests) and the screenshot match them.
- Brain fix a4c777b: the research page now says the 16 of 16 target was not met and why it was accepted. Re-verified consistent at a4c777b (gate green).
- Review (attempt 3): 9 confirmed, 1 refuted. The refuted row was the removal of the visible "Account Brief agent" source label, seen as going beyond the light touch. That label came from BE-19's unfinished work in the e3f9851 base and never reached main: `git diff` of the panel HTML against main shows no `abp-agent-source` line.
- Brain fix 7badf31: the research page's Design section now says where the label came from and that the visible markup matches main. check-docs 0 broken; re-verified consistent at 7badf31 (gate green: 93 unit tests, Jest 50 of 50, validate-org 172 tests).
- Review (attempt 4): 17 confirmed, 1 refuted. The refuted row was right: the page said the visible markup was unchanged against main, but `disabled={sendDisabled}` was added to "Ask the agent". Brain fix 506c21c names that one visible change.
- Review (attempt 5, at 506c21c): 16 confirmed, 2 refuted, 6 unverifiable. The brain overrules both refuted rows after a hand check:
  - `tests/__pycache__` is left by the mod's own gate run (its files are stamped one second after the commit). The brain removed it; the tree is clean at 506c21c.
  - The disabled state on "Ask the agent" while the composer is empty matches Send. It stops a blank question from reaching the agent, and the research page declares it. It is the smallest change that keeps the button honest, so it stays within the light touch.
  - The unverifiable rows are the org run facts. The brain's own validate-org (172 tests) and the screenshot match them, as in attempt 2.
- Review (attempt 5, rerun at 506c21c after the brain cleared `tests/__pycache__`): 23 confirmed, 0 refuted, 5 unverifiable. The unverifiable rows are the org run facts listed above. Verdict: accept.
