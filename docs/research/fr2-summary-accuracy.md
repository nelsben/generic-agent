# FR2 summary accuracy: do the numbers in a live summary come from the gathered sections? (BE-29)

- Covers the accuracy check on card BE-29, which also hardens the summary for N1, N2, N3, N7 and N8 in
  [apex-review-2.md](../reviews/apex-review-2.md#new-findings).
- The check is `scripts/summary-accuracy.apex`. It runs on agent-probe on 2026-11-13, after BE-29 was deployed there
  (validate with RunLocalTests, 268 tests, 0 failures, then quick deploy).
- Short answer: across 5 accounts and 84 numbers, the model wrote 1 number that no section holds. It was a correct
  sum of two figures in one section, not an invented fact. No date, count or percent was unmatched.

## How the check works

- One account per execution, picked by name from the seed data (`data/sample/accounts.json`). One summary per
  transaction keeps it to about 25 queries and 3 model calls, the same as a rep's own request.
- It calls `CustomerSummary.run` for the account with no question and every section. It then lists every date,
  dollar amount, percent and whole number in the answer and looks for each one in the gathered section bodies
  (with record Ids removed, as the model sees them).
  - Dates: `yyyy-MM-dd`, "Month D, YYYY", "Month D" and "Month YYYY" are matched against the section dates.
  - Amounts: `$` amounts, with or without K, M or B, are matched within the precision written. "$1.2M" matches
    anything from 1,150,000 to 1,250,000, and "$45,000" matches only 45,000.
  - Percents and other whole numbers are matched exactly.
  - Numbers written as words ("two deals") are not checked.
- It prints only counts and true/false checks, plus each unmatched value with the answer section it sits in. It
  never prints an account name, an Id or answer text.
- It also checks the ERROR rule (N3): when a section is ERROR, the answer must say that part could not be loaded.

## Results

| Sample | Seed account | Sections OK / EMPTY / ERROR | Answer chars | Dates | Amounts | Percents | Counts | Unmatched |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Edge Communications | 7 / 0 / 0 | 2,943 | 4 | 11 | 0 | 8 | 1 (amount, headline) |
| 2 | Brindlewick Hydroponics | 5 / 2 / 0 | 1,598 | 5 | 6 | 1 | 5 | 0 |
| 3 | Tamsin Ridge Logistics | 4 / 3 / 0 | 1,530 | 5 | 6 | 1 | 3 | 0 |
| 4 | Oddfellow Marine Supply | 4 / 3 / 0 | 1,375 | 5 | 7 | 0 | 2 | 0 |
| 5 | Pimble Quarry Works | 4 / 3 / 0 | 1,405 | 5 | 6 | 1 | 3 | 0 |

- 84 numbers were checked and 83 matched a section.
- Every summary had status OK, and none reached the length cap (the longest was 2,943 of 5,900 characters), so no
  answer ended on the cut marker.
- No section came back ERROR, so the ERROR rule was not exercised live. It is covered by
  `CustomerSummaryTest.aFailedSectionInsideAPreReduceStillReachesTheSynthesisAsError` and the prompt check
  `synthesisPromptHasARuleForAFailedSection`.
- Before the recorded runs, one trial run on sample 1 had 24 numbers and 0 unmatched. The same account gives
  different wording from run to run, so a clean run does not prove the next one will be clean.

## The mismatch, explained

- **Sample 1, headline: an amount of 134,540.** Edge Communications has two open deals past their close date, at
  9,000 and 125,540. The Open deals section lists both deals, with their amounts and the OVERDUE flag, and its top
  line says "2 overdue". It does not state the total of the overdue deals. The model added the two amounts and
  put the total in the headline.
- A read-only aggregate on the org confirms the figure: 2 open overdue deals, summing to 134,540. The number is
  right, but no section holds it, so the reader cannot trace it to a source.
- Prompt rule 1 ("Never invent facts, names, numbers or dates") does not forbid arithmetic on numbers that are in
  the inputs. The model treated a sum as not invented.

## Proposed follow-up (not built here)

Pick one:

1. **Runtime fact, preferred.** Have the Open deals section state the overdue total itself, for example
   "2 overdue ($134,540)". The headline's most likely finding then comes from deterministic Apex, and the
   accuracy check matches it.
2. **Prompt rule.** Add to the synthesis prompt: "Use only the numbers as written in the inputs. Do not add,
   subtract, average or round them into new figures." This is cheaper, but the model may not always follow it.
3. **Runtime check.** After synthesis, run the same token match this script uses. If a number is not in the
   sections, record it (and optionally retry once). The card says not to build this here.

Option 1 also helps option 2: once the section states the total, the model has no reason to compute it.

## What the runs wrote

- Customer Summary session rows (`Customer_Summary_Session__c`): 1 before the runs, 5 after.
  - 4 new rows, one each for samples 2 to 5.
  - The existing row for sample 1 was updated, once by the trial run and once by the recorded run.
  - These are the product's own memory rows for the running user, the same rows a rep's request writes.
- Outcome rows: 0. The org has no custom object with "outcome" in its name, so nothing records outcomes yet.
- Old Account Brief session rows (`Account_Brief_Session__c`): 3, not touched.
- Model calls: 3 per summary, 18 in total across the six runs (five recorded, one trial).

## How to run it again

```
for i in 0 1 2 3 4; do
  sed "s/^Integer SAMPLE = 0;/Integer SAMPLE = $i;/" scripts/summary-accuracy.apex > "$TMPDIR/s$i.apex"
  sf apex run --file "$TMPDIR/s$i.apex" --target-org agent-probe --json > "$TMPDIR/s$i.json"
done
```

- The `ACC|` lines are in the USER_DEBUG lines of each JSON log. The log escapes `|` as `&#124;`.
- Anonymous Apex does not allow `WITH SYSTEM_MODE`, so the script's row counts use plain queries. Those run with
  the signed-in admin's access.
