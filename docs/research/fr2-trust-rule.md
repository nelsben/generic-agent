# FR2 trust rule as a test: sharing, explicit access modes and named system context (BE-37)

- Covers FR2 ledger row F87 in [feature-revision-2.md](../plans/feature-revision-2.md) and the explicit-mode
  half of N11 in [apex-review-2.md](../reviews/apex-review-2.md). The rule is principle 5 in
  [fr2-design.md](../plans/fr2-design.md).
- The check is `tests/test_trust_rule.py`. It runs with the rest of `python3 -m unittest discover -s tests`, so no
  later card can add a system-context use without naming it.

## The rule

- Every top-level non-test class is `with sharing`.
- Every inline query has `WITH USER_MODE` or `WITH SYSTEM_MODE`.
- Every `Database.query`, `queryWithBinds`, `countQuery`, `countQueryWithBinds` and `getQueryLocator` call passes an
  `AccessLevel`.
- Every DML statement has `as user` or `as system`. Every `Database.insert`, `update`, `upsert`, `delete`,
  `undelete` and `merge` call passes an `AccessLevel`.
- Anything in system mode (a `WITH SYSTEM_MODE` query, `AccessLevel.SYSTEM_MODE`, `as system`, or a top-level class
  that is not `with sharing`) sits under a marker.
- A marker that covers no system-mode use fails too, so this page and the markers stay the same list.

## The marker

A comment on the line above the class declaration, the statement or the method that holds the use (annotations may
sit between the marker and the declaration):

```
// system-context: <why the user's own access is not enough, at least five words>
```

A marker above a class covers the whole class, above a method the whole method, above a statement that statement
(to its closing semicolon). The test fails, naming file and line, when the reason is shorter than five words.

## Every marker today

Checked against `grep -rn 'system-context' force-app/main/default/classes` on 2026-11-15 (OPS-66). The grep also finds one marker in a test class (`CustomerSummaryContextTest`), which is test setup and not product code.

| Class | Member | Reason in the code |
| --- | --- | --- |
| `AgentLlm` | `querySettings`, the `Agent_Prompt_Setting__mdt` query (BE-33) | the product's own prompt configuration, the same for every user; reps hold no read access to the type |
| `CustomerSummaryMemory` | `write` (two inserts, the update, the racing-rows insert) | the product's own session rows, written for the running user; reps have no write access to the object |
| `CustomerSummaryMemory` | `purgeOverflow` (the query and the delete) | deletes the running user's own old session rows; reps have no delete access to the object |
| `CustomerSummaryMemory` | `recentRows` | reads the running user's own session rows; history() re-checks the account in user mode first |
| `CustomerSummaryMemory` | `findRows` | reads the running user's own session rows; Customer_Summary_Data_Access grants reps read, and system context scopes the rows to the running user's own sessions |
| `CustomerSummaryMemory` | `findRowsForUpdate` | locks the running user's own session rows for a write; reps have no write access to the object, so the lock runs in system context |
| `CustomerOutcomes` | `writeText` | reps hold no field access to outcome text (F79); set only on rows just inserted as this user |
| `CustomerOutcomes` | `deleteOwn` | reps hold no delete on outcomes; the caller has already checked the user is the author |
| `CustomerOutcomes` | `readText` | reps hold no field access to outcome text (F79); read only for rows view() shows in full |
| `CustomerOutcomeRetentionBatch` | the whole class | the purge deletes every expired outcome, whoever wrote it, and no rep can see them all |

Every memory read is filtered to the running user's session key, so a user only reads and writes their own rows
(unchanged from before; see N-notes on memory in apex-review-2.md).

## Statements whose mode changed

One. No behaviour changed for the memory class, which was already explicit in system mode; it only gained markers.

| Statement | Before | After | Why |
| --- | --- | --- | --- |
| `AgentLlm.loadPrompt`, the `StaticResource` query | implicit mode (no `WITH` clause) | `WITH SYSTEM_MODE`, with a marker | The prompt is the product's own file, read the same way for every user. Naming the mode keeps the behaviour and closes N11 for this query. |

BE-33 moved the `StaticResource` query in `AgentLlm.loadPrompt` on to `WITH USER_MODE` and removed its marker:
a rep who holds only the user group can read static resources in user mode. See
[fr2-model-door.md](fr2-model-door.md#prompt-files-for-reps-n11).

No CRM read or write moved to user mode in this card: every query and call on CRM objects already used
`WITH USER_MODE` or `AccessLevel.USER_MODE`.

## The agent-definition query (N11, second half)

The `BotDefinition` query that apex-review-2.md names in the old `AccountBriefPanelController` is not in any
current class, so it needs no marker. FE-20 is not required for it.

## Adding an exception in a later card

1. Write the system-context use in the smallest unit that holds it (a statement, else a method).
2. Put `// system-context: <reason>` directly above it. The reason says why the user's own access is not enough, in
   at least five words.
3. Add a test proving the guard around it, for example that the rows are filtered to the running user, or that the
   input is validated, in the class's own Apex test. The marker only names the exception; the Apex test proves it is
   safe.
4. Add a row to the table above. OPS-45 builds its list of exceptions from this table and the markers.

A `without sharing` or `inherited sharing` top-level class is the same: the marker goes above the class.

## Notes

- The old `AccountBrief*` classes still deployed in agent-probe compile against these classes. No signature or
  interface method changed.
- The parser is tested on small inline Apex samples (`TestRules` in `tests/test_trust_rule.py`): one for each rule,
  for the marker's reach, and for the five-word reason.
- Not covered: SOSL (`[FIND ...]`) and `Search.query`. No class uses them today.

## Org run (agent-probe, standing approval)

- `sf project deploy validate --source-dir force-app --test-level RunLocalTests -o agent-probe`: **succeeded**, 62 of
  62 components, 251 of 251 Apex tests, 0 failures. No failure in any old `AccountBrief*` class.
- `CONFIRM_PROD=1 sf project deploy quick --job-id <that validate> -o agent-probe`: **succeeded**, 62 of 62
  components. No agent was published or activated. `experimental` was not touched.
- `bash scripts/validate-org.sh`: pass (61 components, 158 of our own tests).

## Undo

Not recorded on this page. The work deployed to `agent-probe` or ran there, but the page lists nothing to remove.
