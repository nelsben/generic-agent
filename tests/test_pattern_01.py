"""Pattern 01, route, gather, reduce (OPS-38): the workbook chapter's shape and the facts it must keep.

The shared shape comes from tests/pattern_shape.py. This page adds one part of its own, 'When something fails'
(the failure behaviour moved here from page 07). The guide-word check reads a comma-separated list from the
PATTERN_GUIDE_WORDS environment variable and skips when it is unset, so the list is never committed.
"""
import os
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/01-route-gather-reduce.md"
ENGINE = ROOT / "force-app/main/default/classes/CustomerSummary.cls"
PARTS = pattern_shape.fixed_parts()
EXTRAS = ("When something fails",)


def registry_keys():
    text = ENGINE.read_text(encoding="utf-8")
    block = text.split("registry = new List<Source>{", 1)[1].split("};", 1)[0]
    return re.findall(r"new Source\('([^']+)'", block)


def h3_body(text, title):
    body = text.split("\n### " + title + "\n", 1)
    if len(body) < 2:
        return ""
    return re.split(r"^#{2,3} ", body[1], flags=re.M)[0]


class PatternOneShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title_is_route_gather_reduce(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), ["Route, gather, reduce"])

    def test_page_has_a_main_sequence_diagram(self):
        sequences = [b for b in pattern_shape.mermaid_blocks(self.text) if "sequenceDiagram" in b]
        self.assertGreaterEqual(len(sequences), 1)
        main = sequences[0]
        for phase in ("Route", "Gather", "Pre-reduce", "Reduce", "Remember"):
            self.assertRegex(main, r"(?m)^\s*Note over .*: *%s\b" % re.escape(phase), "phase note " + phase)
        self.assertGreaterEqual(main.count("rect "), 5, "one shaded rect per phase")
        self.assertGreaterEqual(main.count("box "), 2, "a box per layer")

    def test_reduction_table_lists_every_registry_key(self):
        keys = registry_keys()
        self.assertEqual(len(keys), 7, "the engine's registry")
        part = h3_body(self.text, "The reduction structure")
        self.assertTrue(part, "an H3 'The reduction structure' inside How it works")
        rows = [line for line in part.splitlines() if line.startswith("|")]
        first_cells = [row.split("|")[1].strip() for row in rows]
        for key in keys:
            self.assertIn("`%s`" % key, first_cells, "the reduction table has a row for " + key)

    def test_industry_examples_are_marked_as_examples(self):
        for word in ("case history", "order history"):
            self.assertIn(word, self.text.lower())
        self.assertRegex(self.text, r"(?i)example[s]?, not shipped code")

    def test_names_the_new_synthesis_prompt(self):
        self.assertIn("AgentPrompt_SummarySynthesis", self.text)
        self.assertNotIn("AgentPrompt_BriefSynthesis", self.text)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)

    def test_failure_part_links_both_captures_and_their_tests(self):
        part = pattern_shape.part_body(self.text, "When something fails")
        self.assertIn("../assets/not-found.png", part)
        self.assertIn("../assets/ambiguous.png", part)
        self.assertIn("CustomerSummaryResolverTest.cls", part)
        self.assertIn("CustomerSummaryTest.cls", part)

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        for card in ("BE-29", "FE-5", "OPS-34"):
            self.assertIn(card, limits)

    def test_cites_the_reviewed_build_only_in_generic_terms(self):
        words = [w.strip() for w in os.environ.get("PATTERN_GUIDE_WORDS", "").split(",") if w.strip()]
        if not words:
            self.skipTest("PATTERN_GUIDE_WORDS is unset")
        lower = self.text.lower()
        for word in words:
            self.assertNotIn(word.lower(), lower)


if __name__ == "__main__":
    unittest.main()
