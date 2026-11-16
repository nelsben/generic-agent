# The Cmd/Ctrl-K smoke spec flake (FE-30, 2026-11-15)

Spec: `e2e/panel.spec.js` test 1, run in the `mac` and `windows` projects. Org: agent-probe. No source of the panel changed.

## Reproduction

`SF_E2E_ORG=agent-probe npx playwright test --grep @smoke`, 8 consecutive runs (11 tests each), then stopped by hand:

| Run | Result |
|---|---|
| 1 | failed: test 12 (the fallback names, `a11y-snapshot.spec.js:174`; the launcher's accessible name did not match in time). Not the hotkey spec |
| 2, 3, 4 | passed |
| 5 | failed: panel test 1 and rail test 1, both on the `windows` project, 90 s each |
| 6, 7, 8 | passed |

So test 1 failed once in 8 runs, which is the intermittent failure of FE-29 (1 of 11). Tracing stays off (a trace holds the session
cookie), so the evidence is the failure screenshot and Playwright's error context of the failed test.

## Cause

The page under test was not the expected one. In run 5 the failing tests were waiting for `[data-cs-stage]` (the panel's stage)
and the page held only Lightning's dialog "Your session has ended" (buttons Return to Page and Log In). The key was never
pressed: the failure was in `gotoAccount`, before test 1's own steps. The `windows` hotkey test of `hotkey-platforms.spec.js` ran
just before it, on the same saved session, and passed; the session ended between the two. The panel, its listener and the
launcher were not involved (no panel was on the page), so it is neither a late listener nor a test pressing before the panel is
ready. Why the org ended the session is not known from the page; it recurred in no other run.

FE-29's failure (a 60 s wait for the "Summarize" button) is most likely the same kind of failure, but that run left no screenshot
in the page, so this is not confirmed for it.

## Fix

`e2e/support/panel.js`: `gotoAccount` now watches for the "Your session has ended" dialog while it waits for the stage, the
utility bar item and the launcher, and fails at once with a message naming that page. It is not a retry, a longer wait or a second
key press: test 1 presses the key once, as before. It does not stop the org ending a session; it makes that failure read as what it is
instead of as a hotkey defect after 90 s.

`e2e/global-setup.js`: a timeout waiting for Lightning is now reported as a timeout ("the sf session itself worked"), and not as a
missing sf session. Still no URL, host or username in the message.

## Result

After the fix, `npx playwright test --grep @smoke` against agent-probe: 10 runs in a row, 10 passed, 0 failed (11 of 11 tests each,
both hotkey projects). The session did not end in any of them, so these 10 runs show the suite is green when the session holds, not
that the session-ended case is cured. A rerun in a fresh org is still needed before the README's "A clean install" row can flip.

## Undo

Nothing changed in an org: smoke runs only, nothing deployed and no record written.
