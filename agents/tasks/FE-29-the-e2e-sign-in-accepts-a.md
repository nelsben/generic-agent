---
id: FE-29
title: The e2e sign-in accepts a new org's /lightning landing, and the e2e smoke passes in connect-24h
domain: frontend
tier: standard
status: queued
scope: [e2e/global-setup.js, docs/research/fresh-org-run.md, README.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, spikes/**, e2e/.auth/**, e2e/specs/**, mcp-door/**, reference/**, .chassis-delegation.json]
resources: [org-connect]
red_test: SF_TARGET_ORG=connect-24h SF_E2E_ORG=connect-24h npm run test:e2e:smoke (fails now at global setup's /lightning/ wait; passes after)
gate: test
budget: 2-attempts
spend: 10
---
## Why

OPS-62 ran the README in the new org connect-24h and everything passed except the ladder's e2e smoke rung. e2e/global-setup.js waits for a path starting with /lightning/, and a new org lands on /lightning (title "Home | Salesforce"), so the wait times out. Until that rung passes the README's clean-install row stays Not yet proven.

## Done when

- Guard first: compare `sf org display -o connect-24h --json` and `-o agent-probe` result.id and result.username, printing only SAME or DIFFERENT; stop with no org step if either is SAME.
- e2e/global-setup.js accepts a landing path of exactly /lightning as well as any path starting with /lightning/ (for example a predicate `p === '/lightning' || p.startsWith('/lightning/')`); nothing else in the sign-in flow changes and no wait time is raised.
- `SF_TARGET_ORG=connect-24h SF_E2E_ORG=connect-24h npm run test:e2e:smoke` is run in the worktree and its pass or fail count is recorded in docs/research/fresh-org-run.md under a new section 'e2e smoke after the landing fix (FE-29, 2026-11-15)'. If a spec fails for another reason, record the failure and its likely cause and do not fix it here.
- If the smoke passes: `SF_TARGET_ORG=connect-24h SF_E2E_ORG=connect-24h npm run ladder` is run and each rung's result recorded in the same section. The README's 'A clean install' row says Proven in a new org with no prior build only if every ladder rung passed; otherwise it keeps Not yet proven and names the rung that failed. Keep that the org was not empty (orgfarm template data).
- The worker sets a project-local default org only if the deploy-gate hook needs it, and unsets it after; it does not deploy, publish, assign or change org data (the e2e's own sign-in and reads are fine). The e2e/.auth files are never committed or printed.
- No org Ids, usernames, hostnames, frontdoor or session URLs, or job Ids in any committed file.
