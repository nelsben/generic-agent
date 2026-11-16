# FR2 panel discovery: what the hotkey panel and its surfaces could add later (FE-17)

- Date: 2026-11-12. Docs only: no org was opened, nobody signed in or out, no user was created, and nothing was
  deployed.
- What this page is for: a list of eleven things the compact window, the rail and the conversation they share could
  add after FR2. Each one is ranked by its value to a rep and by its effort. Each has a proposed card, so Ben can pick
  by id (P1 to P11). The brain cuts cards only for the ones he picks
  ([feature-revision-2.md](../plans/feature-revision-2.md#dispatch-rules)).
- Ledger rows: F60 (snap in, hide, display different chats), F62 (the two open limits: the panel only works in apps
  whose utility bar holds it, and it is desktop only) and F63 (what to add later). Both F62 limits are answered
  here: see P2 and P10.
- Read with [fr2-design.md](../plans/fr2-design.md), [the surfaces spike](fr2-surfaces-spike.md) (`OPS-29`),
  [pattern 03](../patterns/03-hotkey-panel.md), [pattern 05](../patterns/05-conversation-memory.md) and
  [pattern 11](../patterns/11-voice-input.md).

## How this was checked

- **The build each idea is judged against.** Every idea is judged against the panel as FR2 leaves it, not as it is
  today. `FE-12` adds the shared conversation component (`customerSummaryConversation`), with a public interface:
  `recordId`, `sessionId`, `focusComposer()` and `sessionchange`. `FE-13` moves the compact window onto the page
  body, with a launcher at the bottom right. `FE-22` adds the sessions control, the scope chip and cards. `FE-15`
  adds the rail. `FE-14` adds the write actions. `BE-26` adds conversation history and `BE-35` adds customer
  outcomes. Nothing here proposes again what those cards build.
- **The spike changes several answers.** The compact window and the rail mount on `document.body` from an eager
  utility item. An LWC cannot be a background utility item. Lightning hides a closed utility panel with
  `display: none`, but the component in it stays alive. All three are verified in `OPS-29`. So resizing, the ready
  signal and pop-out are about our own window, not the utility panel.
- **The panel's code today** (read in `customerSummaryPanel.js`):
  - `/brief <name>` is already a composer command.
  - The panel already follows `CurrentPageReference`, but only on Account pages. On an opportunity, contact or case
    page, it shows no Summarize button and loads no history. A question there carries the page's own record as
    context.
  - The resolver accepts only an Account Id.
  - The app's `formFactors` is `Large` only.
- **Status words**, as in `OPS-29`:
  - verified: seen in the org, in a capture or in a logged measurement, by `OPS-29` or an earlier card.
  - documented: a published Salesforce page says so.
  - unverified: an inference, or a point where the docs disagree or say nothing.

  Every unverified point a candidate rests on is the first line of its card's done-when, so the build proves it
  before relying on it.
- **Sources.** developer.salesforce.com refused automated fetches in this run (HTTP 403). The pages cited below
  were not opened. Each "documented" line rests on that page's published text as the search index shows it, with the
  link given. A builder opens the page before building on it.
- **Effort**, read from the cost of similar FR2 cards:
  - S: one component change and its tests, about $6 to $8.
  - M: a new method or field, or a new page that hosts the existing conversation component, plus the component
    work, about $12 to $15.
  - L: a new device, or a rollout into apps outside the repo, each with a proof first and e2e in the org, $20 or
    more.

  These are estimates, not quotes. The brain prices a card when it cuts it.
- **The two skills the card names** were loaded:
  - `salesforce-development:platform-capability-search`: its plugin match printed "No matching uninstalled plugin
    found for that request."
  - `experience-lwc:experience-lwc-design-generate` is a build workflow. This page only uses its parts for the
    proposed cards: the states, the accessibility, the security pass and the Jest tests.

## The list at a glance

| Id | Candidate | Value to a rep | Effort | Risk | Rank |
|---|---|---|---|---|---|
| P1 | The panel follows the record to its account | High: every page, every rep | S | Low | 1 |
| P2 | The panel in every app (standard Sales and Service apps, or a one-step add) | High: it is where reps already work | L | Medium | 2 |
| P3 | Switch chats across accounts: recent and pinned, one key away | High: Ben's "display different chats" | M | Low | 3 |
| P4 | A signal when a slow answer is ready while the panel is hidden | Medium-high: summaries take a while | S | Low | 4 |
| P5 | Keep an answer on the account (`FE-23`, already cut) | Medium: closes principle 4 | S | Low | 5 |
| P6 | Slash commands for the skills and actions | Medium: speed for typists, and the skills become discoverable | S | Low | 6 |
| P7 | Copy an answer as plain text | Medium: answers go into emails and notes | S | Medium (clipboard unverified) | 7 |
| P8 | Open the conversation in its own browser tab (the pop-out) | Medium: a second monitor, long work | M | Medium | 8 |
| P9 | Resize the compact window and the rail, remembered | Low-medium | S | Low | 9 |
| P10 | The Salesforce mobile app | High for field sellers, but no hotkey and voice unproven there | L | High | 10 |
| P11 | A list of the panel's keyboard shortcuts | Low-medium: teaches the keys | S | Low | 11 |

## Candidates

### P1. The panel follows the record to its account

- **The rep's problem:** on an opportunity, case or contact page, the panel does not know which account the rep is
  working. So there is no "Summarize <Account>", no earlier summaries, and no account scope for a question.
- **How it would work:**
  - On an Opportunity, Contact or Case page, the frame reads that record's `AccountId` and uses it as the account.
    It reads it through Lightning Data Service (`getRecord` with that one field), so no Apex is needed. The
    Summarize button, the history and `FE-22`'s scope chip ("About <Account>") then work as they do on the account
    page.
  - When the rep opens a record of a different account while a thread is open, the thread is not switched silently.
    One line above the composer offers "Now on <Account B>. Switch?". Accepting starts or reopens that account's
    thread through the sessions control. Ignoring it keeps the current thread.
  - With no thread open, the panel follows the page at once.
- **What Lightning allows:**
  - `CurrentPageReference` in a utility item is verified: the panel uses it today, and the e2e suite drives it.
  - `getRecord` with `AccountId` on these three objects is documented
    ([getRecord](https://developer.salesforce.com/docs/platform/lwc/guide/reference-wire-adapters-record.html)).
  - Whether a utility item in a console app gets the page reference of the focused workspace tab is unverified.
    `OPS-29` tested standard navigation only.
- **Effort:** S.
- **Risk:** low. A rep without read access to the parent account gets no account context, and the panel falls back
  to the record alone. The switch offer must not fire on every subtab in a console.
- **Depends on:** `FE-12` (the frame passes `recordId` into the conversation), `FE-22` (the scope chip and the
  sessions control) and `FE-13`.
- **Proposed card:** "FR2+: the panel follows the record to its account — opportunity, contact and case pages
  resolve to their account, and a new account offers to switch the thread"
  - Scope: `force-app/main/default/lwc/customerSummaryPanel/**`, `force-app/main/default/lwc/customerSummaryRail/**`,
    `force-app/main/default/lwc/customerSummaryConversation/**`, `e2e/**`, `docs/patterns/03-hotkey-panel.md`.
  - Done when:
    1. Proof first: in a console-navigation app in `agent-probe`, record whether the utility item's
       `CurrentPageReference` follows the focused workspace tab. If no console app is at hand, the card limits itself
       to standard navigation and says so.
    2. On an opportunity, contact and case page the Summarize button names the parent account, and history and the
       scope chip follow it. A record with no readable account falls back to the record alone. Jest covers all four
       cases.
    3. Opening another account's record while a thread is open shows the switch offer, and the thread changes only
       when the rep accepts. One e2e spec moves from an account to an opportunity of another account.
    4. The FE-12 interface is unchanged, and pattern 03 says what the panel follows, including in a console app
       where line 1 proved it.

### P2. The panel in every app

- **The rep's problem:** the hotkey and the launcher exist only in the Customer Summary app (F62). Reps live in the
  standard Sales app or the Service Console. Today they would have to switch apps to use the panel.
- **How it would work:** two parts.
  - **(a) A one-step add for any app.** A script takes an app's name and finds the utility bar that app uses (an
    app has at most one). It adds the `customerSummaryPanel` item, set to load in the background, to the end of
    that bar's items. It validates, then quick deploys. It never replaces the bar, because the bar may already hold
    a softphone or other utilities.
  - **(b) The standard Sales and Service Console apps** get the same treatment, if their utility bar can be set by
    deploy. If it cannot, the guide gives the App Manager steps (Edit, then Utility Items, then Add, then the
    Customer Summary panel, then "Start automatically").
  - The launcher's corner follows the bar's alignment, as `OPS-29` recommends.
- **What Lightning allows:**
  - A `CustomApplication` names one `utilityBar`. A utility bar made through the API can be shared by several
    apps, so a change to it shows in every app that uses it. Documented:
    [CustomApplication](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_customapplication.htm),
    and the utility bar API overview in the
    [Console Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_console.meta/api_console/sforce_api_console_methods_lightning_utilityBarAPI.htm).
  - An admin can edit the standard Sales app's utility items in App Manager. Documented: the Trailhead unit
    [Display a Flow on Every Page](https://trailhead.salesforce.com/modules/screen_flow_distribution/units/screen_flow_distribution_everypage).
  - Whether a standard app's utility bar can be deployed as metadata is unverified.
  - The body mount and both hotkeys in a console-navigation app are unverified, because `OPS-29` used standard
    navigation. So is the launcher beside a real softphone (`OPS-29` used a stand-in).
- **Effort:** L: a rollout into apps outside the repo, with a proof on the standard apps first.
- **Risk:** medium.
  - Changing another app's utility bar is a change to a bar other teams own, and it shows in every app sharing that
    bar.
  - In a production-classified org this is a deploy under the standing approval only for the repo's own app.
    Adding to someone else's app needs its own Approvals row.
- **Depends on:** `FE-13`. Rank 2, because P1 and P3 to P9 only reach a rep who can open the panel.
- **Proposed card:** "FR2+: the panel in any app — a script adds the panel to a named app's utility bar without
  touching its other items; the standard Sales and Service Console apps proven or given App Manager steps"
  - Scope: `scripts/add-panel-to-app.sh`, `tests/test_add_panel_to_app.py`, `docs/patterns/03-hotkey-panel.md`,
    `e2e/**`.
  - Done when:
    1. Proof first: a read-only retrieve of the standard Sales and Service Console apps to a temporary folder outside
       the repo records whether their utility bar can be set by deploy. The hotkey and the body mount are also run
       in a console-navigation app. The launcher is checked beside a real Open CTI or Service Cloud Voice softphone.
       If no softphone is configured, that check is recorded as a hand check before a phone demo.
    2. The script adds the panel to a named app's existing bar, or to a new bar when the app has none. It keeps
       every other item and its order. It validates, then quick deploys only with that app's Approvals row. A Python
       test checks the merge on fixtures.
    3. An e2e spec opens the panel with the hotkey in a second app. Pattern 03 replaces the F62 limit with the steps,
       or with App Manager steps where a deploy cannot reach.

### P3. Switch chats across accounts: recent and pinned, one key away

- **The rep's problem:** Ben liked being able to "display different chats" (F60). `FE-22` reopens past chats, but
  only for the account on screen. A rep who worked three accounts this morning has no quick way back to the other
  two.
- **How it would work:**
  - Pressing Cmd/Ctrl-K while the compact window is already open and focused opens a switcher over the thread. It
    lists the rep's pinned chats first, then their most recent chats across all accounts (account name, chat
    title, last active). The arrow keys move through it, Enter reopens a chat, and Esc returns to the composer.
  - A pin control on the sessions control pins or unpins the open chat.
  - Reopening a chat of another account does not navigate the page. The thread shows an "Open <Account>" link.
  - The rail shows the same list in its side column.
- **What Lightning allows:**
  - This is all our own component and Apex, so the platform sets no limit.
  - Cmd-K is not a Lightning or Chrome shortcut on a Mac. That is verified and documented in `OPS-29`. The Ctrl
    form on Windows is Chrome's search shortcut, which a page may override (documented).
  - Number keys are avoided: Cmd/Ctrl-1 to 8 switch Chrome tabs. Documented:
    [Chrome keyboard shortcuts](https://support.google.com/chrome/answer/157179), the list `OPS-29` cites.
  - A light alternative with no new field is Salesforce's own recently viewed accounts. The `RecentlyViewed` object
    can be queried, is per user, and is cut back to 200 records. Documented:
    [RecentlyViewed](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_recentlyviewed.htm).
- **Effort:** M.
- **Risk:** low.
  - History stays own-only (F32), so pins are a rep's own too.
  - A chat whose account the rep can no longer see stays hidden, as `BE-26` re-checks on read.
- **Depends on:** `BE-26` (the session store and its own-only filter) and `FE-22` (the sessions control).
- **Proposed card:** "FR2+: switch chats across accounts — a switcher on a second Cmd/Ctrl-K lists pinned chats,
  then recent ones from every account, and reopens one without leaving the page"
  - Scope: `force-app/main/default/classes/CustomerSummaryHistory.cls`,
    `force-app/main/default/classes/CustomerSummaryHistoryTest.cls`,
    `force-app/main/default/objects/Customer_Summary_Session__c/fields/Pinned__c.field-meta.xml`,
    `force-app/main/default/permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml`,
    `force-app/main/default/lwc/customerSummaryConversation/**`, `tests/test_permission_sets.py`, `e2e/**`.
  - Done when:
    1. `listRecentSessions(limitSize)` reads in user mode, returns the running user's own sessions only (F32), and
       hides a chat whose account is no longer readable. `setPinned(sessionId, pinned)` checks the session is the
       running user's own, then writes in system context, because reps have read-only access to the session object
       (`BE-26`). The write carries a `// system-context:` marker with that reason, per `BE-37`. Apex tests cover
       a second user, the cap, a lost account and a pin attempt on another user's session.
    2. The switcher opens on a second Cmd/Ctrl-K, lists pinned chats then recent ones, and moves with the arrow keys
       as one Tab stop. It reopens a chat through `sessionId` and `sessionchange`, keeps the FE-12 interface, and
       has zero jest-axe violations.
    3. One e2e spec reopens another account's chat from the switcher without the page changing. Pattern 03 lists
       the key.

### P4. A signal when a slow answer is ready while the panel is hidden

- **The rep's problem:** a summary makes several model calls. A rep who asks, then hides the panel to keep working,
  has no sign that the answer has landed, so they keep checking or forget it.
- **How it would work:**
  - When an answer arrives while the compact window or the rail is hidden, the launcher shows a small dot and
    reads "Answer ready" in its accessible name.
  - A polite live region on the launcher, which stays on the page, announces "<Agent name> has an answer ready".
  - The utility item is also highlighted, for orgs that keep the bar item visible.
  - Opening the window clears all three and scrolls to the new answer.
  - No toast and no browser notification. A toast covers the page and cannot reopen the panel. A browser
    notification needs its own permission prompt.
- **What Lightning allows:**
  - The component keeps running while its utility panel is closed, and the launcher stays on the page. Both are
    verified in `OPS-29`. A live region inside a hidden panel is not announced, which is why it sits on the
    launcher.
  - `updateUtility` with a highlighted option is the LWC route to the highlight. The Aura `setUtilityHighlighted`
    has no LWC form. Documented:
    [updateUtility](https://developer.salesforce.com/docs/atlas.en-us.api_console.meta/api_console/sforce_api_console_lwc_updateUtility.htm),
    [method parity](https://developer.salesforce.com/docs/atlas.en-us.api_console.meta/api_console/sforce_api_console_js_utility_parity.htm).
    Its exact options are unverified, because the pages were not opened.
- **Effort:** S.
- **Risk:** low.
- **Depends on:** `FE-13` (the launcher) and `FE-15` (the rail's edge strip shows the same dot).
- **Proposed card:** "FR2+: answer ready — the launcher and the rail's strip show a dot and announce it when an
  answer lands while the surface is hidden"
  - Scope: `force-app/main/default/lwc/customerSummaryPanel/**`, `force-app/main/default/lwc/customerSummaryRail/**`,
    `e2e/**`.
  - Done when:
    1. Proof first: one call of `updateUtility` with the highlighted option in `agent-probe` shows the highlight, or
       the card drops the highlight and says so.
    2. An answer that lands while the surface is hidden sets the dot and the launcher's accessible name, and
       announces once through a polite live region outside the hidden panel. Opening clears it. Jest covers a
       hidden and a shown surface, two answers, and zero jest-axe violations.
    3. One e2e spec asks, presses Esc, waits for the dot, reopens and finds the answer in view.

### P5. Keep an answer on the account (already cut: `FE-23`)

- **The rep's problem:** a useful explorer answer ("which of their deals slipped this quarter?") is lost when the
  conversation ends. Only summaries persist against the account (F80).
- **How it would work:** as `FE-23` says. One "Keep" control on a finished answer with an account writes a Saved
  answer outcome through `BE-35`. Only its author sees the text.
- **What Lightning allows:** nothing new on the platform: it is our own object and service (`BE-35`).
- **Effort:** S (`FE-23` is priced at $8).
- **Risk:** low.
- **Depends on:** `FE-22` and `BE-35`.
- **Proposed card:** none. `FE-23` is already cut and parked for this pick. If Ben picks P5, the brain releases
  `FE-23` as written.

### P6. Slash commands for the skills and actions

- **The rep's problem:** the skills (summary, ask anything, the six actions) are hidden behind chips that change
  with the page. A rep who types cannot see or reach them all. `/brief` exists, but nobody can find it except
  through the empty-state hint.
- **How it would work:**
  - Typing `/` as the first character of the composer opens a short list under it: `/summary` (with `/brief` kept
    as an alias), `/ask`, `/deals`, `/activity`, and the actions `/task`, `/event`, `/log`, `/case`, `/contact` and
    `/opportunity`.
  - It narrows as the rep types. The arrow keys move through it, and Tab or Enter picks.
  - Picking an action command leads to `FE-14`'s draft card, never to a write.
  - The action commands stay hidden while `FE-12`'s action flag is off.
  - Voice is untouched: a spoken "slash" is not treated as a command.
- **What Lightning allows:**
  - The composer already stops key propagation, so `/` (Lightning's search shortcut, verified in `OPS-29`'s list)
    does not reach Lightning. This is documented in fr2-design.md's gotchas.
  - The list follows the ARIA combobox pattern. No platform limit.
- **Effort:** S.
- **Risk:** low.
- **Depends on:** `FE-12` (the composer) and `FE-14` (the action drafts).
- **Proposed card:** "FR2+: slash commands — `/` in the composer lists every skill and action, narrows as you type,
  and leads to the same paths the chips use"
  - Scope: `force-app/main/default/lwc/customerSummaryConversation/**`, `e2e/**`.
  - Done when:
    1. `/` at the start of the composer opens a combobox list of the commands. It narrows as the rep types, and the
       arrows, Tab, Enter and Esc work as the ARIA combobox pattern says. `/brief` still works. A `/` later in the
       text is just text.
    2. Each command calls the same path as its chip. The action commands appear only when the action flag is on and
       lead to a draft. Jest covers each, the flag, an IME composition, and zero jest-axe violations.
    3. The empty-state hint names `/`. One e2e spec runs `/summary` on an account page.

### P7. Copy an answer as plain text

- **The rep's problem:** reps paste summaries and answers into emails, call notes and chat with colleagues.
  Selecting text across cards by hand picks up labels and loses line breaks.
- **How it would work:**
  - A "Copy" control on each finished answer copies its plain text: the plain-text fallback the card contract
    already requires (`FE-18`, `BE-39`). Tables come out as tab-separated lines.
  - The control reads "Copied" for two seconds.
  - This is not email drafting, which Ben ruled out for now (F16). Nothing is sent anywhere.
- **What Lightning allows:**
  - Whether `navigator.clipboard.writeText` works under Lightning Web Security is unverified. The LWS pages found
    say nothing about the clipboard
    ([how LWS works](https://developer.salesforce.com/docs/platform/lwc/guide/security-lwsec-architecture.html)).
  - The fallback, if it is blocked: a read-only text area with the text selected and "Press Cmd/Ctrl-C".
- **Effort:** S.
- **Risk:** medium, until the clipboard call is proven.
  - The copied text leaves our surfaces. That is the rep's own choice, but outcome text that only its author may
    see is copied only by its author, which holds already because only the author is shown it.
- **Depends on:** `FE-22` (answers rendered from the card contract, with the plain-text fallback).
- **Proposed card:** "FR2+: copy an answer — one control copies an answer's plain text, with a select-and-copy
  fallback if the clipboard is blocked"
  - Scope: `force-app/main/default/lwc/customerSummaryConversation/**`, `e2e/**`.
  - Done when:
    1. Proof first: one press in `agent-probe` in Chrome records whether `navigator.clipboard.writeText` works under
       LWS. The LWS validation skill reports no blocked API.
    2. Copy puts the answer's plain-text fallback on the clipboard, or shows the selected-text fallback. A table
       copies as tab-separated lines. Jest covers both paths, the "Copied" state and zero jest-axe violations.
    3. One e2e spec copies a summary, reading the clipboard only where Playwright allows it.

### P8. Open the conversation in its own browser tab (the pop-out)

- **The rep's problem:** for long work (a planning session, a call prep), a rep wants the conversation on a second
  monitor or beside a record, not over it.
- **How it would work:**
  - A "Open in a tab" control in the compact window's and the rail's header opens a Lightning app page, "Customer
    Summary", which hosts the same conversation component on the same session (the session and account passed in
    the page's state).
  - The rep can drag that browser tab to another monitor.
  - The page stays on its account. It does not follow the record in another browser tab.
  - This replaces the utility pop-out (see "Dropped" below).
- **What Lightning allows:**
  - Navigating to a Lightning page tab with `standard__navItemPage` is documented, in Lightning Experience and the
    mobile app ([page reference types](https://developer.salesforce.com/docs/platform/lwc/guide/reference-page-reference-type.html)).
    Custom state keys take the `c__` prefix as a rule. Whether this type carries them to the page is unverified,
    because the results did not show it.
  - Opening it in a new browser window from code (`window.open` under LWS, or `NavigationMixin` with a generated
    URL) is unverified. The safe version is a link the rep opens with a middle click or Cmd-click.
- **Effort:** M.
- **Risk:** medium.
  - A second open copy of the same session can race the first. The latest-wins token is per component, so two
    copies writing turns need `BE-26`'s locking to hold.
- **Depends on:** `FE-12` (the `sessionId` interface), `BE-26` and `FE-15`. The same app page is the mobile host in
  P10.
- **Proposed card:** "FR2+: open in a tab — the conversation on its own Lightning app page, on the same session, so
  a rep can move it to a second monitor"
  - Scope: `force-app/main/default/lwc/customerSummaryPage/**`, `force-app/main/default/flexipages/**`,
    `force-app/main/default/tabs/**`, `force-app/main/default/applications/**`, the open control in
    `force-app/main/default/lwc/customerSummaryPanel/**` and `force-app/main/default/lwc/customerSummaryRail/**`,
    `tests/test_app.py`, `e2e/**`.
  - Done when:
    1. Proof first, from one try each in `agent-probe`:
       - whether `standard__navItemPage` delivers `c__` state (the session and the account) to the page;
       - whether the open control can open a new browser window under LWS, or only a link.

       If state is not delivered, the card stops and hands back.
    2. The app page opens on the same session with no lost turns. A new question there appears in the compact
       window's history after a reload. Two copies on one session lose no turn (Jest, plus the `BE-26` store's own
       test).
    3. tests/test_app.py covers the new page and tab, and one e2e spec opens a thread in a tab and asks one question.

### P9. Resize the compact window and the rail, remembered

- **The rep's problem:** about 420 px is right for a quick question but tight for a table of deals. The rail's
  width suits one screen and not another.
- **How it would work:**
  - The compact window gets a resize handle on its top-left corner (it sits at the bottom right), from 360 px wide
    up to 640 px, and taller up to the window height less the header.
  - The rail gets a handle on its left edge, within `FE-15`'s 480 to 640 px range.
  - The handle also works from the keyboard: arrows resize in 16 px steps. This meets WCAG 2.2's "dragging
    movements" rule.
  - The size is remembered per browser in local storage.
- **What Lightning allows:**
  - The window and the rail are our own body-mounted elements (verified in `OPS-29`), so this is our own CSS and
    pointer handling. The utility bar's `updatePanel` sizes only the utility panel, which is no longer what the rep
    sees (documented:
    [updatePanel](https://developer.salesforce.com/docs/atlas.en-us.api_console.meta/api_console/sforce_api_console_lwc_updatePanel.htm)).
  - LWS gives each namespace its own local storage keys (documented:
    [LWS local storage](https://developer.salesforce.com/docs/platform/lwc/guide/security-lwsec-local-storage.html)).
- **Effort:** S.
- **Risk:** low. The fr2-design.md layout must hold at the smallest size (the composer's `min-width: 0`, cards at
  360 px).
- **Depends on:** `FE-13` and `FE-15`.
- **Proposed card:** "FR2+: resize — a handle on the compact window and the rail, by pointer and by keyboard, with
  the size remembered"
  - Scope: `force-app/main/default/lwc/customerSummaryPanel/**`, `force-app/main/default/lwc/customerSummaryRail/**`,
    `e2e/**`.
  - Done when:
    1. Each handle resizes within its limits by pointer and by the arrow keys. It has an accessible name and a 24 px
       target, and reduced motion is respected.
    2. The size survives a reload through local storage, and storage that is missing or blocked falls back to the
       default. Jest covers the limits, the keys, the fallback and zero jest-axe violations.
    3. One e2e spec widens the compact window, reloads and finds the width kept, with no overflow at the smallest
       size.

### P10. The Salesforce mobile app

- **The rep's problem:** field sellers prepare in the car park on a phone (pattern 11's business problem). The
  panel is desktop only (F62), so the moment voice helps most has no surface.
- **How it would work:**
  - There is no hotkey, launcher or utility bar on a phone. The same conversation component runs in two places:
    - on the account record page, as a component or a tab on the page;
    - on the app page from P8, reached from the mobile navigation menu.
  - The app gains the phone form factor.
  - Voice is the main input, if the mobile app's browser view supports speech recognition. Otherwise typing and the
    chips carry it.
  - Write actions keep their draft and Confirm.
- **What Lightning allows:**
  - App pages and record pages support the phone form factor (`Small`) through `supportedFormFactors` (documented:
    [form factors](https://developer.salesforce.com/docs/platform/lwc/guide/use-config-form-factors.html)).
  - LWC quick actions do not appear in the Salesforce mobile app (documented:
    [lightning__RecordAction](https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-record-action.html)),
    so a quick action is not the way in.
  - App Manager labels utility items "Desktop Only" (documented: the Trailhead unit cited in P2), so the utility bar
    is not either.
  - The Web Speech API inside the mobile app is unverified: pattern 11 marks Safari as patchy, and the app's iOS
    view is a Safari engine.
  - The body mount is irrelevant here.
- **Effort:** L.
- **Risk:** high.
  - The layout has to work at 320 px, which fr2-design.md already asks of the composer.
  - Voice may not work.
  - A summary's wait is longer on a phone network.
  - The mobile app cannot be driven by Playwright, so the proof is by hand.
- **Depends on:** `FE-12`, `FE-22`, P8 (the app page) and `FE-11` (voice).
- **Proposed card:** "FR2+: Customer Summary on the Salesforce mobile app — the shared conversation on the account
  page and an app page for phones, voice first where the app allows it"
  - Scope: `force-app/main/default/lwc/customerSummaryPage/**`, `force-app/main/default/flexipages/**`,
    `force-app/main/default/applications/**`, `tests/test_app.py`, `docs/patterns/03-hotkey-panel.md`,
    `docs/research/fr2-mobile.md`.
  - Done when:
    1. Proof first (a spike, by hand on a phone, written up in docs/research/fr2-mobile.md): the component shows on a
       phone on the account page and the app page, and speech recognition in the mobile app works, partly works or
       does not.
    2. The app and both pages carry the phone form factor, and the component lays out at 320 px with no overflow.
       Voice shows only where the spike found it works, and typing always works. tests/test_app.py follows the
       metadata.
    3. Pattern 03 replaces "desktop only" with what runs on a phone. A short hand-check script, like the voice one,
       covers the mobile proof.

### P11. A list of the panel's keyboard shortcuts

- **The rep's problem:** the keys (Cmd/Ctrl-K, Cmd/Ctrl-Shift-K, Esc, Enter and Shift-Enter, the arrows in a
  list, `/`) are what make the panel fast, but nothing on screen lists them except the launcher's key cap.
- **How it would work:**
  - A "Keyboard shortcuts" button in the compact window's and the rail's header opens a small list, with the key
    names for the rep's platform ("⌘K" on a Mac, "Ctrl K" elsewhere).
  - `?` opens the same list when focus is on a panel control that is not a text field.
  - Esc closes the list and focus returns to the button.
  - It lists P3's and P6's keys once they exist.
- **What Lightning allows:**
  - Lightning's own list (Cmd-/ on a Mac) is verified in `OPS-29`. Whether a component can add to it is unverified,
    and no public API for that was found. The design does not rely on adding to it, because ours is a separate list.
    So the point is noted here, but the build does not rest on it.
  - `?` is not a Lightning shortcut (verified: not in `OPS-29`'s list).
- **Effort:** S.
- **Risk:** low.
- **Depends on:** `FE-13` and `FE-15`. Best cut after P3 and P6, so the list is not rewritten.
- **Proposed card:** "FR2+: keyboard shortcuts — one list in the compact window and the rail, with platform key
  names, opened by a button or `?`"
  - Scope: `force-app/main/default/lwc/customerSummaryPanel/**`, `force-app/main/default/lwc/customerSummaryRail/**`,
    `docs/patterns/03-hotkey-panel.md`.
  - Done when:
    1. The button and `?` (outside a text field only) open the list. Esc closes it and returns focus. The list is a
       labelled dialog with zero jest-axe violations.
    2. Key names follow the platform (Jest covers a Mac and a non-Mac platform). The list's rows come from one
       constant, which the hotkey code also reads, so the two cannot drift.
    3. Pattern 03 links the list.

## Dropped

| Idea | Why it is dropped |
|---|---|
| The utility bar's own pop-out | It pops out the utility item, not the body-mounted compact window or rail that the rep actually uses (`OPS-29`). For custom utilities it needs the release update "Utility Bar: Enable Pop-Out for Custom Utilities", which is org-wide. The docs disagree on whether LWC's `enablePopout` exists, and it is not supported on iPad Safari ([pop-out utilities](https://developer.salesforce.com/docs/atlas.en-us.api_console.meta/api_console/sforce_api_console_lightning_utility_popout.htm)). P8 gives the same second-monitor result with a page we control. |
| A browser notification when an answer is ready | It needs its own permission prompt, and its behaviour under LWS is unverified. P4 covers the need on the page. |
| A hotkey outside Salesforce (a browser extension) | Outside the platform and outside this repo's install path. Each rep would have to install it, and IT would have to manage it. |
| Ask about the text selected on the page | Reading another component's selection across LWS namespaces is unverified, and Salesforce's own markup is private (the lesson of the push hack in `OPS-29`). |
| Pushing the page left for the rail | Already tried and ruled out by `OPS-29`: it works only by restyling Salesforce's private markup. |
| A second "keep an answer" card | `FE-23` already exists (P5). |

## Ranked top five, and why

1. **P1, the panel follows the record (S).** Every rep sees it on every opportunity, case and contact page, and it is
   the cheapest item here. Today the panel loses the account the moment the rep leaves the account page. That makes
   the summary, history and the scope chip look broken, and it is where a rep first decides whether the panel knows
   what they are doing.
2. **P2, the panel in every app (L).** It is the bigger of the two limits Ben's notes kept open (F62). None of the
   other items reach a rep who works in the standard Sales app or the Service Console. It goes second, not first,
   because it is the largest item in the top five: it needs a proof on the standard apps and an Approvals row for
   each app it changes.
3. **P3, switch chats across accounts (M).** This is Ben's own words, "display different chats" (F60), and the
   visibility he said "might not actually exist there today". `FE-22` gives the per-account half. This is the half
   that makes the panel a place a rep keeps their morning's work.
4. **P4, the answer-ready signal (S).** "Hide" is one of the three things Ben liked. Hiding only works if the rep
   learns when the slow answer is back, and this is a small change on parts `FE-13` builds.
5. **P5, keep an answer (`FE-23`, S, already cut).** It closes the one gap the pattern 05 recheck found (F80): the
   explorer's good answers vanish. The store (`BE-35`) is already built for it, so the cost is one control and one
   method.

Next in line:

- P6 (slash commands) is cheap, but it serves typists, and Ben's sellers "don't want to type".
- P10 (mobile) has the highest value of anything left off the top five, but it is L, rests on an unproven voice
  path, and needs P8's app page first. If Ben wants mobile, the brain recommends cutting its first done-when line as
  a spike before the build.

[Back to the architecture page](../ARCHITECTURE.md) | [Back to the README](../../README.md)

## Undo

Nothing changed in an org: docs only, no org was opened.
