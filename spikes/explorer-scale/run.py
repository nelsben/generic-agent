#!/usr/bin/env python3
"""BE-31 runner: one anonymous Apex transaction per question per engine, in agent-probe only.

Usage: python3 spikes/explorer-scale/run.py <engine> [qid ...]
  engine: real | current | v2
       python3 spikes/explorer-scale/run.py tool <probe.apex>   (rejections.apex, catalog-scale.apex)
Writes spikes/explorer-scale/results/<engine>.jsonl (one line per question, counts only).
Each script is the header (question, reference), harness.apex and engine-<engine>.apex, with comments
and indentation stripped to stay under the anonymous Apex size limit (about 32,000 characters).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ORG = "agent-probe"
MAX_CHARS = 32000
PARALLEL = 3
TIMEOUT_S = 280


def apex_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


PUNCT = set("(){}[],;=+-*/<>!?:&|.")


def squeeze(code):
    """Drops whitespace next to punctuation, outside string literals. Keeps one space between words."""
    out = []
    i = 0
    while i < len(code):
        c = code[i]
        if c == "'":
            j = i + 1
            while code[j] != "'":
                j += 2 if code[j] == "\\" else 1
            out.append(code[i:j + 1])
            i = j + 1
        elif c.isspace():
            j = i
            while j < len(code) and code[j].isspace():
                j += 1
            prev = out[-1][-1] if out else ";"
            nxt = code[j] if j < len(code) else ";"
            if prev not in PUNCT and nxt not in PUNCT:
                out.append(" ")
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def minify(src):
    out = []
    for line in src.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        out.append(stripped)
    # "public" is not needed: the anonymous block can read every member of its own classes.
    return squeeze(re.sub(r"\bpublic ", "", "\n".join(out)))


def script(engine, q):
    header = "\n".join([
        "String QID = %s;" % apex_str(q["id"]),
        "String QUESTION = %s;" % apex_str(q["question"]),
        "Map<String, Object> REF = (Map<String, Object>) JSON.deserializeUntyped(%s);" % apex_str(json.dumps(q["ref"])),
    ])
    parts = [header, open(os.path.join(HERE, "harness.apex")).read()]
    if engine == "v2":
        parts.append(open(os.path.join(HERE, "prototype.apex")).read())
    parts.append(open(os.path.join(HERE, "engine-%s.apex" % engine)).read())
    return minify("\n".join(parts))


def run_one(engine, q):
    text = script(engine, q)
    if len(text) > MAX_CHARS:
        return {"q": q["id"], "engine": engine, "verdict": "FAIL:script-too-large", "chars": len(text)}
    with tempfile.NamedTemporaryFile("w", suffix=".apex", delete=False) as f:
        f.write(text)
        path = f.name
    try:
        proc = subprocess.run(["sf", "apex", "run", "-o", ORG, "-f", path], capture_output=True, text=True, timeout=TIMEOUT_S)
        log = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired:
        return {"q": q["id"], "engine": engine, "verdict": "FAIL:timeout"}
    finally:
        os.unlink(path)
    m = re.search(r"BE31 :: (\{.*\})", log)
    if not m:
        err = re.search(r"(System\.[A-Za-z]+Exception[^\n]*|Compilation failed[^\n]*\n+[^\n]*|Script too large)", log)
        return {"q": q["id"], "engine": engine, "verdict": "FAIL:no-result", "error": err.group(1).replace("\n", " ")[:300] if err else "unknown", "chars": len(text)}
    row = json.loads(m.group(1).replace("&quot;", '"').replace("&#124;", "|"))
    row["group"] = q["group"]
    row["scriptChars"] = len(text)
    return row


def tool(name):
    """Runs harness.apex, prototype.apex and one probe file once; prints its ' :: ' debug lines."""
    parts = [open(os.path.join(HERE, f)).read() for f in ("harness.apex", "prototype.apex", name)]
    text = minify("\n".join(parts))
    with tempfile.NamedTemporaryFile("w", suffix=".apex", delete=False) as f:
        f.write(text)
        path = f.name
    try:
        proc = subprocess.run(["sf", "apex", "run", "-o", ORG, "-f", path], capture_output=True, text=True, timeout=TIMEOUT_S)
    finally:
        os.unlink(path)
    log = proc.stdout + proc.stderr
    lines = [l.split("|ERROR|", 1)[1] for l in log.splitlines() if "|USER_DEBUG|" in l and "|ERROR|" in l]
    print("\n".join(x.replace("&quot;", '"').replace("&#124;", "|").replace("&#39;", "'") for x in lines) or log[-1500:])


def main():
    if sys.argv[1] == "tool":
        return tool(sys.argv[2])
    engine = sys.argv[1]
    wanted = set(sys.argv[2:])
    questions = [q for q in json.load(open(os.path.join(HERE, "questions.json"))) if not wanted or q["id"] in wanted]
    os.makedirs(os.path.join(HERE, "results"), exist_ok=True)
    out_path = os.path.join(HERE, "results", "%s.jsonl" % engine)
    done = {}
    if os.path.exists(out_path):
        for line in open(out_path):
            r = json.loads(line)
            done[r["q"]] = r
    with ThreadPoolExecutor(PARALLEL) as pool:
        for row in pool.map(lambda q: run_one(engine, q), questions):
            done[row["q"]] = row
            print(row["q"], row["verdict"], row.get("modelCalls"), row.get("error", ""), flush=True)
    with open(out_path, "w") as f:
        for qid in sorted(done):
            f.write(json.dumps(done[qid], sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
