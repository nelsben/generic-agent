---
id: FE-14
title: FR2: write-action cards in the conversation — draft card with Confirm, Edit and Cancel, result card with a link, action chips and voice that lead to a draft; the e2e confirms a task only if its Approvals row is approved
domain: frontend
tier: frontier
tier_reason: first UI that writes records in a live org, with an e2e that creates and removes data
status: merged
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryActionCard/**, e2e/**, docs/assets/fr2-action-*.png, docs/assets/MANIFEST.md, docs/research/fr2-action-cards.md, force-app/main/default/lwc/customerSummaryCard/**]
forbid: [force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest cases for the draft and result cards fail on main and pass after
gate: test, jest, org
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2): sellers "create follow-up tasks, events" by voice or chat, and nothing is written until they confirm. This puts the action service (BE-27) into the shared conversation so every surface gets it. Covers ledger rows F15, F16, F18 and F27 (the action half) in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md, docs/plans/fr2-design.md ('Write actions', 'Cards inline'), docs/patterns/13-write-actions.md, docs/research/fr2-card-contract-apex.md (BE-39: the action draft and action result card types, as BE-27 fills them) and the customerSummaryConversation component as FE-22 left it. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate and salesforce-development:platform-metadata-deploy first
- A typed or spoken request that names an action (for example 'create a follow-up for next Tuesday', 'log a call with Maria'), or a chip ('Create a follow-up', 'Log a call'), calls draftFromText (typed or spoken) or draftAction (chip) and shows a draft card; a 'not an action' result goes down the normal ask path. The draft card appears inside the agent turn with: the action, the target account, each field with its label and an editable value, any warnings, and Confirm, Edit and Cancel. Missing fields are highlighted and Confirm stays disabled until they are filled. Nothing is written before Confirm
- **One card contract:** the draft card and the result card are BE-39's action draft and action result card types, rendered next to FE-22's other renderers (inside customerSummaryCard if FE-22 built that component, otherwise in customerSummaryActionCard), with the same plain-text fallback rule. Add no second card shape, keep FE-12's public interface and FE-22's Jest tests as they are, and write at the top of the conversation component's JavaScript file anything this card adds to its interface
- Confirm calls commitAction once (the button disables while it runs), then a result card shows what was written with a link to the record; a refusal or failure shows the plain-English error turn. Where the service supports it, updates offer Undo for 15 seconds. Each card reads only the --cs-* variables
- Jest covers draft rendering, editing a field, missing-field blocking, Cancel, Confirm calling commit once, the result card, the error path, and zero jest-axe violations. e2e in agent-probe: read the row "FR2: e2e and agent tests that create a record" in the Approvals table of docs/plans/gtm-burn-plan.md first. If its status starts with "approved": one test drafts and confirms a task on an existing sample account, checks the result card and the record, and removes that task and its Action outcome in teardown. If not: the test stops at the draft card and Cancel, and the hand-back says the confirm path is proven by the Jest and Apex tests only. Never create an account or a contact, and never touch a record the test did not create. Tag one spec for FE-21's smoke subset (the tag is in e2e/README.md). Paste the Playwright summary line in the hand-back. Capture docs/assets/fr2-action-draft.png and docs/assets/fr2-action-result.png at 1440x900 (the result card only if the test confirmed) and list them in docs/assets/MANIFEST.md. Every still and GIF is taken through e2e/capture/kit.js. docs/patterns/13-write-actions.md is not edited here: OPS-48 rewrites it from the screens. Write docs/research/fr2-action-cards.md for that card: each card and state as built, the captures by file name, and what page 13 should now say about them
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only. The deploy is under the standing row "Production-classified deploys to `agent-probe`": validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. The record-creating test is under its own row, as above. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Two attempts.
- Attempt 1 ($8.38): the worker stopped while its own validate-org gate ran in the background, with no report (no-report). The brain resumed it to wait for the job in the foreground, finish, and report.
- Attempt 2 (fc610ed, $0.31): the verifier found the report consistent and re-ran the gate green. A sonnet review returned 30 confirmed, 0 refuted and 5 unverifiable.

Findings:
- The conversation gains two chips, "Create a follow-up" (create_task) and "Log a call" (log_call), which call draftAction with an empty input; the server decides every field.
- Typed or spoken text that passes BE-22's filler and verb pre-check, run in the client, calls draftFromText. NOT_AN_ACTION falls through to the normal ask in the same turn, so a question costs no extra request.
- The draft is BE-39's actionDraft card inside the agent turn, drawn by customerSummaryCard through a new action-mode attribute. Each field has a label and an editable value; the account is a link, not an input. Missing fields get a red border, "Needed" and aria-invalid. Confirm stays off until the draft is READY and while a request runs.
- Edit moves focus to the first missing field. Cancel closes the draft with "Cancelled. Nothing was saved." and calls nothing.
- Confirm calls commitAction once (a guard ignores a second click) with only the action, account and input. A result card follows in a new turn, with a record link that navigates by standard__recordPage. A refusal or failure shows the plain-English error turn and leaves the draft open. An update offers Undo, removed by a 15 s client timer.
- cardContract keeps ready:false and adds an optional viewOf opt-in, so FE-12's interface and FE-22's tests are unchanged. The only existing test changed is FE-12's chips test, which now expects the two new chips.
- New Jest suites customerSummaryActionCards and customerSummaryConversationActions cover rendering, editing, missing-field blocking, Cancel, Confirm once, the result, the error path and axe.
- New e2e spec FR2 5 (@smoke, conversation-actions.spec.js) drafts a task from the chip, checks Needed and the disabled Confirm, then Cancels and asserts no commitAction request. The e2e README gains rows for FR2 4 (FE-26) and FR2 5, and counts 36 tests and 10 smoke tests.
- New capture docs/assets/fr2-action-draft.png (1440x900) with its MANIFEST row, made by e2e/capture/11-action-draft.capture.js. New docs/research/fr2-action-cards.md; page 13 is not edited.

Gate (verifier at fc610ed): Python 260 tests, 2 skipped; Jest 9 suites, 351 tests; validate-org pass (148 components, 425 tests). Brain: check-docs 71 pages, 0 broken.

Org (worker's account), under the standing deploy row: a validate with RunLocalTests of the two LWC bundles (518 tests, 0 errors), then a CONFIRM_PROD=1 quick deploy of 2 components. The worktree's target-org was set for the deploy hook, then unset.

E2E (worker's account): FR2 5 passed in the org. Records created 0, removed 0; the capture run created none.

Disclosed and accepted:
- The confirm path is proven by Jest and the existing Apex tests only. The Approvals row for e2e tests that create a record is pending Ben, so the e2e stops at Cancel.
- The review's unverifiable rows: the server's own 15 s undo check (Apex unchanged here), the Playwright summary line, the org figures, check-docs (the brain ran it: 71 pages, 0 broken) and the PNG content. The brain opened the PNG: seed data only ("Sample Owner", "email hidden"), no address bar, no Id, username, email or hostname.
- red-1 was re-recorded after a jest.mock hoisting mistake: 35 failed, 5 passed on the unchanged source.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- The five chips scroll sideways in the 420 px compact window, so the first chip is cut off in the still ("n deals"). Page 13 should note it or a card should fix it.
- Page 13 still describes the write actions as not yet in the UI; fr2-action-cards.md says what it should now say (follow-up card).
- A result-card still is not taken; it needs the record-creating e2e approval.

Privacy check over the full branch diff (1,818 added lines, PNG excluded): 0 denylist hits; no URLs, Ids, local paths or job Ids. The only @ matches are code decorators and lint rule names.
