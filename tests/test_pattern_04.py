"""Pattern 04, the model provider seam (OPS-42): the workbook chapter's shape, the facts it must keep, and its guide.

The shared shape comes from tests/pattern_shape.py. This page adds one part of its own, 'The decision' (API first
for prompts, the trade-off, and when a prompt template still fits). Its 'See it' part is a text block, not an image
(fr2-design.md 'Pattern page shape', exemptions). The builder's guide, docs/guides/models-api-prompts.md, is linked
from 'Adopt it' and is checked here for its sections.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs/patterns/04-model-provider-seam.md"
GUIDE = ROOT / "docs/guides/models-api-prompts.md"
GUIDE_LINK = "../guides/models-api-prompts.md"
PARTS = pattern_shape.fixed_parts()
EXTRAS = ("The decision",)
GUIDE_PARTS = (
    "What the Models API is",
    "Where a prompt's context comes from",
    "Add or change context",
    "Tune a prompt",
    "Try it in a minute",
    "Check accuracy",
    "What each call costs",
    "Switch one prompt to a template and back",
    "Work on prompts with an AI assistant",
)
MODEL_ACCENT = "rect rgba(244, 114, 82, 0.22)"


def guide_text():
    return GUIDE.read_text(encoding="utf-8") if GUIDE.exists() else ""


class PatternFourShape(unittest.TestCase):
    def setUp(self):
        self.text = PAGE.read_text(encoding="utf-8")

    def test_page_has_the_shared_shape(self):
        pattern_shape.check_page(self, PAGE, PARTS, EXTRAS)

    def test_the_decision_follows_the_business_problem(self):
        h2 = pattern_shape.headings(self.text, 2)
        self.assertIn("The decision", h2)
        self.assertEqual(h2[h2.index("The decision") - 1], "The business problem")

    def test_business_problem_is_about_prompt_templates(self):
        part = pattern_shape.part_body(self.text, "The business problem")
        self.assertRegex(part, r"(?i)prompt templates?")
        self.assertRegex(part, r"(?i)trust layer")
        for word in ("Prompt Builder", "version", "merge field", "activat"):
            self.assertIn(word.lower(), part.lower(), "the build layer names " + word)

    def test_the_decision_says_api_first_the_trade_off_and_when_a_template_still_fits(self):
        part = pattern_shape.part_body(self.text, "The decision")
        self.assertRegex(part, r"(?i)api first")
        self.assertRegex(part, r"(?i)trade-off")
        self.assertRegex(part, r"(?im)^#{3} When a template still fits\s*$")
        self.assertIn("Source__c", part)
        self.assertIn("Prompt_Template", part)
        self.assertIn("fr2-design.md#operating-principles", part)

    def test_architecture_in_a_few_steps_has_the_six_steps(self):
        part = pattern_shape.part_body(self.text, "The architecture in a few steps")
        steps = re.findall(r"(?m)^\d+\. \*\*([^*]+)\*\*", part)
        self.assertEqual(
            [s.rstrip(".").lower() for s in steps],
            ["name a prompt", "load its settings", "fill it", "send it", "cap and check", "return"],
        )

    def test_main_diagram_has_phases_one_accent_and_both_sources(self):
        sequences = [b for b in pattern_shape.mermaid_blocks(self.text) if "sequenceDiagram" in b]
        self.assertGreaterEqual(len(sequences), 1)
        main = sequences[0]
        for phase in ("Prepare", "Call", "Return"):
            self.assertRegex(main, r"(?m)^\s*Note over .*: *%s\b" % re.escape(phase), "phase note " + phase)
        self.assertNotIn("box ", main, "no box: the lifeline names say which layer is which")
        for lifeline in ("A feature", "Prompt door", "Settings", "Prompt files", "AI model"):
            self.assertIn(" as " + lifeline, main, "a lifeline for " + lifeline)
        self.assertIn(MODEL_ACCENT, main, "the model call carries the one accent")
        how = pattern_shape.part_body(self.text, "How it works")
        self.assertIn("AgentPrompt_", how, "the static resource path, named in the steps under the diagram")
        for name in ("Agent_Prompt_Setting__mdt", "AgentLlmModelsApi", "AgentLlmPromptTemplate"):
            self.assertIn(name, how, "the steps under the diagram name " + name)
        self.assertRegex(main, r"(?i)prompt template", "the opt-in template path")
        self.assertRegex(main, r"(?m)^\s*alt ", "the two sources are the two branches of one alt")

    def test_see_it_is_a_text_block_from_prompt_try(self):
        part = pattern_shape.part_body(self.text, "See it")
        self.assertNotIn("![", part, "page 04's See it is a text block, not an image")
        self.assertIn("scripts/prompt-try.apex", part)
        block = self.text.split("\n## See it\n", 1)[1].split("\n## ", 1)[0]
        fenced = re.findall(r"(?ms)^```text\n(.*?)^```", block)
        self.assertEqual(len(fenced), 1, "one text block")
        self.assertIn("TRY|prompt=", fenced[0])
        self.assertIn("TRY|reply=", fenced[0])
        self.assertIsNone(re.search(r"\b(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]{15}(?:[A-Za-z0-9]{3})?\b", fenced[0]), "no Ids")

    def test_trust_and_scale_claims_link_their_evidence(self):
        trust = pattern_shape.part_body(self.text, "Why you can trust it")
        for evidence in ("AgentLlmTest.cls", "AgentLlmModelsApiTest.cls", "AgentLlmPromptTemplateTest.cls",
                         "test_trust_rule.py", "fr2-model-door.md"):
            self.assertIn(evidence, trust)
        scale = pattern_shape.part_body(self.text, "How it scales")
        for part_name, body in (("Why you can trust it", trust), ("How it scales", scale)):
            bullets = re.findall(r"(?ms)^- (.*?)(?=^- |\Z)", body)
            self.assertTrue(bullets, part_name + " has claims")
            for bullet in bullets:
                self.assertIn("](", bullet, "%s: each claim links its evidence: %r" % (part_name, bullet[:60]))

    def test_names_the_new_synthesis_prompt(self):
        self.assertIn("AgentPrompt_SummarySynthesis", self.text)
        for text in (self.text, guide_text()):
            self.assertNotIn("AgentPrompt_BriefSynthesis", text)

    def test_never_states_a_proof_status_and_links_the_status_table(self):
        self.assertIsNone(re.search(r"(?i)\bproven\b", self.text))
        self.assertIn("../../README.md#status", self.text)
        self.assertIsNone(re.search(r"(?i)\bproven\b", guide_text()))

    def test_limits_name_cards_by_id_and_never_link_a_card_file(self):
        for text in (self.text, guide_text()):
            self.assertNotIn("agents/tasks", text)
        limits = pattern_shape.part_body(self.text, "Limits and open items")
        for card in ("BE-33", "BE-29"):
            self.assertIn(card, limits)
        self.assertIn("No card yet", limits)

    def test_adopt_it_links_the_guide(self):
        part = pattern_shape.part_body(self.text, "Adopt it")
        self.assertIn(GUIDE_LINK, part)
        self.assertIn("Customer_Summary_User", part)


class ModelsApiGuide(unittest.TestCase):
    def test_guide_exists(self):
        self.assertTrue(GUIDE.exists(), "docs/guides/models-api-prompts.md")

    def test_guide_has_its_sections_in_order(self):
        text = guide_text()
        self.assertTrue(text, "the guide exists")
        self.assertEqual(len(pattern_shape.headings(text, 1)), 1, "one H1")
        self.assertEqual(pattern_shape.headings(text, 2), list(GUIDE_PARTS))

    def test_guide_teaches_the_try_script_the_trace_and_the_accuracy_check(self):
        text = guide_text()
        for word in ("scripts/prompt-try.apex", "Trace__c", "scripts/summary-accuracy.apex", "Max_Tokens__c",
                     "Model__c", "Tone__c", "---system---", "---user---"):
            self.assertIn(word, text)

    def test_guide_links_back_to_the_chapter(self):
        self.assertIn("../patterns/04-model-provider-seam.md", guide_text())


if __name__ == "__main__":
    unittest.main()
