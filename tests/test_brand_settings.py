"""Static checks for the brand settings (BE-24, FR2 rows F05, F06, F08, F09).

One Brand_Setting__mdt record, Default, holds the agent name, company name, logo, colours, fonts and tone.
The panel sets the fr2-design.md theme variables from it and its stylesheet reads only those; the swap
guide (pattern page 10) tells a seller what to change.
"""
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "force-app/main/default"
TYPE_DIR = APP / "objects/Brand_Setting__mdt"
RECORD = APP / "customMetadata/Brand_Setting.Default.md-meta.xml"
PANEL = APP / "lwc/customerSummaryPanel"
# FE-12: the panel is the frame and the conversation renders inside it; the theme is read across both.
CONVERSATION = APP / "lwc/customerSummaryConversation"
LOGO = APP / "staticresources/BrandLogo.resource"
GUIDE = ROOT / "docs/patterns/10-brand-and-theming.md"
NS = {"p": "http://soap.sforce.com/2006/04/metadata"}
XSI_NIL = "{http://www.w3.org/2001/XMLSchema-instance}nil"

FIELDS = {
    "Agent_Name__c": "Text",
    "Company_Name__c": "Text",
    "Logo_Resource__c": "Text",
    "Primary_Color__c": "Text",
    "Accent_Color__c": "Text",
    "Surface_Color__c": "Text",
    "Ink_Color__c": "Text",
    "Display_Font__c": "Text",
    "Body_Font__c": "Text",
    "Tone__c": "LongTextArea",
}
THEME_VARIABLES = [
    "--cs-color-primary",
    "--cs-color-accent",
    "--cs-color-surface",
    "--cs-color-ink",
    "--cs-font-display",
    "--cs-font-body",
    "--cs-radius",
]
HEX = re.compile(r"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$")


def record_values():
    root = ET.parse(RECORD).getroot()
    out = {}
    for v in root.findall("p:values", NS):
        value = v.find("p:value", NS)
        out[v.find("p:field", NS).text] = None if value.get(XSI_NIL) == "true" else value.text
    return root, out


class TestBrandSettingType(unittest.TestCase):
    def test_type_is_public_with_labels(self):
        root = ET.parse(TYPE_DIR / "Brand_Setting__mdt.object-meta.xml").getroot()
        self.assertEqual(root.find("p:visibility", NS).text, "Public")
        self.assertEqual(root.find("p:pluralLabel", NS).text, "Brand Settings")
        for forbidden in ("sharingModel", "nameField", "deploymentStatus"):
            self.assertIsNone(root.find("p:" + forbidden, NS), forbidden)

    def test_every_field_exists_with_its_type(self):
        found = {}
        for path in (TYPE_DIR / "fields").glob("*.field-meta.xml"):
            root = ET.parse(path).getroot()
            found[root.find("p:fullName", NS).text] = root.find("p:type", NS).text
        self.assertEqual(found, FIELDS)


class TestDefaultRecord(unittest.TestCase):
    def setUp(self):
        self.root, self.values = record_values()

    def test_one_record_named_default(self):
        records = sorted(p.name for p in (APP / "customMetadata").glob("Brand_Setting.*.md-meta.xml"))
        self.assertEqual(records, ["Brand_Setting.Default.md-meta.xml"])
        self.assertEqual(self.root.find("p:label", NS).text, "Default")

    def test_default_names(self):
        self.assertEqual(self.values["Agent_Name__c"], "Customer Summary")
        self.assertEqual(self.values["Company_Name__c"], "Your Company")
        self.assertEqual(self.values["Logo_Resource__c"], "BrandLogo")

    def test_default_colours_are_hex(self):
        for field in ("Primary_Color__c", "Accent_Color__c", "Surface_Color__c", "Ink_Color__c"):
            self.assertRegex(self.values[field], HEX, field)

    def test_default_tone_is_one_short_plain_warm_concise_line(self):
        tone = self.values["Tone__c"]
        self.assertNotIn("\n", tone)
        self.assertLessEqual(len(tone), 255)
        for word in ("plain", "warm", "concise"):
            self.assertIn(word, tone.lower())

    def test_every_field_has_a_value_or_is_blank_on_purpose(self):
        self.assertEqual(set(self.values), set(FIELDS))


class TestDefaultLogo(unittest.TestCase):
    def test_logo_is_an_svg_with_no_text(self):
        root = ET.parse(LOGO).getroot()
        self.assertEqual(root.tag, "{http://www.w3.org/2000/svg}svg")
        self.assertEqual(root.findall(".//{http://www.w3.org/2000/svg}text"), [])
        meta = (APP / "staticresources/BrandLogo.resource-meta.xml").read_text(encoding="utf-8")
        self.assertIn("<contentType>image/svg+xml</contentType>", meta)


class TestPanelTheme(unittest.TestCase):
    def setUp(self):
        def read(name):
            return "\n".join(
                (folder / (folder.name + name)).read_text(encoding="utf-8") for folder in (PANEL, CONVERSATION)
            )

        self.css = read(".css")
        self.css_code = re.sub(r"/\*.*?\*/", "", self.css, flags=re.S)
        self.js = read(".js")
        self.html = read(".html")

    def test_the_panel_sets_every_theme_variable(self):
        for name in THEME_VARIABLES:
            self.assertIn("'" + name + "'", self.js, name)

    def test_the_stylesheet_reads_every_theme_variable_with_a_fallback(self):
        for name in THEME_VARIABLES:
            self.assertRegex(self.css_code, r"var\(" + re.escape(name) + r",\s*[^)]+\)", name)

    def test_the_stylesheet_reads_no_other_variable_but_the_error_colour(self):
        read = set(re.findall(r"var\((--[\w-]+)", self.css_code))
        self.assertEqual(read - set(THEME_VARIABLES), {"--slds-g-color-error-1"})

    def test_every_colour_and_font_in_the_stylesheet_is_a_variable_fallback(self):
        without_vars = re.sub(r"var\(--[\w-]+,\s*[^)]*\)", "", self.css_code)
        self.assertEqual(re.findall(r"#[0-9A-Fa-f]{3,8}\b", without_vars), [])
        self.assertEqual(re.findall(r"\brgba?\(|\bhsla?\(", without_vars), [])
        fonts = [f.strip() for f in re.findall(r"font-family:([^;]*);", without_vars) if f.strip()]
        self.assertEqual(fonts, [], "font-family only through --cs-font-*")

    def test_the_markup_names_no_agent_or_company(self):
        for name in ("Customer Summary", "Your Company", "Northwind"):
            self.assertNotIn(name, self.html)
            self.assertNotIn("'" + name + "'", self.js)


class TestSwapGuide(unittest.TestCase):
    def setUp(self):
        self.text = GUIDE.read_text(encoding="utf-8")

    def test_names_the_record_file_and_the_setup_path(self):
        self.assertIn("force-app/main/default/customMetadata/Brand_Setting.Default.md-meta.xml", self.text)
        self.assertIn("Custom Metadata Types", self.text)

    def test_names_every_field(self):
        for field in FIELDS:
            self.assertIn(field, self.text)

    def test_covers_the_logo_the_utility_label_the_redeploy_and_tone(self):
        for needle in ("BrandLogo", "utility item", "Label", "sf project deploy validate", "BE-28"):
            self.assertIn(needle, self.text)

    def test_shows_the_before_and_after_pair(self):
        for name in ("brand-swap-before.png", "brand-swap-after.png"):
            self.assertIn("../assets/" + name, self.text)
            self.assertTrue((ROOT / "docs/assets" / name).is_file(), name)
            self.assertIn("`" + name + "`", (ROOT / "docs/assets/MANIFEST.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
