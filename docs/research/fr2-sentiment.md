# FR2: customer sentiment on the summary, measured in agent-probe (BE-36)

Run 2026-11-14 in `agent-probe`, as the signed-in System Administrator. Three existing sample accounts from the seed
data were each scored in three runs, with `scripts/sentiment-check.apex`. Nothing was inserted or backdated to make a
case, no user was created, and the org this was first built in was not touched. Ids, usernames and hostnames are left
out. The sentiment is written onto the summary's outcome from [fr2-customer-outcomes.md](fr2-customer-outcomes.md)
(BE-35).

## Result

- **Edge Communications agrees, and holds steady:** At risk in all six runs, across both prompt versions.
- **The sparse account agrees only after a prompt fix.** With the first prompt, the account with one open deal and
  nothing else came back Positive in 3 of 3 runs. The rubric's two absence points ("open deals with none overdue" and
  "no open cases") counted as the two signals the sparse rule asked for, so the model was following the prompt. After
  the fix, 2 runs returned "Not enough activity". The third reply failed the strict parse or the call, and was stored
  as no score, as designed.
- **Brindlewick Hydroponics did not agree after the fix.** It was Positive in 3 of 3 runs on the first prompt and
  Concerned in 3 of 3 on the second. Its records score 0 (Neutral) under the rubric itself:
  - a win 32 days before the run: +2
  - one overdue open deal: -1
  - engagement that says contact has gone quiet: -1
- **The model mis-adds the rubric.** Both prompt versions got Brindlewick's total wrong, in opposite directions. The
  first gave the "none overdue" point to an account that has an overdue deal. The second counted the win as less than
  +2.
- **Stability is high within a prompt and low across prompts.** Every run returned the same label as the other two runs
  of its account and prompt version (the one stored no score aside). An edit to one rule that did not touch Brindlewick's
  signals moved its label two steps.

**Recommendation: the score is not steady enough to chart yet.** Repeated runs agree, but an edit to one prompt
rule moves a label by two steps, so a chart line would show prompt edits and model arithmetic, not the customer.
The label can be shown on the summary as it is today. Before the score goes on a chart:

- Move the arithmetic to Apex. The model would return only the signal counts, which are facts it reads off the
  reduced sections. Apex would add the points, map the total to the score, and apply the sparse rule.
- Then repeat this check with more accounts.

## Design

- **One extra model call per summary.** It runs after the synthesis in the same reduce step, and makes no new queries.
  Its prompt is `AgentPrompt_Sentiment`, with its own `Agent_Prompt_Setting` record (Sentiment: 200 max tokens, the
  same model as the other prompts).
- **What the call reads:** today's date and the already-reduced sections, namely open deals, cases, the engagement
  summary and the deal history summary. It does not read the profile, the account name or the earlier outcomes. A
  section that was not requested is sent as `EMPTY: not requested`.
- **What the call returns:** strict JSON `{"score", "label", "reason"}`.
  - The score is an integer from -2 to +2.
  - Each score has one label: At risk, Concerned, Neutral, Positive or Very positive.
  - The reason is one line under 255 characters.
  - One code fence around the whole reply is tolerated.
  - Anything else is stored as no score: no prose, no extra keys, no label that does not match the score, and no
    fractional or out-of-range score.
- **Sparse data.** A null score with the label "Not enough activity" is the sparse answer.
  - Apex returns it without a call when no evidence section has content. The evidence sections are open deals, cases,
    activity, calls and deal history.
  - The prompt returns it when fewer than two signals of activity are present.
- **No sentiment for a partial or failed summary.** There is no call and the fields stay empty unless every evidence
  section was requested and none failed.
- **Budget.** At most one sentiment call per brief, so 12 model calls at the three-brief cap. It is skipped once the
  transaction's model time reaches 90 seconds, which leaves 30 seconds of the 120-second callout allowance.
- **The summary still returns.** A model failure or a malformed reply leaves score, label and reason empty, and the
  summary and its outcome are still written.

## Samples and expected directions

The directions below were written down before the first live run, from each account's records alone.

| Sample | Account | Expected | Why |
|---|---|---|---|
| 1 | Edge Communications | negative (At risk or Concerned) | an open escalated high-priority case, two open deals past their close date |
| 2 | Brindlewick Hydroponics | positive (Positive or Very positive) | a deal won about a month before the run |
| 3 | United Oil & Gas, UK | sparse (Not enough activity) | one open deal and nothing else on record |

Neutral agrees with none of them. Read against the rubric, Brindlewick's expected direction was too generous: its
quiet engagement and overdue deal offset the win, so Neutral is the rubric's answer.

## Runs

The script prints only the expected and returned label. The reasons were read afterwards, to explain the misses.

**Prompt version 1** (as first deployed)

| Sample | Run 1 | Run 2 | Run 3 | Agrees |
|---|---|---|---|---|
| 1 Edge Communications | At risk | At risk | At risk | 3 of 3 |
| 2 Brindlewick Hydroponics | Positive | Positive | Positive | 3 of 3 |
| 3 United Oil & Gas, UK | Positive | Positive | Positive | 0 of 3 |

The sparse account's reason was "One open deal with no overdue items and no open cases": the two absence points.

**Prompt version 2.** Rule 4 now counts only signals that something happened toward the two-signal minimum. This
prompt was changed after seeing version 1's results.

| Sample | Run 1 | Run 2 | Run 3 | Agrees |
|---|---|---|---|---|
| 1 Edge Communications | At risk | At risk | At risk | 3 of 3 |
| 2 Brindlewick Hydroponics | Concerned | Concerned | Concerned | 0 of 3 |
| 3 United Oil & Gas, UK | Not enough activity | Not enough activity | no score | 2 of 3 |

Brindlewick's version 2 reasons all said that one overdue deal and quiet contact "offset" the recent win. By the rubric
that is a total of 0, not -1.

| | Version 1 | Version 2 |
|---|---|---|
| Agreement with the expected direction | 6 of 9 | 5 of 9 |
| Runs that matched the other two runs of their account | 9 of 9 | 8 of 9 (the one with no score) |

## Rows written

Each run is one real summary, so it writes the product's own rows, as any summary does:

- one Customer Summary session row per user and account, updated on a repeat
- one Summary outcome

Counts in `agent-probe` before the first run and after the last:

| Object | Before | After | Added |
|---|---|---|---|
| Customer Summary session | 9 | 12 | 3 (one per sample account) |
| Customer outcome | 31 | 49 | 18 (one per run) |

## Follow-ups

- Do the Apex arithmetic from the recommendation, then repeat this check with more accounts.
- A summary now makes 4 model calls, not 3. The per-run model-call counts in the e2e README predate this card. They
  were not edited here, because that file is outside this card's scope.
