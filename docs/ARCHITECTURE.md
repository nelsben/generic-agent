# Architecture

The agent answers with a small, fixed set of actions. Each answer follows one pattern:
**route, gather, reduce**. Everything below the agent is Apex; there are no Flows and no
prompt template metadata.

```
User -> Agent (route)
  1. Resolve Account for Brief   AccountBriefResolver   -> RESOLVED / AMBIGUOUS / NOT_FOUND
  2. Get Account Brief           AccountBriefGetAction  -> AccountBrief.run(accountId, question, include)
       gather:  registry sources, deterministic Apex, no model
       reduce:  contacts + activity + calls -> BriefEngagement  (pre-reduce)
                deal_history                -> BriefDealHistory (pre-reduce)
                everything else + both summaries + question -> BriefSynthesis
       memory:  AccountBriefMemory.record, last
```

Route: the agent always resolves first and briefs only a RESOLVED Id. Gather: each source
builds one plain-text section. Reduce: the model writes prose from those sections only.

## Class map

| Class | Job |
|---|---|
| `AccountBriefResolver` | Words or the open record to one Account (the resolve action) |
| `AccountBriefGetAction` | The Get Account Brief action; parses `include`, calls `AccountBrief` |
| `AccountBrief` | The brief's only entry point: visibility gate, registry, reduce map, memory |
| `AccountBriefSource` | Interface every gather source implements: `key()`, `title()`, `build(Id)` |
| `AccountBrief*Section` | The seven sources: profile, open_deals, cases, contacts, activity, calls, deal_history |
| `AccountBriefSection` | The one shape a source returns: key, title, status, body, total, shown |
| `AccountBriefMemory` | Per-user, per-account memory of past briefs (the only DML) |
| `AgentLlm` | The only door to a model: loads a prompt, fills `{{vars}}`, calls the provider |
| `AgentLlmModelsApi` | Default provider: the Salesforce Models API, model held in one constant |
| `DataExplorer` | Explore loop (`explore`) and model-free drill-down (`drill`); see Explore |
| `ExploreCatalog` | Curated objects and fields, describe-checked for the running user |
| `ExplorePlan` | The JSON query plan the model fills, and its validation |
| `ExploreQuery` | Builds bound SOQL from a resolved plan and runs it in user mode (read-only) |
| `ExploreAction` | The Explore Data action: question in, status and answer plus a table out |

## Add a source

1. Write `AccountBriefXSection implements AccountBriefSource`. `build()` never throws; it
   returns OK, EMPTY (one human sentence) or ERROR, plain text, capped.
2. Add one line to `AccountBrief.registry` (key, class name). Registry order is brief order.
3. To get it narrated, either add its key to a `PRE_REDUCES` entry or reference `{{key}}`
   in `AgentPrompt_BriefSynthesis`. Its key is then a valid `include` value.

## Add a provider

Write one class implementing `AgentLlm.Provider` and set `AgentLlm.PROVIDER_CLASS` to it.
Nothing else changes. Only the provider class may reference a vendor or platform model API.

## Where prompts live

`force-app/main/default/staticresources/AgentPrompt_<Name>.resource`, plain text, with a
`---system---` part then a `---user---` part. Placeholders are `{{name}}`, filled in one
literal pass; a placeholder with no value is an error. Edit the file and redeploy: no
version bumps. Callers name a prompt without the prefix: `AgentLlm.complete('BriefSynthesis', ...)`.

## Rules

- No prose in Apex. Apex emits facts and fixed one-line statements; prompts write prose.
- A prompt never queries data. Every fact it states was gathered upstream.
- Caps: each source caps its rows and body; prompts cap their length. Keep the final
  answer well under the chat relay ceiling (about 6K characters).
- Sections reach the model as their body when OK, `<STATUS>: <body>` otherwise, and
  `EMPTY: not requested` when not included. A skipped pre-reduce passes `EMPTY`.
- Status is relayed verbatim. NOT_FOUND and ERROR carry fixed user-facing text in `answer`.
- DML last: memory is written only after every model call, and only on OK or EMPTY.
  A model failure gives ERROR, keeps the sections, and writes nothing.
- `with sharing` everywhere; the brief adds no visibility the user lacks.
- Tests set `AgentLlm.stub`; no test calls a model.

## Explore

Ask anything, drill into anything. The model never writes SOQL: it fills a JSON plan, and
Apex checks, builds and runs it. Entry points: `DataExplorer.explore(question, contextRecordId,
historyJson)`, `DataExplorer.drill(recordId, relatedObject)` (no model), and the `Explore Data`
action (`ExploreAction`).

- **Loop.** Each turn `AgentPrompt_Explore` gets the catalog, the open record, the history, the
  question, the turns so far and `queries_left`. The model replies with one JSON object:
  `{"action":"query","plan":{...}}` or `{"action":"answer","text":"...","followups":[...]}`. Caps:
  5 turns, 4 queries. At 0 queries left the prompt says answer now. A bad reply, a plan error or a
  QueryException goes back as `INVALID: <reason>`. The model sees 20 rows plus the total per query.
- **Plan.** `object`, `fields[]`, `filters[]` of `{field, op, value}` joined by AND (ops
  `= != < <= > >= LIKE IN`), `orderBy {field, dir}`, `limit`, `groupBy[]`,
  `aggregates[]` of `{fn, field}` (COUNT SUM AVG MIN MAX). Date values are `YYYY-MM-DD` or a token
  from `ExplorePlan.DATE_LITERALS` / `DATE_LITERALS_N`.
- **Guards.** `ExplorePlan.resolve` matches every name to the catalog and returns errors in plain
  English. `ExploreQuery` resolves again and builds SOQL only from catalog paths, fixed tokens
  and its own aliases. Every value is bound. The limit defaults to 50 and is capped at 200; an
  aggregate without groupBy gets no LIMIT. Queries run in `AccessLevel.USER_MODE`. There is no DML.
  A model failure returns ERROR with fixed text and keeps the result sets already read.
- **Catalog.** `ExploreCatalog.CURATED` maps each object to its allowed fields and one-level
  parent paths. Each name is describe-checked for the running user: anything not accessible or
  not in the org is dropped. Long text is shown but not filterable.

To add an object, add one `CURATED` entry, `'Object' => new List<String>{ 'Id', 'Name', ... }`,
with names as strings. Lookups and parent paths such as `Account.Name` work from then on in
plans and in `drill`. Nothing else changes.
