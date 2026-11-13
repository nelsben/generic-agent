#!/usr/bin/env python3
"""BE-22 runner (spike, never deployed; run by hand, agent-probe only).

Measures the write-action router without the agent: one Models API call that turns a sentence into an action
and its fields, then the draft step (no DML), and, in its own transaction, Confirm in user mode inside a
savepoint that is rolled back. Every run is its own anonymous Apex transaction.

Usage:
  python3 spikes/actions/run.py draft <request id|all> [runs]   # model call + draft, no DML
  python3 spikes/actions/run.py commit [runs]                   # draft from fields + commit + undo, rolled back
  python3 spikes/actions/run.py callout                         # DML then a model call in one transaction
  python3 spikes/actions/run.py names                           # does a method named 'commit' compile?
  python3 spikes/actions/run.py inventory                       # read-only: LogACall target, subtype values, Task fields
  python3 spikes/actions/run.py precheck                     # no org call: the action-verb pre-check on requests.json
  python3 spikes/actions/run.py report                          # no org call: medians and checks
Requests are in requests.json. Results append to spikes/actions/results/<mode>.jsonl: codes, counts, timings,
booleans and dates only, plus, for precheck, the first non-filler word of each sample request, and, for inventory,
field, object and picklist value names (no Ids). The per-run Apex file is written to the system temp folder and deleted after the run.
"""
import calendar
import datetime
import html
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ORG = "agent-probe"
ACCOUNT = "Edge Communications"
TIMEOUT_S = 240
RESULTS = os.path.join(HERE, "results")


def apex_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def requests():
    return json.load(open(os.path.join(HERE, "requests.json")))


def run_apex(src):
    """Runs one anonymous Apex file. Returns (rows parsed from marker lines, cli code, wall ms)."""
    fd, path = tempfile.mkstemp(suffix=".apex", prefix="be22-")
    with os.fdopen(fd, "w") as f:
        f.write(src)
    t0 = time.time()
    try:
        p = subprocess.run(["sf", "apex", "run", "--file", path, "-o", ORG, "--json"],
                           capture_output=True, text=True, timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return [], "timeout", int((time.time() - t0) * 1000)
    finally:
        os.remove(path)
    wall = int((time.time() - t0) * 1000)
    try:
        d = json.loads(p.stdout)
    except Exception:
        return [], "unparsed rc=%d" % p.returncode, wall
    res = d.get("result") or d.get("data") or {}
    if not res.get("compiled"):
        return [], "compile: %s (line %s)" % (res.get("compileProblem"), res.get("line")), wall
    if not res.get("success"):
        return [], "runtime: %s" % (res.get("exceptionMessage") or "")[:200], wall
    rows = []
    for line in (res.get("logs") or "").splitlines():
        # The log escapes "|" as "&#124;" and echoes the source, so match the unescaped USER_DEBUG line only.
        line = html.unescape(line)
        if "|USER_DEBUG|" in line and "BE22" in line:
            marker = line.split("|DEBUG|", 1)[-1] if "|DEBUG|" in line else line.split("|ERROR|", 1)[-1]
            head, _, rest = marker.partition("|")
            row = {"marker": head}
            for part in rest.split("|"):
                k, _, v = part.partition("=")
                row[k] = int(v) if v.lstrip("-").isdigit() else v
            rows.append(row)
    return rows, "", wall


def record(mode, row):
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, mode + ".jsonl"), "a") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")
    print(json.dumps(row, sort_keys=True), flush=True)


def body(name):
    return open(os.path.join(HERE, name)).read()


def count(mode, key, value):
    path = os.path.join(RESULTS, mode + ".jsonl")
    if not os.path.exists(path):
        return 0
    return sum(1 for line in open(path) if json.loads(line).get(key) == value)


def draft(rid, runs):
    todo = [r for r in requests() if rid in ("all", r["id"])]
    for _ in range(runs):
        for r in todo:
            src = "String REQ_ID = %s;\nString REQUEST = %s;\nString ACCOUNT = %s;\n" % (
                apex_str(r["id"]), apex_str(r["request"]), apex_str(ACCOUNT))
            rows, cli, wall = run_apex(body("router.apex") + "\n" + src + body("draft-run.apex"))
            row = rows[0] if rows else {"id": r["id"]}
            row.update({"cli": cli, "wallMs": wall, "run": count("draft", "id", r["id"]) + 1})
            row.pop("marker", None)
            record("draft", row)


def commit(runs):
    for _ in range(runs):
        src = "String ACCOUNT = %s;\n" % apex_str(ACCOUNT)
        rows, cli, wall = run_apex(body("router.apex") + "\n" + src + body("commit-run.apex"))
        n = count("commit", "id", "afterRollback") + 1
        if not rows:
            record("commit", {"cli": cli, "wallMs": wall, "run": n})
        for row in rows:
            row.pop("marker", None)
            row.update({"cli": cli, "wallMs": wall, "run": n})
            record("commit", row)


def callout():
    rows, cli, wall = run_apex(body("router.apex") + "\n" + body("callout-after-dml.apex"))
    row = {"cli": cli, "wallMs": wall}
    if rows:
        row.update({k: v for k, v in rows[0].items() if k != "marker"})
    record("probes", dict(row, probe="callout-after-dml"))


def names():
    for name in ("commit", "commitDraft", "draft", "undo"):
        src = "Integer %s(Integer x) { return x; }\nSystem.debug(LoggingLevel.ERROR, 'BE22N|ok=' + %s(1));\n" % (name, name)
        rows, cli, wall = run_apex(src)
        record("probes", {"probe": "method-name", "name": name, "compiles": not cli.startswith("compile"),
                          "cli": cli.split(" (line")[0]})


INVENTORY = r"""
List<String> parts = new List<String>();
for (String qa : new List<String>{ 'LogACall', 'Global.LogACall' }) {
    try {
        QuickAction.DescribeQuickActionResult r = QuickAction.describeQuickActions(new List<String>{ qa })[0];
        parts.add('quickAction_' + qa.replace('.', '_') + '_target=' + r.getTargetSobjectType());
    } catch (Exception e) {
        parts.add('quickAction_' + qa.replace('.', '_') + '_target=error:' + e.getTypeName());
    }
}
Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
parts.add('taskDescribeHasType=' + taskFields.containsKey('type'));
List<String> vals = new List<String>();
for (Schema.PicklistEntry p : Schema.SObjectType.Task.fields.TaskSubtype.getPicklistValues()) vals.add(p.getValue());
parts.add('taskSubtypeValues=' + String.join(vals, ','));
vals = new List<String>();
for (Schema.PicklistEntry p : Schema.SObjectType.Event.fields.EventSubtype.getPicklistValues()) vals.add(p.getValue());
parts.add('eventSubtypeValues=' + String.join(vals, ','));
vals = new List<String>();
for (FieldDefinition f : [SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Task'
        AND QualifiedApiName IN ('Type', 'TaskSubtype', 'Status') ORDER BY QualifiedApiName]) vals.add(f.QualifiedApiName);
parts.add('fieldDefinitionFound=' + String.join(vals, ','));
parts.add('dml=' + Limits.getDmlStatements());
System.debug(LoggingLevel.ERROR, 'BE22I|' + String.join(parts, '|'));
"""


def inventory():
    rows, cli, wall = run_apex(INVENTORY)
    row = {"cli": cli, "wallMs": wall, "probe": "inventory"}
    if rows:
        row.update({k: v for k, v in rows[0].items() if k != "marker"})
    record("inventory", row)


# The pre-check draftFromText could run before its model call: skip filler words, then test the first word.
FILLER = {"uh", "um", "so", "ok", "okay", "hey", "please", "can", "could", "would", "you", "i", "need", "to", "want", "let's"}
VERBS = {"create", "add", "schedule", "set", "book", "log", "remind", "update", "change", "open", "push", "move", "make"}


def first_verb(text):
    for word in text.lower().replace(",", " ").replace(":", " ").split():
        if word not in FILLER:
            return word
    return ""


def precheck():
    for r in requests():
        w = first_verb(r["request"])
        hit = w in VERBS
        want = r["expect"] != "none"
        anywhere = any(v in r["request"].lower().replace(",", " ").split() for v in VERBS)
        record("precheck", {"id": r["id"], "firstWord": w, "startsWithVerb": hit, "verbAnywhere": anywhere,
                            "isAction": want, "right": hit == want})


def expected_date(rule, today):
    if rule == "tomorrow":
        return today + datetime.timedelta(days=1)
    if rule == "next-tuesday":
        ahead = (1 - today.weekday()) % 7 or 7
        return today + datetime.timedelta(days=ahead)
    if rule == "end-of-next-month":
        y, m = (today.year + (today.month // 12), today.month % 12 + 1)
        return datetime.date(y, m, calendar.monthrange(y, m)[1])
    return None


def med(xs):
    xs = [x for x in xs if isinstance(x, int)]
    return "%d" % statistics.median(xs) if xs else "-"


def rng(xs):
    xs = [x for x in xs if isinstance(x, int)]
    return "%d-%d" % (min(xs), max(xs)) if xs else "-"


def report():
    path = os.path.join(RESULTS, "draft.jsonl")
    rows = [json.loads(line) for line in open(path)] if os.path.exists(path) else []
    print("request | runs | action right | date right | ready | model ms median (range) | in tok | out tok | draft ms | draft soql | dml")
    all_ok = []
    for r in requests():
        mine = [x for x in rows if x.get("id") == r["id"] and not x.get("cli")]
        if not mine:
            continue
        act = sum(1 for x in mine if x.get("action") == r["expect"])
        dates = "-"
        if r.get("dateRule"):
            good = 0
            for x in mine:
                exp = expected_date(r["dateRule"], datetime.date.fromisoformat(x["orgToday"]))
                if str(x.get("date", "")).startswith(exp.isoformat()) and (r["dateRule"] != "tomorrow" or str(x.get("date", "")).endswith("T14:00")):
                    good += 1
            dates = "%d/%d" % (good, len(mine))
        ready = sum(1 for x in mine if x.get("ready") == "true")
        print("%s | %d | %d/%d | %s | %d/%d | %s (%s) | %s | %s | %s | %s | %s" % (
            r["id"], len(mine), act, len(mine), dates, ready, len(mine), med([x.get("modelMs") for x in mine]),
            rng([x.get("modelMs") for x in mine]), med([x.get("inTok") for x in mine]), med([x.get("outTok") for x in mine]),
            med([x.get("draftMs") for x in mine]), med([x.get("draftSoql") for x in mine]),
            ",".join(sorted({str(x.get("dml")) for x in mine}))))
        all_ok += mine
    if all_ok:
        print("all | %d runs | model ms median %s (%s) | wall ms median %s | in tok median %s | out tok median %s" % (
            len(all_ok), med([x.get("modelMs") for x in all_ok]), rng([x.get("modelMs") for x in all_ok]),
            med([x.get("wallMs") for x in all_ok]), med([x.get("inTok") for x in all_ok]), med([x.get("outTok") for x in all_ok])))
    failed = [x for x in rows if x.get("cli")]
    print("cli failures: %d" % len(failed))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "report"
    if mode == "draft":
        draft(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1)
    elif mode == "commit":
        commit(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    elif mode == "callout":
        callout()
    elif mode == "names":
        names()
    elif mode == "precheck":
        precheck()
    elif mode == "inventory":
        inventory()
    elif mode == "report":
        report()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
