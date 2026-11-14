# Right rail

A full-height side panel on the right of the page: the same conversation as the compact window, with the account's
deals, activity, cases and last summary beside it.

## The business problem

The compact window is for a quick question. A seller who is working an account for the next ten minutes needs more
room for the answer, and needs the account's own facts in view while they read it: which deals are open, what happened
last week, which cases are still open and what the last summary said. Without that, the seller flips between the
answer and the record's related lists and loses the thread.

The rail is for that seller. It opens on one key from anywhere on the page, or from the compact window when a quick
question turns into a longer one, and it keeps the conversation the seller already started.

## The architecture in a few steps

1. The seller presses Cmd/Ctrl-Shift-K, clicks the expand button beside the launcher, or clicks Expand in the compact
   window.
2. The rail asks for the account's context at once, before it is drawn, and slides in over the right of the page.
3. The one conversation element moves out of the compact window into the rail, so the thread, the session and the
   composer's text are the same. The composer has focus.
4. The context column fills from one read-only Apex call: open deals, recent activity, open cases and the last summary.
5. Esc or Close sends the conversation back to the window and focus back to where it was. Minimize leaves a slim tab on
   the right edge; resting the pointer on the tab peeks the rail back out.

## How it works

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontFamily": "-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif", "fontSize": "15px", "primaryColor": "#EEF2FA", "primaryBorderColor": "#4A5D85", "primaryTextColor": "#1B2233", "secondaryColor": "#F4F6F9", "tertiaryColor": "#FFFFFF", "lineColor": "#4A5D85", "textColor": "#1B2233", "actorBkg": "#EEF2FA", "actorBorder": "#4A5D85", "actorTextColor": "#1B2233", "actorLineColor": "#8A96AD", "signalColor": "#4A5D85", "signalTextColor": "#1B2233", "labelBoxBkgColor": "#FFFFFF", "labelBoxBorderColor": "#4A5D85", "labelTextColor": "#1B2233", "loopTextColor": "#1B2233", "noteBkgColor": "#FFFFFF", "noteBorderColor": "#8A96AD", "noteTextColor": "#1B2233", "sequenceNumberColor": "#FFFFFF", "activationBkgColor": "#DDE4F2", "activationBorderColor": "#4A5D85", "clusterBkg": "#F7F9FC", "clusterBorder": "#8A96AD", "edgeLabelBackground": "#FFFFFF"}}}%%
sequenceDiagram
    autonumber
    box rgb(247, 249, 252) The surface
        actor U as Seller
        participant P as Panel (utility bar)
        participant R as Rail
        participant C as Conversation
    end
    box rgb(247, 249, 252) Apex
        participant A as CustomerSummaryContext
    end
    rect rgb(225, 236, 252)
        Note over U,A: Open
        U->>P: Cmd/Ctrl-Shift-K, or Expand
        P->>R: open(sessionId, source)
        R->>A: getContext(accountId)
        R-->>P: railopen
        P->>C: move into the rail, same session
        P->>C: focusComposer()
    end
    rect rgb(222, 243, 230)
        Note over U,A: Context
        A-->>R: deals, activity, cases, last summary
        U->>R: click a deal, case or activity
        R-->>P: railopenrecord
        P->>P: Navigate to the record page
    end
    rect rgb(234, 238, 242)
        Note over U,C: Close
        U->>R: Esc or Close
        R-->>P: railclose
        P->>C: move back into the window
    end
```

Steps 1 to 6: the panel (`customerSummaryPanel`) owns the rail (`customerSummaryRail`) and opens it. The key is caught
by a document listener and by a capture listener on the panel's stage, because the composer stops most keys before they
reach the document. The rail calls `getContext` first and draws while the call is on its way; the panel then moves the
one conversation element into the rail's slot and puts focus in the composer. Steps 7 to 10: the context arrives and
fills four sections. A click on a row asks the panel to open the record: the rail lives on the stage the panel moved onto
`document.body`, outside the page's navigation context, so the panel (which stays in the utility bar) does the
navigation. Steps 11 to 13: Esc or Close puts the conversation back in the compact window and focus back where the key
was pressed.

### How it opens

| Way in | What happens |
|---|---|
| Cmd-Shift-K on a Mac, Ctrl-Shift-K elsewhere | Opens the rail from anywhere on the page, the composer included. Pressed again while the rail is out, it puts focus back in the composer. |
| The expand button beside the launcher | Opens the rail. Hovering or focusing the button starts the context call early. |
| Expand in the compact window | The window closes and the rail opens on the same session, thread intact. The `CustomerSummaryExpand` message still goes out with the session and record. |
| The edge tab, when minimized | A click opens the rail. Resting the pointer on it for 350 ms opens a peek; the peek slides back 400 ms after the pointer leaves, unless the seller clicked or tabbed into it. |
| Cmd/Ctrl-K while the rail is out | Brings the conversation back to the compact window. |

The header shows the brand logo, the agent name and the key hint (`⌘⇧K` or `Ctrl Shift K`, also in
`aria-keyshortcuts`). The rail is a non-modal `<dialog>` opened with `show()`: Tab can leave it, and the page stays usable.

### Push or overlay

The rail slides over the page; it does not push the page aside. The surfaces spike
([fr2-surfaces-spike.md](../research/fr2-surfaces-spike.md#rail)) showed that pushing works only by restyling
Salesforce's own `.viewport` element. No published API lets a component resize the Lightning workspace, and that markup
can change in any release, so the rail does not depend on it. The rail is 480 to 640 px wide
(`clamp(480px, 46vw, 640px)`, 640 px in a 1440 px window), full height, with a soft shadow and no backdrop, so the page to
its left can still be clicked.

### What it prefetches

One call, `CustomerSummaryContext.getContext(accountId)`, cacheable, at most 8 SOQL queries:

| Section | What it shows | Cap |
|---|---|---|
| Open deals | Name, amount, stage, close date | 5 |
| Recent activity | Calls, tasks, events, synced emails and case comments, newest first, each labelled with its kind | 10 |
| Open cases | Case number and subject, status, priority | 5 |
| Last summary | The date and first lines of the seller's own last stored summary | 3 lines |

The call goes out on the key press, before the rail is drawn, and on hover or focus of the launcher's expand button and of
the edge tab. The result is kept per account, so reopening the rail on the same account does not ask again. While it
loads, each section shows two skeleton rows and is marked `aria-busy`; a polite live region says "Loading account
details" and then "Account details loaded". A failed call shows one fixed sentence and Try again. A list the seller
cannot read says "Your access doesn't include this." and the others still load. On a page that is not an account the
column says it has no account to show; once an account has been seen, the rail keeps it while the seller opens one of
its deals or cases.

### Speed budget

Measured by e2e spec Rail 6 (warm, three fresh pages per project, Playwright Chromium, 1440x900, `agent-probe`,
2026-11-14):

| Measure | Budget | `mac` | `windows` |
|---|---|---|---|
| Key press to the first frame with the rail open | under 300 ms | 18, 14, 13 ms (median 14) | 12, 18, 11 ms (median 12) |
| Key press to every section filled | under 1.5 s | 323, 286, 244 ms (median 286) | 387, 316, 459 ms (median 387) |

### History visibility (F32)

The rail shows the History list of the conversation component (FE-22's control) open in its main column. History is
own-only: a seller sees the conversations they own for the account, never another rep's, even one shared with them or
one their role would show. The last summary in the context column follows the same rule. Who else may see history is
question Q7 in [feature-revision-2.md](../plans/feature-revision-2.md) and is not answered; until it is, own-only stands.

### Motion and theme

The sheet slides in 280 ms with `cubic-bezier(0.32, 0.72, 0, 1)`; the edge tab, rows and chevrons move in 120 to 180 ms.
With reduced motion asked for, nothing slides or pulses. Every colour, font and radius reads a `--cs-*` variable from
the brand settings, as in [brand and theming](10-brand-and-theming.md). Below 1040 px wide the context column folds
under the conversation.

## See it

![The Edge Communications record page with the rail open on the right, 640 px wide and full height: the header with the agent name and ⌘⇧K, the conversation with one answered question in the main column, and the context column with open deals, recent activity, open cases and the last summary](../assets/fr2-rail-open.png)

![The rail alone: the conversation beside the "About Edge Communications" column, its sections filled](../assets/fr2-rail-context.png)

![Cmd-K opens the compact window, a question is typed and answered, then Expand moves the same thread into the rail and the account's context fills beside it](../assets/fr2-rail.gif)

## Why you can trust it

Runs as the signed-in user: `CustomerSummaryContext` is `with sharing` and every query runs `WITH USER_MODE`, so object,
field and record access all apply. It is read-only. The conversation in the rail is the same component, with the same
doors, as in the compact window.

System context: none on this path.

- **Jest covers the rail.** [customerSummaryRail.test.js](../../force-app/main/default/lwc/customerSummaryRail/__tests__/customerSummaryRail.test.js)
  covers the key on and off a Mac, the expand message and `open()` with a session Id, focus in and back, overlay (no
  page style touched), minimize to the tab, the hover peek and its timings, every section with rows, empty,
  unavailable, loading and error, the sticky account, opening a record (by the rail or by its host), no record Id in the
  markup, and axe in each state.
- **Jest covers the panel's side.** [customerSummaryPanel.test.js](../../force-app/main/default/lwc/customerSummaryPanel/__tests__/customerSummaryPanel.test.js)
  covers the flag off, Expand keeping the same element, turns and session, the sessions list open with a reopen, the
  launcher expand and its prefetch, Cmd/Ctrl-Shift-K from the composer and the page, Esc bringing the thread home, Cmd-K
  bringing it back, a minimized rail, an Open prompt landing in the rail, the panel navigating for a row, and axe.
- **It runs in a real org.** `e2e/rail.spec.js` (six specs, in [e2e/README.md](../../e2e/README.md)): open by key,
  geometry and focus return; Expand with the thread intact; one question answered in the rail; every context section and
  a row opening its record; minimize, peek and tab; and the speed budget.
- **Lightning Web Security.** No blocked API: document listeners, timers, `<dialog>` `show()` and `close()`,
  `appendChild` into the component's own `lwc:dom="manual"` containers, and `NavigationMixin`.

## How it scales

- The context is one cacheable call of at most 8 queries per account, kept in the rail per account, so a seller moving
  between the window and the rail on one account asks once.
- The rail adds no model call. The only model calls are the questions the seller asks, as in the compact window.
- There is one conversation element for both frames, so a second surface costs no second session or second history
  load.

## Adopt it

1. Grant access: assign the permission set group `Customer_Summary_User`.
2. Deploy `customerSummaryPanel`, `customerSummaryRail` and `CustomerSummaryContext`.
3. Turn the rail on: set the utility item's `Right rail` property (`expandEnabled`) to true, as the shipped
   `Customer_Summary_UtilityBar` does.

## Limits and open items

- The diagram on this page was not render-checked.
- Push is not offered: the rail always slides over the page (see Push or overlay).
- Reopening a past conversation from the History list in the rail closes the list; that is the conversation
  component's own behaviour (FE-22).
- The context caps (5 deals, 10 activities, 5 cases) are fixed in `CustomerSummaryContext`, not settings.
- Who else may see a seller's history (F32, Q7) is not answered; history stays own-only.
- The speed numbers are from Playwright's Chromium on one machine, warm; a cold first open also loads the component.
- Rail 1 failed once on `mac` on the first open after a deploy (Esc did not close: focus was not yet in the rail), then
  passed three runs in a row; treat a single failure there as a cold-cache flake and rerun before chasing it.

[Back to the architecture page](../ARCHITECTURE.md) | [Back to the README](../../README.md)
