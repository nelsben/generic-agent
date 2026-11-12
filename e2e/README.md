# Account Brief panel: end-to-end tests

Playwright journeys for the `accountBriefPanel` utility bar panel, run in a real org as the
developer's own signed-in user. They cover what the Jest suite cannot: the real utility bar, the
real Lightning base components, focus, layout and the live region.

## Run

```bash
npm ci
npm run test:e2e                         # org alias "experimental"
SF_E2E_ORG=my-alias npm run test:e2e     # any other signed-in alias
npx playwright test -g "6. typing"       # one spec
```

Chromium only (Playwright's own build, `npx playwright install chromium` if it is missing),
one worker, no parallelism. A full run takes about four minutes.

## What it needs

- **A deployed panel.** The org must already have the Account Brief app
  (`Account_Brief.app-meta.xml`), its utility bar with `accountBriefPanel` (eager, 340x480) and the
  Apex behind it. The suite never deploys anything.
- **A signed-in sf CLI session** for the alias (`sf org login web -a <alias>`). The global setup
  asks `/usr/local/bin/sf org open --url-only --json -o $SF_E2E_ORG` for a one-time frontdoor URL,
  opens it in an untraced browser context and saves the session to `e2e/.auth/` (gitignored).
  It never asks for or types a password. If the session is missing or expired it stops with one
  line telling you to run `sf org login web -a <alias>`.
- **The account Edge Communications** in that org. It is looked up by name at run time.

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
