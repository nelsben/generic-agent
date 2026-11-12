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
RESOLVER = ROOT / "force-app/main/default/classes/AccountBriefResolver.cls"

BUNDLE_META = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">'
    "<bundleType>AGENT</bundleType></AiAuthoringBundle>"
)

ID_GATE = '@variables.briefed_account_id is not None and @variables.briefed_account_id != ""'
OFF_TOPIC_LINE = "I can brief you on an account or answer questions about your CRM data."
NOT_FOUND_TAIL = "Try a fuller or different account name."


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
        # explore_data runs deterministically, so the model is offered only the way back to the router.
        self.assertEqual(set(reasoning_actions(self.subagents["explore"])), {"reclassify"})

    def test_router_sends_a_candidate_pick_to_the_account_route(self):
        instructions = self.router.child("reasoning:").child("instructions:").text()
        self.assertRegex(instructions, r"candidate list[^\n]*-> account_brief")
        description = reasoning_actions(self.router)["go_to_account_brief"].child("description:").line
        self.assertIn("candidate list", description)

    def test_router_hint_uses_the_null_safe_gate(self):
        instructions = self.router.child("reasoning:").child("instructions:")
        self.assertIsNotNone(instructions.child("if %s:" % ID_GATE))

    def test_resolve_account_sets_the_briefed_account_unconditionally(self):
        # Studio preview 2026-11-11: the conditional post-action set never fired. AccountBriefResolver returns a
        # blank accountId and accountName unless RESOLVED, so an unconditional set also clears the briefed account
        # on NOT_FOUND and AMBIGUOUS.
        resolve = reasoning_actions(self.subagents["account_brief"])["resolve_account"]
        expected = {
            "briefed_account_id": "set @variables.briefed_account_id = @outputs.accountId",
            "briefed_account_name": "set @variables.briefed_account_name = @outputs.accountName",
        }
        for name, line in expected.items():
            writers = [n for n in self.tree.walk() if n.line.startswith("set @variables.%s =" % name)]
            self.assertEqual([n.line for n in writers], [line], name)
            # The one writer sits directly under the resolve_account binding, not under a branch.
            self.assertIs(writers[0].parent, resolve, name)
        self.assertFalse([n for n in resolve.walk() if n.line.startswith(("if ", "else"))])
        self.assertNotIn("@outputs.status", resolve.text())

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

    def test_explore_runs_explore_data_deterministically(self):
        explore = self.subagents["explore"]
        before = explore.child("before_reasoning:")
        self.assertIsNotNone(before)
        runs = [n for n in explore.walk() if n.line.startswith("run @actions.")]
        self.assertEqual([n.line for n in runs], ["run @actions.explore_data"])
        run = runs[0]
        self.assertIs(run.parent, before)
        # The run gets the user's message itself, never a model-filled slot, and no open record.
        self.assertEqual(
            [n.line for n in run.children],
            [
                "with question = @system_variables.user_input",
                "with history = @variables.explore_history",
                "set @variables.explore_answer = @outputs.answer",
                "set @variables.explore_history = @outputs.history",
            ],
        )
        # The answer is cleared first, so a failed run never relays an earlier answer.
        siblings = before.children
        self.assertEqual(siblings[siblings.index(run) - 1].line, 'set @variables.explore_answer = ""')
        self.assertIn("explore_answer: mutable string = \"\"", AGENT.read_text(encoding="utf-8"))
        # The reply is the stored answer, verbatim.
        instructions = explore.child("reasoning:").child("instructions:").text()
        self.assertIn("{!@variables.explore_answer}", instructions)
        self.assertIn("verbatim", instructions)
        # Nothing binds contextRecordId and nothing exposes explore_data to the model.
        self.assertNotIn("with contextRecordId", explore.text())
        self.assertNotIn("explore_data_for_account", AGENT.read_text(encoding="utf-8"))

    def test_explore_context_record_id_is_a_record_id_object(self):
        # Studio backend validation rejects `string` and `id` for the Apex Id invocable input.
        definitions = self.subagents["explore"].child("actions:")
        inputs = definitions.child("explore_data:").child("inputs:")
        self.assertIsNone(inputs.child("contextRecordId: string"))
        field = inputs.child("contextRecordId:")
        self.assertEqual(field.line, "contextRecordId: object")
        self.assertEqual(
            [n.line for n in field.children],
            [
                'description: "The Id of the record the user has open, if any."',
                'complex_data_type_name: "lightning__recordIdType"',
                "is_required: False",
            ],
        )

    def test_router_sends_org_wide_questions_to_explore_before_briefed_follow_ups(self):
        instructions = self.router.child("reasoning:").child("instructions:")
        text = instructions.text()
        org_wide = re.search(r"names no account and asks an org-wide count, list[^\n]*-> explore", text)
        follow_up = re.search(r"refers to the account already briefed[^\n]*-> account_brief", text)
        self.assertIsNotNone(org_wide)
        self.assertIsNotNone(follow_up)
        self.assertLess(org_wide.start(), follow_up.start())
        self.assertIn("How many open opportunities are there?", text)
        self.assertRegex(text, r"even when an account has been briefed earlier in the conversation")
        self.assertIn('"their open cases"', text)
        self.assertIn('"what about them"', text)
        # The hint shown once an account is briefed keeps the same order.
        hint = instructions.child("if %s:" % ID_GATE).text()
        self.assertLess(hint.index("goes to explore"), hint.index("goes to account_brief"))
        actions = reasoning_actions(self.router)
        self.assertIn("even when an account has been briefed", actions["go_to_explore"].child("description:").line)
        self.assertIn("Not for an org-wide", actions["go_to_account_brief"].child("description:").line)

    def test_account_brief_hands_org_wide_questions_back(self):
        text = self.subagents["account_brief"].child("reasoning:").child("instructions:").text()
        self.assertRegex(text, r"names no account and asks an org-wide count[^\n]*use reclassify")

    def test_account_brief_never_falls_back_to_an_earlier_account(self):
        instructions = self.subagents["account_brief"].child("reasoning:").child("instructions:")
        branch = instructions.child("if %s:" % ID_GATE)
        siblings = instructions.children
        unresolved = siblings[siblings.index(branch) + 1].text()
        self.assertIn("named most recently", unresolved)
        self.assertIn("never an account named before it", unresolved)

    def test_explore_history_is_kept_bound_and_cleared_when_a_brief_starts(self):
        # N3: the last explore question and answer reach the next explore run, and a brief clears them.
        self.assertIn('explore_history: mutable string = ""', AGENT.read_text(encoding="utf-8"))
        definitions = self.subagents["explore"].child("actions:").child("explore_data:")
        field = definitions.child("inputs:").child("history:")
        self.assertEqual(field.line, "history: string")
        self.assertIsNotNone(field.child("is_required: False"))
        self.assertEqual(definitions.child("outputs:").child("history:").line, "history: string")
        run = [n for n in self.subagents["explore"].walk() if n.line == "run @actions.explore_data"][0]
        brief_actions = reasoning_actions(self.subagents["account_brief"])
        clear = 'set @variables.explore_history = ""'
        writers = [n for n in self.tree.walk() if n.line.startswith("set @variables.explore_history =")]
        self.assertEqual(
            sorted((n.parent.line, n.line) for n in writers),
            sorted(
                [
                    (run.line, "set @variables.explore_history = @outputs.history"),
                    (brief_actions["resolve_account"].line, clear),
                    (brief_actions["get_brief"].line, clear),
                ]
            ),
        )
        # The explore run never clears the history it is about to read.
        before = self.subagents["explore"].child("before_reasoning:")
        self.assertNotIn(clear, [n.line for n in before.children])

    def test_rule_4_applies_only_after_an_account_brief_reply(self):
        instructions = self.router.child("reasoning:").child("instructions:")
        text = instructions.text()
        rule4 = re.search(r"(?m)^4\) .*$", text).group(0)
        self.assertIn("Only when the previous reply came from account_brief", rule4)
        self.assertRegex(rule4, r"After an explore answer[^\n]*goes to explore")
        # Once an explore answer is held, the router is told rule 4 does not apply.
        gate = 'if @variables.explore_history is not None and @variables.explore_history != "":'
        branch = instructions.child(gate)
        self.assertIsNotNone(branch)
        self.assertIn("rule 4 does not apply", branch.text())
        hint = instructions.child("if %s:" % ID_GATE).text()
        self.assertIn("only under rule 4", hint)
        description = reasoning_actions(self.router)["go_to_account_brief"].child("description:").line
        self.assertIn("right after an account_brief reply", description)
        # explore keeps a pronoun follow-up about its own answer instead of handing it back.
        explore = self.subagents["explore"].child("reasoning:").child("instructions:").text()
        self.assertNotIn("refers to the account briefed earlier", explore)
        self.assertIn("refers to the account briefed in the previous reply", explore)
        self.assertIn("stays here", explore)

    def test_system_line_allows_the_router_off_topic_reply(self):
        system = self.tree.child("system:").child("instructions:").line
        self.assertIn(OFF_TOPIC_LINE, system)
        router = self.router.child("reasoning:").child("instructions:").text()
        self.assertIn(OFF_TOPIC_LINE, router)


class TestAccountBriefSpec(unittest.TestCase):
    def test_spec_has_sixteen_utterances(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"^\s*-?\s*utterance:", text, re.M)), 16)
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

    def test_off_topic_case_names_no_expected_topic(self):
        # agentforce-test batch-testing.md: guardrail cases omit expectedTopic and assert on the outcome.
        case = self.case("What is the weather in Paris today?")
        self.assertNotIn("expectedTopic", case)
        self.assertNotIn("topic_selector", SPEC.read_text(encoding="utf-8"))

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
        # The outcome describes AccountBriefResolver.ambiguous(): "<Name> — <BillingCity or 'no city'> — <Id>".
        outcome = case.split("expectedOutcome:", 1)[1]
        self.assertNotIn("each with its city", outcome)
        self.assertIn('Several accounts match \\"United Oil\\". Which one?', outcome)
        self.assertIn("three candidate lines", outcome)
        self.assertIn("18-character", outcome)
        self.assertIn("no city", outcome)
        for city in ("New York", "Singapore"):
            self.assertIn(city, outcome)

    def test_spec_holds_no_record_id_or_org_name(self):
        text = SPEC.read_text(encoding="utf-8")
        # The fake all-zero Id in the pasted-Id case is the only 001 value allowed.
        ids = [i for i in re.findall(r"001[A-Za-z0-9]{12,15}", text) if i != "001000000000000AAA"]
        self.assertEqual(ids, [])
        self.assertNotIn("experimental", text)

    def test_two_turn_follow_up_case(self):
        case = self.case("What about their open cases?")
        history = case.split("conversationHistory:", 1)[1]
        roles = re.findall(r"- role: (\w+)", history)
        self.assertEqual(roles, ["user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertRegex(case, r"expectedActions:\s*\n\s*- get_brief\s*\n")

    def test_org_wide_count_after_a_brief_case(self):
        case = self.case("How many open opportunities are there in the whole org?")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertRegex(case, r"expectedTopic:\s*explore\s*\n")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- explore_data\s*\n")

    def test_not_found_then_follow_up_case(self):
        case = self.case("Show me their open cases")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent", "user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertIn("Zzqxv Nonexistent Holdings", history)
        self.assertRegex(case, r"expectedTopic:\s*account_brief\s*\n")
        outcome = case.split("expectedOutcome:", 1)[1].split("conversationHistory:", 1)[0]
        self.assertIn("does not call get_brief", outcome)
        self.assertIn("Edge Communications", outcome)


    def test_not_found_history_quotes_the_current_resolver_text(self):
        text = SPEC.read_text(encoding="utf-8")
        self.assertNotIn("open the account and ask again", text)
        history = self.case("Show me their open cases").split("conversationHistory:", 1)[1]
        self.assertIn(NOT_FOUND_TAIL, history)

    def test_largest_opportunities_case_says_rows_are_unchanged(self):
        outcome = self.case("List the five largest open opportunities").split("expectedOutcome:", 1)[1]
        self.assertIn("table rows", outcome)
        self.assertIn("unchanged", outcome)

    def test_explore_follow_up_case(self):
        case = self.case("Which close this quarter?")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent"])
        self.assertIn('message: "How many open opportunities are there?"', history)
        self.assertIn("topic: explore", history)
        self.assertRegex(case, r"expectedTopic:\s*explore\s*\n")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- explore_data\s*\n")

    def test_pronoun_after_an_org_wide_count_stays_in_explore(self):
        case = self.case("Which of them close this quarter?")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent", "user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertIn('message: "How many open opportunities are there?"', history)
        self.assertRegex(case, r"expectedTopic:\s*explore\s*\n")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- explore_data\s*\n")
        outcome = case.split("expectedOutcome:", 1)[1].split("conversationHistory:", 1)[0]
        self.assertIn("does not call get_brief", outcome)

    def test_list_pick_after_ambiguous_case(self):
        case = self.case("The Singapore one")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent"])
        self.assertIn('Several accounts match \\"United Oil\\". Which one?', history)
        self.assertRegex(case, r"expectedTopic:\s*account_brief\s*\n")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- resolve_account\s*\n\s*- get_brief\s*\n")
        outcome = case.split("expectedOutcome:", 1)[1].split("conversationHistory:", 1)[0]
        self.assertIn("United Oil & Gas, Singapore", outcome)

    def test_second_account_after_a_brief_case(self):
        case = self.case("Now brief me on Brindlewick Hydroponics")
        history = case.split("conversationHistory:", 1)[1]
        self.assertEqual(re.findall(r"- role: (\w+)", history), ["user", "agent"])
        self.assertIn("Edge Communications", history)
        self.assertRegex(case, r"expectedTopic:\s*account_brief\s*\n")
        self.assertRegex(case, r"expectedActions:\s*\n\s*- resolve_account\s*\n\s*- get_brief\s*\n")
        outcome = case.split("expectedOutcome:", 1)[1].split("conversationHistory:", 1)[0]
        self.assertIn("Brindlewick Hydroponics", outcome)
        self.assertIn("not about Edge Communications", outcome)


class TestResolverWording(unittest.TestCase):
    """Finding 12 and finding 11's Apex label: the resolver's text matches what the script can do."""

    def test_not_found_asks_for_a_name_not_an_open_record(self):
        text = RESOLVER.read_text(encoding="utf-8")
        self.assertFalse("open the account" in text, "the resolver still says to open the account")
        self.assertTrue(NOT_FOUND_TAIL in text, "the resolver does not ask for a fuller or different name")

    def test_account_name_label_matches_the_script(self):
        text = RESOLVER.read_text(encoding="utf-8")
        self.assertFalse("character for character" in text, "the Apex label still says character for character")
        self.assertTrue("without the rest of the request" in text, "the Apex label does not match the script")

class TestCheckScripts(unittest.TestCase):
    def test_agent_check_exists_and_is_executable(self):
        self.assertTrue(AGENT_CHECK.is_file())
        self.assertTrue(os.access(AGENT_CHECK, os.X_OK))

    def test_agent_check_compiles_and_validates_with_the_pinned_cli(self):
        text = AGENT_CHECK.read_text(encoding="utf-8")
        self.assertIn("index-agent.mjs", text)
        self.assertIn("setup-agentscript-sdk.mjs", text)
        self.assertIn('SF="/usr/local/bin/sf"', text)
        self.assertIn('TARGET_ORG="${SF_TARGET_ORG:-agent-probe}"', text)
        self.assertIn(
            '"$SF" agent validate authoring-bundle --json --api-name Account_Brief -o "$TARGET_ORG"', text
        )
        self.assertNotIn("experimental", text)
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
