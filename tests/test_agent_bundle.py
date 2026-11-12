"""Static checks for the Account_Brief Agent Script bundle, its sf agent test spec and its check scripts.

The structure checks parse the .agent file by indentation, so they test which actions, gates, bindings and
transitions sit inside which subagent, not only that a phrase appears somewhere in the file.
"""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "force-app/main/default/aiAuthoringBundles/Account_Brief"
AGENT = BUNDLE / "Account_Brief.agent"
SPEC = ROOT / "tests/agent/Account_Brief-testSpec.yaml"
AGENT_CHECK = ROOT / "scripts/agent-check.sh"
VALIDATE_ORG = ROOT / "scripts/validate-org.sh"

BUNDLE_META = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">'
    "<bundleType>AGENT</bundleType></AiAuthoringBundle>"
)

ID_GATE = '@variables.briefed_account_id is not None and @variables.briefed_account_id != ""'
OFF_TOPIC_LINE = "I can brief you on an account or answer questions about your CRM data."


class Node:
    """One non-blank line of the .agent file and the deeper-indented lines under it."""

    def __init__(self, line, indent, parent=None):
        self.line = line
        self.indent = indent
        self.parent = parent
        self.children = []

    def child(self, prefix):
        for node in self.children:
            if node.line.startswith(prefix):
                return node
        return None

    def walk(self):
        for node in self.children:
            yield node
            yield from node.walk()

    def ancestors(self):
        node = self.parent
        while node is not None:
            yield node
            node = node.parent

    def text(self):
        return "\n".join([self.line] + [n.line for n in self.walk()])


def parse_agent(text):
    root = Node("<root>", -1)
    stack = [root]
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        while stack[-1].indent >= indent:
            stack.pop()
        node = Node(raw.strip(), indent, stack[-1])
        stack[-1].children.append(node)
        stack.append(node)
    return root


def agent_tree():
    return parse_agent(AGENT.read_text(encoding="utf-8"))


def top_blocks(tree, keyword):
    """Map name -> node for top-level blocks such as `subagent <name>:`."""
    out = {}
    for node in tree.children:
        m = re.match(r"%s (\w+):$" % keyword, node.line)
        if m:
            out[m.group(1)] = node
    return out


def reasoning_actions(block):
    """Map name -> node for the actions a block exposes to the model (reasoning > actions)."""
    actions = block.child("reasoning:").child("actions:")
    out = {}
    for node in actions.children:
        m = re.match(r"(\w+):\s*(.+)$", node.line)
        if m:
            out[m.group(1)] = node
    return out


def action_value(node):
    return node.line.split(":", 1)[1].strip()


def spec_cases():
    """Split the spec into one text chunk per test case (no YAML library needed)."""
    text = SPEC.read_text(encoding="utf-8")
    body = text.split("testCases:", 1)[1]
    return [chunk for chunk in re.split(r"(?m)^  - ", body) if chunk.strip()]


class TestAccountBriefBundle(unittest.TestCase):
    def test_bundle_meta_has_no_target(self):
        text = (BUNDLE / "Account_Brief.bundle-meta.xml").read_text(encoding="utf-8")
        self.assertNotIn("<target>", text)
        self.assertEqual(re.sub(r">\s+<", "><", text.strip()), BUNDLE_META)

    def test_agent_names_all_three_apex_targets(self):
        text = AGENT.read_text(encoding="utf-8")
        for target in ("AccountBriefResolver", "AccountBriefGetAction", "ExploreAction"):
            self.assertIn('"apex://%s"' % target, text)

    def test_agent_config(self):
        text = AGENT.read_text(encoding="utf-8")
        self.assertIn('developer_name: "Account_Brief"', text)
        self.assertIn('agent_type: "AgentforceEmployeeAgent"', text)
        for name in ("briefed_account_id", "briefed_account_name"):
            self.assertIn(name + ": mutable string", text)

    def test_unused_last_status_is_gone(self):
        self.assertNotIn("last_status", AGENT.read_text(encoding="utf-8"))

    def test_no_character_for_character_wording(self):
        self.assertNotIn("character for character", AGENT.read_text(encoding="utf-8"))


class TestAgentStructure(unittest.TestCase):
    def setUp(self):
        self.tree = agent_tree()
        self.router = top_blocks(self.tree, "start_agent")["agent_router"]
        self.subagents = top_blocks(self.tree, "subagent")

    def test_router_only_transitions(self):
        actions = reasoning_actions(self.router)
        self.assertEqual(
            {name: action_value(node) for name, node in actions.items()},
            {
                "go_to_account_brief": "@utils.transition to @subagent.account_brief",
                "go_to_explore": "@utils.transition to @subagent.explore",
            },
        )

    def test_each_subagent_has_a_reclassify_transition_to_the_router(self):
        self.assertEqual(set(self.subagents), {"account_brief", "explore"})
        for name, block in self.subagents.items():
            actions = reasoning_actions(block)
            self.assertIn("reclassify", actions, name)
            node = actions["reclassify"]
            self.assertEqual(action_value(node), "@utils.transition to @subagent.agent_router", name)
            self.assertIsNotNone(node.child("description:"), name)

    def test_actions_sit_in_their_own_subagent(self):
        self.assertEqual(
            set(reasoning_actions(self.subagents["account_brief"])),
            {"resolve_account", "get_brief", "reclassify"},
        )
        self.assertEqual(
            set(reasoning_actions(self.subagents["explore"])),
            {"explore_data", "explore_data_for_account", "reclassify"},
        )

    def test_router_sends_a_candidate_pick_to_the_account_route(self):
        instructions = self.router.child("reasoning:").child("instructions:").text()
        self.assertRegex(instructions, r"candidate list[^\n]*-> account_brief")
        description = reasoning_actions(self.router)["go_to_account_brief"].child("description:").line
        self.assertIn("candidate list", description)

    def test_router_hint_uses_the_null_safe_gate(self):
        instructions = self.router.child("reasoning:").child("instructions:")
        self.assertIsNotNone(instructions.child("if %s:" % ID_GATE))

    def test_briefed_id_is_set_only_on_resolved(self):
        writers = [n for n in self.tree.walk() if n.line.startswith("set @variables.briefed_account_id =")]
        self.assertTrue(writers)
        resolve = reasoning_actions(self.subagents["account_brief"])["resolve_account"]
        from_output = [n for n in writers if n.line == "set @variables.briefed_account_id = @outputs.accountId"]
        self.assertEqual(len(from_output), 1)
        for node in writers:
            # Every writer of the Id lives in resolve_account's post-action block.
            self.assertIn(resolve, list(node.ancestors()), node.line)
        # The only copy of the resolver's Id sits directly under the RESOLVED branch.
        self.assertEqual(from_output[0].parent.line, 'if @outputs.status == "RESOLVED":')
        self.assertIs(from_output[0].parent.parent, resolve)
        # Anything else written to it (the else branch) is the empty string.
        for node in writers:
            if node is not from_output[0]:
                self.assertEqual(node.line, 'set @variables.briefed_account_id = ""')

    def test_get_brief_is_gated_on_a_non_null_non_empty_id(self):
        get_brief = reasoning_actions(self.subagents["account_brief"])["get_brief"]
        self.assertIsNotNone(get_brief.child("available when %s" % ID_GATE))
        self.assertIsNotNone(get_brief.child("with accountId = @variables.briefed_account_id"))

    def test_account_brief_follow_up_branches_on_the_stored_id(self):
        instructions = self.subagents["account_brief"].child("reasoning:").child("instructions:")
        branch = instructions.child("if %s:" % ID_GATE)
        self.assertIsNotNone(branch)
        siblings = instructions.children
        self.assertEqual(siblings[siblings.index(branch) + 1].line, "else:")

    def test_resolved_relays_get_brief_not_the_resolver(self):
        text = self.subagents["account_brief"].child("reasoning:").child("instructions:").text()
        self.assertNotIn("every status: RESOLVED", text)
        self.assertRegex(text, r"RESOLVED[^\n]*call get_brief in this same turn")
        self.assertRegex(text, r"AMBIGUOUS, NOT_FOUND or ERROR[^\n]*message text of resolve_account")

    def test_explore_keeps_the_unbound_action_available(self):
        actions = reasoning_actions(self.subagents["explore"])
        plain = actions["explore_data"]
        self.assertEqual(action_value(plain), "@actions.explore_data")
        self.assertFalse([n for n in plain.children if n.line.startswith("available when")])
        self.assertFalse([n for n in plain.children if "contextRecordId" in n.line])
        bound = actions["explore_data_for_account"]
        self.assertEqual(action_value(bound), "@actions.explore_data")
        self.assertIsNotNone(bound.child("available when %s" % ID_GATE))
        self.assertIsNotNone(bound.child("with contextRecordId = @variables.briefed_account_id"))

    def test_explore_context_record_id_is_a_string(self):
        definitions = self.subagents["explore"].child("actions:")
        inputs = definitions.child("explore_data:").child("inputs:")
        self.assertIsNotNone(inputs.child("contextRecordId: string"))

    def test_system_line_allows_the_router_off_topic_reply(self):
        system = self.tree.child("system:").child("instructions:").line
        self.assertIn(OFF_TOPIC_LINE, system)
        router = self.router.child("reasoning:").child("instructions:").text()
        self.assertIn(OFF_TOPIC_LINE, router)


class TestAccountBriefSpec(unittest.TestCase):
    def test_spec_has_ten_utterances(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"^\s*-?\s*utterance:", text, re.M)), 10)
        self.assertIn("subjectType: AGENT", text)
        self.assertIn("subjectName: Account_Brief", text)

    def test_spec_uses_no_missing_account(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertNotIn("Acme Corp", text)
        self.assertIn("Zzqxv Nonexistent Holdings", text)
        self.assertIn("001000000000000AAA", text)
        # A comment at the top of the spec says the account name must exist in the target org.
        head = text.split("name:", 1)[0]
        self.assertRegex(head, r"(?m)^#.*must exist in the target org")

    def test_off_topic_case_names_an_expected_topic(self):
        text = SPEC.read_text(encoding="utf-8")
        case = text.split("What is the weather in Paris today?", 1)[1]
        self.assertRegex(case, r"expectedTopic:\s*\S+")

    def case(self, utterance):
        found = [c for c in spec_cases() if c.startswith('utterance: "%s"' % utterance)]
        self.assertEqual(len(found), 1, utterance)
        return found[0]

    def test_off_topic_case_asserts_on_outcome_text(self):
        case = self.case("What is the weather in Paris today?")
        self.assertNotIn("expectedActions", case)
        self.assertIn(OFF_TOPIC_LINE, case.split("expectedOutcome:", 1)[1])

    def test_fake_id_case_expects_one_outcome(self):
        outcome = self.case("Brief me on 001000000000000AAA").split("expectedOutcome:", 1)[1]
        self.assertIn("no account matches", outcome)
        self.assertNotRegex(outcome, r"brief or says")

    def test_ambiguous_case(self):
        case = self.case("Brief me on United Oil")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- resolve_account\s*\n\s*expectedOutcome")
        for name in ("United Oil & Gas Corp.", "United Oil & Gas, Singapore", "United Oil & Gas, UK"):
            self.assertIn(name, case)

    def test_two_turn_follow_up_case(self):
        case = self.case("What about their open cases?")
        history = case.split("conversationHistory:", 1)[1]
        roles = re.findall(r"- role: (\w+)", history)
        self.assertEqual(roles, ["user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertRegex(case, r"expectedActions:\s*\n\s*- get_brief\s*\n")


class TestCheckScripts(unittest.TestCase):
    def test_agent_check_exists_and_is_executable(self):
        self.assertTrue(AGENT_CHECK.is_file())
        self.assertTrue(os.access(AGENT_CHECK, os.X_OK))

    def test_agent_check_compiles_and_validates_with_the_pinned_cli(self):
        text = AGENT_CHECK.read_text(encoding="utf-8")
        self.assertIn("index-agent.mjs", text)
        self.assertIn("setup-agentscript-sdk.mjs", text)
        self.assertIn('SF="/usr/local/bin/sf"', text)
        self.assertIn(
            '"$SF" agent validate authoring-bundle --json --api-name Account_Brief -o experimental', text
        )
        self.assertNotIn("/dev/null", text)

    def test_validate_org_keeps_stderr(self):
        self.assertNotIn("/dev/null", VALIDATE_ORG.read_text(encoding="utf-8"))


class TestValidateOrgSkipsAgentBundles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.force_app = os.path.join(self.tmp, "force-app")
        self.bundle_dir = os.path.join(self.force_app, "main/default/aiAuthoringBundles/Demo")
        os.makedirs(self.bundle_dir)
        with open(os.path.join(self.bundle_dir, "Demo.agent"), "w") as f:
            f.write("system:\n")
        # A fake sf that records its arguments and reports a successful check-only deploy.
        self.bin = os.path.join(self.tmp, "bin")
        os.makedirs(self.bin)
        self.args_file = os.path.join(self.tmp, "sf-args")
        fake_sf = os.path.join(self.bin, "sf")
        with open(fake_sf, "w") as f:
            f.write(
                "#!/bin/sh\nfor a in \"$@\"; do echo \"$a\"; done > '%s'\n"
                "echo '%s'\n" % (self.args_file, json.dumps({"status": 0, "result": {"success": True}}))
            )
        os.chmod(fake_sf, 0o755)

    def run_script(self):
        env = dict(
            os.environ,
            FORCE_APP_DIR=self.force_app,
            PATH=self.bin + os.pathsep + os.environ.get("PATH", ""),
        )
        return subprocess.run(["bash", str(VALIDATE_ORG)], env=env, capture_output=True, text=True, timeout=60)

    def test_skips_when_only_an_agent_bundle_has_files(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("validate-org: skipped", result.stdout)
        self.assertFalse(os.path.exists(self.args_file), "sf must not be called")

    def test_deploys_every_folder_but_the_agent_bundles(self):
        classes = os.path.join(self.force_app, "main/default/classes")
        os.makedirs(classes)
        for name in ("Foo.cls", "Foo.cls-meta.xml"):
            open(os.path.join(classes, name), "w").close()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with open(self.args_file) as f:
            args = f.read().splitlines()
        dirs = [args[i + 1] for i, a in enumerate(args) if a == "--source-dir"]
        self.assertEqual(dirs, [classes])
        self.assertNotIn("aiAuthoringBundles", "\n".join(args))


if __name__ == "__main__":
    unittest.main()
