# FR2 design brief: Customer Summary on three surfaces

Read this before any `FR2:` card. The feedback it answers is in [feature-revision-2.md](feature-revision-2.md); row
numbers (F01 to F43) point there. Where a card and this page disagree, the card wins and the worker says so.

## The product

- **One branded agent, many skills.** The default name is **Customer Summary**; a seller can rename it per prospect.
  It works like Claude: one place to ask, and it routes the request. Its skills:
  1. **Summary:** the one-ask account summary (today's brief engine, pattern 01).
  2. **Ask anything:** the explorer (pattern 02) and the registered agent (BE-20).
  3. **Act:** create a task, create an event, log a call, update a contact, create a case, update an opportunity. Each
     shows a draft and writes nothing until the user confirms.
- **The same agent everywhere:** the compact window, the rail, an embedded component later, Agentforce's own panel,
  and MCP clients. One Apex service sits behind each skill, and every door calls it.
- **Built to be swapped:** brand settings hold the agent name, company name, logo, colours and tone. No component
  hard-codes a name, a colour or a font.

## Surfaces

| | Compact window | Right rail | Embedded (later) |
|---|---|---|---|
| Who | A seller mid-task | A seller or service rep who wants room to think | A service rep taking a call |
| Opens | Cmd/Ctrl-K, or the launcher | Cmd/Ctrl-Shift-K, the launcher's expand, or the compact window's expand | On the page; starts a summary when the call is accepted |
| Size | About 420 px wide; the corner comes from the surface spike | 480 to 640 px; pushes the page left, or slides over it if pushing is impossible | The component's page region |
| Extras | Minimize and expand | Session history, open deals, recent activity (with emails, calls and case comments), cases, last summary | Account map, key fields, knowledge articles (spike first) |

All of them use one conversation component. The frames differ; the thread, composer, voice, quick actions, cards and
history do not.

## Conversation design (Claude-like)

This pattern is taken from a reference app Ben pointed to. Its name stays out of this repo.

- **Turns:** the user's turn is a recessed note aligned right (soft surface colour, hairline border, max width about
  90 percent). The agent's turn has no bubble and runs full width, so cards inside it never get a double border. Each
  turn carries a tiny uppercase label ("YOU", the agent's name, "ERROR") in a mono face, 10 px with wide tracking.
- **Type:** agent text in a readable serif or the brand's display face, about 15 px with 1.55 line height. User text
  in sans, about 13 px, keeping line breaks. Both come from theme variables.
- **Thread:** a flex column with a 12 px gap and 16 px padding, a thin scrollbar, and auto-scroll to the newest turn
  unless the user has scrolled up.
- **Progress:** no token streaming. A pending turn appears at once and pulses (opacity 0.45 to 0.85, 1.6 s). A
  polite live region announces it for screen readers. The pending turn is replaced by the answer.
- **Errors:** an error turn has a coral left rule and a warm wash, with the text kept in the ink colour for contrast.
  The words are the fixed plain-English failure text, never a stack trace.
- **Cards inline:** summary sections, explorer tables ("Showing 50 of N rows"), a collapsible query trail, follow-up
  chips, action drafts and action results all render inside the agent's turn, 12 px below its text.
- **Rich text:** parse answers into runs and render `<strong>`, `<em>` and `<span>`. Never use `lwc:inner-html` for
  answers; in the reference app it rendered every answer empty on record pages.
- **Empty state:** a headline that names the page context ("Ask Customer Summary about <Account>"), one line on where
  answers come from, and full-width suggestion buttons (left aligned, hairline border, 6 px radius).
- **Composer:** a multi-line text area that grows to about 6 lines, with the mic button and Send on its row. Enter
  sends; Shift-Enter adds a new line. The composer stops key propagation so Lightning's single-key shortcuts don't fire
  while typing; the hotkeys and Esc are handled by the component itself. The input needs `min-width: 0` or it
  overflows at 320 px.
- **Quick actions:** chips above the composer that change with context. On an account: "Summarize", "Open deals",
  "Recent activity", "Create a follow-up", "Log a call". Off an account: "Ask anything", and the last account's
  summary.
- **Motion:** sheets slide with `cubic-bezier(0.32, 0.72, 0, 1)` at about 280 ms; small moves use 120 or 180 ms with
  `cubic-bezier(0.25, 0.46, 0.45, 0.94)`. The launcher scales away as the sheet opens. `prefers-reduced-motion: reduce`
  turns the transitions off.
- **Accessibility:** the sheet is a labelled dialog or complementary region. Focus moves into it on open and back on
  close; Esc closes. Every button has an accessible name, and jest-axe reports zero violations.

## Voice

The pattern comes from the same reference app. It is proven to run under Lightning Web Security with no CSP, trusted
site or permission metadata.

- **Engine:** the browser's Web Speech API (`window.SpeechRecognition || window.webkitSpeechRecognition`),
  `continuous = true`, `interimResults = true`, language from the user's locale with `en-US` as fallback.
- **Interaction:** one toggle button (aria-label "Talk" or "Stop"; a recording style while on). Interim words appear
  live in the composer. Recording stops after 3 s of silence; the timer resets on every result.
- **Never auto-send.** The words land in the editable composer, and the user sends.
- **Events:** lowercase names only (`transcriptupdate`, `transcriptfinal`, `recordingstate`, `voiceerror`); LWC
  rejects hyphens. `disconnectedCallback` stops recognition.
- **Errors:**
  - `not-allowed` shows "<Agent name> needs microphone permission to listen."
  - Any other error shows "Voice input had an issue. Try again or type instead."
  - If the API is missing, the mic is hidden and a short note says voice is not available in this browser. Chrome
    and Edge are full; Safari is patchy; Firefox has none. Typing always works.
- **Privacy:** Chrome sends the audio to Google's servers to transcribe it. The README says so in one line.
- **Testing:** Jest with a mocked recognizer. Automated Chromium cannot speak to the API, so the real check is by hand
  in Chrome.

## Theming

- **Brand settings record:** one custom metadata record (`Default`) holds the agent name, company name, logo static
  resource name, colours (primary, accent, surface, ink) and a tone line. A cacheable Apex method returns them.
- **CSS variables:** each surface sets them as inline custom properties on its host (`--cs-color-primary`,
  `--cs-color-accent`, `--cs-color-surface`, `--cs-color-ink`, `--cs-font-display`, `--cs-font-body`,
  `--cs-radius`). The stylesheets read only these variables, with neutral fallbacks. SLDS styling hooks are used where
  they fit.
- **Tone:** the tone line is added to the Apex prompts (summary synthesis, explorer) and, after the agent publish, to
  the agent's instructions.
- **Swap guide:** a page tells a seller exactly which record and fields to change, and how to redeploy.

## Write actions

- **Flow:** ask (typed, spoken or a chip) → the agent or the Apex router picks the action → the service builds a
  draft (validated, no DML) → the conversation shows a draft card (fields, Confirm, Edit, Cancel) → Confirm commits in
  user mode → a result card links to the record. Where the platform allows it, an Undo is offered for 15 seconds after
  an update.
- **Security:** user mode for every query and DML, so CRUD, FLS and sharing apply. Permission set additions go in
  the data-access set, listed field by field.
- **One service:** the panel calls it through `@AuraEnabled`, the agent through invocable actions, and MCP through
  the same invocables.

## Gotchas carried forward

- Lightning's single-key shortcuts fire inside an input unless the input stops propagation. A document listener
  handles the hotkeys and yields when `defaultPrevented`.
- DML before a callout in the same transaction throws "uncommitted work pending". Commit drafts in a separate call
  from any model call.
- A compile-time reference to `aiplatform.*` breaks installs in orgs without Agentforce. Keep it behind a seam.
- Agent publishes are slow and have failed before. Batch them.
