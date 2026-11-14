# FR2: the write-action cards in the conversation (FE-14)

FE-14 draws BE-27's write actions in the conversation. A typed or spoken request, or a quick chip, gives a draft card inside the agent's turn. The seller fills what is missing, then confirms or cancels. Confirm writes the record and adds a result card that links to it. An update offers Undo for 15 seconds.

There is one card contract. The draft is BE-39's `actionDraft` card and the result is its `actionResult` card. Both are drawn by `c-customer-summary-card` with the same plain-text fallback as every other card. No second card shape was added.

Read with: [13-write-actions.md](../patterns/13-write-actions.md) (BE-27: the service, the statuses and the rules), [fr2-actions-spike.md](fr2-actions-spike.md) (BE-22: the pre-check and the shapes), [fr2-card-architecture.md](fr2-card-architecture.md) (FE-18: the card contract) and [fr2-card-contract-apex.md](fr2-card-contract-apex.md) (BE-39: the cards in Apex).

## What was found, in short

- **The card contract needed one switch, not a new shape.** FE-22 drew `actionDraft` and `actionResult` as their plain text, because they were marked `ready: false`. `viewOf(card, density, options)` now draws them when `options.actions` is set. The card sets it only when the host gives it an `action-mode`. Without one, the card is exactly as FE-22 drew it, and FE-22's tests are unchanged. The version check and the try/catch fallback still apply.
- **The server is the only source of a draft.** The client never builds a field or decides a status. A chip calls `draftAction` with `{}`. An edit or a choice calls `draftAction` again with the draft's resolved input plus the new words. Confirm sends back only `{action, accountId, inputJson}`, and BE-27 rebuilds and checks the draft before it writes.
- **Nothing is written before Confirm.** No create, edit or cancel path calls `commitAction`. The e2e counts the requests and finds none.
- **The pre-check runs in the client too.** Typed or spoken text that starts with an action verb (BE-22's filler and verb lists, the same as `CustomerSummaryActionCatalog`) calls `draftFromText`. Anything else goes straight to the ask path with no extra request. `NOT_AN_ACTION` from the server also goes on to the ask path, inside the same request, so the seller sees one turn.

## What leads to a draft

| Way in | What it calls | Needs |
|---|---|---|
| The chip "Create a follow-up" | `draftAction('create_task', account, '{}')` | an account in view |
| The chip "Log a call" | `draftAction('log_call', account, '{}')` | an account in view |
| Typed text that starts with an action verb ("Create a task to send the quote") | `draftFromText(account, text)` | an account in view |
| Spoken text: the mic fills the composer, and Send goes the same way as typing | `draftFromText(account, text)` | an account in view |

The account comes from the page's account. On a record page that is not yet resolved, it is the account page's own record. Off a record page, it is the account briefed last. The two chips show on an account's record page only. Off one, a typed action uses the account briefed last, and with no account in view the text is a question. The chips sit after Summarize, Open deals and Recent activity in the quick-actions row, which scrolls sideways in the 420 px window. `ACTION_CHIPS_ENABLED` in the conversation turns them off.

`draftFromText` answers in one of five ways:

- `READY`, `NEEDS_INPUT` or `REFUSED` with an `actionDraft` card: the draft card.
- `ERROR`: the error turn with the message.
- `NOT_AN_ACTION`: the question is asked.

## The draft card

| State | What it shows | What it does |
|---|---|---|
| Open, `NEEDS_INPUT` | The title ("Create a task"), the object and mode ("Task · create") and the status badge. Each field has its label and an editable value: a text box for a field the seller can fill, and a record link for the account ("Related to"). A missing field has a 2 px error border, "Needed" under it, and `aria-invalid`. Any warnings, then Confirm (off), Edit and Cancel. | Confirm stays off until no field is missing. A changed value fires `cardedit`. The conversation re-drafts, and the card comes back with the new status. |
| Open, `READY` | The same, with nothing marked. | Confirm is on. |
| Open, a field with several matches | A choice chip for each match, beside the field. | A chip fires `cardchoose`, and the conversation re-drafts with that record's Id. |
| Open, an update | The new value is editable, and the value before is shown beside it ("Was Prospecting"). | |
| Busy | Every field, chip and button is disabled, and `aria-busy` is on the card. | Set while a re-draft or the commit runs, so Confirm cannot run twice. |
| Closed | The values as text. No text box and no button. | Set after Cancel or a saved Confirm. |
| Refused | The message, and only Cancel. | |

- **Edit** moves focus to the first missing field, else to the first field. It changes nothing by itself.
- **Esc** inside a field still reaches the window, so Esc closes it as everywhere else. Other keys stay in the card.
- **Cancel** closes the card and adds "Cancelled. Nothing was saved." under it. It is also announced.

## Confirm, the result card and Undo

- **Confirm** calls `commitAction` once. The card is busy while it runs, and a second click does nothing.
- **Saved (`OK`):** the draft closes, and a new turn ("Confirm") shows the result card. The result card has the title ("Task created"), the record as a link, what was written, and Open. A link or Open goes to the record's page by Id with `standard__recordPage`. No `href` is built from card data.
- **Not saved:** a refusal or a failure (`REFUSED`, `ERROR`, an exception) adds the error turn with the plain-English message. The draft stays open so the seller can fix it or cancel.
- **An update** comes back with an undo token. Its result card shows Undo next to Open for 15 seconds, and then Undo is removed.
  - Undo calls `undoAction` once.
  - A done undo adds a "Change undone" result turn ("Undo").
  - A failed undo adds the error turn.

## Accessibility and theming

- Each field's label is a `<label for>` on its text box.
- A missing field is marked three ways: its border, the word "Needed" (tied by `aria-describedby`), and `aria-invalid`.
- The buttons and chips stay native buttons, with the disabled attribute while busy.
- Text boxes are at least 24 px, in the same rule as the other card controls.
- Status changes go to the conversation's live region: "Updating the draft", "Draft ready to confirm", "Saving", the result's title, "Cancelled. Nothing was saved."
- The card reads only `--cs-*` variables and `--slds-g-color-error-1`, with no colour outside a variable fallback.
- axe finds no violations in either Jest suite, for the draft (open and busy), the missing field and the result.

## Tests

- **Jest, the card** (`customerSummaryActionCards.test.js`): the contract switch and the fallback, draft rendering, editing, the missing field blocking Confirm, Edit focus, busy and closed, an update's value before, choice chips, a refused draft, the result card and Undo, and axe.
- **Jest, the conversation** (`customerSummaryConversationActions.test.js`): the interface notes at the top of the file, and what leads to a draft (chips, typed, spoken, `NOT_AN_ACTION`, `ERROR`). It also covers re-drafting on an edit and a choice, Cancel, and Confirm:
  - commitAction is called once, with the button disabled while it runs;
  - the result card and Open;
  - the error turn, for a refusal and a failure;
  - Undo, and its 15 s.

  Then axe.
- **One FE-12 test changed:** the account page's quick chips now end with "Create a follow-up" and "Log a call".
- **e2e:** `conversation-actions.spec.js` FR2 5 (`@smoke`, 0 model calls, 0 records), in the org.
  - The chip gives a task draft in the turn, with the account by name, and Subject and Due marked.
  - Confirm is off until both are filled, and each fill re-drafts.
  - Cancel closes the card with no `commitAction` request.

**The approval row "FR2: e2e and agent tests that create a record" is pending, so no run clicks Confirm in the org.** The confirm path is proven only by the Jest suites above and by BE-27's Apex tests.

## Captures

- `fr2-action-draft.png` (1440x900, `e2e/capture/11-action-draft.capture.js`): the compact window on Edge Communications with a "Create a follow-up" draft. Subject is filled, Due is marked "Needed", and Confirm is off. The run Cancels the draft after the still.
- `fr2-action-result.png` was not captured. A result needs a saved record, and record-creating runs are not approved. Capture it once that approval lands: the same script, then Confirm, then the still, then delete the record.

## What page 13 should now say

[13-write-actions.md](../patterns/13-write-actions.md) was not changed here. These are the changes for it:

- **See it:** replace "None yet…" with `fr2-action-draft.png`: "The draft card in the compact window: Subject filled, Due needed, Confirm off until it is filled." Add `fr2-action-result.png` once it is captured.
- **Three ways in, the panel:** add that the conversation's chips "Create a follow-up" (`create_task`) and "Log a call" (`log_call`) call `draftAction` with no input. Add that typed or spoken text runs the verb pre-check in the client before it calls `draftFromText`, and that `NOT_AN_ACTION` goes on to the ask path in the same turn.
- **How it works:** a field edit or a choice re-drafts with `draftAction`, and the server decides every value and the status. Confirm sends back only `{action, accountId, inputJson}`.
- **Why you can trust it:** add "Nothing is written before Confirm: no draft, edit or Cancel calls `commitAction`, and the e2e counts none. Confirm is off until the draft is READY and while the commit runs."
- **Limits and open items:** remove "The cards are not drawn in the panel yet". Add:
  - Undo is shown for 15 seconds by a client timer. The server's own 15 s check still decides.
  - Confirm is not yet run in the org by the e2e (pending approval).
  - The chips cover two of the six actions. The other four are reached by typing or speaking.
- **Adopt it, step 4:** point to the conversation's `_startDraft`, `_redraft` and `_confirm` as the reference surface. A surface sets `action-mode` on `c-customer-summary-card` to draw the draft and result cards.
