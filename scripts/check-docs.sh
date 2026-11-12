#!/usr/bin/env bash
# Check that every relative link and image in README.md and docs/**/*.md resolves to a
# tracked file, and that every #anchor names a heading in its target (GitHub slug rules).
# Usage: bash scripts/check-docs.sh   (exit 1 and one line per broken link)
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import os, re, subprocess, sys
tracked = set(subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.split())
pages = [f for f in tracked if f == "README.md" or (f.startswith("docs/") and f.endswith(".md"))]
def slugs(path):
    out, text = set(), open(path, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for h in re.findall(r"^#{1,6}\s+(.*)$", text, flags=re.M):
        s = re.sub(r"[^\w\- ]", "", h.strip().lower().replace("`", "")).replace(" ", "-")
        out.add(s)
    return out
bad = 0
for page in sorted(pages):
    text = re.sub(r"```.*?```", "", open(page, encoding="utf-8").read(), flags=re.S)
    for target in re.findall(r"!?\[[^\]]*\]\(([^)\s]+)\)", text):
        if re.match(r"^[a-z]+:", target):
            continue
        path, _, anchor = target.partition("#")
        full = os.path.normpath(os.path.join(os.path.dirname(page), path)) if path else page
        if full not in tracked and not any(t.startswith(full + "/") for t in tracked):
            print(f"{page}: missing {target}"); bad += 1
        elif anchor and full.endswith(".md") and anchor not in slugs(full):
            print(f"{page}: no heading for {target}"); bad += 1
print(f"checked {len(pages)} pages, {bad} broken")
sys.exit(1 if bad else 0)
PY
