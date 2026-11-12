# The panel asks the agent directly (BE-19, finished as BE-20)

Run 2026-11-12 in `agent-probe`, as the signed-in System Administrator, against `Account_Brief`
version 2 (active). No agent was published or activated, no user was created, and the org this
was first built in was not touched. Ids, session Ids, usernames and hostnames are left out.

## Result

"Ask the agent" in the custom panel now sends the composer text to the registered `Account_Brief`
agent through Apex and shows the reply in the panel. It no longer opens the built-in Agentforce
panel. A follow-up reuses the agent session. Playwright spec 9 failed on the old panel and passed
after the deploy, and the full e2e suite passed 9 of 9.

## Probe

Before the deploy, one anonymous Apex run made two calls of
`Invocable.Action.createCustomAction('generateAiAgentResponse', 'Account_Brief')`, the second with
the first call's `sessionId`. The messages were the ones the panel sends: "What are the open deals
at this account?" with the open record appended (`The record I have open is <record Id>.`, the
Edge Communications account), then "What about their open cases?" with no record. The script
printed field names, timings and true/false checks only.

| Turn | Success | Errors | Time | Outputs | `agentResponse` | Same session as turn 1 | Reply checks |
|---|---|---|---|---|---|---|---|
| 1 | true | 0 | 15.4 s | `agentResponse`, `sessionId` | JSON `{"type":"Text","value":...}`, 1,041 characters of text | (first) | about deals: yes; asks which account: no |
| 2 | true | 0 | 10.1 s | `agentResponse`, `sessionId` | same envelope, 801 characters | yes | about cases: yes; asks which account: no |

The second turn named no account and carried no record, so it answered about cases only because
the session held the first turn. The earlier probe in the first org recorded 14 to 18 s a turn
([agent-api.md](agent-api.md)).

**Permission.** The running user has the System Administrator profile and holds
`Account_Brief_Agent_Access` twice: assigned directly and through the `Account_Brief_User`
group. The call worked with that. The probe cannot show which permission a user needs beyond
agent access (for example Manage AI Agents, which a web-search summary names; unverified in
[agent-api.md](agent-api.md)), because an admin has them all. `Account_Brief_Agent_Access` was
not changed. A non-admin run is the open item.

## Design

- **`AccountBriefAgentClient`** (new): `ask(message, sessionId, contextRecordId)` returns a
  `Reply` with `text`, `sessionId` and `failed`. It adds the open record to the message text, as
  the probe proved; the agent declares no context variable to carry it. It unwraps the
  `{"type":"Text","value":"..."}` envelope (a reply that is not JSON is kept as it is). Any
  failure, a blank message, an unsuccessful action, an empty reply or an exception, returns the
  fixed line "The agent could not answer right now. Try again in a minute." with `failed` true,
  and the raw error is only logged. The action cannot run in an Apex test, so the call sits
  behind a `Transport` interface; the real one runs the action, and tests set a scripted one
  through a `@TestVisible` field.
- **`AccountBriefPanelController.askAgent`** (new, `@AuraEnabled`, not cacheable): passes through
  to the client and turns anything unexpected into the same fixed line. No existing method,
  invocable signature, label or description changed.
- **`accountBriefPanel`**: "Ask the agent" no longer imports `lightning/accApi`. It sends the
  composer text through `askAgent` as one more request in the panel's latest-wins `_request`, with
  the loading line "Asking the agent", which the polite live region announces, and "Agent
  replied" when the reply renders as a text turn. The first turn of an agent session sends the
  open record and no session; later turns send the session and no record. A new account (a new
  page context) or a new panel instance starts a new agent session, and a reply that lands after
  the account changed does not restore the old session. A failure shows only the fixed line. The
  button is disabled while the composer is empty, like Send. Layout, position, size and styling
  did not change; the brief, explore and drill paths did not change.

## Deploy steps, in order

Under the Approvals lines "The panel calls the registered agent directly" and
"Production-classified deploys to agent-probe ... standing" (Ben's standing approval, relayed).

1. Red evidence before any source change, with the work-in-progress tests: Jest against the old
   panel, a check-only validate of the two Apex test classes, and Playwright spec 9 against the
   panel then deployed (see Tests).
2. The probe above.
3. `sf project deploy validate` of `AccountBriefAgentClient`, `AccountBriefAgentClientTest`,
   `AccountBriefPanelController`, `AccountBriefPanelControllerTest` and the `accountBriefPanel`
   bundle, `--test-level RunLocalTests`: Succeeded, 5 of 5 components, 172 tests, 0 errors.
   Coverage: `AccountBriefAgentClient` 36 of 46 lines (9 of the 10 left are the real
   `ActionTransport`, which only a live action reaches; the 10th is the fallback for a reply that
   parses as JSON but is not an object), `AccountBriefPanelController` 73 of 75.
4. `CONFIRM_PROD=1 sf project deploy quick --job-id <validation id>`: Succeeded, 5 of 5
   components, under its own deploy Id.
5. The permission set was not deployed: it did not change.

## Tests

| Check | Before (red) | After (green) |
|---|---|---|
| Jest, the "ask the agent" tests | 10 of 11 failed against the old panel (`askAgent` never called) | 50 of 50 for the whole panel suite |
| Apex, `AccountBriefAgentClientTest` and `AccountBriefPanelControllerTest` | check-only validate failed to compile: `AccountBriefAgentClient` did not exist in the org | passed inside the RunLocalTests validate (172 tests) |
| Playwright spec 9 alone | failed: the live region stayed empty because the button opened the built-in Agentforce panel (its "You're about to use Agentforce" notice was on screen) | passed, 42.6 s |
| `npm run test:e2e` | | 9 of 9 passed, 3.3 minutes; spec 2 did not flake |
| Agent spec, `Account_Brief_Test` (16 cases, `tests/agent/Account_Brief-testSpec.yaml`), run once after e2e | | 16 of 16 actions, 15 of 16 topics (case 12, the expected false failure of the off-topic case), 15 of 16 replies |

Spec 9 checks booleans only, from the `askAgent` Aura request and response read in memory: turn 1
sent the open account and no session and got a reply with a session; turn 2 sent turn 1's
session and no record, got the same session back, answered about cases and did not ask which
account; each reply's text is what its turn shows in the custom panel; and the live region said
"Asking the agent" during each wait.

**Agent spec, case 14.** "Which of them close this quarter?" (after a brief and an org-wide count)
routed to explore and called `explore_data`, as expected, and answered "27 opportunities close
this quarter", with a Closed Won row in the table. That is the same answer as in the version 2
run in [agent-iteration-1.md](agent-iteration-1.md), where the judge rated it 3 and passed it;
this time it rated it 2 and failed it ("some of which are not open"). Testing Center does not set
`explore_history`, so the explorer sees only the last question (N3). The agent did not change in
this work. The other 15 replies were rated 3 to 5 and passed.

## Model use

About 31 agent turns in all: 2 in the probe, 1 in the red run of spec 9 (the hand-off, which
stopped at the built-in panel's notice), 2 in spec 9 alone, about 9 in the full e2e run, 16 in
the agent spec (each also graded) and 1 for `panel-ask-agent.png`. The explorer and the brief make
more model calls inside one turn.

## Asset

`docs/assets/panel-ask-agent.png` was captured with `e2e/capture/07-ask-agent.capture.js` (one
agent turn, the capture kit's privacy guard on) and read by eye: the question, the start of the
reply, the owner shown as "Sample Owner", email addresses hidden, no Id in view. No other asset
was recaptured. `agent-brief.png` and `agent-explore.png` show the built-in panel itself, not the
hand-off, and are unchanged; their capture script reached the built-in panel through the old
button, so it is now skipped until it is pointed at the built-in panel's own entry point.

## Open

- A run as a non-admin user, and the permission it needs beyond agent access.
- The agent's reply is shown as plain text in a pre-line block. How an agent reply that relays an
  explorer table reads in the panel was not checked.
- The reply in `panel-ask-agent.png` contains "Account Not requested.", the brief's section line
  relayed verbatim; whether the agent should drop it is an agent script question.
