"""OPS-66: pins the docs sweep (trust table, model-call count, Undo headings)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Listed by name, as they exist at OPS-66's base. The explorer pages BE-43 to BE-45 write are not covered; the two
# explorer pages BE-42 and BE-41 own (catalog, scale) are left alone.
UNDO_PAGES = [
    "fr2-action-cards.md",
    "fr2-actions-spike.md",
    "fr2-agent-memory.md",
    "fr2-agent-publish.md",
    "fr2-captures.md",
    "fr2-card-architecture.md",
    "fr2-card-contract-apex.md",
    "fr2-conversation-history.md",
    "fr2-coworker-spike.md",
    "fr2-customer-outcomes.md",
    "fr2-explorer-baseline.md",
    "fr2-follow-ups.md",
    "fr2-front-end-tests.md",
    "fr2-hotkey-spec-flake.md",
    "fr2-ladder.md",
    "fr2-model-door.md",
    "fr2-panel-later.md",
    "fr2-panel-proof.md",
    "fr2-quick-start-change.md",
    "fr2-rail-context.md",
    "fr2-rename-go.md",
    "fr2-rename-org.md",
    "fr2-retire-ask-agent.md",
    "fr2-sentiment.md",
    "fr2-standard-limits.md",
    "fr2-summary-accuracy.md",
    "fr2-surfaces-spike.md",
    "fr2-trust-rule.md",
]


class DocsSweep(unittest.TestCase):
    def test_trust_table_lists_the_outcome_classes(self):
        text = (ROOT / "docs/research/fr2-trust-rule.md").read_text()
        self.assertIn("`CustomerOutcomes`", text)
        self.assertIn("`CustomerOutcomeRetentionBatch`", text)

    def test_summary_is_up_to_four_model_calls(self):
        for rel in ("docs/research/fr2-model-door.md", "scripts/summary-accuracy.apex"):
            self.assertNotIn("up to 3", (ROOT / rel).read_text(), rel)

    def test_every_listed_research_page_has_an_undo_heading(self):
        for name in UNDO_PAGES:
            text = (ROOT / "docs/research" / name).read_text()
            self.assertTrue(re.search(r"^#.*undo", text, re.I | re.M), name)


if __name__ == "__main__":
    unittest.main()
