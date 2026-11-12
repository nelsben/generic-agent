# Agent iteration 1 (BE-16)

Org: agent-probe only. Date: 2026-11-12. Everything below was read from command output in this
run (verified) unless it says otherwise.

## Changes and the findings they close

Findings are from `docs/reviews/agent-review-2.md`.

| Change | Finding |
|---|---|
| `ExploreAction` takes an optional History input and passes it to `DataExplorer.explore` (blank means none). It also returns a History output: this question and its answer as one JSON item, each part clipped to 600 characters, ready for the next turn. `ExploreActionTest` covers no history, history from one turn reaching the next turn's prompt, the clip, and a blank question or null request | N3, scenario A |
| The script keeps `explore_history`, binds it to `explore_data`'s `history` input on every explore run, stores the output back, and clears it when `resolve_account` or `get_brief` runs (not on entry to account_brief, so a reclassify does not wipe it) | N3, scenario A |
| Router rule 4 applies only when the previous reply came from account_brief. After an explore answer, "them", "those" and "which" refer to its records and go to explore under rule 5. A router branch says so whenever `explore_history` is set; the briefed hint, both router action descriptions, account_brief rule 7 and the explore instructions agree | N3, scenario B |
| NOT_FOUND now says `Try a fuller or different account name.`; the blank-name message says `Which account? Give me the account's name.` The input label says "without the rest of the request" instead of "character for character". `AccountBriefResolverTest` asserts both texts | 12 |
| Spec: an explore follow-up, a pronoun after an org-wide count, a list pick after AMBIGUOUS, and a second account that resolves after a brief | 7 (list pick, second account), 6 (a second account that resolves is now tested), N3 (both scenarios) |
| Spec: case 11's outcome says the table rows are relayed unchanged | N6 (spec part only; no FunctionStep diff was made) |
| Spec: the off-topic case no longer names `expectedTopic: topic_selector` | 7 |
| `tests/test_agent_bundle.py` asserts the binding, the clears, the narrowed rule 4, the new spec cases and the resolver wording; a further test keeps every variable description within 255 characters | guards the above |

## Commands and outcomes, in order

| # | Step | Command | Outcome |
|---|---|---|---|
| 1 | Version table before | read-only `SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion` | v1 Active (table below) |
| 2 | Red | `python3 -m unittest discover -s tests` and a static check of the Apex | 82 tests, 13 failures; the new Apex test methods do not compile on main (`.delegation/BE-16/red-1.txt`, git-ignored) |
| 3 | Green, local | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`; `bash scripts/agent-check.sh` | OK; local compile ok (0 warnings), org validate ok |
| 4 | Validate | `sf project deploy validate --source-dir <every force-app folder except aiAuthoringBundles> --test-level RunLocalTests -o agent-probe --wait 4 --json` | Succeeded: 60 components, 154 tests, 0 failures |
| 5 | Quick deploy | `CONFIRM_PROD=1 sf project deploy quick --job-id <validation> -o agent-probe --wait 4 --json` | Succeeded, 60 components |
| 6 | N4 and N3 preview | `sf agent preview start --authoring-bundle Account_Brief --use-live-actions`, six `send`s, `end` (all `--json`) | See "N4 trace notes" and "Explore two-turn result" |
| 7 | Commit | `git commit` | before the publish, so the bundle checkout cannot lose edits |
| 8 | Publish, first | `sf agent publish authoring-bundle --api-name Account_Brief -o agent-probe --skip-retrieve --json` | **Failed**: "Description: data value too large ... (max length=255)". The new `explore_history` description was 276 characters. It created no version: the next BotVersion query (step 11) shows only v1 and the v2 from the second publish |
| 9 | Fix | shortened the description to 225 characters; added `test_variable_descriptions_fit_the_publish_limit`; tests and agent-check green; commit | |
| 10 | Publish, second (changed bundle, not the same call) | same command | `success` true, 3 deployed. `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` left the tree clean |
| 11 | Version table | read-only BotVersion query | v1 Active, v2 Inactive |
| 12 | Activate | `sf agent activate --api-name Account_Brief --version 2 -o agent-probe --json` | `success` true, version 2 |
| 13 | Version table after | read-only BotVersion query | v1 Inactive, v2 Active |
| 14 | Evaluation definition | `sf agent test create --json --spec tests/agent/Account_Brief-testSpec.yaml --api-name Account_Brief_Test --test-runner testing-center --force-overwrite -o agent-probe` | Overwritten with 16 cases. The file the CLI wrote under `force-app/main/default/aiEvaluationDefinitions/` was deleted |
| 15 | Check the definition | read-only `sf project retrieve start --metadata AiEvaluationDefinition:Account_Brief_Test --target-metadata-dir <scratch> --unzip` | `subjectName Account_Brief`, `subjectType AGENT`, `subjectVersion v2`, 16 test cases |
| 16 | Spec run | `sf agent test run --api-name Account_Brief_Test --test-runner testing-center --wait 4 --result-format json -o agent-probe --json` | COMPLETED, 07:52:50Z to 07:56:00Z. 16 of 16 (table below) |
| 17 | Two-turn brief check | `sf apex run --file <scratch>/turn1.apex`, then `turn2.apex` with turn 1's session | Pass (below) |
| 18 | Gates | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests`, `bash scripts/validate-org.sh`, `bash scripts/agent-check.sh` | 83 tests OK; validate-org pass (60 components, 154 tests); agent-check pass (local compile ok, 0 warnings; org validate ok) |

Org model use: 6 preview turns, 16 spec cases (each also graded) and 2 two-turn turns, 24 agent
turns in all. The explorer makes several model calls inside one turn. No data was written except
the evaluation definition and what the agent and its actions write themselves.

## Version table

| When | Agent | Version | Number | Status | LastModifiedDate |
|---|---|---|---|---|---|
| Before | Account_Brief | v1 | 1 | **Active** | 2026-11-12T05:55:35Z |
| After the second publish | Account_Brief | v1 | 1 | **Active** | 2026-11-12T05:55:35Z |
| After the second publish | Account_Brief | v2 | 2 | Inactive | 2026-11-12T07:51:29Z |
| After activation | Account_Brief | v1 | 1 | Inactive | 2026-11-12T07:51:53Z |
| After activation | Account_Brief | v2 | 2 | **Active** | 2026-11-12T07:51:53Z |

Previously active: v1. Now active: v2. No rollback: v2 passed all 12 carried-over cases.

## Spec run (Account_Brief v2)

Each case has a topic, an action and a graded reply (1 to 5) assertion. The rollback rule was
decided before the run: roll back if any of the 12 carried-over cases fails; score the off-topic
case on its reply and actions only, because a guardrail case names no topic and the runner then
reports a false topic FAILURE.

| Case | Utterance | Topic | Actions | Rating | Result | Judge note (short) |
|---|---|---|---|---|---|---|
| 1 | Give me a brief on Edge Communications | account_brief | resolve_account, get_brief | 5 | PASS | a detailed brief, as expected |
| 2 | What is going on with Edge Communications, and which deals are slipping? | account_brief | resolve_account, get_brief | 3 | PASS | addresses the question but "overly detailed and not concise" |
| 3 | Brief me on Zzqxv Nonexistent Holdings | account_brief | resolve_account | 5 | PASS | says no account matches, no brief |
| 4 | Brief me on a pasted Id that matches nothing | account_brief | resolve_account | 5 | PASS | says no account matches the Id |
| 5 | Brief me on United Oil | account_brief | resolve_account | 5 | PASS | "exactly matches" the candidate format |
| 6 | Just the open deals for Edge Communications | account_brief | resolve_account, get_brief | 3 | PASS | right deals, "unnecessary details" |
| 7 | What about their open cases? (after an Edge brief) | account_brief | resolve_account, get_brief (spec: get_brief) | 5 | PASS | answers about the open cases |
| 8 | Show me their open cases (after a no-match) | account_brief | resolve_account | 5 | PASS | the resolver's message, verbatim |
| 9 | How many open opportunities are there in the whole org? (after an Edge brief) | explore | explore_data | 5 | PASS | 36, the org-wide count |
| 10 | How many open opportunities are there? | explore | explore_data | 5 | PASS | 36 |
| 11 | List the five largest open opportunities | explore | explore_data | 5 | PASS | relays the rows "without reordering, rounding, dropping, or adding rows or columns" |
| 12 | What is the weather in Paris today? | topic_selector | none | 5 | PASS (topic assertion FAILURE ignored) | the one off-topic line, exactly |
| 13 | Which close this quarter? (after a count) | explore | explore_data | 5 | PASS | relays opportunities closing this quarter |
| 14 | Which of them close this quarter? (after a brief and a count) | explore | explore_data | 3 | PASS | right subject, but lists closed-won ones too and does not say "them" means the open ones |
| 15 | The Singapore one (after the United Oil list) | account_brief | resolve_account, get_brief | 5 | PASS | a brief on United Oil & Gas, Singapore, no list again |
| 16 | Now brief me on Brindlewick Hydroponics (after an Edge brief) | account_brief | resolve_account, get_brief | 5 | PASS | a brief on Brindlewick Hydroponics |

Score: 16 of 16 on the reply and action assertions; 15 of 16 topic assertions, the miss being
case 12's expected false FAILURE. The 12 carried-over cases: 12 of 12, the same as v1.

Notes:

- Case 14 is N3 scenario A in miniature. Testing Center replays history as text and does not set
  `explore_history`, so the explorer saw only "Which of them close this quarter?" and counted 27
  opportunities, two of them already Closed Won. The live preview with the history bound (below)
  counted 25 open ones. The routing part of the case, the one this spec can test, passed: explore,
  not get_brief on Edge.
- Case 11's reply restated the five rows in prose and then gave the explorer's table. The judge
  found the rows unchanged. No diff against the FunctionStep output was made (N6 asks for one; it
  needs a preview trace of that case).

## Two-turn brief check (published v2)

The check as `docs/research/org-migration.md` records it: `generateAiAgentResponse` for
Account_Brief, turn 1 "Give me a brief on Edge Communications", turn 2 in a separate execution
with turn 1's session and "What about their open cases?". The session Id stayed in a scratch file,
was never printed, and was deleted.

| Turn | Result |
|---|---|
| 1 | `isSuccess` true, no errors, 31767 ms, a session came back. Reply 2717 characters, a full brief of Edge Communications. It starts: "Two overdue deals totaling $134,540 require immediate attention, and a high-priority escalated case is threatening the largest open opportunity." |
| 2 | `isSuccess` true, no errors, 9608 ms, the same session came back. Reply 922 characters, limited to service health without naming the account: "One high-priority escalated case needs immediate attention; five cases now open with two closed recently." **Pass** |

## Explore two-turn result (local bundle, live actions)

Turns 1 and 2 of the preview session. The previewed script differs from the published v2 only in the shorter `explore_history` description (step 9):

| Turn | Utterance | Route | `explore_data` inputs | Reply |
|---|---|---|---|---|
| 1 | How many open opportunities are there? | explore | question, `history` empty | "There are 36 open opportunities." |
| 2 | Which close this quarter? | explore | question, `history` = turn 1's question and answer as one JSON item | "There are 25 open opportunities scheduled to close this quarter (Q4 2026) ..." |

The trace shows `explore_history` set after each run from the `history` output. Turn 2 kept
"open" from turn 1, which the history-less spec case 14 did not. **Pass.**

## N4 trace notes

Turns 3 to 6 of the same session took the three reclassify paths out of explore
(`.agent` explore instructions: names an account or asks for a brief; picks from a list or refers
to the briefed account; not about CRM data), right after explore answers, so the router had the
most reason to send them to explore.

| Turn | Utterance | Path | Route in the trace | `explore_data` step |
|---|---|---|---|---|
| 3 | What is the weather in Paris today? | not about CRM data | stayed in the router (topic_selector), the off-topic line | none |
| 4 | Brief me on United Oil | names an account | router to account_brief; resolve_account (AMBIGUOUS); `explore_history` cleared | none |
| 5 | The Singapore one | picks from a candidate list | router to account_brief; resolve_account with the picked Id, then get_brief; a brief on United Oil & Gas, Singapore | none |
| 6 | What about their open cases? | refers to the briefed account | router to account_brief; get_brief with `include` cases on the Singapore account | none |

No discarded `explore_data` FunctionStep appeared: in every turn the router sent the message
straight to the right place, and the explore subagent was never entered, so its `before_reasoning`
never ran. N4 stays "suspected": the misroute it needs did not happen in one preview of each path.
Nothing was changed for N4.

## Left open

- `docs/patterns/06-agent-routing-and-verbatim-relay.md` still quotes the old NOT_FOUND text
  ("open the account and ask again"). It is outside this card's scope.
- N6's FunctionStep diff of case 11.
- Cases 2 and 6 were rated 3 for length (4 on v1 in `org-migration.md`); case 1 rose from 3 to 5. The grader varies between runs, and both still pass.
