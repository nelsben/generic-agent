import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "validate-org.sh")

FOLDERS = [
    "main/default/aiAuthoringBundles",
    "main/default/classes",
    "main/default/flows",
    "main/default/genAiPromptTemplates",
    "main/default/permissionsets",
]


class TestValidateOrg(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.force_app = os.path.join(self.tmp, "force-app")
        for folder in FOLDERS:
            path = os.path.join(self.force_app, folder)
            os.makedirs(path)
            open(os.path.join(path, ".gitkeep"), "w").close()

        # A fake sf that records any call, so the test can prove sf was never run.
        self.bin = os.path.join(self.tmp, "bin")
        os.makedirs(self.bin)
        self.marker = os.path.join(self.tmp, "sf-called")
        fake_sf = os.path.join(self.bin, "sf")
        with open(fake_sf, "w") as f:
            f.write("#!/bin/sh\ntouch '%s'\nexit 99\n" % self.marker)
        os.chmod(fake_sf, 0o755)

    def test_skips_when_force_app_holds_only_gitkeep(self):
        env = dict(
            os.environ,
            FORCE_APP_DIR=self.force_app,
            PATH=self.bin + os.pathsep + os.environ.get("PATH", ""),
        )
        result = subprocess.run(
            ["bash", SCRIPT],
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("validate-org: skipped (no metadata in force-app)", result.stdout)
        self.assertFalse(os.path.exists(self.marker), "sf must not be called")


if __name__ == "__main__":
    unittest.main()
