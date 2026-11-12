#!/usr/bin/env bash
# Seeds the small dated sample-data set under data/sample/ into the target org (SF_TARGET_ORG, default agent-probe).
# The templates hold dates as day offsets from today ("$day:-30", "$datetime:-4@10:00"). This script renders them
# with today's date into a new temporary folder outside the repo, then runs one `sf data import tree`.
#   --render-only   render, print the folder path, touch no org (no sf call at all)
# Before importing it stops if an Account named Edge Communications already exists (one read-only query).
# sf output is never printed: it can hold a URL or a token. SEED_TODAY=YYYY-MM-DD overrides today (tests).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$ROOT/data/sample"
TARGET_ORG="${SF_TARGET_ORG:-agent-probe}"
render_only=0

case "${1:-}" in
  "") ;;
  --render-only) render_only=1 ;;
  *) echo "seed-sample-data: fail (unknown argument: $1; the only option is --render-only)"; exit 2 ;;
esac

[ -f "$TEMPLATES/sample-data-plan.json" ] || { echo "seed-sample-data: fail (plan not found: $TEMPLATES/sample-data-plan.json)"; exit 1; }

work="$(mktemp -d)"
keep=0
trap '[ "$keep" -eq 1 ] || rm -rf "$work"' EXIT

python3 - "$TEMPLATES" "$work" <<'PY'
import datetime
import json
import os
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
today = datetime.date.fromisoformat(os.environ.get("SEED_TODAY") or datetime.date.today().isoformat())
DAY = re.compile(r"^\$day:([+-]?\d+)$")
DATETIME = re.compile(r"^\$datetime:([+-]?\d+)@(\d{2}):(\d{2})$")


def render(value):
    if isinstance(value, dict):
        return {k: render(v) for k, v in value.items()}
    if isinstance(value, list):
        return [render(v) for v in value]
    if isinstance(value, str):
        m = DAY.match(value)
        if m:
            return (today + datetime.timedelta(days=int(m.group(1)))).isoformat()
        m = DATETIME.match(value)
        if m:
            day = today + datetime.timedelta(days=int(m.group(1)))
            return "%sT%s:%s:00.000+0000" % (day.isoformat(), m.group(2), m.group(3))
        if value.startswith("$"):
            sys.exit("seed-sample-data: fail (unknown date token: %s)" % value)
    return value


for name in sorted(os.listdir(src)):
    if not name.endswith(".json"):
        continue
    with open(os.path.join(src, name), encoding="utf-8") as f:
        data = json.load(f)
    with open(os.path.join(dst, name), "w", encoding="utf-8") as f:
        json.dump(render(data), f, indent=2, ensure_ascii=False)
        f.write("\n")
PY

if [ "$render_only" -eq 1 ]; then
  keep=1
  echo "$work"
  exit 0
fi

command -v sf >/dev/null 2>&1 || { echo "seed-sample-data: fail (sf not found on PATH)"; exit 1; }

# One read-only query: refuse to seed twice.
query_rc=0
sf data query --query "SELECT Id FROM Account WHERE Name = 'Edge Communications' LIMIT 1" \
  --json -o "$TARGET_ORG" > "$work/query.out" 2> /dev/null || query_rc=$?
existing="$(python3 - "$work/query.out" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        payload = json.load(f)
    print((payload.get("result") or {}).get("totalSize", "unknown") if payload.get("status") == 0 else "unknown")
except (OSError, ValueError):
    print("unknown")
PY
)"
if [ "$existing" = "unknown" ] || [ "$query_rc" -ne 0 ]; then
  echo "seed-sample-data: fail (could not check org $TARGET_ORG for an existing Edge Communications; is the alias signed in?)"
  exit 1
fi
if [ "$existing" != "0" ]; then
  echo "seed-sample-data: stop (org $TARGET_ORG already has an Account named Edge Communications; nothing was imported)"
  exit 1
fi

import_rc=0
sf data import tree --plan "$work/sample-data-plan.json" -o "$TARGET_ORG" --json > "$work/import.out" 2> /dev/null || import_rc=$?
summary="$(python3 - "$work/import.out" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        payload = json.load(f)
except (OSError, ValueError):
    print("no JSON")
    sys.exit(0)
if payload.get("status") == 0:
    print("ok %d" % len(payload.get("result") or []))
else:
    print("error %s" % str(payload.get("name") or "unknown")[:60])
PY
)"
case "$summary" in
  "ok "*)
    if [ "$import_rc" -eq 0 ]; then
      echo "seed-sample-data: pass (${summary#ok } records imported into $TARGET_ORG)"
      exit 0
    fi
    ;;
esac
keep=1
echo "seed-sample-data: fail (import into $TARGET_ORG: $summary, exit $import_rc; rendered files kept in $work; sf output is not shown)"
exit 1
