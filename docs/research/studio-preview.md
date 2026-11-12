# Studio preview of the merged Account_Brief agent (OPS-15)

- Date: 2026-11-11
- Org: `experimental` (Developer Edition), Agentforce Builder, Account Brief, Version 2 (Draft)
- Script: `force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent`, sha256 prefix `fb0fc27d` (identical to origin/main at 8ceccc3, checked before pasting)
- Writes made in the org: one Save of the existing draft. No Commit Version, Publish, Activate, Deactivate or delete; no new agent or version.

## Studio validation

Saved to Version 2 (Draft): "Your changes were saved." Studio's Problems panel: 0 errors, 1 warning, 0 info.

- Warning (line 1): `The action resolve_account is missing the input parameters: knownAccountId`

The script was pasted through the editor's clipboard path and its hash was checked in the page before pasting. I could not byte-compare the editor content after the paste, so "exact bytes" rests on the pre-paste hash only.

## Live preview results

Each row is one Studio Live Test conversation unless noted. Every turn entered `agent_router` first and then transitioned to the subagent shown. Ids are shortened to `<id..last6>`.

| # | Utterance | Subagent | Actions (inputs) | Reply excerpt | Result |
|---|-----------|----------|------------------|---------------|--------|
| 1 | Give me a brief on Edge Communications | account_brief | resolve_account (accountName "Edge Communications") -> RESOLVED `<id..9BFQAZ>`; get_brief (userQuestion, accountId `<id..9BFQAZ>`) | Edge Communications shows zero engagement for 90 days while a $35,000 deal sits overdue and two senior contacts have gone silent. | pass |
| 2 | What is going on with Edge Communications, and which deals are slipping? | account_brief | resolve_account; get_brief (userQuestion is the full message, accountId `<id..9BFQAZ>`) | Edge Communications shows zero engagement across all contacts while a $35,000 deal sits overdue. (reply equals get_brief answer) | pass |
| 3 | Brief me on Zzqxv Nonexistent Holdings | account_brief | resolve_account only -> NOT_FOUND | No account matches "Zzqxv Nonexistent Holdings". Try the full name or open the account and ask again. | pass |
| 4 | Brief me on 001000000000000AAA | account_brief | resolve_account only (accountName "001000000000000AAA") -> NOT_FOUND | No account matches "001000000000000AAA". Try the full name or open the account and ask again. | pass |
| 5 | Brief me on United Oil | account_brief | resolve_account only -> AMBIGUOUS | Several accounts match "United Oil". Which one? then three lines: United Oil & Gas Corp. — New York — `<id..9BKQAZ>`; United Oil & Gas, Singapore — Singapore — `<id..9BOQAZ>`; United Oil & Gas, UK — no city — `<id..9BNQAZ>` (reply equals resolver message) | pass |
| 6 | Just the open deals for Edge Communications | account_brief | resolve_account; get_brief (include "open_deals", accountId `<id..9BFQAZ>`) | Edge Communications has one overdue deal worth $35,000 that requires immediate attention. Account section "EMPTY: not requested". | pass |
| 7 | (after "Give me a brief on Edge Communications") What about their open cases? | account_brief | get_brief only (include "cases", accountId `<id..9BFQAZ>` from the stored variable); no resolve_account, no explore_data | No open cases to report; zero high-priority issues and no cases closed in the past 90 days. | pass |
| 8 | (after Edge brief, then "Brief me on Zzqxv Nonexistent Holdings") Show me their open cases | account_brief | resolve_account (accountName "Zzqxv Nonexistent Holdings") -> NOT_FOUND; no get_brief | No account matches "Zzqxv Nonexistent Holdings". Try the full name or open the account and ask again. | pass |
| 9 | (after Edge brief) How many open opportunities are there in the whole org? | explore | explore_data (question equals the message) | There are 36 open opportunities in the whole org. ... COUNT(Id) 36 (reply equals explore_data answer) | pass |
| 10 | How many open opportunities are there? | explore | explore_data (question equals the message) | There are 36 open opportunities in the system. ... COUNT(Id) 36 (reply equals answer) | pass |
| 11 | List the five largest open opportunities | explore | explore_data (question equals the message) | Here are the five largest open opportunities: 1. Coveline Industries Brands — Services Migration: $1,489,000 ... | pass, with a relay note below |
| 12 | What is the weather in Paris today? | agent_router (no subagent) | none | I can brief you on an account or answer questions about your CRM data. (exactly the spec line) | pass |

Notes:

- Case 11 relay: the reply is not byte-identical to explore_data's answer. The reply has 41 lines against 36, and two column headers in the answer's table (`Account.Name`, `Owner.Name`) appear in the reply as `URL_Redacted` tokens. The five opportunities and amounts are all present. The spec only asks the reply to list the largest open opportunities, so I count it a pass, but "verbatim relay" does not hold for this reply. The cause is not established (a Studio preview redaction of dotted names, or the model rewriting the table); I did not investigate.
- Cases 7 to 9 were built as the spec's `conversationHistory` implies: the first turn was a real preview turn, so the stored variables were set. Case 8's NOT_FOUND turn ran in the same conversation as the Edge brief.
- Case 1 was the first conversation after saving; every other case began with the preview's reset button.
- Replies were read from the trace's PlannerResponseStep; the chat pane agreed with them where I looked (case 1).

## Answers

(a) Does explore_data's `question` input equal the user's message word for word? Yes. In cases 9, 10 and 11 the input `question` was string-equal to the typed message.

(b) Is explore's before_reasoning run of explore_data shown as an action? Yes. In the trace it is a FunctionStep named `explore_data` with its input and output, so the spec's `expectedActions: explore_data` is satisfiable. The reply was the action's `answer` in cases 9 and 10.

(c) On a new turn, does the conversation re-enter the router or stay in the subagent that answered before? It re-enters `agent_router` every turn. In case 7 turn 2 and case 8 turn 3 the trace shows NodeEntry `agent_router`, then a transition Router -> account_brief, then NodeEntry `account_brief`. Case 9's second turn went Router -> explore, so a follow-up can change subagents.

NOT_FOUND then a follow-up ("Show me their open cases", case 8): the agent relays NOT_FOUND again. It calls resolve_account again with the not-found name "Zzqxv Nonexistent Holdings", gets NOT_FOUND and relays the resolver message. It does not call get_brief and does not fall back to Edge Communications. Stored-id path (case 7): with no NOT_FOUND in between, the follow-up calls get_brief directly with the stored account Id and no resolve_account.

## Verdict

Not fully clean, but no routing failure: Studio accepts the script with 0 errors and one warning (`resolve_account` missing input `knownAccountId`), and all 12 spec utterances behave as the spec expects; the only deviations are that warning and the case 11 reply not being a byte-for-byte relay of the explorer's answer.
