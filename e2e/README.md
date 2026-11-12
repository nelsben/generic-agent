# Account Brief panel: end-to-end tests

Playwright journeys for the `accountBriefPanel` utility bar panel, run in a real org as the
developer's own signed-in user. They cover what the Jest suite cannot: the real utility bar, the
real Lightning base components, focus, layout and the live region.

## Run

```bash
npm ci
npm run test:e2e                         # org alias from SF_TARGET_ORG, default "agent-probe"
SF_TARGET_ORG=my-alias npm run test:e2e  # any other signed-in alias
SF_E2E_ORG=my-alias npm run test:e2e     # same, and wins over SF_TARGET_ORG for e2e only
npx playwright test -g "6. typing"       # one spec
```

Chromium only (Playwright's own build, `npx playwright install chromium` if it is missing),
one worker, no parallelism. A full run takes about four minutes (3.3 minutes for 9 of 9 in `agent-probe`).

## What it needs

- **A deployed panel.** The org must already have the Account Brief app
  (`Account_Brief.app-meta.xml`), its utility bar with `accountBriefPanel` (eager, 340x480) and the
  Apex behind it. The suite never deploys anything.
- **A signed-in sf CLI session** for the alias (`sf org login web -a <alias>`). The global setup
  asks `/usr/local/bin/sf org open --url-only --json -o <alias>` for a one-time frontdoor URL,
  opens it in an untraced browser context and saves the session to `e2e/.auth/` (gitignored).
  It never asks for or types a password. If the session is missing or expired it stops with one
  line telling you to run `sf org login web -a <alias>`.
- **The sample data**, including the account Edge Communications, which is looked up by name at run time.
  Load it with `bash scripts/seed-sample-data.sh` (it targets `SF_TARGET_ORG`, default `agent-probe`, and
  stops if Edge Communications already exists). It is not Developer Edition demo data.

The frontdoor URL and the session it opens are secrets: they are never printed or written
anywhere but `e2e/.auth/`. For the same reason tracing, video and HAR are off in
`playwright.config.js` (a trace records request headers and Aura bodies). Screenshots of failures
go to `test-results/`, the HTML report to `playwright-report/`; both are gitignored.

## Model calls

A full run makes **at most about nine model calls** (briefs, questions and two agent turns), so
it costs money and writes brief memory rows, as any use of the panel does:

| Spec | Calls |
|---|---|
| 1. Cmd/Ctrl-K before the utility was ever opened | 0 |
| 2. Esc returns focus; Tab can leave | 0 |
| 3. Brief: headline, collapsed accordions, live region; the pinned bar at most 80 px, the scroll box at least 240 px | 1 |
| 4. Composer pinned at 340x480, newest answer in view | 2 |
| 5. Latest wins | 1 |
| 6. Typing enables Send; Enter sends | 0 |
| 7. Drill and breadcrumb | 1 (it fails if no brief section line is drillable) |
| 8. axe in the brief and drill states | 1, or 2 when no brief section line is drillable |
| 9. Ask the agent, then a follow-up that reuses its agent session | 2 agent turns (each runs the agent's own actions) |

Specs 5 and 6 send `/brief` of a name that matches no account: the resolver answers from SOQL
with no model call. Spec 5 uses it as the second request because it lands well before the first
(a question), so the test sees a late reply arrive and get dropped; it checks that the first was
still in flight, and fails as a test problem if it was not.

## How the specs find things

Every test loads the Account Brief app, then the account's record page, fresh: the utility has
never been opened. Locators pierce the panel's shadow DOM with Playwright's built-in engine:
roles and labels first, then the panel's test hooks and the data attributes it renders
(`data-turn`, `data-id`, `data-focus`):

- `c-account-brief-panel`, the host, to scope every locator and the axe scan
- the region named `Conversation`, the scroll box (specs 3 and 4)
- `.slds-utility-panel__header`, the utility panel's own header (title, Minimize, Pop-out), whose
  bottom edge spec 3 measures the pinned bar from: the platform renders it with no role or label
- `data-testid="abp-live-region"`, the panel's polite live region (`lightning-textarea` renders a
  second, empty `role=status`, so the role alone is not enough)
- `data-testid="abp-spinner"`, the loading spinner's container
- `data-testid="abp-summary-headline"`, the brief's summary headline, apart from the accordion
  section headers, which are also level-2 headings
- `lightning-breadcrumbs` and `lightning-accordion-section`, to find the drill trail, each brief
  section and its header button
- `article`, to find the drill view's heading
- `button[data-id]`, a drillable section line or result row

Spec 3 measures the panel at 340x480 after one brief, with the account's "Earlier briefs" list
rendered: from the panel header's bottom edge to the top of the scroll box is at most 80 CSS px,
the scroll box is at least 240 CSS px tall, and the Brief and "Ask the agent" buttons share one row.

Every brief line that describes one record (a deal, a contact, a case, a task, a call) is a
drill button; spec 7 fails if none is. Spec 2 checks that focus is back where the hotkey was
pressed after Esc, and is still there 2.5 seconds later, once the utility bar's own late focus
moves are over. Spec 5 waits on the Aura response of the panel's Apex method, matched by method
name only.

Spec 9 types "What are the open deals at this account?" and presses "Ask the agent", then asks
"What about their open cases?", which only makes sense after the first turn. It reads each
`askAgent` call's params and return value from the Aura request and response in memory
(`Panel.apexCall`) and compares them as booleans only, so no Id, session or reply text reaches an
assertion message: turn 1 sends the open account and no session, turn 2 sends turn 1's session and
no record, the agent keeps the session, turn 2 does not ask which account, and each reply shows
in its turn in the custom panel. The live region must say "Asking the agent" during each wait. On
the panel before the direct call, the button handed off to the built-in Agentforce panel, so the
spec failed at the live region; it took 42.6 seconds alone after the deploy.

Every test closes the "Meet the new Guidance Center" walkthrough of a fresh org whenever it appears
(`Panel.gotoAccount`), because it covers the page. It was on screen when spec 2 failed in agent-probe.
Spec 2 has also failed there with no walkthrough, cause not found, so it can still be flaky in a fresh
org ([org-migration.md](../docs/research/org-migration.md), "e2e after FE-9").

Accessibility checks use `@axe-core/playwright` scoped to `c-account-brief-panel`, WCAG 2.0-2.2
A and AA rules; the violations of each state are attached to the test as JSON.

## Capture

The screenshots and GIFs in `docs/assets/` (listed in `docs/assets/MANIFEST.md`) come from the
live org with one command:

```bash
npm run test:e2e    # first: e2e-report.png is a screenshot of this run's HTML report
npm run capture     # writes every panel still and GIF into docs/assets/
```

`npm run capture` runs `playwright.capture.config.js` and the `e2e/capture/*.capture.js` files,
one worker. It is separate from the e2e suite: its own test folder and file pattern, its output in
`test-results/capture/` (its `.last-run.json` too) and no HTML report, so it never overwrites the
e2e run's `playwright-report/`. The e2e config does not match `*.capture.js` and Jest only looks
under `force-app/`.

What it needs:

- Everything the e2e suite needs (above): the deployed panel, a signed-in sf CLI session for the
  alias, and the seeded sample account Edge Communications. Sign-in is the e2e global setup;
  capture never logs in itself.
- For `06-agent.capture.js` (`agent-brief.png`, `agent-explore.png`): the `Account_Brief` agent
  published and active, with the running user granted it. **Stale since the direct call:** the
  script opened the built-in Agentforce panel through the custom panel's "Ask the agent" button,
  which now asks the agent itself and shows the reply in the custom panel. It is skipped (`test.skip`)
  until it is pointed at the built-in panel's own entry point; the committed
  stills are from before the change and still show the built-in panel correctly.
- For `07-ask-agent.capture.js` (`panel-ask-agent.png`): the same agent, and the deployed panel
  with "Ask the agent" calling it directly. One agent turn. On a
  user's first use it closes the "Agentforce Learns from Your Conversations" pop-up with "Cancel
  and close" (memory is not turned on) and accepts the generative AI notice with "Got It".
- `playwright-report/index.html` from a full `npm run test:e2e` run, for `e2e-report.png`.
- `/opt/homebrew/bin/ffmpeg` and `ffprobe`, which turn the recorded video into GIFs (two-pass
  palette, 12 fps, at most 900 px wide).
- Model calls per run: four. Three in the custom panel (one brief, one follow-up question and one
  explorer question) and one agent turn through "Ask the agent". The skipped `06-agent.capture.js`
  made two more agent turns in the built-in panel (a brief, then an org-wide count). The `test:e2e` run adds about nine. The resolver stills (`not-found.png`, `ambiguous.png`) and
  `hotkey-open.gif` make none. Nothing is written to the org by the capture itself beyond the
  panel's own memory rows and what the platform keeps for the two agent turns.

What it produces: stills at viewport 1440x900 and deviceScaleFactor 2, cropped to the panel and
the record header (at most 1600 px wide); GIFs cut from the test's video, 6 to 20 seconds, each
starting on a settled frame. `brief-flow.gif` cuts most of the spinner wait between Send and the
answer. `panel-brief.png` frames the brief's question at the top of the scroll box, and the run
fails if the headline and the first two section headers are not all inside it. `explore-answer.png`
frames the question the same way, and the run fails if the table's header row is not inside it.
Its question is the plain "Which 5 open opportunities have the largest amounts?". Rule 9 of
`AgentPrompt_Explore` keeps the answer to a short lead and leaves the rows to the table; before that
rule (BE-17), the answer listed every row and the header row needed 470 px of a 273 px scroll box
([explore-prompt-1.md](../docs/research/explore-prompt-1.md)).
Raw videos stay in `test-results/capture/raw/` (gitignored). One frame per second of each
GIF, and its last frame, are written outside the repo for review (`$TMPDIR/abp-capture-frames/`,
or `CAPTURE_FRAMES_DIR`).

### Privacy rules

- **Never traced.** Video and screenshots only: tracing and HAR are off, as in the e2e config. The
  browser URL is never in frame (Playwright captures the page, not the browser chrome).
- **The running user is never shown.** At run time the script reads the user's Id and username
  with `sf org display user --target-org <alias> --json` and the name, email and nickname with one
  User query, which also reads the first and last name. They stay in memory: never printed,
  logged, put in an error or written to disk. A context init script, which runs in every frame of
  the page, iframes included, replaces each of them, on every animation frame before paint and
  inside every shadow root, with `Sample Owner`. The first and last name are replaced only as
  whole words (no letter or digit on either side), so an agent reply that greets the user by first
  name is masked while a longer word that contains it is left alone.
- **Masked everywhere:** any email address becomes `email hidden`, any 15 or 18 character record Id
  (letters and digits with at least one digit) becomes `Id hidden`, and injected CSS and inline
  styles hide the global header's avatar button and every round user photo.
- **Checked, not trusted.** Before every still, and every 0.5 s of every recording, the script reads
  all visible text in every frame of the page, iframes and shadow roots included, and fails the run
  if it finds the user's identity (the first or last name as a whole word included), an email
  address, a 15 or 18 character Id, or `URL_Redacted`. The error names the asset and the category
  only, never the text.
- **Cropped.** Stills and GIFs show the panel and enough of the record page for context, not the
  global header. The two agent stills crop the right of the page, where the built-in panel docks.
- **Sample data only.** Captures use the sample account Edge Communications and the other records
  seeded from `data/sample/`. Explorer questions in captures do not ask for owners.
- **Review by eye before committing:** every PNG, and the frames written for each GIF.
