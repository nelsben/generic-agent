---
id: FE-22
title: FR2: the conversation gains history, the scope chip and cards — a sessions control that reopens a past conversation, a chip that says what a question is about, and every answer rendered from the card contract with a plain-text fallback
domain: frontend
tier: frontier
tier_reason: extends the component every surface shares, renders a contract from two services, and must keep the interface the compact window already uses
status: merged
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryCard/**, e2e/**]
forbid: [force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/lwc/customerSummaryPanel/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, agents/**, docs/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest tests for the sessions control, the scope chip and each card type fail on main (none of the three exists) and pass after
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2): Ben asked for conversations a rep can come back to ("show that this customer has had this interaction through history", ledger F32, and switching between past chats, F60), for the product to show when a question is tied to the summarized account (F58), and for every answer to be richly formatted in cards (F65). As first cut all three sat in FE-12 with the thread, the composer and the theme, which made FE-12 too large for one card and tied it to a contract that did not exist yet (findings 29 and 34 in docs/reviews/fr2-plan-review.md). FE-12 now ships the core. This card adds the three parts once the history store (BE-26) and the card contract (FE-18, BE-39) exist.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F32, F58, F60 and F65), docs/plans/fr2-design.md ('Conversation design', 'Cards inline' and 'Rich text'), docs/research/fr2-conversation-history.md (BE-26: the methods that list and reopen sessions), docs/research/fr2-card-architecture.md (FE-18), docs/research/fr2-card-contract-apex.md (BE-39: exactly what the panel receives) and the customerSummaryConversation component as FE-12 left it, with its Jest tests. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-metadata-deploy first
- **Keep the public interface.** FE-12's interface (`@api recordId`, `@api sessionId`, `@api focusComposer()` and the event `sessionchange`) stays as it is, and FE-12's Jest tests pass unchanged. Anything this card adds to the interface is written at the top of the component's JavaScript file and tested. The compact panel's folder is not edited: it gets all three parts through the component it already uses
- **History:** a sessions control lists the user's past conversations on this account, newest first, through BE-26's list method, and reopening one loads its turns in order through BE-26's get method and sets `sessionId`, firing `sessionchange`. A 'New conversation' button starts a clean thread. An empty list, a failed load and a session whose account the user can no longer see each show one plain sentence. The control can be shown open through the public interface, because the rail (FE-15) shows this same control in its side column and builds no second one
- **The scope chip:** above the composer, a chip says what the next question is about: 'About <account name>' on an account page or after a summary, with a control to ask across the org instead, and 'Whole org' when there is no account. The choice is sent with the question through the controller's existing ask methods; if a method is missing, hand back and do not add Apex. The chip has an accessible name and is reachable by keyboard
- **Cards and rich text:** every answer that arrives with cards is rendered from them by one shared component, customerSummaryCard, which FE-18's page recommends (merged 2026-11-13). Port `cardSpikeCard` and `cardSpikeContract` from spikes/cards/ (read them; change nothing under spikes/) into the customerSummaryCard folder, with the contract as a module file inside that bundle, and port their Jest tests with them. The component takes `@api card` and `@api density` (`compact` or `comfortable`), picks one of the six layouts from the type's family in the registry, folds at 5 rows or items when compact and 10 when comfortable with the count line pinned, and fires `cardopen`, `cardchoose`, `cardask` and `cardaction`. It draws rich text from the card's `body` runs as BE-39 returns them; the ported parser stays only for text the surface writes itself. No `lwc:inner-html`, no `innerHTML`, and no `href` built from card data: a record link is a button, and the conversation navigates by Id on `cardopen`. The conversation gains `@api density`, default `compact`, and passes it to every card (the rail sets `comfortable` in FE-15). `cardask` sends the question down the normal ask path. `cardchoose` and `cardaction` are not handled here (BE-46's choice card and FE-14); they still bubble. An unknown card type, a newer version or a view builder that throws shows that card's `text`. An answer with no cards renders exactly as it does today. The action draft and action result types are FE-14's: here they fall back to text. Where BE-39's page and FE-18's page disagree on a name or a shape, BE-39's page is what the panel receives: follow it and say so in the hand-back. In the spike's fixtures the table reads 'Showing 6 of 212 rows' and the notice under it 'Showing 50 of 212 rows'; make any fixture carried over agree
- The limits FE-12 took on still hold for what this card adds: one Tab stop per result list, the target size of a drill line, Esc during IME composition, no overflow at 320 px, and every colour and font from the --cs-* variables. Jest: the sessions control (list, reopen, new, empty, error), the chip in each state, one test per card type from the JSON examples in FE-18's and BE-39's pages, the three fallbacks, the four events, no record Id anywhere in the rendered markup at either density, and zero axe violations through `toBeAccessible()` from @sa11y/jest, which the repo already sets up (add no dependency). Run the Lightning Web Security skill over both folders and fix what it finds
- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote. e2e specs: reopen a past session, the chip's two states, and one answer that shows a card. They are written and run in the suite when the row is approved, and written but not run when it is not. Paste the Playwright summary line in the hand-back
- **Seen in FE-12's capture (docs/assets/fr2-conversation-core.png):** at the compact width the 'Earlier summaries of <account>' heading truncates with an ellipsis. Make every section heading in the conversation readable at the compact frame's width: wrap it, or shorten it and keep the full text as its accessible name. The FE-12 action-draft/result turn (`_actionTurn`, `turn.isAction`) has no caller yet and its only test reads the source; do not rely on it being tested
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only, under the standing row "Production-classified deploys to `agent-probe`": validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/validate-org.sh. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-14). Two attempts, both at the same sha (03a06bc).
- Attempt 1: the worker handed back gate=fail with an amend asking to lift the forbid on customerSummaryPanel/** so it could rebuild FE-12's two accordion headings. The verifier found the gate green. The brain refused the amend: it was the last attempt, and the fix means rebuilding both headings and rerunning the live suite. The work is cut as FE-26.
- Attempt 2: the worker re-sent the hand-back with gate=pass and changed no file. A review returned 18 confirmed, 0 refuted, 6 unverifiable.

Findings:
- New bundle customerSummaryCard (`@api card`, `@api density`, public `focusLink(ref)`) draws the BE-39 card contract. It folds at 5 rows (compact) and 10 (comfortable). No innerHTML, inner-html or href from card data; Jest asserts it, and asserts no record Id reaches the rendered markup at either density. toBeAccessible() runs in Jest.
- The chip wash is the primary colour mixed 10% into the surface, replacing --cs-color-accent after a live contrast failure (1.83:1 on related chips); a Jest test pins it.
- customerSummaryConversation gains `@api density` (default compact), `@api sessionsOpen` and a `sessionchange` event, declared at the top of the JS. Reopening a session calls getSession and shows an empty-question turn as 'Summary'. "New conversation" clears the turns, sets a new session id and keeps the briefed account.
- The scope chip reads 'Whole org' or 'About <account>'; a whole-org question sends a null context (an e2e test asserts it).
- cardask and cardopen are handled; focus after a drill returns to the card link, falling back to the composer. cardchoose and cardaction have no handler and bubble.
- The e2e helpers match both card and card-less markup, and e2e/conversation-fr2.spec.js adds three tests, including the Shift+Tab/Enter keyboard switch. FE-12's own Jest tests were not edited. Answers without cards render as before.
- No Apex, Panel bundle or spike file changed.

Gate (verifier): 175 Python tests, 264 Jest in 6 suites, validate-org pass (130 components, 326 tests).

Org (worker's account): three scoped LWC deploy cycles to agent-probe, each validated with RunLocalTests (419 tests, 0 failures) and quick deployed under the standing row. The final full Playwright run passed 16 of 16 (4.5 min).

Org writes outside the deploy, under the approved live-checks row: the e2e runs ran as the developer user, who holds the outcome set from BE-35, so Customer_Outcome__c rows on the seed account went from 3 to 21 and Customer_Summary_Session__c from 7 to 8. Nothing was published, no user was created and no assignment changed.

Disclosed and accepted:
- The org and Playwright figures are the worker's account; nothing in git shows them.
- Spec 7 ("record heading has focus") failed once in four full runs and passed on rerun; the cause was not found.
- Requirement 8 is partly met: the headings FE-22 adds wrap, but FE-12's two accordion headings ("Sections: all", "Earlier summaries of <account> (n)") are unchanged and still use nowrap. FE-26 does them.
- Two zero-padded fixture constants in the new Jest file look like record Ids; they are synthetic, not from an org.
- A tests/__pycache__ made by the verifier's gate run was removed before review and before merge.

Still open:
- The drill view shows the record name and object twice (the h2 and the card's h3).
- The 320 px header row with History was not measured live.
- When several accounts match, the panel still shows FE-12's candidate buttons; the AMBIGUOUS choice card's cardchoose and cardaction events are not handled yet.
- The outcome rows the e2e runs write accumulate on the seed account; deleting them, or scheduling the purge job, is Ben's call.

Privacy grep over the diff (4,605 added lines): 0 denylist hits; the two Id-shaped strings are the synthetic fixtures above.
