import json
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FOLDERS = [
    "force-app/main/default/aiAuthoringBundles",
    "force-app/main/default/flows",
    "force-app/main/default/classes",
    "force-app/main/default/genAiPromptTemplates",
    "force-app/main/default/permissionsets",
]


class TestSfdxProject(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ROOT, "sfdx-project.json"), encoding="utf-8") as f:
            self.project = json.load(f)

    def test_package_directories(self):
        self.assertEqual(
            self.project["packageDirectories"],
            [{"path": "force-app", "default": True}],
        )

    def test_name_and_namespace(self):
        self.assertEqual(self.project["name"], "generic-agent")
        self.assertEqual(self.project["namespace"], "")

    def test_login_url_and_api_version(self):
        self.assertEqual(self.project["sfdcLoginUrl"], "https://login.salesforce.com")
        self.assertEqual(self.project["sourceApiVersion"], "68.0")

    def test_metadata_folders_exist(self):
        for folder in FOLDERS:
            with self.subTest(folder=folder):
                self.assertTrue(
                    os.path.isdir(os.path.join(ROOT, folder)),
                    f"missing folder: {folder}",
                )


if __name__ == "__main__":
    unittest.main()
