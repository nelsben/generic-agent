"""Static checks for the Account_Brief Agent Script bundle and its sf agent test spec."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "force-app/main/default/aiAuthoringBundles/Account_Brief"
SPEC = ROOT / "tests/agent/Account_Brief-testSpec.yaml"

BUNDLE_META = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">'
    "<bundleType>AGENT</bundleType></AiAuthoringBundle>"
)


class TestAccountBriefBundle(unittest.TestCase):
    def test_bundle_meta_has_no_target(self):
        text = (BUNDLE / "Account_Brief.bundle-meta.xml").read_text(encoding="utf-8")
        self.assertNotIn("<target>", text)
        self.assertEqual(re.sub(r">\s+<", "><", text.strip()), BUNDLE_META)

    def test_agent_names_all_three_apex_targets(self):
        text = (BUNDLE / "Account_Brief.agent").read_text(encoding="utf-8")
        for target in ("AccountBriefResolver", "AccountBriefGetAction", "ExploreAction"):
            self.assertIn('"apex://%s"' % target, text)

    def test_agent_config(self):
        text = (BUNDLE / "Account_Brief.agent").read_text(encoding="utf-8")
        self.assertIn('developer_name: "Account_Brief"', text)
        self.assertIn('agent_type: "AgentforceEmployeeAgent"', text)
        for name in ("briefed_account_id", "briefed_account_name", "last_status"):
            self.assertIn(name + ": mutable string", text)

    def test_spec_has_eight_utterances(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"^\s*-?\s*utterance:", text, re.M)), 8)
        self.assertIn("subjectType: AGENT", text)
        self.assertIn("subjectName: Account_Brief", text)


if __name__ == "__main__":
    unittest.main()
