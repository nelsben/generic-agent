# FR2 build review (OPS-35)

This review was done on 2026-11-14, on branch `agent/ops/OPS-35`. The branch was cut from `main` at `ea2d7ab`, so it
already includes FE-14, FE-19, FE-26, FE-27, OPS-39 and OPS-45. It checks the built product against the ledger and
decisions in [feature-revision-2.md](../plans/feature-revision-2.md) and the design brief
[fr2-design.md](../plans/fr2-design.md). It covers ledger rows F31 and F43 directly, and traces every other row.

**Method.** The review had four parts:

- **Reading.** The plan and the design, ARCHITECTURE.md, every pattern page and every `docs/research/fr2-*.md` page.
- **Static review.** Architecture and security, by reading the Apex, the LWC bundles and the MCP door metadata. It
  followed the Apex review, LWS security and accessibility skills.
- **Front-end checks in `agent-probe`.** The checks used Playwright at 1440x900 and 1280x720, on the seed account Edge
  Communications. The script is [e2e/review/fr2-review.review.js](../../e2e/review/fr2-review.review.js), with its own
  config. It is not a `*.spec.js` file, so the e2e suite never picks it up. Every still was taken through
  `e2e/capture/kit.js`.
- **Test runs.** The full e2e suite, the Jest suite and `bash scripts/agent-check.sh`.

**Approvals.** In the Approvals table of [gtm-burn-plan.md](../plans/gtm-burn-plan.md):

- "FR2: live checks in `agent-probe`" is approved, so the org checks ran.
- "FR2: e2e and agent tests that create a record" is still pending. So every draft stopped at Cancel. No Confirm and
  no `commitAction` request were sent; the script counts them and found 0.

The security part is a code review only: no agent test, no Testing Center run, and no injection or red-team probe.
Nothing was deployed.

## Verdict

**Ready with fixes. Nothing blocks the README rewrite (OPS-36).** Every FR2 card that has merged has evidence: a
file, a test, a capture or a page. Every surface works as the rows describe, at both sizes:

- The compact window and the rail open by hotkey and by click.
- Expand keeps the thread.
- The mic is labelled, and it is hidden when the browser has no speech API.
- The draft stops at Cancel and writes nothing.
- History reopens a past conversation.
- A theme variable set from the test repaints the window.
- Reduced motion turns the transitions off.
- Both speed budgets hold with wide margins.

The trust rule holds in the code:

- All CRM reads and writes run in user mode.
- Every system-context use is marked.
- The model door is the only place that names `aiplatform`.
- No component uses `lwc:inner-html`.
- The draft never writes.
- The commit makes no callout.
- Each skill has one service behind it, used by the compact window, the rail and MCP.

Five findings should be fixed before the build is shown to customers. They are ranked below:

- the session text can be read outside our surfaces (M1);
- the composer is crushed when voice is unavailable (M2);
- the unsigned undo token (M3);
- the e2e drill specs fail now and then (M4);
- an axe target-size failure at 1280x720 (M5).

The rest are low: stale lines in docs and in the code's reasons, crowding in the chart and the chip row, and test rows
left in the org.

## Measured numbers (2026-11-14, `agent-probe`)

OPS-36's proof table takes these from here.

| Measure | Result |
| --- | --- |
| Full e2e suite, first run (42 tests) | 38 passed, 3 failed, 1 skipped (the Mac-only Ctrl-K case on the windows project). By project: `mac` 31 of 32 passed; `windows` 7 of 10 passed, 2 failed, 1 skipped |
| The three failures, re-run on their own | 3 of 3 passed. They were panel spec 7 (`mac`, focus on the record heading after a drill) and conversation View record specs 1 and 2 (`windows`, the breadcrumb never appeared after a drill). See M4 |
| e2e by file (first run) | panel 11 of 12; rail 8 of 8; history 2 of 2; hotkey-platforms 7 of 8 (1 skipped); a11y-snapshot 3 of 3; conversation-fr2 4 of 4; conversation-actions 1 of 1; conversation-view-record 2 of 4 |
| `bash scripts/agent-check.sh` | pass. Local compile ok with 0 warnings, and `sf agent validate authoring-bundle` ok for `Customer_Summary` on `agent-probe` |
| Jest (`npm run test:unit`, including jest-axe and sa11y) | 11 of 11 suites, 381 of 381 tests passed. 35 axe assertions, in 10 test files |
| Review checks (this card) | 9 of 9 passed (four at each size, and the voice stub once) |
| axe on each open surface (WCAG 2.0, 2.1 and 2.2 A and AA) | At 1440: compact window 0, draft card 0, rail 0. At 1280: compact window 1, draft card 1, rail 0. Both 1280 failures are the same one: `target-size` on the window's Minimize button. See M5 |
| Rows the org gained in this run, on Edge Communications | Sessions +1 (9 to 10), outcomes +12 (66 to 78), tasks +0, events +0. Org totals: sessions 15 to 16, outcomes 78 to 90 |

### Speed budgets

| Budget ([fr2-design.md](../plans/fr2-design.md)) | e2e spec | Measured |
| --- | --- | --- |
| Compact window: key to first painted frame, under 300 ms | panel spec 10, five warm samples per project | `mac` 10, 12, 19, 6, 11 (median 11, max 19). `windows` 20, 17, 4, 12, 16 (median 16, max 20) |
| Rail: key to first painted frame, under 300 ms | rail spec 6 | `mac` 14, 12, 21 (median 14). `windows` 14, 19, 17 (median 17) |
| Rail: context filled within 1.5 s (warm) | rail spec 6 | `mac` 304, 263, 399 (median 304). `windows` 323, 288, 330 (median 323) |
| The same, re-measured by the review script (three warm samples each) | review | 1440: compact 8, 10, 9; rail 25, 41, 40. 1280: compact 22, 10, 11; rail 19, 48, 42 |

## Front-end checks

| Check | 1440x900 | 1280x720 | Still |
| --- | --- | --- | --- |
| Compact window by hotkey | opens 420 x 560, 16 px from the right and 48 px from the bottom | same | [1440](../assets/fr2-review-1440-compact.png), [1280](../assets/fr2-review-1280-compact.png) |
| Compact window by click on the launcher | opens, and focus is on the composer | same | |
| Quick actions | Summarize, Open deals, Recent activity, Create a follow-up, Log a call. The row is 136 px wider than the window and scrolls sideways (L5) | same | |
| Voice button | present, named "Talk" | same | |
| Voice, with the speech API removed | no mic. The note "Voice input is not available in this browser. You can type instead." shows, but it squeezes the composer to a sliver (M2) | not run | [1440](../assets/fr2-review-1440-voice-stubbed.png) |
| Brand variable | `--cs-color-primary` set on the stage from the test: the mic border changed from rgb(1, 118, 211) to rgb(200, 30, 120), and so did the Summarize button, the links and the focus ring. No org record changed | same | [1440](../assets/fr2-review-1440-brand.png) |
| Draft card ("Create a follow-up") | a task draft, NEEDS INPUT, with Confirm disabled until Subject and Due are filled. Cancelled: "Cancelled. Nothing was saved." `commitAction` requests: 0 | same | [1440](../assets/fr2-review-1440-draft.png) |
| Expand keeps the thread | 1 turn before and 1 turn after; the same draft card shows in the rail | same | |
| Rail context sections | Open deals, Recent activity, Cases and Last summary all finish loading (`aria-busy` false) with content | same; the rail is 589 px wide | [1440](../assets/fr2-review-1440-rail.png), [1280](../assets/fr2-review-1280-rail.png) |
| Outcomes timeline | 5 entries shown, with "Show 73 more". Every entry shown is a "Summary, At risk" from today's e2e runs (L9) | same | [1440](../assets/fr2-review-1440-history.png) |
| Sentiment chart | 47 points in a chart 215 px wide; the points overlap and the axis text is tiny (L6) | same | [1440](../assets/fr2-review-1440-history.png) |
| History reopen | 10 conversations listed. The newest is labelled "15 turns" in the list, and it reopens with 10 turns (the script counted `[data-turn]` sections). Both numbers are right: the list label is `Turn_Count__c`, which counts every turn ever written to the session. The stored thread `Turns_JSON__c` keeps only the newest `MAX_TURNS` = 10 (CustomerSummaryMemory.cls:27 and :232-237), and that is what a reopen shows | same | [1440](../assets/fr2-review-1440-reopen.png) |
| Reduced motion | with `reduce`, the window and the rail transitions are `0s`, and no animation is running on the rail. Without it, the window transitions are 0.28 s | same | |
| Open speed | see the speed table | same | |

## Architecture and security (code review)

| Rule | Result | Evidence |
| --- | --- | --- |
| Every query and DML in user mode, apart from the system-context uses BE-37 names | Holds | Every system-context use carries a `// system-context:` reason. AgentLlm.cls:261, the prompt-setting query. CustomerSummaryMemory.cls:103, 203, 284, 314 and 325. CustomerOutcomes.cls:185, 226 and 409. CustomerOutcomeRetentionBatch.cls:6, `without sharing` with its reason. The trust-rule page's table lags behind the code (L1), and two reasons are out of date (L2) |
| No `aiplatform` reference at compile time outside the seam | Holds | Only `AgentLlmModelsApi.cls` (the provider) and its own test, `AgentLlmModelsApiTest.cls`. `AgentLlm` reaches the provider by name, as [pattern 04](../patterns/04-model-provider-seam.md) says |
| No `lwc:inner-html` | Holds | No `lwc:inner-html` and no `innerHTML` in any bundle |
| No hard-coded brand value in components | Holds, with two notes | Every colour and font is `var(--cs-*, fallback)`. The fallbacks differ: `#0b5cab` in customerSummaryVoiceInput.css:21-34 and `#0176d3` in customerSummaryConversation.css:13-14 (L7). One name default, `@api agentName = 'Customer Summary'` in customerSummaryVoiceInput.js:13, is always overridden by `agent-name={micAgentName}` (L8) |
| Draft never writes | Holds | `CustomerSummaryActions.draft` and `draftJson` make no DML and no callout. `draftFromText` makes one model call and writes nothing. The e2e suite and this review sent 0 `commitAction` requests |
| Commit never shares a transaction with a callout | Holds | `commitDraft` rebuilds the draft from its input and writes in user mode. `recordOutcome` (CustomerSummaryActions.cls:974) calls `CustomerOutcomes.record`, which reads settings only. The panel's `commitAction` is its own Aura call; the MCP door's `commit_action` is its own tool call |
| One service behind each skill, for the compact window, the rail and MCP | Holds | Summary: `CustomerSummary`, behind the panel controller's `getBrief` and MCP's `get_account_summary` (`CustomerSummaryGetAction`). Ask anything: `DataExplorer`, behind the controller's `explore` and `drill` and MCP's `ask_anything` (`ExploreAction`). Actions: `CustomerSummaryActions`, behind the controller's draft, commit and undo and MCP's `draft_action` and `commit_action`. The compact window and the rail share one conversation component, so they share one controller. The MCP door is renamed (OPS-31 merged) |
| History visibility as F32 says | Holds in our surfaces, not outside them (M1) | `CustomerSummaryHistory.listSessions` and `getSession` filter on `visibleOwnerId()`, the running user, and check the account again. `CustomerSummaryMemory.history` reads only the user's own rows, after an account check in user mode |
| Privacy grep of the whole tracked tree | Clean | 0 hits for Salesforce-shaped Ids, emails (only `example.com` in the sample data), my.salesforce.com or force.com hosts, URLs with query strings, home paths and consumer keys. The deny-list check found 0 files |
| LWS | No blocked API. Three patterns noted, none blocked | The stage is moved onto `document.body` (customerSummaryPanel.js:114). Document-level capture listeners guard focus, and are removed on disconnect. Some events are `composed: true` (customerSummaryCard.js:437, customerSummaryPanel.js:413, customerSummaryConversation.js:1650). All three work under LWS today; they are the first things to retest if LWS tightens |

## Findings

Ranked by severity. Each one gives the file and line, and a proposed card title. No code was changed by this card.

### Medium

**M1. A rep's conversation text can be read outside our surfaces.**
- *Where:* Customer_Summary_Data_Access.permissionset-meta.xml:128 gives reps read access to `Turns_JSON__c`, and
  :98 to `Last_Question__c`. Customer_Summary_Session__c.object-meta.xml:17 has `enableReports` set to true.
- *Why it matters:* F32 says each rep sees only their own history. Our surfaces filter by owner, but a manager above
  the rep in the role hierarchy, or anyone the row is shared with, can read the turns through a report or the API.
  [fr2-conversation-history.md](../research/fr2-conversation-history.md) names the hierarchy and leaves N6 open.
  Customer outcomes do it the stricter way (BE-35, F87): reps get no field access to the text, and the service reads
  it in system context.
- *Proposed card:* "History: remove rep field access to the session turn text, so F32 holds in reports and the API
  too".

**M2. When the browser has no speech recognition, the voice note crushes the composer.**
- *Where:* customerSummaryVoiceInput.html:20 renders the note inside the composer row, a flex row with no wrap
  (customerSummaryConversation.css:594-599). The textarea shrinks to about 10 px
  ([still](../assets/fr2-review-1440-voice-stubbed.png)).
- *Why it matters:* any browser without the API (Firefox, for one) gets a composer the rep can barely type into. This
  breaks F19's "We also need to be able to type".
- *Proposed card:* "Voice: show the unsupported note below the composer, not beside it".

**M3. The undo token is not signed.**
- *Where:* CustomerSummaryActions.cls:1022-1044. The token is base64 JSON, and its 15-second window is read from the
  token's own `at` field.
- *Why it matters:* a client that builds its own token can run an allow-listed, user-mode update on the token's
  account at any time, with no draft and no Confirm. It also removes that user's own Action outcome. Page 13
  (13-write-actions.md:188) accepts this, because it can only do what the seller could already do. But it is a write
  path that skips F18's draft-and-Confirm.
- *Proposed card:* "Actions: sign the undo token, or keep the before-values on the server, so Undo cannot skip
  Confirm".

**M4. The drill specs fail now and then.**
- *Where:* the first full run failed panel spec 7 (e2e/panel.spec.js:348, focus on the record heading after a drill)
  and conversation-view-record specs 1 and 2 on the `windows` project (the breadcrumb never appeared within 60 s).
  All three passed when re-run on their own.
- *Why it matters:* this is the same "spec 2 fails now and then, cause not found" pattern that FE-21 fixed for one
  spec. A flaky drill weakens the suite as the gate for front-end changes (F89).
- *Proposed card:* "e2e: find why the drill specs fail now and then (panel 7, View record 1 and 2)".

**M5. axe fails `target-size` on the compact window's Minimize button at 1280x720.**
- *Where:* the `.slds-button_icon[title="Minimize"]` button in the window's header. It fails on the compact window
  and the draft card at 1280x720 only; at 1440x900 the same scans are clean. The likely cause is the small icon
  buttons sitting next to something else at that size.
- *Why it matters:* this is WCAG 2.2 AA (2.5.8). The suite does scan WCAG 2.2 AA: e2e/panel.spec.js:23 (`WCAG_TAGS`
  includes `wcag22aa`), :77-96 (`axeScan`) and :360-373 (spec 8, the brief and drill states). But
  playwright.config.js sets a 1440x900 viewport only, so no axe scan runs at 1280x720, where this failure shows.
- *Proposed card:* "Panel: header icon buttons meet the 24 px target size at 1280x720, and the suite's axe scan
  also runs at 1280x720".

### Low

- **L1. The trust-rule page's table is stale.** [fr2-trust-rule.md](../research/fr2-trust-rule.md):35-41 does not
  list `CustomerOutcomes` (three markers) or `CustomerOutcomeRetentionBatch`. The history read's reason has also
  changed since. *Card:* "Trust rule: bring the system-context table up to date with BE-35 and BE-26".
- **L2. Two system-context reasons contradict the permission set.** CustomerSummaryMemory.cls:314 and :325 say
  "reps have no access to the object". Customer_Summary_Data_Access grants reps read on it. *Card:* "Memory: correct
  the system-context reasons for findRows and findRowsForUpdate".
- **L3. Page 13 says the cards are not drawn yet.** 13-write-actions.md:149 and :192 say the cards "are not drawn
  in the panel yet", but FE-14 drew them ([fr2-action-draft.png](../assets/fr2-action-draft.png)). *Card:* this
  belongs in the docs sweep (OPS-48); if it is not caught there, "Page 13: See it and open items after FE-14".
- **L4. The model-door page undercounts the model calls in a summary.**
  [fr2-model-door.md](../research/fr2-model-door.md):53 says "up to 3 requests". Since BE-36 added the sentiment
  call, a summary makes up to 4 (CustomerSummary.cls:37). *Card:* "Model door page: a summary is up to 4 model
  calls".
- **L5. The quick-action chips scroll sideways in the 420 px window.** The five chips are 136 px wider than the
  row (customerSummaryConversation.css:533-540, `nowrap` and `overflow-x: auto`). "Create a follow-up" is cut off,
  and "Log a call" is out of sight until the row is scrolled. *Card:* "Panel: the five quick chips fit, or wrap, in
  the 420 px window".
- **L6. The sentiment chart crowds 50 points into the rail.** customerSummarySentimentChart.js:25 sets
  `LIMIT = 50`. The review saw 47 points in 215 px: the dots overlap, the axis text is about 6 px high, and the two
  date ticks read the same day. *Card:* "Sentiment chart: thin or bucket the points to fit the rail's width".
- **L7. The fallback blues differ between components.** customerSummaryVoiceInput.css:21-34 falls back to
  `#0b5cab`; customerSummaryConversation.css:13-14 falls back to `#0176d3`. This only shows when brand settings fail
  to load. *Card:* fold into L5's card, or "Theme: one fallback palette".
- **L8. The mic has a hard-coded default name.** customerSummaryVoiceInput.js:13 has
  `@api agentName = 'Customer Summary'`. The conversation always overrides it (customerSummaryConversation.html:427),
  but a reuse of the mic elsewhere would show the default. *Card:* fold into L7's card.
- **L9. The e2e runs leave outcome rows on the seed account.** Edge Communications holds 78 outcome rows after this
  run (66 before it). The timeline shows only today's "Summary, At risk" entries, with "Show 73 more", and the chart
  is all one label. The purge job is "not approved" in the Approvals table. *Card:* "e2e: remove the outcome rows the
  suite writes, or run it on its own account".
- **L10. The MCP door's External Client App lists a second callback.** CustomerSummaryMcpClient.ecaGlblOauth-meta.xml:3-4
  lists the Postman OAuth callback next to the Claude callback. It is a test convenience, not needed by Claude.
  *Card:* "MCP door: drop the Postman callback before customers copy the door".
- **L11. The MCP door marks `resolve_account` as not read-only.** CustomerSummaryMcp.mcpServerDefinition-meta.xml:45
  has `readOnly` false on `resolve_account`, which only reads. A client may then ask for a confirmation it does not
  need. *Card:* fold into L10's card.
- **L12. Some research pages have no Undo list.** The count uses one rule: a heading that matches `^#.*undo`
  (case-insensitive). Of the 26 `docs/research/fr2-*.md` pages, 11 have such a heading and 15 do not.
  - **With one:** action-cards, actions-spike, agent-memory, agent-publish, card-architecture, coworker-spike,
    explorer-scale, rename-go, rename-org, standard-limits and surfaces-spike. fr2-action-cards' match is "Confirm,
    the result card and Undo", which is about the product's Undo button, not a list of leftovers.
  - **Without one:** most of the 15 changed only product metadata that ships in `force-app`, so they leave nothing
    behind. [fr2-retire-ask-agent.md](../research/fr2-retire-ask-agent.md) is counted among the 15. It has an
    inline "To undo" line (:63) but no heading, and it leaves `AccountBriefAgentClient` and its test in the org. *Card:* fold into the docs sweep (OPS-48).

### Notes (no card)

- README.md:23-24 and ARCHITECTURE.md:82, :103 and :188 still use the old titles of pages 07 and 08 ("Trust, access
  and failure", "Test and release lifecycle"). OPS-36 and OPS-49 rewrite those pages and have not landed.
- Over MCP, `ask_anything` (`ExploreAction`) does not remember turns; the panel's `explore` does. The client keeps the
  thread there.
- CustomerSummaryActions.cls is 1240 lines long, and it logs with `System.debug` (for example, :983).
  These are refactor candidates, not defects.
- `docs/assets/panel-ask-agent.png` and the `agent-*.png` captures still show the retired "Ask the agent" button.
  They are referenced only from research and MANIFEST.md; OPS-52 recaptures.

## Trace: ledger rows F01 to F93

Key:

- **Yes:** the shipped thing matches Ben's words.
- **Partly:** part of the row has shipped, and the rest waits on a named card or a finding.
- **Not landed:** the row's card has not merged; that is a line here, not a finding.
- **Tabled, open, parked or done:** as the ledger says.

Cards not landed on 2026-11-14:

- **Blocked:** OPS-36, OPS-48, OPS-49, OPS-52, OPS-28, OPS-57, OPS-58, BE-47 and FE-24.
- **Queued:** OPS-43.

Parked cards: BE-28, BE-38, FE-5, FE-23, OPS-33, OPS-34, OPS-53, OPS-54 and OPS-10.

| Row | Where it shipped, or why not | Matches |
| --- | --- | --- |
| F01 | The workbook: `docs/patterns/00` to `14`, and docs/guides/models-api-prompts.md. The README framing is not landed (OPS-36) | Partly; not landed (OPS-36) |
| F02 | One branded agent with skills in our surfaces: summary, ask anything and actions, through one conversation component (customerSummaryConversation, CustomerSummaryPanelController). The sub-capabilities in the optional agent are parked (BE-28) | Yes in our surfaces; the agent part is parked |
| F03 | Customer Summary names across Apex, LWC, objects and the agent: BE-21, BE-23 and OPS-30 ([fr2-rename-go.md](../research/fr2-rename-go.md), [fr2-rename-org.md](../research/fr2-rename-org.md)). The agent's v2 is published and active: OPS-51 ([fr2-agent-publish.md](../research/fr2-agent-publish.md)) | Yes |
| F04 | The MCP door under the new name: mcp-door/…/CustomerSummaryMcp.mcpServerDefinition-meta.xml (OPS-31) and [mcp-door-runbook.md](../research/mcp-door-runbook.md). The README is not landed (OPS-36) | Yes; L10 and L11 |
| F05 | BE-24: Brand_Setting__mdt, BrandSettings.cls and [pattern 10](../patterns/10-brand-and-theming.md), with brand-swap-before.png and brand-swap-after.png | Yes |
| F06 | BE-24's settings and swap guide (pattern 10). This review's brand still shows one variable repainting the window ([still](../assets/fr2-review-1440-brand.png)). The README quick start is not landed (OPS-36) | Partly; not landed (OPS-36) |
| F07 | Renamed everywhere except the parts BE-21 kept (fr2-rename-go.md); v2 published by OPS-51 | Yes; the leftovers are in the "Left in agent-probe" table |
| F08 | BE-24: name, company, logo, colours and the tone of the Apex prompts. The agent's tone is parked (BE-28) | Yes in our surfaces |
| F09 | FE-12: every colour and font is from a `--cs-*` variable (static check), and the review's override test proved it | Yes; L7 |
| F10 | **Tabled**: OPS-34, parked | Tabled |
| F11 | **Tabled**: OPS-34, parked | Tabled |
| F12 | The skills in [fr2-design.md](../plans/fr2-design.md); FE-12's shared conversation | Yes |
| F13 | FE-11 (customerSummaryVoiceInput) in FE-12's shared composer, so the compact window and the rail both have the mic. The review found it labelled "Talk" at both sizes; pattern 11 | Yes; M2 when the API is missing |
| F14 | FE-11 uses the browser's own speech recognition ([pattern 11](../patterns/11-voice-input.md)). The README privacy line is not landed (OPS-36) | Yes; not landed (OPS-36) for the privacy line |
| F15 | BE-22 ([fr2-actions-spike.md](../research/fr2-actions-spike.md)), BE-27 (CustomerSummaryActions, with `draftFromText` for typed or spoken words), FE-14 ([fr2-action-cards.md](../research/fr2-action-cards.md), fr2-action-draft.png). The agent's share is parked (BE-28) | Yes |
| F16 | CustomerSummaryActionCatalog.cls:16-21: create_task, create_event, log_call, update_contact, create_case and update_opportunity; no email drafting | Yes |
| F17 | `LOG_CALL_AS = 'Event'` at CustomerSummaryActions.cls:29, one constant, as Ben said | Yes |
| F18 | Draft, then write only on Confirm: conversation-actions spec 5, and the review's Cancel (0 `commitAction` requests) | Yes; M3 (Undo skips Confirm) |
| F19 | Voice, typing and quick actions (FE-12); history (BE-26, FE-22, FE-15); the review's history reopen | Yes; M2 and L5 |
| F20 | OPS-29 ([fr2-surfaces-spike.md](../research/fr2-surfaces-spike.md)) chose bottom right; FE-13 built it: 16 px from the right and 48 px from the bottom | Yes |
| F21 | FE-13: Cmd/Ctrl-K, with a launcher that shows the key; hotkey-platforms specs (7 of 8, 1 skipped by design) | Yes |
| F22 | FE-12 and FE-13: [fr2-conversation-core.png](../assets/fr2-conversation-core.png) and the review stills | Yes |
| F23 | FE-13 keeps the compact window | Yes |
| F24 | FE-15: Expand carries the session (the review: 1 turn before and 1 after, with the same draft card); FE-13's slide motion (0.28 s) | Yes |
| F25 | OPS-29: pushing the page works only as a hack, so the rail slides over the page | Yes, by the fallback Ben allowed (F26) |
| F26 | FE-15: the rail overlays, with minimize and close | Yes |
| F27 | FE-15, FE-12 and FE-14: summaries, follow-ups, questions and drafts in one thread | Yes |
| F28 | Two levels, compact and rail, in [fr2-design.md](../plans/fr2-design.md). The README telling is not landed (OPS-36) | Yes; not landed (OPS-36) |
| F29 | BE-25 (CustomerSummaryContext, [fr2-rail-context.md](../research/fr2-rail-context.md)) and FE-15: open deals, recent activity (calls, emails, events, tasks), cases and the last summary. All four loaded in the review | Yes |
| F30 | FE-15: Cmd/Ctrl-Shift-K opens the rail directly (rail spec 6, hotkey-platforms) | Yes |
| F31 | Speed and motion budgets, re-measured by this review: first paint 4 to 48 ms against 300 ms, context 263 to 399 ms against 1.5 s. Reduced motion is honoured | Yes |
| F32 | BE-26 (CustomerSummaryHistory, `visibleOwnerId()`), FE-22 (reopen, shown in this review), FE-15 | Yes in our surfaces; M1 outside them |
| F33 | FE-15: [fr2-rail-open.png](../assets/fr2-rail-open.png) and the review's rail stills | Yes |
| F34 | FE-15. The README use case is not landed (OPS-36) | Yes; not landed (OPS-36) |
| F35 | OPS-29 checked both keys; FE-13 and FE-15 built them; hotkey-platforms on both projects | Yes |
| F36 | **Tabled**: the placeholder page [14](../patterns/14-embedded-surface.md) (OPS-32); spike OPS-33 parked | Tabled |
| F37 | **Tabled**: written into OPS-32 (page 14) and OPS-33 (parked) | Tabled |
| F38 | OPS-32's placeholder page only; OPS-33 parked | Yes (placeholder) |
| F39 | The plan page, the design and the FR2 cards | Done |
| F40 | OPS-37: [fr2-plan-review.md](fr2-plan-review.md) | Done |
| F41 | BE-20, merged | Done |
| F42 | **Done**: the notes are rows F44 to F92 | Done |
| F43 | Chapter cards OPS-38 to OPS-45 and OPS-47 have merged; this review (OPS-35); FE-21 and OPS-46 for testing. Not landed: OPS-48 (the sweep), OPS-52 (captures), OPS-36 (README) and OPS-28 (proof in a new org) | Partly; not landed (OPS-48, OPS-52, OPS-36, OPS-28) |
| F44 | OPS-38: [pattern 01](../patterns/01-route-gather-reduce.md) | Yes |
| F45 | OPS-38: pattern 01 has a business part and an architecture part | Yes |
| F46 | OPS-38: how to change the sections and the narrative. The industry switch is **open** (F50) | Yes; open |
| F47 | OPS-38 (the data graph gathered as sections); BE-29's accuracy check ([fr2-summary-accuracy.md](../research/fr2-summary-accuracy.md)) | Yes |
| F48 | OPS-38: the pre-reduce, in generic terms | Yes |
| F49 | Pattern 01's numbered, coloured diagram. The Mermaid render was not checked by this review (see Limits) | Yes, source only |
| F50 | OPS-38: the reduction structure and the swappable sections. Whether to build the switch is **open** | Yes; open |
| F51 | OPS-38: trust and scale sections | Yes |
| F52 | BE-29 (N1, N2, N3, N7, N8 and the accuracy check). The non-admin run is parked (FE-5) | Yes; FE-5 parked |
| F53 | OPS-38's header shape, applied to every pattern page | Yes |
| F54 | OPS-39: [pattern 02](../patterns/02-ask-anything-explorer.md) | Yes |
| F55 | Principle 1; BE-30 ([fr2-follow-ups.md](../research/fr2-follow-ups.md)); BE-31 ([fr2-explorer-scale.md](../research/fr2-explorer-scale.md)); OPS-39. The agent's share is parked (BE-28) | Yes |
| F56 | OPS-39: pattern 02's numbered diagram | Yes, source only |
| F57 | OPS-52 is not landed | Not landed (OPS-52) |
| F58 | BE-30, FE-22 and BE-31 have merged. BE-28 and FE-5 are parked | Yes; parts parked |
| F59 | BE-31 (the discovery spike; it proposed the cards) | Yes |
| F60 | FE-13, FE-22, BE-26 and FE-15; OPS-40 tells it ([pattern 03](../patterns/03-hotkey-panel.md)) | Yes |
| F61 | Superseded by F82 and F83 (FE-20); OPS-40. The README is not landed (OPS-36) | Yes; not landed (OPS-36) |
| F62 | FE-12, FE-22, FE-13 and FE-16 (both hotkey branches, dark theme, screen reader); FE-17. FE-5 is parked. The review's axe scans are clean at 1440 | Partly; M5 at 1280 |
| F63 | FE-17: [fr2-panel-later.md](../research/fr2-panel-later.md) | Yes |
| F64 | OPS-40: pattern 03's numbered diagram | Yes, source only |
| F65 | FE-18 ([fr2-card-architecture.md](../research/fr2-card-architecture.md)), BE-39 (AnswerCard.cls, [fr2-card-contract-apex.md](../research/fr2-card-contract-apex.md)), FE-22 (customerSummaryCard), BE-27 and FE-14 (the draft and result cards); the fr2-cards-*.png captures | Yes |
| F66 | BE-32 ([fr2-standard-limits.md](../research/fr2-standard-limits.md)); OPS-41 ([pattern 00](../patterns/00-why-custom.md)). The README and ARCHITECTURE links are not landed (OPS-36, OPS-49) | Yes; not landed (OPS-36, OPS-49) |
| F67 | OPS-42: [pattern 04](../patterns/04-model-provider-seam.md) | Yes |
| F68 | OPS-42: the trade-off, said plainly | Yes |
| F69 | BE-33: Agent_Prompt_Setting__mdt with a prompt-template source (AgentLlmPromptTemplate); OPS-42 | Yes |
| F70 | Principle 3; OPS-42 | Yes |
| F71 | OPS-42: pattern 04's numbered diagram | Yes, source only |
| F72 | BE-33 ([fr2-model-door.md](../research/fr2-model-door.md)): the model per prompt in settings, the token limit and the time limits; BE-29 | Yes; L4 |
| F73 | OPS-42: [models-api-prompts.md](../guides/models-api-prompts.md); BE-33's try-a-prompt script | Yes |
| F74 | BE-34: [fr2-agent-memory.md](../research/fr2-agent-memory.md) | Yes |
| F75 | BE-35: Customer_Outcome__c and CustomerOutcomes ([fr2-customer-outcomes.md](../research/fr2-customer-outcomes.md)). BE-27 writes an Action outcome for each confirmed write (CustomerSummaryActions.cls:974) | Yes |
| F76 | BE-35: retention per type (Customer_Outcome_Type__mdt, CustomerOutcomeRetentionBatch); the schedule is "not approved". FE-19's timeline is shown in the review | Yes; L9 |
| F77 | BE-36: CustomerSentiment ([fr2-sentiment.md](../research/fr2-sentiment.md)); FE-19's chart | Yes; L6 |
| F78 | BE-35 (the outcome context and "what changed since"); BE-26 | Yes |
| F79 | BE-34. The page that says it plainly is not landed (OPS-43) | Partly; not landed (OPS-43) |
| F80 | Each open item maps to BE-26, BE-35 and BE-34, all merged. The page listing is not landed (OPS-43) | Partly; not landed (OPS-43); M1 is N6 |
| F81 | Not landed (OPS-43) | Not landed (OPS-43) |
| F82 | OPS-44: [pattern 06](../patterns/06-agent-routing-and-verbatim-relay.md) is an appendix. The README is not landed (OPS-36) | Yes; not landed (OPS-36) |
| F83 | FE-20: "Ask the agent" removed ([fr2-retire-ask-agent.md](../research/fr2-retire-ask-agent.md)). BE-28 parked | Yes |
| F84 | Positioning in fr2-design; OPS-41; OPS-44. The README is not landed (OPS-36) | Yes; not landed (OPS-36) |
| F85 | OPS-45: [page 07](../patterns/07-trust-access-and-failure.md) is "Trust by design"; OPS-38 and OPS-40 carry the failure behaviour | Yes; README and ARCHITECTURE still use the old title (not landed: OPS-36, OPS-49) |
| F86 | OPS-45 keeps the permission-set reference. The README step and the sweep are not landed (OPS-36, OPS-48); FE-5 and OPS-53 are parked | Partly; not landed (OPS-36, OPS-48) |
| F87 | BE-37: [fr2-trust-rule.md](../research/fr2-trust-rule.md) and its test; BE-35 (no rep field access to the outcome text); FE-19; BE-26; BE-33 | Yes in the code; L1, L2 and M1 |
| F88 | OPS-46 ([fr2-ladder.md](../research/fr2-ladder.md)); OPS-47 ([pattern 08](../patterns/08-test-and-release-lifecycle.md)). BE-38 is parked; OPS-28 is not landed | Partly; parked (BE-38), not landed (OPS-28) |
| F89 | FE-21 ([fr2-front-end-tests.md](../research/fr2-front-end-tests.md)); each surface's specs; the counts above | Yes; M4 |
| F90 | OPS-47: pattern 08's "What the tests prove" | Yes |
| F91 | OPS-47 and OPS-46 | Yes |
| F92 | Withdrawn and dropped, as the ledger says | Done |
| F93 | OPS-37: [fr2-plan-review.md](fr2-plan-review.md) | Done |

## Left in agent-probe

This table is built from the Undo list of every `docs/research/fr2-*.md` page, plus the MCP door runbook, which FR2
renamed. Five pages say their run left nothing but debug logs or session rows: fr2-actions-spike,
fr2-agent-memory, fr2-coworker-spike, fr2-explorer-scale and fr2-standard-limits. By the rule in L12 (a heading
that matches `^#.*undo`), 15 of the 26 pages have no Undo section. fr2-retire-ask-agent.md is one of the 15: its
inline "To undo" line is read for this table anyway.

| What is left | Page | Removing it needs |
| --- | --- | --- |
| Agent `Customer_Summary` v2 active, v1 inactive; v2's BotVersion, AiAgentDefinition version `Customer_Summary#2`, GenAiPlannerBundle `Customer_Summary_v2` and authoring bundle `Customer_Summary_2` | [fr2-agent-publish.md](../research/fr2-agent-publish.md) | Kept on purpose: it is the live agent |
| Bot and AiAgentDefinition `Customer_Summary`, its v1 metadata, and one session row updated in place | [fr2-rename-go.md](../research/fr2-rename-go.md) | Kept: the renamed agent |
| Permission set `FR2_Cards_Spike_Access` and its assignment, tab `FR2_Cards_Spike`, and the `cardSpike*` LWC bundles | [fr2-card-architecture.md](../research/fr2-card-architecture.md) | A destructive deploy (none approved) |
| App `FR2_Surface_Spike`, its FlexiPages and tab, the `surfaceSpike` LWC, and permission set `FR2_Surface_Spike_Access` and its assignment | [fr2-surfaces-spike.md](../research/fr2-surfaces-spike.md) | A destructive deploy (none approved) |
| The `Customer_Summary_User` assignment and 62 deployed components | [fr2-rename-org.md](../research/fr2-rename-org.md) | Kept: the product |
| 28 old `AccountBrief%` Apex classes (15 classes and 13 tests; their 93 test methods run in every RunLocalTests) and the `AgentPrompt_BriefSynthesis` static resource | [fr2-rename-org.md](../research/fr2-rename-org.md) | A destructive deploy: OPS-54, "not approved" |
| `AccountBriefAgentClient` and its test, still in the org after the button was removed | [fr2-retire-ask-agent.md](../research/fr2-retire-ask-agent.md) (no Undo heading) | A destructive deploy, with the OPS-54 set |
| The old `AccountBriefMcp` server and `AccountBriefMcpClient` app, still active next to the renamed door | [mcp-door-runbook.md](../research/mcp-door-runbook.md) | Deactivate, then a destructive deploy |
| Test rows from e2e runs: 78 outcome rows and 10 session rows on Edge Communications, after this review (L9) | this page | A cleanup script or the purge job (both need approval) |

## Limits

- **Not checked:** the Mermaid render. The CDN render check was not run (the coordinator's instruction), so the
  sequence diagrams (F49, F56, F64, F71) were checked as source only.
- **Drafts:** no record-creating step ran, because that Approvals row is pending. Confirm, the result card and
  Undo were not exercised live; their evidence is Jest and the specs that stop before Confirm.
- **Reading depth:** the long research pages were read for their findings, Undo lists and open items, not line by
  line.
- **How the e2e suite ran:** one spec file or group at a time. The tool moved two of the runs (the panel spec, and
  the three conversation specs) to the background after 3 minutes; each was waited for and not started twice.
- **Out of scope:** a non-admin run (FE-5, parked). Everything here ran as the admin user.
- **Undo count:** the count of pages without an Undo section (15 of 26) uses the rule in L12, a heading that matches
  `^#.*undo`. fr2-retire-ask-agent.md, with only an inline "To undo" line, counts as having none.
- **Main has moved on:** this review read `main` at `ea2d7ab`. Since then, page 05 has been rewritten (OPS-43) and
  the pattern sweep (OPS-48) is under way. The notes on page titles (README and ARCHITECTURE for 07 and 08) and on
  page 13 (L3) may be stale.
