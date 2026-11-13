"""Static checks for the Customer Summary permission set group.

Customer_Summary_User holds only the data-access set: reps reach the product through our
surfaces, not the agent. Customer_Summary_Agent_Access stays in the repo, outside the group,
for a team that adds the agent to a channel later.
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = ROOT / "force-app/main/default/permissionsetgroups"
PERMSETS = ROOT / "force-app/main/default/permissionsets"
GROUP = GROUPS / "Customer_Summary_User.permissionsetgroup-meta.xml"
NS = {"p": "http://soap.sforce.com/2006/04/metadata"}
EXPECTED = {"Customer_Summary_Data_Access"}


class TestAccessGroup(unittest.TestCase):
    def setUp(self):
        self.assertTrue(GROUP.is_file(), "group file is missing")
        self.root = ET.parse(GROUP).getroot()

    def test_group_holds_only_the_data_access_set(self):
        names = [e.text for e in self.root.findall("p:permissionSets", NS)]
        self.assertEqual(sorted(names), sorted(EXPECTED))

    def test_agent_access_set_stays_in_the_repo_but_not_in_the_group(self):
        self.assertTrue((PERMSETS / "Customer_Summary_Agent_Access.permissionset-meta.xml").is_file())
        names = [e.text for e in self.root.findall("p:permissionSets", NS)]
        self.assertNotIn("Customer_Summary_Agent_Access", names)

    def test_set_files_exist(self):
        for name in EXPECTED:
            self.assertTrue((PERMSETS / (name + ".permissionset-meta.xml")).is_file(), name)

    def test_group_has_label_and_description(self):
        self.assertTrue(self.root.findtext("p:label", namespaces=NS))
        self.assertTrue(self.root.findtext("p:description", namespaces=NS))


if __name__ == "__main__":
    unittest.main()
