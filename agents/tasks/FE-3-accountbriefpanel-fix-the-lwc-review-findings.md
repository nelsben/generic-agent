---
id: FE-3
title: accountBriefPanel: fix the LWC review findings and add the Jest setup with the review's test cases
domain: frontend
tier: frontier
tier_reason: 14 interacting UI, accessibility and race fixes plus a Jest suite from scratch; regressions are silent
status: merged
fixes: []
scope: [force-app/main/default/lwc/accountBriefPanel/**, force-app/main/default/flexipages/Account_Brief_UtilityBar.flexipage-meta.xml, force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, package.json, package-lock.json, jest.config.js]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, force-app/main/default/objects/**, force-app/main/default/staticresources/**, force-app/main/default/applications/**, docs/**, reference/**, agents/**, scripts/**, tests/**, .chassis-delegation.json, .gitignore, .forceignore]
red_test: npm run test:unit (the Jest suite does not exist yet; the token-drop, hotkey-modifier, history-clear and error-text cases fail on the current component), plus AccountBriefPanelControllerTest's new raw-exception case via bash scripts/validate-org.sh
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

The LWC peer review (docs/reviews/lwc-review.md, merged in PR #22) scored the panel 120/165 and found 14 issues. They include a hotkey that may stay inert until the utility is first opened, a one-request guard that three entry points bypass, no screen-reader announcements, lost focus, and raw Apex errors reaching the user. The panel has no Jest tests, and Jest setup is already planned in corrective plan step 3. This card folds the two together, so the fixes land with tests that hold them.

## Done when

- Read docs/reviews/lwc-review.md fully first; every finding (1 to 14) and its list of Jest cases are this card's work. Read and load with the Skill tool where available: experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-base-components-integrate, experience-lwc:experience-lwc-security-validate, salesforce-development:platform-flexipage-generate. Otherwise read their SKILL.md and references under ~/.claude/plugins/cache/salesforce/<plugin>/<version>/skills/
- Finding 1: the utility item in Account_Brief_UtilityBar.flexipage-meta.xml is eager (eager=true), so Cmd/Ctrl-K and the AccountBriefOpen subscription work before the panel is first opened. This is decided; do not leave it eager=false
- Finding 2: every entry point (submit, candidate pick, 'brief this account', related drill, message channel) goes through one request path. The latest request wins: each request carries a token, and a response whose token is not the latest is discarded, never rendered. A Jest test proves a slow first response arriving after a second request is dropped
- Finding 3: the js-meta.xml exposes only lightning__UtilityBar. Remove the lightning__RecordPage target; no page in force-app uses it
- Finding 4: a visually hidden aria-live=polite region announces 'Loading brief for <account>' when a request starts and a short result line when it ends (WCAG 4.1.3)
- Findings 5 and 6: there is no Tab trap, because the panel is not a modal. The element focused before Cmd/Ctrl-K is recorded. Esc from anywhere inside the panel minimizes the utility through lightning/platformUtilityBarApi and returns focus to that element. After a drill or back, focus moves to the new heading or the restored row (WCAG 2.4.3)
- Finding 7: clickable rows are real controls (a button or link inside the row, or the base component the review names), with an accessible name (WCAG 4.1.2)
- Finding 8: the layout fix the review gives is applied: :host and .abp-panel at height 100%, with min-height 0 on .abp-body, so the composer stays pinned at 340x480; the newest turn scrolls into view after each answer
- Finding 9: history clears when the account changes, and a history response for an account that is no longer current is discarded. Use historyAccountId or remove it
- Finding 10: AccountBriefPanelController's @AuraEnabled methods catch unexpected exceptions and throw AuraHandledException with a fixed user-facing message, never raw exception text, matching docs/ARCHITECTURE.md's fixed NOT_FOUND and ERROR text. AccountBriefPanelControllerTest proves it
- Finding 11: the hotkey matches exactly Cmd-K on Mac or Ctrl-K elsewhere, with no Shift or Alt. The unreachable Escape branch in the document handler is removed
- Findings 12 to 14 are applied as the review recommends: base components where it names them, SLDS 2 styling hooks in place of the two non-SLDS-2 hooks with their hex fallbacks, the nits, and apiVersion 68.0 in the js-meta.xml. Where you judge a recommendation wrong, leave it and say why in your hand-back
- Jest is set up: package.json (private, with devDependency @salesforce/sfdx-lwc-jest and a script test:unit that runs sfdx-lwc-jest), package-lock.json and jest.config.js at the repo root. Tests live in force-app/main/default/lwc/accountBriefPanel/__tests__/ (already ignored by .forceignore; keep it). They cover the review's 10 cases plus the token-drop case above, and use jest mocks for the Apex imports, message channel and platformUtilityBarApi. node_modules is already gitignored
- Gates pass: `python3 -m unittest discover -s tests`, `npm run test:unit`, and `bash scripts/validate-org.sh` (check-only deploy in org `experimental`). Run Python with PYTHONDONTWRITEBYTECODE=1 and leave no tests/__pycache__/. `git status --short` is empty when you report (node_modules is ignored)
- Hard limits: check-only deploy only; do not deploy, publish or activate anything. Do not touch the agent bundle, the engine classes or the permission sets. Do not install plugins. Do not use the Chrome browser tools. Never run all local tests in the org. A plugin hook may refuse a raw command or suggest a plugin install: load the named skill and retry; never install a plugin
- Your hand-back lists the live checks for the brain to run in the browser after deploy: Cmd/Ctrl-K before the utility is ever opened, focus return on Esc, the layout at 340x480, the screen-reader announcement, and a second request sent while one is pending

## Review

Sonnet review, attempt 2 at ee09511: 21 confirmed, 0 refuted, 3 unverifiable. Attempt 1 failed only on tests/test_app.py:59 (eager false); amend approved for that one file. Open: live browser checks after deploy (Cmd/Ctrl-K before first open, Esc focus return, 340x480 layout, screen-reader announcements, latest-wins in the UI, lightning-textarea change per keystroke, accordions collapsed, breadcrumb click). Jest needs npm ci first.
