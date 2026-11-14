"""Pattern 03, the hotkey panel (OPS-40): the workbook chapter's shape and the facts it must keep.

The shared shape comes from tests/pattern_shape.py. This page has all eight fixed parts and no extra H2 of its own:
the card catalog ('The cards') is an H3 inside 'How it works', and 'What comes later' is an H3 inside 'Limits and
open items'. On top of the shared checks, this test checks that the numbered steps under each sequence diagram cover
its numbers, one to the last, each once.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/03-hotkey-panel.md"
PARTS = pattern_shape.fixed_parts()
EXTRAS = ()
PHASES = ("Open", "Ask through Apex", "Switch chats", "Driven by another component", "Close")
MODEL_ACCENT = "rect rgb(255, 214, 204)"
MODEL_BOX = "box rgb(255, 236, 230)"
ARROW = re.compile(r"^\s*[A-Za-z0-9_]+\s*(?:->>|-->>|->|-->|-x|--x|-\)|--\))\s*[A-Za-z0-9_]+")
OPENERS = re.compile(r"^\s*(rect|box|loop|alt|opt|par|critical|break)\b")
SEE_IT_IMAGES = (
    "../assets/fr2-compact-launcher.png",
    "../assets/fr2-compact-open.png",
    "../assets/hotkey-open.gif",
    "../assets/panel-sections-open.png",
)
CARD_TYPES = (
    "summary", "section", "text", "table", "metric", "recordList", "notice", "trail", "followups", "error", "record",
    "actionDraft", "actionResult",
)
FIXED_SENTENCE = "I couldn't finish that right now. Try again in a minute."


def h3_body(text, title):
    body = pattern_shape.outside_fences(text).split("\n### " + title + "\n", 1)
    if len(body) < 2:
        return ""
    return re.split(r"^#{2,3} ", body[1], flags=re.M)[0]


def sequences(text):
    return [b for b in pattern_shape.mermaid_blocks(text) if "sequenceDiagram" in b]


def steps_after_each_sequence(text):
    """For each sequence diagram, the numbered list right under it (up to the next fence or heading)."""
    out = []
    for match in re.finditer(r"^```mermaid[ \t]*\n(.*?)^```[ \t]*$", text, re.M | re.S):
        if "sequenceDiagram" not in match.group(1):
            continue
        rest = text[match.end():]
        stop = re.search(r"^(```|#{1,6} )", rest, re.M)
        out.append((match.group(1), rest[: stop.start()] if stop else rest))
    return out


def covered_numbers(steps):
    """Every diagram number a numbered item names: '(step 4)', '(steps 4 to 7)', '(steps 4 and 5)'."""
    numbers = []
    for item in re.findall(r"(?ms)^\d+\. (.*?)(?=^\d+\. |\Z)", steps):
        for a, b in re.findall(r"\bsteps? (\d+)(?: (?:to|and) (\d+))?\b", item):
            lo, hi = int(a), int(b or a)
            numbers.extend(range(lo, hi + 1))
    return numbers


class PatternThreeShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title_and_header_name_the_compact_window(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), ["Hotkey panel"])
        line = re.split(r"(?m)^# Hotkey panel\s*$", self.text, maxsplit=1)[1].strip().split("\n\n", 1)[0]
        self.assertIn("compact window", line)
        self.assertRegex(line, r"\b(rep|seller)\b", "the header line says what it gives a rep")

    def test_business_problem_is_the_button_nobody_reaches_for(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        for word in ("button", "one key", "snaps in", "hides", "past chats"):
            self.assertIn(word, part.lower(), "the business problem says " + word)
        self.assertIn("00-why-custom.md", part)
        self.assertEqual(self.text.count("Agentforce's own panel"), 1, "the standard option is named once")

    def test_architecture_in_a_few_steps_has_the_five_steps(self):
        part = pattern_shape.part_body(self.text, "The architecture in a few steps")
        steps = re.findall(r"(?m)^\d+\. \*\*([^*]+)\*\*", part)
        self.assertEqual([s.rstrip(".").lower() for s in steps], ["open", "ask", "answer", "switch or hide", "close"])

    def test_main_diagram_has_its_phases_layers_and_one_accent(self):
        seqs = sequences(self.text)
        self.assertGreaterEqual(len(seqs), 1)
        main = seqs[0]
        for phase in PHASES:
            self.assertRegex(main, r"(?m)^\s*Note over [^:]+: *%s\s*$" % re.escape(phase), "phase note " + phase)
        self.assertGreaterEqual(main.count("rect rgb("), len(PHASES) + 1, "a shaded rect per phase, and the accent")
        self.assertGreaterEqual(main.count("box "), 3, "a box per layer")
        self.assertIn(MODEL_ACCENT, main, "the model call carries the one accent")
        self.assertIn(MODEL_BOX, main, "the model layer has its own box")
        for name in ("CustomerSummaryPanelController", "CustomerSummaryHistory", "CustomerSummaryOpen"):
            self.assertIn(name, main)

    def test_every_sequence_diagram_is_well_formed(self):
        for n, code in enumerate(sequences(self.text), 1):
            lines = [line for line in code.splitlines() if line.strip()]
            opened = sum(1 for line in lines if OPENERS.match(line))
            closed = sum(1 for line in lines if line.strip() == "end")
            self.assertEqual(opened, closed, "diagram %d: every block is closed" % n)
            for line in lines:
                if ARROW.match(line):
                    self.assertIn(":", line, "diagram %d: a message with no colon: %r" % (n, line))
                    label = line.split(":", 1)[1]
                    self.assertNotIn(";", label, "diagram %d: a semicolon ends a Mermaid statement: %r" % (n, line))
                    self.assertNotIn("#", label, "diagram %d: a hash starts an entity in Mermaid: %r" % (n, line))

    def test_numbered_steps_under_each_diagram_cover_its_numbers(self):
        pairs = steps_after_each_sequence(self.text)
        self.assertEqual(len(pairs), len(sequences(self.text)))
        for n, (code, steps) in enumerate(pairs, 1):
            arrows = sum(1 for line in code.splitlines() if ARROW.match(line))
            self.assertGreater(arrows, 0, "diagram %d has messages" % n)
            self.assertEqual(sorted(covered_numbers(steps)), list(range(1, arrows + 1)),
                             "diagram %d: the steps under it cover 1 to %d, each once" % (n, arrows))

    def test_no_ask_the_agent_and_no_plain_text_only(self):
        self.assertNotIn("Ask the agent", self.text)
        self.assertNotIn("plain text only", self.text.lower())

    def test_card_catalog_lists_what_was_built(self):
        part = h3_body(self.text, "The cards")
        self.assertTrue(part, "an H3 'The cards' inside How it works")
        self.assertIn("The cards", pattern_shape.headings(pattern_shape.part_body(self.text, "How it works"), 3))
        rows = [line for line in part.splitlines() if line.startswith("|") and not line.startswith("| ---")]
        self.assertEqual([c.strip() for c in rows[0].split("|")[1:4]], ["Card", "When it shows", "Text fallback"])
        first_cells = [row.split("|")[1].strip() for row in rows[1:]]
        for card in CARD_TYPES:
            self.assertIn("`%s`" % card, first_cells, "the catalog has a row for " + card)
        for card in ("choice", "timeline", "comparison"):
            self.assertIn("`%s`" % card, part, "the catalog says what happens to " + card)

    def test_trust_and_scale_carry_the_failure_behaviour_and_link_their_evidence(self):
        trust = pattern_shape.part_body(self.text, "Why you can trust it")
        scale = pattern_shape.part_body(self.text, "How it scales")
        for name, body in (("Why you can trust it", trust), ("How it scales", scale)):
            self.assertIn(FIXED_SENTENCE, body, name + " quotes the fixed sentence")
            bullets = re.findall(r"(?ms)^- (.*?)(?=^- |\Z)", body)
            self.assertTrue(bullets, name + " has claims")
            for bullet in bullets:
                self.assertIn("](", bullet, "%s: each claim links its evidence: %r" % (name, bullet[:60]))
        self.assertRegex(trust, r"(?i)never (as )?markup")
        self.assertIn("../research/fr2-panel-proof.md", trust)
        self.assertIn("customerSummaryConversation.test.js", trust)
        system = re.search(r"(?m)^System context:.*?(?=\n\n)", trust, re.S).group(0)
        for use in ("prompt settings", "session rows", "outcome"):
            self.assertIn(use, system, "the System context line names " + use)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)proven", self.text))
        self.assertNotIn("[!WARNING]", self.text)
        self.assertIn("../../README.md#status", self.text)

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        for card in ("FE-5", "FE-16", "P1", "P2", "P10"):
            self.assertIn(card, limits)
        self.assertIn("No card yet", limits)
        self.assertIn("not been render-checked", limits)
        for closed in ("N4", "N5", "row 6", "14f"):
            self.assertNotIn(closed, limits, "closed by FE-12, FE-13 or FE-22: " + closed)

    def test_what_comes_later_is_the_top_of_fe17_and_not_built(self):
        later = h3_body(self.text, "What comes later")
        self.assertTrue(later, "an H3 'What comes later' inside Limits and open items")
        self.assertIn("What comes later", pattern_shape.headings(pattern_shape.part_body(self.text, "Limits and open items"), 3))
        self.assertIn("not built", later.lower())
        for rank in ("P1", "P2", "P3", "P4"):
            self.assertIn(rank, later)
        self.assertIn("../research/fr2-panel-later.md", later)

    def test_see_it_keeps_its_images(self):
        part = pattern_shape.part_body(self.text, "See it")
        for image in SEE_IT_IMAGES:
            self.assertIn("](%s)" % image, part)

    def test_uses_customer_summary_names_outside_the_kept_alt_text(self):
        prose = "\n".join(line for line in self.text.splitlines() if not line.startswith("!["))
        self.assertNotIn("Account" + " Brief", prose, "the old product name, built from parts for test_fr2_rename")
        self.assertIn("Customer Summary", prose)

    def test_adopt_it_grants_access_in_the_shared_words(self):
        part = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn("Grant access: assign the permission set group `Customer_Summary_User`.", part)

    def test_names_roles_not_people(self):
        self.assertNotIn("Ben", self.text)

    def test_ends_with_the_way_back(self):
        last = self.text.rstrip().splitlines()[-1]
        self.assertIn("../../README.md", last)
        self.assertIn("../ARCHITECTURE.md", last)


if __name__ == "__main__":
    unittest.main()
