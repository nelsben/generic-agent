# LWC re-review: accountBriefPanel, its Jest tests and the Playwright suite

Reviewed 2026-11-11 (OPS-17), against main after FE-3, FE-4, FE-6 and the OPS-20 deploy. This is a review only: no code was changed, nothing was deployed, and the e2e suite was not re-run (each run makes model calls and writes brief memory rows). Earlier review: docs/reviews/lwc-review.md (OPS-12).

Short names, all in force-app/main/default/lwc/accountBriefPanel/ unless noted:
- `js`, `html`, `css` and `meta` are the bundle's .js, .html, .css and .js-meta.xml files.
- `test` is `__tests__/accountBriefPanel.test.js`.
- `flexipage` is Account_Brief_UtilityBar.flexipage-meta.xml, and `controller` is AccountBriefPanelController.cls.
- `spec` is e2e/panel.spec.js, and `panel.js` is e2e/support/panel.js.

Tags: V = verified in the code, S = suspected (depends on runtime or platform behaviour).

## Verdict

**Ready with fixes.** The panel now does what the first review asked for:
- The shortcut works before anyone opens the panel, and only the newest request is ever shown.
- Screen-reader users hear when an answer arrives, and keyboard users are never trapped.
- Esc puts the cursor back where the user was.
- Errors show one fixed sentence, not raw system text.

Every earlier finding is fixed or reduced, and the live suite passed 8 of 8 as the admin user. Nothing found here is a blocker. Five things should be fixed before the panel is shown widely:
- One drill view shows raw record Ids and technical field names.
- A number in a note can become a button that fails when clicked.
- A question asked after a brief is quietly tied to that account.
- Focus return is proven for one kind of page element only.
- Drill lines may be smaller click targets than WCAG 2.2 allows.

Two gaps in the evidence remain: no one has run the panel as a non-admin user, and no real MCP call has been made.

## Earlier findings

| # | Earlier finding | Status | Decided by |
|---|---|---|---|
| 1 | Hotkey and channel inert until first open | fixed | flexipage:8-10 (`eager` true); live spec 1 pass (docs/research/deploy-verify.md:27) |
| 2 | One-request guard bypassed | fixed (new design: latest wins, a repeat is ignored) | js:435-471; every entry point calls `_request` (js:495, 506, 526, 542, 781, 914); test:161-283; live spec 5 (deploy-verify.md:31) |
| 3 | Two live instances via the RecordPage target | fixed | meta:7-9 (UtilityBar only) |
| 4 | No screen-reader announcement | fixed | html:4 live region; js:445, 450, 463; test:746-760; live spec 3 (deploy-verify.md:29) |
| 5 | Focus lost on Esc, close and drill | fixed for light-DOM anchors; see N4 | js:258-301, 753-767, 800; test:524-557, 636-718; live spec 2 (deploy-verify.md:28) |
| 6 | Tab trap in a non-modal panel | changed: the trap is gone (js:223-229), but every result row is still a tab stop (html:112, 214) | test:720-728; live spec 2, Tab step |
| 7 | Clickable rows with no role or name | fixed | a real button in the first cell (html:111-113, 213-215); no `tr[tabindex]` (test:534) |
| 8 | Composer scrolls away at 340x480 | fixed | css:2-5, 12, 41-47; scroll into view js:180-186; live spec 4 (deploy-verify.md:30) |
| 9 | Another account's history shown | fixed | cleared on context change js:373-376; stale guard js:861-863; labelled js:845-848; test:476-510 |
| 10 | Unexpected Apex errors reach the user raw | fixed inside the methods; residual in N2 | controller:28-33 and its siblings throw the fixed line; js:56-60 |
| 11 | Hotkey matches too broadly | fixed | js:96-102 (`code`, no Shift or Alt, Cmd on Mac only); js:235-238 (inside the composer); dead branch removed; test:391-444 |
| 12 | Hand-rolled controls | changed: see the note below the table | html:10-69, 98, 112, 148, 176, 180, 200, 214, 243, 262 |
| 13 | Non-SLDS-2 hooks, dark-theme contrast | fixed (hooks); dark theme still unmeasured | css:67, 109, 113 use `--slds-g-color-error-1` and `--slds-g-color-border-1`, both in `styling_hooks.json` |
| 14a | apiVersion 64.0 | fixed | meta:3 (68.0) |
| 14b | Enter submits mid-IME | fixed (Esc is still unguarded, N9) | js:244; test:730-741 |
| 14c | Disclosure triangle removed | fixed | `lightning-accordion` replaces `<details>` (html:17, 31, 172, 229) |
| 14d | Last crumb lacks `aria-current` | changed: now `lightning-breadcrumbs`; whether it marks the current crumb is not verified | html:63-69 |
| 14e | `'Account'` string literal | fixed | js:25, 359 |
| 14f | App has no `brand` block | open | Account_Brief.app-meta.xml:1-18 |
| 14g | AMBIGUOUS buttons show raw Ids | changed: the Id is hidden unless two candidates read the same, when it is added back | js:592-604 |

Finding 12 in detail:
- Now base components: the brief bar, chips, accordions, badges, breadcrumbs, the composer textarea and dates (html:10-69, 176, 262).
- Still raw `slds-button`: candidates, follow-ups, drill lines and drill rows (html:112, 148, 180, 214, 243). The tables are still hand-built (html:98, 200).

**The two FE-4 defects.** The FE-4 card's Review names both. e2e/README.md no longer records them: FE-6 rewrote it, and README:76-79 now describes the fixed behaviour.
- **Esc lost focus to the platform's late minimize.**
  - Fixed by a focus guard (js:303-333). Jest covers a simulated late steal (test:651-718).
  - Live spec 2 passes (deploy-verify.md:28). Residual: N4.
- **No brief line could be drilled.**
  - Fixed: Apex appends ` — <Id>` to each one-record line (AccountBriefSection.cls:62-74), and the panel cuts that Id off (js:74-88).
  - Live spec 7 passes (deploy-verify.md:33). Residual: N2.

## New findings

There are no blockers.

**N1. Drill views show raw record Ids and API field names.** Should-fix. V.
- Where:
  - `_table` makes column 0 the drill button and uses `rs.columns` as headers (js:691-713).
  - Every ExploreCatalog CURATED entry starts with `'Id'` (ExploreCatalog.cls:16-50), and a related-object drill selects every catalog path (DataExplorer.cls:227). So column 0 is `Id`.
  - The record card drops only `Id` (js:827), so lookups such as `OwnerId` show raw values.
  - `ResultSet.labels` exists for display (ExploreQuery.cls:38-39), but the panel never reads it.
- Scenario: a user drills a deal, then clicks the "Contact" chip.
  - The first header reads "Id", and each row's button text is an 18-character record Id. Other headers read `Account.Name` or `StageName`.
  - This breaks FE-6's rule that Ids are never visible text. It would also put Ids into FE-7's screenshots, which its privacy rule forbids.
- Why the tests miss it: the Jest related-drill fixture has only a `Name` column (test:519-521), and spec 7 drills a record, not a related list.
- Fix:
  - In `_table`, hide `Id` and other Id-kind columns (the row keeps `row.id`), label the button from the first remaining column, and use `labels` for headers.
  - Hide or resolve lookup Ids in the record card.
- Skill: experience-accessibility-validate `reviewers/sc-2-4-6-headings-labels.md` (headers must describe their content).

**N2. An Id-shaped number in a brief line becomes a drill button that fails.** Should-fix. V (the button); S (the wording of the error).
- Where:
  - When a line has no trailing ` — <Id>`, `briefLine` falls back to `idInLine` (js:82-88), which matches any 18-character token that starts with a digit (js:39).
  - I ran the regex on a continuation line holding an 18-digit reference number. It returned that number as the drill Id.
  - test:593-619 asserts only that the first line drills. It never checks that the second line is not a button.
- Scenario:
  - A call note quotes an 18-digit order number, so that line renders as a button.
  - A click sends the number as `drill`'s `Id` parameter (controller:64). The conversion happens before the method body runs, so the fixed-text catch (controller:66-76) never applies.
  - `errorText` then shows whatever `body.message` the platform sends (js:56-60). The same path shows platform text for any failure before a method runs, such as missing class access.
- Fix: drill brief lines only on the trailing Id, which every one-record source now writes (AccountBriefSection.cls:62-74). Show `ERROR_TEXT` unless the error is a handled one.

**N3. A question after a brief is silently scoped to that account.** Should-fix. V (the code); S (how far the model narrows its answer).
- Where: `contextRecordId` falls back to `briefedAccount` on any page without a record (js:363-365, 505). Nothing on screen says so.
- Scenario:
  - On Home, a user types `/brief Acme`, then asks "How many open cases do we have?".
  - `explore` receives Acme as the open record. The model may answer for Acme only, and the user reads the answer as org-wide.
  - test:449-460 proves that the context clears after a message, but only because no brief ran first.
- Fix: show the context as a removable chip ("About: Acme"), or use only the page's record.

**N4. Focus return is proven for one kind of element only.** Should-fix. S.
- Where:
  - `_openAndFocus` records `document.activeElement` (js:261-263). When focus is inside a shadow tree, that is the outermost shadow host, not the focused field.
  - `_close` focuses that host (js:292-294), and the guard re-focuses it every 50 ms for 2 s (js:312-318). `focus()` does nothing on a host that neither delegates focus nor has a tabindex.
  - experience-lwc-generate `references/accessibility-guide.md:302` uses the same pattern, so this is a platform risk, not a departure from the skill.
- Scenario 1: a user in an input inside a custom LWC on the record page presses Cmd-K, then Esc. Focus ends on `body`. Spec 2 starts only from the global header's Search button (spec:24-26).
- Scenario 2:
  - `_returnFocus` is cleared only in `_close` (js:281-284).
  - A user opens the panel with Cmd-K and minimizes it with the utility's own button. Later they open it by mouse and press Esc.
  - Focus jumps to the old element, and the guard holds it there for 2 s.
- Fix:
  - Clear `_returnFocus` when the panel is minimized another way.
  - Add an e2e step that starts from a field inside an LWC.
  - If the host cannot take focus, fall back to the utility bar button, not `body`.

**N5. Drill lines may miss WCAG 2.2 target size (2.5.8 AA).** Should-fix. S.
- Where: `.abp-line-link` is an `slds-button` with `line-height: 1.375` (css:97-102). Stacked one-line buttons are about 18 px tall, with no gap between them.
- Scenario:
  - Adjacent line buttons in an open "Open deals" section fail both the 24 px size test and the spacing test.
  - axe's `target-size` rule (`wcag22aa`, spec:21) never saw them. Spec 8 scans the brief with every section collapsed (spec:237-238), and the drill state with the conversation hidden (js:722-724).
- Fix: give line buttons a 24 px minimum height or a gap, and scan once with a section open.
- Skill: no installed reference covers 2.5.8; experience-lwc-generate `references/slds-blueprints.json` only says "adequate touch target size". This is reviewer judgement.

**N6. Latest-wins is client-side only.** Note. V.
- A superseded reply is never shown (js:449-470), but the server still finishes the work.
- A brief overtaken by a question still makes its model call and writes its memory row (ARCHITECTURE.md:69; js:608-616). Send stays enabled while a request is pending (js:422-424).
- Scenario: "Earlier briefs" later lists a brief the user never saw, and the org paid for it. Document this, or disable Send while a brief runs.

**N7. Any component can start a paid request.** Note. V.
- `AccountBriefOpen` is exposed (AccountBriefOpen.messageChannel-meta.xml:4). The panel opens, takes focus and runs the prompt with no user gesture (js:902-925).
- Nothing flows back to the publisher, and queries run as the user. A looping publisher still costs one model call per message, plus a memory row per `/brief`.

**N8. Background cost and growth.** Note. V.
- The item is eager, so every Account page view in the app runs `resolve` and `history`, even if the panel is never opened (js:142-146, 380, 859).
- `turns` is never trimmed (js:562-566). Each answer can add a table of up to 200 buttons.

**N9. Esc during IME composition minimizes the panel.** Note. S.
- js:240 has no `isComposing` check, unlike Enter (js:244).
- Scenario: a Japanese user presses Esc to cancel a conversion, and the panel closes.

**N10. "Ask the agent" is unproven.** Note. S.
- The button shows whenever `agentId()` finds the bot (controller:104-114). Holding the agent permission set is not required.
- `handleAskAgent` (js:886-897) is outside `_request`, and neither suite covers it.
- The agent was not deployed (deploy-verify.md:11), and no installed skill documents `lightning/accApi`.

**N11. The e2e harness is tied to one machine and one user.** Note. V.
- The sf path and the account name are hard-coded (e2e/support/env.js:7-8). On Apple Silicon Homebrew, Linux or CI, setup stops with "The sf CLI was not found" (e2e/global-setup.js:54-56).
- The hotkey follows the platform (panel.js:69-76), so the Ctrl-K path has never run live: OPS-20 ran on a Mac.
- There is no CI job, and each run spends money and leaves memory rows (e2e/README.md:36-55).

## Security and access

- **Rendering:**
  - Model and record text is bound as text only: no `innerHTML`, no `lwc:dom` and no model-supplied URL.
  - test:286-304 proves that markup renders as text.
- **LWS, rechecked:** the code added since OPS-12 passes experience-lwc-security-validate `references/security-analysis.md`.
  - The timers take function arguments (js:273, 312, 320), which the reference allows (:88).
  - The capture listeners go on `document`, not `document.body` (:170-186). `_stopFocusGuard` removes them, and `disconnectedCallback` calls it (js:190, 332).
- **Visibility:** the panel adds none.
  - The controller is `with sharing` and only delegates (controller:11).
  - Explore runs in user mode against a describe-checked catalog (ARCHITECTURE.md:90-97).
- **Permission set:** Account_Brief_Data_Access grants the app, five Apex classes and read-only access to Account_Brief_Session__c.
  - Memory is still written, because AccountBriefMemory uses `SYSTEM_MODE` DML (AccountBriefMemory.cls:117-124).
  - That is a deliberate design, and the Apex lane (OPS-16) owns it.
- **Not proven:** the non-admin run (FE-5 is queued). Until it happens, no one has seen what a Standard User gets from `history`, `agentId` or a catalog trimmed by describe.

## Limits and failure handling

- **Limits:** each request is one synchronous Apex transaction, and the panel never loops Apex calls.
  - Explore is capped at 5 turns, 4 queries and 200 rows (ARCHITECTURE.md:84-92).
  - The total callout time of a slow explore has not been measured.
  - Bulk behaviour does not apply to a single-user UI, apart from N8.
- **What the user sees on failure:**
  - An unexpected Apex error shows the fixed line, in the turn and in the live region (js:453-463; test:363-380).
  - NOT_FOUND and ERROR text shows verbatim (js:580-582, 626).
  - A drill error appears in a `role="alert"` notice (html:51-53; js:785-787). Jest never exercises this path.
  - A failed page-context resolve or `history` call shows nothing (js:387-389, 873-877), and the brief button still works.
  - An error raised before a controller method runs shows platform text (N2).

## What is proven, and what is not

- **Jest (my own run):** 36 of 36 pass, with 89.5% line coverage of the panel's .js file.
  - Not covered: the "Brief this account" handler (js:521-538), the include chips (js:413-418), Ask the agent (js:886-897), a superseded brief (js:615) and the history error path (js:874-875).
  - sa11y `toBeAccessible` passes in the empty, brief and drill states (test:794-823).
  - jsdom cannot measure layout, contrast or target size. The suite runs in jsdom, as experience-lwc-accessibility-jest-run `SKILL.md:120` requires.
- **Playwright (OPS-20's run, not mine):** one admin run in Chromium on a Mac passed 8 of 8 (deploy-verify.md:23-36).
  - The layer has not changed since that deploy: `git diff feb0d7b` is empty for these paths.
  - The axe scans covered collapsed sections and the drill view only. They never saw expanded sections, result tables, candidates, follow-ups or error turns.
- **Not proven:**
  - any run as a non-admin user (FE-5 is queued) and any real MCP call;
  - the Ctrl-K path on Windows or Linux;
  - dark theme and its contrast;
  - focus return from inside an LWC (N4);
  - the agent bridge (N10);
  - real screen-reader output: the live region was asserted in the DOM only;
  - RTL, and mobile (the app is Large only).

## Can a new team adopt this pattern?

**Yes, with two cautions.** The parts that carry over:
- one Apex door that delegates to the agent's engine;
- one `_request` path with tokens;
- an eager utility item;
- text-only rendering;
- a Jest suite plus a live Playwright suite whose test hooks (`data-testid`) change nothing users see.

The two cautions:
- **The focus guard works around platform timing.** It polls for 2 s after minimize (js:41-46, 303-333), so a platform release could break it. Keep spec 2 in every regression run.
- **Drilling relies on a text convention.**
  - Apex appends ` — <Id>`, and the regex accepts only Ids that start with a digit (js:39, 75). Custom-object Ids usually start with a letter.
  - So a team that adds a custom-object source, as ARCHITECTURE.md:40-46 describes, gets lines that do not drill and that show the Id as text.
  - A structured `recordId` on each line would remove this and N2.

## Skills used

All are under `~/.claude/plugins/cache/salesforce/`, read from that cache.
- experience-lwc/0.3.0/skills/:
  - experience-lwc-generate: `references/accessibility-guide.md`, `references/lms-guide.md`, `references/slds-blueprints.json` and `scripts/slds_data/styling_hooks.json`.
  - experience-accessibility-validate: `reviewers/sc-1-3-1-ii-tables.md`, `reviewers/sc-2-4-6-headings-labels.md`, `vision/sc-1-4-1-use-of-color.md` and `scripts/contrast-ratio.py`. The drill line's default link blue measures 3.83:1 against body text. That is above the 3:1 sc-1-4-1 asks for, so it is not a finding.
  - experience-lwc-security-validate: `references/security-analysis.md`.
  - experience-lwc-accessibility-jest-run and experience-lwc-runtime-observe: `SKILL.md` of each.
- salesforce-development/2.7.0/skills/:
  - platform-flexipage-generate: `references/xml_rules.md` (`decorator` is valid only on UtilityBar pages).
  - platform-custom-application-generate: `SKILL.md` (the brand block, 14f).
