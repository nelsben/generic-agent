# Trust by design

The assistant sees only what the rep sees, and when something fails the rep reads one plain sentence. This is
principle 5, told once here and shown in each chapter.

## Why you can trust it

Runs as the signed-in user: every class is `with sharing`, and every read or write of CRM data names user mode
(`WITH USER_MODE` or `AccessLevel.USER_MODE`), so the rep's object, field and record access all apply.

System context: only for the product's own records, each named in the code with a `// system-context:` marker and its
reason, and each listed below. [test_trust_rule.py](../../tests/test_trust_rule.py) fails a build that adds a system
use with no marker, or a marker with no system use.

## The exceptions

| What | Why | The guard | The test |
| --- | --- | --- | --- |
| Prompt settings, `AgentLlm` (`Agent_Prompt_Setting__mdt`) | The product's own configuration, the same for every user; reps hold no read access | Read only; one record per prompt, no user input in the query | `AgentLlmTest` `aRepWithTheUserGroupsDataSetReadsPromptFilesAndSettings` |
| Session rows, `CustomerSummaryMemory` (write, trim, find, lock) | Reps hold no write, delete or lock access to the session object | Every row is keyed to the running user; history re-checks the account in user mode first | `CustomerSummaryMemoryTest` `twoUsersGetSeparateRows`, `theCapNeverPurgesAnotherUsersRows` |
| Outcome text, `CustomerOutcomes` (set on insert, read, delete) | Reps hold no field access to outcome text, so no list view, report or API shows it | Set only on rows just inserted by this user; read only for rows shown in full (the author, or a type marked to share); delete only after the author check | `CustomerOutcomesTest` `noRepGetsTheTextFromAUserModeQuery`, `anotherRepSeesTypeDatePhraseAndLabelButNoText`, `anAuthorRemovesTheirOwnOutcome` |
| Expiry purge, `CustomerOutcomeRetentionBatch` | The purge removes every expired outcome, whoever wrote it, and no rep can see them all | Deletes only rows past their type's retention | `CustomerOutcomesTest` `theBatchDeletesOnlyExpiredOutcomes` |

The same list, with each reason as written in the code, is in [fr2-trust-rule.md](../research/fr2-trust-rule.md).

## Failures

Each failure is shown where it happens, as one fixed sentence that says what to do next. No raw error text reaches the
rep.

- Not found, a choice of accounts, and a section that cannot load: [pattern 01](01-route-gather-reduce.md#when-something-fails).
- The panel's fixed sentences for any failed call, and markup shown as plain text: [pattern 03](03-hotkey-panel.md).

## Adopt it

Grant access in one step: assign the permission set group `Customer_Summary_User`. Assign the group, not the sets one
by one. What each set grants, for a builder:

| Set | Grants |
| --- | --- |
| `Customer_Summary_Data_Access` (in the group) | The Customer Summary app, the entry-point classes, the brand settings, and read-only access to the session object |
| `Customer_Summary_Outcome_Access` (in the group) | Read on Account (the outcome object needs it), create and read on outcomes; no access to outcome text fields |
| `Customer_Summary_Agent_Access` (not in the group) | The Customer Summary agent and nothing else; only for the optional agent in [pattern 06](06-agent-routing-and-verbatim-relay.md) |

Add a class to `Customer_Summary_Data_Access` only when it becomes an entry point, and update
[test_permission_sets.py](../../tests/test_permission_sets.py) in the same change.

## Limits and open items

- A rep's run with only the group: see the Status table in the [README](../../README.md#status).
- A section that failed for a missing field, and every resolver query error reading as not found, are closed (BE-29).
- Reading the prompt files in user mode is closed (BE-33), and the agent-definition query is gone (FE-20).
- A number in a brief line that looks like a record Id no longer becomes a drill button (FE-12).
- Whether the Models API call needs anything extra for a rep: no card yet.

[Back to the pattern index](README.md) | [Back to the architecture page](../ARCHITECTURE.md) | [Back to the README](../../README.md)
