# FR2: "Ask the agent" and the built-in panel are no longer ways in (FE-20)

Run 2026-11-12 in `agent-probe`, as the signed-in System Administrator. No agent was published,
activated or deactivated, no user was created, and the org this was first built in was not
touched. Covers ledger rows F82 and F83 in [feature-revision-2.md](../plans/feature-revision-2.md).

## Why

"Ask the agent" sent a typed question from the panel to the registered agent and showed the reply
as plain text. It took 10 to 18 seconds a turn ([panel-agent-1.md](panel-agent-1.md)), returned
text where principle 2 wants cards, and repeated what the panel already answers by calling the
Apex directly. It goes before the rename, so dead code is not renamed.

## What was removed

| Where | Removed |
|---|---|
| `accountBriefPanel` | the "Ask the agent" button, its handler, the "Asking the agent" and "Agent replied" live-region text, the agent session state and the `agentId` wire |
| `AccountBriefPanelController` | `askAgent`, `agentId` and the BotDefinition query that only gated the button (half of N11 in [apex-review-2.md](../reviews/apex-review-2.md)) |
| Repo | `AccountBriefAgentClient` and its test (both classes and their meta files) |
| Jest | the ten "ask the agent" cases; new case: no "Ask the agent" button renders |
| Apex tests | the `askAgent` and `agentId` cases |
| e2e | spec 9, the `agentButton` and `apexCall` helpers, the 06-agent and 07-ask-agent capture scripts; spec 3 now checks the bar holds the Brief button and no "Ask the agent" button |
| Access | `Account_Brief_Agent_Access` is out of the `Account_Brief_User` group; the group holds only `Account_Brief_Data_Access` |

The agent itself, its script and `Account_Brief_Agent_Access` stay in the repo, for a team that
adds the agent to a channel later. The three images the removed scripts wrote stay in
`docs/assets/`, marked "retired, still linked" in the manifest.

**Left in the org.** The deploy does not delete: `AccountBriefAgentClient` and its test stay in
`agent-probe`, unused. Deleting them there is a destructive deploy and joins the leftovers that
wait for Ben's go. The org's `Account_Brief_User` group was redeployed without the agent set; the
two direct assignments the admin already held are unchanged.

## Results in agent-probe

- Gates: `python3 -m unittest discover -s tests` 101 tests OK; `npm run test:unit` 41 of 41;
  `bash scripts/validate-org.sh` pass (61 components, 158 tests); `bash scripts/check-docs.sh`
  0 broken.
- Red first: the new Jest case failed on main (the button rendered) and the group test failed
  (the group held the agent set too); both pass now.
- Validate with RunLocalTests: Succeeded, 4 components (panel bundle, controller, its test and the
  group), 169 tests, 0 errors. Quick deploy: Succeeded, 4 components.
- Playwright, full suite after the deploy: `8 passed (2.8m)`.

## The built-in launcher (the Agentforce icon)

Hiding it for reps is Ben's own click: the row "FR2: hide the Agentforce icon for reps" in the
Approvals table of [gtm-burn-plan.md](../plans/gtm-burn-plan.md) does not start with "approved", so
no setting was changed.

What makes it show, from Salesforce's help pages ("Connect an Agent to Lightning Experience and
Mobile", "Manage Employee Agent Access", "Create the Agentforce (Default) Agent"; read as search
excerpts, the full article bodies did not load, so treat the wording as unverified until checked in
Setup): an agent appears in the Agentforce panel in Lightning Experience once it is active and
the user has access to it. The Agentforce (Default) agent also needs its setting turned on, plus
user access and activation. Access comes from a permission set or profile.

The Setup step that should hide it for reps (to confirm on screen before Ben relies on it): in
Setup, Quick Find "Permission Sets" (or "Profiles"), open each set or profile reps hold, edit
**Enabled Agent Access**, and untick every agent, including Agentforce (Default). Leaving no agent
available to reps is what should remove the panel. Reps no longer get `Account_Brief` through our
group. To undo, tick the agents again in the same place.

What the admin sees: in `agent-probe` the admin still holds `Account_Brief_Agent_Access` directly
(one assignment), so the admin can still reach the agent in the built-in panel. The Playwright run
does not inspect the header icon. The non-admin check is left to FE-5.

## Undo

Not recorded on this page. It does say `AccountBriefAgentClient` and its test stay in `agent-probe`, unused; deleting them is a destructive deploy that waits for Ben's go.
