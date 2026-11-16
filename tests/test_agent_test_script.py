"""Checks for the Testing Center suite (tests/agent/Customer_Summary-testSpec.yaml) and scripts/agent-test.sh (BE-38).

The spec checks read the YAML with a small parser (no YAML library here): its shape, the 20-case cap, that no case
asks for a write, and that every case that reaches a summary uses the one sample account the suite is allowed to
brief. The script checks run scripts/agent-test.sh against a fake `sf` on PATH that returns canned JSON, so the
parsing, the counts, the version line and the clean tree are proven without an org.
"""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "tests/agent/Customer_Summary-testSpec.yaml"
SCRIPT = ROOT / "scripts/agent-test.sh"
RESOLVER = ROOT / "force-app/main/default/classes/CustomerSummaryResolver.cls"
SUMMARY = ROOT / "force-app/main/default/classes/CustomerSummary.cls"
RENAME_VERDICT = ROOT / "docs/research/fr2-rename-go.md"

MAX_CASES = 20
SUMMARY_ACCOUNT = "Gallowglass Textiles"
DEMO_ACCOUNT = "Edge Communications"
READ_ACTIONS = {"resolve_account", "get_brief", "explore_data"}
SUBAGENTS = {"account_summary", "explore"}
WRITE_WORDS = re.compile(
    r"(?i)\b(create|update|delete|remove|edit|change|save|log|add|assign|insert|close (?:the|this|that) (?:deal|case|opportunity))\b"
)


def scalar(raw):
    raw = raw.strip()
    if raw.startswith('"'):
        return json.loads(raw)
    return raw


def parse_spec(text):
    """A list of case dicts: utterance, expectedTopic, expectedActions, expectedOutcome, conversationHistory."""
    body = text.split("\ntestCases:\n", 1)[1]
    cases = []
    for chunk in re.split(r"(?m)^  - ", body):
        if not chunk.strip():
            continue
        case = {"expectedActions": [], "conversationHistory": []}
        lines = ("    " + chunk).splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            m = re.match(r"^    (\w+):\s*(.*)$", line)
            if not m:
                i += 1
                continue
            key, value = m.group(1), m.group(2)
            if key == "expectedActions":
                i += 1
                while i < len(lines) and re.match(r"^      - ", lines[i]):
                    case["expectedActions"].append(lines[i].strip()[2:].strip())
                    i += 1
                continue
            if key == "conversationHistory":
                i += 1
                turn = None
                while i < len(lines) and lines[i].startswith("      "):
                    t = re.match(r"^      (?:- )?\s*(\w+):\s*(.*)$", lines[i])
                    if lines[i].startswith("      - "):
                        turn = {}
                        case["conversationHistory"].append(turn)
                    if t and turn is not None:
                        turn[t.group(1)] = scalar(t.group(2))
                    i += 1
                continue
            case[key] = scalar(value)
            i += 1
        cases.append(case)
    return cases


def spec_text():
    return SPEC.read_text(encoding="utf-8")


def fixed_text(path, name):
    """The value of a `@TestVisible private static final String NAME = '...'` constant, Apex escapes undone."""
    text = path.read_text(encoding="utf-8")
    m = re.search(r"String %s = '((?:[^'\\]|\\.)*)'" % name, text)
    return m.group(1).replace("\\'", "'")


class TestSuiteSpec(unittest.TestCase):
    def setUp(self):
        self.text = spec_text()
        self.cases = parse_spec(self.text)

    def case(self, utterance):
        found = [c for c in self.cases if c.get("utterance") == utterance]
        self.assertEqual(len(found), 1, utterance)
        return found[0]

    def test_header(self):
        self.assertRegex(self.text, r"(?m)^subjectType: AGENT$")
        self.assertRegex(self.text, r"(?m)^subjectName: Customer_Summary$")
        # The script adds the version at run time; the file never pins one.
        self.assertNotRegex(self.text, r"(?m)^subjectVersion:")

    def test_case_cap(self):
        self.assertGreaterEqual(len(self.cases), 7)
        self.assertLessEqual(len(self.cases), MAX_CASES)
        self.assertEqual(len(re.findall(r"(?m)^\s*-?\s*utterance:", self.text)), len(self.cases))

    def test_every_case_has_a_plain_outcome_and_known_checks(self):
        utterances = [c["utterance"] for c in self.cases]
        self.assertEqual(len(utterances), len(set(utterances)), "utterances repeat")
        for c in self.cases:
            self.assertTrue(c.get("expectedOutcome", "").strip(), c["utterance"])
            if "expectedTopic" in c:
                self.assertIn(c["expectedTopic"], SUBAGENTS, c["utterance"])
            self.assertLessEqual(set(c["expectedActions"]), READ_ACTIONS, c["utterance"])
            roles = [t.get("role") for t in c["conversationHistory"]]
            self.assertEqual(roles, ["user", "agent"] * (len(roles) // 2), c["utterance"])
            for turn in c["conversationHistory"]:
                self.assertTrue(turn.get("message"), c["utterance"])
                if turn["role"] == "agent":
                    self.assertIn(turn.get("topic"), SUBAGENTS, c["utterance"])

    def test_no_case_asks_for_a_write(self):
        for c in self.cases:
            said = [c["utterance"]] + [t["message"] for t in c["conversationHistory"] if t["role"] == "user"]
            for text in said:
                self.assertIsNone(WRITE_WORDS.search(text), text)
        self.assertNotIn("customEvaluations", self.text)

    def test_every_summary_uses_the_one_sample_account(self):
        self.assertNotIn(DEMO_ACCOUNT, self.text)
        briefs = [c for c in self.cases if "get_brief" in c["expectedActions"]]
        self.assertGreaterEqual(len(briefs), 3)
        for c in briefs:
            said = c["utterance"] + " ".join(t["message"] for t in c["conversationHistory"])
            self.assertIn(SUMMARY_ACCOUNT, said, c["utterance"])
        accounts = json.loads((ROOT / "data/sample/accounts.json").read_text(encoding="utf-8"))
        records = accounts.get("records", accounts)
        self.assertIn(SUMMARY_ACCOUNT, [r["Name"] for r in records])

    def test_required_kinds_of_case(self):
        named = self.case("Give me a summary of %s" % SUMMARY_ACCOUNT)
        self.assertEqual(named["expectedTopic"], "account_summary")
        self.assertEqual(named["expectedActions"], ["resolve_account", "get_brief"])

        missing = self.case("Brief me on Zzqxv Nonexistent Holdings")
        self.assertEqual(missing["expectedActions"], ["resolve_account"])

        several = self.case("Brief me on United Oil")
        self.assertEqual(several["expectedActions"], ["resolve_account"])
        self.assertIn("Which one?", several["expectedOutcome"])

        follow_up = self.case("What about their open deals?")
        self.assertEqual([t["role"] for t in follow_up["conversationHistory"]], ["user", "agent"])
        self.assertIn(SUMMARY_ACCOUNT, follow_up["conversationHistory"][0]["message"])
        self.assertIn("get_brief", follow_up["expectedActions"])

        org_wide = self.case("How many open opportunities are there?")
        self.assertEqual(org_wide["expectedTopic"], "explore")
        self.assertEqual(org_wide["expectedActions"], ["explore_data"])

        off_topic = self.case("What is the weather in Paris today?")
        self.assertNotIn("expectedTopic", off_topic)
        self.assertEqual(off_topic["expectedActions"], [])

    def test_one_case_per_error_status_from_be29(self):
        # The resolver's query error (N7) and the over-cap line (N1). Neither can be reached by the admin who runs the
        # suite, so each case starts after the error reply and checks the agent does not repeat it.
        summary = SUMMARY.read_text(encoding="utf-8")
        cap = re.search(r"Integer MAX_BRIEFS_PER_CALL = (\d+);", summary).group(1)
        over_cap = re.search(
            r"String OVER_CAP_TEXT = '([^']*)' \+ MAX_BRIEFS_PER_CALL\s*\+ '([^']*)';", summary
        )
        over_cap_text = over_cap.group(1) + cap + over_cap.group(2)
        for text in (fixed_text(RESOLVER, "ERROR_TEXT"), over_cap_text):
            with_error = [
                c for c in self.cases
                if any(t["role"] == "agent" and t["message"] == text for t in c["conversationHistory"])
            ]
            self.assertEqual(len(with_error), 1, text)
            c = with_error[0]
            self.assertEqual(c["expectedActions"], ["resolve_account", "get_brief"])
            self.assertIn(SUMMARY_ACCOUNT, c["utterance"])


class TestAgentTestScriptText(unittest.TestCase):
    def setUp(self):
        self.text = SCRIPT.read_text(encoding="utf-8")

    def test_exists_and_is_executable(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        self.assertTrue(self.text.startswith("#!/usr/bin/env bash"))

    def test_flags_and_defaults(self):
        for flag in ("--org", "--agent", "--spec", "--wait", "--dry-run", "--help"):
            self.assertIn(flag, self.text)
        self.assertIn('ORG="${SF_TARGET_ORG:-agent-probe}"', self.text)
        self.assertIn('AGENT="Customer_Summary"', self.text)
        self.assertIn("--test-runner testing-center", self.text)
        self.assertIn("--force-overwrite", self.text)
        self.assertIn("subjectVersion", self.text)
        self.assertNotIn("experimental", self.text)
        self.assertNotIn("/dev/null", self.text)
        # Every sf call names the org.
        calls = re.findall(r'"\$SF" [^\n]+', self.text)
        self.assertTrue(calls)
        for call in calls:
            self.assertIn('-o "$ORG"', call)

    def test_default_agent_follows_the_rename_verdict(self):
        plain = RENAME_VERDICT.read_text(encoding="utf-8").split("## Plain answer", 1)[1][:600]
        self.assertIn("**GO.**", plain)


FAKE_SF = r'''#!/usr/bin/env python3
import json, os, shutil, sys
log = os.environ["FAKE_SF_LOG"]
args = sys.argv[1:]
with open(log, "a") as f:
    f.write(json.dumps({"args": args, "cwd": os.getcwd()}) + "\n")
mode = os.environ.get("FAKE_SF_MODE", "ok")
cmd = " ".join(args[:3])
if args[:2] == ["data", "query"]:
    recs = [] if mode == "no-active" else [{"attributes": {"type": "BotVersion", "url": "/services/data/v68.0/sobjects/BotVersion/0X9bm000000AAAAAAA"}, "VersionNumber": 2}]
    print(json.dumps({"status": 0, "result": {"records": recs, "totalSize": len(recs)}}))
elif cmd == "agent test create":
    spec = args[args.index("--spec") + 1]
    shutil.copy(spec, os.environ["FAKE_SF_SPEC_COPY"])
    name = args[args.index("--api-name") + 1]
    version = [l.split(":", 1)[1].strip() for l in open(spec) if l.startswith("subjectVersion:")][0]
    if "--preview" not in args:
        out = os.path.join("force-app", "main", "default", "aiEvaluationDefinitions")
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, name + ".aiEvaluationDefinition-meta.xml"), "w") as f:
            f.write("<AiEvaluationDefinition><subjectVersion>%s</subjectVersion></AiEvaluationDefinition>" % version)
    print(json.dumps({"status": 0, "result": {"path": os.path.abspath(name), "contents": "<x/>"}}))
elif cmd == "agent test run":
    if mode == "timeout":
        print(json.dumps({"status": 0, "result": {"status": "IN_PROGRESS", "runId": "4KBbm000000AAAAAAA"}}))
        sys.exit(0)
    def tc(utt, topic_expected, topic, action, outcome):
        return {
            "status": "COMPLETED",
            "inputs": {"utterance": utt},
            "generatedData": {"outcome": "reply for admin@example.com at https://example.my.salesforce.com", "sessionId": "0Xxbm000000BBBBBBB"},
            "testResults": [
                {"name": "topic_assertion", "result": topic, "expectedValue": topic_expected, "actualValue": "account_summary"},
                {"name": "action_assertion", "result": action, "expectedValue": "['resolve_account']"},
                {"name": "output_validation", "result": outcome, "expectedValue": "x", "score": 5},
                {"name": "coherence", "result": "PASS", "score": 5},
            ],
        }
    cases = [
        tc("a", "account_summary", "PASS", "PASS", "PASS"),
        tc("b", "account_summary", "FAILURE", "PASS", "PASS"),
        tc("c", "explore", "PASS", "FAILURE", "FAILURE"),
        tc("weather", "", "FAILURE", "PASS", "PASS"),
    ]
    print(json.dumps({"status": 1, "result": {"status": "COMPLETED", "runId": "4KBbm000000AAAAAAA", "testCases": cases}}))
    sys.exit(1)
else:
    print(json.dumps({"status": 1, "name": "UnexpectedCall", "message": "unexpected: " + cmd}))
    sys.exit(1)
'''


class TestAgentTestScriptRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.bin = os.path.join(self.tmp, "bin")
        os.makedirs(self.bin)
        fake = os.path.join(self.bin, "sf")
        with open(fake, "w") as f:
            f.write(FAKE_SF)
        os.chmod(fake, 0o755)
        self.log = os.path.join(self.tmp, "calls.jsonl")
        self.spec_copy = os.path.join(self.tmp, "spec-sent.yaml")

    def run_script(self, *args, mode="ok"):
        env = dict(
            os.environ,
            PATH=self.bin + os.pathsep + os.environ.get("PATH", ""),
            FAKE_SF_LOG=self.log,
            FAKE_SF_MODE=mode,
            FAKE_SF_SPEC_COPY=self.spec_copy,
            TMPDIR=self.tmp,
        )
        env.pop("SF_TARGET_ORG", None)
        return subprocess.run(
            ["bash", str(SCRIPT)] + list(args), env=env, cwd=str(ROOT), capture_output=True, text=True, timeout=120
        )

    def calls(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log) as f:
            return [json.loads(line) for line in f]

    def git_status(self):
        return subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=all"], cwd=str(ROOT), capture_output=True, text=True
        ).stdout

    def test_help(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        for flag in ("--org", "--agent", "--spec", "--wait", "--dry-run"):
            self.assertIn(flag, result.stdout)
        self.assertEqual(self.calls(), [])

    def test_unknown_flag_and_bad_agent_name(self):
        self.assertEqual(self.run_script("--nope").returncode, 2)
        self.assertEqual(self.run_script("--agent", "x' OR Name != '").returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_a_run_prints_counts_per_assertion_and_the_version(self):
        before = self.git_status()
        result = self.run_script()
        out = result.stdout
        self.assertEqual(result.returncode, 1, out + result.stderr)
        lines = out.strip().splitlines()
        self.assertIn("version 2", lines[0])
        # The weather case sets no subagent, so its subagent FAILURE is left out.
        self.assertIn("subagent: 2 passed, 1 failed", out)
        self.assertIn("actions: 3 passed, 1 failed", out)
        self.assertIn("outcome: 3 passed, 1 failed", out)
        self.assertIn("coherence: 4 passed, 0 failed", out)
        # Each failed check is named by its case number in the spec, never by anything the org returned.
        self.assertEqual(
            [l for l in lines if l.startswith("failed:")],
            ["failed: case 2 subagent", "failed: case 3 actions", "failed: case 3 outcome"],
        )
        self.assertRegex(lines[-1], r"^agent-test: 12 of 15 assertions passed on Customer_Summary v2")
        # No Ids, usernames or hosts reach the output.
        for leak in ("4KB", "0X9", "0Xx", "@", "http", "salesforce.com"):
            self.assertNotIn(leak, out + result.stderr)
        # Every call names agent-probe; the definition is built for the active version outside the repo.
        calls = self.calls()
        self.assertEqual([c["args"][:3] for c in calls], [["data", "query", "--json"], ["agent", "test", "create"], ["agent", "test", "run"]])
        for c in calls:
            self.assertEqual(c["args"][c["args"].index("-o") + 1], "agent-probe")
            self.assertFalse(Path(c["cwd"]).resolve().is_relative_to(ROOT), c["cwd"])
            self.assertFalse(os.path.exists(c["cwd"]), "the temporary folder is removed")
        create = calls[1]["args"]
        for flag in ("--force-overwrite", "--test-runner", "--api-name"):
            self.assertIn(flag, create)
        self.assertEqual(create[create.index("--api-name") + 1], "Customer_Summary_Test")
        sent = Path(self.spec_copy).read_text(encoding="utf-8")
        self.assertRegex(sent, r"(?m)^subjectName: Customer_Summary\nsubjectVersion: v2$")
        self.assertEqual(sent.count("utterance:"), spec_text().count("utterance:"))
        self.assertEqual(self.git_status(), before)

    def test_dry_run_builds_but_neither_creates_nor_runs(self):
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        self.assertIn("--preview", calls[1]["args"])
        self.assertIn("dry run", result.stdout.strip().splitlines()[-1])

    def test_an_unfinished_run_prints_no_counts(self):
        result = self.run_script("--wait", "1", mode="timeout")
        self.assertEqual(result.returncode, 3)
        self.assertNotIn("passed", result.stdout)
        self.assertNotIn("4KB", result.stdout + result.stderr)

    def test_no_active_version_stops_before_create(self):
        result = self.run_script(mode="no-active")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(len(self.calls()), 1)
        self.assertIn("no active version", result.stdout + result.stderr)

    def test_other_org_and_agent(self):
        result = self.run_script("--org", "scratch-alias", "--agent", "Other_Agent", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for c in self.calls():
            self.assertEqual(c["args"][c["args"].index("-o") + 1], "scratch-alias")
        sent = Path(self.spec_copy).read_text(encoding="utf-8")
        self.assertRegex(sent, r"(?m)^subjectName: Other_Agent$")


if __name__ == "__main__":
    unittest.main()
