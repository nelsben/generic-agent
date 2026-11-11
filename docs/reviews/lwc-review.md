# LWC review: accountBriefPanel, the Account Brief app and its utility bar

Reviewed 2026-11-11 (OPS-12). This is a review only: nothing was changed, deployed or run against the org.

## Summary

**Verdict: sound with fixes.** The panel is safe where it matters most. Model text is only ever bound as text: there is no `innerHTML`, no `lwc:dom="manual"` and no model-supplied link. The LWS rule catalog (lws-001 to lws-023b) comes up clean, the listeners are removed on disconnect, and page-context resolves are guarded against stale replies.

The defects are in behaviour:
- The Cmd/Ctrl-K hotkey probably does nothing until the utility has been opened once.
- Some actions bypass the "one request at a time" guard, and a record-page placement creates a second live instance.
- Keyboard and screen-reader users get no announcement of results and lose focus on Esc and on drill.
- The composer is not pinned at 340x480, and most controls are hand-rolled instead of `lightning-*` base components.

There are no Jest tests. Score: **120/165**. Tags: V = verified (the failure path is in the code), S = suspected (depends on platform behaviour at runtime).

## Findings

**1. Hotkey and message channel are inert until the utility is first opened.** Blocker if confirmed. S, new (the live Cmd-K check is already planned, plan section 6).
- Where: `Account_Brief_UtilityBar.flexipage-meta.xml:7-11` sets `eager=false`.
- What is wrong: utility items that are not eager are created only when first clicked. Until then nothing has run `connectedCallback` (js:112-118), so neither the `document` keydown listener nor the `AccountBriefOpen` subscription exists.
- Scenario: a user loads the app and presses Cmd-K. Nothing happens. Any `AccountBriefOpen` publish before the first click is lost.
- Fix: set `eager` to `true` (Load in background), then confirm it live.
- Skill: platform-flexipage-generate (`xml_rules.md`, decorator properties). The skill does not document `eager`'s behaviour, hence S.

**2. The one-request guard is bypassed.** Should-fix. V, new.
- Where: `_run` (js:402-411) never checks `pending`. `handleCandidate` (js:393-396) calls it unguarded, and the candidate buttons are never disabled (html:136-139). The message-channel brief path (js:710-712) does the same.
- Scenario: a double-click on an AMBIGUOUS candidate starts two resolve+brief runs, which means two model calls and two memory writes. The first run to finish sets `pending=false` while the second is still running, so Send re-enables mid-flight. Separately, a message with a `prompt` that arrives while a request is pending is silently dropped (js:371).
- Fix: early-return in `_run` when `pending`, and disable the candidate buttons. Queue or reject an incoming message visibly.
- Skill: none states a request-guard rule. This is reviewer judgement against the card's racing-request checklist item.

**3. Two live instances when the component is also placed on a record page.** Should-fix. V, new.
- Where: `accountBriefPanel.js-meta.xml:7-10` exposes both `lightning__UtilityBar` and `lightning__RecordPage`, with no `targetConfigs`. Every instance subscribes with `APPLICATION_SCOPE` (js:141-146) and adds a `document` listener (js:113-114).
- Scenario: an admin drops the panel on an Account page in this app and publishes one `AccountBriefOpen`. Both instances run the prompt, so there are two model calls and two answers. For a brief, both also upsert the same memory row; for a plain question, no memory is written. Cmd-K focuses whichever instance registered first.
- Fix: drop the RecordPage target. If it stays, register the hotkey and subscription only when `utilityId` is truthy.
- Skill: experience-lwc-security-validate step 5 (over-broad targets).

**4. Screen readers are told nothing about results.** Should-fix. V, new. WCAG 4.1.3 Status Messages.
- Where: turns are appended (html:121-233) with no `aria-live` region. The only status is the "Loading" spinner (html:49). Apex error turns (js:407) and brief ERROR/NOT_FOUND text (html:149-151) are plain text. Only `notice` has `role="alert"` (html:43).
- Scenario: after a 14-18 s brief, a screen-reader user hears nothing when the answer or an error arrives.
- Fix: add a visually hidden `aria-live="polite"` region and set it to "Brief ready: <header>" or "Answer ready". Give error turns `role="alert"`, and give brief ERROR turns `isError` styling too.
- Skill: experience-lwc-generate `accessibility-guide.md` (Live Regions). The skill's own `validate_slds.py` also emits "Consider adding aria-live".

**5. Focus is lost on Esc, on close and on drill.** Should-fix. V, new (the live focus check is already planned, plan section 6). WCAG 2.4.3 Focus Order.
- Where:
  - Esc in the composer blurs it to `body` (js:173-174).
  - `_close` blurs and minimizes, but never returns focus to where it was before Cmd-K (js:237-249).
  - Several clicks remove the element that has focus. A conversation row click swaps the conversation for the drill view (js:556-561; html:52/120). Within a drill, a row click or a related-object chip replaces the table or card (js:574-579). "Conversation" removes the whole drill view (js:586-588).
- Scenario: a keyboard user drills a row and focus lands on `body`, so they must Tab from the top of the page.
- Fix: record `document.activeElement` on Cmd-K and restore it on close. After a drill or back, focus the new heading or the restored row.
- Skill: experience-lwc-generate `accessibility-guide.md` (Focus Management: store and restore previous focus).

**6. A Tab trap in a non-modal panel.** Should-fix. V, new (the live focus-trap check is already planned, plan section 6). The nearest criterion is WCAG 2.1.2 No Keyboard Trap. This is not a strict failure, because Esc does leave the panel, but it is a design defect.
- Where: `_trapKeydown` (js:166-200) wraps Tab inside the panel.
- What is wrong: the utility header (minimize, pop-out) and the page cannot be reached by Tab. Esc is the only way out, and the first Esc only blurs. Every result row is also a tab stop (js:529), so 50 rows means 50 stops inside the wrap.
- Fix: remove the trap; the skill's trap pattern is for modals only. Keep Esc to minimize, and give rows a single tab stop (finding 7). Do not patch FOCUSABLE (js:33) instead: it will not match `lightning-*` hosts once finding 12 lands.
- Skill: experience-lwc-generate `accessibility-guide.md` (Focus Trap in Modals). There is no matching reviewer file in experience-accessibility-validate.

**7. Clickable table rows have no control role or name.** Should-fix. V, new. WCAG 4.1.2 (role).
- Where: `<tr tabindex="0" onclick onkeydown>` (html:102-103, 201-202).
- Scenario: a screen reader announces "row", not an actionable control, so users do not know the row drills.
- Fix: put a `<button>` in the first cell labelled with the record name, and drop `tabindex` from the `<tr>`. Or use `lightning-datatable` with a button column.
- Skill: experience-accessibility-validate `sc-4-1-2-ii-role.md`.

**8. At 340x480 the composer scrolls away and new answers land off-screen.** Should-fix. V in the CSS, S live. New (the layout check is already planned, plan section 6).
- Where: `:host` has no height (css:1-3), so `.abp-panel { height:100% }` (css:10) resolves to auto. `.abp-body` (css:33-39) then never becomes the scroll box. Nothing scrolls to the newest turn.
- Scenario: after two briefs the composer is below the fold, and the third answer appears out of view.
- Fix: make `:host` and `.abp-panel` `height:100%` with `min-height:0` on `.abp-body`. After `_push`, scroll the new turn into view.
- Skill: none covers panel layout. This is reviewer judgement from the CSS.

**9. Earlier briefs can show another account's history.** Should-fix. V, new.
- Where: `_syncContext` clears `pageAccount` but not `historyItems` (js:288-292). `_loadHistory` (js:660-677) has no stale-reply guard. The list never names its account (html:26-39). `historyAccountId` (js:648-650) is unused.
- Scenario: go from Account A to Home. A's "Earlier briefs" stay visible with no label. Go quickly A to B, and if A's reply lands last, B shows A's history.
- Fix: clear `historyItems` in `_syncContext`, guard on a request token the way `_lastContextId` does, and label the list with the account name.
- Skill: none states a stale-reply rule. This is reviewer judgement.

**10. Unexpected Apex errors reach the user raw.** Should-fix. S, new.
- Where: `AccountBriefPanelController.resolve`, `getBrief`, `explore` and `history` (controller:21, 27, 33, 58) do not catch unexpected exceptions. `drill` rethrows `QueryException` text verbatim (controller:45). `errorText` shows `body.message` as-is (js:42-50).
- Scenario: a limit or query failure shows platform text or a generic "internal server error" instead of the fixed sentence that ARCHITECTURE.md's Rules require ("ERROR carry fixed user-facing text").
- Fix: wrap each controller method in `catch (Exception e)`, log the detail, and throw an `AuraHandledException` with one fixed line.
- Skill: experience-lwc-generate `assets/apex-controller/LwcController.cls` (the AuraHandledException pattern). Apex itself is OPS-11's lane; this is the contract as the panel sees it.

**11. The hotkey matches too broadly.** Should-fix. V, new.
- Where: js:155-157.
- What is wrong, case by case:
  - On macOS it accepts `ctrlKey`, which hijacks Ctrl-K ("delete to end of line") in every text field in the app.
  - It ignores Shift and Alt, so Cmd-Shift-K also triggers it.
  - `event.key` fails on non-Latin layouts: a Cyrillic layout reports `л`.
  - Inside the composer, keydown never reaches `document` (js:204), so Ctrl-K there falls through to the browser. Chrome and Firefox on Windows focus their own search box.
  - The `document` Escape branch (js:158-162) is unreachable: the trap or the composer always consumes Esc first.
- Fix: use `metaKey` on Mac and `ctrlKey` elsewhere, test `event.code === 'KeyK'` with no Shift or Alt, and handle Cmd-K in `handleComposerKeydown` too. Delete the dead branch.
- Skill: none covers shortcuts directly. This is reviewer judgement against the card's hotkey checklist.

**12. Hand-rolled controls where base components exist.** Should-fix. V, new.
- Where:
  - raw `<button class="slds-button">` (html:7, 12, 20, 56, 60, 82, 115, 136, 172, 226, 247)
  - raw `<textarea>` (html:244)
  - hand-built tables (html:92, 191), badges (js:36-40), breadcrumbs (html:54-63)
  - `<details>` as an accordion (html:16, 27, 162, 215)
  - `toLocaleString()` for dates (js:668), which ignores the user's Salesforce locale
- Fix: switch to `lightning-button` / `lightning-button-stateful` (chips), `lightning-textarea` (its keydown is composed, so `stopPropagation` still works), `lightning-badge`, `lightning-breadcrumbs`, `lightning-accordion` with `allow-multiple-sections-open`, and `lightning-formatted-date-time`. Consider `lightning-datatable` for results, which also addresses finding 7.
- Skill: experience-lwc-base-components-integrate (component and attribute names confirmed with its `extract-component-docs.sh`); experience-lwc-generate ("prefer platform base components").

**13. Styling hooks that are not SLDS 2 hooks, which may fail contrast in dark theme.** Should-fix. S, new. WCAG 1.4.3.
- Where: `--slds-g-color-error-base-40` (css:59) and `--slds-g-color-border-base-1` (css:110, 114) are not in the skill's SLDS 2 hook list (`scripts/slds_data/styling_hooks.json`). If they do not resolve, the hex fallbacks apply.
- Contrast (the a11y skill's `contrast-ratio.py`): `#ea001e` on white is 4.65:1 (pass). On `#242424`, my assumption for a dark surface (not measured), it is 3.34:1 (fail).
- Fix: use `--slds-g-color-error-1` and `--slds-g-color-border-1`.
- Skill: experience-lwc-generate (`scoring-and-testing.md` Dark Mode); experience-accessibility-validate `sc-1-4-3-contrast.md`.

**14. Smaller items.** Nits. V, new unless marked.
- **(a)** `apiVersion` 64.0 against the project's 68.0. The generate skill's `minApiVersion` is 66.0. Already planned (plan section 3).
- **(b)** Enter submits mid-IME-composition: there is no `event.isComposing` check (js:206). Japanese and Chinese users send half-typed text. Arguably should-fix.
- **(c)** `summary.abp-section-head { display:flex }` (css:62-72) removes the disclosure triangle.
- **(d)** `breadcrumbs[].current` (js:553) is never bound, so the last crumb lacks `aria-current="page"`.
- **(e)** `'Account'` is a string literal (js:275). The LDS skill prefers `@salesforce/schema/Account`.
- **(f)** The app has no `brand` block, which platform-custom-application-generate calls "highly recommended". Otherwise the app passes that skill's checklist: Lightning, Standard nav, Large, a description, the utility bar, and no custom record pages, so no `actionOverrides` are needed.
- **(g)** AMBIGUOUS candidate buttons show raw 18-character Ids (html:138).

**Checked and clean:**
- No `innerHTML` or `lwc:dom`; everything is bound as text.
- Drill Ids come only from Apex section text and result rows.
- Follow-ups are model-written (js:517), but they render as text and only resubmit as a question when the user clicks one (js:398-400).
- Navigation goes only through `NavigationMixin` with a record Id.
- LWS lws-001 to lws-023b: no pattern matched in any bundle file. `document.addEventListener('keydown')` is allowed.
- Listener and subscription cleanup in `disconnectedCallback` (js:125-135) is correct, and `_trapKeydown` is a stable arrow function.
- `_syncContext` discards stale resolves (js:295).
- Cacheable versus imperative is used correctly: `sources` and `agentId` are cacheable wires; `getBrief` and `explore` are imperative because they call out and write.
- The flexipage's decorators use `<type>decorator</type>` as the flexipage skill requires, and its identifiers are unique.

## Tests I would require, most valuable first

The Jest setup is already planned (plan section 3). `.forceignore` ignoring `**/__tests__/**` is correct; keep it. `lightning/platformUtilityBarApi` and `lightning/accApi` need `moduleNameMapper` stubs.

1. Concurrency: a second submit, candidate click or message while pending does not call Apex. A late reply after a context change is discarded.
2. Rendering safety: an answer, section line or follow-up containing `<img src=x onerror=...>` renders as text and creates no element.
3. Turn mapping: RESOLVED briefs; AMBIGUOUS parses candidate Ids; NOT_FOUND and ERROR show `message` verbatim; `ignored` is listed.
4. Errors: a rejected Apex promise produces an error turn with `body.message`, and the fallback text when there is none.
5. Hotkey: Cmd-K calls `open(utilityId)` and focuses the composer; `defaultPrevented` is respected; after removal from the DOM, Cmd-K does nothing.
6. Message channel: a prompt runs with the message's `recordId` as context, which is cleared afterwards; an Account Id alone briefs that account.
7. History: it loads on an Account page, clears on leaving, and ignores stale replies.
8. Drill: click, Enter and Space drill a row; crumbs pop the stack; "View record" navigates.
9. Keyboard and focus: Esc minimizes and focus returns (after findings 5 and 6).
10. `@sa11y/jest` `toBeAccessible()` on the empty state, a brief turn and the drill view (experience-lwc-accessibility-jest-run).

## Config notes

- **js-meta.xml:** `isExposed=true` and `masterLabel` are correct. Targets: see finding 3. If RecordPage stays, add `<targetConfig targets="lightning__RecordPage"><objects><object>Account</object></objects>`.
- **`force-app/main/default/lwc/jsconfig.json` (untracked):** the Salesforce VS Code extension generates it from `.sfdx` typings. It is machine-local and `.forceignore` already keeps it out of deploys. **Ignore it**: add `**/lwc/jsconfig.json` to `.gitignore`. Do not commit it, and do not delete it, because the extension regenerates it.
- **No ESLint config:** there is no `.eslintrc.json` and no `package.json`, so the `eslint-disable @lwc/lwc/...` comment (js:228) refers to a rule nothing runs. The planned Jest card should add both (plan section 3).

## experience-lwc-generate score

The skill's `validate_slds.py` scored HTML 153/165 and CSS and JS 165/165. That number is not reliable:
- It flagged valid SLDS classes as unknown (`slds-breadcrumb`, `slds-breadcrumb__item`, `slds-line-height_reset`).
- It passed CSS hooks that are absent from its own SLDS 2 list.
- It does not inspect behaviour at all.

`template_validator.py` reported no anti-patterns. My manual score on the 165-point rubric in `scoring-and-testing.md`:

| Category | Score | Reason |
|---|---|---|
| SLDS class usage | 23/25 | Valid classes throughout; some redundant padding overrides on `slds-button` |
| Accessibility | 15/25 | No live region, focus lost, Tab trap, clickable rows with no role (findings 4-7) |
| Dark mode | 18/25 | No raw colours, but the hooks fall back to hex (finding 13) |
| SLDS migration | 16/20 | SLDS-1-era hook names |
| Styling hooks | 14/20 | Hooks with fallbacks are used, but not SLDS 2 names |
| Component structure | 7/15 | Almost no `lightning-*` (finding 12) |
| Performance | 9/10 | Keyed loops and a guarded `renderedCallback`; getters rebuild chips each render |
| PICKLES | 18/25 | Right wire/imperative split, LMS and with-sharing Apex; no tests, guard gaps |
| **Total** | **120/165** | Functional, needs SLDS cleanup (3 stars) |

## Deliberate differences

**Apex for every read instead of LDS/UI API.** experience-lds-best-practices-apply section 4 would use `getRecord` for the single-record drill. ARCHITECTURE.md records one Apex engine, catalog-gated and describe-checked, shared with the agent. Switching to LDS would split the visibility rules between the panel and the agent. I agree with keeping Apex. No LDS cache is mixed in, so the skill's section 3 (refresh after mutation) does not apply.

**Status-based results.** The panel branches on `status` (RESOLVED, AMBIGUOUS, NOT_FOUND, OK, EMPTY, ERROR) rather than `isSuccess`/`errorMessage`. This is consistent with ARCHITECTURE.md, and I agree. Finding 10 is about unexpected exceptions only.

**"No Flows, no prompt templates"** does not touch this lane.

## Not reviewed, and why

- **Live behaviour:** the browser tools were out of scope. That covers `eager`, focus after minimize, the 340x480 layout, dark theme and the Chrome/Windows Ctrl-K conflict. Plan section 6 already lists the Cmd/Ctrl-K, focus-trap and 340px checks.
- **`lightning/accApi` open/execute semantics:** no installed skill documents it, and plan section 5 replaces this hand-off.
- **Apex internals beyond the contract:** OPS-11's lane.
- **Running as a non-admin user.**
- **RTL:** experience-lwc-rtl-validate is not in this lane.
- **Bare `accountBriefPanel` against the `c:` prefix** the flexipage skill uses: it deployed, and I did not compare it against an org retrieve.

**How the skills were loaded:** experience-lds-best-practices-apply, platform-custom-application-generate and platform-flexipage-generate were loaded with the Skill tool. experience-lwc-generate, experience-accessibility-validate, experience-lwc-security-validate and experience-lwc-base-components-integrate were read, with their scripts, from the plugin cache.
