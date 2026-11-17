"""docs/ARCHITECTURE.md under the Customer Summary names (OPS-49).

The page is the one map of the product: three ways in, one service behind each skill, the card contract, the trust
rule and the pattern list. This test checks what a reader and the other pages rely on:

- the pattern list is the index's (docs/patterns/README.md): every page once, in order, with its title and kind;
- chapter 00 is linked near the top and page 14 where the page names the embedded surface;
- the built-in panel and "Ask the agent" are not shown as a way in, and the agent is called optional;
- each diagram follows the theme page's snippets and rules (pattern_shape.check_diagrams);
- every system-context use named in docs/research/fr2-trust-rule.md appears on the page, and the Status table is
  linked without any run being called proven or not proven;
- the old names and the old prompt name are gone, and the user group holds no agent access.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape
from tests import test_pattern_pages as pages

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/ARCHITECTURE.md"
TRUST_RULE = ROOT / "docs/research/fr2-trust-rule.md"
LIST_PART = "The pattern pages"
KIND_WORDS = {"appendix": "appendix", "principles page": "principles page", "placeholder": "placeholder"}
LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")


def text():
    return PAGE.read_text(encoding="utf-8")


def prose():
    """The page without fenced blocks, so a diagram's words are not read as page text."""
    return pattern_shape.outside_fences(text())


def list_rows():
    """The pattern list: (number, title, file, kind) per table row of the list part."""
    rows = []
    for line in pattern_shape.part_body(text(), LIST_PART).splitlines():
        m = re.match(r"^\|\s*(\d\d)\s*\|\s*\[([^\]]+)\]\(patterns/(\d\d-[^)\s]+\.md)\)\s*\|\s*([^|]*?)\s*\|\s*$", line)
        if m:
            rows.append(m.groups())
    return rows


def trust_rule_uses():
    """(class, [members]) per row of the 'Every marker today' table in the BE-37 page."""
    body = TRUST_RULE.read_text(encoding="utf-8").split("## Every marker today", 1)[1].split("\n## ", 1)[0]
    uses = []
    for line in body.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 2 and cells[0].startswith("`"):
            cls = re.findall(r"`([^`]+)`", cells[0])[0]
            members = re.findall(r"`([^`]+)`", cells[1])[:1]
            uses.append((cls, members))
    return uses


class ThePatternList(unittest.TestCase):
    def test_every_page_in_the_index_is_listed_once_in_order_with_its_title(self):
        index = pages.index_rows()
        self.assertEqual(len(index), 15)
        rows = list_rows()
        self.assertEqual([r[2] for r in rows], [r[2] for r in index], "the same pages, in the index's order")
        for (number, title, name, _kind), (i_number, i_title, i_name, _i_kind, _line) in zip(rows, index):
            with self.subTest(page=name):
                self.assertEqual((number, title, name), (i_number, i_title, i_name))

    def test_each_page_is_linked_exactly_once_in_the_list_and_nowhere_else_but_00_and_14(self):
        links = [target for _label, target in LINK.findall(prose())]
        for _number, _title, name, _kind, _line in pages.index_rows():
            count = sum(1 for t in links if t.split("#")[0] == "patterns/" + name)
            with self.subTest(page=name):
                self.assertEqual(count, 2 if name[:2] in ("00", "14") else 1)

    def test_06_is_an_appendix_07_a_principles_page_and_14_a_placeholder(self):
        kinds = {r[0]: r[3] for r in list_rows()}
        self.assertEqual(kinds["06"], "appendix")
        self.assertEqual(kinds["07"], "principles page")
        self.assertEqual(kinds["14"], "placeholder")
        self.assertEqual(sum(1 for k in kinds.values() if k == "chapter"), 12)

    def test_chapter_00_is_linked_near_the_top(self):
        head = "\n".join(prose().splitlines()[:25])
        self.assertIn("(patterns/00-why-custom.md)", head)

    def test_page_14_is_linked_where_the_embedded_surface_is_named(self):
        before_list = prose().split("## " + LIST_PART, 1)[0]
        lines = [l for l in before_list.splitlines() if "(patterns/14-embedded-surface.md)" in l]
        self.assertEqual(len(lines), 1)
        self.assertRegex(lines[0].lower(), r"embedded")


class TheWaysIn(unittest.TestCase):
    def test_the_built_in_panel_and_ask_the_agent_are_not_a_way_in(self):
        low = prose().lower()
        for phrase in ("ask the agent", "built-in panel", "agentforce panel"):
            self.assertNotIn(phrase, low)
        part = pattern_shape.part_body(text(), "Three ways in")
        self.assertIn("optional", part.lower())
        self.assertRegex(part, r"(?i)not a way in")
        for way in ("compact window", "right rail", "MCP"):
            self.assertIn(way, part)

    def test_each_skill_has_one_service_and_every_way_in_calls_it(self):
        part = pattern_shape.part_body(text(), "One service behind each skill")
        for service in ("CustomerSummary", "DataExplorer", "CustomerSummaryActions"):
            self.assertIn("`%s`" % service, part)

    def test_the_summary_prompt_has_its_new_name_and_no_old_name_remains(self):
        self.assertIn("AgentPrompt_SummarySynthesis", text())
        for old in ("Account" + "Brief", "Account" + "_Brief", "Brief" + "Synthesis", "Account" + " Brief"):
            self.assertNotIn(old, text())

    def test_a_summary_makes_up_to_four_model_calls(self):
        self.assertRegex(text(), r"up to 4 model calls")


class TheDiagrams(unittest.TestCase):
    def test_there_is_one_component_diagram_and_one_sequence_diagram(self):
        blocks = pattern_shape.mermaid_blocks(text())
        starts = sorted(re.search(r"^(sequenceDiagram|flowchart)", b, re.M).group(1) for b in blocks)
        self.assertEqual(starts, ["flowchart", "sequenceDiagram"])

    def test_every_diagram_follows_the_theme_page_and_each_sequence_has_numbered_steps(self):
        pattern_shape.check_diagrams(self, text(), "ARCHITECTURE.md")


class TheTrustPart(unittest.TestCase):
    def test_the_part_opens_with_the_two_standard_lines(self):
        part = pattern_shape.part_body(text(), "Why you can trust it")
        self.assertIn("Runs as the signed-in user:", part)
        self.assertIn("System context:", part)

    def test_every_system_context_use_in_the_trust_rule_page_appears(self):
        part = pattern_shape.part_body(text(), "Why you can trust it")
        uses = trust_rule_uses()
        self.assertGreaterEqual(len(uses), 5)
        for cls, members in uses:
            with self.subTest(use=cls):
                self.assertIn("`%s`" % cls, part)
                for member in members:
                    self.assertIn(member, part)

    def test_status_is_linked_and_no_run_is_called_proven_or_not(self):
        self.assertIn("(../README.md#status)", text())
        self.assertIsNone(re.search(r"(?i)\bunproven\b|\bnot yet proven\b|\bproven\b", prose()))

    def test_the_user_group_holds_no_agent_access(self):
        group = (ROOT / "force-app/main/default/permissionsetgroups/Customer_Summary_User.permissionsetgroup-meta.xml")
        self.assertNotIn("Agent_Access", group.read_text(encoding="utf-8"))
        part = pattern_shape.part_body(text(), "Why you can trust it")
        self.assertRegex(part, r"(?i)no agent access")
        self.assertNotRegex(part, r"(?i)Customer_Summary_Agent_Access`[^.\n]*in the group")

    def test_no_card_file_is_linked_and_no_person_is_named(self):
        self.assertNotIn("agents/tasks", text())
        self.assertNotIn("/Users/", text())


if __name__ == "__main__":
    unittest.main()
