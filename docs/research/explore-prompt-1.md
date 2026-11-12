# Explore prompt iteration 1 (BE-17)

Org: agent-probe only. Date: 2026-11-12. Everything below was read from command output in this
run (verified) unless it says otherwise.

## Why

FE-10 found that the explorer wrote every row of its result into the answer text, although rule 9
of `AgentPrompt_Explore` already said "summarize rather than list every row". The table under the
answer then fell out of the 340x480 panel, so the explore capture had to add "Answer in one
sentence." to its question. This change makes the rule work, so the capture asks the plain question
a rep would type: "Which 5 open opportunities have the largest amounts?"

## The rule 9 change

Only rule 9 changed. Rules 1 to 8, 10 and 11, the reply format and the template variables are
unchanged; `tests/test_explore_prompt.py` checks all of that and pins the new rule 9 text.

Before:

> 9. The answer text is plain text, at most about 1,500 characters. No markdown headers, tables or
> JSON inside it. Lines starting with "- " are allowed. The system shows the last result's rows as a
> table after your text, so summarize rather than list every row.

Revision 1 (deployed, then replaced):

> 9. The answer text is plain text, at most about 1,500 characters. No markdown headers, tables or
> JSON inside it. The system shows the last result's rows as a table right after your text, so the
> text must not list those rows: open with one or two short sentences that answer the question
> directly (a count, a total, the top item, or what stands out). Do not repeat the names and values
> of the rows that table shows, and name at most three records. Lines starting with "- " are allowed,
> but not to restate the table's rows. A result that is one row of totals, such as a count, is the
> answer: state it in the text. Facts from an earlier query are not in that table, so they belong in
> the text too.

Revision 2 (deployed, kept):

> 9. The answer text is plain text, at most about 1,500 characters, and it names at most three
> records. No markdown headers, tables or JSON inside it. The system shows the last result's rows as
> a table right after your text, and when the question asks which records or for a list, that table
> is the answer. So open with one or two short sentences that lead into it: the top item, the total
> or the range, a count, or what stands out. Do not repeat the names and values of the table's rows,
> whether in a sentence or as lines. Lines starting with "- " are allowed, but not to restate the
> table's rows. A result that is one row of totals, such as a count, is the answer: state it in the
> text. Facts from an earlier query are not in that table, so they belong in the text too.

Why a second revision: revision 1 fitted (236 px of 273 px), but its answer still named all five
records with their amounts, in one sentence instead of as "- " lines. For a "which five" question,
"answer the question directly" read as "give the five names", and the three-record limit came
too late in the rule to win. Revision 2 puts the limit first, says the table is the answer to a
list question, and covers rows restated in a sentence as well as in lines.

## Fit and answers

The capture `e2e/capture/04-explore.capture.js` asks the question, scrolls the question to the top
of the scroll box and fails unless the table's header row is inside it. It now also logs the answer
text as the panel shows it (after the privacy mask, so the record owner reads "Sample Owner").

| Run | Prompt | Question to header row | Scroll box | Fits | Records named in the text |
|---|---|---|---|---|---|
| Red | before | 470 px | 273 px | no | 5, as "- " lines with stage, account and close date |
| 1 | revision 1 | 236 px | 273 px | yes | 5, in one sentence |
| Measured 1 | revision 2 | 236 px | 273 px | yes | 2 |
| Measured 2 | revision 2 | 255 px | 273 px | yes | 2 |
| Measured 3 | revision 2 | 216 px | 273 px | yes | 2 |
| Recapture | revision 2 | 216 px | 273 px | yes | 1 |

Revision 2: 3 of 3 measured runs fit, and none names more than three records. Each still gives
the name and amount of one or two table rows, and all three, and the recapture, wrote three
sentences, not the "one or two" the rule asks for; they still fit.

The answers, word for word:

- **Red (before):** "The 5 open opportunities with the largest amounts are:" then five "- " lines,
  "Juniper Project B: $293,920 (Needs Analysis stage, Juniper Lantern Media, closes 2027-01-14)"
  and the same for Fernhollow Project C, Pimble Project B, Oddfellow Project A and United Oil
  Singapore Terminal Link, then "All five opportunities are owned by Sample Owner. The total value
  of these top 5 opportunities is $1,372,400."
- **Revision 1:** "The five open opportunities with the largest amounts are Juniper Project B
  ($293,920), Fernhollow Project C ($280,960), Pimble Project B ($274,480), Oddfellow Project A
  ($268,000), and United Oil Singapore Terminal Link ($255,040). All five are owned by Sample Owner
  and are in either Needs Analysis or Proposal/Price Quote stages."
- **Measured 1:** "The 5 open opportunities with the largest amounts range from $255,040 to
  $293,920. The top opportunity is Juniper Project B at $293,920, followed by Fernhollow Project C
  at $280,960. Most of these deals are in Needs Analysis or Proposal/Price Quote stages, with close
  dates between November 2026 and January 2027."
- **Measured 2:** "The five open opportunities with the largest amounts are all owned by Sample
  Owner. The top opportunity is Juniper Project B at $293,920, followed by Fernhollow Project C at
  $280,960. These deals range from $255,040 to $293,920 and are in various stages from Needs
  Analysis to Proposal/Price Quote, with close dates between November 2026 and January 2027."
- **Measured 3:** "The 5 open opportunities with the largest amounts range from $255,040 to
  $293,920. Juniper Project B leads at $293,920, followed by Fernhollow Project C at $280,960. All
  five are owned by Sample Owner and are currently in either Needs Analysis or Proposal/Price Quote
  stages."
- **Recapture (the committed still):** "The 5 open opportunities with the largest amounts total
  nearly $1.4 million, ranging from $255,040 to $293,920. All five are owned by Sample Owner, with
  most in Needs Analysis stage and two at Proposal/Price Quote. The top opportunity is Juniper
  Project B at $293,920, closing in January 2027."

## No regression

- **e2e:** one full `SF_TARGET_ORG=agent-probe npm run test:e2e` on revision 2: **8 passed (2.7 m)**,
  spec 2 in 9.8 s. No rerun was needed.
- **Agent spec:** `Account_Brief_Test` run once against the active version 2 (BotVersion read
  first: v1 Inactive, v2 Active; the definition was not re-created), the way
  [agent-iteration-1.md](agent-iteration-1.md) ran it. COMPLETED, 09:43:50Z to 09:47:11Z. **16 of
  16** on the reply and action assertions; 15 of 16 topic assertions, the miss being case 12's
  expected false FAILURE (a guardrail case names no topic).

| Case | Utterance (short) | Topic | Actions | Rating | Result |
|---|---|---|---|---|---|
| 1 | Give me a brief on Edge Communications | account_brief | resolve_account, get_brief | 3 | PASS |
| 2 | What is going on with Edge Communications ... | account_brief | resolve_account, get_brief | 5 | PASS |
| 3 | Brief me on Zzqxv Nonexistent Holdings | account_brief | resolve_account | 5 | PASS |
| 4 | Brief me on a pasted Id that matches nothing | account_brief | resolve_account | 5 | PASS |
| 5 | Brief me on United Oil | account_brief | resolve_account | 5 | PASS |
| 6 | Just the open deals for Edge Communications | account_brief | resolve_account, get_brief | 4 | PASS |
| 7 | What about their open cases? (after a brief) | account_brief | resolve_account, get_brief | 5 | PASS |
| 8 | Show me their open cases (after a no-match) | account_brief | resolve_account | 5 | PASS |
| 9 | How many open opportunities are there in the whole org? | explore | explore_data | 5 | PASS |
| 10 | How many open opportunities are there? | explore | explore_data | 5 | PASS |
| 11 | List the five largest open opportunities | explore | explore_data | 5 | PASS |
| 12 | What is the weather in Paris today? | topic_selector | none | 5 | PASS (topic FAILURE ignored) |
| 13 | Which close this quarter? (after a count) | explore | explore_data | 5 | PASS |
| 14 | Which of them close this quarter? | explore | explore_data | 4 | PASS |
| 15 | The Singapore one | account_brief | resolve_account, get_brief | 5 | PASS |
| 16 | Now brief me on Brindlewick Hydroponics | account_brief | resolve_account, get_brief | 5 | PASS |

The explore cases show the new rule in the agent too. Cases 9 and 10 still state the count in the
text ("There are 36 open opportunities ..."), the one-row-totals clause. Case 11's text is now a
lead (the total, over $1.37 million, and the range) followed by the explorer's table of five rows,
which the judge found relayed unchanged. Cases 13 and 14 open with a count and a total, name the
earliest and largest deals, then give the table.

## Recapture

`SF_TARGET_ORG=agent-probe npx playwright test -c playwright.capture.config.js e2e/capture/04-explore.capture.js`,
frames to a scratch folder outside the repo, with the privacy machinery unchanged (masking, the
0.5 s checks, the all-frames checks). Read by eye:

- `explore-answer.png` (1520x1500): the plain question, the recapture answer above over six lines,
  the caption "Opportunity · 5 of 36 rows", the Name, Amount and StageName headers and the first
  row, Juniper Project B.
- `explore-drill.gif` (760x750, 7.8 s, 8 frames at 1 fps plus the last): frame 1 the answer and the
  first row; frame 2 the panel dimmed under a spinner after the click; frames 3 to 5 the drill view
  of Juniper Project B under "Conversation > Juniper Project B"; frames 6 to 8 and the last frame
  the conversation again, the end of the answer and the first three rows (Juniper Project B,
  Fernhollow Project C, Pimble Project B).
- `drill-view.png` (1520x1500): the drill view of Juniper Project B with Name, StageName, Amount,
  CloseDate and Probability. The new file is byte-identical to the one it replaced (the same
  record, rendered the same), so git shows no change to it.

The record header in all three shows the masked owner "Sample Owner" and "email hidden" on the
contact cards. Every other file in `docs/assets/` is unchanged (`git diff --stat`).

## Deploy steps, in order

| # | Step | Command | Outcome |
|---|---|---|---|
| 1 | Red, unit | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_explore_prompt` | 2 of 7 fail on rule 9 (`.delegation/BE-17/red-1.txt`, git-ignored) |
| 2 | Red, capture | the capture file above, plain question, prompt unchanged | fails its fit check: 470 px needed, 273 px box |
| 3 | Validate revision 1 | `sf project deploy validate --metadata StaticResource:AgentPrompt_Explore --test-level RunLocalTests -o agent-probe --wait 4 --json` | Succeeded, 1 component, 154 tests, 0 failures |
| 4 | Quick deploy | `CONFIRM_PROD=1 sf project deploy quick --job-id <validation> -o agent-probe --wait 4 --json` | Succeeded, 1 component |
| 5 | Run 1 | the capture file | fits (236 of 273 px), but names all five records |
| 6 | Validate revision 2 | the same validate with `--async`, then `sf project deploy resume --job-id <validation> --wait 2 --json` | Succeeded, 1 component, 154 tests, 0 failures |
| 7 | Quick deploy | as step 4 | Succeeded, 1 component |
| 8 | Measured runs | the capture file, 3 times | 3 of 3 fit (table above) |
| 9 | e2e | `SF_TARGET_ORG=agent-probe npm run test:e2e` | 8 passed (2.7 m) |
| 10 | Version table | read-only `SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status FROM BotVersion` | v1 Inactive, v2 Active |
| 11 | Agent spec | `sf agent test run --api-name Account_Brief_Test --test-runner testing-center --result-format json -o agent-probe --json`, then `sf agent test resume --job-id <run> --wait 2` | COMPLETED, 16 of 16 |
| 12 | Recapture | the capture file | the three assets above |

Steps 9 and 11 overlapped: the spec run (09:43:50Z to 09:47:11Z) was started while the e2e run was
still going in the background, and both finished green. Two prompt revisions reached the org, the
most the card allows. Nothing was published or
activated, and no sign-in or sign-out was made. Only the static resource was deployed.

Org model use: six explorer questions through the panel (each up to five model calls), the e2e
run's model calls (about seven) and the 16 spec cases (each also graded).

## Left open

- Every revision 2 answer ran to three sentences against the rule's "one or two". They fit, so no
  third revision was made (the card allows two).
- The answers mention the owner although the question does not ask for one. In the still it is the
  masked "Sample Owner".
