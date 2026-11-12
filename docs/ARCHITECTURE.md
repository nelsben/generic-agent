# Architecture

The engineer reference. The [pattern pages](patterns/) explain each part for adopters, with
tests and review findings; this page is the map and the rules.

The agent answers with a small, fixed set of actions. Each answer follows one pattern:
**route, gather, reduce**. Everything below the agent is Apex; there are no Flows and no
prompt template metadata.

```
User -> Agent (route) or panel (accountBriefPanel -> AccountBriefPanelController)
  1. Resolve Account for Brief   AccountBriefResolver   -> RESOLVED / AMBIGUOUS / NOT_FOUND
  2. Get Account Brief           AccountBriefGetAction  -> AccountBrief.run(accountId, question, include)
       gather:  registry sources, deterministic Apex, no model
       reduce:  contacts + activity + calls -> BriefEngagement  (pre-reduce)
                deal_history                -> BriefDealHistory (pre-reduce)
                everything else + both summaries + question -> BriefSynthesis
       memory:  AccountBriefMemory.recordAll, once, after every model call
  3. Explore Data                ExploreAction          -> DataExplorer.explore(question, contextRecordId, historyJson)
```

Route: the agent always resolves first and briefs only a RESOLVED Id. Gather: each source
builds one plain-text section. Reduce: the model writes prose from those sections only.
Pattern pages: [01 route, gather, reduce](patterns/01-route-gather-reduce.md),
[06 agent routing](patterns/06-agent-routing-and-verbatim-relay.md).

## Class map

| Class | Job |
|---|---|
| `AccountBriefResolver` | Words or the open record to one Account (the resolve action) |
| `AccountBriefGetAction` | The Get Account Brief action; parses `include`, calls `AccountBrief` |
| `AccountBrief` | The brief's only entry point: visibility gate, registry, reduce map, memory |
| `AccountBriefSource` | Interface every gather source implements: `key()`, `title()`, `build(Id)` |
| `AccountBrief*Section` | The seven sources: profile, open_deals, cases, contacts, activity, calls, deal_history |
| `AccountBriefSection` | The one shape a source returns: key, title, status, body, total, shown |
| `AccountBriefMemory` | Per-user, per-account memory of past briefs. The only DML, in system mode. No invocable entry point |
| `AgentLlm` | The only door to a model: loads a prompt, fills `{{vars}}`, calls the provider |
| `AgentLlmModelsApi` | Default provider: the Salesforce Models API, model held in one constant |
| `DataExplorer` | Explore loop (`explore`) and model-free drill-down (`drill`); see Explore |
| `ExploreCatalog` | Curated objects and fields, describe-checked for the running user |
| `ExplorePlan` | The JSON query plan the model fills, and its validation |
| `ExploreQuery` | Builds bound SOQL from a resolved plan and runs it in user mode (read-only) |
| `ExploreAction` | The Explore Data action: question in, status and answer plus a table out |
| `AccountBriefPanelController` | `@AuraEnabled` door for the panel: resolve, getBrief, explore, drill, history, sources, agentId. Catches everything |

The panel is the LWC `accountBriefPanel` in the `Account_Brief_UtilityBar` utility bar
([03 hotkey panel](patterns/03-hotkey-panel.md)).

## Add a source

Pattern page: [01 route, gather, reduce](patterns/01-route-gather-reduce.md).

1. Write `AccountBriefXSection implements AccountBriefSource`. `build()` never throws; it
   returns OK, EMPTY (one human sentence) or ERROR, plain text, capped. Query `WITH USER_MODE`
   and return `AccountBriefSection.failed(...)` from the catch block.
2. Add one line to `AccountBrief.registry` (key, class name). Registry order is brief order.
3. To get it narrated, either add its key to a `PRE_REDUCES` entry or reference `{{key}}`
   in `AgentPrompt_BriefSynthesis`. Its key is then a valid `include` value.

## Add a provider

Pattern page: [04 model provider seam](patterns/04-model-provider-seam.md).

Write one class implementing `AgentLlm.Provider` and set `AgentLlm.PROVIDER_CLASS` to it.
Nothing else changes. Only the provider class may reference a vendor or platform model API.
`AgentLlm` caps every reply at `maxTokens` x 4 characters, for every provider.

## Where prompts live

Pattern page: [04 model provider seam](patterns/04-model-provider-seam.md).

`force-app/main/default/staticresources/AgentPrompt_<Name>.resource`, plain text, with a
`---system---` part then a `---user---` part. Placeholders are `{{name}}`, filled in one
literal pass; a placeholder with no value is an error. Edit the file and redeploy: no
version bumps. Callers name a prompt without the prefix: `AgentLlm.complete('BriefSynthesis', ...)`.
A prompt is read once per transaction and cached.

## Rules

Pattern page: [07 trust, access and failure](patterns/07-trust-access-and-failure.md).

- No prose in Apex. Apex emits facts and fixed one-line statements; prompts write prose.
- A prompt never queries data. Every fact it states was gathered upstream.
- Caps: each source caps its rows and body; prompts cap their length. Keep the final
  answer well under the chat relay ceiling (about 6K characters).
- Sections reach the model as their body when OK, `<STATUS>: <body>` otherwise, and
  `EMPTY: not requested` when not included. A skipped pre-reduce passes `EMPTY`.
- Status is relayed verbatim. NOT_FOUND and ERROR carry fixed user-facing text in `answer`.
  A brief where no section is OK and at least one failed is ERROR, not EMPTY.
- DML last: memory is written once per transaction, through `AccountBriefMemory.recordAll`,
  only after every model call, and only on OK or EMPTY. A model failure gives ERROR, keeps the
  sections, and writes nothing. A failed memory write is logged and the brief still returns.
- `with sharing` everywhere; the brief adds no visibility the user lacks. Every read of CRM data
  states `WITH USER_MODE` or `AccessLevel.USER_MODE`. Only memory runs in system mode.
- The panel controller turns any unexpected exception into an `AuraHandledException` with one
  fixed line.
- Tests set `AgentLlm.stub`; no test calls a model.

## Permission sets

Pattern page: [07 trust, access and failure](patterns/07-trust-access-and-failure.md).

- `Account_Brief_Data_Access`: app visibility for `Account_Brief`, class access to the five entry
  points only (`AccountBriefGetAction`, `AccountBriefMemory`, `AccountBriefPanelController`,
  `AccountBriefResolver`, `ExploreAction`), and Read on `Account_Brief_Session__c` and its fields.
  No Create, Edit, Delete, View All or Modify All: memory writes run in system mode, so users
  never need them.
- `Account_Brief_Agent_Access`: access to the `Account_Brief` agent, nothing else.
- `tests/test_permission_sets.py` pins both. A new entry point needs a line in the set and in
  the test.

## Memory

Pattern page: [05 conversation memory](patterns/05-conversation-memory.md).

- One `Account_Brief_Session__c` row per user and account, keyed by `Session_Key__c`
  (User Id + `_` + Account Id). `Turns_JSON__c` is a ring of the newest 10 turns
  (`MAX_TURNS`); headlines are clipped to 200 characters.
- `recordAll` reads the rows it will change `FOR UPDATE`, inserts a missing row, and on
  DUPLICATE_VALUE redoes the whole write once from a fresh locked read.
- Rows per user are capped at 200 (`maxRowsPerUser`). After a write that created rows, the
  user's least recently active rows beyond the cap are deleted. Other users' rows are never
  touched.
- There is no invocable entry point. The old `recordFromFlow` action is gone; only the engine
  writes memory.
- Reads: `history(accountId)` feeds the panel's "Earlier briefs". `lastBrief(accountId)` has no
  production caller yet.
- In a conversation, the panel sends its last 5 turns to `DataExplorer.explore` as
  `historyJson`; the agent keeps `briefed_account_id` and `briefed_account_name`.

## Explore

Pattern page: [02 ask-anything explorer](patterns/02-ask-anything-explorer.md).

Ask anything, drill into anything. The model never writes SOQL: it fills a JSON plan, and
Apex checks, builds and runs it. Entry points: `DataExplorer.explore(question, contextRecordId,
historyJson)`, `DataExplorer.drill(recordId, relatedObject)` (no model), and the `Explore Data`
action (`ExploreAction`).

- **Loop.** Each turn `AgentPrompt_Explore` gets the catalog, the open record, the history, the
  question, the turns so far and `queries_left`. The model replies with one JSON object:
  `{"action":"query","plan":{...}}` or `{"action":"answer","text":"...","followups":[...]}`. Caps:
  5 turns, 4 queries. At 0 queries left the prompt says answer now. A bad reply, a plan error, a
  QueryException or a row-cap refusal goes back as `INVALID: <reason>` (a refused or failed query
  still counts as a query). The model sees 20 rows plus the total per query.
- **Turn cap.** When the turns run out with result sets in hand, they are kept: the status is
  OK (EMPTY when no set has rows) and the answer is `TURN_CAP_TEXT`, so the caller still shows
  the last result. Turns that run out with nothing read, and any model failure, are ERROR.
- **Plan.** `object`, `fields[]`, `filters[]` of `{field, op, value}` joined by AND (ops
  `= != < <= > >= LIKE IN`), `orderBy {field, dir}`, `limit`, `groupBy[]`,
  `aggregates[]` of `{fn, field}` (COUNT SUM AVG MIN MAX). Date values are `YYYY-MM-DD`
  (a Datetime field also takes `YYYY-MM-DDThh:mm:ssZ`) or a token from
  `ExplorePlan.DATE_LITERALS` / `DATE_LITERALS_N`.
- **Dates.** A date-only value on a Datetime field means the whole day in the running user's
  time zone, never midnight GMT. `=` becomes a range from that local midnight to the next and
  `!=` its outside (or null); `>` and `<=` move to the start of the next local day; `<` and `>=`
  use the start of the day; each date-only `IN` item gets its own day range.
- **Guards.** `ExplorePlan.resolve` matches every name to the catalog and returns errors in plain
  English. `ExploreQuery` resolves again and builds SOQL only from catalog paths, fixed tokens
  and its own aliases. Every value is bound. The limit defaults to 50 and is capped at 200; an
  aggregate without groupBy gets no LIMIT. Queries run in `AccessLevel.USER_MODE`. There is no DML.
  A model failure returns ERROR with fixed text and keeps the result sets already read.
- **Row cap.** A LIMIT on an aggregate limits groups, not the records read, and the 50,000
  query-row limit cannot be caught. So an aggregate first runs `COUNT()` with
  `LIMIT ROW_CAP + 1` (`ROW_CAP` is 10,000, shrunk to what the transaction has left), and throws
  `ExploreQuery.RowCapException` instead of running when more match. An aggregate whose only
  functions are `COUNT(Id)` skips the pre-count. Four queries at most 10,001 rows each keep one
  question under the limit.
- **Labels.** Each result set carries a plain label per column (no dots, unique). Answers, the
  model preview and the panel show labels; rows stay keyed by field path.
- **Catalog.** `ExploreCatalog.CURATED` maps each object to its allowed fields and one-level
  parent paths. Each name is describe-checked for the running user: anything not accessible or
  not in the org is dropped. Long text is shown but not filterable.
- **In the agent.** The `explore` subagent runs `explore_data` deterministically in
  `before_reasoning`, with `@system_variables.user_input` as the question, and relays its answer
  verbatim. It passes no open record and no history. `ExploreAction` keeps the answer plus the
  last result's table under 5,900 characters.

To add an object, add one `CURATED` entry, `'Object' => new List<String>{ 'Id', 'Name', ... }`,
with names as strings. Lookups and parent paths such as `Account.Name` work from then on in
plans and in `drill`. Nothing else changes.

## Tests and release

Pattern page: [08 test and release lifecycle](patterns/08-test-and-release-lifecycle.md).

Local: `python3 -m unittest discover -s tests` and `npm run test:unit`. Org, check-only:
`bash scripts/validate-org.sh` (all `*Test` classes) and `bash scripts/agent-check.sh`. Then the
agent's draft-first lifecycle: Studio save and preview, publish, activate, `sf agent test run`.
Browser: `npm run test:e2e`.

## Outside callers

Pattern page: [09 outside door (MCP)](patterns/09-outside-door-mcp.md). Designed, not built: a
Salesforce Hosted MCP server exposing the three actions and the agent as tools, as the
signed-in user.
