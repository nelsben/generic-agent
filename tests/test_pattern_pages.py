"""Every pattern page, 00 to 14, against the shared shape, plus the index that fixes their titles and order (OPS-48).

One table, PAGES, lists each page with its kind, the fixed parts it has and the extra H2 parts it adds. Rows 00 to 08
are read from each chapter's own test, so the two cannot disagree; rows 09 to 14 are written here. Each row runs
through the shared helper tests/pattern_shape.py. The test also checks the index (docs/patterns/README.md), the access
step in every 'Adopt it' part, the way-back line at the end of every page, and that no page links a card file.
"""
import re
import unittest
from pathlib import Path

from tests import pattern_shape
from tests import test_pattern_00 as p00
from tests import test_pattern_01 as p01
from tests import test_pattern_02 as p02
from tests import test_pattern_03 as p03
from tests import test_pattern_04 as p04
from tests import test_pattern_05 as p05
from tests import test_pattern_06 as p06
from tests import test_pattern_07 as p07
from tests import test_pattern_08 as p08

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = ROOT / "docs/patterns"
INDEX = PATTERNS / "README.md"
ALL = tuple(pattern_shape.fixed_parts())
GROUP = "permission set group `Customer_Summary_User`"

CHAPTER, APPENDIX, PRINCIPLES, PLACEHOLDER = "chapter", "appendix", "principles page", "placeholder"

# (file, kind, fixed parts, extra parts), in reading order.
PAGES = (
    ("00-why-custom.md", CHAPTER, tuple(p00.PARTS), tuple(p00.EXTRAS)),
    ("01-route-gather-reduce.md", CHAPTER, tuple(p01.PARTS), tuple(p01.EXTRAS)),
    ("02-ask-anything-explorer.md", CHAPTER, tuple(p02.PARTS), tuple(p02.EXTRAS)),
    ("03-hotkey-panel.md", CHAPTER, tuple(p03.PARTS), tuple(p03.EXTRAS)),
    ("04-model-provider-seam.md", CHAPTER, tuple(p04.PARTS), tuple(p04.EXTRAS)),
    ("05-conversation-memory.md", CHAPTER, tuple(p05.PARTS), tuple(p05.EXTRAS)),
    ("06-agent-routing-and-verbatim-relay.md", APPENDIX, tuple(p06.PARTS), tuple(p06.EXTRAS)),
    ("07-trust-access-and-failure.md", PRINCIPLES, tuple(p07.PARTS), tuple(p07.EXTRAS)),
    ("08-test-and-release-lifecycle.md", CHAPTER, tuple(p08.PARTS), tuple(p08.EXTRAS)),
    ("09-outside-door-mcp.md", CHAPTER, ALL, ("Writing from an outside client",)),
    ("10-brand-and-theming.md", CHAPTER, ALL, ("Swap the brand: step by step",)),
    ("11-voice-input.md", CHAPTER, ALL, ()),
    ("12-right-rail.md", CHAPTER, ALL, ()),
    ("13-write-actions.md", CHAPTER, ALL, ()),
    (
        "14-embedded-surface.md",
        PLACEHOLDER,
        ("The business problem", "Limits and open items"),
        (
            "What the rep would see",
            "Platform pieces a real build would have to fit",
            "How it would reuse what exists",
            "What is deliberately not done",
        ),
    ),
)

INDEX_ROW = re.compile(r"^\|\s*(\d\d)\s*\|\s*\[([^\]]+)\]\((\d\d-[^)\s]+\.md)\)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$")


def page_files():
    return sorted(p.name for p in PATTERNS.glob("[0-9][0-9]-*.md"))


def h1(path):
    return pattern_shape.headings(path.read_text(encoding="utf-8"), 1)[0]


def index_rows():
    rows = []
    for line in INDEX.read_text(encoding="utf-8").splitlines():
        m = INDEX_ROW.match(line)
        if m:
            rows.append(m.groups())
    return rows


class EveryPatternPage(unittest.TestCase):
    def test_the_table_lists_every_page_once_in_number_order(self):
        self.assertEqual([row[0] for row in PAGES], page_files())

    def test_every_page_has_the_shared_shape(self):
        for name, _kind, parts, extras in PAGES:
            with self.subTest(page=name):
                pattern_shape.check_page(self, PATTERNS / name, parts, extras)

    def test_every_adopt_it_part_grants_access_through_the_group(self):
        for name, _kind, parts, _extras in PAGES:
            if "Adopt it" not in parts:
                continue
            with self.subTest(page=name):
                part = pattern_shape.part_body((PATTERNS / name).read_text(encoding="utf-8"), "Adopt it")
                self.assertIn(GROUP, part)

    def test_every_page_ends_with_the_way_back_line(self):
        for name in page_files():
            with self.subTest(page=name):
                last = (PATTERNS / name).read_text(encoding="utf-8").rstrip().splitlines()[-1]
                self.assertIn("](README.md)", last, "links the index")
                self.assertIn("](../../README.md)", last, "links the repo's README")

    def test_no_page_links_a_card_file(self):
        for path in [PATTERNS / name for name in page_files()] + [INDEX]:
            with self.subTest(page=path.name):
                self.assertNotIn("agents/tasks", path.read_text(encoding="utf-8"))


class ThePatternIndex(unittest.TestCase):
    def test_index_exists(self):
        self.assertTrue(INDEX.is_file(), "docs/patterns/README.md")

    def test_index_lists_every_page_once_in_reading_order_with_its_h1_and_kind(self):
        rows = index_rows()
        self.assertEqual([row[2] for row in rows], [row[0] for row in PAGES], "every page once, in reading order")
        kinds = {name: kind for name, kind, _parts, _extras in PAGES}
        for number, title, name, kind, line in rows:
            with self.subTest(page=name):
                self.assertEqual(number, name[:2])
                self.assertEqual(title, h1(PATTERNS / name), "the index title is the page's H1")
                self.assertEqual(kind, kinds[name])
                self.assertTrue(line.strip(), "one line on what the page gives a seller or a service rep")


if __name__ == "__main__":
    unittest.main()
