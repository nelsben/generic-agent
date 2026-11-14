"""Pattern 06, the optional Agentforce agent (OPS-44): a short appendix, not a way in.

fr2-design.md exempts page 06 from the full page shape, so it passes only the fixed parts it has to the shared
helper in tests/pattern_shape.py, plus one part of its own, 'When you would add it'. The rest of the shape rules
still apply: an H1 with no number, no proof status on the page (it links the README's Status table), roles not
people, and limits that never link a card file. Its own checks: the appendix title, and that it no longer
promotes the built-in Agentforce panel or the custom panel's old agent button.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/06-agent-routing-and-verbatim-relay.md"
QUICK_START_CHANGE = ROOT / "docs/research/fr2-quick-start-change.md"
TESTING_CENTER = ROOT / "docs/research/fr2-testing-center.md"
TITLE = "Appendix: the Agentforce agent (optional)"
PARTS = ("How it works", "Adopt it", "Limits and open items")
EXTRAS = ("When you would add it",)
BUILT_IN_PANEL_SHOTS = ("agent-brief.png", "agent-explore.png", "panel-ask-agent.png")


class PatternSixAppendix(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_appendix_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title_is_the_appendix_title(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), [TITLE])

    def test_never_promotes_the_old_agent_button(self):
        self.assertNotIn("ask the agent", self.text.lower())

    def test_never_links_the_built_in_panel_screenshots(self):
        for name in BUILT_IN_PANEL_SHOTS:
            self.assertNotIn(name, self.text)

    def test_has_one_sequence_diagram_with_model_calls_in_the_accent(self):
        sequences = [b for b in pattern_shape.mermaid_blocks(self.text) if "sequenceDiagram" in b]
        self.assertEqual(len(sequences), 1)
        main = sequences[0]
        self.assertIn("rect rgb(255, 214, 204)", main, "model calls use the one coral accent")
        self.assertGreaterEqual(main.count("box "), 3, "a box per layer")
        for phase in ("Route", "Resolve, then summarize", "Explore", "Relay"):
            self.assertRegex(main, r"(?m)^\s*Note over .*: *%s\b" % re.escape(phase), "phase note " + phase)

    def test_says_our_surfaces_and_mcp_do_not_use_it(self):
        self.assertRegex(self.text, r"None of our surfaces[^.]*MCP[^.]*use it")

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)

    def test_adopt_steps_link_the_lifecycle_and_the_agent_permission_set(self):
        adopt = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn("08-test-and-release-lifecycle.md", adopt)
        self.assertIn("Customer_Summary_Agent_Access", adopt)
        self.assertIn("sf agent publish authoring-bundle", adopt)
        self.assertIn("sf agent activate", adopt)

    def test_testing_center_suite_is_claimed_only_with_its_research(self):
        if not TESTING_CENTER.is_file():
            self.assertNotIn("fr2-testing-center.md", self.text)
            self.assertNotRegex(self.text, r"(?i)suite is part of this build")

    def test_limits_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        self.assertTrue(pattern_shape.part_body(self.text, "Limits and open items").strip())

    def test_ends_with_the_way_back(self):
        last = self.text.rstrip().splitlines()[-1]
        self.assertIn("../ARCHITECTURE.md", last)
        self.assertIn("../../README.md", last)

    def test_quick_start_change_is_written_for_ops_36(self):
        self.assertTrue(QUICK_START_CHANGE.is_file(), "docs/research/fr2-quick-start-change.md")
        text = QUICK_START_CHANGE.read_text(encoding="utf-8")
        self.assertIn("06-agent-routing-and-verbatim-relay.md#adopt-it", text)
        self.assertIn("sf agent publish authoring-bundle", text)


if __name__ == "__main__":
    unittest.main()
