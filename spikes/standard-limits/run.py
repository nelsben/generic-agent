#!/usr/bin/env python3
"""BE-32 runner (spike, never deployed; run by hand, agent-probe only).

Measures how much of an action's answer the active Customer_Summary agent relays, against the same
question on the direct Apex path. Every run is its own anonymous Apex transaction, so an agent turn
never shares a transaction with a direct call (and a brief's memory write never precedes a callout).

Usage:
  python3 spikes/standard-limits/run.py direct <rung> [runs]   # action class and panel path, no agent
  python3 spikes/standard-limits/run.py agent <rung> [runs]    # generateAiAgentResponse, new session per run
  python3 spikes/standard-limits/run.py sessions <label>       # count the product's session rows
  python3 spikes/standard-limits/run.py report                 # no org call: pair results, print pass/fail
Rungs are in rungs.json. Results append to spikes/standard-limits/results/<mode>.jsonl: counts and
booleans only. The per-run Apex file is written to the system temp folder and deleted after the run.
"""
import html
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ORG = "agent-probe"
TIMEOUT_S = 280
RESULTS = os.path.join(HERE, "results")


def apex_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def rung(rid):
    for r in json.load(open(os.path.join(HERE, "rungs.json"))):
        if r["id"] == rid:
            return r
    sys.exit("unknown rung %s" % rid)


def run_apex(src, marker):
    fd, path = tempfile.mkstemp(suffix=".apex", prefix="be32-")
    with os.fdopen(fd, "w") as f:
        f.write(src)
    try:
        p = subprocess.run(["sf", "apex", "run", "--file", path, "-o", ORG, "--json"],
                           capture_output=True, text=True, timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return {"cli": "timeout"}
    finally:
        os.remove(path)
    try:
        res = json.loads(p.stdout).get("result") or {}
    except Exception:
        return {"cli": "unparsed rc=%d" % p.returncode}
    if not res.get("compiled"):
        return {"cli": "compile: %s" % res.get("compileProblem")}
    if not res.get("success"):
        return {"cli": "runtime: %s" % (res.get("exceptionMessage") or "")[:160]}
    for line in (res.get("logs") or "").splitlines():
        # The log escapes "|" as "&#124;" and echoes the source, so match the unescaped USER_DEBUG line only.
        line = html.unescape(line)
        if "|USER_DEBUG|" in line and marker + "|" in line:
            out = {}
            for part in line.split(marker + "|", 1)[1].split("|"):
                k, _, v = part.partition("=")
                out[k] = int(v) if v.lstrip("-").isdigit() else v
            return out
    return {"cli": "no marker"}


def header(r):
    lines = ["String RUNG = %s;" % apex_str(r["id"]), "String QUESTION = %s;" % apex_str(r["question"])]
    if r.get("account"):
        lines.append("String ACCOUNT = %s;" % apex_str(r["account"]))
    return "\n".join(lines) + "\n"


def record(mode, row):
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, mode + ".jsonl"), "a") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")
    print(json.dumps(row, sort_keys=True), flush=True)


SESSIONS = """
Integer rows = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId()];
Decimal briefs = 0;
for (Customer_Summary_Session__c s : [SELECT Brief_Count__c FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId()]) {
    briefs += s.Brief_Count__c == null ? 0 : s.Brief_Count__c;
}
System.debug('BE32S|rows=' + rows + '|briefs=' + briefs);
"""


def load(mode):
    path = os.path.join(RESULTS, mode + ".jsonl")
    return [json.loads(line) for line in open(path)] if os.path.exists(path) else []


def report():
    """Read-only: pair each agent run with the direct run of the same rung and number, print sizes and pass/fail."""
    direct = {(r["rung"], r["run"]): r for r in load("direct")}
    for a in load("agent"):
        d = direct.get((a["rung"], a["run"]))
        if a.get("cli") or not d or d.get("cli"):
            print("%s run %s: no pair" % (a["rung"], a["run"]))
            continue
        if a["rung"] == "brief":
            checks = {"labelsOwnLine": a["labels"] == d["labels"]}
            if "labelsAnywhere" in a:
                checks["sectionsPresent"] = a["labelsAnywhere"] == 6
                checks["dashLines"] = a["bulletLines"] == d["bulletLines"]
            sizes = "action=%d relayed=%d" % (d["actionLen"], a["replyLen"])
        else:
            checks = {"rows": a["rows"] == d["actionRows"], "footer": a["footer"] == d["actionFooter"],
                      "cols": a["cols"] == d["actionCols"], "names": a["names"] == d["actionNames"]}
            sizes = "action=%d relayed=%d panel=%d" % (d["actionLen"], a["replyLen"], d["panelRenderedLen"])
        verdict = "PASS" if all(checks.values()) else "FAIL " + ",".join(k for k, v in checks.items() if not v)
        print("%s run %d: %s %s" % (a["rung"], a["run"], sizes, verdict))


def main():
    mode = sys.argv[1]
    if mode == "report":
        report()
        return
    if mode == "sessions":
        row = run_apex(SESSIONS, "BE32S")
        row["label"] = sys.argv[2] if len(sys.argv) > 2 else ""
        record("sessions", row)
        return
    r = rung(sys.argv[2])
    runs = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    if mode == "direct":
        body, marker = ("brief-direct.apex", "BE32B") if r["kind"] == "brief" else ("explore-direct.apex", "BE32D")
    elif mode == "agent":
        body, marker = "agent-turn.apex", "BE32A"
    else:
        sys.exit("mode must be direct, agent or sessions")
    src = header(r) + open(os.path.join(HERE, body)).read()
    done = 0
    path = os.path.join(RESULTS, mode + ".jsonl")
    if os.path.exists(path):
        done = sum(1 for line in open(path) if json.loads(line).get("rung") == r["id"])
    for i in range(runs):
        row = run_apex(src, marker)
        row["run"] = done + i + 1
        row.setdefault("rung", r["id"])
        record(mode, row)


if __name__ == "__main__":
    main()
