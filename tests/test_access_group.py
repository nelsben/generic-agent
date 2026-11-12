"""Static checks for the Account Brief permission set group.

Account_Brief_User holds exactly the two custom permission sets. The standard Agentforce
user set is named in the setup step, not added to the group.
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = ROOT / "force-app/main/default/permissionsetgroups"
PERMSETS = ROOT / "force-app/main/default/permissionsets"
GROUP = GROUPS / "Account_Brief_User.permissionsetgroup-meta.xml"
NS = {"p": "http://soap.sforce.com/2006/04/metadata"}
EXPECTED = {"Account_Brief_Agent_Access", "Account_Brief_Data_Access"}


class TestAccessGroup(unittest.TestCase):
    def setUp(self):
        self.assertTrue(GROUP.is_file(), "group file is missing")
        self.root = ET.parse(GROUP).getroot()

    def test_group_names_exactly_the_two_sets(self):
        names = [e.text for e in self.root.findall("p:permissionSets", NS)]
        self.assertEqual(sorted(names), sorted(EXPECTED))

    def test_both_set_files_exist(self):
        for name in EXPECTED:
            self.assertTrue((PERMSETS / (name + ".permissionset-meta.xml")).is_file(), name)

    def test_group_has_label_and_description(self):
        self.assertTrue(self.root.findtext("p:label", namespaces=NS))
        self.assertTrue(self.root.findtext("p:description", namespaces=NS))


if __name__ == "__main__":
    unittest.main()
