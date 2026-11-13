# FR2: the card contract in Apex (BE-39)

BE-39 builds FE-18's card contract ([fr2-card-architecture.md](fr2-card-architecture.md)) in Apex. One class, `AnswerCard`, holds the types, one builder per card type, the rich-text parser, the plain-text rule and the JSON for the invocables. The summary and the explorer each return the same answer as cards next to their unchanged text. The panel gets them through its controller, and the two invocables return them as one more output, `cards`, a JSON string.

Read with: [fr2-card-architecture.md](fr2-card-architecture.md) (FE-18: the contract, the catalog and the MCP findings) and the task [BE-39](../../agents/tasks/BE-39-fr2-card-contract-in-apex.md). For: [FE-22](../../agents/tasks/FE-22-fr2-history-scope-chip-and-cards.md) (renders the cards in the conversation), [BE-27](../../agents/tasks/BE-27-fr2-write-action-service-one-apex.md) (fills `actionDraft` and `actionResult`), [FE-14](../../agents/tasks/FE-14-fr2-write-action-cards-in-the.md) (draws the action cards) and [FE-19](../../agents/tasks/FE-19-fr2-customer-history-and-sentiment-on.md) (history), and [BE-46](../../agents/tasks/BE-46-fr2-the-resolver-and-the-drill.md) (the resolver's choice card and the drill).

## What was built, in short

- **One class, `AnswerCard`** (`with sharing`). It has no query, DML or callout. It holds the typed FE-18 shape, 14 builders and the parser, and every type's plain-text rule.
- **Every card type the summary and the explorer produce is built.** The summary gives `summary`, `section`, `notice` and `error` cards. The explorer gives `text`, `table`, `metric`, `recordList`, `notice`, `error`, `trail` and `followups` cards. `record`, `timeline`, `comparison` and `choice` have builders and tests but no caller yet. `actionDraft` and `actionResult` are typed, with a text rule, and nothing builds them (BE-27 will).
- **The text is unchanged.** Every existing member and output keeps its name and its value; a test serializes each result and checks its members and text. Cards are built from data the service already holds: no new model call or query.
- **A table card never holds a row its text leaves out.** The explorer's card table holds the rows the caller's text shows, the same `shown`: every row of the last result set for the panel, the rows `compose()` fitted under 5,900 characters for the invocable.
- **The invocable JSON has its own cap, 60,000 characters.** Over it, the `cards` output is `''` (never cut JSON) and the answer is unchanged. The largest summary the tests build gives 22,706 characters of cards JSON (see 'The cards cap').
- **Live in `agent-probe`:** deployed by validate with RunLocalTests and quick deploy, and one summary and one explorer question were run from anonymous Apex (see 'Live check').

## The Apex types as built

`AnswerCard` is the card. Its inner classes are the parts. Every member is `@AuraEnabled`, so the panel reads them as they are. No member is a Map or an Object, every cell and value is a formatted string, and a record Id appears only in `Ref.recordId`.

| Class | Members | Notes |
|---|---|---|
| `AnswerCard` | `type`, `version` (Integer, 1), `key`, `title`, `meta`, `status`, `text`, `body` (List<Block>), `total`, `shown` (Integer), `columns` (List<Column>), `rows` (List<Row>), `items` (List<Item>), `fields` (List<Field>), `controls` (List<Control>), `refs` (List<Ref>) | `body` and `refs` are never null. Every other list is null unless the type uses it, so `JSON.serialize(card, true)` leaves it out. |
| `Block` | `kind` (`p`, `li` or `ol`), `runs` (List<Run>) | One line of rich text. |
| `Run` | `text`, `strong`, `em`, `code` (Boolean), `ref` (a ref key) | The Booleans are set only when true. |
| `Field` | `key`, `label`, `value`, `ref`, `state` (`missing` or `choose`), `choices` (ref keys) | Record and action cards. |
| `Column` | `key`, `label`, `kind` (`text`, `number`, `currency`, `percent` or `date`) | |
| `Row` | `ref`, `cells` (List<String>) | Cells are in column order. `ref` is null for a group. |
| `Item` | `at`, `kind`, `label`, `value`, `detail`, `ref` | `at` and `kind` are for a timeline; `kind` is `related` for a record's related lists. |
| `Control` | `key`, `label`, `kind` (`primary`, `neutral` or `link`) | Action cards. |
| `Ref` | `key`, `recordId`, `objectName`, `label` | The only place an Id appears. |

The members present by type are FE-18's: `section` always has `total`, `shown` and `items`; `table` and `recordList` have `total` and `shown`; `text`, `notice` and `error` have `title` `""`; `followups` and `trail` have no `status`.

### The builders

| Builder | Card | Rules |
|---|---|---|
| `summary(key, status, answer)` | `summary` | The answer's first line is the title, the rest is rich text. `meta` is `Account summary`. |
| `section(CustomerSummarySection s)` | `section`, key `sec-<s.key>` | See 'Sections' below. Null for no section. |
| `text(key, status, markdown, refs)` | `text` | Rich text. A link is a link only when its key is in `refs`. |
| `table(key, title, columns, rows, total, refs)` | `table` | `shown` is the rows it holds. |
| `metric(key, title, items)` | `metric` | |
| `record(key, title, meta, fields, relatedLabels, refs)` | `record` | Each related label is an item with `kind` `related`. |
| `recordList(key, title, items, total, refs)` | `recordList` | `shown` is the items it holds. |
| `timeline(key, title, items, refs)` | `timeline` | The caller sets each item's `at` and `kind`. |
| `comparison(key, title, columns, rows, refs)` | `comparison` | |
| `choice(key, title, items, refs)` | `choice` | Status `AMBIGUOUS`. |
| `followups(key, questions)` | `followups` | Title `Ask next`. No status. |
| `trail(key, items)` | `trail` | Title `Ran N queries` (`Ran 1 query`). No status. |
| `notice(key, status, message)` | `notice` | Literal text, one `p` block per line. |
| `error(key, message)` | `error` | Status `ERROR`. Literal text: the fixed message, never the cause. |

The helpers are `newRef`, `newItem`, `newColumn`, `newRow` and `newField`. `addRef(refs, Id, label)` adds a record and returns its key: the object name's first letter, lowercase, and a count per letter (`o1`, `c1` for a Contact, `c2` for a Case). The same record keeps its key. `parse(text, refs)` gives the blocks, and `plainText(card)` gives the text rule's output; every builder sets `text` from it. `toJson(cards)` and `fromJson(json)` are the invocables' JSON: `toJson` gives `'[]'` for no cards and `''` over the cap, and `fromJson` gives an empty list for blank or unreadable JSON and never throws.

### Rich text

`parse` is FE-18's `parseRich` and `parseInline`, ported line for line, and `AnswerCardTest` has one case per row of FE-18's 'Rich text' table. Lines are right-trimmed and blank lines skipped. A `- ` or `• ` line is a bullet (`li`), a `1. ` or `1) ` line a numbered item (`ol`), and anything else a paragraph (`p`), trimmed. Inline, `**bold**`, `*italic*` (a lone star stays literal), `` `code` `` and `[label](ref:key)` become runs. A link to a key not in the card's refs keeps its label as a plain run. Anything else, HTML and other links included, is literal text.

### Plain text

`plainText` is FE-18's rule per type, and every builder's `text` is its output. The tests assert `plainText(card) == card.text` for every card they build, and for FE-18's `actionDraft` and `actionResult` fixtures. An unknown type keeps its own `text`, and no card gives `''`.

### Sections

A summary section's body is record data, so it is never parsed as markup. `section()` reads it line by line:

- A top-level `- ` line that ends with a record Id (as `CustomerSummarySection.withId` writes it) is an item. Its label is the first ` — ` part, its detail the other parts joined ` · `, and its ref the record, labelled as the item. For the activity and calls sections the first part, and so the label, is the date.
- The `- …and N more not shown` line is left out: `total` and `shown` carry the count.
- Every other line is a literal block: an indented ` • ` contact line is an `li`, a header, a left-out line or a `Next:` line a `p`. A line that ends with an Id becomes one run linked to its record (the Id removed).
- An ERROR section is one `p` block of its fixed message, with `total` and `shown` 0 and no items. Its cause never reaches a card.
- Refs follow the order the records first appear.

So the section card's items are exactly the section's shown records, in order, and its text is the title, `(shown of total)`, and one `- label — detail` line per item.

## What the services return

### The summary

`CustomerSummary.Result` gains `cards` (List<AnswerCard>). `runAll` builds them for every result after the briefs and before the memory write, from the result's own `status`, `answer` and `sections`:

| Result | Cards |
|---|---|
| OK, or EMPTY with sections | `summary` (key `sum`), then one `section` card per section, in the sections' order |
| ERROR (a failed reduce, or every section failed) | `error` (key `err`, the fixed ERROR text), then the sections that were built |
| NOT_FOUND | one `notice` (key `not`), status NOT_FOUND, the fixed not-found text |
| EMPTY with no valid sections | one `notice`, status EMPTY, the same text as `answer` |
| Past the request cap | one `error`, the over-the-cap text |

A failed section is still a section card (status ERROR). A failure building the cards leaves `cards` empty and changes nothing else.

### The explorer

`DataExplorer.Result` gains `cards`. `explore()` builds them after `forDisplay`, with `DataExplorer.cards(result, maxRows)`, in this order:

1. The answer: `text` (key `ans`, the answer's markup as runs, status as the result's) or, on ERROR, `error` (key `err`).
2. The last result set, at most `maxRows` rows of it: a `metric` (`met`) for an aggregate with no groups, one item per column; a `recordList` (`lst`) for records with at most two shown columns, the first the label and the second the detail; otherwise a `table` (`tbl`). Its title is the object's name, its columns are the shown columns in the text's order, and each record row's ref is labelled by its first cell. A grouped row has no ref.
3. A `notice` (`not`), `Showing N of M rows. Ask with a filter to narrow it.`, when that card holds fewer rows than matched.
4. The `trail` (`trl`): one item per query, `Object where filters` and its row count, with Ids hidden as the text hides them.
5. The `followups` (`fol`), when there are any (none on ERROR).

Cells are formatted strings, by the column's catalog field (by path, or by label for an aggregate such as `Sum of Amount`): currency as `$3,000`, a percent with `%`, a number with grouping, a date as `yyyy-MM-dd`, a date-time as `yyyy-MM-dd HH:mm`, a checkbox as `Yes` or `No`. The invocable's text keeps its raw values (`750.00`), so text and card agree on rows, order, labels and counts, and the card's cells are the formatted ones.

## What the panel receives

The panel calls `CustomerSummaryPanelController`, which passes each result through as the engine built it. `getBrief` returns `{status, message, answer, sections, ignored, cards}` and `explore` returns `{status, answer, resultSets, trail, followups, cards}`. Every member before `cards` is unchanged, and `sections` still carries each line's Id for the drill. `cards` is the list above, every member as in the types table; a null member may be absent on the wire. The explorer's table card holds every row of the last result set, because the panel shows them all. The panel does not draw cards yet: FE-22 does.

## What an MCP client gets

The door (mcp-door/, `CustomerSummaryMcp`) has three tools. How a hosted MCP server lays out an invocable's outputs in a tool result is still not observed (FE-18, 'MCP clients'), so this is what each tool returns as outputs. The door's definition names each tool's invocable (its API catalog operation), not the outputs, so a tool's outputs are the invocable's. `cards` was not checked through a signed-in MCP client, because BE-39 does not sign in.

| Tool | Outputs | Cards |
|---|---|---|
| `get_account_summary` (`CustomerSummaryGetAction`) | `status`, `answer` (unchanged), `cards` (new) | The summary's cards as JSON text: the `summary` card and one `section` card per section, each section's records as items with their Ids in `refs`. `''` over 60,000 characters. |
| `ask_anything` (`ExploreAction`) | `status`, `answer` (unchanged), `history` (unchanged), `cards` (new) | The explorer's cards as JSON text, the table cut to the rows the `answer` shows, with a `notice` when that is fewer than matched. `''` over the cap. |
| `resolve_account` (`CustomerSummaryResolver`) | unchanged | None. The choice card for AMBIGUOUS is BE-46's. |

What a client does not get: no card for an earlier turn, no resolver choice card, no drill, no action cards, and no `structuredContent` (still unproven on the hosted server). The `cards` description tells a model it is for a client that can show cards and that the `answer` is what it relays. A client that ignores `cards` loses nothing: the `answer` says the same.

The Customer Summary agent's actions declare their outputs by name, and `cards` is not among them, so the agent and Agentforce's own panel go on with the text alone. Adding `cards` to the agent is an agent change, outside this card.

## The cards cap

`AnswerCard.MAX_JSON_CHARS` is 60,000 characters. The test `theLargestBriefTheTestsBuildFitsTheCardsCap` builds the largest summary the tests make: 60 contacts, 60 deals, 60 cases and 100 tasks with long names, and an answer of 5,517 characters. Its cards JSON is 22,706 characters, measured in `agent-probe` on 2026-11-13. The cap leaves more than twice that, so any summary the sections can build fits, and the explorer's cards are bounded by the 5,900-character text they follow. It is also low enough that one tool result stays a bounded part of a client's context (about 15,000 tokens at most). Over the cap the output is `''`, never cut JSON, and the answer is unchanged. The panel's members are not capped.

## History

`docs/research/fr2-conversation-history.md` does not exist. `CustomerSummaryMemory` stores each turn's question, status and answer text only, in `Customer_Summary_Session__c`. It stores no cards, so a reopened turn shows as its text. No history class changed. A card for a reopened turn would need either the cards stored next to the answer or the turn rebuilt, which is FE-19's and FE-22's to decide.

## What was left out, and why

- **The resolver and the drill** (`choice` for AMBIGUOUS, `record` for a drilled record): BE-46.
- **`actionDraft` and `actionResult` builders:** BE-27. The types hold FE-18's fixtures and their text rule is tested.
- **`timeline` and `comparison` callers:** no service produces them yet. Their builders are tested from FE-18's fixtures.
- **Cards in the agent's outputs:** the agent bundle is outside this card (see 'What an MCP client gets').
- **Links in the explorer's answer:** the model does not know ref keys, so the `text` card has no refs and a `[label](ref:key)` in its answer is plain text.
- **Stored cards:** see 'History'.

## How to add a card type

1. Add its row, fixture and plain-text rule to FE-18's contract ([fr2-card-architecture.md](fr2-card-architecture.md), 'How a new card type is added').
2. If it needs a member the types lack, add it to the inner class as an `@AuraEnabled` String, Integer, Boolean or list of those; never a Map or an Object. An added optional member does not change the version.
3. Add its rule to `AnswerCard.plainText`, in the `switch on c.type`.
4. Add its builder to `AnswerCard`: start the card, set its members, and end with `finish`, which sets `text`. Put any record Id in `refs` with `addRef` and point at it by key.
5. Add a test to `AnswerCardTest` that builds the card and asserts it equals FE-18's fixture with `assertMatchesFixture`, and add the example to this page.
6. Have the service add the card in `CustomerSummary.cardsOf` or `DataExplorer.cards`, from data it already holds, and assert the card agrees with the text.

## Live check

On 2026-11-13, under the approved live-checks row, in `agent-probe`:

- **Deploy.** The eleven changed classes were validated with RunLocalTests (338 tests, 0 failures, every AccountBrief* test among them) and then quick deployed. 11 components deployed, 0 errors.
- **Explorer.** From anonymous Apex, `DataExplorer.explore` was asked "What are the open opportunities for this account and their amounts?" with the seed account Edge Communications as context. It returned 4 cards: `text`, `table` (5 rows, `total` 5, `shown` 5), `trail` (1 item) and `followups` (4 items). Their JSON is 2,895 characters.
- **Summary.** From anonymous Apex, `CustomerSummary.run` for Edge Communications returned status OK and 8 cards: `summary`, then 7 `section` cards. Six sections held records (5, 5, 5, 5 of 10, 4 and 5 items, `total` and `shown` matching the text's counts) and one held none. Their JSON is 19,398 characters, under the cap.
- **Rows written.** Session rows: 0 created and 1 updated (Edge Communications' row, the only one modified during the run). `Customer_Summary_Session__c` held 5 rows before and after. The summary's turn was added to the account's existing row, which is how `CustomerSummaryMemory` stores turns, and the explorer wrote nothing. Outcome rows: 0. The org has no outcome object (no custom object with "outcome" in its name).
- The scripts printed card types and counts only, with no Ids or record contents.

## The JSON examples

Each example below is FE-18's fixture, quoted in `AnswerCardTest`. Record Ids are written `record-id:<key>`, and the names are sample data.

### `summary` (sum)

From `AnswerCardTest.summaryIsTheHeadlineAsTitleAndTheRestAsRuns`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "summary",
  "version": 1,
  "key": "sum",
  "title": "Edge Communications: steady service, one large renewal at risk",
  "meta": "Account summary",
  "status": "OK",
  "text": "Edge Communications: steady service, one large renewal at risk\nOpen deals: 3 worth $412,000; the largest closes this quarter.\nService health: 2 open cases, one high priority for 9 days.\n- Renewal owner has not logged a call in 41 days\n- Two contacts on their side have never been called",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "Open deals:",
          "strong": true
        },
        {
          "text": " 3 worth $412,000; the largest closes this quarter."
        }
      ]
    },
    {
      "kind": "p",
      "runs": [
        {
          "text": "Service health:",
          "strong": true
        },
        {
          "text": " 2 open cases, one "
        },
        {
          "text": "high priority",
          "em": true
        },
        {
          "text": " for 9 days."
        }
      ]
    },
    {
      "kind": "li",
      "runs": [
        {
          "text": "Renewal owner has not logged a call in 41 days"
        }
      ]
    },
    {
      "kind": "li",
      "runs": [
        {
          "text": "Two contacts on their side have never been called"
        }
      ]
    }
  ],
  "refs": []
}
```

### `section` (sec-deals)

From `AnswerCardTest.sectionListsItsRecordsAsItemsWithTheirIdsInRefs`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "section",
  "version": 1,
  "key": "sec-deals",
  "title": "Open deals",
  "status": "OK",
  "text": "Open deals (3 of 3)\n- Edge Emergency Generator — Proposal · $250,000 · closes 2026-12-18\n- Edge Installation — Negotiation · $112,000 · closes 2027-01-30\n- Edge SLA — Qualification · $50,000 · closes 2027-03-02",
  "body": [],
  "total": 3,
  "shown": 3,
  "items": [
    {
      "label": "Edge Emergency Generator",
      "detail": "Proposal · $250,000 · closes 2026-12-18",
      "ref": "o1"
    },
    {
      "label": "Edge Installation",
      "detail": "Negotiation · $112,000 · closes 2027-01-30",
      "ref": "o2"
    },
    {
      "label": "Edge SLA",
      "detail": "Qualification · $50,000 · closes 2027-03-02",
      "ref": "o3"
    }
  ],
  "refs": [
    {
      "key": "o1",
      "recordId": "record-id:o1",
      "objectName": "Opportunity",
      "label": "Edge Emergency Generator"
    },
    {
      "key": "o2",
      "recordId": "record-id:o2",
      "objectName": "Opportunity",
      "label": "Edge Installation"
    },
    {
      "key": "o3",
      "recordId": "record-id:o3",
      "objectName": "Opportunity",
      "label": "Edge SLA"
    }
  ]
}
```

### `section` (sec-calls)

From `AnswerCardTest.aFailedSectionIsASectionCardWithItsFixedMessage`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "section",
  "version": 1,
  "key": "sec-calls",
  "title": "Calls",
  "status": "ERROR",
  "text": "Calls\nCouldn't load Calls right now.",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "Couldn't load Calls right now."
        }
      ]
    }
  ],
  "total": 0,
  "shown": 0,
  "items": [],
  "refs": []
}
```

### `text` (ans)

From `AnswerCardTest.textParsesTheAnswerIntoRunsWithLinksByRef`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "text",
  "version": 1,
  "key": "ans",
  "title": "",
  "status": "OK",
  "text": "There are 212 open opportunities; the 6 largest are below. The top one is Edge Emergency Generator, at $250,000.",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "There are "
        },
        {
          "text": "212",
          "strong": true
        },
        {
          "text": " open opportunities; the 6 largest are below. The top one is "
        },
        {
          "text": "Edge Emergency Generator",
          "ref": "o1"
        },
        {
          "text": ", at "
        },
        {
          "text": "$250,000",
          "code": true
        },
        {
          "text": "."
        }
      ]
    }
  ],
  "refs": [
    {
      "key": "o1",
      "recordId": "record-id:o1",
      "objectName": "Opportunity",
      "label": "Edge Emergency Generator"
    }
  ]
}
```

### `table` (tbl)

From `AnswerCardTest.tableHoldsFormattedCellsAndItsCounts`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "table",
  "version": 1,
  "key": "tbl",
  "title": "Opportunity",
  "status": "OK",
  "text": "Opportunity\nName | Stage | Amount | Close date\nEdge Emergency Generator | Proposal | $250,000 | 2026-12-18\nJuniper Project B | Negotiation | $180,000 | 2026-12-04\nFernhollow Project C | Proposal | $160,000 | 2027-01-12\nEdge Installation | Negotiation | $112,000 | 2027-01-30\nPimble Project B | Qualification | $95,000 | 2027-02-20\nEdge SLA | Qualification | $50,000 | 2027-03-02\n(6 of 212 rows)",
  "body": [],
  "columns": [
    {
      "key": "Name",
      "label": "Name",
      "kind": "text"
    },
    {
      "key": "StageName",
      "label": "Stage",
      "kind": "text"
    },
    {
      "key": "Amount",
      "label": "Amount",
      "kind": "currency"
    },
    {
      "key": "CloseDate",
      "label": "Close date",
      "kind": "date"
    }
  ],
  "rows": [
    {
      "ref": "o1",
      "cells": [
        "Edge Emergency Generator",
        "Proposal",
        "$250,000",
        "2026-12-18"
      ]
    },
    {
      "ref": "o4",
      "cells": [
        "Juniper Project B",
        "Negotiation",
        "$180,000",
        "2026-12-04"
      ]
    },
    {
      "ref": "o5",
      "cells": [
        "Fernhollow Project C",
        "Proposal",
        "$160,000",
        "2027-01-12"
      ]
    },
    {
      "ref": "o2",
      "cells": [
        "Edge Installation",
        "Negotiation",
        "$112,000",
        "2027-01-30"
      ]
    },
    {
      "ref": "o6",
      "cells": [
        "Pimble Project B",
        "Qualification",
        "$95,000",
        "2027-02-20"
      ]
    },
    {
      "ref": "o3",
      "cells": [
        "Edge SLA",
        "Qualification",
        "$50,000",
        "2027-03-02"
      ]
    }
  ],
  "total": 212,
  "shown": 6,
  "refs": [
    {
      "key": "o1",
      "recordId": "record-id:o1",
      "objectName": "Opportunity",
      "label": "Edge Emergency Generator"
    },
    {
      "key": "o4",
      "recordId": "record-id:o4",
      "objectName": "Opportunity",
      "label": "Juniper Project B"
    },
    {
      "key": "o5",
      "recordId": "record-id:o5",
      "objectName": "Opportunity",
      "label": "Fernhollow Project C"
    },
    {
      "key": "o2",
      "recordId": "record-id:o2",
      "objectName": "Opportunity",
      "label": "Edge Installation"
    },
    {
      "key": "o6",
      "recordId": "record-id:o6",
      "objectName": "Opportunity",
      "label": "Pimble Project B"
    },
    {
      "key": "o3",
      "recordId": "record-id:o3",
      "objectName": "Opportunity",
      "label": "Edge SLA"
    }
  ]
}
```

### `metric` (met)

From `AnswerCardTest.metricLeadsWithItsFirstFigure`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "metric",
  "version": 1,
  "key": "met",
  "title": "Open pipeline",
  "status": "OK",
  "text": "Open pipeline\nOpen opportunities: 212 — in your access\nTotal amount: $18.4M\nClosing this quarter: 37",
  "body": [],
  "items": [
    {
      "label": "Open opportunities",
      "value": "212",
      "detail": "in your access"
    },
    {
      "label": "Total amount",
      "value": "$18.4M"
    },
    {
      "label": "Closing this quarter",
      "value": "37"
    }
  ],
  "refs": []
}
```

### `record` (rec)

From `AnswerCardTest.recordHoldsFieldsLookupsAsLinksAndRelatedObjects`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "record",
  "version": 1,
  "key": "rec",
  "title": "Edge Emergency Generator",
  "meta": "Opportunity",
  "status": "OK",
  "text": "Edge Emergency Generator · Opportunity\nAccount: Edge Communications\nStage: Proposal\nAmount: $250,000\nClose date: 2026-12-18\nOwner: Seller One",
  "body": [],
  "fields": [
    {
      "key": "AccountId",
      "label": "Account",
      "value": "Edge Communications",
      "ref": "a1"
    },
    {
      "key": "StageName",
      "label": "Stage",
      "value": "Proposal"
    },
    {
      "key": "Amount",
      "label": "Amount",
      "value": "$250,000"
    },
    {
      "key": "CloseDate",
      "label": "Close date",
      "value": "2026-12-18"
    },
    {
      "key": "OwnerId",
      "label": "Owner",
      "value": "Seller One"
    }
  ],
  "items": [
    {
      "label": "Tasks",
      "kind": "related"
    },
    {
      "label": "Events",
      "kind": "related"
    },
    {
      "label": "Opportunity Contact Roles",
      "kind": "related"
    }
  ],
  "refs": [
    {
      "key": "a1",
      "recordId": "record-id:a1",
      "objectName": "Account",
      "label": "Edge Communications"
    }
  ]
}
```

### `recordList` (lst)

From `AnswerCardTest.recordListEndsOnItsCountWhenCut`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "recordList",
  "version": 1,
  "key": "lst",
  "title": "Contacts never called",
  "status": "OK",
  "text": "Contacts never called\n- Contact One — VP Facilities\n- Contact Two — Procurement lead\n- Contact Three — IT director\n(3 of 4)",
  "body": [],
  "total": 4,
  "shown": 3,
  "items": [
    {
      "label": "Contact One",
      "detail": "VP Facilities",
      "ref": "c1"
    },
    {
      "label": "Contact Two",
      "detail": "Procurement lead",
      "ref": "c2"
    },
    {
      "label": "Contact Three",
      "detail": "IT director",
      "ref": "c3"
    }
  ],
  "refs": [
    {
      "key": "c1",
      "recordId": "record-id:c1",
      "objectName": "Contact",
      "label": "Contact One"
    },
    {
      "key": "c2",
      "recordId": "record-id:c2",
      "objectName": "Contact",
      "label": "Contact Two"
    },
    {
      "key": "c3",
      "recordId": "record-id:c3",
      "objectName": "Contact",
      "label": "Contact Three"
    }
  ]
}
```

### `timeline` (tml)

From `AnswerCardTest.timelineLinesLeadWithTheirDate`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "timeline",
  "version": 1,
  "key": "tml",
  "title": "Recent activity",
  "status": "OK",
  "text": "Recent activity\n2026-11-10 · Call: renewal check-in — Seller One\n2026-11-04 · Email: revised proposal sent — Seller One\n2026-10-28 · Case comment: generator fault — Support",
  "body": [],
  "items": [
    {
      "at": "2026-11-10",
      "kind": "call",
      "label": "Call: renewal check-in",
      "detail": "Seller One",
      "ref": "t1"
    },
    {
      "at": "2026-11-04",
      "kind": "email",
      "label": "Email: revised proposal sent",
      "detail": "Seller One",
      "ref": "t2"
    },
    {
      "at": "2026-10-28",
      "kind": "case",
      "label": "Case comment: generator fault",
      "detail": "Support",
      "ref": "k1"
    }
  ],
  "refs": [
    {
      "key": "t1",
      "recordId": "record-id:t1",
      "objectName": "Task",
      "label": "Call: renewal check-in"
    },
    {
      "key": "t2",
      "recordId": "record-id:t2",
      "objectName": "Task",
      "label": "Email: revised proposal sent"
    },
    {
      "key": "k1",
      "recordId": "record-id:k1",
      "objectName": "Case",
      "label": "Generator fault"
    }
  ]
}
```

### `comparison` (cmp)

From `AnswerCardTest.comparisonIsAGridWithTheFieldFirst`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "comparison",
  "version": 1,
  "key": "cmp",
  "title": "Two largest open deals",
  "status": "OK",
  "text": "Two largest open deals\nField | Edge Emergency Generator | Juniper Project B\nStage | Proposal | Negotiation\nAmount | $250,000 | $180,000\nClose date | 2026-12-18 | 2026-12-04\nLast activity | 3 days ago | 19 days ago",
  "body": [],
  "columns": [
    {
      "key": "field",
      "label": "Field",
      "kind": "text"
    },
    {
      "key": "o1",
      "label": "Edge Emergency Generator",
      "kind": "text"
    },
    {
      "key": "o4",
      "label": "Juniper Project B",
      "kind": "text"
    }
  ],
  "rows": [
    {
      "cells": [
        "Stage",
        "Proposal",
        "Negotiation"
      ]
    },
    {
      "cells": [
        "Amount",
        "$250,000",
        "$180,000"
      ]
    },
    {
      "cells": [
        "Close date",
        "2026-12-18",
        "2026-12-04"
      ]
    },
    {
      "cells": [
        "Last activity",
        "3 days ago",
        "19 days ago"
      ]
    }
  ],
  "refs": []
}
```

### `choice` (cho)

From `AnswerCardTest.choiceNumbersItsCandidatesAndIsAmbiguous`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "choice",
  "version": 1,
  "key": "cho",
  "title": "More than one account matches \"edge\". Which one?",
  "status": "AMBIGUOUS",
  "text": "More than one account matches \"edge\". Which one?\n1. Edge Communications — Austin\n2. Edge Communications — Toronto\n3. Edgewater Freight — Portland",
  "body": [],
  "items": [
    {
      "label": "Edge Communications",
      "detail": "Austin",
      "ref": "a1"
    },
    {
      "label": "Edge Communications",
      "detail": "Toronto",
      "ref": "a2"
    },
    {
      "label": "Edgewater Freight",
      "detail": "Portland",
      "ref": "a3"
    }
  ],
  "refs": [
    {
      "key": "a1",
      "recordId": "record-id:a1",
      "objectName": "Account",
      "label": "Edge Communications"
    },
    {
      "key": "a2",
      "recordId": "record-id:a2",
      "objectName": "Account",
      "label": "Edge Communications"
    },
    {
      "key": "a3",
      "recordId": "record-id:a3",
      "objectName": "Account",
      "label": "Edgewater Freight"
    }
  ]
}
```

### `followups` (fol)

From `AnswerCardTest.followupsAreChipsUnderAskNext`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "followups",
  "version": 1,
  "key": "fol",
  "title": "Ask next",
  "text": "Ask next\n- Which of these close this quarter?\n- Who on their side have we not called?\n- Show the open cases",
  "body": [],
  "items": [
    {
      "label": "Which of these close this quarter?"
    },
    {
      "label": "Who on their side have we not called?"
    },
    {
      "label": "Show the open cases"
    }
  ],
  "refs": []
}
```

### `trail` (trl)

From `AnswerCardTest.trailCountsItsQueries`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "trail",
  "version": 1,
  "key": "trl",
  "title": "Ran 2 queries",
  "text": "Ran 2 queries\n1. Opportunity where IsClosed = false: COUNT() — 212 rows\n2. Opportunity where IsClosed = false, by Amount descending, first 6 — 6 of 212 rows",
  "body": [],
  "items": [
    {
      "label": "Opportunity where IsClosed = false: COUNT()",
      "detail": "212 rows"
    },
    {
      "label": "Opportunity where IsClosed = false, by Amount descending, first 6",
      "detail": "6 of 212 rows"
    }
  ],
  "refs": []
}
```

### `notice` (not)

From `AnswerCardTest.noticeIsOneSentence`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "notice",
  "version": 1,
  "key": "not",
  "title": "",
  "status": "OK",
  "text": "Showing 50 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it.",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "Showing 50 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it."
        }
      ]
    }
  ],
  "refs": []
}
```

### `error` (err)

From `AnswerCardTest.errorCarriesTheFixedMessage`, which builds this card and asserts that it equals this JSON, record Ids aside.

```json
{
  "type": "error",
  "version": 1,
  "key": "err",
  "title": "",
  "status": "ERROR",
  "text": "I couldn't finish that right now. Try again in a minute.",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "I couldn't finish that right now. Try again in a minute."
        }
      ]
    }
  ],
  "refs": []
}
```

### `actionDraft` (drf)

From `AnswerCardTest.theActionDraftAndResultFitTheTypesAndTheirTextRules`, which reads this JSON into the types and checks its text rule. Nothing builds this type yet.

```json
{
  "type": "actionDraft",
  "version": 1,
  "key": "drf",
  "title": "Create a task",
  "meta": "Task · create",
  "status": "NEEDS_INPUT",
  "text": "Create a task · Task · create\nSubject: Follow up on the generator proposal\nDue: 2026-11-17\nContact: Jordan (choose one)\nRelated to: Edge Emergency Generator\nPriority: (needed)\nNote: Two contacts match \"Jordan\"; choose one or clear the field.\nOptions: Confirm, Edit, Cancel",
  "body": [],
  "fields": [
    {
      "key": "Subject",
      "label": "Subject",
      "value": "Follow up on the generator proposal"
    },
    {
      "key": "ActivityDate",
      "label": "Due",
      "value": "2026-11-17"
    },
    {
      "key": "WhoId",
      "label": "Contact",
      "value": "Jordan",
      "state": "choose",
      "choices": [
        "c1",
        "c4"
      ]
    },
    {
      "key": "WhatId",
      "label": "Related to",
      "value": "Edge Emergency Generator",
      "ref": "o1"
    },
    {
      "key": "Priority",
      "label": "Priority",
      "value": "",
      "state": "missing"
    }
  ],
  "items": [
    {
      "label": "Two contacts match \"Jordan\"; choose one or clear the field."
    }
  ],
  "controls": [
    {
      "key": "confirm",
      "label": "Confirm",
      "kind": "primary"
    },
    {
      "key": "edit",
      "label": "Edit",
      "kind": "neutral"
    },
    {
      "key": "cancel",
      "label": "Cancel",
      "kind": "link"
    }
  ],
  "refs": [
    {
      "key": "c1",
      "recordId": "record-id:c1",
      "objectName": "Contact",
      "label": "Jordan Lee"
    },
    {
      "key": "c4",
      "recordId": "record-id:c4",
      "objectName": "Contact",
      "label": "Jordan Park"
    },
    {
      "key": "o1",
      "recordId": "record-id:o1",
      "objectName": "Opportunity",
      "label": "Edge Emergency Generator"
    }
  ]
}
```

### `actionResult` (res)

From `AnswerCardTest.theActionDraftAndResultFitTheTypesAndTheirTextRules`, which reads this JSON into the types and checks its text rule. Nothing builds this type yet.

```json
{
  "type": "actionResult",
  "version": 1,
  "key": "res",
  "title": "Task created",
  "meta": "Task",
  "status": "OK",
  "text": "Task created · Task\nSubject: Follow up on the generator proposal\nDue: 2026-11-17\nContact: Jordan Lee\nSaved as you, with your access. Undo is offered for 15 seconds after an update.",
  "body": [
    {
      "kind": "p",
      "runs": [
        {
          "text": "Saved as you, with your access. Undo is offered for 15 seconds after an update."
        }
      ]
    }
  ],
  "fields": [
    {
      "key": "Subject",
      "label": "Subject",
      "value": "Follow up on the generator proposal",
      "ref": "t9"
    },
    {
      "key": "ActivityDate",
      "label": "Due",
      "value": "2026-11-17"
    },
    {
      "key": "WhoId",
      "label": "Contact",
      "value": "Jordan Lee"
    }
  ],
  "controls": [
    {
      "key": "open",
      "label": "Open task",
      "kind": "primary"
    }
  ],
  "refs": [
    {
      "key": "t9",
      "recordId": "record-id:t9",
      "objectName": "Task",
      "label": "Follow up on the generator proposal"
    }
  ]
}
```
