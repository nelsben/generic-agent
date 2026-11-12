"""Static checks for the explorer prompt, AgentPrompt_Explore (BE-17).

Rule 9 tells the model to open with a short answer and leave the rows to the table the system
shows after the text. Every rule from 1 to 11 is still there, in order, and the reply format and
the template variables are unchanged.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPT = ROOT / "force-app/main/default/staticresources/AgentPrompt_Explore.resource"

# One phrase per rule that carries its meaning; rule 9 is checked on its own below.
KEPT = {
    1: "Use only object and field names that appear in the catalog",
    2: "One object per query.",
    3: "Answer only from rows the system returned.",
    4: "say so plainly in the answer",
    5: "Keep record ids and other system identifiers out of the answer text.",
    6: "If a turn shows INVALID, read the reason and send a corrected reply.",
    7: 'When "Queries left" is 0, your reply must be an answer.',
    8: '"Open record" is the record the user is looking at.',
    10: "Never write a dotted field path (like Account.Name)",
    11: "followups: up to 4 short next questions",
}

RULE_9 = (
    "9. The answer text is plain text, at most about 1,500 characters, and it names at most three "
    "records. No markdown headers, tables or JSON inside it. The system shows the last result's rows as a"
    " table right after your text, and when the question asks which records or for a list, that table is "
    "the answer. So open with one or two short sentences that lead into it: the top item, the total or "
    "the range, a count, or what stands out. Do not repeat the names and values of the table's rows, "
    "whether in a sentence or as lines. Lines starting with \"- \" are allowed, but not to restate the "
    "table's rows. A result that is one row of totals, such as a count, is the answer: state it in the "
    "text. Facts from an earlier query are not in that table, so they belong in the text too."
)


def rules(text):
    """The numbered rules between 'Rules:' and the next blank line, keyed by number."""
    block = text.split("Rules:\n", 1)[1].split("\n\n", 1)[0]
    out = {}
    for line in block.splitlines():
        m = re.match(r"^(\d+)\. ", line)
        if m:
            out[int(m.group(1))] = line
    return out


class TestExplorePrompt(unittest.TestCase):
    def setUp(self):
        self.text = PROMPT.read_text(encoding="utf-8")
        self.rules = rules(self.text)

    def test_rules_1_to_11_are_all_present_in_order(self):
        self.assertEqual(list(self.rules), list(range(1, 12)))

    def test_rule_9_opens_with_a_short_answer_and_leaves_the_rows_to_the_table(self):
        self.assertEqual(self.rules[9], RULE_9)

    def test_rule_9_no_longer_only_asks_to_summarize(self):
        self.assertNotIn("summarize rather than list every row", self.text)

    def test_every_other_rule_keeps_its_meaning(self):
        for n, phrase in KEPT.items():
            self.assertIn(phrase, self.rules[n], f"rule {n}")

    def test_reply_format_is_unchanged(self):
        self.assertIn('A query: {"action":"query","plan":PLAN}', self.text)
        self.assertIn('An answer: {"action":"answer","text":"...","followups":["...","..."]}', self.text)

    def test_template_variables_are_unchanged(self):
        found = set(re.findall(r"\{\{(\w+)\}\}", self.text))
        self.assertEqual(
            found, {"date_literals", "catalog", "context", "history", "question", "turns", "queries_left"}
        )

    def test_system_and_user_parts_are_kept(self):
        self.assertTrue(self.text.startswith("---system---\n"))
        self.assertIn("\n---user---\n", self.text)


if __name__ == "__main__":
    unittest.main()
