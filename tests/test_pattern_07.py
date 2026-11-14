"""Pattern 07, trust by design (OPS-45): one screen, not a chapter.

fr2-design.md exempts page 07 from the full page shape. It keeps 'Why you can trust it' (the rule, in the same two
lines the chapters open their trust part with), 'Adopt it' (access in one step) and 'Limits and open items', plus two
parts of its own, 'The exceptions' and 'Failures'. It has no diagram and no screenshots; the failure behaviour is
shown in patterns 01 and 03, which it links. The shared rules in tests/pattern_shape.py still apply.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/07-trust-access-and-failure.md"
TITLE = "Trust by design"
PARTS = ("Why you can trust it", "Adopt it", "Limits and open items")
EXTRAS = ("The exceptions", "Failures")
MARKER = re.compile(r"//\s*system-context:")


class PatternSevenTrust(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_short_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title_is_trust_by_design(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), [TITLE])

    def test_has_no_diagram_and_no_screenshots(self):
        self.assertEqual(pattern_shape.mermaid_blocks(self.text), [])
        self.assertNotIn("![", self.text)

    def test_is_about_one_screen(self):
        self.assertLess(len(self.text.splitlines()), 90)

    def test_failures_link_the_chapters_where_they_are_shown(self):
        body = pattern_shape.part_body(self.text, "Failures")
        self.assertIn("01-route-gather-reduce.md", body)
        self.assertIn("03-hotkey-panel.md", body)

    def test_exceptions_table_names_every_system_context_class(self):
        body = pattern_shape.part_body(self.text, "The exceptions")
        classes = set()
        for path in (ROOT / "force-app/main/default/classes").glob("*.cls"):
            if path.name.endswith("Test.cls"):
                continue
            if MARKER.search(path.read_text(encoding="utf-8")):
                classes.add(path.stem)
        self.assertTrue(classes)
        for name in classes:
            self.assertIn("`%s`" % name, body, "no row for " + name)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        for card in ("BE-29", "BE-33", "FE-20", "FE-12"):
            self.assertIn(card, limits)

    def test_names_every_permission_set(self):
        adopt = pattern_shape.part_body(self.text, "Adopt it")
        for name in ("Customer_Summary_User", "Customer_Summary_Data_Access", "Customer_Summary_Outcome_Access",
                     "Customer_Summary_Agent_Access"):
            self.assertIn(name, adopt)

    def test_names_roles_not_people(self):
        self.assertNotIn("Ben", self.text)

    def test_ends_with_the_way_back(self):
        last = self.text.rstrip().splitlines()[-1]
        self.assertIn("../../README.md", last)
        self.assertIn("../ARCHITECTURE.md", last)


if __name__ == "__main__":
    unittest.main()
