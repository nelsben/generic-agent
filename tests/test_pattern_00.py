"""Pattern 00, why custom (OPS-41): the chapter's shape and the facts it must keep.

The shared shape comes from tests/pattern_shape.py. Page 00 is exempt from 'See it', 'Why you can trust it', 'How it
scales' and 'Adopt it' (fr2-design.md 'Pattern page shape'), and adds three parts of its own. The guide-word check
reads a comma-separated list from the PATTERN_GUIDE_WORDS environment variable and skips when it is unset, so the
list is never committed.
"""
import os
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/00-why-custom.md"
EXEMPT = ("See it", "Why you can trust it", "How it scales", "Adopt it")
PARTS = [p for p in pattern_shape.fixed_parts() if p not in EXEMPT]
EXTRAS = ("What was measured, and how to say it", "What changes for a team", "When the standard chat fits")
LIMITS = "../research/fr2-standard-limits.md"
CORAL = "rect rgb(255, 214, 204)"


class PatternZeroShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape_less_its_exemptions(self):
        self.assertEqual(len(PARTS), 4, "page 00 keeps four of the eight fixed parts")
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_header_says_it_is_agentforce_with_its_own_skin(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), ["Why custom"])
        line = re.split(r"(?m)^# Why custom\s*$", self.text, maxsplit=1)[1].strip().split("\n\n", 1)[0]
        for word in ("Agentforce", "models", "trust layer", "skin"):
            self.assertIn(word, line, "the header line names " + word)

    def test_two_sequence_diagrams_each_with_a_model_call_in_the_accent(self):
        sequences = [b for b in pattern_shape.mermaid_blocks(self.text) if "sequenceDiagram" in b]
        self.assertEqual(len(sequences), 2, "the standard path and ours")
        for n, code in enumerate(sequences, 1):
            self.assertIn(CORAL, code, "diagram %d marks its model calls in coral" % n)
            self.assertGreaterEqual(code.count("rect "), 4, "diagram %d has phase blocks" % n)
            self.assertRegex(code, r"(?m)^\s*Note over ", "diagram %d names its phases" % n)
        self.assertIn("Lightning type", sequences[0], "the standard path shows when a card renders")
        self.assertIn("AnswerCard", sequences[1], "our path builds the typed card contract")

    def test_every_number_in_the_business_problem_has_a_link_on_its_line(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        self.assertTrue(part.strip(), "the business problem part has a body")
        for line in part.splitlines():
            if re.search(r"\d", line):
                self.assertRegex(line, r"\]\([^)\s]+\)", "a number with no link on its line: %r" % line)

    def test_business_problem_carries_the_measured_figures(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        for figure in ("6 of 6", "5,900", "36 of 47", "13 to 33", "5 to 9"):
            self.assertIn(figure, part)
        self.assertIn(LIMITS, part)
        self.assertIn("02-ask-anything-explorer.md", part, "follow-ups link pattern 02")

    def test_measured_part_bounds_the_relay_and_claims_no_ceiling(self):
        part = pattern_shape.part_body(self.text, "What was measured, and how to say it")
        for figure in ("5,811", "18 of 18", "not measured"):
            self.assertIn(figure, part)
        self.assertIn(LIMITS, part)
        self.assertIn("unproven", part, "what is said about the launcher is marked unproven")

    def test_mcp_client_output_is_stated_from_the_contract_page(self):
        part = pattern_shape.part_body(self.text, "How it works")
        self.assertIn("../research/fr2-card-contract-apex.md", part)
        for word in ("`answer`", "`cards`", "JSON text", "60,000"):
            self.assertIn(word, part)

    def test_why_not_coworker_is_a_paragraph_that_links_the_spike_and_quotes_no_terms(self):
        self.assertIn("../research/fr2-coworker-spike.md", self.text)
        self.assertNotIn("Coworker", "".join(pattern_shape.headings(self.text, 2)), "no H2 of its own")
        self.assertIn("F83", self.text)
        for word in ("$", "licen", "edition", "price", "per user"):
            self.assertNotIn(word, self.text.lower(), "no price, licence or edition: " + word)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        self.assertIn("No card yet", limits)
        for card in ("BE-31", "BE-28"):
            self.assertIn(card, limits)

    def test_links_the_right_rail_page(self):
        self.assertIn("12-right-rail.md", self.text)

    def test_names_the_rail_in_the_say_column(self):
        measured = pattern_shape.part_body(self.text, "What was measured, and how to say it")
        rows = [line for line in measured.splitlines() if line.startswith("| ") and not line.startswith("| ---")]
        self.assertGreater(len(rows), 1, "the Say / Do not say table")
        says = [row.split("|")[1].lower() for row in rows[1:]]
        self.assertTrue(any("rail" in say for say in says), "no Say cell names the rail")
        for say in says:
            for claim in ("push", "sticky", "screen reader"):
                self.assertNotIn(claim, say, "the Say column claims %r: %r" % (claim, say))

    def test_never_calls_the_rail_planned_or_fe_15_work(self):
        sentences = re.split(r"(?<=[.!?])\s+|\n\s*\n|\n(?=\s*(?:[-*]|\d+\.|\|))", self.text)
        for sentence in sentences:
            if "rail" in sentence.lower():
                self.assertNotRegex(sentence, r"(?i)\bplanned\b|FE-15", "the rail is built: %r" % sentence)

    def test_claims_no_object_or_combination_beyond_pattern_02(self):
        for phrase in ("any object", "any combination"):
            self.assertNotIn(phrase, self.text.lower())

    def test_names_roles_not_people(self):
        self.assertNotIn("Ben", self.text)

    def test_cites_the_reviewed_build_only_in_generic_terms(self):
        self.assertIn("a production Agentforce build we reviewed", self.text)
        words = [w.strip() for w in os.environ.get("PATTERN_GUIDE_WORDS", "").split(",") if w.strip()]
        if not words:
            self.skipTest("PATTERN_GUIDE_WORDS is unset")
        lower = self.text.lower()
        for word in words:
            self.assertNotIn(word.lower(), lower)

    def test_ends_with_the_way_back(self):
        last = self.text.rstrip().splitlines()[-1]
        self.assertIn("../../README.md", last)
        self.assertIn("../ARCHITECTURE.md", last)


if __name__ == "__main__":
    unittest.main()
