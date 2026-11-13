#!/usr/bin/env python3
"""BE-34 (spike, never deployed; run by hand, agent-probe only): does a Customer_Summary agent conversation keep its context after 1, 5, 15 and 30 idle minutes?

One session per gap. Each session: a first turn naming the account, then (after the gap) one follow-up that does
not name it, on the same session. Session Ids stay in this process's memory only; the per-run apex file is deleted
after each run and the result lines written to disk never hold an Id.
"""
import html, json, os, subprocess, sys, tempfile, time, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
TMPL = open(os.path.join(HERE, "turn.apex.tmpl")).read()
# Results and the per-run apex file go outside the repo (BE34_OUT_DIR, default the system temp folder).
WORK = os.environ.get("BE34_OUT_DIR", tempfile.gettempdir())
OUT = os.path.join(WORK, "be34-results.txt")
FIRST = "Give me a summary of Edge Communications"
FOLLOW = "What about their open cases?"
GAPS = [30, 15, 5, 1]  # minutes; started longest first so every follow-up lands close to its due time


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%H:%M:%S")


def log(line):
    with open(OUT, "a") as f:
        f.write(line + "\n")
    print(line, flush=True)


def turn(msg, sid):
    src = TMPL.replace("__MSG__", msg).replace("__SID__", sid or "")
    path = os.path.join(WORK, "be34-turn-%d.apex" % os.getpid())
    with open(path, "w") as f:
        f.write(src)
    try:
        p = subprocess.run(["sf", "apex", "run", "--file", path, "-o", "agent-probe", "--json"],
                           capture_output=True, text=True, timeout=280)
    except subprocess.TimeoutExpired:
        return {"cli": "timeout"}, ""
    finally:
        os.remove(path)
    try:
        res = json.loads(p.stdout).get("result") or {}
    except Exception:
        return {"cli": "unparsed rc=%d" % p.returncode}, ""
    if not res.get("compiled"):
        return {"cli": "compile: %s" % res.get("compileProblem")}, ""
    if not res.get("success"):
        return {"cli": "runtime: %s" % (res.get("exceptionMessage") or "")[:120]}, ""
    marker = ""
    for ln in (res.get("logs") or "").splitlines():
        # Only the USER_DEBUG line; the log echoes the source too. The log escapes "|" as "&#124;".
        ln = html.unescape(ln)
        if "|USER_DEBUG|" in ln and "BE34|" in ln:
            marker = ln.split("BE34|", 1)[1]
    if not marker:
        return {"cli": "no marker in the debug log"}, ""
    fields = dict(kv.split("=", 1) for kv in marker.split("|") if "=" in kv)
    out_sid = fields.pop("SID", "")
    return fields, out_sid


def main():
    log("# start %s UTC; first turn %r; follow-up %r; gaps %s min" % (now(), FIRST, FOLLOW, GAPS))
    sessions = []
    for gap in GAPS:
        t = now()
        fields, sid = turn(FIRST, None)
        ended = time.time()
        log("first  gap=%2d start=%s %s" % (gap, t, " ".join("%s=%s" % kv for kv in fields.items())))
        if "cli" in fields or not sid:
            log("# abort: the first turn did not return a session; no more turns spent")
            return
        sessions.append({"gap": gap, "sid": sid, "due": ended + gap * 60, "ended": ended})
    for s in sorted(sessions, key=lambda x: x["due"]):
        wait = s["due"] - time.time()
        if wait > 0:
            time.sleep(wait)
        if not s["sid"]:
            log("follow gap=%2d skipped: the first turn returned no session" % s["gap"])
            continue
        idle = (time.time() - s["ended"]) / 60.0
        t = now()
        fields, sid2 = turn(FOLLOW, s["sid"])
        kept = (fields.get("ok") == "true" and fields.get("sameSession") == "true"
                and fields.get("briefDelta", "0") not in ("0", "0.0", "") )
        log("follow gap=%2d idle=%.1fmin start=%s %s => %s" % (
            s["gap"], idle, t, " ".join("%s=%s" % kv for kv in fields.items()), "kept" if kept else "lost"))
    log("# end %s UTC" % now())


if __name__ == "__main__":
    main()
