import os
import re
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
LADDER = os.path.join(SCRIPTS, "ladder.sh")
SCAN = os.path.join(SCRIPTS, "apex-scan.sh")
DRIFT = os.path.join(SCRIPTS, "org-drift.sh")

# A real deploy, publish or activate: none of the three scripts may hold one.
FORBIDDEN = [
    r"project\s+deploy\s+start",
    r"project\s+deploy\s+quick",
    r"project\s+deploy\s+resume",
    r"agent\s+publish",
    r"agent\s+activate",
    r"agent\s+deactivate",
    r"CONFIRM_PROD",
]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def code_lines(path):
    return "\n".join(l for l in read(path).splitlines() if not l.strip().startswith("#"))


class TestLadder(unittest.TestCase):
    def test_scripts_exist(self):
        for path in (LADDER, SCAN, DRIFT):
            self.assertTrue(os.path.isfile(path), path)

    def test_rungs_run_in_order(self):
        text = code_lines(LADDER)
        names = ["python", "jest", "scan", "org-check", "drift", "e2e-smoke"]
        positions = []
        for name in names:
            m = re.search(r"^\s*rung\s+%s\b" % re.escape(name), text, re.M)
            self.assertIsNotNone(m, "no rung %s" % name)
            positions.append(m.start())
        self.assertEqual(positions, sorted(positions))

    def test_agent_track_follows_the_rungs(self):
        text = code_lines(LADDER)
        self.assertLess(text.index("rung e2e-smoke"), text.index("rung agent-compile"))
        self.assertLess(text.index("rung agent-compile"), text.index("rung agent-suite"))
        self.assertIn("skipped: agent suite not built", text)
        self.assertIn("agent-test.sh", text)

    def test_flags(self):
        text = read(LADDER)
        for flag in ("--agent", "--full", "--continue"):
            self.assertIn(flag, text)
        self.assertIn('"ladder"', read(os.path.join(ROOT, "package.json")))

    def test_org_rules(self):
        text = read(LADDER)
        self.assertIn("agent-probe", text)
        self.assertNotIn("experimental", text)

    def test_unknown_flag_fails(self):
        r = subprocess.run(["bash", LADDER, "--nope"], capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)

    def test_no_real_deploy_publish_or_activate(self):
        for path in (LADDER, SCAN, DRIFT):
            text = code_lines(path)
            for pattern in FORBIDDEN:
                self.assertIsNone(re.search(pattern, text), "%s: %s" % (path, pattern))

    def test_scan_says_what_it_skipped(self):
        text = read(SCAN)
        self.assertIn("skipped", text)
        self.assertIn("Java 11", text)
        for engine in ("pmd", "cpd", "sfge"):
            self.assertIn(engine, text)

    def test_drift_names_no_secret_bearing_type(self):
        for line in read(DRIFT).lower().splitlines():
            for bad in ("externalclientapp", "connectedapp", "mcpserver", "externalcredential"):
                if bad in line:
                    self.assertTrue(line.strip().startswith("#"), line)
        text = read(DRIFT)
        self.assertIn("-o ", text)
        self.assertIn("mktemp -d", text)
        self.assertIn("trap", text)
        self.assertNotIn("instanceUrl", text)


if __name__ == "__main__":
    unittest.main()
