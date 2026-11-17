"""Pattern 02, ask anything (OPS-39): the workbook chapter's shape and the facts it must keep.

The shared shape comes from tests/pattern_shape.py. This page has all eight fixed parts and no extra H2 of its own:
the follow-up diagram is an H3 inside 'How it works', and the scale-out path is an H3 inside 'How it scales'. On top of
the shared checks, this test checks the operating principle line, that the numbered steps under each sequence diagram
cover its numbers, one to the last, each once, and that "any object" is never claimed as built.
"""
import os
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/02-ask-anything-explorer.md"
PARTS = pattern_shape.fixed_parts()
EXTRAS = ()
PRINCIPLE = "A follow-up is never a new build"
PHASES = ("Ask", "Plan and check", "Run in the rep's access", "Answer", "Drill")
FOLLOW_UP_PHASES = ("Summary", "Follow-up")
MODEL_ACCENT = "rect rgba(244, 114, 82, 0.22)"
ARROW = re.compile(r"^\s*[A-Za-z0-9_]+\s*(?:->>|-->>|->|-->|-x|--x|-\)|--\))\s*[A-Za-z0-9_]+")
OPENERS = re.compile(r"^\s*(rect|box|loop|alt|opt|par|critical|break)\b")
SEE_IT_IMAGES = (
    "../assets/explore-answer.png",
    "../assets/explore-drill.gif",
    "../assets/drill-view.png",
)
SCALE_OUT_CARDS = ("BE-41", "BE-42", "BE-43", "BE-44", "BE-45")


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


def sentences(text):
    return re.split(r"(?<=[.!?])\s+|\n\s*\n|\n(?=\s*(?:[-*]|\d+\.|\|))", text)


class PatternTwoShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title_and_header_say_what_it_gives_a_rep(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), ["Ask anything"])
        line = re.split(r"(?m)^# Ask anything\s*$", self.text, maxsplit=1)[1].strip().split("\n\n", 1)[0]
        self.assertRegex(line, r"\b(rep|seller)\b", "the header line says what it gives a rep")

    def test_business_problem_is_a_flow_per_follow_up(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        lower = part.lower()
        for word in ("summary", "flow", "follow-up", "build cycles", "hours", "by hand", "own words", "no new build"):
            self.assertIn(word, lower, "the business problem says " + word)
        self.assertIn("a production Agentforce build we reviewed", part)

    def test_business_problem_states_the_operating_principle(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        self.assertRegex(part, r"(?m)^\s*(?:[-*]\s+)?\*\*[^*\n]*%s[^*\n]*\*\*" % re.escape(PRINCIPLE),
                         "the principle is a bold lead-in inside the business problem")
        self.assertIn("../plans/fr2-design.md#operating-principles", part)
        self.assertNotIn(PRINCIPLE, pattern_shape.headings(self.text, 2))

    def test_architecture_in_a_few_steps_has_the_six_steps(self):
        part = pattern_shape.part_body(self.text, "The architecture in a few steps")
        steps = re.findall(r"(?m)^\d+\. \*\*([^*]+)\*\*", part)
        self.assertEqual([s.rstrip(".").lower() for s in steps],
                         ["plan", "check", "run in the rep's access", "correct", "answer", "drill"])

    def test_main_diagram_has_its_phases_layers_and_one_accent(self):
        seqs = sequences(self.text)
        self.assertGreaterEqual(len(seqs), 2, "the main diagram and the follow-up diagram")
        main = seqs[0]
        for phase in PHASES:
            self.assertRegex(main, r"(?m)^\s*Note over [^:]+: *%s\s*$" % re.escape(phase), "phase note " + phase)
        self.assertGreaterEqual(main.count("rect rgba("), len(PHASES) + 1, "a tinted rect per phase, and the accent")
        self.assertNotIn("box ", main, "no box: the lifeline names say which layer is which")
        self.assertIn("AI model", main, "the model is its own lifeline")
        self.assertIn(MODEL_ACCENT, main, "the model calls carry the one accent")
        steps = steps_after_each_sequence(self.text)[0][1]
        for name in ("DataExplorer", "ExplorePlan", "ExploreCatalog", "ExploreQuery", "AgentLlm", "CustomerSummaryPanelController"):
            self.assertIn(name, steps, "the steps under the diagram name " + name)

    def test_follow_up_diagram_carries_the_summary_context_in(self):
        self.assertIn("A follow-up after a summary", pattern_shape.headings(pattern_shape.part_body(self.text, "How it works"), 3))
        follow = sequences(self.text)[1]
        for phase in FOLLOW_UP_PHASES:
            self.assertRegex(follow, r"(?m)^\s*Note over [^:]+: *%s\s*$" % re.escape(phase), "phase note " + phase)
        self.assertIn(MODEL_ACCENT, follow)
        steps = steps_after_each_sequence(self.text)[1][1]
        self.assertIn("lastBrief", steps)
        self.assertIn("summary's records", follow)
        self.assertIn("The summary's records", steps)

    def test_every_sequence_diagram_starts_with_autonumber(self):
        seqs = sequences(self.text)
        self.assertTrue(seqs, "the page has sequence diagrams")
        for n, code in enumerate(seqs, 1):
            lines = [line.strip() for line in code.splitlines() if line.strip()]
            at = lines.index("sequenceDiagram")
            self.assertEqual(lines[at + 1 : at + 2], ["autonumber"], "diagram %d starts with autonumber" % n)

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
                    for bad in (";", "#", "{", "}", "<", ">"):
                        self.assertNotIn(bad, label, "diagram %d: %r in a message: %r" % (n, bad, line))

    def test_numbered_steps_under_each_diagram_cover_its_numbers(self):
        pairs = steps_after_each_sequence(self.text)
        self.assertEqual(len(pairs), len(sequences(self.text)))
        for n, (code, steps) in enumerate(pairs, 1):
            arrows = sum(1 for line in code.splitlines() if ARROW.match(line))
            self.assertGreater(arrows, 0, "diagram %d has messages" % n)
            self.assertEqual(sorted(covered_numbers(steps)), list(range(1, arrows + 1)),
                             "diagram %d: the steps under it cover 1 to %d, each once" % (n, arrows))

    def test_how_it_scales_marks_the_scale_out_path_as_not_built(self):
        scale = pattern_shape.part_body(self.text, "How it scales")
        self.assertIn("../research/fr2-follow-ups.md", scale, "the live follow-up result")
        self.assertIn("18 of 20", scale)
        later = h3_body(self.text, "The scale-out path")
        self.assertIn("The scale-out path", pattern_shape.headings(scale, 3))
        self.assertIn("not yet built", later.lower())
        self.assertIn("../research/fr2-explorer-scale.md", later)
        for card in SCALE_OUT_CARDS:
            self.assertIn(card, later, "the scale-out path names " + card)
        for bullet in re.findall(r"(?ms)^- (.*?)(?=^- |^### |\Z)", scale.split("\n### ", 1)[0]):
            self.assertIn("](", bullet, "How it scales: each claim links its evidence: %r" % bullet[:60])

    def test_any_object_is_never_claimed_as_built(self):
        later = h3_body(self.text, "The scale-out path")
        rest = self.text.replace(later, "")
        for phrase in ("any object", "any combination"):
            self.assertNotIn(phrase, rest.lower(), "%r only in the not-built scale-out path" % phrase)

    def test_trust_opens_with_the_two_lines_and_links_its_evidence(self):
        trust = pattern_shape.part_body(self.text, "Why you can trust it")
        first = [p for p in trust.strip().split("\n\n") if p.strip()]
        self.assertTrue(first[0].startswith("Runs as the signed-in user:"))
        self.assertTrue(first[1].startswith("System context:"))
        system = first[1]
        for use in ("prompt settings", "session rows", "outcome"):
            self.assertIn(use, system, "the System context line names " + use)
        self.assertIn("../../tests/test_trust_rule.py", system)
        bullets = re.findall(r"(?ms)^- (.*?)(?=^- |\Z)", trust)
        self.assertTrue(bullets, "Why you can trust it has claims")
        for bullet in bullets:
            self.assertIn("](", bullet, "Why you can trust it: each claim links its evidence: %r" % bullet[:60])
        for name in ("ExploreQueryTest", "DataExplorerTest", "ExploreCatalogTest"):
            self.assertIn(name, trust)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)proven", self.text))
        self.assertNotIn("[!WARNING]", self.text)
        self.assertIn("../../README.md#status", self.text)

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        for card in ("BE-43", "FE-5", "OPS-44"):
            self.assertIn(card, limits)
        self.assertIn("No card yet", limits)
        self.assertIn("not been render-checked", limits)
        for bullet in re.findall(r"(?ms)^- (.*?)(?=^- |\Z)", limits):
            self.assertRegex(bullet, r"\b(?:[A-Z]{2,3}-\d+|No card yet)\b", "each limit names its card: %r" % bullet[:60])

    def test_see_it_keeps_its_images(self):
        part = pattern_shape.part_body(self.text, "See it")
        for image in SEE_IT_IMAGES:
            self.assertIn("](%s)" % image, part)

    def test_uses_customer_summary_names_and_no_retired_button(self):
        prose = "\n".join(line for line in self.text.splitlines() if not line.startswith("!["))
        self.assertNotIn("Account" + " Brief", prose, "the old product name, built from parts for test_fr2_rename")
        self.assertIn("Customer Summary", prose)
        self.assertNotIn("Ask the agent", self.text)

    def test_adopt_it_grants_access_in_the_shared_words(self):
        part = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn("Grant access: assign the permission set group `Customer_Summary_User`.", part)

    def test_names_roles_not_people_and_no_org_names(self):
        self.assertNotIn("Ben", self.text)
        self.assertNotIn("agent-probe", self.text)
        self.assertIsNone(re.search(r"[\w.-]+@[\w-]+\.[\w.]+", self.text), "no email address")

    def test_cites_the_reviewed_build_only_in_generic_terms(self):
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
