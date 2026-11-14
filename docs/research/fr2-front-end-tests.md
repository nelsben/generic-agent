# FR2: the front-end test run (FE-21)

What changed in the Playwright suite (`e2e/`, `playwright.config.js`), what was found about spec 2, and
the runs behind it. Org: `agent-probe` only, read-only apart from the records the suite creates. No
deploy, publish or activation. All counts and times are measured (verified) unless marked.

## Spec 2: the cause

Spec 2 ("Esc closes the window and returns focus where it came from") failed now and then
([org-migration.md](org-migration.md)): focus was not on the global Search button after Esc.

- **Before, unchanged spec: 20 of 20 passed** (2 runs of 10, 3.7 minutes each, about 21 s a run,
  `--repeat-each=10`, screenshot and console log kept on failure, tracing off). The failure did not
  show in 20 runs, so it was not reproduced there.
- **The cause was found by another test.** A new test (Ctrl-K in a text field on a Mac) focuses a
  stand-in text field on the record page, presses a key, waits 1 s and checks focus. In 4 of 5 runs
  focus had gone to the body between 2.8 and 3.3 s after the record page was loaded: the field was
  still on the page, visible and connected, the page still had focus, and no panel code had run (the
  window was never opened). Something on the page drops focus to the body about 3 s after load; what
  it is was not identified (a Lightning page-load step; the stack of the blur event is empty). A test
  that focuses anything before then loses it. Spec 2 anchors on the Search button the same way, so
  this is the likely cause of its failures (probable: it matches the failure, which was not
  reproduced in spec 2 itself).
- **Fix, in `e2e/support/panel.js` (`gotoAccount`):** no test starts until the record page is 6 s
  old (`PAGE_SETTLE_MS`, measured with `performance.now()` in the page). It costs about 2 s a test.
  The component (`force-app`) was not changed, and no finding is raised against it: the panel was
  closed when focus was lost.
- **After: spec 2 passed 20 of 20** (2 runs of 10, 4.3 minutes each, about 25 s a run). The new
  Ctrl-K test went from 1 of 5 passing to 6 of 6. Because spec 2 did not fail before the fix, its
  rate went from 20 of 20 to 20 of 20: the fix is shown for the focus-loss test, not for spec 2.
- The earlier fix (a handler for the "Meet the new Guidance Center" walkthrough, FE-9) stays.
- A failure now attaches the page's console and uncaught errors (`console.log`, the last 200 lines)
  and the screenshot to the report.

## Spec 7 ("record heading has focus")

Failed once in the first full run of this card (before the 6 s wait): `the record heading has focus`,
20 s poll, after the drill. It passed in the full run after the wait. Not reproduced since; one
failure in two runs is not enough to name a cause. It is the same kind of failure (focus not where
expected, with a 6-second-old page the difference is the wait). Recorded, not fixed.

## Both hotkey branches

`playwright.config.js` has two projects: `mac` (every spec, the panel reads a Mac, Cmd-K) and
`windows` (only specs tagged `@hotkey`, the panel reads Windows, Ctrl-K). `support/panel.js` sets
`navigator.platform` and `navigator.userAgentData.platform` before any page script runs, so a Mac
runs the Windows branch. The keys are those of
[fr2-surfaces-spike.md](fr2-surfaces-spike.md) (`code === 'KeyK'`, no Shift or Alt; Cmd on a Mac,
Ctrl elsewhere). `e2e/hotkey-platforms.spec.js` proves, on each branch: the key opens the window and
the launcher names it; the other platform's key does nothing; Shift and Alt forms do nothing. On the
Mac branch it also proves Ctrl-K in a text field is left alone: the window stays shut and the
keydown reaches the page not prevented. Specs 1 and 10 run on both branches.

Red: before the config, the Windows-branch test failed on a Mac with the launcher reading the Mac key
(`Expected: "Ctrl K"`, received the Command-K label).

## Smoke subset

`npm run test:e2e:smoke` (`--grep @smoke`): one test per surface (window and launcher, composer,
conversation, accessible names, hotkey on both branches), no model call.

## Runs

| Run | Result |
|---|---|
| Spec 2, 10 runs, before | 10 passed (3.7m) |
| Spec 2, 10 runs, before | 10 passed (3.7m) |
| Full suite, first (before the 6 s wait) | 2 failed (Ctrl-K field test, spec 7), 23 passed (6.0m) |
| Spec 2, 10 runs, after | 10 passed (4.3m) |
| Spec 2, 10 runs, after | 10 passed (4.3m) |
| Full suite, final | 1 skipped, 25 passed (6.8m) |
| Smoke, final | 7 passed (1.3m) |

## Org rows

Counted on the seed account (read-only queries) before the first e2e run and after the last:

| | Before | After |
|---|---|---|
| Customer_Outcome__c | 21 | 31 |
| Customer_Summary_Session__c | 4 | 5 |

The suite writes outcome rows for every summary; they were not deleted (that is Ben's call).
