# FR2+ explorer catalog from describe, with a deny list (BE-42)

- Date: 2026-11-15. Org `agent-probe`. Validated with RunLocalTests (531 tests, 0 failures), then quick deployed. No record, user or setting was created; no agent was published or activated.
- Code: [ExploreCatalog.cls](../../force-app/main/default/classes/ExploreCatalog.cls), [DataExplorer.cls](../../force-app/main/default/classes/DataExplorer.cls), the deny list type [Explore_Deny_Rule__mdt](../../force-app/main/default/objects/Explore_Deny_Rule__mdt/Explore_Deny_Rule__mdt.object-meta.xml) and its default records in [customMetadata](../../force-app/main/default/customMetadata/). Tests: [ExploreCatalogTest.cls](../../force-app/main/default/classes/ExploreCatalogTest.cls), [DataExplorerTest.cls](../../force-app/main/default/classes/DataExplorerTest.cls).
- Measurement: BE-31's 30 [questions](../../spikes/explorer-scale/questions.json) and harness, run once on the deployed explorer. Results: [be42.jsonl](../../spikes/explorer-scale/results/be42.jsonl), one JSON line per question in BE-31's record format (counts, statuses and limits only). Baseline: [fr2-explorer-baseline.md](fr2-explorer-baseline.md) (BE-41). Status words: verified (measured here), unverified (inference).

## Plain answer

- **The deployed explorer passed 22 of 30 in one run**, against BE-41's 20, 20 and 20 (verified). That is a gain of 2, inside the replay's spread of about 5, so it is not yet a proven gain. One run is not enough to call it.
- **q29 ("How many active products are there?") now passes.** `Product2` is outside the eight core objects. The first plan named it and got an INVALID line, and its fields arrived on the next turn: 3 model calls (verified). BE-41 failed it in all six runs.
- **q30 (customer summary sessions) is still refused.** The product's own object is on the deny list (verified).
- **The per-call catalog stayed at or under 6,000 characters on all 30 questions:**
  - live run, largest catalog per question: median 4,948, maximum 5,994 (84 model calls, verified);
  - first-call catalog for the 30 questions: median 4,948, maximum 5,994;
  - the same 30 after describing `Product2`, `Lead` and `Campaign` on demand: median 5,473, maximum 5,940.
- **Cost:**
  - Model calls: median 2.5 per question, against the replay's 3. The deployed engine's calls are counted exactly now, through `DataExplorer.lastRun`.
  - Input tokens: median about 7,300. This is an estimate: the prompt file plus every variable sent, divided by 4. It is not a Models API count, and BE-41's replay measured a median of 10,622.
  - CPU and heap rose: median CPU 725 ms against 262, and median heap 239 KB against 38 (verified). Limits are still far off: the worst CPU was 1,385 ms of 10,000, and the worst heap was 262 KB of 6 MB.

## Next to BE-41's baseline

| | BE-41 real (3 runs) | BE-41 replay (3 runs) | BE-42 real (1 run) |
|---|---|---|---|
| pass count | 20, 20, 20 | 17, 21, 22 | 22 |
| model calls, median per question | not visible | 3 | 2.5 (exact) |
| model calls, total | not visible | 271 over 90 | 84 over 30 |
| input tokens, median per question | not visible | 10,622 (measured) | about 7,305 (estimate) |
| input tokens, worst question | not visible | 24,519 | about 19,700 (estimate) |
| CPU ms, median / worst | 262 / 373 | 238 / 370 | 725 / 1,385 |
| heap KB, median / worst | 38 / 63 | 46 / 78 | 239 / 262 |
| per-call catalog chars | 3,436 (fixed) | 3,436 (fixed) | median 4,948, max 5,994 |

Changed against BE-41 run 1:
- Four failures became passes: q09, q11, q16 and q29.
- Two passes became failures: q18 and q20. q20 already changed between BE-41's runs. q18 passed in all six BE-41 runs; it is a count of accounts in two industries, and its verdict was a wrong number. Why it failed is not established (unverified). The catalog now shows at most 6 picklist values per field (3 or none when the text would pass the size cap), with the ones the question names first; BE-41's catalog showed 12.

Per question:
- BE-41: real runs 1 to 3.
- BE-42: one run.
- Calls and tokens: BE-42, with the BE-41 replay median in brackets.
- Catalog: the first call's characters and the largest call's characters.

| q | group | BE-41 real | BE-42 | calls (replay) | input tokens, estimate (replay) | CPU ms | heap KB | catalog first / max |
|---|---|---|---|---|---|---|---|---|
| q01 | single | PPP | P | 2 (2) | 5,313 (6,801) | 599 | 231 | 4,043 / 4,043 |
| q02 | single | PPP | P | 2 (2) | 5,147 (6,816) | 628 | 230 | 3,692 / 3,692 |
| q03 | single | PPP | P | 2 (2) | 5,487 (6,939) | 630 | 233 | 4,095 / 4,095 |
| q04 | single | PPP | P | 2 (2) | 5,522 (7,037) | 552 | 235 | 4,139 / 4,139 |
| q05 | single | PPP | P | 2 (2) | 5,471 (6,982) | 549 | 234 | 4,086 / 4,086 |
| q06 | parent | PPP | P | 2 (4) | 6,305 (13,911) | 715 | 243 | 5,994 / 5,994 |
| q07 | parent | PPP | P | 2 (4) | 6,225 (14,262) | 708 | 241 | 5,511 / 5,511 |
| q08 | parent | PPP | P | 2 (4) | 6,258 (14,308) | 694 | 241 | 5,893 / 5,893 |
| q09 | parent2 | FFP | P | 4 (5) | 12,719 (17,760) | 1385 | 250 | 4,971 / 4,971 |
| q10 | parent2 | PPP | P | 4 (5) | 12,478 (19,088) | 1363 | 247 | 5,012 / 5,012 |
| q11 | child | FFF | P | 4 (3) | 14,027 (11,251) | 1057 | 244 | 5,893 / 5,893 |
| q12 | child | PPP | P | 4 (4) | 14,507 (19,232) | 737 | 262 | 4,925 / 4,925 |
| q13 | child | PPP | P | 2 (2) | 5,863 (6,892) | 545 | 235 | 4,925 / 4,925 |
| q14 | child | PPP | P | 2 (3) | 5,945 (10,467) | 735 | 239 | 5,169 / 5,169 |
| q15 | child | FFF | F | 2 (2) | 6,462 (7,226) | 679 | 243 | 5,893 / 5,893 |
| q16 | or | FPP | P | 4 (2) | 10,989 (6,818) | 781 | 233 | 4,004 / 4,004 |
| q17 | or | FFF | F | 5 (5) | 19,747 (24,181) | 987 | 254 | 4,139 / 4,139 |
| q18 | or | PPP | F | 2 (2) | 6,040 (6,842) | 758 | 239 | 5,314 / 5,314 |
| q19 | or | PFF | P | 4 (4) | 11,114 (14,923) | 829 | 235 | 3,541 / 3,541 |
| q20 | or | PPF | F | 5 (4) | 14,349 (16,180) | 1170 | 247 | 4,183 / 4,183 |
| q21 | semi | PPP | P | 2 (2) | 5,906 (6,853) | 586 | 238 | 5,169 / 5,169 |
| q22 | semi | PPP | P | 3 (3) | 10,602 (12,251) | 855 | 247 | 5,961 / 5,961 |
| q23 | semi | PPP | P | 3 (3) | 9,471 (10,710) | 785 | 244 | 5,647 / 5,647 |
| q24 | semi | FFF | F | 3 (3) | 9,312 (10,639) | 842 | 242 | 5,387 / 5,387 |
| q25 | longtext | FFF | F | 1 (2) | 3,023 (6,818) | 591 | 239 | 5,595 / 5,595 |
| q26 | longtext | FFF | F | 3 (2) | 8,677 (6,832) | 620 | 237 | 4,375 / 4,375 |
| q27 | chain | FFF | F | 3 (4) | 8,502 (14,527) | 741 | 234 | 4,086 / 4,086 |
| q28 | chain | PPP | P | 3 (4) | 9,019 (13,943) | 808 | 240 | 5,152 / 5,152 |
| q29 | anyobject | FFF | P | 3 (1) | 8,147 (3,366) | 578 | 236 | 3,876 / 4,203 |
| q30 | deny | PPP | P | 2 (3) | 5,369 (10,288) | 587 | 232 | 3,950 / 4,163 |

## What the catalog does now

- **Built from describe for the running user.** Any object the user can read and query may be explored, unless the deny list says no. The eight curated objects remain the core: they are always described, and their listed fields are the curated paths. Every other allowed object is described on demand, the first time a plan names it.
- **Deny list** (`Explore_Deny_Rule__mdt`, 58 default rows):
  - The product's own objects. Any later custom object is denied too, until an Allow Object row names it.
  - Setup and audit objects: SetupAuditTrail, LoginHistory, AuthSession, PermissionSet and its assignment, group and licence objects, Profile, ApexClass and the other Apex objects, StaticResource, Organization, Group and others.
  - The suffixes __Share, Share, History, Feed, ChangeEvent, __mdt, __e, __x, __b, __kav and __chn.
  - Fields that are encrypted, base64, or an address or location compound.
  - Fields whose name or label is secret-like: password, secret, token, SSN or social security, tax ID, card number, bank account, IBAN or routing number.
  - `User` shows only Id, Name and Title, the curated limit from before.
- **Rule order.** A deny always beats an allow.
- **Fails closed.** An empty or unreadable list allows no object, and so does a pattern that does not compile.
- **User mode stays.** Every query still runs in user mode. The deny list removes access; it never grants any.
- **No denied name reaches SOQL.** `ExplorePlan` resolves every object and field through the catalog before `ExploreQuery` builds a query. A denied name is refused wherever it appears:
  - at the top level (`Unknown object`);
  - in a parent path (`Owner.Email`; `Account.Name` when Account is denied);
  - in a semi-join position. The grammar has no sub-select: a nested plan as a filter value is refused, and SOQL text in a value is bound as a value.
- **Pruned per call.** `describeForPrompt(question)` lists, for each described object:
  - Id, the name field, picklists, dates, amounts, flags and lookups;
  - every field the question mentions, matched on name or label, including a core parent's field through a lookup (Contact's `Account.Industry`).
- **Other objects, name and label only.** After the described objects comes one line of other allowed objects. It holds those the question names, then a short common list, 16 at most. All 1,099 allowed objects do not fit: their names alone take 49,284 characters (BE-31).
- **On-demand describe.** A plan that names an allowed object not yet described gets `INVALID: <Object> was not in the catalog yet. Its fields are listed there now; plan again with them.` That costs a turn, not a query, and the next turn's catalog lists the object's fields.
- **Size guard.** If the text goes over 6,000 characters, it shrinks in this order until it fits:
  1. fewer picklist values;
  2. a shorter index;
  3. only the name and mentioned fields;
  4. whole lines dropped from the end.
- **Drill.** `DataExplorer.drill` opens a record of any allowed object. Related rows still come from the core objects only, as before.

## Prompt file

`AgentPrompt_Explore` was not changed. Its readers:
- `DataExplorer`, through `AgentLlm` and the `Explore` prompt setting;
- the BE-31 spike engines `engine-current.apex` and `engine-v2.apex`;
- `tests/test_explore_prompt.py` and `tests/test_pattern_02.py`.

Its rule 1 ("use only names that appear in the catalog") still holds, because the index lists the other objects by name. No new resource was needed.

## Limits and open items

- **One run only.** A gain of 2 is inside the noise. Three more runs would settle it.
- **CPU about 2.8 times BE-41's.** Most of it goes on rendering the catalog for each call (the index pass over about 1,000 allowed objects is cached for the transaction) and on describing every field of the eight core objects. There is room to cache the rendered text per turn.
- **Input tokens are an estimate.** `AgentLlmModelsApi` does not return usage, so the real engine's tokens cannot be counted.
- **Still failing:**
  - the long-text questions q25 and q26;
  - the OR and HAVING shapes: q15, q17 and q20;
  - q24 (anti-join) and q27.

  None of these is a catalog problem.

## Undo

- Org: deploy the previous `ExploreCatalog` and `DataExplorer` from main with validate and quick deploy. The `Explore_Deny_Rule__mdt` type and records can stay, since nothing else reads them; removing them needs a destructive deploy, which is a separate decision.
- Repo: revert the BE-42 commit.

## q18 fix (BE-57)

- **Cause (found in BE-43).** Describe kept only the first 12 active picklist values of each field, before the values the question names were ranked first. Account.Industry has 32, so 'Technology' never reached the prompt, and q18 counted 3 accounts, not 4.
- **Change.** Describe keeps every active picklist value, capped at 500 per field to bound heap. The 6, 3 and 0 values-shown levels and the 6,000-character cap are unchanged. A named value still goes first, so it is shown whenever any value of its field is shown.
- **Matching.** A picklist value is named by the old word rule (any question word of four letters or more, or its singular, inside the value) or by the whole-value match below. Field matching by name or label is unchanged.
- **Test.** `ExploreCatalogTest.aNamedPicklistValuePastTheFirstTwelveIsShown` takes the last active Account.Industry value in describe order, asks 'Industry <value>', and asserts that the value is in the Account line's Industry values. It fails on main, where the value is past the first 12, and passes after. The question is short on purpose: longer questions pull in extra fields, push the prompt over the cap, and drop every picklist value at the 0 level.
- **Live run.** q18 alone through the harness, `current` engine, agent-probe: PASS, count 4, 2 model calls, 19,488 prompt characters. Recorded in `spikes/explorer-scale/results/be57-q18.jsonl`. This run does not exercise the fix: the `current` engine replays BE-31's loop with the first explore prompt and `describeForPrompt()` with no question, so no value is ranked first as named. It shows q18 can pass; it is not evidence that the named value now reaches the deployed explorer's prompt. That evidence is the Apex test above, and BE-45's rerun of all 30 questions on the deployed explorer (DataExplorer, `describeForPrompt(question)`, the v2 prompt).
- **Matching changed.** The whole-value match is added to the old word rule, so nothing the old rule named is lost. A value is named when the question holds the whole value as whole words, case-insensitively ('Technology' in 'the Technology industries'). Before, 'closed deals' named 'Closed Won' and 'Closed Lost', and 'technologies' named 'Technology'; both still do.
- **Still open.** A longer question can push the catalog to the 0-values level, where no picklist value is shown, named or not (the worker hit this writing the test). Keeping named values at that level is not part of this card.
- **Undo.** Redeploy `ExploreCatalog` from the previous main commit (c5c4643), with validate and quick deploy.
