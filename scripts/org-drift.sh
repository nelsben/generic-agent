#!/usr/bin/env bash
# Read-only drift check: does the org still match main? Covers force-app only.
# Retrieves the components that main holds (an allow-list of types, below) from the target org into a
# temporary folder outside the repo, compares each file with main's, prints counts by type and the
# names of what differs, and deletes the folder. It prints no Ids, hostnames or usernames, and
# keeps sf's JSON in the temporary folder.
# The allow-list is the only thing that decides what is retrieved. Types that can carry a consumer key
# or a secret (client apps, connected apps, MCP servers, credentials) are not on it and are never asked for.
# It never writes to the org and never changes the repo. Components that exist only in the org are not
# looked for: the manifest is built from main.
# Exit: 0 org matches main, 2 it differs, 1 the check could not run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET_ORG="${SF_TARGET_ORG:-agent-probe}"
SF="${SF_BIN:-/usr/local/bin/sf}"
[ -x "$SF" ] || SF="$(command -v sf || true)"
if [ -z "$SF" ]; then
  echo "org-drift: fail (sf CLI not found)"
  exit 1
fi
if [ ! -d force-app ]; then
  echo "org-drift: fail (force-app not found)"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/manifest" "$TMP/proj"

# 1. A manifest of what main holds (a local step), cut down to the allow-list.
"$SF" project generate manifest --source-dir force-app --name package --output-dir "$TMP/manifest" >/dev/null 2>"$TMP/err" || {
  echo "org-drift: fail (could not build a manifest from force-app)"
  exit 1
}
python3 - "$TMP/manifest/package.xml" "$TMP/proj/package.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

ALLOW = {
    "ApexClass", "CustomApplication", "CustomField", "CustomMetadata", "CustomObject", "FlexiPage",
    "Flow", "GenAiPromptTemplate", "LightningComponentBundle", "LightningMessageChannel",
    "PermissionSet", "PermissionSetGroup", "ReportType", "StaticResource",
}
ns = "http://soap.sforce.com/2006/04/metadata"
ET.register_namespace("", ns)
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for t in list(root.findall("{%s}types" % ns)):
    if t.find("{%s}name" % ns).text not in ALLOW:
        root.remove(t)
tree.write(sys.argv[2], xml_declaration=True, encoding="UTF-8")
PY
cat > "$TMP/proj/sfdx-project.json" <<EOF
{"packageDirectories": [{"path": "force-app", "default": true}], "sourceApiVersion": "68.0"}
EOF
mkdir -p "$TMP/proj/force-app"

# 2. Retrieve into the temporary project (read-only for the org).
rc=0
(cd "$TMP/proj" && "$SF" project retrieve start --manifest package.xml -o "$TARGET_ORG" --wait 20 --json >"$TMP/retrieve.json" 2>"$TMP/err") || rc=$?
if [ ! -s "$TMP/retrieve.json" ] || ! python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
sys.exit(0 if d.get('status')==0 else 1)" "$TMP/retrieve.json"; then
  echo "org-drift: fail (retrieve from $TARGET_ORG did not succeed, exit $rc)"
  exit 1
fi

# 3. Compare main's files with the retrieved ones.
python3 - "$ROOT/force-app" "$TMP/proj/force-app" <<'PY'
import os
import sys
import xml.etree.ElementTree as ET

local_root, org_root = sys.argv[1], sys.argv[2]
DIRS = {
    "classes": "ApexClass", "applications": "CustomApplication", "customMetadata": "CustomMetadata",
    "flexipages": "FlexiPage", "flows": "Flow", "genAiPromptTemplates": "GenAiPromptTemplate",
    "lwc": "LightningComponentBundle", "messageChannels": "LightningMessageChannel",
    "permissionsets": "PermissionSet", "permissionsetgroups": "PermissionSetGroup",
    "reportTypes": "ReportType", "staticresources": "StaticResource", "objects": "CustomObject",
}


# Values the org leaves out because they are its defaults.
DEFAULTS = {("/CustomObject/nameField/startingNumber", "1"), ("/CustomField/externalId", "false")}


def leaves(el, prefix=""):
    # Every leaf of an XML tree as (path, text). Order does not matter.
    path = prefix + "/" + el.tag.split("}")[-1]
    kids = list(el)
    if not kids:
        return [(path, (el.text or "").strip())]
    out = []
    for k in kids:
        out.extend(leaves(k, path))
    return out


def same(a, b):
    # XML: the org's copy may add defaults it fills in (for example trackTrending), so main's leaves
    # must all be there, as a multiset, and extra leaves in the org are not drift. Other files: exact.
    if a.endswith(".xml"):
        try:
            mine = leaves(ET.parse(a).getroot())
            theirs = leaves(ET.parse(b).getroot())
        except ET.ParseError:
            mine = theirs = None
        if mine is not None:
            pool = {}
            for item in theirs:
                pool[item] = pool.get(item, 0) + 1
            for item in mine:
                if item in DEFAULTS:
                    continue
                if pool.get(item, 0) == 0:
                    return False
                pool[item] -= 1
            return True
    with open(a, "rb") as fa, open(b, "rb") as fb:
        return fa.read().replace(b"\r\n", b"\n").rstrip() == fb.read().replace(b"\r\n", b"\n").rstrip()


def component(rel):
    # rel: main/default/<dir>/<...>; returns (type, name)
    parts = rel.split(os.sep)
    d = parts[2]
    t = DIRS.get(d)
    if t is None:
        return None
    if d == "objects":
        if len(parts) > 4 and parts[4] == "fields":
            return "CustomField", parts[3] + "." + parts[5].split(".")[0]
        return "CustomObject", parts[3]
    if d == "lwc":
        return t, parts[3]
    if d == "staticresources":
        return t, parts[3].split(".")[0]
    return t, parts[3].split(".")[0]


differs, absent, present = set(), set(), set()
for base, _, files in os.walk(local_root):
    for fn in files:
        if fn == ".gitkeep":
            continue
        path = os.path.join(base, fn)
        rel = os.path.relpath(path, local_root)
        if "__tests__" in rel.split(os.sep):
            continue  # Jest tests are not deployed
        comp = component(rel)
        if comp is None:
            continue
        other = os.path.join(org_root, rel)
        if comp[0] == "StaticResource" and not fn.endswith(".xml"):
            # The org names the body by its content type (.txt, .png), main by its own; match on the name.
            stem = os.path.join(os.path.dirname(other), fn.rsplit(".", 1)[0])
            found = [stem + ext for ext in (".resource", ".txt", ".png", ".svg", ".js", ".css", ".json", ".html")]
            other = next((c for c in found if os.path.exists(c)), other)
        if not os.path.exists(other):
            absent.add(comp)
        else:
            present.add(comp)
            if not same(path, other):
                differs.add(comp)

# A component with none of its files in the org is missing; one with some of them there that
# differs (or lacks a file) is changed.
missing = absent - present
differs |= absent & present


def report(label, items):
    by = {}
    for t, n in items:
        by.setdefault(t, []).append(n)
    print("%s: %d" % (label, len(items)))
    for t in sorted(by):
        print("  %s: %d" % (t, len(by[t])))
        for n in sorted(by[t]):
            print("    %s" % n)


if not differs and not missing:
    print("org-drift: in sync (the org matches main for the types checked)")
    sys.exit(0)
print("org-drift: differs")
if differs:
    report("changed in the org", differs)
if missing:
    report("missing from the org", missing)
sys.exit(2)
PY
