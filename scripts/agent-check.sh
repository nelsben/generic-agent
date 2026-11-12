#!/usr/bin/env bash
# Gate `agent`: compile the Account_Brief Agent Script locally, then validate the authoring bundle in the org.
#   (a) The agentforce-generate skill's local compiler (index-agent.mjs). The AgentScript SDK is installed into
#       the skill's cache under the home directory (never into this repo) when it is missing. Any severity-1
#       diagnostic fails the gate; warnings are printed.
#   (b) `sf agent validate authoring-bundle` against the experimental org. Read-only: it compiles the bundle
#       in the org and saves nothing.
# Uses /usr/local/bin/sf (2.157.8) by absolute path: /opt/homebrew/bin/sf (2.130.9) is first on PATH and too old.
# stderr is never discarded, so CLI and compiler errors stay visible.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_NAME="Account_Brief"
AGENT_FILE="force-app/main/default/aiAuthoringBundles/$BUNDLE_NAME/$BUNDLE_NAME.agent"
SF="/usr/local/bin/sf"
SKILL_DIR="${AGENTFORCE_GENERATE_SKILL_DIR:-$HOME/.claude/plugins/cache/salesforce/agentforce-adlc/0.14.0/skills/agentforce-generate}"

fail() {
  echo "agent-check: fail ($1)"
  exit 1
}

[ -f "$AGENT_FILE" ] || fail "agent file not found: $AGENT_FILE"
[ -f "$SKILL_DIR/scripts/index-agent.mjs" ] || fail "agentforce-generate skill not found: $SKILL_DIR"
[ -x "$SF" ] || fail "sf CLI not found at $SF"
NODE="$(command -v node)" || fail "node not found on PATH"
echo "agent-check: node $NODE ($("$NODE" --version)), sf $SF"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# (a) Local compile. index-agent.mjs exits 2 when the SDK cannot load: install it into the cache and retry once.
compile_rc=0
"$NODE" "$SKILL_DIR/scripts/index-agent.mjs" "$AGENT_FILE" > "$work/index.json" || compile_rc=$?
if [ "$compile_rc" -eq 2 ]; then
  echo "agent-check: AgentScript SDK not loadable; installing it into the skill cache"
  "$NODE" "$SKILL_DIR/scripts/setup-agentscript-sdk.mjs" --npm --json || fail "AgentScript SDK setup failed"
  compile_rc=0
  "$NODE" "$SKILL_DIR/scripts/index-agent.mjs" "$AGENT_FILE" > "$work/index.json" || compile_rc=$?
fi

python3 - "$work/index.json" "$compile_rc" <<'PY' || exit 1
import json
import sys

path, rc = sys.argv[1], int(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        index = json.load(f)
except (OSError, ValueError):
    print("agent-check: fail (local compiler produced no JSON, exit %d)" % rc)
    sys.exit(1)

compiler = index.get("compiler") or {}
diagnostics = index.get("diagnostics") or []
errors = [d for d in diagnostics if d.get("severity") == 1]
print("agent-check: compiler %s %s (%s)" % (compiler.get("package"), compiler.get("version"), compiler.get("provider")))
for d in diagnostics:
    level = "error" if d.get("severity") == 1 else "warning"
    print("  %s line %s: %s: %s" % (level, d.get("line"), d.get("code"), d.get("message")))
if rc != 0 or errors:
    print("agent-check: fail (local compile: %d errors, exit %d)" % (len(errors), rc))
    sys.exit(1)
print("agent-check: local compile ok (%d warnings)" % len(diagnostics))
PY

# (b) Org validate of the authoring bundle.
validate_rc=0
"$SF" agent validate authoring-bundle --json --api-name Account_Brief -o experimental > "$work/validate.json" || validate_rc=$?

python3 - "$work/validate.json" "$validate_rc" <<'PY'
import json
import re
import sys

path, rc = sys.argv[1], int(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        raw = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", f.read())
    payload = json.loads(raw)
except (OSError, ValueError):
    print("agent-check: fail (sf agent validate produced no JSON, exit %d)" % rc)
    sys.exit(1)

result = payload.get("result") or {}
ok = rc == 0 and payload.get("status") == 0 and result.get("success") is True
if not ok:
    print(json.dumps(payload, indent=2))
    print("agent-check: fail (sf agent validate authoring-bundle, exit %d)" % rc)
    sys.exit(1)
for warning in payload.get("warnings") or []:
    print("  warning: %s" % warning)
print("agent-check: org validate ok (Account_Brief on experimental)")
PY

echo "agent-check: pass"
