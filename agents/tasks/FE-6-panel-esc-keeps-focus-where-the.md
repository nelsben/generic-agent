---
id: FE-6
title: Panel: Esc keeps focus where the user was, brief lines drill into records, and the panel has the test hooks the e2e suite needs
domain: frontend
tier: frontier
tier_reason: crosses Apex sections, prompts and LWC focus timing against platform behaviour
status: queued
fixes: []
scope: [force-app/main/default/lwc/accountBriefPanel/**, force-app/main/default/classes/AccountBrief*.cls, e2e/panel.spec.js, e2e/support/panel.js, e2e/README.md]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, force-app/main/default/classes/Explore*.cls, force-app/main/default/classes/DataExplorer*.cls, tests/**, scripts/**, docs/**, agents/**, .chassis-delegation.json, reference/**]
red_test: the new Jest test for the late focus steal and the new Apex tests for record Ids in section lines fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

The Playwright suite (FE-4) found two live defects: after Esc the platform's minimize steals focus from the element the panel restored, and no brief line can be drilled because the section Apex writes no record Id into its lines. Both must be fixed before screenshots and GIFs are captured for the GTM repo, and the suite must be able to reach 8 of 8.

## Done when

- Read e2e/README.md, e2e/panel.spec.js, accountBriefPanel.js (the _close function, idInLine and handleLineDrill) and docs/reviews/lwc-review.md first. Read the skills experience-lwc-generate and platform-apex-generate (SKILL.md under ~/.claude/plugins/cache/salesforce/*/skills/)
- Esc: after the panel minimizes, focus ends on the element that had focus before the hotkey and stays there. The platform moves focus after minimizeUtility() resolves (to the utility header, then the bar button, then body, up to about 1 s later), so restore focus after the platform has finished, and stop as soon as the user moves focus themselves. A Jest test covers the restore logic with a simulated late focus steal
- Drill from a brief: every line in the open_deals, cases, contacts, activity, calls and deal_history sections that describes one record carries that record's Id in the form the panel's idInLine already matches, so the line renders as a drill button. The Id must not be shown as visible text to the user and must not reach the model prompts (strip it before sections are sent to AgentLlm). Apex tests prove both: the Id is in the section line returned to the panel, and it is absent from the prompt text
- Test hooks, without changing what users see or hear: the scrolling body gets a role and an accessible name; the spinner container gets a data-testid; the summary headline is distinguishable from section headers by level or a data-testid; the panel's live region gets a data-testid. Update e2e/support/panel.js and e2e/README.md to use them
- e2e/panel.spec.js: spec 2's focus checks and spec 7's section-line check become hard assertions. Do not run the e2e suite (the org does not have this code yet; a later card deploys and runs it)
- Existing behaviour and wording stay. No invocable signature, label or description changes. Jest stays at zero accessibility violations
- Gates pass: python3 -m unittest discover -s tests, npm run test:unit, and bash scripts/validate-org.sh (check-only; never a real deploy, never all local tests in the org)
- Hard limits: never publish, activate, deactivate, deploy for real or delete anything in the org; never install a plugin even if a hook suggests one; never sign in or print tokens. Run Python with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/, and git status --short is empty when you report
