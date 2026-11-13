# FR2 explorer discovery: reaching any object and any combination safely (BE-31)

- Date: 2026-11-13. Org `agent-probe`, run as the org's own admin through anonymous Apex. Nothing was
  deployed, published or activated, and no record was created, changed or deleted.
- Code: [spikes/explorer-scale](../../spikes/explorer-scale/). The prototype is
  [prototype.apex](../../spikes/explorer-scale/prototype.apex): a describe-driven catalog with a deny
  list and a wider plan grammar. [run.py](../../spikes/explorer-scale/run.py) runs one question per
  anonymous Apex transaction. Nothing in `force-app` changed.
- Status words: verified (measured in the org), documented (a published page says so),
  unverified (inference).
- Read with [fr2-design.md](../plans/fr2-design.md) and
  [02-ask-anything-explorer.md](../patterns/02-ask-anything-explorer.md) and [07-trust-access-and-failure.md](../patterns/07-trust-access-and-failure.md).

## Plain answer

- **Yes, the explorer can reach any object the user can read, and the combinations the card names.**
  The checks stay the same: every name in a plan is checked against describe, every value is a bind
  variable, and every query runs in user mode.
  - The prototype answered 27 of 30 questions. The current explorer answered 23 of 30 in a metered
    replay and 20 of 30 in a run through the deployed `DataExplorer.explore` (verified, one run each).
  - Run-to-run noise is real. The replay and the deployed run share the prompt, planner and query code,
    yet they disagreed on 5 of 30 questions: model noise, or a difference between the replayed loop and
    the deployed one (not separated here). Only two of the gains are structural:
    - Long-text search went from 0 of 2 to 2 of 2.
    - Objects outside the curated eight went from 0 of 1 to 1 of 1.
    The current grammar cannot express either one at all. The other gains are within the noise.
- **Recommendation: build it, in four cards** ([Proposed build cards](#proposed-build-cards)).
  - Catalog: describe-driven with an admin deny list in custom metadata, not a hand-curated list.
  - Grammar: nested `where` groups, two-lookup paths, semi- and anti-joins (`sub`), `CONTAINS` on long
    text, `children`, `having`, and step references for chained questions.
- **The cost is prompt size, not governor limits.**
  - The describe-driven catalog of 8 to 14 objects is 22k to 29k characters. The current catalog is
    3.4k characters.
  - Median input tokens per question went from 10.1k to 21.6k, even though the model made fewer calls
    (median 2, against 3).
  - CPU (median 665 ms) and heap (median 350 KB) are 7% and 6% of the synchronous limits (verified).
  - Field pruning is the first thing the build should do ([Limits](#limits)).
- **A user must never reach:**
  - the product's own records (`Customer_Summary_Session__c`, `Account_Brief_Session__c`)
  - setup and audit objects
  - history, share, feed and change-event families
  - encrypted, base64 and secret-named fields
  The deny list does that, and user mode still applies under it. Question q30 and checks 1 to 3 and 9
  show it holding (verified).

## What was built and run

- **Three engines** answered the same 30 questions
  ([questions.json](../../spikes/explorer-scale/questions.json)), one anonymous Apex transaction each:
  - `real`: the deployed `DataExplorer.explore`. Model calls and tokens are not visible from outside it.
  - `current`: a line-for-line replay of the `DataExplorer.run` loop, with the same prompt file,
    `ExplorePlan`, `ExploreQuery`, caps (5 turns, 4 queries) and feedback lines, and with each Models
    API call metered.
  - `v2`: the same loop and caps, with the prototype's catalog and planner. It reuses the deployed
    prompt and swaps only the PLAN section and rules 1 and 2
    ([engine-v2.apex](../../spikes/explorer-scale/engine-v2.apex)).
- **Grading** ([harness.apex](../../spikes/explorer-scale/harness.apex)):
  - Each question has an independent reference: raw SOQL in user mode, written by hand and never by an
    engine.
  - A set question passes only when the last table's record Ids equal the reference set. A table with
    extra rows is `FAIL:superset`.
  - A count or sum passes when the number is in the answer or in a cell.
  - Grouped results must match every group.
  - The deny question passes when the denied object was never queried.
  - An empty result counts as correct only when the reference is 0.
  - One question was replaced before the final runs. q06 had asked about an industry with no contacts,
    so an empty answer was the right one. It now uses an industry with five contacts.
- **No-model checks** ([rejections.apex](../../spikes/explorer-scale/rejections.apex),
  [output](../../spikes/explorer-scale/results/rejections.txt)) hand the planner 44 plans:
  - 31 malformed or forbidden plans, one or more for every new plan position.
  - 13 valid ones, including the five shapes that [red-1](#red-evidence) shows the deployed
    `ExplorePlan` rejecting.
  - 44 of 44 behaved as expected (verified). The first pass found three planner bugs: `NOT` needed
    parentheses, a `HAVING COUNT` bind must be an Integer, and the long-text column must be selected.
    All three were fixed before the 30-question runs.
- **Probes:**
  - [inventory.apex](../../spikes/explorer-scale/inventory.apex): describe sizes.
  - [soql-rules.apex](../../spikes/explorer-scale/soql-rules.apex): which SOQL shapes the platform
    accepts.
  - [catalog-scale.apex](../../spikes/explorer-scale/catalog-scale.apex),
    [output](../../spikes/explorer-scale/results/catalog-scale.txt): catalog growth.
- **Results:** [results/](../../spikes/explorer-scale/results/) holds one JSON line per question per
  engine, with counts, statuses and limits only. No names, no Ids and no answer text are recorded.

### Red evidence

Before the prototype existed, these five plan shapes were given to the deployed `ExplorePlan.validate`.
All five were rejected, and the catalog was fixed at 8 objects and 3,436 characters (saved outside the
repo as the card's red file):

| Shape | Deployed result |
|---|---|
| OR group in a `where` key | `Unknown plan key` |
| `Account.Owner.Name` (two lookups) | `Unknown field` |
| `Description LIKE` (long text) | long-text error |
| semi-join value | `IN needs a non-empty list` |
| object `Lead` | `Unknown object` |

All five build and run in the prototype: rejection checks 31 to 35 (verified).

## Results by group

| Group (questions) | real | current | v2 |
|---|---|---|---|
| single object (5) | 5 | 5 | 5 |
| one parent lookup (3) | 3 | 3 | 3 |
| two lookups (2) | 2 | 1 | 2 |
| children, anti-join, HAVING (5) | 3 | 4 | 5 |
| OR and grouped filters (5) | 2 | 4 | 4 |
| semi-joins (4) | 3 | 3 | 3 |
| long text (2) | 0 | 0 | 2 |
| chained steps (2) | 1 | 2 | 1 |
| object outside the curated 8 (1) | 0 | 0 | 1 |
| denied object (1) | 1 | 1 | 1 |
| **all (30)** | **20** | **23** | **27** |

| Per question, median (max) | real | current | v2 |
|---|---|---|---|
| model calls | not visible | 3 (5) | 2 (3) |
| input tokens | not visible | 10,078 (19,351) | 21,604 (35,915) |
| output tokens | not visible | 234 (811) | 194 (576) |
| INVALID turns, total over 30 | not visible | 9 | 3 |
| plans run | 2 (4) | 2 (4) | 1 (2) |
| SOQL statements | 4 (6) | 4 (7) | 3 (5) |
| query rows | 8 (98) | 10 (98) | 8 (44) |
| CPU ms | 267 (403) | 268 (370) | 665 (761) |
| heap bytes | 33k (51k) | 45k (73k) | 350k (362k) |
| wall ms (model time is most of it) | 7,352 (15,656) | 8,700 (19,060) | 7,793 (12,798) |

What the failures show (verified from the run records; why the model chose as it did is unverified):

- **Current and real, structural:**
  - q25 and q26 (long text): the plan cannot filter `Description`, so the model gave up.
  - q29 (`Product2`): the object is not in the catalog.
- **Current and real, workarounds that leave the wrong last table:**
  - q11 (accounts with no opportunities): the engine queried accounts, then opportunities, and the last
    table was the opportunities.
  - q17 and q24 have the same problem.
  - The current grammar does semi-joins by carrying Ids from one query to the next. That works
    (q21 to q23 passed), but it costs a turn per step, and the answer then rests on the last step's
    table.
- **v2:**
  - q19 returned extra tasks for "not started or due in the next 7 days".
  - q24 and q27 returned the wrong sets.
  - These questions turn on how a date window is read: overdue counted as due, "before the end of this
    year", "in the last 30 days" against `ActivityDate`. They may be reference-definition disagreements
    as much as engine errors (unverified, n=1).
- **v2 used the new shapes the questions called for:**
  - 9 semi-joins and 2 anti-joins
  - 5 OR groups
  - 7 two-lookup paths
  - 2 HAVING clauses
  - 2 step references
  - 2 long-text searches

## Catalog

**Curated or describe-driven: describe-driven, with a deny list.** The curated list cannot answer q29 or any
custom object, and an admin cannot extend it without a deploy. Describe already reports what the running
user can read, so the catalog follows profiles and permission sets for free.

What the org has (verified):

- Global describe: about 1,750 to 1,900 entries. The two probes counted 1,752 and 1,916; the gap is
  unexplained.
- 1,099 objects are allowed by the prototype (accessible, queryable and not denied) for the admin.
- Fields: 21,410 on the first 1,107 objects described. Of those, 41 are custom, 436 are long text and 950
  cannot be filtered. None are encrypted, and 92 have sensitive-sounding names.
- Two custom objects, both the product's own session records.

**What a user must never reach** (the prototype's deny list, kept as custom metadata in a build):

| Rule | Why |
|---|---|
| Objects `Customer_Summary_Session__c`, `Account_Brief_Session__c` and any later product object | product state, not CRM data |
| Setup and audit objects (`SetupAuditTrail`, `LoginHistory`, `AuthSession`, `PermissionSet`, `Profile`, `ApexClass`, `StaticResource`) | not sales questions; security-relevant. A typo left `SetupAuditTrail` allowed during the 30-question runs (no question touched it); fixed, and check 44 now rejects it |
| Suffixes `__Share`, `History`, `Feed`, `ChangeEvent`, `__mdt`, `__e`, `__x`, `__b`, `__kav`, `__chn` | sharing internals, event and external objects, platform metadata |
| Fields that are encrypted, base64, address or location compounds, or named like password, secret, token, SSN, tax id, card or bank account | never shown in chat, even when readable (unverified: no check covers these field rules) |

- **The deny list is extra, never instead.** User mode still applies to every query, so an object the
  deny list misses is still bounded by the user's own access. The list exists for data the user can read
  but the assistant should not show.
- **Checks:**
  - Checks 1 to 3 reject a session object, a brief object and `AccountHistory` at the top level.
  - Check 9 rejects a session object inside `sub`.
  - q30 asked for session counts. The engine never queried the object, and the model said it could not
    reach it (verified).

**Keeping the prompt small (relevance pruning).** The prototype sends:

- a core set of 8 sales objects;
- plus up to 6 allowed objects whose API name contains a word of the question (5 letters or more), with
  the shortest names first;
- each with its full field list, its lookups (`Owner->User`) and its child lists to other objects in the
  prompt.

Object pruning alone is not enough. Catalog lines from [catalog-scale.txt](../../spikes/explorer-scale/results/catalog-scale.txt)
(verified):

| Objects described | Characters | About tokens | CPU ms |
|---|---|---|---|
| the 8 core objects, as sent per question (child lists only to prompt objects) | 22,421 | 5,600 | (part of the 665 ms median) |
| 8, with child lists to every allowed object | 35,373 | 8,800 | 479 |
| 50 | 73,851 | 18,500 | 1,228 |
| 200 | 181,556 | 45,400 | 2,046 |
| all 1,099 | 947,951 | 237,000 | 8,223 |
| names-only index of all 1,099 (name and label) | 49,284 | 12,300 | 165 |

- Describing everything is out: 237k tokens is beyond any sensible prompt, and the CPU alone is 82% of
  the limit.
- A names-only index of every object fits at about 12k tokens, but that is still more than the whole
  current prompt.
- **The build should:**
  - prune fields as well as objects: name, the fields the question mentions, picklists, dates, amounts
    and lookups, and nothing else;
  - send other objects as name and label only, and describe an object in full only when a plan names it.
    The model sees an INVALID line, asks for the object, and gets its fields on the next turn. That costs
    a turn only when it is needed.
- The prototype did not try this second step (unverified).

## Combinations

What the platform accepts, measured in agent-probe with
[soql-rules.apex](../../spikes/explorer-scale/soql-rules.apex) (verified):

| Shape | Platform |
|---|---|
| semi-join, two semi-joins, anti-join, on `Id` or a lookup (`AccountId IN (...)`) | works |
| semi-join AND (plain OR plain) | works |
| a third semi-join | "Maximum 2 semi join sub-selects are allowed" |
| semi-join inside OR, or under NOT | "only allowed at the top level WHERE expressions"; "'NOT' operator cannot be combined" |
| nested semi-join | "Nesting of semi join sub-selects is not supported" |
| `Task` or `Event` as the inner select | "Entity 'Task' is not supported for semi join inner selects" |
| inner and outer on the same object | "should not be on the same object type" |
| a parent path on the left (`Account.Id IN (...)`) | "cannot have more than one level of relationships" |
| parent paths 2, 3, 5 and 6 levels deep, and filtering on a 2-level path | works |
| child subqueries, two-level child subqueries, binds inside them | works |
| an aggregate inside a child subquery | "only root queries support aggregate expressions" |
| long text in WHERE | "field 'Description' can not be filtered in a query call" |
| ORDER BY long text | `System.UnexpectedException`, which Apex cannot catch: the transaction ends |
| SOSL in user mode | ran, but found nothing even for a word in a case subject (index not built or not searchable here) |

How the prototype builds each one. Every name comes from describe, and every value is bound:

- **OR and grouped filters:** `"where"` takes a condition or `{"and":[...]}`, `{"or":[...]}` or
  `{"not":...}`. Groups go at most 4 deep, with at most 20 conditions. `NOT` is written `(NOT (...))`, the
  only form SOQL accepts inside an AND.
- **Two-level parent paths:** `Opportunity.Account.Owner.Name` is resolved one hop at a time. Each lookup
  must be readable and point to an allowed object, and polymorphic lookups try each target. The platform
  allows 5 levels, and the cap of 2 is a choice: deeper paths were rarely needed in the questions, and
  every level widens what the model must know.
- **Long text:** `CONTAINS` on a field describe marks unfilterable is applied in Apex after the query. It
  scans at most 2,000 rows and refuses past that, and it must sit at the top level of `where`. On ordinary
  text, `CONTAINS` becomes `LIKE %v%`, with `%` and `_` escaped. Sorting and grouping by long text are
  refused, because sorting by it would end the transaction. SOSL would scale better, but it found nothing
  in this org, so it waits for its own proof.
- **Child subqueries:** `"children"` takes up to 2 child lists with up to 10 rows each. The table shows how
  many each record has.
- **Semi- and anti-joins:** `{"field":"Id","op":"IN"|"NOT IN","sub":{"object","field","where"}}`. The
  planner enforces the platform's rules before the query runs, so the model gets a plain INVALID line
  rather than a platform error:
  - top-level AND only, at most 2
  - not nested
  - not `Task` or `Event`
  - not the same object
  - the left side is `Id` or a lookup
  - the right side is a lookup
- **HAVING:** on one of the plan's own aggregates. A `COUNT` value binds as an Integer.
- **Chained steps:** `"value":{"step":1,"field":"AccountId"}` binds the Ids from an earlier query of the
  same question, at most 500 of them. This is the way through for `Task` and `Event`, which cannot be
  inner selects, and for "of those, which" questions.
- **Values:** check 41 passes `x' OR Name != '` as a value. It is bound, so it matches nothing and changes
  no SOQL text (verified).

## Limits

Per question, from the runs (verified):

- **SOQL:**
  - The prototype ran 3 to 5 statements out of 100: one for the prompt file, the plans, a COUNT() when a
    table fills its limit, and one more that the run did not attribute (probably the brand settings read
    for the prompt). The count is taken before grading, so the grader's queries are not in it.
  - The 4-plan cap keeps a question under about 12 statements in the worst case: each plan, a pre-count
    and a total.
- **Rows:** at most 98 in any run. The 10,000-row pre-count cap from `ExploreQuery` is kept. The long-text
  scan reads at most 2,001 rows.
- **CPU:**
  - The prototype's median is 665 ms of 10,000, against 268 ms for the current explorer.
  - The extra 400 ms is describe work for 8 to 14 objects.
  - It grows by about 5 to 18 ms per extra object described, and reaches 8.2 s for all 1,099. That is the
    reason to describe only on demand.
- **Heap:** 350 KB of 6 MB, against 45 KB. It is describe results, held for the transaction.
- **Callouts:**
  - Models API calls do not count in `Limits.getCallouts()` (verified earlier in this card).
  - Model time is most of the wall time: median 7.0 s for v2 and 8.1 s for the current explorer.
  - The 5-turn cap bounds it.
- **Model calls and tokens:**
  - v2 needed fewer calls: median 2 against 3, and 3 INVALID turns in all against 9.
  - But each call is 3 times larger, so input tokens per question doubled.
  - With field pruning the per-call size should fall back toward the current 3.4k-character catalog plus
    the few objects a question needs (unverified until the build measures it).

## Comparison with Data Cloud, standard actions and reports

These come from public pages that could not be opened in this run: developer.salesforce.com refused
automated fetches. Each line rests on the page's text as a search index shows it. Treat every figure as
unverified until someone opens the page. This is a list of differences, not a parity claim in either
direction.

- **Agentforce standard actions:** "Query Records" and "Query Records with Aggregate (Beta)", per Salesforce
  Help's Standard Agent Action Reference.
  - Documented: at most 50 results, a filter through at most one relationship, and no multi-object
    queries.
  - The aggregate action does count, sum, min, max and average, with no aggregates on related objects.
  - Employee agents run as the signed-in user.
  - OR, anti-joins, long-text search and chained steps are not mentioned (unverified).
  - The prototype goes further on each of these, but it is a spike, and the standard actions are
    supported product.
- **Data 360 (Data Cloud):**
  - Documented:
    - the Query API takes ANSI SQL, up to 49,999 rows per request;
    - CRM data arrives on a schedule (about every 10 minutes for incremental refresh), and data graphs
      refresh every 30 minutes or more unless they stream;
    - row-level access is set by its own policies, and the CRM connector ingests as an integration user
      with View All Data by default;
    - queries consume Flex Credits.
  - What the architecture pages imply: CRM sharing does not carry over on its own. So Data 360 suits
    analytics across sources, and suits less well "what can I, this rep, see right now"
    (unverified).
  - The explorer reads live CRM data in user mode at no extra credit cost.
- **Reports:**
  - Documented:
    - up to 3 cross filters (WITH or WITHOUT) with 5 subfilters each;
    - filter logic with AND and OR over up to 20 filters;
    - custom report types reach up to 4 related objects;
    - 2,000 rows in the UI and the Analytics REST API, and 500 synchronous API runs per hour;
    - long text filters see only the first 1,000 characters of standard fields and 255 of custom ones.
  - Reports are admin-built ahead of time. The explorer builds its query per question.
  - A report-backed path would keep report-type governance, but it would need a report for each shape of
    question.

## Recommendation

1. Move the catalog to describe plus a custom-metadata deny list, with field pruning and on-demand
   describe. This is the card that unlocks "any object" and keeps tokens near today's.
2. Widen the plan grammar to the prototype's (`where` groups, two-lookup paths, `sub`, `children`,
   `having`, `step`, `CONTAINS`), in `ExplorePlan` and `ExploreQuery`, with the platform's rules enforced
   in the planner.
3. Keep every current guard: user mode, binds only, the 4-query and 5-turn caps, the row cap and the
   pre-count. Add the long-text scan cap and the 500-Id step cap.
4. Re-run the 30 questions three times per engine after the build. n=1 cannot separate engines that differ
   by 4 questions.

## Risks

- **Noise:** with n=1, the replay and the deployed run disagreed on 5 of 30. The headline
  27 against 23 or 20 is suggestive, not proven. Only long text and the object outside the curated eight
  are structural wins.
- **Prompt cost:** describe-driven lines doubled input tokens. Without field pruning the bill doubles.
- **Deny list gaps:** a readable object the list misses is reachable, bounded only by user mode. The list
  should default to deny for new custom objects until an admin allows them (a choice for the build card).
- **Long-text post-filter:** it is exact for up to 2,000 scanned rows and refuses past that, so large orgs
  get a refusal, not a slow scan. SOSL is the scalable path, but it returned nothing here.
- **Platform crash shapes:** ORDER BY on long text throws an exception Apex cannot catch. Any new grammar
  position needs a describe guard like `isSortable`, or it can end the transaction.
- **Data shape:** this org has 14 accounts, one owner and data piled on one account. Selectivity, and the
  10,000-row cap on real volumes, are untested here.
- **Polymorphic lookups (`What`, `Who`, `Owner`):** paths resolve against the first target that has the
  field, which can surprise. The questions did not exercise them.

## Proposed build cards

- **"FR2+: describe-driven explorer catalog with an admin deny list"**
  - Scope: `force-app/main/default/classes/ExploreCatalog*.cls`, a new custom metadata type for the deny
    and allow rows, `docs/patterns/02-ask-anything-explorer.md`.
  - Done when:
    1. The catalog comes from describe for the running user, with deny rows in custom metadata. The
       product's session objects and the setup and history families are denied by default, and Apex
       tests prove each rule.
    2. Field pruning and an on-demand describe keep the per-call catalog at or under 6,000 characters
       on the 30-question set, recorded on the card's page.
    3. A denied object never reaches SOQL, even when it is named in a plan, a `sub` or a path.
- **"FR2+: explorer plan grammar v2 — where groups, two-lookup paths, sub, children, having, step"**
  - Scope: `force-app/main/default/classes/ExplorePlan*.cls`, `ExploreQuery*.cls`, `DataExplorer*.cls`,
    `force-app/main/default/staticresources/AgentPrompt_Explore.resource`.
  - Done when:
    1. Every shape in [rejections.apex](../../spikes/explorer-scale/rejections.apex) is an Apex test with
       the same accept or reject outcome.
    2. Platform rules (2 semi-joins, top level only, no Task or Event inner select, no long-text
       ORDER BY) are refused by the planner with a plain line, never by a platform error.
    3. All values are bound, and a test shows an injected value changes no SOQL text.
- **"FR2+: long-text search for the explorer"**
  - Scope: `ExploreQuery*.cls`, and a SOSL proof under `spikes/`.
  - Done when:
    1. Proof first: SOSL in user mode returns a known word from a case subject in agent-probe. If it
       does not, the card keeps the post-filter and records why.
    2. `CONTAINS` on long text returns the same records as a hand query, and refuses past the scan cap
       with a plain line.
    3. Sorting or grouping by long text is refused before SOQL runs.
- **"FR2+: explorer evaluation, three runs per engine"**
  - Scope: `spikes/explorer-scale/**`, `docs/research/`.
  - Done when:
    1. The 30 questions run 3 times on the deployed explorer before and after the build, with pass
       counts and spread recorded.
    2. Per-question medians of model calls, input tokens, CPU and heap are recorded next to this page's.
    3. Any question that fails in every run gets a named cause on the page.

## Sources

Salesforce Help pages are named by title, because their addresses carry a query string:

- Standard Agent Action Reference.
- Agent Action: Query Records.
- Agent Action: Query Records with Aggregate (Beta).
- Agent Execution Context and Data Access by Type.
- Data stream schedules, and Data Graphs.
- Cross Filters overview.
- Filter Logic.
- Report and dashboard limits.
- Limits on Report Types.
- Long text area fields in report filters (knowledge article).

Other pages:

- [SOQL and SOSL limits](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_limits.htm)
- [Relationship query limits](https://developer.salesforce.com/docs/atlas.en-us.262.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_relationships_query_limits.htm)
- [Semi-joins and anti-joins](https://developer.salesforce.com/docs/atlas.en-us.262.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_semijoin_antijoin.htm)
- [AccessLevel class](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AccessLevel.htm)
- [Analytics REST API limits](https://developer.salesforce.com/docs/analytics/salesforce-analytics-rest-api/guide/sforce-analytics-rest-api-limits-limitations.html)
- [Data 360 security architecture](https://architect.salesforce.com/docs/architect/fundamentals/guide/data360_security_architecture)
- [Data 360 architecture](https://architect.salesforce.com/docs/architect/fundamentals/guide/data-360-architecture.html)
- Data 360 "Request Data With Query V1" (Query API reference).
- The Flex Credits rate card PDF (11.3.2026).

## Undo

Nothing was left in the org: every run was anonymous Apex that read data and describe, and wrote nothing.
No deploy, publish, activation, user or record was created. Each anonymous run leaves a debug log in the
org, as any `sf apex run` does. The logs age out on their own.

- Repo: delete `spikes/explorer-scale/` and this page.
- Local only: the red file `.delegation/BE-31/red-1.txt` in the BE-31 worktree (git-ignored).
