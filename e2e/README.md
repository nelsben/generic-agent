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
one worker, no parallelism. A full run takes about four minutes.

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

A full run makes **at most about seven model calls** (briefs and questions), so it costs money
and writes brief memory rows, as any use of the panel does:

| Spec | Calls |
|---|---|
| 1. Cmd/Ctrl-K before the utility was ever opened | 0 |
| 2. Esc returns focus; Tab can leave | 0 |
| 3. Brief: headline, collapsed accordions, live region | 1 |
| 4. Composer pinned at 340x480, newest answer in view | 2 |
| 5. Latest wins | 1 |
| 6. Typing enables Send; Enter sends | 0 |
| 7. Drill and breadcrumb | 1 (it fails if no brief section line is drillable) |
| 8. axe in the brief and drill states | 1, or 2 when no brief section line is drillable |

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
- the region named `Conversation`, the scroll box (spec 4)
- `data-testid="abp-live-region"`, the panel's polite live region (`lightning-textarea` renders a
  second, empty `role=status`, so the role alone is not enough)
- `data-testid="abp-spinner"`, the loading spinner's container
- `data-testid="abp-summary-headline"`, the brief's summary headline, apart from the accordion
  section headers, which are also level-2 headings
- `lightning-breadcrumbs` and `lightning-accordion-section`, to find the drill trail, each brief
  section and its header button
- `article`, to find the drill view's heading
- `button[data-id]`, a drillable section line or result row

Every brief line that describes one record (a deal, a contact, a case, a task, a call) is a
drill button; spec 7 fails if none is. Spec 2 checks that focus is back where the hotkey was
pressed after Esc, and is still there 2.5 seconds later, once the utility bar's own late focus
moves are over. Spec 5 waits on the Aura response of the panel's Apex method, matched by method
name only.

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
  alias, and Edge Communications. Sign-in is the e2e global setup; capture never logs in itself.
- `playwright-report/index.html` from a full `npm run test:e2e` run, for `e2e-report.png`.
- `/opt/homebrew/bin/ffmpeg` and `ffprobe`, which turn the recorded video into GIFs (two-pass
  palette, 12 fps, at most 900 px wide).
- Model calls: one brief, one follow-up question and one explorer question per run (plus about
  seven for the `test:e2e` run). The resolver stills (`not-found.png`, `ambiguous.png`) and
  `hotkey-open.gif` make none. Nothing is written to the org beyond the panel's own memory rows.

What it produces: stills at viewport 1440x900 and deviceScaleFactor 2, cropped to the panel and
the record header (at most 1600 px wide); GIFs cut from the test's video, 6 to 20 seconds, each
starting on a settled frame. `brief-flow.gif` cuts most of the spinner wait between Send and the
answer. Raw videos stay in `test-results/capture/raw/` (gitignored). One frame per second of each
GIF, and its last frame, are written outside the repo for review (`$TMPDIR/abp-capture-frames/`,
or `CAPTURE_FRAMES_DIR`).

### Privacy rules

- **Never traced.** Video and screenshots only: tracing and HAR are off, as in the e2e config. The
  browser URL is never in frame (Playwright captures the page, not the browser chrome).
- **The running user is never shown.** At run time the script reads the user's Id and username
  with `sf org display user --target-org <alias> --json` and the name, email and nickname with one
  User query. They stay in memory: never printed, logged, put in an error or written to disk. A
  context init script replaces each of them, on every animation frame before paint and inside
  every shadow root, with `Sample Owner`.
- **Masked everywhere:** any email address becomes `email hidden`, any 15 or 18 character record Id
  (letters and digits with at least one digit) becomes `Id hidden`, and injected CSS and inline
  styles hide the global header's avatar button and every round user photo.
- **Checked, not trusted.** Before every still, and every 0.5 s of every recording, the script reads
  all visible text on the page, shadow roots included, and fails the run if it finds the user's
  identity, an email address, a 15 or 18 character Id, or `URL_Redacted`. The error names the asset
  and the category only, never the text.
- **Cropped.** Stills and GIFs show the panel and enough of the record page for context, not the
  global header.
- **Sample data only.** Captures use the demo account Edge Communications and other demo records.
  Explorer questions in captures do not ask for owners.
- **Review by eye before committing:** every PNG, and the frames written for each GIF.
