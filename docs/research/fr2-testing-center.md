# FR2 Testing Center suite for Customer Summary (BE-38)

- Date: 2026-11-16. Org `agent-probe` (Developer Edition, `IsSandbox` false, verified by a query on the day).
  Covers ledger row F88 and the version-pinning open item of page 08 in
  [feature-revision-2.md](../plans/feature-revision-2.md).
- Approval: the row "FR2: create and run the functional Testing Center suite" in the Approvals table of
  [gtm-burn-plan.md](../plans/gtm-burn-plan.md) reads "approved (Ben, 2026-11-16 ...)" (verified before any org step).
- CLI: `@salesforce/cli` 2.158.7. Agent: `Customer_Summary`, the GO name in [fr2-rename-go.md](fr2-rename-go.md);
  its version 2 is the active one (verified).
- Status words: verified (seen in a command result, an org query or the CLI's own source), unproven (from a
  document I could not open, or inference).
- No record Ids, job Ids, usernames, emails or hostnames are written here. Counts only.

## The facts, settled first

### What a case can assert

| Check | Spec field | What it compares | Source |
|---|---|---|---|
| Subagent | `expectedTopic` | The subagent the agent ran in, by name (`account_summary`, `explore`) | Trailhead "Set Up Testing Criteria" (the "Expected Subagent"); the agentforce-test skill's batch-testing reference |
| Actions | `expectedActions` | The actions the agent called, as a flat list of the names under `reasoning: actions:`. Superset match: an extra action never fails it | The skill's batch-testing reference; [agent-iteration-1.md](agent-iteration-1.md) saw it pass with an extra `resolve_account` |
| Outcome | `expectedOutcome` | A plain sentence that a model judge compares the reply with | Trailhead (the "expected response"); the skill reference |
| Quality metrics | `metrics` | `completeness`, `coherence`, `conciseness`, `output_latency_milliseconds`, scored per case | The metric list in the CLI's `@salesforce/agents` library (verified in its source). The skill reference says `conciseness` returns 0 (unproven here) |
| Custom evaluation | `customEvaluations` | A named comparison with parameters, for example a value read from an action's output by a JSON path, against an expected value | The CLI's spec translator carries `customEvaluations` into the definition (verified in its source). The skill reference lists a known bug: a custom evaluation that reads an action's output by reference crashes the results API. Not used in this suite (unproven) |

A case without `expectedTopic` still gets an empty subagent check in the definition, and that check always reports a
failure (the skill reference; seen again in this run, below). `scripts/agent-test.sh` leaves those out of its counts.

### What one run costs

- Trailhead, "Set Up Testing Criteria": "Running tests consumes requests and credits." It points to the Salesforce Help
  article "Considerations for Testing Center" for the amounts. I could not open that article or the Testing API
  considerations page (the fetch was refused), so the per-case rate is **unproven** here.
- What a case spends, from the code (inference, unproven as a rate): the agent's own reasoning calls to route and
  reply; the model calls inside the actions it runs (a summary makes up to four: the synthesis, the focused calls and
  the sentiment; the explorer runs its own model loop); and one judge call for the outcome. Sixteen cases, six of them
  summaries and five explorer questions, is a few dozen model calls per run.
- Where to see it: the org's Digital Wallet shows generative AI usage (a search summary said so; unproven, not opened).
- So the suite is a named rung (`bash scripts/ladder.sh --agent`), not part of every card's gate, and it is capped at 20
  cases.

### Salesforce's sandbox advice, and an org with no sandbox

- Trailhead, "Set Up Testing Criteria": "Testing agents can modify CRM data." and "be sure to use the Agentforce
  Testing Center only in your sandbox environment." (verified on the page).
- `agent-probe` is a Developer Edition org: `IsSandbox` is false and it cannot have a sandbox. Two answers:
  - **A scratch org** with the sample data loaded (`bash scripts/seed-sample-data.sh`), as OPS-28 uses for the quick
    start. The script runs there unchanged: `SF_TARGET_ORG=<scratch-alias> bash scripts/agent-test.sh` or `--org`.
    The agent must be published and activated in that org first.
  - **`agent-probe` itself, only with Ben's go**, which the Approvals row gives for this functional suite. What makes it
    safe enough here: the agent has no write actions and no case asks for a write. A summary still writes its own
    session row and customer outcome; the suite keeps those on one sample account (below).
- No security suite runs anywhere in this card (see [Security suite](#security-suite-not-written)).

### How a definition stays tied to one agent version

- A test definition (`AiEvaluationDefinition`) names its agent (`subjectName`) and one version (`subjectVersion`, for
  example `v2`). The CLI copies `subjectVersion` from the spec into the definition when the spec has one (verified in
  the `@salesforce/agents` source the CLI ships). [org-migration.md](org-migration.md) saw the CLI write the version that
  was active at create time when the spec named none.
- So a definition made before a publish and activation keeps testing the old version. `scripts/agent-test.sh` closes
  that: every run reads the active version, writes `subjectVersion` into a temporary copy of the spec, overwrites the
  definition, checks the created definition names that version, and prints it.

## The suite

[tests/agent/Customer_Summary-testSpec.yaml](../../tests/agent/Customer_Summary-testSpec.yaml), 16 cases (the cap is
20). Each has an outcome in plain words; subagent and action checks are set wherever a case has a route and actions.

| # | Kind | Utterance | Subagent | Actions |
|---|---|---|---|---|
| 1 | Summary for a named account | Give me a summary of Gallowglass Textiles | account_summary | resolve_account, get_brief |
| 2 | Summary with a question | What is going on with Gallowglass Textiles, and which deals are slipping? | account_summary | resolve_account, get_brief |
| 3 | Not found | Brief me on Zzqxv Nonexistent Holdings | account_summary | resolve_account |
| 4 | Not found, pasted Id | Brief me on 001000000000000AAA | account_summary | resolve_account |
| 5 | Several matches | Brief me on United Oil | account_summary | resolve_account |
| 6 | Follow-up that needs the first turn | What about their open deals? (after a summary) | account_summary | get_brief |
| 7 | Follow-up after a not-found | Show me their open cases | account_summary | resolve_account |
| 8 | Org-wide question after a summary | How many open opportunities are there in the whole org? | explore | explore_data |
| 9 | Org-wide explorer question | How many open opportunities are there? | explore | explore_data |
| 10 | Explorer list | List the five largest open opportunities | explore | explore_data |
| 11 | Outside the agent's job | What is the weather in Paris today? | none | none |
| 12 | Explorer follow-up | Which close this quarter? | explore | explore_data |
| 13 | Pronoun after an org-wide count | Which of them close this quarter? | explore | explore_data |
| 14 | A second account after a summary | Now brief me on Gallowglass Textiles (after another account) | account_summary | resolve_account, get_brief |
| 15 | After the resolver's access error (BE-29, N7) | Try Gallowglass Textiles again | account_summary | resolve_account, get_brief |
| 16 | After the over-cap line (BE-29, N1) | Then just Gallowglass Textiles on its own | account_summary | resolve_account, get_brief |

- **One sample account.** Every case that reaches a summary briefs **Gallowglass Textiles** (Greenville), from
  `data/sample/accounts.json`: three open deals, one of them past its close date, one closed-lost deal and one contact.
  It is not the demo account (Edge Communications, in the README and the browser suite) and no other script or check
  briefs it (the accuracy, sentiment and follow-up scripts use other accounts), so the rows a run writes do not
  change what those checks see. Other account names appear only as text in conversation history; nothing runs for
  them. The several-matches case names the three United Oil accounts and briefs none.
- **No write actions.** The agent has none, and no utterance or history turn asks to create, change or delete a record
  (`tests/test_agent_test_script.py` checks the words and that every expected action is one of `resolve_account`,
  `get_brief` and `explore_data`).
- **Changed from the 16-case spec before it.** Every Edge Communications case now uses Gallowglass Textiles. Dropped:
  "The Singapore one" (a pick from the United Oil list briefs a second account) and "Just the open deals for ..."
  (a third summary of the same kind). Added: cases 15 and 16.
- **The BE-29 error statuses.** BE-29 added two error replies: the resolver's ERROR when the account query fails
  (N7, "I couldn't search accounts. ...") and the over-cap ERROR when one call asks for more than three summaries
  (N1). Neither can be produced through the agent by the admin who runs the suite: the first needs a user without read
  access to Account, and this card may not create one; the second needs one action call with four account Ids, and
  `get_brief` passes exactly one. So cases 15 and 16 start after that reply (as conversation history) and check what
  the agent can be held to: it does not repeat the error, it resolves again and returns the summary. The statuses
  themselves are covered by Apex tests: the resolver's query error in `CustomerSummaryResolverTest` and the cap in
  `CustomerSummaryTest` (BE-29, [fr2-summary-accuracy.md](fr2-summary-accuracy.md)).

## The script

`bash scripts/agent-test.sh [--org <alias>] [--agent <DeveloperName>] [--spec <file>] [--wait <minutes>] [--dry-run]`

- Defaults: org `$SF_TARGET_ORG`, else `agent-probe`; agent `Customer_Summary`; the spec above; a 15-minute wait.
  Every `sf` call passes `-o`. `--dry-run` reads the version and builds the definition with `--preview`, and creates
  and runs nothing.
- Steps: read the active `BotVersion` of the agent; copy the spec into a temporary project folder with
  `subjectVersion: v<n>`; `sf agent test create --test-runner testing-center --force-overwrite` from that folder, so the
  metadata file the CLI writes lands there and never under `force-app`; check the created definition names `v<n>`;
  `sf agent test run --wait`; count. The folder is removed on exit, so `git status` does not change.
- Output: a header line with the agent, its version and the test name; one line per assertion type (`subagent`,
  `actions`, `outcome`, and any metric) with pass and fail counts; one `failed: case <n> <check>` line per failed
  check, numbered in the spec's order; a last line with the total and the version, which
  the ladder's `agent-suite` rung shows. The subagent check on a case that sets no subagent is left out and said so.
  Nothing from the `sf` output is echoed, so no record Ids, job Ids, usernames or hostnames are printed; a failed step
  prints only the error's name.
- Exit: 0 when every assertion passed, 1 when one failed, 2 for bad arguments, 3 when an org step failed or the run did
  not finish within the wait.
- Not in `force-app`: [validate-org.sh](../../scripts/validate-org.sh) and the README's quick start deploy `force-app`,
  so they never deploy a test that needs the agent.
- Checked without an org by `tests/test_agent_test_script.py`, which runs the script against a fake `sf` with canned
  results.

## The run in agent-probe

One run, 2026-11-16, about four minutes (19:07 to 19:11 UTC), `bash scripts/agent-test.sh` with its defaults:

| Check | Passed | Failed |
| --- | --- | --- |
| subagent | 15 | 0 (the off-topic case, which names no subagent, left out) |
| actions | 16 | 0 |
| outcome | 15 | 1 |
| Total | 46 of 47 on `Customer_Summary` v2, 16 cases | exit 1 |

No case ended in ERROR. Which case's outcome failed is not known: the script at that point printed counts only, and
the run's results are not queryable afterwards (`AiEvaluation` is not exposed to SOQL in agent-probe). The script now
prints a `failed: case <n> <check>` line per failure, by spec position only, so the next run names it. The suite was
not run a second time in this card.

What the run wrote, counted read-only before and after:

| Object | Gallowglass Textiles before | after | Org total before | after |
| --- | --- | --- | --- | --- |
| `Customer_Outcome__c` | 0 | 6 | 117 | 123 |
| `Customer_Summary_Session__c` | 0 | 1 | 19 | 20 |

Six outcomes for the six summary cases (1, 2, 6, 14, 15, 16), one session row for the one user and account, as the
summary path always writes. The explorer cases wrote nothing. The `sf agent test create` step also created or updated
the `Customer_Summary_Test` definition in the org, under the card's Approvals row. `git status` did not change.

## Findings for Ben

- The agent's script lags the Apex on one status. `resolve_account` returns `ERROR` when the account search
  fails (BE-29), and the agent's instructions handle it, but the action's output descriptions in the `.agent` still
  list only `RESOLVED`, `AMBIGUOUS` and `NOT_FOUND`. The agent is not republished in this card; it is a one-line fix to
  the descriptions at the next publish.
- One outcome check failed in the run and is not yet named (see above). The next run of the script names it by case
  number; a repeat failure on the same case is the one to look at, since a single LLM-judged miss can be judge noise.
- The two BE-29 error cases test the agent's answer after an error, given as history, not the error itself: neither
  error can be caused by an admin through the agent (the resolver's search does not fail for an admin, and the agent
  never asks for more than three summaries in one call). The Apex tests cover the errors themselves.
- Tests that run the suite in CI would need an org per run; the script is wired into the ladder's `agent-suite` rung
  only, which runs on Ben's go.

## Security suite (not written)

A security suite would cover the OWASP LLM Top 10 categories the agentforce-test skill tests: prompt injection
(direct, and through account text that `get_brief` and `explore_data` read back), leaking the system instructions,
reaching data the user cannot see (an Id pasted for an account outside the user's sharing, an explorer question about a
denied object), unbounded output, and claims the data does not support. The agent has no write actions, so the
write-bypass cases do not apply. It is not written or run here: it needs a non-production org (a sandbox or a scratch
org) and Ben's go.

## Undo

- The test definition `Customer_Summary_Test` is the only thing this card adds to the org. To remove it, delete that
  `AiEvaluationDefinition` in Setup (Testing Center); that is a destructive change and needs its own Approvals row.
- The rows a run writes are listed under [The run in agent-probe](#the-run-in-agent-probe). They are ordinary summary
  rows on one sample account; the outcome retention job expires outcomes as it does any other.
- In the repo: revert the BE-38 commit. The spec returns to its 16 cases on Edge Communications.
