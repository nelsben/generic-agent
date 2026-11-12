"""Static checks for the explorer prompt, AgentPrompt_Explore (BE-17, BE-18).

Rule 9 caps the answer text at two short sentences that lead into the table the system shows
after the text: at most one record named, no owner unless asked, a count stated first, and a
follow-up about an earlier answer's records answered about exactly those records. Every rule
from 1 to 11 is still there, in order, and the reply format and the template variables are
unchanged.
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
    "9. The answer text is plain text of at most two short sentences in all, with no markdown headers, "
    "tables, lists or JSON. The system shows the last result's rows as a table right after your text, and "
    "when the question asks which records or for a list, that table is the answer, so the text only leads "
    "into it with a count, the total or the range, or what stands out. Name at most one record in the text, "
    "even when the question asks which ones and several match: give how many match and the top one, and "
    "never put a second name in the text, since the table shows the rest. An account "
    "or contact counts as a record too, so when the question asks for a single record, such as the largest, "
    "name only that record and its key value, not its account. Do not repeat the table's other rows, and do "
    "not mention an owner or any user unless the question asks about owners. A result that is one row of "
    "totals, such as a count, is the answer: state the number in the first sentence. Facts from an earlier "
    "query are not in that table, so they belong in the text too. When the question points back to records "
    "of an earlier answer (\"those\", \"them\") that it does not list, answer about exactly those records: "
    "keep the earlier question's filters, and if it took only the top or first few, rerun it unchanged with "
    "Id, then run one more query on those Ids with the new condition, so the table shows only the matches. "
    "A good lead for a \"which of those\" follow-up: \"Of those 8 deals, 3 close next month. The largest is "
    "Acme Renewal at $310,000.\""
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

    def test_rule_9_caps_the_answer_at_two_sentences_that_lead_into_the_table(self):
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
