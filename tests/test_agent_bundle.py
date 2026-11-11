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

    def test_spec_uses_no_missing_account(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertNotIn("Acme Corp", text)
        self.assertIn("Zzqxv Nonexistent Holdings", text)
        self.assertIn("001000000000000AAA", text)
        # A comment at the top of the spec says the account name must exist in the target org.
        head = text.split("name:", 1)[0]
        self.assertRegex(head, r"(?m)^#.*must exist in the target org")

    def test_off_topic_case_names_an_expected_topic(self):
        text = SPEC.read_text(encoding="utf-8")
        case = text.split("What is the weather in Paris today?", 1)[1]
        self.assertRegex(case, r"expectedTopic:\s*\S+")

    def test_agent_routes_by_named_account_and_relays_verbatim(self):
        text = (BUNDLE / "Account_Brief.agent").read_text(encoding="utf-8")
        router = text.split("subagent account_brief:", 1)[0]
        self.assertIn("names one specific account", router)
        self.assertIn("do not name one account", router)
        for sub in text.split("subagent ")[1:]:
            self.assertIn("nothing else", sub)
            self.assertIn("closing question", sub)
        self.assertIn("userQuestion", text.split("subagent explore:", 1)[0])


if __name__ == "__main__":
    unittest.main()
