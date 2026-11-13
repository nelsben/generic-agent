"""FR2 rename (BE-23): the old product name is gone from every living file, and the new names exist.

Historical records keep the names they were written with: docs/research, docs/reviews, docs/plans, agents
and spikes, plus the asset folder docs/assets (its pictures are recaptured by a later card). In the living
Markdown, image alt text and the text of a link that points into a historical folder or docs/assets may
still name the old product. If BE-21's verdict is NO-GO, the agent bundle, its test spec and
scripts/agent-check.sh keep the old bundle name too.

The old name is built from parts below so this file never matches its own search.
"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OLD_NAME = re.compile("account" + r"[ _-]?" + r"brief\b", re.IGNORECASE)
OLD_BUNDLE = "Account" + "_" + "Brief"
NEW_BUNDLE = "Customer_Summary"
VERDICT = ROOT / "docs/research/fr2-rename-go.md"

HISTORICAL = ("docs/research/", "docs/reviews/", "docs/plans/", "agents/", "spikes/")
EXEMPT_PREFIXES = HISTORICAL + ("docs/assets/",)

CLASSES = ROOT / "force-app/main/default/classes"
LWC = ROOT / "force-app/main/default/lwc"
BUNDLES = "aiAuthoringBundles"

# ![alt](target) and [text](target). The target is relative to the Markdown file.
IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]*)[^)]*\)")


def tracked_files():
    out = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT, check=True, capture_output=True
    ).stdout.decode("utf-8")
    return [p for p in out.split("\0") if p and (ROOT / p).is_file()]


def is_go():
    text = VERDICT.read_text(encoding="utf-8")
    plain = text.split("## Plain answer", 1)[-1][:600]
    if "NO-GO" in plain:
        return False
    return "**GO.**" in plain


def no_go_exempt(path):
    bundle_dir = "force-app/main/default/%s/%s/" % (BUNDLES, OLD_BUNDLE)
    spec = "tests/agent/%s-testSpec.yaml" % OLD_BUNDLE
    return path.startswith(bundle_dir) or path in (spec, "scripts/agent-check.sh")


def points_into_history(md_path, target):
    target = target.split("#", 1)[0]
    if not target or "://" in target:
        return False
    resolved = (ROOT / md_path).parent.joinpath(target).resolve()
    try:
        rel = resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return False
    return rel.startswith(EXEMPT_PREFIXES) or (rel + "/").startswith(EXEMPT_PREFIXES)


def strip_allowed_markdown(md_path, text):
    """Blank out image markup and links into historical folders, which may keep the old name."""
    text = IMAGE.sub("", text)

    def link(match):
        return "" if points_into_history(md_path, match.group(2)) else match.group(0)

    return LINK.sub(link, text)


def old_name_hits(go):
    hits = []
    for path in tracked_files():
        if path.startswith(EXEMPT_PREFIXES):
            continue
        if not go and no_go_exempt(path):
            continue
        if OLD_NAME.search(path):
            hits.append("%s (path)" % path)
            continue
        try:
            text = (ROOT / path).read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if path.endswith(".md"):
            text = strip_allowed_markdown(path, text)
        for number, line in enumerate(text.splitlines(), 1):
            if OLD_NAME.search(line):
                hits.append("%s:%d: %s" % (path, number, line.strip()[:120]))
    return hits


class OldNameGoneTest(unittest.TestCase):
    def test_verdict_is_readable(self):
        text = VERDICT.read_text(encoding="utf-8")
        self.assertIn("## Plain answer", text)

    def test_no_old_name_outside_historical_folders(self):
        hits = old_name_hits(is_go())
        self.assertEqual([], hits, "old product name still present:\n" + "\n".join(hits))

    def test_no_rename_slip_outside_historical_folders(self):
        # BE-23's mechanical rename left a bad past-tense form of the verb in several files. The pattern is built from parts so this file never matches itself.
        pattern = "summ" + "aryed|summ" + "arys\\b"
        result = subprocess.run(
            ["git", "grep", "-n", "-i", "-E", pattern, "--", ".",
             ":!docs/research", ":!docs/reviews", ":!docs/plans", ":!agents"],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(1, result.returncode, "rename slip still present:\n" + result.stdout + result.stderr)

    def test_markdown_allowance_is_narrow(self):
        old = "Account" + " " + "Brief"
        sample = (
            "![The %s panel](docs/assets/x.png)\n"
            "[%s notes](docs/research/a.md)\n"
            "[%s here](docs/patterns/01-route-gather-reduce.md)\n" % (old, old, old)
        )
        left = strip_allowed_markdown("README.md", sample)
        self.assertEqual(1, len(OLD_NAME.findall(left)), left)


class NewNamesExistTest(unittest.TestCase):
    def test_panel_controller_exists(self):
        self.assertTrue((CLASSES / "CustomerSummaryPanelController.cls").is_file())
        self.assertTrue((CLASSES / "CustomerSummaryPanelController.cls-meta.xml").is_file())

    def test_panel_component_exists(self):
        panel = LWC / "customerSummaryPanel"
        for name in ("customerSummaryPanel.js", "customerSummaryPanel.html", "customerSummaryPanel.js-meta.xml"):
            self.assertTrue((panel / name).is_file(), name)


class OneBundleNamedCustomerSummaryTest(unittest.TestCase):
    def bundles_named(self, name):
        return sorted(
            p for p in tracked_files()
            if re.search(r"(^|/)%s/%s/%s\.agent$" % (BUNDLES, name, name), p)
        )

    def test_at_most_one_customer_summary_bundle(self):
        found = self.bundles_named(NEW_BUNDLE)
        self.assertLessEqual(len(found), 1, "two bundles share the name %s: %s" % (NEW_BUNDLE, found))

    def test_the_one_bundle_lives_in_force_app(self):
        found = self.bundles_named(NEW_BUNDLE if is_go() else OLD_BUNDLE)
        self.assertEqual(1, len(found), found)
        self.assertTrue(found[0].startswith("force-app/"), found)


if __name__ == "__main__":
    unittest.main()
