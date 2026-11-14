# Customer Summary panel: end-to-end tests

Playwright journeys for the `customerSummaryPanel` compact window (FE-13): the launcher and the
420x560 window its eager utility item puts at the bottom right of the page, run in a real org as
the developer's own signed-in user. They cover what the Jest suite cannot: the real utility bar
and record page, the real Lightning base components, focus, layout, timing and the live region.

## Run

```bash
npm ci
npm run test:e2e                         # the full suite: the release check, about 7 minutes
npm run test:e2e:smoke                   # one test per surface, about 1.5 minutes: for a front-end change
SF_TARGET_ORG=my-alias npm run test:e2e  # org alias from SF_TARGET_ORG, default "agent-probe"
SF_E2E_ORG=my-alias npm run test:e2e     # same, and wins over SF_TARGET_ORG for e2e only
npx playwright test --project=mac -g "6\. typing"   # one spec
npx playwright show-report               # open the HTML report of the last run (playwright-report/)
```

Chromium only (Playwright's own build, `npx playwright install chromium` if it is missing),
one worker, no parallelism. Two projects run in the one run, whatever machine it is on:
`mac` runs every spec with the panel reading a Mac (Cmd-K), and `windows` runs only the specs
tagged `@hotkey`, with the panel reading Windows (Ctrl-K). `support/panel.js` sets what the page's
`navigator.platform` and `userAgentData.platform` say before any page script runs; the keys the
tests press follow it. A full run is 38 tests (one skips on `windows`: the Mac-only Ctrl-K check; FE-15 ran it in chunks,
so there is no single-run time yet); the smoke run is 11 tests.

### Smoke subset

`npm run test:e2e:smoke` runs the tests tagged `@smoke`, one per surface, for a builder checking a
front-end change (the full suite stays the release check). They make no model call.

| Surface | Smoke test |
|---|---|
| The window and the launcher | 1. Cmd/Ctrl-K opens the window in the corner, composer focused |
| The composer | 6. Typing enables Send; Enter sends |
| The conversation | FR2 2. the scope chip |
| The write-action cards | FR2 5. a draft card from the Create a follow-up chip, then Cancel |
| The accessible names | 12. the fallback names |
| The hotkey, both branches | `hotkey-platforms.spec.js`, the platform key opens the window (runs on `mac` and `windows`) |
| The right rail | `rail.spec.js` 1. Cmd/Ctrl-Shift-K opens the rail over the page, full height; Esc returns focus (runs on `mac` and `windows`) |
| The history timeline in the rail | `history.spec.js` 1. the timeline opens in the context column, newest first, or its empty line; an entry opens and closes (FE-19; `@smoke`, `mac` only) |

### Reading the HTML report

After a run, `npx playwright show-report` serves `playwright-report/` on localhost. The list shows
each test with its project (`mac` or `windows`) and time. Open a failed test for the failing step,
the screenshot taken at the failure and, attached to it, `console.log`: the page's console and
uncaught errors (the last 200 lines). Axe results of specs 8 and 13 are attached as JSON.
Tracing is off, so there is no trace to open. The report is local and gitignored.

## What it needs

- **A deployed panel.** The org must already have the Customer Summary app
  (`Customer_Summary.app-meta.xml`), its utility bar with `customerSummaryPanel` (eager; the item's own panel is 340x200 and only
  holds a note, the window is on the page) and the
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

A full run makes **at most about ten model calls** (briefs and questions), so
it costs money and writes brief memory rows, as any use of the panel does:

The `windows` project runs only specs that make no model call, so it adds none.

| Spec | What it proves, and its model calls |
|---|---|
| 1. Cmd/Ctrl-K before the window was ever opened: bottom right corner, composer focused | 0 |
| 2. Esc returns focus from the Search button, a record field and the launcher, or falls back to the launcher; Tab can leave | 0 |
| 3. Brief: headline, collapsed accordions, live region; the pinned bar at most 80 px, the scroll box at least 240 px | 1 |
| 4. Composer pinned in the 420x560 window, newest answer in view | 2 |
| 5. Latest wins | 1 |
| 6. Typing enables Send; Enter sends | 0 |
| 7. Drill and breadcrumb | 1 (it fails if no brief section line is drillable) |
| 8. axe in the brief and drill states | 1, or 2 when no brief section line is drillable |
| 9. Minimize keeps the conversation; Expand is on with the rail (FE-15) | 0 |
| 10. Time from Cmd/Ctrl-K to the window's first paint, under 300 ms warm | 0 |
| 11. Accessibility snapshot of the stage: closed, open, pending, answered, error; names, live region, focus after Esc (`a11y-snapshot.spec.js`, FE-16) | 0 |
| 12. The fallback names are short-lived and outside the live region (FE-16) | 0 |
| 13. axe `color-contrast` on the open window, light theme (FE-16) | 0 |
| Hotkey 1. The platform key opens the window, the launcher names it (`@smoke`, `mac` and `windows`) | 0 |
| Hotkey 2. The other platform's key does nothing | 0 |
| Hotkey 3. Cmd/Ctrl-Shift-K opens the rail, not the window; Alt opens neither (FE-15) | 0 |
| Hotkey 4. On a Mac, Ctrl-K inside a text field is left alone: window shut, key not taken (`mac` only) | 0 |
| FR2 1. History lists the account's conversations; New conversation starts clean; reopening the newest loads its turns (`conversation-fr2.spec.js`, FE-22) | 1 |
| FR2 2. The scope chip reads About the account, switches to Whole org and back by keyboard (FE-22) | 0 |
| FR2 3. A whole-org question is sent with no context record and its answer is drawn as cards (FE-22) | 1 |
| FR2 4. At 320 px the two tools headings show their full text, wrapped, not clipped (FE-26) | 1 |
| FR2 5. The Create a follow-up chip draws a task draft card in the turn: the account by name, Subject and Due marked Needed, Confirm off until both are filled (each fill re-drafts), then Cancel closes it with "Cancelled. Nothing was saved." and no commitAction request (`conversation-actions.spec.js`, FE-14; `@smoke`). It never clicks Confirm and creates no record: the confirm path is in the Jest and Apex tests | 0 |
| Rail 1. Cmd/Ctrl-Shift-K opens the rail flush right, 640 px wide and full height, over the page (the page does not move); header; Esc returns focus (`rail.spec.js`, FE-15; `@smoke`, `mac` and `windows`) | 0 |
| History 1 and 2. The rail's context column holds the history timeline (the shared card, newest first, an entry opens its detail) and the sentiment chart (labelled points with no line and a text table, or its plain note); with no outcomes on the account each shows its empty line and passes (`history.spec.js`, FE-19; 1 is `@smoke`). Neither writes a record | 0 |
| Rail 2. Expand from the window opens the rail on the same session with the thread intact and History open | 0 (a `/brief` of no account) |
| Rail 3. One question asked in the rail is answered in the rail | 1 |
| Rail 4. Each context section shows rows or its empty line, activity rows name their kind, a row opens its record | 0 |
| Rail 5. Minimize leaves a slim edge tab; resting on it opens a peek that slides back; a click opens it for real | 0 |
| Rail 6. First paint under 300 ms after Cmd/Ctrl-Shift-K and the context filled within 1.5 s, three fresh pages, warm (`mac` and `windows`) | 0 |

Specs 5 and 6 send `/brief` of a name that matches no account: the resolver answers from SOQL
with no model call. Spec 5 uses it as the second request because it lands well before the first
(a question), so the test sees a late reply arrive and get dropped; it checks that the first was
still in flight, and fails as a test problem if it was not.

## How the specs find things

Every test loads the Customer Summary app, then the account's record page, fresh: the window has
never been opened. Locators pierce the panel's shadow DOM with Playwright's built-in engine:
roles and labels first, then the panel's test hooks and the data attributes it renders
(`data-turn`, `data-id`, `data-focus`):

- `[data-cs-stage]`, the stage the eager utility item moves to the page body (the launcher and
  the window), to scope every locator and the axe scan. The utility item itself,
  `c-customer-summary-panel`, keeps only a note. Since FE-12 the conversation inside the window is
  `c-customer-summary-conversation`; locators pierce its shadow root
- the button named `Ask <agent name> ⌘K` (or `Ctrl K`), the launcher, and the `dialog`, the window
- the region named `Conversation`, the scroll box (specs 3 and 4)
- `.cs-sheet-controls`, the window's controls row (Minimize, and Expand when it is turned on),
  whose bottom edge spec 3 measures the pinned bar from
- `data-testid="abp-live-region"`, the conversation's polite live region (the role alone is not
  enough: the page has other `role=status` regions)
- `data-testid="abp-spinner"`, the pending turn: the question and the pulse until the reply lands
- `data-testid="abp-summary-headline"`, the brief's summary headline, apart from the accordion
  section headers, which are also level-2 headings, for a brief drawn without cards
- `c-customer-summary-card` (FE-22), an answer card, and inside it the card's own hooks: `article[data-type]`
  (`summary`, `section`, ...), `.cs-title-text` (the summary card's title is the headline), `.cs-toggle`
  (a section card's fold button, collapsed by default) and `button.cs-link[data-ref]` (a record link:
  the drill origin). The page cannot read a card's markup (outerHTML reads empty from outside the
  component), so the check that no record Id reaches it is in the Jest suite
- `.abp-sessions` and `button.abp-session` (FE-22), the History list and its rows; the group named
  `Question scope` and `.abp-scope-label`, the scope chip
- `lightning-breadcrumbs` and `lightning-accordion-section`, to find the drill trail, each brief
  section and its header button
- `article`, to find the drill view's heading
- `button[data-id]`, a drillable section line or result row of an answer drawn without cards

Spec 3 measures the window at 420x560 after one brief, with the account's "Earlier summaries" list
rendered: from the controls row's bottom edge to the top of the scroll box is at most 80 CSS px,
the scroll box is at least 240 CSS px tall, and the bar holds the Summarize button with no "Ask the agent" button.

Every brief line that describes one record (a deal, a contact, a case, a task, a call) is a
drill button; spec 7 fails if none is. Spec 2 checks that focus is back where the hotkey was
pressed after Esc, and is still there 2.5 seconds later, from three places: the global Search
button, the Phone field of the record's inline edit (a field inside another component, on the
Details tab; the edit is cancelled, nothing is saved) and the launcher. It then removes the element
focus came from and checks that Esc lands on the launcher, never the page body. Focus inside the
stage is read with the `:focus` selector, polled: the page's synthetic shadow DOM hides it from
`document.activeElement`, so Playwright's `toBeFocused` cannot see it. Spec 10 opens the window five
times after a warm-up and records, for each, the time from the K key event to the first frame after
the window is marked open; the numbers are logged and attached to the test. Spec 5 waits on the
Aura response of the panel's Apex method, matched by method name only.

Every test closes the "Meet the new Guidance Center" walkthrough of a fresh org whenever it appears
(`Panel.gotoAccount`), because it covers the page. It was on screen when spec 2 failed in agent-probe.
It closes the docked "Welcome to Data Cloud!" pop-up (Minimize, Pop-out, Close) the same way, with its
Close button, because it opens over the window's corner.
Spec 2 has also failed there with no walkthrough, cause not found, so it can still be flaky in a fresh
org ([org-migration.md](../docs/research/org-migration.md), "e2e after FE-9").

Accessibility checks run `axe-core` (a direct devDependency) on the stage element (the
launcher and the window), WCAG 2.0-2.2
A and AA rules; the violations of each state are attached to the test as JSON. The stage is
passed as an element, not a selector: the page's synthetic shadow DOM hides it from
`document.querySelectorAll`, which is how axe resolves a selector, and `AxeBuilder` from
`@axe-core/playwright` takes selectors only.

## Capture

The capture scripts for the built-in panel (`06-agent`) and for "Ask the agent" (`07-ask-agent`) were deleted with the feature (FR2); the three images they wrote stay in `docs/assets/`, marked retired in the manifest.

The screenshots and GIFs in `docs/assets/` (listed in `docs/assets/MANIFEST.md`) come from the
live org with one command:

```bash
npm run test:e2e    # first: fr2-08-e2e-report.png is a screenshot of this run's HTML report
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
- `playwright-report/index.html` from a full `npm run test:e2e` run, for `fr2-08-e2e-report.png`.
- `/opt/homebrew/bin/ffmpeg` and `ffprobe`, which turn the recorded video into GIFs (two-pass
  palette, 12 fps, at most 900 px wide).
- Model calls per run: four, all in the custom panel: `13-summary-memory` makes two (a summary of
  Edge Communications and one follow-up), `15-explorer` one (a whole-org question) and `10-rail`
  one. The `test:e2e` run adds about ten. The rest make none: `14-resolver` (the not-found and
  several-matches stills), `16-hotkey` (the hotkey GIF; its line is answered by the resolver),
  `17-voice` (the mic stills), `09-compact`, `11-action-draft` and `12-history`. Nothing is written
  to the org by the capture itself beyond the product's own session and outcome rows, which the two
  model calls of `13-summary-memory` and the one of `15-explorer` write. `11-action-draft` never
  clicks Confirm and Cancels each draft after its still; there is no result still, since a result
  needs a saved record.

The scripts, one per pattern page or surface (OPS-52 replaced the utility-panel scripts `01-hotkey`,
`02-resolver`, `03-brief`, `04-explore` and `08-conversation-core`; the images they wrote stay in
`docs/assets/`, marked in the manifest):

| Script | Writes | Pages |
|---|---|---|
| `05-report` | `fr2-08-e2e-report.png` | 08 |
| `06-brand` | `brand-swap-before.png`, `brand-swap-after.png` (skipped by a plain run, see below) | 10 |
| `07-surface-spike` | `fr2-spike-*.png` (skipped by a plain run, see its header) | research |
| `09-compact` | `fr2-compact-launcher.png`, `fr2-compact-open.png` | 03 |
| `10-rail` | `fr2-rail.gif`, `fr2-rail-open.png`, `fr2-rail-context.png` | 12 |
| `11-action-draft` | `fr2-action-draft.png`, `fr2-action-draft-rail.png` | 13 |
| `12-history` | `fr2-history-timeline.png`, `fr2-history-sentiment.png` | 12 |
| `13-summary-memory` | `fr2-01-summary.gif`, `fr2-readme-hero.gif`, `fr2-01-summary-*.png`, `fr2-05-*.png` | 01, 05, README |
| `14-resolver` | `fr2-01-not-found.png`, `fr2-01-several-matches.png` | 01 |
| `15-explorer` | `fr2-02-explorer-compact.png`, `fr2-02-explorer-rail.png`, `fr2-02-drill.gif` | 02 |
| `16-hotkey` | `fr2-03-hotkey.gif` | 03 |
| `17-voice` | `fr2-11-mic-compact.png`, `fr2-11-mic-rail.png`; `fr2-11-mic-listening.png` only if "Listening" shows without a stub | 11 |

What it produces: stills of the whole 1440x900 viewport at CSS scale (1440x900 pixels: the page, not
the browser, so no address bar), except `fr2-rail-context.png` (the rail alone, 640x900) and
`fr2-08-e2e-report.png` (800x900 at device scale 2); GIFs cut from the test's video of the same
viewport, scaled to 900 px wide, 6 to 20 seconds, each starting on a settled frame. The summary GIFs
cut most of the wait between Send and the answer. A still that names a turn frames that turn's
question at the top of the conversation's own scroll box, and the run fails if it cannot. Only that
box is scrolled: `scrollIntoView` would also scroll the rail's dialog and leave the page half off
screen, and `11-action-draft` puts the rail's dialog back to the top after the draft's focus moves.
Raw videos stay in `test-results/capture/raw/` (gitignored). One frame per second of each
GIF, and its last frame, are written outside the repo for review (`$TMPDIR/abp-capture-frames/`,
or `CAPTURE_FRAMES_DIR`).

The brand pair (`brand-swap-before.png`, `brand-swap-after.png`, pattern page 10) needs a different
brand record deployed for each shot, so a plain `npm run capture` skips it. Run it once per shot,
right after that shot's `Brand_Setting.Default` record is deployed (the steps are in
[10-brand-and-theming.md](../docs/patterns/10-brand-and-theming.md)), then deploy the shipped record
again:

```bash
BRAND_SHOT=before BRAND_AGENT_NAME='Customer Summary' npx playwright test -c playwright.capture.config.js e2e/capture/06-brand.capture.js
BRAND_SHOT=after BRAND_AGENT_NAME='Northwind Assist' npx playwright test -c playwright.capture.config.js e2e/capture/06-brand.capture.js
```

The run fails if the panel's agent name is not the one given, or is cut short. It makes no model
call.

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
  global header. - **Sample data only.** Captures use the sample account Edge Communications and the other records
  seeded from `data/sample/`. Explorer questions in captures do not ask for owners.
- **Review by eye before committing:** every PNG, and the frames written for each GIF.
