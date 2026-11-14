"""README.md as the FR2 workbook for Customer Summary (OPS-36).

The README is the repo's front page, for a seller and a builder at once. This test checks what other pages and cards
rely on, and what the FR2 ledger asks of it:

- the product name is Customer Summary, and the old name appears only in links into historical folders (not even in
  alt text);
- the first screen gives the outcome, the hero GIF and a short "Why not just the standard chat?" linking chapter 00;
- the three surfaces (the embedded one as a labelled placeholder), the three skills, voice with its privacy line, the
  brand swap in five steps (pattern 10), the MCP door as page 09 tells it, and the five design principles;
- the built-in Agentforce panel and the retired agent button are never shown as a way in;
- the quick start ("See it in 5 minutes") deploys every metadata folder under force-app/main/default except the
  agent bundle, needs no agent publish, grants access with the one group, and ends with the ladder;
- the workbook table copies the index (docs/patterns/README.md): the same titles, files and kinds, in order;
- the proof table takes its counts from the build review and the ladder page, and the Testing Center row follows
  whether its page exists;
- the Status table has one row per claim a page may link, and each reads "not yet proven" unless it links a tracked
  file that records the run;
- the diagrams carry the shared theme, and each sequence diagram starts with autonumber;
- every image has alt text and exists; the old README captures are no longer linked.
"""
import re
import subprocess
import unittest
from pathlib import Path

from tests import pattern_shape
from tests import test_pattern_pages as pages

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
DEFAULT = ROOT / "force-app/main/default"
PAGE_09 = ROOT / "docs/patterns/09-outside-door-mcp.md"
TESTING_CENTER = ROOT / "docs/research/fr2-testing-center.md"
LADDER = ROOT / "docs/research/fr2-ladder.md"

QUICK_START = "See it in 5 minutes"
STATUS = "Status"
WHY = "Why not just the standard chat?"
PRINCIPLES = "Design principles"
WORKBOOK = "The pattern workbook"
PROOF = "Proof"
LIMITS = "Limits and open items"

STATUS_CLAIMS = (
    "A run as a non-admin user",
    "A real MCP tool call",
    'A clean install from "See it in 5 minutes"',
    "Runs without the agent",
    "The microphone in Chrome",
    "VoiceOver",
)

OLD_NAME = re.compile("account" + r"[ _-]?" + r"brief(?!ed)", re.IGNORECASE)
HISTORICAL = ("docs/research/", "docs/reviews/", "docs/plans/", "docs/assets/")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)\)")
SOURCE_DIR = re.compile(r"--source-dir\s+force-app/main/default/([A-Za-z]+)")
WORKBOOK_ROW = re.compile(
    r"^\|\s*(\d\d)\s*\|\s*\[([^\]]+)\]\(docs/patterns/(\d\d-[^)\s#]+\.md)\)\s*\|\s*([^|]+?)\s*\|.*\|\s*$"
)


def text():
    return README.read_text(encoding="utf-8")


def prose():
    return pattern_shape.outside_fences(text())


def part(title):
    """One H2 part of the README, code blocks included (the quick start's commands and the ladder's lines are in
    them), up to the next H2. No code block in the README holds a line that starts with '## '."""
    for chunk in re.split(r"^## ", text(), flags=re.M)[1:]:
        head, _, body = chunk.partition("\n")
        if head.strip() == title:
            return body
    return ""


def tracked():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, check=True, capture_output=True, text=True).stdout
    return set(out.split())


def table_rows(body):
    rows = []
    for line in body.splitlines():
        if line.startswith("|") and not re.match(r"^\|[\s\-|]+\|\s*$", line):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
    return rows[1:]


def metadata_folders():
    """Folders under force-app/main/default that hold at least one file other than a .gitkeep."""
    out = set()
    for folder in DEFAULT.iterdir():
        if folder.is_dir() and any(f.is_file() and f.name != ".gitkeep" for f in folder.rglob("*")):
            out.add(folder.name)
    return out


class TheName(unittest.TestCase):
    def test_customer_summary_throughout_and_no_old_name_outside_history_links(self):
        self.assertIn("Customer Summary", text())
        left = text()

        def keep(match):
            target = match.group(2)
            return "" if target.startswith(HISTORICAL) else match.group(0)

        left = LINK.sub(keep, left)
        hits = [line for line in left.splitlines() if OLD_NAME.search(line)]
        self.assertEqual(hits, [], "the old name outside a link into a historical folder")


class TheFirstScreen(unittest.TestCase):
    def test_the_hero_gif_is_the_first_image_and_comes_before_any_h2(self):
        head = text().split("\n## ", 1)[0]
        images = IMAGE.findall(head)
        self.assertTrue(images, "an image before the first H2")
        self.assertEqual(images[0][1], "docs/assets/fr2-readme-hero.gif")

    def test_why_not_the_standard_chat_is_on_the_first_screen_and_links_chapter_00(self):
        lines = prose().splitlines()
        heads = [i for i, line in enumerate(lines) if line.strip() == "## " + WHY]
        self.assertEqual(len(heads), 1)
        self.assertLess(heads[0], 40, "within the first screen")
        body = part(WHY)
        self.assertIn("(docs/patterns/00-why-custom.md)", body)
        self.assertLessEqual(len([l for l in body.splitlines() if l.strip()]), 6, "two or three short lines")

    def test_it_says_plainly_this_is_agentforce_with_its_own_surfaces(self):
        self.assertRegex(prose(), r"(?i)this is agentforce,\s+with its own surfaces")


class TheSurfacesSkillsAndVoice(unittest.TestCase):
    def test_three_surfaces_with_the_embedded_one_a_labelled_placeholder(self):
        low = prose().lower()
        for word in ("compact window", "right rail", "embedded"):
            self.assertIn(word, low)
        lines = [l for l in prose().splitlines() if "(docs/patterns/14-embedded-surface.md)" in l]
        self.assertTrue(any(re.search(r"(?i)placeholder|not built", l) for l in lines))

    def test_one_still_per_surface(self):
        targets = [t for _alt, t in IMAGE.findall(text())]
        for still in ("docs/assets/fr2-01-summary-compact.png", "docs/assets/fr2-01-summary-rail.png"):
            self.assertIn(still, targets)

    def test_the_three_skills(self):
        low = prose().lower()
        for skill in ("summary", "ask anything", "act"):
            self.assertIn("**" + skill, low)

    def test_voice_has_the_privacy_line(self):
        self.assertRegex(prose(), r"Chrome sends the audio to Google's servers to transcribe it")

    def test_the_brand_swap_has_five_steps_and_links_pattern_10(self):
        body = part("Swap the brand in five steps")
        self.assertEqual(re.findall(r"^(\d)\. ", body, re.M), ["1", "2", "3", "4", "5"])
        self.assertIn("(docs/patterns/10-brand-and-theming.md", body)

    def test_the_mcp_line_follows_page_09(self):
        body = part("The MCP door")
        self.assertIn("(docs/patterns/09-outside-door-mcp.md)", body)
        if "still active" in PAGE_09.read_text(encoding="utf-8"):
            self.assertIn("still active", body)
            self.assertIn("(docs/research/mcp-door-runbook.md", body)
        self.assertIn("(#status)", body)

    def test_the_built_in_panel_and_the_agent_button_are_not_ways_in(self):
        low = prose().lower()
        self.assertNotIn("ask the agent", low)
        for block in pattern_shape.mermaid_blocks(text()):
            self.assertNotRegex(block.lower(), r"agentforce panel|built-in panel|astro")

    def test_no_claim_beyond_what_pattern_02_lists(self):
        low = prose().lower()
        self.assertNotIn("any object", low)
        self.assertNotIn("any combination", low)

    def test_the_model_call_count_matches_architecture(self):
        self.assertIn("Up to 4 model calls", text())


class ThePrinciples(unittest.TestCase):
    def test_five_principles_one_line_each_and_trust_links_page_07(self):
        body = part(PRINCIPLES)
        items = re.findall(r"^(\d)\. (.+)$", body, re.M)
        self.assertEqual([n for n, _ in items], ["1", "2", "3", "4", "5"])
        self.assertIn("(docs/patterns/07-trust-access-and-failure.md)", items[4][1])


class TheQuickStart(unittest.TestCase):
    def test_it_deploys_every_metadata_folder_except_the_agent_bundle(self):
        named = set(SOURCE_DIR.findall(part(QUICK_START)))
        expected = metadata_folders() - {"aiAuthoringBundles"}
        self.assertEqual(named, expected)

    def test_it_needs_no_agent_publish_and_names_the_appendix(self):
        body = part(QUICK_START)
        self.assertNotIn("sf agent", body)
        self.assertNotIn("aiAuthoringBundles", body)
        self.assertNotIn("Customer_Summary_Agent_Access", body)
        self.assertIn("(docs/patterns/06-agent-routing-and-verbatim-relay.md#adopt-it)", body)

    def test_access_is_one_line_assigning_the_group(self):
        body = part(QUICK_START)
        assigns = re.findall(r"^\s*sf org assign permset .*$", body, re.M)
        self.assertEqual(len(assigns), 1)
        self.assertIn("-n Customer_Summary_User", assigns[0])
        self.assertIn("permission set group `Customer_Summary_User`", body)

    def test_the_group_step_says_ops_30_ran_it_and_links_its_record(self):
        body = part(QUICK_START)
        self.assertIn("(docs/research/fr2-rename-org.md)", body)
        self.assertNotIn("not part of that record", body)

    def test_it_ends_with_the_ladder(self):
        last = [l for l in part(QUICK_START).splitlines() if l.strip()][-1]
        self.assertIn("run the checks: npm run ladder", last)


class TheWorkbook(unittest.TestCase):
    def test_the_same_titles_files_and_kinds_as_the_index_in_order(self):
        rows = [WORKBOOK_ROW.match(l).groups() for l in part(WORKBOOK).splitlines() if WORKBOOK_ROW.match(l)]
        index = pages.index_rows()
        self.assertEqual(len(index), 15)
        self.assertEqual([r[:4] for r in rows], [r[:4] for r in index])
        self.assertEqual(rows[0][0], "00")


class TheProofTable(unittest.TestCase):
    def test_it_links_the_build_review_and_the_ladder_with_dates(self):
        body = part(PROOF)
        self.assertIn("(docs/reviews/fr2-build-review.md", body)
        self.assertIn("(docs/research/fr2-ladder.md", body)
        self.assertIn("2026-11-14", body)

    def test_the_ladder_lines_are_copied_from_its_page(self):
        body = part(PROOF)
        ladder = LADDER.read_text(encoding="utf-8")
        lines = [l for l in body.splitlines() if l.startswith("ladder: ")]
        self.assertGreaterEqual(len(lines), 6)
        for line in lines:
            self.assertIn(line, ladder)

    def test_the_testing_center_row_follows_whether_its_page_exists(self):
        rows = [r for r in table_rows(part(PROOF)) if "Testing Center" in r[0]]
        self.assertEqual(len(rows), 1)
        if not TESTING_CENTER.exists():
            self.assertIn("not run in this build", " ".join(rows[0]))

    def test_the_e2e_report_still_says_its_run_was_cut(self):
        body = part(PROOF)
        self.assertIn("docs/assets/fr2-08-e2e-report.png", body)
        self.assertIn("560 s", body)


class TheStatusTable(unittest.TestCase):
    def test_one_row_per_claim_a_page_may_link(self):
        firsts = [r[0] for r in table_rows(part(STATUS))]
        for claim in STATUS_CLAIMS:
            self.assertEqual(firsts.count(claim), 1, claim)

    def test_a_claim_reads_not_yet_proven_unless_it_links_a_tracked_record(self):
        files = tracked()
        for row in table_rows(part(STATUS)):
            if row[0] not in STATUS_CLAIMS:
                continue
            with self.subTest(claim=row[0]):
                if "not yet proven" in row[1].lower():
                    continue
                linked = [t.split("#")[0] for _l, t in LINK.findall(" ".join(row[1:]))]
                self.assertTrue(any(t in files and t.startswith("docs/research/") for t in linked))

    def test_proven_is_said_only_in_the_status_table(self):
        outside = prose().replace(part(STATUS), "")
        self.assertIsNone(re.search(r"(?i)\bproven\b|\bunproven\b", outside))


class TheDiagrams(unittest.TestCase):
    def test_three_sequence_diagrams_and_one_component_diagram(self):
        starts = sorted(b.split("\n", 2)[1].split()[0] for b in pattern_shape.mermaid_blocks(text()))
        self.assertEqual(starts, ["flowchart", "sequenceDiagram", "sequenceDiagram", "sequenceDiagram"])

    def test_every_diagram_carries_the_theme_and_each_sequence_starts_with_autonumber(self):
        theme = pattern_shape.theme_line()
        for block in pattern_shape.mermaid_blocks(text()):
            lines = block.splitlines()
            with self.subTest(kind=lines[1]):
                self.assertEqual(lines[0].strip(), theme)
                if lines[1].startswith("sequenceDiagram"):
                    self.assertEqual(lines[2].strip(), "autonumber")


class TheImagesAndLimits(unittest.TestCase):
    def test_every_image_has_alt_text_and_exists(self):
        files = tracked()
        images = IMAGE.findall(text())
        self.assertGreaterEqual(len(images), 3)
        for alt, target in images:
            with self.subTest(image=target):
                self.assertGreaterEqual(len(alt.split()), 8, "alt text that says what the image shows")
                self.assertIn(target, files)

    def test_the_old_readme_captures_are_gone(self):
        for old in ("docs/assets/brief-flow.gif", "docs/assets/e2e-report.png"):
            self.assertNotIn("(" + old + ")", text())

    def test_the_limits_list_the_build_reviews_open_findings_and_the_render_check(self):
        body = part(LIMITS)
        for finding in ("M1", "M2", "M3", "M4", "M5"):
            self.assertIn(finding, body)
        self.assertIn("OPS-61", body)

    def test_no_card_file_and_no_local_path(self):
        self.assertNotIn("agents/tasks", text())
        self.assertNotIn("/Users/", text())


if __name__ == "__main__":
    unittest.main()
