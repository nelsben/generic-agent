"""Static checks for the Customer Summary permission sets.

Customer_Summary_Agent_Access grants agent access only. Customer_Summary_Data_Access grants
the Apex entry-point classes and read-only access to the Customer_Summary_Session__c memory object.
Customer_Summary_Outcome_Access grants Read and Create on Customer_Outcome__c and the Account read its
master-detail needs, and no access to the outcome's text fields (BE-35, F79).
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERMSETS = ROOT / "force-app/main/default/permissionsets"
CLASSES = ROOT / "force-app/main/default/classes"
AGENT_SET = PERMSETS / "Customer_Summary_Agent_Access.permissionset-meta.xml"
DATA_SET = PERMSETS / "Customer_Summary_Data_Access.permissionset-meta.xml"
OUTCOME_SET = PERMSETS / "Customer_Summary_Outcome_Access.permissionset-meta.xml"
OUTCOME_TEXT_FIELDS = ("Title__c", "Headline__c", "Body__c", "Sentiment_Reason__c")
GROUP = ROOT / "force-app/main/default/permissionsetgroups/Customer_Summary_User.permissionsetgroup-meta.xml"
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
        for name in ("Account__c", "Title__c", "Started__c", "Last_Activity__c", "Last_Brief_At__c", "Turn_Count__c", "Turns_JSON__c"):
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
            "CustomerOutcomeSaveAnswer",
            "CustomerOutcomes",
            "CustomerSummaryActionCommitAction",
            "CustomerSummaryActionDraftAction",
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

    def test_data_set_grants_nothing_on_outcomes_or_accounts(self):
        objects = {text_of(p, "object") for p in children(self.root, "objectPermissions")}
        self.assertNotIn("Customer_Outcome__c", objects)
        self.assertNotIn("Account", objects)
        fields = [text_of(f, "field") for f in children(self.root, "fieldPermissions")]
        self.assertEqual([f for f in fields if f.startswith("Customer_Outcome__c.")], [])

    def test_agent_set_does_not_grant_brand_settings(self):
        self.assertNotIn("BrandSettings", AGENT_SET.read_text(encoding="utf-8"))


class TestOutcomeAccessSet(unittest.TestCase):
    def setUp(self):
        self.root = load(OUTCOME_SET)
        self.objects = {text_of(p, "object"): p for p in children(self.root, "objectPermissions")}

    def test_outcome_set_reads_and_creates_outcomes_only(self):
        outcome = self.objects["Customer_Outcome__c"]
        self.assertEqual(text_of(outcome, "allowRead"), "true")
        self.assertEqual(text_of(outcome, "allowCreate"), "true")
        for flag in ("allowEdit", "allowDelete", "viewAllRecords", "modifyAllRecords"):
            self.assertNotEqual(text_of(outcome, flag), "true", flag)

    def test_outcome_set_only_reads_accounts(self):
        account = self.objects["Account"]
        self.assertEqual(text_of(account, "allowRead"), "true")
        for flag in ("allowCreate", "allowEdit", "allowDelete", "viewAllRecords", "modifyAllRecords"):
            self.assertNotEqual(text_of(account, flag), "true", flag)
        self.assertEqual(sorted(self.objects), ["Account", "Customer_Outcome__c"])

    def test_outcome_set_gives_no_access_to_the_text_fields(self):
        fields = {text_of(f, "field"): f for f in children(self.root, "fieldPermissions")}
        for name in OUTCOME_TEXT_FIELDS:
            self.assertNotIn("Customer_Outcome__c." + name, fields, name)
        for name in ("Outcome_Type__c", "Skill__c", "Sentiment_Label__c", "Expires__c"):
            self.assertEqual(text_of(fields["Customer_Outcome__c." + name], "readable"), "true", name)

    def test_outcome_set_grants_no_class_and_no_other_object(self):
        self.assertEqual(children(self.root, "classAccesses"), [])
        fields = [text_of(f, "field") for f in children(self.root, "fieldPermissions")]
        self.assertEqual([f for f in fields if not f.startswith("Customer_Outcome__c.")], [])


class TestUserGroup(unittest.TestCase):
    def test_group_holds_the_data_and_outcome_sets_and_nothing_else(self):
        root = load(GROUP)
        sets = sorted(p.text for p in children(root, "permissionSets"))
        self.assertEqual(sets, ["Customer_Summary_Data_Access", "Customer_Summary_Outcome_Access"])


if __name__ == "__main__":
    unittest.main()
