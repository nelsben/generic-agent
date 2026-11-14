# FR2: the quick-start change for OPS-36 — the agent publish leaves the required steps (OPS-44)

Written 2026-11-14 by OPS-44, for OPS-36 to apply to README.md. Covers ledger rows F82 to F84 in
[feature-revision-2.md](../plans/feature-revision-2.md): our surfaces are the only ways in, and the registered agent
is an optional add-on documented in the appendix,
[06](../patterns/06-agent-routing-and-verbatim-relay.md). OPS-44 does not edit README.md. Nothing here was run in an
org; it is a text change only. Whether a run without the agent has passed belongs in the README's
[Status table](../../README.md#status) (OPS-28's run), not in the quick start.

## What moves out of the README

Everything below is in the appendix's [Adopt it](../patterns/06-agent-routing-and-verbatim-relay.md#adopt-it) now.

| README, "See it in 5 minutes" today | Where it goes |
|---|---|
| Step 3, **Publish and activate the agent**: its heading, the code block (`bash scripts/agent-check.sh`, `sf agent publish authoring-bundle ...`, `sf agent activate ...`) and the paragraph under it ("Publishing needs the Apex from step 1 ... `git checkout -- force-app/main/default/aiAuthoringBundles/Customer_Summary` afterwards.") | Appendix steps 2 and 3 (check the script; publish, activate and restore the bundle folder) |
| Step 4's sentence "`Customer_Summary_Agent_Access` stays in the repo, outside the group, for a team that adds the agent to a channel later." | Appendix step 4, which also deploys and assigns that set (the README never did) |
| The closing paragraph after step 5, "In `agent-probe`, a fresh Developer Edition org, main's bundle published on the first try ... The panel path does not depend on publishing." | Appendix, "Limits and open items" (publishing fails in the org this was first built in) |

## What to delete, and what to change

1. **Delete step 3** whole, as named in the table.
2. **Step 1's heading and its first paragraph.** Delete ", without the agent and without
   `Customer_Summary_Agent_Access`" from the heading and the sentence "That set names the `Customer_Summary` agent,
   which does not exist until step 3, so it cannot deploy yet." Keep the `--source-dir` list as it is: it leaves out
   the agent bundle and that set on purpose. If a reason is wanted, it is "The agent and its permission set are
   optional; see the appendix."
3. **Delete step 4's sentence** about `Customer_Summary_Agent_Access`, as named in the table. Keep the rest of step 4.
4. **Delete the closing paragraph** after step 5, as named in the table.
5. **Renumber.** Step 4 (deploy the group) becomes step 3, and step 5 (open the org) becomes step 4. In step 1,
   "The panel works from here (step 5)" becomes "(step 4)", and "Do the same for step 4" becomes "Do the same for
   step 3".
6. **Add the one line** below at the end of the steps, where the closing paragraph was.

## The one line that replaces them

```markdown
The registered Agentforce agent is optional, and none of the steps above need it. To add it to an Agentforce channel, see the appendix, [06](docs/patterns/06-agent-routing-and-verbatim-relay.md#adopt-it).
```

## Left for OPS-36 to decide

- The Status table rows about the agent (routing, the panel calling the agent, the publish, the spec run) are not
  quick-start steps, so this page does not rewrite them. They stay the one place that says whether a run passed.
- The README's lead and system map should no longer show the built-in panel as a way in (F82); that is OPS-36's own
  part of the ledger row.
