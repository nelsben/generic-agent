#!/usr/bin/env bash
# agent-test.sh: run the Testing Center suite for the optional agent's active version (BE-38).
#
#   bash scripts/agent-test.sh [--org <alias>] [--agent <DeveloperName>] [--spec <file>] [--wait <minutes>] [--dry-run]
#
#   --org      target org alias (default: $SF_TARGET_ORG, else agent-probe). Every sf call passes it with -o.
#   --agent    the agent's developer name (default Customer_Summary: the GO verdict in docs/research/fr2-rename-go.md)
#   --spec     the test spec (default tests/agent/Customer_Summary-testSpec.yaml)
#   --wait     minutes to wait for the run (default 15)
#   --dry-run  look up the active version and build the definition with --preview; create and run nothing
#
# A test definition is tied to one agent version, so every run looks up the active version, copies the spec into a
# temporary project folder with subjectVersion set to it, and creates or overwrites the definition from there. The
# CLI writes its metadata file into that folder, never under force-app, and the folder is removed on exit, so git
# status does not change. A run spends model calls (the agent, its actions and a judge per case) and each summary
# case writes the rows a summary always writes; see docs/research/fr2-testing-center.md.
#
# Output: one line per assertion type with pass and fail counts, then a last summary line naming the version. The
# subagent check on a case that sets no subagent always reports a failure (an empty expectation); it is left out.
# Nothing from the sf output is echoed: no record Ids, job Ids, usernames or hostnames.
# Exit: 0 every assertion passed, 1 an assertion failed, 2 bad arguments, 3 the org step failed or did not finish.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SF="sf"
ORG="${SF_TARGET_ORG:-agent-probe}"
AGENT="Customer_Summary"
SPEC="$ROOT/tests/agent/Customer_Summary-testSpec.yaml"
WAIT=15
DRY_RUN=0

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

need_value() {
  if [ $# -lt 2 ] || [ -z "$2" ]; then
    echo "agent-test: $1 needs a value" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --org) need_value "$@"; ORG="$2"; shift 2 ;;
    --agent) need_value "$@"; AGENT="$2"; shift 2 ;;
    --spec) need_value "$@"; SPEC="$2"; shift 2 ;;
    --wait) need_value "$@"; WAIT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "agent-test: unknown flag $1 (flags: --org --agent --spec --wait --dry-run --help)" >&2; exit 2 ;;
  esac
done

if ! [[ "$AGENT" =~ ^[A-Za-z][A-Za-z0-9_]{0,79}$ ]]; then
  echo "agent-test: --agent must be an agent developer name (letters, digits and underscores)" >&2
  exit 2
fi
if ! [[ "$WAIT" =~ ^[1-9][0-9]*$ ]]; then
  echo "agent-test: --wait must be a whole number of minutes" >&2
  exit 2
fi
case "$SPEC" in /*) ;; *) SPEC="$PWD/$SPEC" ;; esac
if [ ! -f "$SPEC" ]; then
  echo "agent-test: spec not found: $SPEC" >&2
  exit 2
fi
TEST="${AGENT}_Test"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/agent-test.XXXXXX")" || { echo "agent-test: could not make a temporary folder" >&2; exit 3; }
trap 'rm -rf "$WORK"' EXIT
printf '{"packageDirectories":[{"path":"force-app","default":true}],"sourceApiVersion":"65.0"}\n' >"$WORK/sfdx-project.json"
cd "$WORK" || exit 3

# Report a failed sf step by its error name only: its message can carry Ids, usernames or hostnames.
fail_step() { # step json-file
  local name
  name="$(python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get("name") or "no error name")
except Exception:
    print("no JSON output")' "$2")"
  echo "agent-test: $1 failed ($name); run the sf command by hand to see why"
  exit 3
}

# 1. The active version.
"$SF" data query --json -q "SELECT VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName = '$AGENT' AND Status = 'Active'" -o "$ORG" >"$WORK/version.json" 2>"$WORK/version.err" || fail_step "the version lookup" "$WORK/version.json"
VERSION="$(python3 -c 'import json,sys
recs = json.load(open(sys.argv[1]))["result"]["records"]
print(recs[0]["VersionNumber"] if len(recs) == 1 else "")' "$WORK/version.json" 2>"$WORK/version.parse.err")"
if ! [[ "$VERSION" =~ ^[0-9]+$ ]]; then
  echo "agent-test: $AGENT has no active version in the org; publish and activate it first"
  exit 3
fi

# 2. The definition for that version, built from a copy of the spec in the temporary folder.
CASES="$(python3 -c 'import re,sys
agent, version, src, dst = sys.argv[1:5]
text = open(src, encoding="utf-8").read()
text = re.sub(r"(?m)^subjectVersion:.*\n", "", text)
text, n = re.subn(r"(?m)^subjectName:.*$", "subjectName: %s\nsubjectVersion: v%s" % (agent, version), text)
if n != 1:
    sys.exit("the spec needs one subjectName line")
open(dst, "w", encoding="utf-8").write(text)
print(len(re.findall(r"(?m)^\s*-?\s*utterance:", text)))' "$AGENT" "$VERSION" "$SPEC" "$WORK/spec.yaml")" || { echo "agent-test: could not build the spec copy"; exit 3; }

if [ "$DRY_RUN" -eq 1 ]; then
  "$SF" agent test create --json --spec "$WORK/spec.yaml" --api-name "$TEST" --test-runner testing-center --preview -o "$ORG" >"$WORK/create.json" 2>"$WORK/create.err" || fail_step "the definition preview" "$WORK/create.json"
  echo "agent-test: dry run: built $TEST for $AGENT v$VERSION ($CASES cases); nothing created or run"
  exit 0
fi

"$SF" agent test create --json --spec "$WORK/spec.yaml" --api-name "$TEST" --test-runner testing-center --force-overwrite -o "$ORG" >"$WORK/create.json" 2>"$WORK/create.err" || fail_step "the definition create" "$WORK/create.json"
DEFINED="$(python3 -c 'import glob,re
files = glob.glob("force-app/main/default/aiEvaluationDefinitions/*.xml")
m = re.search(r"<subjectVersion>v?(\d+)</subjectVersion>", open(files[0]).read()) if files else None
print(m.group(1) if m else "")' 2>"$WORK/defined.err")"
if [ "$DEFINED" != "$VERSION" ]; then
  echo "agent-test: the created definition does not name v$VERSION"
  exit 3
fi
echo "agent-test: $AGENT version $VERSION (active), test $TEST, $CASES cases"

# 3. The run. sf exits 1 when a case ends in ERROR, so its exit code is not the verdict; the JSON is.
"$SF" agent test run --json --api-name "$TEST" --test-runner testing-center --wait "$WAIT" --result-format json -o "$ORG" >"$WORK/run.json" 2>"$WORK/run.err"
python3 - "$WORK/run.json" "$AGENT" "$VERSION" "$WAIT" <<'PY'
import json, sys
path, agent, version, wait = sys.argv[1:5]
try:
    data = json.load(open(path))
except Exception:
    print("agent-test: the run returned no JSON; run the sf command by hand to see why")
    sys.exit(3)
result = data.get("result") or {}
status = result.get("status")
cases = result.get("testCases")
if status != "COMPLETED" or not isinstance(cases, list):
    if status in ("NEW", "IN_PROGRESS"):
        print("agent-test: the run did not finish within %s minutes (status %s); try a longer --wait" % (wait, status))
    else:
        print("agent-test: the run failed (%s)" % (data.get("name") or status or "no status"))
    sys.exit(3)
LABELS = {
    "topic_assertion": "subagent", "topic_sequence_match": "subagent",
    "action_assertion": "actions", "actions_assertion": "actions", "action_sequence_match": "actions",
    "output_validation": "outcome", "bot_response_rating": "outcome",
}
ORDER = ["subagent", "actions", "outcome"]
counts = {}
skipped = 0
errored_cases = 0
for case in cases:
    if case.get("status") == "ERROR":
        errored_cases += 1
    for r in case.get("testResults") or []:
        label = LABELS.get(r.get("name"), str(r.get("name")))
        if label == "subagent" and not (r.get("expectedValue") or "").strip():
            skipped += 1
            continue
        c = counts.setdefault(label, {"passed": 0, "failed": 0, "errors": 0})
        verdict = r.get("result")
        if verdict == "PASS":
            c["passed"] += 1
        elif verdict == "ERROR":
            c["errors"] += 1
        else:
            c["failed"] += 1
for label in ORDER + sorted(k for k in counts if k not in ORDER):
    if label not in counts:
        continue
    c = counts[label]
    line = "%s: %d passed, %d failed" % (label, c["passed"], c["failed"])
    if c["errors"]:
        line += ", %d errored" % c["errors"]
    if label == "subagent" and skipped:
        line += " (%d cases set no subagent; not counted)" % skipped
    print(line)
if errored_cases:
    print("cases that ended in ERROR: %d" % errored_cases)
passed = sum(c["passed"] for c in counts.values())
total = sum(c["passed"] + c["failed"] + c["errors"] for c in counts.values())
print("agent-test: %d of %d assertions passed on %s v%s (%d cases)" % (passed, total, agent, version, len(cases)))
sys.exit(0 if passed == total and not errored_cases else 1)
PY
