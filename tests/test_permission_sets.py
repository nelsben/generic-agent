"""Static checks for the Customer Summary permission sets.

Customer_Summary_Agent_Access grants agent access only. Customer_Summary_Data_Access grants
the Apex entry-point classes and read-only access to the Customer_Summary_Session__c memory object.
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERMSETS = ROOT / "force-app/main/default/permissionsets"
CLASSES = ROOT / "force-app/main/default/classes"
AGENT_SET = PERMSETS / "Customer_Summary_Agent_Access.permissionset-meta.xml"
DATA_SET = PERMSETS / "Customer_Summary_Data_Access.permissionset-meta.xml"
NS = {"p": "http://soap.sforce.com/2006/04/metadata"}


def load(path):
    return ET.parse(path).getroot()


def children(root, tag):
    return root.findall("p:" + tag, NS)


def text_of(element, tag):
    found = element.find("p:" + tag, NS)
    return found.text if found is not None else None


class TestAgentAccessSet(unittest.TestCase):
    def setUp(self):
        self.root = load(AGENT_SET)

    def test_agent_set_has_no_class_or_object_access(self):
        self.assertEqual(children(self.root, "classAccesses"), [])
        self.assertEqual(children(self.root, "objectPermissions"), [])

    def test_agent_set_names_the_account_summary_agent(self):
        self.assertIn("Customer_Summary", AGENT_SET.read_text(encoding="utf-8"))


class TestDataAccessSet(unittest.TestCase):
    def setUp(self):
        self.root = load(DATA_SET)

    def test_data_set_grants_session_object_without_delete_or_view_all(self):
        perms = {text_of(p, "object"): p for p in children(self.root, "objectPermissions")}
        session = perms["Customer_Summary_Session__c"]
        self.assertEqual(text_of(session, "allowRead"), "true")
        for flag in ("allowCreate", "allowEdit", "allowDelete", "viewAllRecords", "modifyAllRecords"):
            self.assertNotEqual(text_of(session, flag), "true", flag)

    def test_data_set_reads_every_session_field_the_history_door_lists(self):
        fields = {text_of(f, "field"): f for f in children(self.root, "fieldPermissions")}
        for name in ("Account__c", "Title__c", "Started__c", "Last_Activity__c", "Turn_Count__c", "Turns_JSON__c"):
            perm = fields["Customer_Summary_Session__c." + name]
            self.assertEqual(text_of(perm, "readable"), "true", name)
            self.assertEqual(text_of(perm, "editable"), "false", name)

    def test_data_set_never_grants_delete_view_all_or_modify_all(self):
        for flag in ("allowDelete", "viewAllRecords", "modifyAllRecords"):
            for perm in children(self.root, "objectPermissions"):
                self.assertNotEqual(text_of(perm, flag), "true", flag)

    def test_only_the_entry_point_classes_are_granted(self):
        granted = {text_of(c, "apexClass") for c in children(self.root, "classAccesses")}
        entry_points = {
            "BrandSettings",
            "CustomerSummaryContext",
            "CustomerSummaryGetAction",
            "CustomerSummaryHistory",
            "CustomerSummaryMemory",
            "CustomerSummaryPanelController",
            "CustomerSummaryResolver",
            "ExploreAction",
        }
        self.assertEqual(sorted(granted), sorted(entry_points))
        self.assertEqual([n for n in granted if n.endswith("Test")], [])

    def test_data_set_grants_read_on_the_brand_settings_type(self):
        types = {text_of(t, "name"): text_of(t, "enabled") for t in children(self.root, "customMetadataTypeAccesses")}
        self.assertEqual(types, {"Brand_Setting__mdt": "true"})

    def test_agent_set_does_not_grant_brand_settings(self):
        self.assertNotIn("BrandSettings", AGENT_SET.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
