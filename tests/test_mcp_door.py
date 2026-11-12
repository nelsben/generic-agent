"""The MCP outside door keeps its metadata in its own, non-default package folder (OPS-23).

mcp-door/ holds what was retrieved from agent-probe: the McpServerDefinition and the External
Client App. It must never carry a consumer key or secret, a record or org Id, an email or an
org host, so it is safe to commit and to deploy on purpose into another org.
"""

import json
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOOR = os.path.join(ROOT, "mcp-door")

SECRET_WORDS = ("consumerKey", "consumerSecret", "clientSecret")
# A Salesforce Id: a standalone run of exactly 15 or 18 letters and digits. Real Ids carry
# several digits (key prefix, instance, the reserved 0), so a run needs 3 or more digits to count.
SF_ID_RUN = re.compile(r"(?<![A-Za-z0-9])(?:[A-Za-z0-9]{18}|[A-Za-z0-9]{15})(?![A-Za-z0-9])")


def salesforce_ids(text):
    return [run for run in SF_ID_RUN.findall(text) if sum(c.isdigit() for c in run) >= 3]

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
ORG_HOST = re.compile(r"my\.salesforce\.com", re.IGNORECASE)


def door_files():
    out = []
    for base, _dirs, files in os.walk(DOOR):
        for name in files:
            out.append(os.path.join(base, name))
    return sorted(out)


class TestPackageDirectories(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ROOT, "sfdx-project.json"), encoding="utf-8") as f:
            self.dirs = json.load(f)["packageDirectories"]

    def test_force_app_is_the_only_default(self):
        defaults = [d["path"] for d in self.dirs if d.get("default") is True]
        self.assertEqual(defaults, ["force-app"])

    def test_mcp_door_is_a_non_default_package_directory(self):
        door = [d for d in self.dirs if d["path"] == "mcp-door"]
        self.assertEqual(len(door), 1, "mcp-door is not in packageDirectories")
        self.assertIs(door[0].get("default"), False)

    def test_force_app_comes_first(self):
        self.assertEqual(self.dirs[0]["path"], "force-app")


class TestGuards(unittest.TestCase):
    def test_id_detector(self):
        # Id-shaped samples are built at run time, so this file holds no Id itself.
        long_id = "1g1" + "0" * 12 + "AAA"
        short_id = "0H4" + "gK" + "0" * 5 + "1aBcD"
        self.assertEqual(salesforce_ids("<id>%s</id>" % long_id), [long_id])
        self.assertEqual(salesforce_ids("x %s y" % short_id), [short_id])
        self.assertEqual(salesforce_ids("AccountBriefResolver apex-AccountBriefGetAction"), [])
        self.assertEqual(salesforce_ids("resolve_account mcp_api refresh_token"), [])


class TestDoorMetadata(unittest.TestCase):
    def test_folder_holds_the_server_definition(self):
        path = os.path.join(DOOR, "main", "default", "mcpServerDefinitions")
        self.assertTrue(os.path.isdir(path), "missing mcp-door/main/default/mcpServerDefinitions")
        defs = [f for f in os.listdir(path) if f.endswith(".mcpServerDefinition-meta.xml")]
        self.assertEqual(len(defs), 1, defs)

    def test_server_definition_names_the_three_tools(self):
        path = os.path.join(DOOR, "main", "default", "mcpServerDefinitions")
        self.assertTrue(os.path.isdir(path))
        (name,) = [f for f in os.listdir(path) if f.endswith(".mcpServerDefinition-meta.xml")]
        with open(os.path.join(path, name), encoding="utf-8") as f:
            text = f.read()
        tools = re.findall(r"<toolName>([^<]+)</toolName>", text)
        self.assertEqual(sorted(tools), ["ask_account_brief", "get_account_brief", "resolve_account"])
        # Every tool carries its own description, so the agent-facing Apex and agent wording
        # ("Relay the answer verbatim") does not reach MCP clients.
        overrides = re.findall(r"<descriptionOverride>([^<]+)</descriptionOverride>", text)
        self.assertEqual(len(overrides), 3, "each tool needs a descriptionOverride")
        for text_ in overrides:
            self.assertNotIn("verbatim", text_.lower())

    def test_no_secrets_ids_emails_or_org_hosts(self):
        files = door_files()
        self.assertTrue(files, "mcp-door/ holds no files")
        for path in files:
            rel = os.path.relpath(path, ROOT)
            with open(path, encoding="utf-8") as f:
                text = f.read()
            with self.subTest(file=rel):
                for word in SECRET_WORDS:
                    self.assertNotIn(word, text)
                self.assertEqual(salesforce_ids(text), [], "a Salesforce Id")
                self.assertIsNone(EMAIL.search(text), "an email address")
                self.assertIsNone(ORG_HOST.search(text), "a my.salesforce.com host")
                for url in re.findall(r"https?://[^\s<\"']+", text):
                    self.assertNotIn("?", url, "a URL with a query string")


if __name__ == "__main__":
    unittest.main()
