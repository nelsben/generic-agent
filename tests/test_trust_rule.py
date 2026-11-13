"""The trust rule (FR2 principle 5) as a test.

Every non-test Apex class runs `with sharing`, every CRM read and write names its access mode, and each
system-context use carries a marker comment on the line above the class, statement or method that holds it:

    // system-context: <reason of at least five words that says why the user's own access is not enough>

The checker masks comments and string literals, then applies the rules below. Each rule is proved against small
inline Apex samples (TestRules), so the parser is tested, not just run over the real classes (TestRealClasses).
"""
import bisect
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ROOT / "force-app/main/default/classes"

MARKER = re.compile(r"//\s*system-context:\s*(.*?)\s*$")
MIN_REASON_WORDS = 5
ANNOTATION_LINE = re.compile(r"^\s*@\w+(\([^)]*\))?\s*$")
INLINE_MODE = re.compile(r"\bWITH\s+(USER_MODE|SYSTEM_MODE)\b", re.I)
WITH_SYSTEM = re.compile(r"\bWITH\s+SYSTEM_MODE\b", re.I)
ACCESS_LEVEL = re.compile(r"\bAccessLevel\s*\.\s*(USER_MODE|SYSTEM_MODE)\b", re.I)
ACCESS_SYSTEM = re.compile(r"\bAccessLevel\s*\.\s*SYSTEM_MODE\b", re.I)
QUERY_CALL = re.compile(
    r"\bDatabase\s*\.\s*(query|queryWithBinds|countQuery|countQueryWithBinds|getQueryLocator|getQueryLocatorWithBinds)\s*\(", re.I
)
DB_DML_CALL = re.compile(
    r"\bDatabase\s*\.\s*(insert|update|upsert|delete|undelete|merge|insertImmediate|deleteImmediate)\s*\(", re.I
)
DML_STATEMENT = re.compile(r"(?:^|(?<=[;{}]))\s*(insert|update|upsert|delete|undelete|merge)\s+(?=[A-Za-z_\[(:])", re.I)
AS_MODE = re.compile(r"\bas\s+(user|system)\b", re.I)
AS_SYSTEM = re.compile(r"\bas\s+system\b", re.I)
CONTROL = re.compile(r"^(if|for|while|else|try|catch|finally|switch|do)\b")
ASSIGN = re.compile(r"(?<![=!<>])=(?!=)")


def mask(src):
    """Blank out comments and string literals (newlines kept, so offsets and lines still match).

    Returns the masked text and the list of (line, reason) for every `// system-context:` comment."""
    out, markers = [], []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j == -1 else j
            m = MARKER.match(src[i:j])
            if m:
                markers.append((line, m.group(1)))
            out.append(" " * (j - i))
            i = j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j == -1 else j + 2
            chunk = src[i:j]
            out.append(re.sub(r"[^\n]", " ", chunk))
            line += chunk.count("\n")
            i = j
        elif c == "'":
            j = i + 1
            while j < n and src[j] != "'":
                j += 2 if src[j] == "\\" else 1
            j = min(j + 1, n)
            out.append("'" + " " * (j - i - 2) + "'" if j - i >= 2 else src[i:j])
            i = j
        else:
            if c == "\n":
                line += 1
            out.append(c)
            i += 1
    return "".join(out), markers


def match_close(text, start):
    """Offset just past the bracket that closes the one at text[start]."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    for i in range(start, len(text)):
        ch = text[i]
        if ch in pairs:
            stack.append(pairs[ch])
        elif stack and ch == stack[-1]:
            stack.pop()
            if not stack:
                return i + 1
    return len(text)


def covered_range(masked, line_starts, marker_line):
    """The (start, end) offsets the marker on `marker_line` covers: the next declaration or statement."""
    lines = masked.split("\n")
    idx = marker_line  # zero-based index of the line below the marker
    while idx < len(lines) and (not lines[idx].strip() or ANNOTATION_LINE.match(lines[idx])):
        idx += 1
    if idx >= len(lines):
        return None
    start = line_starts[idx]
    depth, i = 0, start
    while i < len(masked):
        ch = masked[i]
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif depth == 0 and ch == ";":
            return start, i + 1
        elif depth == 0 and ch == "{":
            head = masked[start:i].strip()
            if ASSIGN.search(head) and not CONTROL.match(head):
                i = match_close(masked, i)
                continue
            return start, match_close(masked, i)
        i += 1
    return start, len(masked)


def check_source(name, src):
    """Every trust-rule violation in one Apex source as (file, line, message)."""
    masked, markers = mask(src)
    newlines = [m.start() for m in re.finditer("\n", masked)]
    line_starts = [0] + [p + 1 for p in newlines]

    def line_of(offset):
        return bisect.bisect_right(newlines, offset - 1) + 1

    found = []

    def fail(offset, message):
        found.append((name, line_of(offset), message))

    ranges = []  # (marker line, start, end)
    for mline, reason in markers:
        if len(reason.split()) < MIN_REASON_WORDS:
            found.append((name, mline, "system-context marker needs a reason of at least %d words" % MIN_REASON_WORDS))
        rng = covered_range(masked, line_starts, mline)
        if rng is None:
            found.append((name, mline, "system-context marker covers nothing"))
        else:
            ranges.append((mline, rng[0], rng[1]))

    system_uses = []  # (offset, what)

    def covered(offset):
        return any(s <= offset < e for _, s, e in ranges)

    # Rule 1: a top-level class is `with sharing`, or carries a marker.
    depth_at, depth = [], 0
    for ch in masked:
        depth_at.append(depth)
        depth += 1 if ch == "{" else -1 if ch == "}" else 0
    for m in re.finditer(r"\bclass\s+\w+", masked):
        if depth_at[m.start()] != 0:
            continue
        cut = max(masked.rfind("}", 0, m.start()), masked.rfind(";", 0, m.start()))
        header = masked[cut + 1:m.start()]
        if not re.search(r"\bwith\s+sharing\b", header, re.I):
            system_uses.append((m.start(), "a top-level class that is not `with sharing`"))

    # Rule 2: an inline query names its mode.
    for m in re.finditer(r"\[\s*SELECT\b", masked, re.I):
        text = masked[m.start():match_close(masked, m.start())]
        if not INLINE_MODE.search(text):
            fail(m.start(), "inline query has neither WITH USER_MODE nor WITH SYSTEM_MODE")
        elif WITH_SYSTEM.search(text):
            system_uses.append((m.start(), "an inline query WITH SYSTEM_MODE"))

    # Rules 3 and 4 (Database methods): the call passes an AccessLevel.
    for regex, what in ((QUERY_CALL, "Database.%s passes no AccessLevel"), (DB_DML_CALL, "Database.%s passes no AccessLevel")):
        for m in regex.finditer(masked):
            args = masked[m.end() - 1:match_close(masked, m.end() - 1)]
            if not ACCESS_LEVEL.search(args):
                fail(m.start(), what % m.group(1))
            elif ACCESS_SYSTEM.search(args):
                system_uses.append((m.start(), "Database.%s in system mode" % m.group(1)))

    # Rule 4 (DML statements): `as user` or `as system`.
    for m in DML_STATEMENT.finditer(masked):
        end = masked.find(";", m.end())
        text = masked[m.start(1):end if end != -1 else len(masked)]
        if not AS_MODE.search(text):
            fail(m.start(1), "%s statement has neither `as user` nor `as system`" % m.group(1).lower())
        elif AS_SYSTEM.search(text):
            system_uses.append((m.start(1), "a %s statement as system" % m.group(1).lower()))

    # Rule 5: anything in system mode has a marker covering it.
    for offset, what in system_uses:
        if not covered(offset):
            fail(offset, "%s has no `// system-context: <reason>` marker" % what)

    # A marker that covers no system-mode use is stale: the list of exceptions must stay exact.
    for mline, s, e in ranges:
        if not any(s <= off < e for off, _ in system_uses):
            found.append((name, mline, "system-context marker covers no system-mode use"))

    return sorted(found, key=lambda f: (f[1], f[2]))


def class_files():
    return sorted(p for p in CLASSES.glob("*.cls") if not p.name.endswith("Test.cls"))


def check_all():
    found = []
    for path in class_files():
        found.extend(check_source(path.name, path.read_text(encoding="utf-8")))
    return found


def markers_in(src):
    return mask(src)[1]


class TestRealClasses(unittest.TestCase):
    def test_classes_are_found(self):
        self.assertGreater(len(class_files()), 10)

    def test_every_class_follows_the_trust_rule(self):
        found = check_all()
        self.assertEqual(found, [], "\n" + "\n".join("%s:%d: %s" % f for f in found))


GOOD_QUERY = "public with sharing class A { void m(Id i) { List<Account> r = [SELECT Id FROM Account WHERE Id = :i WITH USER_MODE]; } }"


def rules(src):
    return [message for _, _, message in check_source("A.cls", src)]


class TestRules(unittest.TestCase):
    def test_clean_class_passes(self):
        self.assertEqual(check_source("A.cls", GOOD_QUERY), [])

    # Rule 1: sharing
    def test_class_without_sharing_keyword_fails(self):
        self.assertEqual(len(rules("public class A {}")), 1)
        self.assertIn("not `with sharing`", rules("public class A {}")[0])

    def test_without_sharing_and_inherited_sharing_fail(self):
        self.assertTrue(rules("public without sharing class A {}"))
        self.assertTrue(rules("public inherited sharing class A {}"))

    def test_inner_class_needs_no_sharing(self):
        self.assertEqual(rules("public with sharing class A { public class B {} }"), [])

    def test_class_marker_covers_a_class_that_is_not_with_sharing(self):
        src = "// system-context: the batch reads every rep's rows for the nightly roll up\npublic without sharing class A {}"
        self.assertEqual(rules(src), [])

    def test_with_sharing_in_a_comment_does_not_count(self):
        self.assertTrue(rules("// with sharing\npublic class A {}"))

    # Rule 2: inline queries
    def test_inline_query_without_mode_fails_with_its_line(self):
        src = "public with sharing class A {\n  void m() {\n    List<Account> r = [SELECT Id FROM Account];\n  }\n}"
        found = check_source("A.cls", src)
        self.assertEqual([(f[1], "neither WITH USER_MODE" in f[2]) for f in found], [(3, True)])

    def test_multi_line_inline_query_with_mode_passes(self):
        src = "public with sharing class A {\n void m() {\n  Integer n = [\n   SELECT COUNT()\n   FROM Case\n   WITH USER_MODE\n  ];\n }\n}"
        self.assertEqual(rules(src), [])

    def test_with_security_enforced_is_not_an_explicit_mode(self):
        src = "public with sharing class A { void m() { Integer n = [SELECT COUNT() FROM Case WITH SECURITY_ENFORCED]; } }"
        self.assertEqual(len(rules(src)), 1)

    def test_select_inside_a_string_or_comment_is_not_an_inline_query(self):
        src = "public with sharing class A { String s = '[SELECT Id FROM Account]'; /* [SELECT Id FROM Account] */ }"
        self.assertEqual(rules(src), [])

    def test_subscript_is_not_an_inline_query(self):
        self.assertEqual(rules("public with sharing class A { Object o = items[0]; }"), [])

    # Rule 3: Database query calls
    def test_database_query_calls_without_access_level_fail(self):
        for call in ("query(s)", "queryWithBinds(s, b)", "countQuery(s)", "countQueryWithBinds(s, b)", "getQueryLocator(s)"):
            src = "public with sharing class A { void m() { Object o = Database.%s; } }" % call
            self.assertEqual(len(rules(src)), 1, call)

    def test_database_query_calls_with_user_mode_pass(self):
        for call in ("query(s, AccessLevel.USER_MODE)", "queryWithBinds(s, b, AccessLevel.USER_MODE)", "getQueryLocator(s, AccessLevel.USER_MODE)"):
            src = "public with sharing class A { void m() { Object o = Database.%s; } }" % call
            self.assertEqual(rules(src), [], call)

    def test_access_level_in_a_nested_call_is_still_seen(self):
        src = "public with sharing class A { void m() { Object o = Database.queryWithBinds(f(s), new Map<String, Object>{ 'a' => 1 }, AccessLevel.USER_MODE); } }"
        self.assertEqual(rules(src), [])

    # Rule 4: DML
    def test_dml_statement_without_mode_fails(self):
        for stmt in ("insert rows;", "update rows;", "delete rows;", "upsert rows;", "undelete rows;", "merge a b;"):
            src = "public with sharing class A { void m() { %s } }" % stmt
            self.assertEqual(len(rules(src)), 1, stmt)

    def test_dml_statement_with_user_mode_passes(self):
        self.assertEqual(rules("public with sharing class A { void m() { insert as user rows; update as user rows; } }"), [])

    def test_dml_after_a_brace_or_semicolon_is_seen(self):
        src = "public with sharing class A { void m() { if (x) { delete rows; } a = 1; update rows; } }"
        self.assertEqual(len(rules(src)), 2)

    def test_method_named_update_is_not_dml(self):
        self.assertEqual(rules("public with sharing class A { void m() { svc.update(rows); other(); } }"), [])

    def test_database_dml_without_access_level_fails(self):
        src = "public with sharing class A { void m() { Database.insert(rows, true); Database.delete(rows); } }"
        self.assertEqual(len(rules(src)), 2)

    def test_database_dml_with_user_mode_passes(self):
        src = "public with sharing class A { void m() { Database.insert(rows, true, AccessLevel.USER_MODE); } }"
        self.assertEqual(rules(src), [])

    # Rule 5: system mode needs a marker
    def test_system_mode_query_without_marker_fails(self):
        src = "public with sharing class A { void m() { Integer n = [SELECT COUNT() FROM Case WITH SYSTEM_MODE]; } }"
        self.assertIn("no `// system-context", rules(src)[0])

    def test_system_mode_without_marker_in_every_form_fails(self):
        forms = (
            "Object o = Database.query(s, AccessLevel.SYSTEM_MODE);",
            "Database.insert(rows, true, AccessLevel.SYSTEM_MODE);",
            "insert as system rows;",
            "Object o = [SELECT Id FROM Case WITH SYSTEM_MODE];",
        )
        for stmt in forms:
            src = "public with sharing class A { void m() { %s } }" % stmt
            self.assertEqual(len(rules(src)), 1, stmt)

    def test_statement_marker_covers_that_statement_only(self):
        src = (
            "public with sharing class A {\n void m() {\n"
            "  // system-context: the product's own memory rows; reps have read-only access\n"
            "  insert as system a;\n"
            "  delete as system b;\n }\n}"
        )
        found = check_source("A.cls", src)
        self.assertEqual([f[1] for f in found], [5])

    def test_marker_above_a_multi_line_statement_covers_all_of_it(self):
        src = (
            "public with sharing class A {\n void m() {\n"
            "  // system-context: the product's own memory rows; reps have read-only access\n"
            "  List<X> r = [\n   SELECT Id FROM X\n   WITH SYSTEM_MODE\n  ];\n }\n}"
        )
        self.assertEqual(rules(src), [])

    def test_method_marker_covers_the_whole_method_past_an_annotation(self):
        src = (
            "public with sharing class A {\n"
            " /** doc */\n"
            " // system-context: the product's own memory rows; reps have read-only access\n"
            " @TestVisible\n"
            " private static void m(Id a,\n   Id b) {\n"
            "  insert as system a;\n  Database.delete(b, false, AccessLevel.SYSTEM_MODE);\n }\n"
            " void other() { delete as system c; }\n}"
        )
        found = check_source("A.cls", src)
        self.assertEqual([f[1] for f in found], [10])

    def test_class_marker_covers_every_method(self):
        src = (
            "// system-context: the product's own memory rows; reps have read-only access\n"
            "public with sharing class A {\n void m() { insert as system a; }\n void n() { delete as system b; }\n}"
        )
        self.assertEqual(rules(src), [])

    def test_marker_must_sit_on_the_line_above_not_further_up(self):
        src = (
            "public with sharing class A {\n"
            " // system-context: the product's own memory rows; reps have read-only access\n"
            " void m() { }\n"
            " void n() { insert as system a; }\n}"
        )
        messages = rules(src)
        self.assertEqual(len(messages), 2)
        self.assertTrue(any("covers no system-mode use" in m for m in messages))
        self.assertTrue(any("no `// system-context" in m for m in messages))

    def test_marker_reason_needs_five_words(self):
        src = (
            "public with sharing class A { void m() {\n"
            " // system-context: own rows only\n"
            " insert as system a;\n } }"
        )
        self.assertEqual(len(rules(src)), 1)
        self.assertIn("at least 5 words", rules(src)[0])

    def test_marker_with_five_words_passes(self):
        src = (
            "public with sharing class A { void m() {\n"
            " // system-context: reps only have read access\n"
            " insert as system a;\n } }"
        )
        self.assertEqual(rules(src), [])

    def test_marker_that_covers_no_system_use_is_stale(self):
        src = (
            "public with sharing class A { void m() {\n"
            " // system-context: reps only have read access here\n"
            " insert as user a;\n } }"
        )
        self.assertIn("covers no system-mode use", rules(src)[0])

    def test_markers_are_listed_with_their_lines(self):
        src = "a\n// system-context: reps only have read access\nb"
        self.assertEqual(markers_in(src), [(2, "reps only have read access")])


if __name__ == "__main__":
    unittest.main()
