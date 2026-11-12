---
id: OPS-46
title: FR2: the test ladder in one command — scripts/ladder.sh runs each rung in order and prints one line per rung, the code scan runs what it can without Java and says what it skipped, and a read-only check says whether the org still matches main
domain: ops
tier: standard
tier_reason: scripts every adopter runs first, so they must be plain, honest about what they skipped, and never change the org
status: blocked
blocked_by: [OPS-30, BE-38, FE-21]
fixes: []
scope: [scripts/ladder.sh, scripts/apex-scan.sh, scripts/org-drift.sh, package.json, tests/test_ladder.py]
forbid: [force-app/**, mcp-door/**, spikes/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: tests/test_ladder.py fails on main (scripts/ladder.sh and scripts/org-drift.sh do not exist) and passes after
gate: test
budget: 2-attempts
spend: 5
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 08: "we're going to be bringing some of these programmatic testing concepts to Salesforce users who haven't historically done this type of testing. Meaningful and valuable." One command with one line per rung is the easiest first step for someone new to testing. Covers ledger row F91, and two open items on page 08: the code scan needs Java (this machine has none, so it does not run at all), and nothing says whether the org still matches main.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F88 to F92 and the review of page 08's open items), docs/patterns/08-test-and-release-lifecycle.md, every script in scripts/, e2e/README.md and docs/research/fr2-testing-center.md (BE-38). Load the skill salesforce-development:platform-metadata-deploy first
- **scripts/ladder.sh** (and npm run ladder) runs the rungs in order: Python, Jest, the code scan, the org check-only deploy, the drift check, the e2e smoke subset; with --agent it adds the optional agent track (compile, then the Testing Center suite through scripts/agent-test.sh); with --full it runs the full e2e suite. It prints one plain line per rung (passed, failed, or skipped and why) and stops at the first failure unless told to continue. It never deploys for real, publishes or activates
- **The code scan:** apex-scan.sh runs the Code Analyzer engines that need no Java when Java is missing and prints which rules it skipped and that installing Java 11 or later turns them on. It still reports and does not gate
- **The drift check:** scripts/org-drift.sh finds, read-only, which components differ between main and the org (for example by retrieving to a temporary folder and comparing), and prints counts by type and the names, never Ids or hostnames
- tests/test_ladder.py checks the rung order, the flags, that no script contains a real deploy, publish or activate command, and that the scan's skip message exists. Run the ladder once against agent-probe without --agent and once with it, and put both outputs in the hand-back. Never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
