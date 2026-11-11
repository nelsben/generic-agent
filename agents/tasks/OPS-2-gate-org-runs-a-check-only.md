---
id: OPS-2
title: Gate `org` runs a check-only deploy of force-app to the experimental org, with our own Apex tests
domain: ops
tier: economy
tier_reason: Small shell script with every flag and output line specified
status: merged
scope: [scripts/validate-org.sh, tests/test_validate_org.py, .chassis-delegation.json]
forbid: [force-app/**, agents/**, tests/test_ok.py, tests/test_sfdx_project.py]
red_test: python3 -m unittest discover -s tests (tests/test_validate_org.py fails before: no scripts/validate-org.sh)
gate: test
budget: 2-attempts
spend: 3
---
## Why

Every later card adds Salesforce metadata (Apex, prompt templates, Flows, an Agent Script bundle, LWC). The current gate only runs local Python tests, so a card could break compilation and still pass. This adds a second gate id, `org`, that proves the worker's force-app compiles and its Apex tests pass in the real target org without changing the org.

## Done when

- scripts/validate-org.sh exists, is executable, and uses bash with `set -euo pipefail`
- When force-app holds no files other than .gitkeep, the script prints `validate-org: skipped (no metadata in force-app)` and exits 0 without calling sf
- Otherwise it runs `sf project deploy validate --source-dir force-app --target-org "${SF_TARGET_ORG:-experimental}" --wait 30 --json`. The test level is `RunSpecifiedTests` with `--tests` for every Apex class under force-app whose file name ends in `Test.cls` (class name = file name without .cls). When there are none, it uses `--test-level NoTestRun`. Never RunLocalTests: the org has unrelated classes whose tests must not gate us
- On failure it prints a short summary to stdout (each componentFailures entry as `<type> <fullName>: <problem>` and each failing test as `<class>.<method>: <message>`) and exits non-zero. On success it prints `validate-org: pass (<n> components, <m> tests)` and exits 0. Parse JSON with python3 (stdlib), not jq
- The script never runs `sf project deploy start`, `sf data` writes or anything else that changes the org
- .chassis-delegation.json gateMap gains `"org": "bash scripts/validate-org.sh"` and keeps `"test"` unchanged. No other key in that file changes
- tests/test_validate_org.py (unittest, stdlib) runs the script against a temporary copy of a force-app with only .gitkeep files (via an env var FORCE_APP_DIR the script honors, default `force-app`). It asserts exit 0 and the skipped message, with no sf call needed
- Run the script once yourself against an empty force-app and quote its output in the hand-back

## Review

Brain smoke-tested all three non-skip paths against experimental: tests present -> pass (2 components, 1 tests); no tests (dry-run) -> pass (1 components, 0 tests); compile error -> `ApexClass GateSmokeBad: Variable does not exist: nope`, rc=1.
