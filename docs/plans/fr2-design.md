# FR2 design brief: Customer Summary on three surfaces

Read this before any `FR2:` card. The feedback it answers is in [feature-revision-2.md](feature-revision-2.md); row
numbers (F01 onward) point there. Where a card and this page disagree, the card wins and the worker says so.

## The product

- **One branded agent, many skills.** The default name is **Customer Summary**; a seller can rename it per prospect.
  It works like Claude: one place to ask, and it routes the request. Its skills:
  1. **Summary:** the one-ask account summary (today's brief engine, pattern 01).
  2. **Ask anything:** the explorer (pattern 02).
  3. **Act:** create a task, create an event, log a call, update a contact, create a case, update an opportunity. Each
     shows a draft and writes nothing until the user confirms.
- **The same agent everywhere:** the compact window, the rail, an embedded component later, and MCP clients. One Apex
  service sits behind each skill, and every door calls it. Over MCP the tools are Apex actions; the optional agent is
  not an MCP tool. Agentforce's own panel and "Ask the agent" are not doors (F82, F83); the registered agent is an
  optional add-on (pattern 06's appendix).
- **It is Agentforce, with its own skin** (F84): the platform's models through its trust layer, behind surfaces we
  control. No page argues about whether it counts as Agentforce.
- **Built to be swapped:** brand settings hold the agent name, company name, logo, colours and tone. No component
  hard-codes a name, a colour or a font.

## Operating principles

1. **A follow-up is never a new build.** After a summary, the next question ("which of those close this quarter?",
   "who on their side have we not called?") is answered by the explorer from the same context, in the user's own
   access. Nobody builds a flow or an action to answer a follow-up, and context is not passed back by hand (F54,
   F55). A page claims only the questions pattern 02 lists as proven. Whether the explorer reaches any object in
   any combination is the question `BE-31` answers, and no page says so before its build cards land.
2. **Every answer is richly formatted and shown in cards.** Wherever the product shows text (the compact window, the
   rail, an MCP client), it is formatted for reading, not dumped as plain text, and structured
   data comes as a card from one typed card contract that every surface reads. `FE-18` designs the contract, `BE-39` builds it into the Apex services and `FE-22` renders it (F65).
3. **API first for prompts.** Every model call goes through the Models API from Apex, with prompts kept as files a
   team can read, change, deploy and try in minutes, alone or with an AI coding assistant. A prompt template is an
   opt-in per prompt for teams that need one, never a required layer (F67 to F70).
4. **What the product does for a customer is kept against the customer.** A summary, an action taken or an answer a
   rep saves is a customer outcome: stored against the account, not inside one agent or one conversation, and kept
   for as long as its type says. Anyone who can see the account sees each outcome's type, date and sentiment label.
   Only its author sees its text, because the text is built from what the author could read, unless its type is
   marked to share; for an action, another rep sees a fixed phrase for its kind, not its title. Only a rep's own
   outcomes are fed back in full as context the next time they open a conversation on that account. `BE-35` builds
   the store (F75 to F79, F87).
5. **It sees what the rep sees.** Every door (the compact window, the rail, MCP and the optional agent) runs as the
   signed-in user: every Apex class is `with sharing` unless it carries a named exception, and every read of CRM data is in user mode, so object, field and
   record access all apply. System context is used only where the product keeps its own records, and each use is named
   in the code with its reason and checked by a test (`BE-37`): the conversation history (a rep's own rows, with access
   to the account re-checked on read, `BE-26`), the text of customer outcomes (reps get no field access to it; the
   outcome service returns it, and adds it to a model prompt, only for its author or a type marked to share, `BE-35`),
   the outcome purge job, and
   the product's own prompt files if a rep cannot read them in user mode (`BE-33`). Failures read as one plain
   sentence that says what to do next, never raw error text. Granting access is one permission set group, an
   implementation step in the quick start, not a chapter (F85 to F87).

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
- **Rich text:** the card contract from `FE-18` wins where it differs from this line. Parse answers into runs and render `<strong>`, `<em>` and `<span>`. Never use `lwc:inner-html` for
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
- **Tone:** the tone line is added to the Apex prompts (summary synthesis, explorer). The optional agent's
  instructions do not get it in FR2 (`BE-28` is parked, F83).
- **Swap guide:** a page tells a seller exactly which record and fields to change, and how to redeploy.

## Write actions

- **Flow:** ask (typed, spoken or a chip) → the Apex router picks the action → the service builds a
  draft (validated, no DML) → the conversation shows a draft card (fields, Confirm, Edit, Cancel) → Confirm commits in
  user mode → a result card links to the record. Where the platform allows it, an Undo is offered for 15 seconds after
  an update.
- **Security:** user mode for every query and DML, so CRUD, FLS and sharing apply. Permission set additions go in
  the data-access set, listed field by field.
- **One service:** the panel calls it through `@AuraEnabled` and MCP through invocable actions, which an agent a team
  adds later can call too.

## Pattern page shape

From Ben's notes on pattern 01 (F45, F53). Every page under docs/patterns/ follows it. The headings are fixed words, so
one test helper can check every page.

- **The H1** is the page's title with no number, followed by one line on what the pattern gives a seller or a service
  rep.
- **The H2 headings**, in these exact words and in this order:
  1. `The business problem`: who has it, what it costs them today, and what changes. Plain words, no class names.
  2. `The architecture in a few steps`: three to five numbered steps a non-developer can follow, before any detail.
  3. `How it works`: the sequence diagram, then the steps in detail, each matching a diagram number.
  4. `See it`: a capture on each surface where the pattern runs (the compact window, the rail), a GIF where something
     moves, and alt text on each (F57). `OPS-52` takes them from a written list.
  5. `Why you can trust it`: it opens with two lines. One starts `Runs as the signed-in user:`. The other starts
     `System context:` and names each system-context use on this path with its reason, or says "none on this path"
     (principle 5, F87). Each claim after them is linked to a test, a review or a recorded run.
  6. `How it scales`: each claim is linked to a test, a review or a recorded run.
  7. `Adopt it`: for a builder. One step grants access by assigning the one permission set group, in the same words
     on every page (F86).
  8. `Limits and open items`: each names the open item in plain words. It may give a card id, or say "no card yet".
     It never links a card file.
- **A part of a page's own** (for example pattern 01's reduction structure) is an extra H2 between the fixed ones, and
  the page's test lists it.
- **Exemptions.** Page 00 (why custom) has no `See it`, `Why you can trust it`, `How it scales` or `Adopt it` part.
  On pages 04 and 09 the `See it` part is a text block, not an image. Page 06 is a short appendix, page 07 is one
  screen and page 14 is a labelled placeholder: those three are exempt from the full shape, and the rules below still
  apply to them.
- **No proof status on a page.** A page never says a run is proven or not yet proven. It links the README's Status
  table, the one place that is changed when a run passes.
- **Roles, not people.** A page names the seller, the service rep, the admin or the builder, never a person.
- **The way back.** Every page ends with one line that links the index page and the repo's README.

## Diagrams

From Ben's notes on pattern 01 (F49). Every Mermaid diagram in the repo follows it.

- **Numbered steps.** Sequence diagrams start with `autonumber`. The text under the diagram refers to the same numbers
  ("steps 3 to 6"), so a reader can follow one step from the picture to the words.
- **Colour that carries meaning.** Shaded `rect` blocks group the phases (for example route, gather, reduce), each in
  its own soft tint, with a `Note` naming the phase. Participants are grouped with `box` where it helps (the page, Apex,
  the model). Model calls use one accent colour everywhere, so a reader sees at a glance where a model is involved.
- **Type and theme.** One shared snippet sets the type and layout for every diagram, so every page matches, and text
  keeps WCAG AA contrast in both GitHub's light and dark themes. *Brain-recorded 2026-11-17, on Ben's ask that the
  diagrams be legible and customer facing ("they are messy hard to read, and not customer facing"):* the snippet is
  now a `config` frontmatter block with no fixed theme, so GitHub draws each diagram in its own light or dark palette;
  phases use translucent tints with a slate chip naming each one; lifelines are at most five, in plain business words,
  with no `box` (the lifeline names say the layer); messages are short, and class and prompt names move to the
  numbered steps under the diagram. [_diagram-theme.md](../patterns/_diagram-theme.md) holds the snippets and rules.
- **Checked on GitHub.** A diagram counts as done only when it renders on GitHub (the GitHub markdown API or the pushed
  page), not just in a local preview.

## Lessons from a reviewed build

These come from a production Agentforce build we reviewed. They are restated here in generic terms, with no names and
no numbers from that build; `BE-32` measures our own. A page that uses one cites the source only as "a production
Agentforce build we reviewed".

- **Route, gather, reduce.** Code routes the request and gathers the records in the user's own access. One prompt
  reduces what was gathered to an answer. Prose comes only from the prompt, and data comes only from code.
- **A small set of paths.** The router picks from a small, fixed set of paths.
- **Status codes are relayed as they are.** A status that a step returns (not found, a choice of records, a failed
  section) is passed on unchanged. No model rewords it.
- **A follow-up passes the record's Id.** A follow-up or a retry names the record by its Id, not by its name. A name
  can match two records or none.
- **The agent's model step re-writes a relayed answer.** In the standard chat, the answer an action returns passes
  through the agent's model before the user sees it. The model can reword it, and it shortens a long answer without
  saying so.
- **Builds cut their lists to fit.** To stay under that length a build caps its lists, so the user gets fewer rows
  than exist and no sign that rows were left out.
- **A judge grades only the reply it is shown.** An evaluation that grades the wording of a reply passes an answer
  that left rows out, because it never sees the rows. A check for completeness has to compare the answer with the
  data.
- **Whether a card shows is the model's choice at run time.** In the standard chat a rich card renders only when the
  model picks it, so the same question can come back as a card once and as text the next time. So every answer must
  also read correctly as plain text.
- **Multi-turn tests.** An employee agent cannot be tested over several turns from the CLI, so follow-up behaviour
  needs its own test path.

## Gotchas carried forward

- Lightning's single-key shortcuts fire inside an input unless the input stops propagation. A document listener
  handles the hotkeys and yields when `defaultPrevented`.
- DML before a callout in the same transaction throws "uncommitted work pending". Commit drafts in a separate call
  from any model call.
- A compile-time reference to `aiplatform.*` breaks installs in orgs without Agentforce. Keep it behind a seam.
- Agent publishes are slow and have failed before. FR2 has two: the spike copy (`BE-21`) and the renamed agent
  (`OPS-51`), which is split from the rename deploy so that a failed publish stops nothing else.
