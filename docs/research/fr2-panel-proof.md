# FR2: compact window proof pass (FE-16)

Feature revision 2 (FR2), row F62 of [feature-revision-2.md](../plans/feature-revision-2.md): the "Not yet proven" list of
[pattern 03](../patterns/03-hotkey-panel.md) named the dark theme and its contrast, and real screen-reader output. This
page records what was checked in `agent-probe` on 2026-11-13, the result, and what is still unproven. The two hotkey
branches are FE-21's and the non-admin run is FE-5's.

The live runs were approved (the row "FR2: live checks in `agent-probe`" of the Approvals table in
[gtm-burn-plan.md](../plans/gtm-burn-plan.md)). They ran on the seed account Edge Communications, as the signed-in
developer. No deploy. The new specs make no model call. They send `/brief` of a name that matches no account, which the
resolver answers from SOQL alone, and the count of `Customer_Summary_Session__c` rows was 5 before and 5 after (68 briefs
in total before and after): the product wrote no session rows and there is no outcome object in the org. The org holds
only the session object.

## Checks

| # | Check | Result |
|---|---|---|
| 1 | Dark theme in `agent-probe` | Not offered (see below). Brand colours checked on the light theme instead |
| 2 | Accessibility snapshot, closed | Pass. The stage holds one button, "Ask Customer Summary" plus the key (⌘K or Ctrl K). No dialog and no composer in the tree |
| 3 | Snapshot, open | Pass. `dialog` named "Customer Summary"; `textbox` "Ask or /brief an account"; buttons "Minimize" and "Summarize Edge Communications"; `region` "Conversation". The live region (`role=status`, `aria-live=polite`) is empty. Focus is in the composer |
| 4 | Snapshot, pending | Pass. Live region: "Loading summary for" and the name asked. The question is in the tree. Window name and composer label unchanged |
| 5 | Snapshot, answered | Pass. The live region says the resolver's own line, which is also the reply on screen. Name and label unchanged |
| 6 | Snapshot, in error | Pass. The live region says the same text as the error reply on screen. Name and label unchanged |
| 7 | Focus after Esc | Pass in the open, pending, answered and error states: focus returns to the global Search button the hotkey was pressed on, and stays there for 2.5 s. Esc while a request runs does not cancel it; reopening shows the same live region text |
| 8 | axe `color-contrast` on the open window, answer showing, light theme | 10 elements pass, 2 incomplete (axe could not decide, for example text over a gradient or shadow), 0 violations |
| 9 | Brand colours, computed (below) | All pairs at 4.5:1 or better |
| 10 | The fallback names | See "Before brand settings load" |

The checks are the e2e specs 11 to 13 in `e2e/a11y-snapshot.spec.js`. The error state is made by the browser failing the one
`resolve` request (Playwright `route.abort`), so the panel's own error path runs without touching the org. The snapshots
are `locator.ariaSnapshot()` of the stage element and are attached to the Playwright report as text. The stage is found
through the `Panel` helper in `e2e/support/panel.js` and axe is run on it directly, as spec 8 does, because the page's synthetic shadow DOM hides the stage from
`document.querySelectorAll`. The scan covers the stage only. The note in the utility item's own panel is covered by Jest.

### Dark theme

`agent-probe` is a Developer Edition org. Setup Quick Find for "dark" returns "No matching items found". The
profile card (Settings, Log Out, Display Density) offers Comfy and Compact density and no theme or colour mode, and the
page does not report `prefers-color-scheme: dark`. So there is no dark theme for Lightning here, and `docs/assets/fr2-compact-dark.png` was not captured. Source:
the org's own Setup and profile menu, read on 2026-11-13, no change made.
Dark theme and its contrast therefore stays **unproven**. When an org offers one, run spec 13 under it.

The panel reads only `--cs-color-*` variables and SLDS hooks, so a dark brand (a dark surface colour and a light ink
colour) set in the brand settings record is the way it would be themed. Light-theme brand colours, computed from the
default brand record with the WCAG relative-luminance formula:

| Pair | Ratio | Needed |
|---|---|---|
| Ink #181818 on surface #ffffff | 17.76 | 4.5 |
| Primary #0176d3 as text on surface | 4.63 | 4.5 |
| White on primary (brand button) | 4.63 | 4.5 |
| White on accent #014486 (hover) | 9.67 | 4.5 |
| Muted text (ink 72% over surface) on surface | 7.00 | 4.5 |
| Muted text on the 5% ink tint | 6.31 | 4.5 |
| Ink on the 10% primary tint | 15.51 | 4.5 |

The primary colour is within 0.13 of the limit: a lighter primary set by a seller would fail as text and as a button
background. The swap guide should say to keep it at 4.5:1 against white.

### Before brand settings load

Until the brand settings arrive the window is named "Assistant" and the launcher "Ask the assistant". Spec 12 watched the
launcher from the first document on: the fallback showed for about 220 ms (1492 to 1711 ms after navigation start,
one warm run), then "Ask Customer Summary". It is not in the live region and is not announced: a screen reader says an
element's name when focus lands on it, and the window is closed in that interval. Only a user who focused the
launcher in those 220 ms would hear "Ask the assistant". The window itself is never open before the brand loads in practice
(its name read after load is "Customer Summary"). Unproven: a slow connection, where the interval is longer.

### Finding for the panel's owner

The error line in the live region is the platform's own text. With the request cut off in the browser, the screen reader would hear
"Disconnected or Canceled", not the panel's fixed sentence ("I couldn't finish that right now. Try again in a
minute."): `errorText` in the conversation component returns `error.body.message` when there is one. That is a
platform message from outside Apex. It is a change in `force-app` and not part of this card.

Fixed by FE-25: `errorText` now always returns the panel's fixed sentence.

2026-11-14 (FE-27): the conversation's View record did nothing in `agent-probe`, in the compact window and in the rail: both new e2e tests (`e2e/conversation-view-record.spec.js`, on `mac` and `windows`) failed on the first run, before any change, on the URL never leaving the account page. Changed: View record now dispatches a cancelable `csopenrecord` first and `customerSummaryPanel` navigates (one method shared with the rail's rows); after the deploy both tests pass.

## VoiceOver script (about five minutes, macOS Safari or Chrome)

Automated browsers cannot hear a screen reader, so this is by hand. Open the Customer Summary app on an account page
in `agent-probe`. Turn VoiceOver on with Cmd-F5. Write down anything that differs from "Hear".

1. **The launcher.** Press Tab until VoiceOver lands at the bottom right. Hear: "Ask Customer Summary, Command K" (or
   "Control K") and "button". Not "Ask the assistant".
2. **Open it.** Press Cmd-K (Ctrl-K on Windows). Hear: "Customer Summary, dialog", then "Ask or /brief an account, edit
   text" for the composer, which has focus.
3. **Ask.** Type `/brief` and a name that does not exist, then Enter. Hear: "Loading summary for" and the name, then,
   when it ends, the line "No account matches ..." read once. Not silence, and not read twice.
4. **Summarize an account.** Tab to "Summarize Edge Communications, button" and press it. Hear: "Loading summary for
   Edge Communications", then "Summary ready:" and the headline. Tab on: each section is a collapsed button,
   "expanded, false" or "collapsed".
5. **Leave.** Click the Search button at the top of the page, press Cmd-K, then Esc. Hear the window close and
   "Search, button" again, not the page title or silence. Press Cmd-K and Tab until you leave the window, to check
   that nothing traps you.

## Not yet proven

- A real screen reader's output, until Ben runs the script. What the browser exposes is proven, not what is spoken.
- The dark theme and its contrast: not offered in `agent-probe`.
- Contrast of the 2 elements axe left "incomplete".
- A slow connection, for how long the fallback names show.
- The two hotkey branches (FE-21) and the non-admin run (FE-5).
