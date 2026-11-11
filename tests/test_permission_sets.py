"""Static checks for the Account Brief permission sets.

Account_Brief_Agent_Access grants agent access only. Account_Brief_Data_Access grants
the Apex classes and the Account_Brief_Session__c memory object.
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERMSETS = ROOT / "force-app/main/default/permissionsets"
CLASSES = ROOT / "force-app/main/default/classes"
AGENT_SET = PERMSETS / "Account_Brief_Agent_Access.permissionset-meta.xml"
DATA_SET = PERMSETS / "Account_Brief_Data_Access.permissionset-meta.xml"
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

    def test_agent_set_names_the_account_brief_agent(self):
        self.assertIn("Account_Brief", AGENT_SET.read_text(encoding="utf-8"))


class TestDataAccessSet(unittest.TestCase):
    def setUp(self):
        self.root = load(DATA_SET)

    def test_data_set_grants_session_object_without_delete_or_view_all(self):
        perms = {text_of(p, "object"): p for p in children(self.root, "objectPermissions")}
        session = perms["Account_Brief_Session__c"]
        self.assertEqual(text_of(session, "allowRead"), "true")
        self.assertEqual(text_of(session, "allowCreate"), "true")
        self.assertEqual(text_of(session, "allowEdit"), "true")
        for flag in ("allowDelete", "viewAllRecords", "modifyAllRecords"):
            self.assertNotEqual(text_of(session, flag), "true", flag)

    def test_data_set_never_grants_delete_view_all_or_modify_all(self):
        for flag in ("allowDelete", "viewAllRecords", "modifyAllRecords"):
            for perm in children(self.root, "objectPermissions"):
                self.assertNotEqual(text_of(perm, flag), "true", flag)

    def test_every_non_test_apex_class_is_granted(self):
        granted = {text_of(c, "apexClass") for c in children(self.root, "classAccesses")}
        names = {p.name[: -len(".cls")] for p in CLASSES.glob("*.cls")}
        required = {n for n in names if not n.endswith("Test")}
        self.assertTrue(required, "no non-test classes found")
        self.assertEqual(sorted(required - granted), [])


if __name__ == "__main__":
    unittest.main()
