"""The shape every pattern page shares (fr2-design.md 'Pattern page shape' and 'Diagrams').

Not a test module (its name does not start with test_): each chapter's own test calls check_page() with the page
path, the fixed parts the page has and any extra H2 parts of its own. The fixed H2 headings are read from
fr2-design.md, and the diagram snippets from docs/patterns/_diagram-theme.md, so neither is copied here and no page
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


MAX_LIFELINES = 5
MAX_MESSAGE = 32
MAX_NOTE = 24
ARROW = re.compile(r"^\s*([\w]+)\s*(?:-->>|->>|-->|->|--x|-x|--\)|-\))[+-]?\s*([\w]+)\s*:(.*)$")
LIFELINE = re.compile(r"^\s*(?:participant|actor)\s+(\w+)")
NOTE = re.compile(r"^\s*Note\s+(?:over|left of|right of)\s+([^:]+):(.*)$")


def snippets():
    """The theme page's snippets: {'sequence': [...lines], 'flowchart': [...lines], 'classDef': {...lines}}."""
    text = THEME.read_text(encoding="utf-8")
    blocks = re.findall(r"^```text[ \t]*\n(.*?)^```[ \t]*$", text, re.M | re.S)
    out = {}
    for block in blocks:
        lines = [line.rstrip() for line in block.splitlines() if line.strip()]
        if lines and lines[0] == "---" and any(line.strip() == "sequence:" for line in lines):
            out["sequence"] = lines
        elif lines and lines[0] == "---" and any(line.strip() == "layout: dagre" for line in lines):
            out["flowchart"] = lines
        elif lines and all(line.strip().startswith("classDef ") for line in lines):
            out["classDef"] = {line.strip() for line in lines}
    if set(out) != {"sequence", "flowchart", "classDef"}:
        raise AssertionError("%s should hold the sequence, flowchart and classDef snippets, found %s" % (THEME, sorted(out)))
    return out


def covered_numbers(steps):
    """Every diagram number a numbered item names: '(step 4)', '(steps 4 to 7)', '(steps 4 and 5)'."""
    numbers = []
    for item in re.findall(r"(?ms)^\d+\. (.*?)(?=^\d+\. |\Z)", steps):
        for a, b in re.findall(r"\bsteps? (\d+)(?: (?:to|and) (\d+))?\b", item):
            numbers.extend(range(int(a), int(b or a) + 1))
    return numbers


def check_diagrams(case, text, name):
    """Check every mermaid block in one page's text against the theme page's snippets and rules."""
    snip = snippets()
    for match in re.finditer(MERMAID, text):
        code = match.group(1)
        n = text[: match.start()].count("```mermaid") + 1
        where = "%s: diagram %d" % (name, n)
        raw = [line.rstrip() for line in code.splitlines() if line.strip()]
        lines = [line.strip() for line in raw]
        case.assertNotIn("%%{init", code, "%s: settings go in the frontmatter snippet" % where)
        if "sequenceDiagram" in lines:
            head = snip["sequence"]
            case.assertEqual(raw[: len(head)], head, "%s opens with the sequence snippet, word for word" % where)
            case.assertEqual(lines[len(head) : len(head) + 2], ["sequenceDiagram", "autonumber"],
                             "%s: sequenceDiagram, then autonumber" % where)
            body = lines[len(head) + 2 :]
            lifelines = [m.group(1) for m in map(LIFELINE.match, body) if m]
            case.assertLessEqual(len(lifelines), MAX_LIFELINES, "%s: at most %d lifelines" % (where, MAX_LIFELINES))
            case.assertFalse([l for l in body if l.startswith("box ")], "%s: no box" % where)
            arrows = 0
            for line in body:
                arrow = ARROW.match(line)
                if arrow:
                    arrows += 1
                    case.assertNotEqual(arrow.group(1), arrow.group(2), "%s: a message to itself: %r" % (where, line))
                    case.assertLessEqual(len(arrow.group(3).strip()), MAX_MESSAGE,
                                         "%s: a message over %d characters: %r" % (where, MAX_MESSAGE, line))
                note = NOTE.match(line)
                if note:
                    case.assertNotIn(",", note.group(1), "%s: a phase note sits over one lifeline: %r" % (where, line))
                    case.assertLessEqual(len(note.group(2).strip()), MAX_NOTE,
                                         "%s: a phase name over %d characters: %r" % (where, MAX_NOTE, line))
            rest = text[match.end():]
            stop = re.search(r"^(```|#{1,6} )", rest, re.M)
            steps = rest[: stop.start()] if stop else rest
            case.assertEqual(sorted(covered_numbers(steps)), list(range(1, arrows + 1)),
                             "%s: the numbered steps under it name 1 to %d, each once" % (where, arrows))
        else:
            head = snip["flowchart"]
            case.assertEqual(raw[: len(head)], head, "%s opens with the flowchart snippet, word for word" % where)
            case.assertRegex(lines[len(head)] if len(lines) > len(head) else "", r"^flowchart (TB|LR)$",
                             "%s: flowchart TB or LR after the snippet" % where)
            for line in lines:
                if line.startswith("classDef "):
                    case.assertIn(line, snip["classDef"], "%s: a classDef not on the theme page: %r" % (where, line))
            subgraphs = re.findall(r"^\s*subgraph\s+(\w+)", code, re.M)
            classed = set()
            for ids, cls in re.findall(r"^\s*class\s+([\w,]+)\s+(\w+)\s*$", code, re.M):
                if cls == "zone":
                    classed.update(ids.split(","))
            case.assertEqual(sorted(set(subgraphs) - classed), [], "%s: every subgraph is class zone" % where)


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

    check_diagrams(case, text, page.name)

    if TRUST_PART in parts:
        body = part_body(text, TRUST_PART)
        for start in TRUST_LINES:
            case.assertRegex(body, r"(?m)^\s*(?:[-*]\s+)?(?:\*\*)?" + re.escape(start), "%s: %r line" % (page.name, start))
    return text
