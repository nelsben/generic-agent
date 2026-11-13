"""The MCP outside door keeps its metadata in its own, non-default package folder (OPS-23).

mcp-door/ holds what was retrieved from agent-probe: the McpServerDefinition and the External
Client App. It must never carry a consumer key or secret, a record or org Id, an email or an
org host, so it is safe to commit and to deploy on purpose into another org.
"""

import json
import os
import re
import unittest
import xml.etree.ElementTree as ET

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


def server_definition_path():
    return os.path.join(DOOR, "main", "default", "mcpServerDefinitions",
                        "CustomerSummaryMcp.mcpServerDefinition-meta.xml")


def server_tools():
    """Each <tools> element of the server definition as a flat dict of its child texts."""
    ns = "{http://soap.sforce.com/2006/04/metadata}"
    root = ET.parse(server_definition_path()).getroot()
    tools = []
    for el in root.findall(ns + "tools"):
        tool = {child.tag[len(ns):]: (child.text or "") for child in el if len(child) == 0}
        api = el.find(ns + "apiDefinition")
        if api is not None:
            for child in api:
                tool[child.tag[len(ns):]] = child.text or ""
        tools.append(tool)
    return tools


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
        self.assertEqual(salesforce_ids("CustomerSummaryResolver apex-CustomerSummaryGetAction"), [])
        self.assertEqual(salesforce_ids("resolve_account mcp_api refresh_token"), [])


class TestDoorMetadata(unittest.TestCase):
    def test_folder_holds_the_server_definition(self):
        path = os.path.join(DOOR, "main", "default", "mcpServerDefinitions")
        self.assertTrue(os.path.isdir(path), "missing mcp-door/main/default/mcpServerDefinitions")
        defs = [f for f in os.listdir(path) if f.endswith(".mcpServerDefinition-meta.xml")]
        self.assertEqual(len(defs), 1, defs)

    def test_server_is_customer_summary_mcp(self):
        path = os.path.join(DOOR, "main", "default", "mcpServerDefinitions")
        self.assertEqual(os.listdir(path), ["CustomerSummaryMcp.mcpServerDefinition-meta.xml"])

    def test_tools_are_the_three_apex_actions_and_no_agent(self):
        # OPS-31: the door's tools are Apex actions (resolve, summary, ask anything through the
        # explorer). The optional agent is not a tool, so no tool points at an agent (ag:...).
        tools = server_tools()
        self.assertEqual(
            sorted((t["toolName"], t["apiIdentifier"], t["operation"]) for t in tools),
            [
                ("ask_anything", "aa:apex-ExploreAction", "ExploreAction"),
                ("get_account_summary", "aa:apex-CustomerSummaryGetAction", "CustomerSummaryGetAction"),
                ("resolve_account", "aa:apex-CustomerSummaryResolver", "CustomerSummaryResolver"),
            ],
        )
        for tool in tools:
            with self.subTest(tool=tool["toolName"]):
                self.assertEqual(tool["apiSource"], "API_CATALOG")
                self.assertTrue(tool["apiIdentifier"].startswith("aa:apex-"), tool["apiIdentifier"])
        with open(server_definition_path(), encoding="utf-8") as f:
            text = f.read()
        self.assertNotIn("ag:", text, "an agent is listed as a tool")
        self.assertNotIn("agent", text.lower(), "the server or a tool still points clients at the agent")

    def test_every_tool_has_its_own_client_description(self):
        # Every tool carries its own description, so the agent-facing Apex wording
        # ("Relay the answer verbatim") does not reach MCP clients.
        for tool in server_tools():
            with self.subTest(tool=tool["toolName"]):
                text = tool.get("descriptionOverride") or ""
                self.assertTrue(text.strip(), "each tool needs a descriptionOverride")
                self.assertNotIn("verbatim", text.lower())
                self.assertNotIn("'", text, "an apostrophe comes back HTML-escaped")

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


class TestClientApp(unittest.TestCase):
    def test_description_names_the_scopes_as_the_metadata_does(self):
        # OPS-23 left the description naming mcp_api and refresh_token while the metadata
        # carries MCP and RefreshToken. The description now uses the metadata's names.
        base = os.path.join(DOOR, "main", "default")
        with open(os.path.join(base, "extlClntAppOauthSettings",
                               "CustomerSummaryMcpClient.ecaOauth-meta.xml"), encoding="utf-8") as f:
            scopes_text = re.search(r"<commaSeparatedOauthScopes>([^<]+)</commaSeparatedOauthScopes>",
                                    f.read()).group(1)
        scopes = sorted(s.strip() for s in scopes_text.split(","))
        self.assertEqual(scopes, ["MCP", "RefreshToken"])
        with open(os.path.join(base, "externalClientApps", "CustomerSummaryMcpClient.eca-meta.xml"),
                  encoding="utf-8") as f:
            description = re.search(r"<description>([^<]+)</description>", f.read()).group(1)
        for scope in scopes:
            self.assertRegex(description, r"(?<![A-Za-z_])%s(?![A-Za-z_])" % scope)
        for other in ("mcp_api", "refresh_token"):
            self.assertNotIn(other, description)
        self.assertIn("CustomerSummaryMcp", description)


if __name__ == "__main__":
    unittest.main()
