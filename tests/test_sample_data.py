"""Renders the sample-data templates (no org, no sf call) and checks the set the brief code reads."""
import datetime
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES = os.path.join(ROOT, "data", "sample")
SCRIPT = os.path.join(ROOT, "scripts", "seed-sample-data.sh")
TODAY = datetime.date(2026, 11, 12)


def load(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as f:
        return json.load(f)


class TestSampleData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # A fake sf that records any call: --render-only must never run it.
        cls.tmp = tempfile.mkdtemp()
        cls.bin = os.path.join(cls.tmp, "bin")
        os.makedirs(cls.bin)
        cls.marker = os.path.join(cls.tmp, "sf-called")
        fake = os.path.join(cls.bin, "sf")
        with open(fake, "w") as f:
            f.write("#!/bin/sh\ntouch '%s'\nexit 99\n" % cls.marker)
        os.chmod(fake, 0o755)
        env = dict(os.environ, SEED_TODAY=TODAY.isoformat(), PATH=cls.bin + os.pathsep + os.environ.get("PATH", ""))
        result = subprocess.run(
            ["bash", SCRIPT, "--render-only"], env=env, capture_output=True, text=True, timeout=60
        )
        assert result.returncode == 0, result.stdout + result.stderr
        cls.out = result.stdout.strip()
        cls.rendered = cls.out.splitlines()[-1]
        cls.plan = load(cls.rendered, "sample-data-plan.json")
        cls.records = []
        for entry in cls.plan:
            for name in entry["files"]:
                for r in load(cls.rendered, name)["records"]:
                    cls.records.append((entry, name, r))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.rendered, True)
        shutil.rmtree(cls.tmp, True)

    def of(self, sobject):
        return [r for _, _, r in self.records if r["attributes"]["type"] == sobject]

    def test_render_only_touches_no_org_and_uses_a_folder_outside_the_repo(self):
        self.assertFalse(os.path.exists(self.marker))
        self.assertTrue(os.path.isdir(self.rendered))
        self.assertFalse(os.path.abspath(self.rendered).startswith(ROOT + os.sep))
        self.assertEqual(len(self.out.splitlines()), 1)

    def test_plan_parses_and_every_reference_resolves(self):
        seen = set()
        for entry, name, r in self.records:
            self.assertEqual(r["attributes"]["type"], entry["sobject"], name)
            ref = r["attributes"]["referenceId"]
            self.assertNotIn(ref, seen, "duplicate reference id")
            for key, value in r.items():
                if isinstance(value, str) and value.startswith("@"):
                    self.assertIn(value[1:], seen, "%s.%s points at %s before it is defined" % (ref, key, value))
            seen.add(ref)
        # sf data import tree resolves a reference only from an earlier plan entry with saveRefs:
        # one into the same file, or into an entry that does not save refs, is sent as literal text.
        saved = set()
        for entry in self.plan:
            batch = [r for e, _, r in self.records if e is entry]
            for r in batch:
                for key, value in r.items():
                    if isinstance(value, str) and value.startswith("@"):
                        self.assertIn(value[1:], saved, "%s.%s points at %s, which no earlier plan entry saves"
                                      % (r["attributes"]["referenceId"], key, value))
            if entry.get("saveRefs"):
                saved.update(r["attributes"]["referenceId"] for r in batch)

    def test_record_count_is_under_300(self):
        self.assertLess(len(self.records), 300)

    def test_united_oil_accounts(self):
        uo = {a["Name"]: a for a in self.of("Account") if a["Name"].startswith("United Oil")}
        self.assertEqual(
            sorted(uo), ["United Oil & Gas Corp.", "United Oil & Gas, Singapore", "United Oil & Gas, UK"]
        )
        self.assertEqual(uo["United Oil & Gas Corp."]["BillingCity"], "New York")
        self.assertEqual(uo["United Oil & Gas, Singapore"]["BillingCity"], "Singapore")
        self.assertNotIn("BillingCity", uo["United Oil & Gas, UK"])
        names = [a["Name"] for a in self.of("Account")]
        self.assertNotIn("United Oil", names)
        self.assertNotIn("Zephyr Quartz Holdings", names)
        self.assertEqual(names.count("Edge Communications"), 1)

    def test_edge_profile_and_contacts(self):
        edge = [a for a in self.of("Account") if a["Name"] == "Edge Communications"][0]
        for field in ("Type", "Industry", "AnnualRevenue", "NumberOfEmployees", "BillingCity", "Website", "Description"):
            self.assertTrue(edge.get(field), field)
        ref = edge["attributes"]["referenceId"]
        contacts = [c for c in self.of("Contact") if c["AccountId"] == "@" + ref]
        self.assertTrue(4 <= len(contacts) <= 6, len(contacts))
        for c in contacts:
            self.assertTrue(c["Title"])

    def test_open_opportunities(self):
        opps = self.of("Opportunity")
        open_opps = [o for o in opps if not o["StageName"].startswith("Closed")]
        self.assertTrue(30 <= len(open_opps) <= 40, len(open_opps))
        amounts = [o["Amount"] for o in open_opps]
        self.assertEqual(len(set(amounts)), len(amounts), "open amounts must be distinct")
        edge_ref = "@" + [a for a in self.of("Account") if a["Name"] == "Edge Communications"][0]["attributes"]["referenceId"]
        edge = [o for o in opps if o["AccountId"] == edge_ref]
        slipping = [o for o in edge if not o["StageName"].startswith("Closed") and o["CloseDate"] < TODAY.isoformat()]
        self.assertGreaterEqual(len(slipping), 1)
        stages = {o["StageName"] for o in edge}
        self.assertIn("Closed Won", stages)
        self.assertIn("Closed Lost", stages)

    def test_activities(self):
        subtypes = {t["TaskSubtype"] for t in self.of("Task")}
        self.assertEqual(subtypes, {"Call", "Email", "Task"})
        overdue = [t for t in self.of("Task") if t["Status"] != "Completed" and t["ActivityDate"] < TODAY.isoformat()]
        self.assertGreaterEqual(len(overdue), 1)
        for t in self.of("Task"):
            self.assertTrue(t["WhoId"].startswith("@Con"))
        starts = [e["StartDateTime"] for e in self.of("Event")]
        now = TODAY.isoformat() + "T12:00:00.000+0000"
        self.assertTrue(any(s < now for s in starts))
        self.assertTrue(any(s > now for s in starts))

    def test_cases(self):
        cases = self.of("Case")
        open_cases = [c for c in cases if c["Status"] != "Closed"]
        self.assertTrue(any(c.get("Priority") == "High" for c in open_cases))
        self.assertTrue(any(c["Status"] == "Closed" for c in cases))
        self.assertGreaterEqual(len({c.get("Priority") for c in cases}), 3)

    def test_every_email_ends_in_example_com(self):
        emails = [v for _, _, r in self.records for k, v in r.items() if "Email" in k and isinstance(v, str)]
        self.assertTrue(emails)
        for e in emails:
            self.assertTrue(e.endswith("@example.com"), e)

    def test_phones_and_websites_are_made_up(self):
        for _, _, r in self.records:
            if "Phone" in r:
                self.assertRegex(r["Phone"], r"^\(555\) 010-\d{4}$")
            if "Website" in r:
                self.assertTrue(r["Website"].startswith("www.example.com"), r["Website"])

    def test_templates_hold_offsets_not_absolute_dates(self):
        for name in os.listdir(TEMPLATES):
            with open(os.path.join(TEMPLATES, name), encoding="utf-8") as f:
                text = f.read()
            self.assertIsNone(re.search(r"\d{4}-\d{2}-\d{2}", text), name)
        with open(os.path.join(TEMPLATES, "opportunities.json"), encoding="utf-8") as f:
            self.assertRegex(f.read(), r'"\$day:-?\d+"')

    def test_rendered_files_hold_dates_relative_to_today(self):
        for entry, name, r in self.records:
            for key, value in r.items():
                if isinstance(value, str):
                    self.assertFalse(value.startswith("$"), "%s %s unrendered" % (name, key))
        slipping = [o for o in self.of("Opportunity") if o["Name"] == "Edge Core Router Refresh"][0]
        self.assertEqual(slipping["CloseDate"], (TODAY - datetime.timedelta(days=12)).isoformat())
        self.assertEqual(self.of("Event")[0]["StartDateTime"], "2026-11-08T10:00:00.000+0000")


class TestSeedScript(unittest.TestCase):
    def test_script_is_executable_and_defaults_to_agent_probe(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        with open(SCRIPT, encoding="utf-8") as f:
            text = f.read()
        self.assertIn('"${SF_TARGET_ORG:-agent-probe}"', text)
        self.assertNotIn("experimental", text)
        self.assertEqual(text.count("sf data import tree"), 2)  # one comment, one call
        self.assertIn("mktemp -d", text)
        self.assertIn("Edge Communications", text)

    def fake_sf(self, tmp, query_json):
        log = os.path.join(tmp, "calls.log")
        fake = os.path.join(tmp, "sf")
        with open(fake, "w") as f:
            f.write(
                "#!/bin/sh\necho \"$@\" >> '%s'\n"
                "case \"$*\" in *'data query'*) echo '%s'; exit 0;; esac\n"
                "echo '{\"status\":0,\"result\":[1,2,3]}'\n" % (log, query_json)
            )
        os.chmod(fake, 0o755)
        return log

    def run_seed(self, query_json, org=None):
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp, True)
        log = self.fake_sf(tmp, query_json)
        env = dict(os.environ, PATH=tmp + os.pathsep + os.environ.get("PATH", ""))
        env.pop("SF_TARGET_ORG", None)
        if org:
            env["SF_TARGET_ORG"] = org
        result = subprocess.run(["bash", SCRIPT], env=env, capture_output=True, text=True, timeout=60)
        calls = []
        if os.path.exists(log):
            with open(log, encoding="utf-8") as f:
                calls = f.read().splitlines()
        return result, calls

    def test_stops_before_importing_when_edge_communications_exists(self):
        result, calls = self.run_seed('{"status":0,"result":{"totalSize":1,"records":[]}}')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already has an Account named Edge Communications", result.stdout)
        self.assertEqual(len(calls), 1)
        self.assertIn("data query", calls[0])
        self.assertIn("-o agent-probe", calls[0])

    def test_imports_once_into_the_target_org_when_empty(self):
        result, calls = self.run_seed('{"status":0,"result":{"totalSize":0,"records":[]}}', org="some-alias")
        self.assertEqual(result.returncode, 0, result.stdout)
        imports = [c for c in calls if "data import tree" in c]
        self.assertEqual(len(imports), 1)
        self.assertIn("-o some-alias", imports[0])
        self.assertIn("--json", imports[0])
        self.assertIn("3 records imported", result.stdout)

    def test_unknown_argument_is_refused_without_running_sf(self):
        result = subprocess.run(["bash", SCRIPT, "--bogus"], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
