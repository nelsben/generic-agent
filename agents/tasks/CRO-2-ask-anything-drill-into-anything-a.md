---
id: CRO-2
title: Ask anything, drill into anything: a safe data explorer where the model fills a structured query plan and Apex validates, builds and runs it in a capped loop
domain: cross
tier: frontier
tier_reason: security-sensitive query builder plus an agentic loop; the catalog and validator are the safety boundary
status: merged
scope: [force-app/main/default/classes/Explore*.cls, force-app/main/default/classes/Explore*.cls-meta.xml, force-app/main/default/classes/DataExplorer*.cls, force-app/main/default/classes/DataExplorer*.cls-meta.xml, force-app/main/default/staticresources/AgentPrompt_Explore*, docs/ARCHITECTURE.md]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/AccountBrief*.cls, force-app/main/default/classes/AgentLlm*.cls, force-app/main/default/objects/**]
red_test: bash scripts/validate-org.sh (DataExplorerTest absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Ben wants the 'ask any question, drill down into anything' pattern from his Plesio project in the baseline, made safe. Plesio lets the model write SOQL and validates the string; most of its bugs came from parsing that string. Here the model never writes SOQL: it fills a small JSON plan, Apex checks every name against a curated catalog and the user's access, builds the query itself with bound values, and runs it in user mode. The loop, self-correction, follow-up suggestions and visible query trail carry over from Plesio. Model calls go through the AgentLlm seam built in CRO-1.

## Done when

- Read first: docs/ARCHITECTURE.md, AgentLlm.cls and AccountBrief.cls on main (from CRO-1), and the pattern notes at /Users/bennelsen/.claude/projects/-Users-bennelsen-Documents-generic-agent/memory/plesio-data-explorer-pattern.md (do not copy Plesio names into the repo)
- `ExploreCatalog.cls` (`public with sharing`): a curated map of object to allowed fields for Account, Contact, Opportunity, OpportunityContactRole, Case, Task, Event and User (User limited to Id, Name, Title). One-level parent paths are allowed where listed (e.g. Owner.Name, Account.Name). Every object and field is describe-checked for the running user (isAccessible) and dropped if not accessible or not present in the org; long text fields are marked not filterable. `describeForPrompt()` renders the catalog as compact text. Cached per transaction. Adding an object is one map entry
- `ExplorePlan.cls`: the plan the model may emit, parsed from JSON: object, fields[], filters[] of {field, op, value} joined by AND, orderBy {field, dir}, limit, groupBy[] and aggregates[] of {fn, field} with fn in COUNT/SUM/AVG/MIN/MAX. Allowed ops: =, !=, <, <=, >, >=, LIKE, IN, and date literals from a fixed list (TODAY, THIS_QUARTER, LAST_N_DAYS:n and similar; name the list in code). `validate(plan)` returns a list of plain-English errors: unknown object or field, non-filterable field in a filter, bad op, bad date literal, a mix of plain fields and aggregates without groupBy. No raw SOQL fragment from the model is ever concatenated
- `ExploreQuery.cls` (`public with sharing`, header 'Read-only: no DML.'): builds SOQL from a validated plan with every value bound, a row limit defaulted to 50 and clamped to 200 (no LIMIT on an aggregate without groupBy), and runs it with `Database.queryWithBinds(..., AccessLevel.USER_MODE)`. It returns a ResultSet {object, columns, rows (List<Map<String,Object>>), total shown, the plan, and the SOQL text for the trail}
- `DataExplorer.cls`: `public static Result explore(String question, Id contextRecordId, String historyJson)`. The loop: each turn the model returns exactly one JSON object, either {"action":"query","plan":{...}} or {"action":"answer","text":"...","followups":[...]}. Caps: 5 turns and 4 queries per question; at the query cap the model is told to answer now. A plan validation error, a QueryException or a non-JSON reply is fed back as `INVALID: <reason>` so the model corrects itself. The model sees a preview of each result (20 rows plus the total). The context record (object, Id, Name) is given as a hint when contextRecordId is set. Result fields, @AuraEnabled: status (OK/EMPTY/ERROR), answer, resultSets, trail (one line per query: object, filters, row count), followups (at most 4)
- Typed drill-down that skips the model: `public static ExploreQuery.ResultSet drill(Id recordId, String relatedObject)` returns the record's catalog fields when relatedObject is blank, or its child rows for a catalog object that has a lookup to it (resolved by describe, not by the caller's text), under the same caps and user mode
- Prompt as text: static resource `AgentPrompt_Explore` (system and user parts) holding the JSON contract, the rules (use only catalog names; one object per query; answer only from returned rows; say so when the data doesn't answer the question; no record ids in prose) and placeholders for catalog, context, history and question. No prompt wording in Apex
- No DML anywhere in the explore path. Any model failure gives status ERROR with answer `I couldn't finish that right now. Try again in a minute.` and whatever result sets were already read
- `ExploreAction.cls` has one @InvocableMethod (label 'Explore Data'): inputs question (required) and contextRecordId; outputs status and answer (the text plus a compact plain-text table of the last result set, with the whole output kept under 6,000 characters)
- Tests use the AgentLlm stub with scripted replies, no SeeAllData: a one-query answer; a two-query chain; an invalid plan corrected on the next turn; the query cap forcing an answer; an object outside the catalog rejected; a value containing a quote and SOQL keywords is bound, not injected (assert it returns no rows and does not throw); limit clamping; aggregate with and without groupBy; drill by record and by related object; a user without access to an object (System.runAs a minimal-access user) gets it dropped from the catalog. Each new class is at least 90% covered
- docs/ARCHITECTURE.md gains an 'Explore' section (30 lines or fewer): the loop, the plan shape, the guards, and how to add an object to the catalog
- Both gates pass: test and org. Quote the `validate-org:` line. No real deploy

## Review

Independent review at 0de500a: 35 confirmed, 0 refuted, 4 unverifiable. Every piece ExploreQuery.build concatenates into SOQL traces to a describe-derived catalog name, a fixed token list, a parsed Integer or a locally made alias; all values are typed binds. Unverified: per-class coverage at the final sha (measured one commit earlier, before a test-only fix).
