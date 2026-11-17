"""Pattern 05, memory and customer history (OPS-43): the workbook chapter's shape and the facts it must keep.

The shared shape comes from tests/pattern_shape.py. This page has all eight fixed parts and two extra H2 parts of its
own, between 'The business problem' and 'The architecture in a few steps': 'Two memories' (the conversation and the
customer outcomes) and "Agentforce's Agent Memory" (what the platform's feature covers and what our outcomes keep).
On top of the shared checks, this test checks that the numbered steps under each sequence diagram cover its numbers,
one to the last, each once, that the agent-session measurement is given hedged as it was recorded, and that every
limit says where it stands.
"""
import os
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/05-conversation-memory.md"
PARTS = pattern_shape.fixed_parts()
TWO_MEMORIES = "Two memories"
AGENT_MEMORY = "Agentforce's Agent Memory"
EXTRAS = (TWO_MEMORIES, AGENT_MEMORY)
PHASES = ("Write", "Read", "Reuse")
MODEL_ACCENT = "rect rgba(244, 114, 82, 0.22)"
ARROW = re.compile(r"^\s*[A-Za-z0-9_]+\s*(?:->>|-->>|->|-->|-x|--x|-\)|--\))\s*[A-Za-z0-9_]+")
OPENERS = re.compile(r"^\s*(rect|box|loop|alt|opt|par|critical|break)\b")
FE19_CAPTURES = ("fr2-history-timeline.png", "fr2-history-sentiment.png")


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


def bullets(body):
    return re.findall(r"(?ms)^- (.*?)(?=^- |^### |\Z)", body)


class PatternFiveShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_the_extra_parts_sit_after_the_business_problem(self):
        h2 = pattern_shape.headings(self.text, 2)
        self.assertEqual(h2[:4], ["The business problem", TWO_MEMORIES, AGENT_MEMORY, "The architecture in a few steps"])

    def test_title_and_header_say_the_product_remembers(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), ["Memory and customer history"])
        line = re.split(r"(?m)^# Memory and customer history\s*$", self.text, maxsplit=1)[1].strip().split("\n\n", 1)[0]
        self.assertIn("remembers", line)
        self.assertRegex(line, r"\b(rep|seller)\b", "the header line says what it gives a rep")

    def test_business_problem_is_the_summary_paid_for_and_forgotten(self):
        part = pattern_shape.part_body(self.text, "The business problem").lower()
        for word in ("paid for", "forgotten", "repeat", "trending"):
            self.assertIn(word, part, "the business problem says " + word)
        self.assertIn("../plans/fr2-design.md#operating-principles", part)

    def test_two_memories_names_the_conversation_and_customer_outcomes(self):
        part = pattern_shape.part_body(self.text, TWO_MEMORIES)
        lower = part.lower()
        self.assertIn("customer outcome", lower)
        self.assertIn("the conversation", lower)
        for word in ("own", "session", "account", "type", "author"):
            self.assertIn(word, lower, "Two memories says " + word)
        self.assertIn("Customer_Summary_Session__c", part)
        self.assertIn("Customer_Outcome__c", part)

    def test_agent_memory_section_is_fair_and_does_not_claim_a_replacement(self):
        part = pattern_shape.part_body(self.text, AGENT_MEMORY)
        self.assertTrue(part.strip(), "an Agent Memory section exists")
        lower = part.lower()
        self.assertIn("../research/fr2-agent-memory.md", part)
        self.assertIn("per user and per agent", lower)
        self.assertIn("not keyed to an account", lower)
        for surface in ("panel", "rail", "mcp"):
            self.assertIn(surface, lower, "Agent Memory says it never reaches the " + surface)
        rows = [line for line in part.splitlines() if line.startswith("|") and not line.startswith("| ---")]
        self.assertGreaterEqual(len(rows), 4, "a header and a row per need, from BE-34's table")
        self.assertIsNone(re.search(r"(?i)\breplaces? (BE-26|BE-35)", part), "never says Agent Memory replaces ours")

    def test_agent_memory_section_gives_the_basis_of_never_reaching_our_surfaces(self):
        part = " ".join(pattern_shape.part_body(self.text, AGENT_MEMORY).split()).lower()
        self.assertIn("reasoned from the design", part)
        self.assertIn("not tested", part)

    def test_limits_carry_every_open_row_of_the_agent_memory_and_sentiment_research(self):
        limits = " ".join(pattern_shape.part_body(self.text, "Limits and open items").split())
        lower = limits.lower()
        for phrase in ("time-based expiry", "licence", "cost", "rest agent api", "reasoned from the design",
                       "not tested", "model-call counts", "e2e"):
            self.assertIn(phrase, lower, "Limits names " + phrase)

    def test_architecture_in_a_few_steps_has_the_five_steps(self):
        part = pattern_shape.part_body(self.text, "The architecture in a few steps")
        steps = re.findall(r"(?m)^\d+\. \*\*([^*]+)\*\*", part)
        self.assertEqual([s.rstrip(".").lower() for s in steps],
                         ["a skill finishes", "it records an outcome", "the next conversation starts from it",
                          "the next summary says what changed", "the rail shows the timeline and the trend"])

    def test_main_diagram_has_write_read_and_reuse_and_one_accent(self):
        seqs = sequences(self.text)
        self.assertGreaterEqual(len(seqs), 1)
        main = seqs[0]
        for phase in PHASES:
            self.assertRegex(main, r"(?m)^\s*Note over [^:]+: *%s\s*$" % re.escape(phase), "phase note " + phase)
        self.assertGreaterEqual(main.count("rect rgba("), len(PHASES) + 1, "a shaded rect per phase, and the accent")
        self.assertNotIn("box ", main, "no box: the lifeline names say which layer is which")
        self.assertIn(MODEL_ACCENT, main, "the model calls carry the one accent")
        for lifeline in ("Conversation memory", "Customer outcomes", "AI model"):
            self.assertIn(" as " + lifeline, main, "a lifeline for " + lifeline)
        steps = steps_after_each_sequence(self.text)[0][1]
        for name in ("CustomerSummaryMemory", "CustomerOutcomes", "CustomerSummaryHistory"):
            self.assertIn(name, steps, "the steps under the diagram name " + name)

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

    def test_see_it_names_fe19s_captures_and_leaves_their_links_to_ops52(self):
        part = pattern_shape.part_body(self.text, "See it")
        for capture in FE19_CAPTURES:
            self.assertIn(capture, part, "See it names " + capture)
            self.assertNotIn("](../assets/" + capture + ")", self.text, "the image link is OPS-52's")
        self.assertIn("OPS-52", part)

    def test_trust_opens_with_the_two_lines_and_names_both_stores(self):
        trust = pattern_shape.part_body(self.text, "Why you can trust it")
        first = [p for p in trust.strip().split("\n\n") if p.strip()]
        self.assertTrue(first[0].startswith("Runs as the signed-in user:"))
        self.assertTrue(first[1].startswith("System context:"))
        system = first[1]
        for use in ("session rows", "outcome", "purge"):
            self.assertIn(use, system, "the System context line names " + use)
        self.assertIn("../../tests/test_trust_rule.py", system)
        claims = bullets(trust)
        self.assertTrue(claims, "Why you can trust it has claims")
        for claim in claims:
            self.assertIn("](", claim, "Why you can trust it: each claim links its evidence: %r" % claim[:60])
        for name in ("CustomerSummaryMemoryTest", "CustomerOutcomesTest", "CustomerSummaryHistoryTest"):
            self.assertIn(name, trust)

    def test_how_it_scales_has_retention_the_purge_job_and_the_cost(self):
        scale = pattern_shape.part_body(self.text, "How it scales")
        lower = scale.lower()
        for word in ("forever", "two years", "purge", "2 kb"):
            self.assertIn(word, lower, "How it scales says " + word)
        self.assertIn("../research/fr2-customer-outcomes.md", scale)
        for claim in bullets(scale):
            self.assertIn("](", claim, "How it scales: each claim links its evidence: %r" % claim[:60])

    def test_sentiment_is_labels_only(self):
        self.assertIn("labels only", self.text.lower())
        self.assertIn("../research/fr2-sentiment.md", self.text)

    def test_adopt_it_grants_access_and_names_the_record_page_target(self):
        part = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn("Grant access: assign the permission set group `Customer_Summary_User`.", part)
        lower = part.lower()
        self.assertIn("record page", lower)
        self.assertIn("swap guide", lower)
        self.assertIn("quick start", lower)

    def test_the_agent_session_measurement_is_given_hedged(self):
        limits = " ".join(pattern_shape.part_body(self.text, "Limits and open items").split())
        self.assertNotIn("has not been measured", self.text)
        self.assertIn("1, 5 and 15", limits)
        self.assertIn("30", limits)
        self.assertIn("one sample", limits.lower())
        self.assertIn("idle time", limits.lower(), "the cause is hedged: idle time is not separated from the rest")
        self.assertIn("../research/fr2-agent-memory.md", limits)

    def test_every_limit_says_where_it_stands(self):
        self.assertNotIn("agents/tasks", self.text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        claims = bullets(limits)
        self.assertGreaterEqual(len(claims), 10, "every item rechecked")
        for claim in claims:
            self.assertRegex(claim, r"\b(?:Closed by|Open|Accepted|No card yet|Parked)\b",
                             "each limit says closed, open, accepted or no card yet: %r" % claim[:60])
            self.assertRegex(claim, r"\b(?:[A-Z]{2,3}-\d+|Q\d+|No card yet|Accepted)\b",
                             "each limit names its card, its question or that it is accepted: %r" % claim[:60])
        for card in ("BE-26", "BE-35", "BE-34", "BE-36", "BE-49", "FE-23", "BE-28"):
            self.assertIn(card, limits)
        self.assertIn("not been render-checked", limits)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)proven", self.text))
        self.assertNotIn("[!WARNING]", self.text)
        self.assertIn("../../README.md#status", self.text)

    def test_uses_customer_summary_names(self):
        prose = "\n".join(line for line in self.text.splitlines() if not line.startswith("!["))
        self.assertNotIn("Account" + " Brief", prose, "the old product name, built from parts for test_fr2_rename")
        self.assertIn("Customer Summary", prose)
        self.assertNotIn("Ask the agent", self.text)

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
