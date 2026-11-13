---
id: OPS-46
title: FR2: the test ladder in one command — scripts/ladder.sh runs each rung in order and prints one line per rung, the code scan runs what it can without Java and says what it skipped, and a read-only check says whether the org still matches main
domain: ops
tier: standard
tier_reason: scripts every adopter runs first, so they must be plain, honest about what they skipped, and never change the org
status: blocked
blocked_by: [OPS-30, FE-21]
fixes: []
scope: [scripts/ladder.sh, scripts/apex-scan.sh, scripts/org-drift.sh, package.json, tests/test_ladder.py, docs/research/fr2-ladder.md]
forbid: [force-app/**, mcp-door/**, spikes/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_ladder.py fails on main (scripts/ladder.sh and scripts/org-drift.sh do not exist) and passes after
gate: test
budget: 2-attempts
spend: 5
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: "we're going to be bringing some of these programmatic testing concepts to Salesforce users who haven't historically done this type of testing." One command with one line per rung is the easiest first step for someone new to testing. Covers ledger row F91, and two open items on page 08: the code scan needs Java (this machine has none, so it does not run at all), and nothing says whether the org still matches main.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", run the ladder with the rungs that reach a model skipped (the e2e subset and the agent track) and say so in the hand-back and in docs/research/fr2-ladder.md. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md (rows F88 to F92 and the review of page 08's open items), docs/patterns/08-test-and-release-lifecycle.md, every script in scripts/, e2e/README.md and docs/research/fr2-testing-center.md (BE-38; read it only if it exists: BE-38 waits on its own approval). Load the skill salesforce-development:platform-metadata-deploy first
- **scripts/ladder.sh** (and npm run ladder) runs the rungs in order: Python, Jest, the code scan, the org check-only deploy, the drift check, the e2e smoke subset; with --agent it adds the optional agent track (compile, then the Testing Center suite through scripts/agent-test.sh when that script exists; when it does not, the rung prints 'skipped: agent suite not built' and the ladder carries on); with --full it runs the full e2e suite. It prints one plain line per rung (passed, failed, or skipped and why) and stops at the first failure unless told to continue. Apart from the test definition scripts/agent-test.sh creates on --agent (covered by BE-38's row in the Approvals table), it never deploys for real, publishes or activates
- **The code scan:** apex-scan.sh runs the Code Analyzer engines that need no Java when Java is missing and prints which rules it skipped and that installing Java 11 or later turns them on. It still reports and does not gate
- **The drift check:** scripts/org-drift.sh finds, read-only, which components differ between main and the org (for example by retrieving to a temporary folder and comparing), and prints counts by type and the names, never Ids or hostnames. It covers force-app only. It never retrieves an External Client App, a connected app, an MCP server or any other type that can carry a consumer key or secret, and it works in a temporary folder outside the repo that it deletes afterwards
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- tests/test_ladder.py checks the rung order, the flags, that ladder.sh, apex-scan.sh and org-drift.sh contain no real deploy, publish or activate command, that the scan's skip message exists, and that org-drift.sh names no External Client App, connected app or MCP server type. Run the ladder once against agent-probe without --agent and once with it (the Testing Center rung runs only if scripts/agent-test.sh exists and the row "FR2: create and run the functional Testing Center suite" in the Approvals table of docs/plans/gtm-burn-plan.md starts with "approved"; otherwise it must print its skip line). Write both outputs, with hostnames, usernames and Ids removed, to docs/research/fr2-ladder.md: OPS-36 and OPS-47 take the ladder's output from that page, not from the hand-back. The check-only deploy and the drift check are read-only and need no Approvals row. Never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
