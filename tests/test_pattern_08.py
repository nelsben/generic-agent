"""Pattern 08, testing an AI feature on Salesforce (OPS-47): the workbook chapter on testing, for readers new to it.

The shared shape comes from tests/pattern_shape.py. This page has every fixed part and adds two of its own between
'How it works' and 'See it': 'Each kind of test, with a first test to copy' and 'Turn a bad answer into a test'. Its
own checks: a Testing Center section and a first-test section for each kind of test, the ladder diagram with a shaded
block per track and the one accent for model calls, the publish and activate steps page 06 links, a 'What the tests
prove' table whose files exist, and the Testing Center suite claimed only when its script exists.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/08-test-and-release-lifecycle.md"
AGENT_TEST = ROOT / "scripts/agent-test.sh"
TESTING_CENTER = ROOT / "docs/research/fr2-testing-center.md"
TITLE = "Testing an AI feature on Salesforce"
PARTS = pattern_shape.fixed_parts()
FIRST_TESTS = "Each kind of test, with a first test to copy"
BAD_ANSWER = "Turn a bad answer into a test"
EXTRAS = (FIRST_TESTS, BAD_ANSWER)
KINDS = ("Apex tests", "Jest for components", "Playwright in a real browser", "Testing Center for the agent")
AREAS = ("Summary", "Explorer", "Panel", "Memory", "Access")
ACCENT = "rect rgba(244, 114, 82, 0.22)"
GRANT = "Grant access: assign the permission set group `Customer_Summary_User`."
PUBLIC_DOCS = (
    "developer.salesforce.com/docs/ai/agentforce/guide/testing-api-get-started.html",
    "developer.salesforce.com/docs/platform/salesforce-code-analyzer/",
    "developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_apex_run_test.html",
    "developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-test.html",
)


def h3_body(text, title):
    body = text.split("\n### " + title + "\n", 1)
    if len(body) < 2:
        return ""
    return re.split(r"^#{2,3} ", body[1], flags=re.M)[0]


class PatternEightShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_title(self):
        self.assertEqual(pattern_shape.headings(self.text, 1), [TITLE])

    def test_ladder_diagram_has_a_block_per_track_and_the_accent_for_model_calls(self):
        sequences = [b for b in pattern_shape.mermaid_blocks(self.text) if "sequenceDiagram" in b]
        self.assertGreaterEqual(len(sequences), 1)
        main = sequences[0]
        for track in ("Every change", "The optional agent"):
            self.assertRegex(main, r"(?m)^\s*Note over .*: *%s\b" % re.escape(track), "track note " + track)
        self.assertGreaterEqual(main.count("rect rgba("), 3, "a shaded block per track, and the accent")
        self.assertNotIn("box ", main, "no box: the lifeline names say which layer is which")
        how = pattern_shape.part_body(self.text, "How it works")
        for name in ("scripts/ladder.sh", "scripts/validate-org.sh", "scripts/org-drift.sh", "scripts/agent-check.sh",
                     "scripts/agent-test.sh", "Chromium"):
            self.assertIn(name, how, "the steps under the diagram name " + name)
        self.assertIn(ACCENT, main, "model calls use the one coral accent")

    def test_steps_under_the_diagram_use_its_numbers(self):
        how = pattern_shape.part_body(self.text, "How it works")
        self.assertRegex(how, r"\(steps? \d+")

    def test_a_first_test_to_copy_for_each_kind(self):
        part = pattern_shape.part_body(self.text, FIRST_TESTS)
        self.assertTrue(part, "the first-test part")
        for kind in KINDS:
            body = h3_body(self.text, kind)
            self.assertTrue(body.strip(), "an H3 %r inside the first-test part" % kind)
            self.assertIn("### " + kind, part)
            for label in ("What it proves", "The command"):
                self.assertIn("**%s.**" % label, body, "%s: %s" % (kind, label))
            self.assertIn("```", body, kind + ": an example to copy")

    def test_apex_example_stubs_the_model(self):
        self.assertIn("AgentLlm.stub", h3_body(self.text, "Apex tests"))

    def test_jest_example_checks_accessibility(self):
        self.assertIn("toBeAccessible", h3_body(self.text, "Jest for components"))

    def test_playwright_names_chromium_in_one_plain_line(self):
        body = h3_body(self.text, "Playwright in a real browser")
        self.assertRegex(body, r"Chromium is the open-source browser behind Chrome")

    def test_testing_center_says_what_it_asserts_costs_and_where_to_run_it(self):
        body = h3_body(self.text, "Testing Center for the agent")
        for word in ("expectedTopic", "expectedActions", "expectedOutcome", "model call", "sandbox"):
            self.assertIn(word, body)

    def test_testing_center_suite_is_claimed_only_with_its_script(self):
        if not AGENT_TEST.is_file():
            body = h3_body(self.text, "Testing Center for the agent")
            self.assertRegex(body, r"not run in this build")
            self.assertNotIn("fr2-testing-center.md", self.text)
            self.assertNotRegex(body, r"\b\d+ of \d+\b", "no counts without the suite")
        if not TESTING_CENTER.is_file():
            self.assertNotIn("fr2-testing-center.md", self.text)

    def test_bad_answer_part_names_each_layer(self):
        part = pattern_shape.part_body(self.text, BAD_ANSWER)
        for layer in ("Apex", "Jest", "Playwright", "Testing Center"):
            self.assertIn(layer, part)

    def test_publish_and_activate_keep_their_steps(self):
        self.assertIn("sf agent publish authoring-bundle", self.text)
        self.assertIn("sf agent activate", self.text)

    def test_what_the_tests_prove_names_files_that_exist(self):
        trust = pattern_shape.part_body(self.text, "Why you can trust it")
        self.assertIn("### What the tests prove", trust)
        table = h3_body(self.text, "What the tests prove")
        rows = [line for line in table.splitlines() if line.startswith("|")]
        areas = [row.split("|")[1].strip() for row in rows]
        for area in AREAS:
            self.assertIn(area, areas, "a row for " + area)
        links = re.findall(r"\]\(\.\./\.\./([^)#]+)\)", table)
        self.assertGreaterEqual(len(links), len(AREAS))
        for link in links:
            self.assertTrue((ROOT / link).exists(), "the table links a file that exists: " + link)

    def test_see_it_shows_the_ladder_output_as_text(self):
        see = self.text.split("\n## See it\n", 1)[1].split("\n## ", 1)[0]
        self.assertRegex(see, r"(?m)^ladder: python")

    def test_adopt_grants_access_and_links_the_public_docs(self):
        adopt = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn(GRANT, adopt)
        for url in PUBLIC_DOCS:
            self.assertIn(url, adopt)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)

    def test_limits_never_link_a_card_file(self):
        self.assertNotIn("agents/tasks", self.text)
        self.assertTrue(pattern_shape.part_body(self.text, "Limits and open items").strip())

    def test_ends_with_the_way_back(self):
        last = self.text.rstrip().splitlines()[-1]
        self.assertIn("../ARCHITECTURE.md", last)
        self.assertIn("../../README.md", last)


if __name__ == "__main__":
    unittest.main()
