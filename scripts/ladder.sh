#!/usr/bin/env bash
# The test ladder in one command: runs each rung in order and prints one plain line per rung
# (passed, failed, or skipped and why). Stops at the first failure unless told to continue.
#
#   bash scripts/ladder.sh [--agent] [--full] [--continue] [--help]     (also: npm run ladder -- <flags>)
#
# Rungs, in order: python, jest, scan, org-check, drift, e2e-smoke.
#   --agent     adds the optional agent track: agent-compile (scripts/agent-check.sh), then agent-suite
#               (the Testing Center suite through scripts/agent-test.sh; skipped when that script does not
#               exist or the Approvals row for it is not approved)
#   --full      runs the full e2e suite (e2e-full) in place of the smoke subset
#   --continue  carries on after a failed rung
#
# Org: agent-probe only (SF_TARGET_ORG overrides it for the org rungs). Every org rung is read-only: the
# org-check is a check-only validate (scripts/validate-org.sh), the drift check a retrieve to a temporary
# folder. Nothing here deploys for real, publishes or activates. Exit: 0 no rung failed, 1 one did.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export SF_TARGET_ORG="${SF_TARGET_ORG:-agent-probe}"
export PYTHONDONTWRITEBYTECODE=1

AGENT=0
FULL=0
CONTINUE=0
for arg in "$@"; do
  case "$arg" in
    --agent) AGENT=1 ;;
    --full) FULL=1 ;;
    --continue) CONTINUE=1 ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ladder: unknown flag $arg (flags: --agent --full --continue)" >&2
      exit 2
      ;;
  esac
done

LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
FAILED=0
STOPPED=0
RESULTS=()

emit() { # name verdict detail
  printf 'ladder: %-14s %s\n' "$1" "$2"
  RESULTS+=("$1 $2")
}

detail() { # name logfile: what to say beside "passed"
  case "$1" in
    python) grep -E '^Ran [0-9]+ tests?' "$2" | tail -1 ;;
    jest) grep -E '^Tests:' "$2" | tail -1 | sed 's/  */ /g' ;;
    scan)
      grep -E '^Found [0-9]+ violation' "$2" | tail -1 | sed 's/^Found/reported/; s/ across.*//'
      grep -E '^apex-scan: skipped' "$2" | sed 's/^apex-scan: //'
      ;;
    org-check) grep -E '^validate-org: ' "$2" | tail -1 | sed 's/^validate-org: //' ;;
    drift)
      grep -E '^org-drift: ' "$2" | tail -1 | sed 's/^org-drift: //'
      grep -E '^(changed in the org|missing from the org): [0-9]+' "$2"
      ;;
    e2e-*) grep -E '^ +[0-9]+ (passed|skipped|failed)' "$2" | sed 's/^ *//' | tr '\n' ' ' | sed 's/ *$//' ;;
    agent-compile) grep -E '^agent-check: ' "$2" | tail -1 | sed 's/^agent-check: //' ;;
    agent-suite) tail -1 "$2" ;;
  esac
}

rung() { # name command...: runs it, prints one line
  local name="$1"
  shift
  if [ "$STOPPED" -eq 1 ]; then
    return 0
  fi
  local log="$LOGS/$name.log" start rc=0 secs note
  start="$(date +%s)"
  "$@" >"$log" 2>&1 || rc=$?
  secs=$(($(date +%s) - start))
  if [ "$rc" -eq 0 ]; then
    note="$(detail "$name" "$log" | paste -sd ';' - | sed 's/;/; /g')"
    emit "$name" "passed (${secs}s)${note:+: $note}"
  else
    note="$(detail "$name" "$log" | paste -sd ';' - | sed 's/;/; /g')"
    emit "$name" "failed (exit $rc, ${secs}s)${note:+: $note}"
    tail -n 8 "$log" | sed 's/^/ladder:                  | /'
    FAILED=1
    [ "$CONTINUE" -eq 1 ] || STOPPED=1
  fi
}

skip() { # name "skipped: reason"
  [ "$STOPPED" -eq 1 ] && return 0
  emit "$1" "$2"
}

approved() { # does the Approvals row naming $1 start with "approved"?
  python3 - "$1" docs/plans/gtm-burn-plan.md <<'PY'
import sys
needle, path = sys.argv[1], sys.argv[2]
for line in open(path, encoding="utf-8"):
    cells = [c.strip() for c in line.split("|")]
    if len(cells) > 3 and needle in cells[1]:
        sys.exit(0 if cells[2].startswith("approved") else 1)
sys.exit(1)
PY
}

rung python python3 -m unittest discover -s tests
rung jest npm run test:unit
rung scan bash scripts/apex-scan.sh
rung org-check bash scripts/validate-org.sh
rung drift bash scripts/org-drift.sh
if [ "$FULL" -eq 1 ]; then
  rung e2e-full npm run test:e2e
else
  rung e2e-smoke npm run test:e2e:smoke
fi

if [ "$AGENT" -eq 1 ]; then
  rung agent-compile bash scripts/agent-check.sh
  if [ ! -f scripts/agent-test.sh ]; then
    skip agent-suite "skipped: agent suite not built"
  elif ! approved "create and run the functional Testing Center suite"; then
    skip agent-suite "skipped: the Testing Center suite's Approvals row is not approved"
  else
    rung agent-suite bash scripts/agent-test.sh
  fi
fi

if [ "$STOPPED" -eq 1 ]; then
  echo "ladder: stopped at the first failure (run with --continue to carry on)"
fi
if [ "$FAILED" -eq 1 ]; then
  echo "ladder: FAILED"
  exit 1
fi
echo "ladder: no rung failed"
