"""The shape every pattern page shares (fr2-design.md 'Pattern page shape' and 'Diagrams').

Not a test module (its name does not start with test_): each chapter's own test calls check_page() with the page
path, the fixed parts the page has and any extra H2 parts of its own. The fixed H2 headings are read from
fr2-design.md, and the theme line from docs/patterns/_diagram-theme.md, so neither is copied here and no page
name is written into this helper.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "docs/plans/fr2-design.md"
THEME = ROOT / "docs/patterns/_diagram-theme.md"

FENCE = re.compile(r"^```.*?^```[ \t]*$", re.M | re.S)
MERMAID = re.compile(r"^```mermaid[ \t]*\n(.*?)^```[ \t]*$", re.M | re.S)
TRUST_PART = "Why you can trust it"
TRUST_LINES = ("Runs as the signed-in user:", "System context:")


def fixed_parts():
    """The eight H2 headings, in order, from the numbered list under 'Pattern page shape' in fr2-design.md."""
    text = DESIGN.read_text(encoding="utf-8")
    section = text.split("\n## Pattern page shape", 1)[1].split("\n## ", 1)[0]
    return re.findall(r"^\s+\d+\.\s+`([^`]+)`", section, re.M)


def theme_line():
    """The one %%{init: ...}%% line in the theme page's snippet."""
    text = THEME.read_text(encoding="utf-8")
    lines = {line.strip() for line in text.splitlines() if line.strip().startswith("%%{init:")}
    if len(lines) != 1:
        raise AssertionError("%s should hold exactly one %%%%{init: ...}%%%% line, found %d" % (THEME, len(lines)))
    return lines.pop()


def outside_fences(text):
    return FENCE.sub("", text)


def headings(text, level):
    marks = "#" * level
    return re.findall(r"^%s (.+?)\s*$" % marks, outside_fences(text), re.M)


def part_body(text, title):
    """The text of one H2 part, up to the next H2, or '' when the page has no such part."""
    parts = re.split(r"^## ", outside_fences(text), flags=re.M)
    for part in parts[1:]:
        head, _, body = part.partition("\n")
        if head.strip() == title:
            return body
    return ""


def mermaid_blocks(text):
    return MERMAID.findall(text)


def check_page(case, page, parts, extras=()):
    """Check one page against the shared shape.

    case: the calling unittest.TestCase. page: the page's Path. parts: the fixed parts this page has (a page that
    is exempt from some leaves them out). extras: the page's own extra H2 parts, each placed between fixed ones.
    """
    fixed = fixed_parts()
    case.assertEqual(len(fixed), 8, "fr2-design.md 'Pattern page shape' should list eight H2 headings")
    unknown = [p for p in parts if p not in fixed]
    case.assertEqual(unknown, [], "parts not in fr2-design.md")
    expected = [p for p in fixed if p in parts]
    text = page.read_text(encoding="utf-8")

    h1 = headings(text, 1)
    case.assertEqual(len(h1), 1, "%s: one H1" % page.name)
    case.assertIsNone(re.match(r"\d", h1[0]), "%s: the H1 has no number: %r" % (page.name, h1[0]))

    h2 = headings(text, 2)
    case.assertEqual([h for h in h2 if h not in extras], expected, "%s: the fixed H2 parts, in order" % page.name)
    for extra in extras:
        case.assertEqual(h2.count(extra), 1, "%s: the extra part %r appears once" % (page.name, extra))
        at = h2.index(extra)
        case.assertTrue(0 < at < len(h2) - 1, "%s: the extra part %r sits between fixed parts" % (page.name, extra))

    theme = theme_line()
    for n, code in enumerate(mermaid_blocks(text), 1):
        lines = [line.strip() for line in code.splitlines() if line.strip()]
        if "sequenceDiagram" not in lines:
            continue
        at = lines.index("sequenceDiagram")
        case.assertIn(theme, lines[:at], "%s: sequence diagram %d carries the theme line first" % (page.name, n))
        case.assertEqual(lines[at + 1 : at + 2], ["autonumber"], "%s: sequence diagram %d starts with autonumber" % (page.name, n))

    if TRUST_PART in parts:
        body = part_body(text, TRUST_PART)
        for start in TRUST_LINES:
            case.assertRegex(body, r"(?m)^\s*(?:[-*]\s+)?(?:\*\*)?" + re.escape(start), "%s: %r line" % (page.name, start))
    return text
