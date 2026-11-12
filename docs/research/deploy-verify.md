# Deploy main to experimental and prove it (OPS-20)

Date: 2026-11-11
Commit deployed: feb0d7b (main, via branch agent/ops/OPS-20, which holds no source changes)
Target: org alias `experimental`, Developer Edition, not a sandbox, not production.
Approval: real deploy approved by Ben on 2026-11-11 (docs/plans/gtm-burn-plan.md, Approvals).

## Deploy

Same scope as scripts/validate-org.sh: every `force-app` metadata folder except `aiAuthoringBundles`
(the agent was not deployed, published or activated), `--test-level RunSpecifiedTests` naming the 19 `*Test.cls` classes.
Nothing assigned, nothing deleted.

| Run | Status | Components | Components deployed | Tests run | Test failures | Component errors |
|---|---|---|---|---|---|---|
| Dry-run (`--dry-run`) | Succeeded | 60 | n/a (check-only) | 150 | 0 | 0 |
| Real deploy | Succeeded | 60 | 60 | 150 | 0 | 0 |

## Apex tests

150 run, 150 passed, 0 failed (19 classes, run as part of the real deploy).

## Playwright panel suite (`npm ci`, `npm run test:e2e`, one run, 1 worker, 2.3 min)

| Spec | Result |
|---|---|
| 1. Cmd/Ctrl-K opens the panel and focuses the composer | pass |
| 2. Esc minimizes and returns focus; Tab can leave the panel | pass |
| 3. A brief renders with headline and collapsed accordions, announced by the live region | pass |
| 4. After two answers the composer stays pinned and the newest answer is in view | pass |
| 5. A second request before the first answers: only the second renders | pass |
| 6. Typing enables Send without blur, and Enter sends | pass |
| 7. A drill opens the record view and a breadcrumb returns without navigating to # | pass |
| 8. axe finds no WCAG A/AA violations in brief and drill states | pass |

8 of 8 passed on the first run; no re-runs and no failure screenshots.

## Verdict

experimental now matches main (outside the agent bundle): 60 components deployed, 150 of 150 Apex tests green, panel suite 8 of 8.
