"""Static checks for the Customer Summary Lightning app, its utility bar and visibility.

The app hosts the customerSummaryPanel LWC as an eager utility bar item; the item mounts the
compact window and its launcher at the bottom right of the page (FE-13), so its own utility panel
only holds a short note. The data-access permission set makes the app visible. XML parsing only,
no org needed.
"""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT = ROOT / "force-app/main/default"
APP = DEFAULT / "applications/Customer_Summary.app-meta.xml"
BAR = DEFAULT / "flexipages/Customer_Summary_UtilityBar.flexipage-meta.xml"
DATA_SET = DEFAULT / "permissionsets/Customer_Summary_Data_Access.permissionset-meta.xml"
AGENT_SET = DEFAULT / "permissionsets/Customer_Summary_Agent_Access.permissionset-meta.xml"
EXPAND = DEFAULT / "messageChannels/CustomerSummaryExpand.messageChannel-meta.xml"
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}


def load(path):
    return ET.parse(path).getroot()


def texts(root, tag):
    return [e.text for e in root.findall("m:" + tag, NS)]


def panel_instance():
    root = load(BAR)
    found = [
        c
        for c in root.iter("{%s}componentInstance" % NS["m"])
        if c.findtext("m:componentName", namespaces=NS) == "customerSummaryPanel"
    ]
    return found


def panel_props():
    instance = panel_instance()[0]
    return {
        p.findtext("m:name", namespaces=NS): p.findtext("m:value", namespaces=NS)
        for p in instance.findall("m:componentInstanceProperties", NS)
    }


class TestUtilityBarFlexipage(unittest.TestCase):
    def test_flexipage_is_a_utility_bar(self):
        self.assertEqual(load(BAR).findtext("m:type", namespaces=NS), "UtilityBar")

    def test_flexipage_has_exactly_one_item_which_is_the_panel(self):
        items = list(load(BAR).iter("{%s}itemInstances" % NS["m"]))
        self.assertEqual(len(items), 1)
        self.assertEqual(len(panel_instance()), 1)

    def test_panel_utility_item_properties(self):
        props = panel_props()
        self.assertEqual(props["label"], "Customer Summary")
        self.assertEqual(props["width"], "340")
        # The panel holds only a note and an Open button: the window itself is on the page.
        self.assertEqual(props["height"], "200")
        # Eager, so the hotkey and the launcher exist before anyone opens the utility.
        self.assertEqual(props["eager"], "true")
        self.assertTrue(props["icon"])

    def test_panel_compact_window_properties(self):
        props = panel_props()
        self.assertEqual(props["corner"], "right")
        # Expand stays off until the rail (FE-15) ships.
        self.assertEqual(props["expandEnabled"], "false")


class TestExpandChannel(unittest.TestCase):
    def test_expand_channel_carries_the_session_and_record(self):
        root = load(EXPAND)
        self.assertEqual(root.findtext("m:isExposed", namespaces=NS), "true")
        fields = [f.findtext("m:fieldName", namespaces=NS) for f in root.findall("m:lightningMessageFields", NS)]
        self.assertEqual(sorted(fields), ["recordId", "sessionId"])


class TestApp(unittest.TestCase):
    def setUp(self):
        self.root = load(APP)

    def test_app_is_a_lightning_standard_nav_large_app(self):
        self.assertEqual(self.root.findtext("m:label", namespaces=NS), "Customer Summary")
        self.assertEqual(self.root.findtext("m:uiType", namespaces=NS), "Lightning")
        self.assertEqual(self.root.findtext("m:navType", namespaces=NS), "Standard")
        self.assertEqual(texts(self.root, "formFactors"), ["Large"])

    def test_app_has_no_brand_block(self):
        # 14f: an app brand block is static metadata with a ContentAsset logo; it cannot follow the
        # runtime brand settings, so the brand is shown in the launcher only.
        self.assertIsNone(self.root.find("m:brand", NS))

    def test_app_references_the_utility_bar(self):
        self.assertEqual(texts(self.root, "utilityBar"), ["Customer_Summary_UtilityBar"])

    def test_app_tabs(self):
        self.assertEqual(
            texts(self.root, "tabs"),
            [
                "standard-home",
                "standard-Account",
                "standard-Opportunity",
                "standard-Contact",
                "standard-Case",
            ],
        )


class TestAppVisibility(unittest.TestCase):
    def test_data_access_set_makes_the_app_visible_not_default(self):
        visibilities = load(DATA_SET).findall("m:applicationVisibilities", NS)
        self.assertEqual(len(visibilities), 1)
        entry = visibilities[0]
        self.assertEqual(entry.findtext("m:application", namespaces=NS), "Customer_Summary")
        self.assertEqual(entry.findtext("m:visible", namespaces=NS), "true")
        # PermissionSetApplicationVisibility has no default element: absent means not default.
        self.assertIsNone(entry.find("m:default", NS))

    def test_agent_access_set_has_no_app_visibility(self):
        self.assertEqual(load(AGENT_SET).findall("m:applicationVisibilities", NS), [])


if __name__ == "__main__":
    unittest.main()
