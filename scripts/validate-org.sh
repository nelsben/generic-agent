#!/usr/bin/env bash
# Gate `org`: check-only deploy of force-app to the target org, running only our own Apex tests.
# With *Test.cls classes it uses `deploy validate` (RunSpecifiedTests). With none, sf rejects
# NoTestRun for validate, so it uses `deploy start --dry-run` (still check-only, never saves).
# Never deploys for real and never writes to the org.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORCE_APP_DIR="${FORCE_APP_DIR:-force-app}"
TARGET_ORG="${SF_TARGET_ORG:-experimental}"

if [ ! -d "$FORCE_APP_DIR" ]; then
  echo "validate-org: fail (force-app not found: $FORCE_APP_DIR)"
  exit 1
fi

# Anything other than .gitkeep counts as metadata.
other_files="$(find "$FORCE_APP_DIR" -type f ! -name .gitkeep)"
if [ -z "$other_files" ]; then
  echo "validate-org: skipped (no metadata in force-app)"
  exit 0
fi

# Only our own Apex test classes gate the deploy: files named *Test.cls.
test_args=()
test_count=0
while IFS= read -r file; do
  test_args+=(--tests "$(basename "$file" .cls)")
  test_count=$((test_count + 1))
done < <(find "$FORCE_APP_DIR" -type f -name '*Test.cls')

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

sf_rc=0
if [ "$test_count" -gt 0 ]; then
  sf project deploy validate --source-dir "$FORCE_APP_DIR" --target-org "$TARGET_ORG" \
    --wait 30 --json --test-level RunSpecifiedTests "${test_args[@]}" > "$out" 2>/dev/null || sf_rc=$?
else
  sf project deploy start --dry-run --source-dir "$FORCE_APP_DIR" --target-org "$TARGET_ORG" \
    --wait 30 --json --test-level NoTestRun > "$out" 2>/dev/null || sf_rc=$?
fi

python3 - "$out" "$sf_rc" <<'PY'
import json
import sys

path, sf_rc = sys.argv[1], int(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        payload = json.load(f)
except (OSError, ValueError):
    print("validate-org: fail (sf produced no JSON, exit %d)" % sf_rc)
    sys.exit(1)

# sf puts the deploy result under "result" on success and under "data" on failure.
body = payload.get("result") or payload.get("data") or {}
details = body.get("details") or {}
run = details.get("runTestResult") or body.get("runTestResult") or {}

lines = []
for cf in details.get("componentFailures") or []:
    lines.append("%s %s: %s" % (cf.get("componentType", "?"), cf.get("fullName", "?"), cf.get("problem", "?")))
for tf in run.get("failures") or []:
    lines.append("%s.%s: %s" % (tf.get("name", "?"), tf.get("methodName", "?"), tf.get("message", "?")))

ok = sf_rc == 0 and body.get("success") is True and not lines
if not ok:
    if not lines:
        lines.append("validate-org: fail (%s)" % (payload.get("message") or "deploy did not succeed"))
    for line in lines:
        print(line)
    sys.exit(1)

components = body.get("numberComponentsTotal", 0)
tests = run.get("numberTestsCompleted", body.get("numberTestsCompleted", 0))
print("validate-org: pass (%d components, %d tests)" % (components, tests))
PY
