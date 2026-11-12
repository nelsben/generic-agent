# Explore prompt iteration 2 (BE-18)

Org: agent-probe only. Date: 2026-11-12. Everything below was read from command output in this
run (verified) unless it says otherwise. Follows [explore-prompt-1.md](explore-prompt-1.md).

## Outcome

**Shipped in attempt 2: revision 3 of rule 9, with a DataExplorer change.** See
[Attempt 2](#attempt-2-revision-3-shipped). Attempt 1, below, rolled revision 3 back under the
card's spec rule.

Attempt 1: **not shipped; the org and `main` kept BE-17's rule 9.** Three revisions of rule 9 reached the org.
Revision 3 met the bar on the list (L), count (C) and follow-up (F) questions in 3 of 3 runs each.
Two things still missed:

- **S named the account.** On "What is the largest open opportunity?" every revision 3 answer named
  the opportunity's account, Juniper Lantern Media, as well as the opportunity. The bar asks for
  exactly one record.
- **Spec case 2 failed its reply check.** The Account_Brief spec, run once on revision 3, passed 15
  of 16 replies. The card says to roll back on any regression, so the original resource was
  redeployed and the repo change reverted.

Case 2 is a brief case. Its actions were `resolve_account` and `get_brief`, which use the
BriefSynthesis, BriefEngagement and BriefDealHistory prompts. Only `DataExplorer` loads
`AgentPrompt_Explore`, and nothing on the brief path calls it. The judge marked the brief "overly
detailed", although its headline named the two slipping deals. The judge has rated brief cases
unevenly before: case 1 was rated 3 here and in BE-17.

So the case 2 miss is very likely judge noise. The rollback follows the card's rule; it does not
show that revision 3 broke the brief.

At the end of attempt 1 the commit held only this page, the pointer line in explore-prompt-1.md,
and the capture file without BE-17's `console.log` of the answer text.

## The rule 9 revisions

Only rule 9 changed in each revision. Rules 1 to 8, 10 and 11, the reply format and the template
variables were unchanged, and `tests/test_explore_prompt.py` pinned each revision's text while it
was live. That test is back to BE-17's text with the prompt.

Before (BE-17, on `main`, and back in the org now):

> 9. The answer text is plain text, at most about 1,500 characters, and it names at most three
> records. No markdown headers, tables or JSON inside it. The system shows the last result's rows as
> a table right after your text, and when the question asks which records or for a list, that table
> is the answer. So open with one or two short sentences that lead into it: the top item, the total
> or the range, a count, or what stands out. Do not repeat the names and values of the table's rows,
> whether in a sentence or as lines. Lines starting with "- " are allowed, but not to restate the
> table's rows. A result that is one row of totals, such as a count, is the answer: state it in the
> text. Facts from an earlier query are not in that table, so they belong in the text too.

Revision 1:

> 9. The answer text is plain text of at most two short sentences in all, with no markdown headers,
> tables, lists or JSON. The system shows the last result's rows as a table right after your text,
> and when the question asks which records or for a list, that table is the answer, so the text
> only leads into it with a count, the total or the range, or what stands out. Name at most one
> record in the text (an opportunity, account or contact each count as one), and when the question
> asks for a single record, such as the largest, name only that record and its key value. Do not
> repeat the table's other rows, and do not mention an owner or any user unless the question asks
> about owners. A result that is one row of totals, such as a count, is the answer: state the number
> in the first sentence. Facts from an earlier query are not in that table, so they belong in the
> text too. When the question points back to records of an earlier answer ("those", "them") that it
> does not list, answer about exactly those records: keep the earlier question's filters, and if it
> took only the top or first few, rerun it unchanged with Id, then filter on those Ids, so the table
> shows only the matches.

Revision 2 changed the record limit and added one example:

> ... Name at most one record in the text, even when several match: give their count and the top
> one, and leave the rest to the table. An account or contact counts as a record too, so when the
> question asks for a single record, such as the largest, name only that record and its key value,
> not its account. ... [the rest as revision 1] ... A good lead: "Of those 8 deals, 3 close next
> month. The largest is Acme Renewal at $310,000."

Revision 3 changed two sentences of revision 2 and left the rest byte-identical:

> ... Name at most one record in the text, even when the question asks which ones and several match:
> give how many match and the top one, and never put a second name in the text, since the table
> shows the rest. ... rerun it unchanged with Id, then run one more query on those Ids with the new
> condition, so the table shows only the matches. A good lead for a "which of those" follow-up: "Of
> those 8 deals, 3 close next month. The largest is Acme Renewal at $310,000."

Why each revision:

- **Baseline:** the follow-up failed for a structural reason. The panel passes earlier turns to the
  explorer as question and answer text only (`DataExplorer.historyText`), so the model never sees
  the five rows. It ran a new query for all open opportunities that close in 2027 and said that all
  five of "those" close in 2027. Only two of the five do.
- **Revision 1** added the follow-up clause, which tells the model to rerun the earlier query and
  then narrow it. The record limit was only in a parenthesis.
- **Revision 2** came after F named both matching records and S named the account.
- **Revision 3** came after F named both records again, and in one run filtered the five rows in its
  head without a second query.

## How it was measured

The four questions were asked through the panel on the Edge Communications account page, with the
capture privacy guard installed (the owner reads "Sample Owner"):

| Shape | Question |
|---|---|
| L | Which 5 open opportunities have the largest amounts? |
| C | How many open opportunities are there? |
| S | What is the largest open opportunity? |
| F | Which of those close in 2027? (asked right after L in the same panel session) |

C and S each ran on a fresh page load. A git-ignored Playwright script and a sentence counter did
the work; neither is committed.

The counter applies the card's rule. It splits on ".", "!" or "?" followed by whitespace or the
end of the text. A "." between two digits, or inside Inc., Corp., Ltd., e.g., i.e. or vs., does not
end a sentence. A line starting with "- " or with a digit and "." counts as one sentence.

"Records named" counts opportunity and account names from the answer's own tables and, for F, from
L's table. The truth for F, read from L's table: of the five, Juniper Project B (2027-01-14) and
Fernhollow Project C (2027-01-07) close in 2027; Pimble Project B, Oddfellow Project A and United
Oil Singapore Terminal Link close in November or December 2026.

## Answers and counts

S. = sentences. Named = records named in the text. Owner = mentions an owner or user.

| Run | Prompt | Shape | S. | Named | Owner | Answer, word for word |
|---|---|---|---|---|---|---|
| Baseline | before | L | **3** | **2** | **yes** | The five open opportunities with the largest amounts range from $255,040 to $293,920. Juniper Project B leads at $293,920, followed by Fernhollow Project C at $280,960. All five are owned by Sample Owner and are in either Needs Analysis or Proposal/Price Quote stages, with close dates between November 2026 and January 2027. |
| Baseline | before | C | 1 | 0 | no | There are 36 open opportunities in total. |
| Baseline | before | S | 2 | **2** | **yes** | The largest open opportunity is Juniper Project B with an amount of $293,920. It is currently in the Needs Analysis stage with a close date of January 14, 2027, owned by Sample Owner for the account Juniper Lantern Media. |
| Baseline | before | F | **3** | 1 | **yes** | All five of those opportunities close in 2027. Each has a close date in January 2027, ranging from January 7th to January 31st. Juniper Project B remains the largest at $293,920, and all five continue to be owned by Sample Owner. (**wrong set**: a new query, 5 of 11 rows, three of them not in L's five) |
| 1a | rev 1 | L | 1 | 1 | no | The 5 open opportunities with the largest amounts range from $255,040 to $293,920, with Juniper Project B at the top. |
| 1a | rev 1 | C | 1 | 0 | no | There are 36 open opportunities. |
| 1a | rev 1 | S | 1 | **2** | no | The largest open opportunity is Juniper Project B for $293,920 with Juniper Lantern Media in the Needs Analysis stage. |
| 1a | rev 1 | F | - | - | - | No answer within the script's 150 s wait. Every model call was slow during this pass: L took about 2.5 minutes, against 6 to 21 s for every timed question in later passes |
| 1b | rev 1 | L | 1 | 1 | no | The 5 open opportunities with the largest amounts range from $255,040 to $293,920, led by Juniper Project B at $293,920. |
| 1b | rev 1 | F | 1 | **2** | no | Of the 5 largest open opportunities, 2 close in 2027: Juniper Project B at $293,920 and Fernhollow Project C at $280,960. (right set: two queries, table of the 2 matches) |
| 2a | rev 2 | L | 2 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920. The biggest is Juniper Project B at $293,920. |
| 2a | rev 2 | C | 1 | 0 | no | There are 36 open opportunities. |
| 2a | rev 2 | S | 1 | 1 | no | The largest open opportunity is Juniper Project B at $293,920. |
| 2a | rev 2 | F | 1 | **2** | no | Of those 5 opportunities, 2 close in 2027: Juniper Project B at $293,920 and Fernhollow Project C at $280,960. (right set, but one query: the table showed all five) |
| 3a | rev 3 | L | 1 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920, led by Juniper Project B at $293,920. |
| 3a | rev 3 | C | 1 | 0 | no | There are 36 open opportunities. |
| 3a | rev 3 | S | 1 | **2** | no | The largest open opportunity is Juniper Project B for $293,920 at Juniper Lantern Media, closing January 14, 2027. |
| 3a | rev 3 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |
| 3b | rev 3 | L | 2 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920. The biggest is Juniper Project B at $293,920. |
| 3b | rev 3 | C | 1 | 0 | no | There are 36 open opportunities. |
| 3b | rev 3 | S | 1 | **2** | no | The largest open opportunity is Juniper Project B at $293,920.00 from Juniper Lantern Media, currently in Needs Analysis stage and closing January 14, 2027. |
| 3b | rev 3 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |
| 3c | rev 3 | L | 1 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920, with Juniper Project B at the top. |
| 3c | rev 3 | C | 1 | 0 | no | There are 36 open opportunities. |
| 3c | rev 3 | S | 1 | **2** | no | The largest open opportunity is Juniper Project B at $293,920.00 for Juniper Lantern Media in the Needs Analysis stage. |
| 3c | rev 3 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |

Bold marks a miss against the bar.

Every C answer states 36 in its first sentence. On revision 3, F used the earlier result in 3 of
3 runs. Each ran two queries: the L query again with Id (5 of 36 rows), then those five Ids with
the 2027 condition (2 rows, Juniper Project B and Fernhollow Project C), so the table holds just
the two matches.

Revision 3 against the bar, 12 answers:

| Check | L | C | S | F |
|---|---|---|---|---|
| At most two sentences | 3 of 3 | 3 of 3 | 3 of 3 | 3 of 3 |
| Records named (at most one; S exactly the one) | 3 of 3 | 3 of 3 | **0 of 3** (all add the account) | 3 of 3 |
| No owner or user | 3 of 3 | 3 of 3 | 3 of 3 | 3 of 3 |
| C's number in sentence 1 | | 3 of 3 | | |
| F about L's five | | | | 3 of 3 |

The S clause, "name only that record and its key value, not its account", is the same in
revisions 2 and 3. It held in the one revision 2 run and failed in all three revision 3 runs, so it
is not reliable.

## Fit (L)

The question, the answer and the table header row, measured from the top of the question to the
bottom of the header row with the question scrolled to the top of the panel's scroll box:

| Run | Prompt | Needed | Box | Fits |
|---|---|---|---|---|
| Baseline | before | 236 px | 273 px | yes |
| 1a, 1b | rev 1 | 158 px | 273 px | yes |
| 2a | rev 2 | 158 px | 273 px | yes |
| 3a, 3b, 3c | rev 3 | 158 px | 273 px | yes, 3 of 3 |
| Recapture | rev 3 | 158 px | 273 px | yes |

## No regression

Both checks ran on revision 3.

- **e2e:** one full `SF_TARGET_ORG=agent-probe npm run test:e2e`, 14:56:14Z to 14:59:05Z: **8
  passed (2.8 m)**, spec 2 in 11.0 s. No rerun was needed.
- **Agent spec:** the read-only BotVersion query showed v1 Inactive and v2 Active. The
  `Account_Brief_Test` definition was not re-created. The run started after e2e finished and went
  from 14:59:27Z to 15:01:46Z. The explore recapture (one explorer question) ran inside that window.
  Result: **15 of 16** on replies, 16 of 16 on actions, and 15 of 16 on topic, the miss being case
  12's expected false FAILURE.

| Case | Utterance (short) | Topic | Actions | Rating | Reply |
|---|---|---|---|---|---|
| 1 | Give me a brief on Edge Communications | account_brief | resolve_account, get_brief | 3 | PASS |
| 2 | What is going on with Edge Communications, and which deals are slipping? | account_brief | resolve_account, get_brief | 2 | **FAILURE** |
| 3 | Brief me on Zzqxv Nonexistent Holdings | account_brief | resolve_account | 5 | PASS |
| 4 | Brief me on a pasted Id that matches nothing | account_brief | resolve_account | 5 | PASS |
| 5 | Brief me on United Oil | account_brief | resolve_account | 5 | PASS |
| 6 | Just the open deals for Edge Communications | account_brief | resolve_account, get_brief | 3 | PASS |
| 7 | What about their open cases? (after a brief) | account_brief | resolve_account, get_brief | 5 | PASS |
| 8 | Show me their open cases (after a no-match) | account_brief | resolve_account | 5 | PASS |
| 9 | How many open opportunities are there in the whole org? | explore | explore_data | 5 | PASS |
| 10 | How many open opportunities are there? | explore | explore_data | 5 | PASS |
| 11 | List the five largest open opportunities | explore | explore_data | 5 | PASS |
| 12 | What is the weather in Paris today? | topic_selector | none | 5 | PASS (topic FAILURE ignored) |
| 13 | Which close this quarter? (after a count) | explore | explore_data | 5 | PASS |
| 14 | Which of them close this quarter? | explore | explore_data | 3 | PASS |
| 15 | The Singapore one | account_brief | resolve_account, get_brief | 5 | PASS |
| 16 | Now brief me on Brindlewick Hydroponics | account_brief | resolve_account, get_brief | 5 | PASS |

The judge's reason on case 2: the reply "provides a comprehensive account overview ... is overly
detailed and does not directly answer the user's query about which deals are slipping". The reply's
first line named the two overdue deals as slipping, and the full brief followed. Every explore case
(9, 10, 11, 13, 14) passed.

## Recapture (on revision 3, then reverted)

`CAPTURE_FRAMES_DIR=<scratch> SF_TARGET_ORG=agent-probe npx playwright test -c playwright.capture.config.js e2e/capture/04-explore.capture.js`
passed with its privacy checks: masking, the 0.5 s checks and the all-frames checks.

The new still showed the question, the two-sentence answer "The 5 largest open opportunities range
from $255,040 to $293,920. The biggest is Juniper Project B at $293,920.", the caption
"Opportunity · 5 of 36 rows", and the Name, Amount and Account.Name headers with two rows. The GIF
showed the same answer, a click on Juniper Project B, the spinner, the drill view and the way back.
`drill-view.png` came out byte-identical.

With the rollback, the new `explore-answer.png` and `explore-drill.gif` were restored from git, so
they still match the prompt in the org. MANIFEST.md and the pattern page are unchanged. The capture
file no longer logs the answer text; its fit line (box and needed px) stays.

## Deploy steps, in order

| # | Step | Command | Outcome |
|---|---|---|---|
| 1 | Org prompt check | `sf project retrieve start --metadata StaticResource:AgentPrompt_Explore --target-metadata-dir <scratch> --unzip -o agent-probe --json`, then `cmp` with `main` | byte-identical |
| 2 | Baseline | the measurement script, four shapes once | table above |
| 3 | Red, unit | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_explore_prompt` with revision 1's text asserted | 1 of 7 fails on rule 9 (`.delegation/BE-18/red-1.txt`, git-ignored) |
| 4 | Validate rev 1 | `sf project deploy validate --metadata StaticResource:AgentPrompt_Explore --test-level RunLocalTests -o agent-probe --async --json`, then `sf project deploy resume --job-id <validation> --wait 4 --json` | Succeeded, 1 component, 154 tests, 0 failures |
| 5 | Quick deploy rev 1 | `CONFIRM_PROD=1 sf project deploy quick --job-id <validation> -o agent-probe --wait 4 --json`, under the standing approval in the burn plan's Approvals table | Succeeded |
| 6 | Runs 1a, 1b | the measurement script | table above |
| 7 | Validate and quick deploy rev 2 | as steps 4 and 5 | Succeeded, 154 tests, 0 failures; Succeeded |
| 8 | Run 2a | the measurement script | table above |
| 9 | Validate and quick deploy rev 3 | as steps 4 and 5 | Succeeded, 154 tests, 0 failures; Succeeded |
| 10 | Runs 3a, 3b, 3c | the measurement script | table above |
| 11 | e2e | `SF_TARGET_ORG=agent-probe npm run test:e2e` | 8 passed (2.8 m) |
| 12 | Version table | read-only `SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status FROM BotVersion` | v1 Inactive, v2 Active |
| 13 | Agent spec | `sf agent test run --api-name Account_Brief_Test --test-runner testing-center --result-format json -o agent-probe --json`, then `sf agent test resume --job-id <run> --wait 4 --result-format json --json` | COMPLETED, 15 of 16 replies |
| 14 | Recapture | the capture command above | passed; later reverted |
| 15 | Rollback | `git checkout` of the resource, the test and the two assets; validate and quick deploy as steps 4 and 5 | Succeeded, 154 tests, 0 failures; Succeeded |
| 16 | Org check | the retrieve of step 1, then `cmp` with `main` | byte-identical: the org runs BE-17's prompt again |

Nothing was published or activated, no sign-in or sign-out was made, and only the static resource
was deployed. Three prompt revisions reached the org, the most the card allows, plus the rollback.

Org model use was well over the card's budget of about 40 calls:

| Source | Model calls |
|---|---|
| Explorer questions, measurement and recapture | about 57 to 61 |
| e2e run | not counted (its briefs and questions) |
| Spec cases | 16, each also graded |

An explorer question is one call per query plus one for the answer: 2 for L, C and S, and 3 for F
on revision 3. Run 1a's F answer was never read, so its call count is unknown (at most 5).

## Left open after attempt 1

Each point is settled in attempt 2 below.


- **S names the account.** A fourth revision would need to say so more forcefully, perhaps with a
  single-record example, or the bar could accept the account as part of the record's description.
  The card allows three revisions, so none was tried.
- **Ship revision 3 or not.** Its L, C and F answers met the bar. The rollback was triggered by spec
  case 2, a brief case the explore prompt cannot reach. A second spec run would show whether case 2
  is noise.
- **Follow-ups.** The follow-up rule works around history that carries only question and answer
  text. Passing the earlier result's Ids in the history (`DataExplorer`, the panel) would make it
  structural, outside this card's scope. The rule also puts an Id column in F's table, which the
  capture guard masks but a live user would see.
- **Header label.** The recaptured still shows a dotted header, "Account.Name", in the result table,
  although rule 10 and the plain-label tests expect plain labels. It is panel or Apex work.

## Attempt 2: revision 3 shipped

The coordinator settled the four open points:

- Spec case 2 is not a regression from this card, because only `DataExplorer` loads the explore
  prompt. The new spec rule: the explore cases (9, 10, 11, 13, 14) pass replies and actions, and
  actions pass 16 of 16. A non-explore reply failure is a hand-back only if the same case fails two
  runs in a row.
- S may name the opportunity's account. It still names exactly one opportunity, mentions no owner
  and has at most two sentences.
- The Id column must never be displayed. The card's scope gained `DataExplorer.cls` and
  `DataExplorerTest.cls` for this.
- Ship revision 3's resource and the two classes to agent-probe.

### The DataExplorer change

`explore()` and `drill()` now return each result set through `forDisplay`:

- **No Id columns.** Columns that hold a record Id are dropped: `Id`, any field whose name ends in
  `Id`, or a catalog field of kind id. Rows keep their record Id under `Id`, so a row still drills.
- **Plain labels.** Every other column is named by the plain label `ExploreCatalog` already gives it
  (Account, not Account.Name; Stage, not StageName). The panel's table uses column names as its
  headers. The panel code itself is out of scope, so the fix sits in Apex. Rows gain each label as
  a key and keep their old keys, so the panel's name lookup still finds `Name`.
- **The model still sees the Ids.** Its result preview keeps every column, so revision 3's follow-up
  clause still works: rerun the earlier query with Id, then query those Ids.
- **The trail hides Ids.** F's follow-up filters on the five earlier Ids, and the trail line would
  have listed them. The trail now reads "Id IN (5 records)", and any other Id reads "a record".

Tests, in `DataExplorerTest`:

| Test | What it checks |
|---|---|
| `exploreNeverShowsAnIdColumnAndItsRowsStillDrill` | Covers both the explore table and the drill view. |
| `relationshipColumnsShowPlainLabelsWithTheirValues` | Relationship columns show plain labels with their values. |
| `aFollowUpQueriesTheEarlierIdsWithoutShowingThem` | Also checks the trail line. |
| `countsAndHandBuiltSetsKeepTheirOtherColumns` | `COUNT(Id)` is kept. |
| `theTrailHidesRecordIdsOnly` | Only record Ids are hidden in the trail. |
| `drillByRecord` | Now expects `Owner`, not `Owner.Name`. |

`tests/test_explore_prompt.py` asserts revision 3's rule 9 again.

Red: before the class changed, the new tests ran against the org's DataExplorer in a validation
that deployed nothing. Four failed, showing `Id`, `AccountId` and `OwnerId` displayed and
`Account.Name` and `Owner.Name` dotted.

### Deploy steps, in order

| # | Step | Outcome |
|---|---|---|
| 17 | Red: validate `DataExplorerTest` alone with RunSpecifiedTests | 4 failures, nothing deployed |
| 18 | Validate the resource (revision 3) and the two classes with RunLocalTests, then quick deploy with CONFIRM_PROD=1 under the standing approval | Succeeded, 3 components, 158 tests, 0 failures; Succeeded |
| 19 | Run a2r1 | All four shapes met the bar. F's trail still listed the five Ids, masked as "Id hidden" by the capture guard |
| 20 | Validate and quick deploy the same three components with the trail change | Succeeded, 3 components, 159 tests, 0 failures; Succeeded. This is the final org state |
| 21 | Runs a2r2, a2r3, a2r4 | Table below |
| 22 | e2e, 15:27:59Z to 15:30:56Z | 8 passed (2.9 m) |
| 23 | Agent spec, 15:31:04Z to 15:33:37Z, after e2e | 16 of 16 replies, 16 of 16 actions |
| 24 | Recapture, after the spec | Passed with its privacy checks |

Nothing was published or activated, and no sign-in or sign-out was made.

### Answers on the final org state

| Run | Shape | S. | Opportunities named | Owner | Answer, word for word |
|---|---|---|---|---|---|
| a2r2 | L | 2 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920. The biggest is Juniper Project B at $293,920. |
| a2r2 | C | 1 | 0 | no | There are 36 open opportunities. |
| a2r2 | S | 1 | 1 | no | The largest open opportunity is Juniper Project B for $293,920, closing January 14, 2027. |
| a2r2 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |
| a2r3 | L | 2 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920. The biggest is Juniper Project B at $293,920. |
| a2r3 | C | 1 | 0 | no | There are 36 open opportunities. |
| a2r3 | S | 1 | 1 | no | The largest open opportunity is Juniper Project B at $293,920 in the Needs Analysis stage. |
| a2r3 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |
| a2r4 | L | 1 | 1 | no | The 5 largest open opportunities range from $255,040 to $293,920, with Juniper Project B at the top at $293,920. |
| a2r4 | C | 1 | 0 | no | There are 36 open opportunities. |
| a2r4 | S | 1 | 1 | no | The largest open opportunity is Juniper Project B at $293,920.00, closing January 14, 2027. |
| a2r4 | F | 2 | 1 | no | Of those 5 deals, 2 close in 2027. The largest is Juniper Project B at $293,920. |

All 12 answers meet the bar.

- Every C answer states 36 in its first sentence.
- None of the S answers named the account this time; the bar now allows it.
- Each F answer ran two queries: the L query again (5 of 36 rows), then those five Ids with the
  2027 condition. It returned 2 rows, Juniper Project B and Fernhollow Project C, both in L's five.
- No table had an Id column. Headers read, for example, Name, Amount, Account, Stage, Close Date.
- L fit: 158 px of 273 px in all three runs.

Run a2r1, on the state before the trail change, gave the same results. Its L answer was "The 5
largest open opportunities range from $255,040 to $293,920. The biggest is Juniper Project B at
$293,920." (2 sentences, 158 px). Its S answer was "The largest open opportunity is Juniper
Project B at $293,920, in the Needs Analysis stage and closing January 14, 2027."

### No regression

- **e2e:** 8 passed (2.9 m), with no rerun.
- **Agent spec:** one run, after e2e. It passed 16 of 16 on replies and 16 of 16 on actions. Topic
  was 15 of 16; the miss is case 12's expected false FAILURE.
  - All explore cases (9, 10, 11, 13, 14) passed. Ratings were 5, except case 14 at 3.
  - Case 2 passed with a rating of 4, and case 6 was also 4. No second run was needed.
  - The explore replies carried no Id-like strings, and their tables had plain headers, such as
    "Name | Amount | Account | Close Date | Stage".

### Recapture

- **explore-answer.png:** The question, then the two-sentence answer "The 5 largest open
  opportunities total $1,372,400, led by Juniper Project B at $293,920. All five are in mid-to-late
  stages with close dates between November 2026 and January 2027." Below it, the caption
  "Opportunity · 5 of 36 rows", the Name, Amount and Stage headers, and the rows Juniper Project B
  and Fernhollow Project C. The total matches the five rows' amounts. The question to the header
  row needs 177 px of the 273 px box.
- **explore-drill.gif,** at 1 fps:
  - Frame 1: the answer with two rows.
  - Frame 2: the panel dimmed under a spinner.
  - Frames 3 to 5: the drill view of Juniper Project B.
  - Frames 6 to 8: back in the conversation, with the end of the answer and three rows (Juniper
    Project B, Fernhollow Project C, Pimble Project B).
- **drill-view.png:** The record's fields under plain labels: Name, Stage, Amount, Close Date and
  Probability (%). There is no Id field; in the old image, Id fields showed as "Id hidden".

MANIFEST.md and the pattern page's alt text match these images.

### Model calls in attempt 2

| Source | Model calls |
|---|---|
| Four measurement runs, 9 each | 36 |
| Recapture | 2 |
| e2e run | not counted |
| Spec cases | 16, each also graded |

The red validation and the deploys made no model calls. The total is over the coordinator's
"about 45" by roughly the e2e run's share.

### Still open

- The follow-up still depends on the model rerunning the earlier query. A structural fix would pass
  the earlier result's Ids in the history (`DataExplorer` and the panel).
- A group-by on an id field now shows only its counts, because the id column is hidden. No catalog
  question in this run grouped by one.
