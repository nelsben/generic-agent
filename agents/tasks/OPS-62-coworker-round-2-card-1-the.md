---
id: OPS-62
title: Coworker round 2, card 1: the README's "See it in 5 minutes" runs as written in the new org connect-24h, and the clean-install row gets its first real result
domain: ops
tier: standard
status: queued
scope: [docs/research/fresh-org-run.md, README.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, spikes/**, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json]
resources: [org-connect]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

Ben made a new orgfarm Developer Edition org for Coworker (alias connect-24h, expiring about 24 hours after it was made) and gave the brain full control of it on 2026-11-15. The org is empty, so the product has to be installed before any Coworker step, and that install is also the first true clean install of the README's quick start (OPS-28 could only rerun it in an org that already held the build). This card installs the product and records the run; it changes no product code.

## Done when

- **Org guard first, before any other step.** Run `sf org display -o connect-24h --json` and `sf org display -o agent-probe --json` and compare `result.id` and `result.username` in a shell expression that prints only SAME or DIFFERENT, never the values. If connect-24h does not resolve, or either value is the same, take no org step: write nothing to the org, say so in the hand-back and stop
- Read first: README.md 'See it in 5 minutes' and 'Status', docs/research/fresh-org-run.md (OPS-28) in full, docs/research/org-migration.md (the fresh-org order and its gotchas), and the Approvals row 'FR2+: Agentforce Coworker live steps' in docs/plans/gtm-burn-plan.md (it is approved for connect-24h). Load the skills salesforce-development:platform-metadata-deploy and agentforce-adlc:agentforce-generate first
- **Org rules.** Only `connect-24h`, with `-o connect-24h` on every `sf` command; the one exception is the read-only `sf org display -o agent-probe` of the guard. Never touch `agent-probe`, `experimental`, `experimental-web` or `my-devhub` otherwise. Never sign in or out, enter a password or credential, or create a user; the running user is the org's existing admin user. Never create a connected app or External Client App. No destructive deploy, no security or red-team test. Deploys go validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, never `deploy start`. Setup toggles the quick start needs (for example turning on Einstein generative AI or Agentforce) are allowed under the row. Foreground waits under 10 minutes, no background jobs; when a step fails, diagnose it once rather than loop
- **Run the quick start as written.** Every command in 'See it in 5 minutes' in the README's order, each with `-o connect-24h` (or `SF_TARGET_ORG=connect-24h` where the README says to set it), including the deploy, the agent publish and activation of `Customer_Summary`, the permission set group assignment to the running user, the seed data and the ladder. Where a command fails, note the exact error class (no Ids), apply the smallest fix that the README or org-migration.md already documents, and record it as a deviation. Do not change force-app/**, data/** or scripts/**: if the install needs a code or data fix, record it as a finding with the error and the proposed fix and go on with the next step that does not depend on it
- **Record.** Add a section 'Clean install in a new org (OPS-62, 2026-11-15)' to docs/research/fresh-org-run.md: the date and times, the CLI version, each step as typed (with `<org-alias>` in place of the alias where the page already does that), its result as counts (components, Apex tests, records seeded, ladder rungs), minutes per step, and a Deviations list. Update the page's Plain answer. In README.md change only the Status row 'A clean install from "See it in 5 minutes"' (and 'Runs without the agent' only if this run observed it): proven only if every step passed with no deviation outside the README; otherwise say what failed. Fix a README quick-start line only when the run proved it wrong, and list each such fix
- **Leave the org ready for the next cards** (OPS-63 and FE-28 run Coworker in it): the product deployed, `Customer_Summary` published and active, the running user holding the product's permission set group, the seed data in. Name in the hand-back the one seed account the next cards should use (the README's demo account) and whether the running user has agent access to `Customer_Summary`
- No org Ids, record Ids, job Ids, usernames, emails, hostnames or URLs with a query string in any file; job Ids stay out of the hand-back too. Workers may read docs/plans/** and run scripts/check-docs.sh but edit neither
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. End with the [[report]] line
