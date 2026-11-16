# FR2: conversation history (BE-26)

- Date: 2026-11-13. Org `agent-probe` only; every `sf` command named it.
- Ledger rows: F19 (history), F32 (who sees it), F78 (reusable past outcomes, the conversation half) and F80
  (pattern 05's limits rechecked) in [feature-revision-2.md](../plans/feature-revision-2.md). Principle 5 (F87) in
  [fr2-design.md](../plans/fr2-design.md). OPS-43 rewrites [pattern 05](../patterns/05-conversation-memory.md)
  from this page.
- Read first: [fr2-agent-memory.md](fr2-agent-memory.md) (BE-34). This card follows its recommendation: keep our
  own conversation history, and lean on nothing in the platform's Agent Memory, which never reaches the panel, the
  rail or MCP. Where it differs: nowhere in substance. BE-34 measured that an agent conversation lost its context
  after 30 idle minutes (one sample); our own session timeout is also 30 minutes, chosen on its own merits (a rep
  who comes back after a meeting starts a new conversation), not to match the agent.
- Customer outcomes that outlive a conversation (summaries and actions kept against the account) are BE-35's, not
  this page's.

## Plain answer

- **One row is one session**: one rep, one account, a title, a start, a last activity, a turn count and the
  newest 10 turns. Both the summary's and the explorer's turns are kept.
- **A session ends after 30 idle minutes.** The next question about that account starts a new one.
- **Each rep sees only their own sessions** (F32, still open as Q7), and only while they can still read the
  account. A session for an account the rep has lost is hidden, never deleted.
- **Two read methods**, both in user mode: `CustomerSummaryHistory.listSessions(accountId, limitSize)` and
  `CustomerSummaryHistory.getSession(sessionId)`. Writes stay in `CustomerSummaryMemory`, in system context.

## What is stored

`Customer_Summary_Session__c`, extended, not replaced. Three fields are new; the rest were already there.

| Field | Holds | New |
|---|---|---|
| `Account__c`, `User__c`, `OwnerId` | The account and the rep. The row is inserted as the rep, so the rep owns it | no |
| `Title__c` | The session's first question, spaces collapsed, trimmed to 80 characters. A summary asked with no question is titled "Summary" | yes |
| `Started__c` | When the session's first turn was saved | yes |
| `Last_Activity__c` | When its newest turn was saved (the last-active time) | no |
| `Turn_Count__c` | Every turn saved in the session, including turns the ring has since dropped | yes |
| `Turns_JSON__c` | The ring: the session's newest 10 turns, oldest first. Each turn: time, status, question (255 characters), a headline (the answer's first line, 200 characters) and its kind, `summary` or `explorer` | no; `kind` is new in each turn |
| `Brief_Count__c`, `Last_Brief__c`, `Last_Question__c`, `Last_Status__c` | The rep's last brief of the account. Only summaries change them; an explorer answer never replaces the brief | no |
| `Session_Key__c` | The current session: user Id, `_`, account Id. An ended session adds `_` and its own record Id | no; meaning widened |

- **The ring limit is unchanged**: `CustomerSummaryMemory.MAX_TURNS` is 10 turns per session. Headlines are
  `HEADLINE_MAX`, 200 characters. The full answer text is not kept per turn; only the last brief is kept whole
  (up to 32,768 characters), as before.
- **The explorer's turns are kept.** `CustomerSummaryPanelController.explore` saves the turn after the explorer's
  last callout, as `CustomerSummary` does for a brief: only an OK or EMPTY answer, only when the context record
  is an Account, and a failed write is logged while the answer still returns. The agent is not a way in (F83), so
  nothing is recorded from it.
- **The timeout.** `CustomerSummaryMemory.sessionTimeoutMinutes` is 30. A turn that arrives more than 30 minutes
  after the current session's last activity ends that session: its row is re-keyed and keeps its title, start,
  turns and count, and a new row takes the plain key. The new row carries the last brief over, so the rail's
  "last summary" and the explorer's follow-up check still find it.
- **Rows saved before this card** have no title, start or turn count. The next write fills them from the oldest
  kept turn; a turn with no kind reads as a summary.

## For how long

- No time-based expiry. A session stays until the per-rep cap removes it.
- **The cap**: `maxRowsPerUser` is 200 rows per rep, now counted in sessions, not accounts. After a write that
  creates a row, the rep's least recently active rows beyond 200 are deleted. Another rep's rows are never
  touched. A rep who opens many short sessions reaches the cap sooner than before, so the oldest sessions go first.
- An account deleted later leaves its sessions with no account (`SetNull`); they are hidden, and the cap removes
  them in time.

## Who can see it, and why

- **Own-only (F32).** Both methods return only sessions the running user owns. Ben has not answered Q7, so the
  default in the ledger stands: history is stored per rep and per account, and each rep sees only their own.
- **The filter sits in one place**: `CustomerSummaryHistory.visibleOwnerId()`, with a comment naming F32. A later
  brand or permission setting can widen history there and nowhere else.
- **Why a filter on top of sharing.** The object is Private, but sharing alone is not own-only: a manual share or
  the role hierarchy can open a rep's row to someone else. The test shares one rep's row with a second rep, shows
  the second rep can read it in user mode, and shows neither method returns it.
- **Reps have read-only access** to the object and its fields through `Customer_Summary_Data_Access`, which also
  grants `CustomerSummaryHistory`. They cannot create, edit or delete rows, so every write runs in system context.
  Each system-context use in `CustomerSummaryMemory` carries its `// system-context:` reason (BE-37, F87):
  the locked read, the writes, the cap's delete, and the reads behind `history()` and `lastBrief()`, always for the
  running user's own rows.
- **Still open from N6**: the Read grant and `enableReports` let a rep build a report on their own rows, and an
  admin with View All Data can read anyone's. That is unchanged by this card.

## The access re-check (N6)

- `listSessions`, `getSession` and `CustomerSummaryMemory.history()` (the panel's earlier summaries) each check,
  in user mode, that the running user can read the session's account right now. No read access to Account at all
  hides every session. A session whose account is unreadable, or gone, is hidden, never deleted: it comes back if
  access does.
- The rail's last summary (`CustomerSummaryContext`) already returns nothing for an account the user cannot read.
- `lastBrief()` is not exposed to a rep; the explorer uses it only to compare against the conversation the panel
  sent, and then builds its lines in user mode.

## Governor cost

| Call | SOQL | DML | Heap |
|---|---|---|---|
| `listSessions` | 2: the account check and the sessions (at most 50 rows, no turns) | 0 | small |
| `getSession` | 2: the session and the account check | 0 | one `Turns_JSON__c` (10 turns, a few KB) |
| `history` | 2: the account check and the rep's newest 10 sessions of the account | 0 | up to 10 `Turns_JSON__c` values |
| A memory write (a brief, or an explorer turn) | 1 locked read, plus 1 for the cap when a row is created | at most 3: re-key ended sessions, insert new ones, update the rest; plus the cap's delete when it applies | the rows written |

- An explorer question now ends with that memory write, after its last callout. A DUPLICATE_VALUE race redoes
  the write once, as before.
- Every listing is bounded: at most 50 sessions, never their turns.

## Limits and open items

- **The rail's last-summary date can move.** `CustomerSummaryContext` (outside this card) dates the last summary
  by `Last_Activity__c`, which an explorer turn now also moves, and which a new session resets while carrying
  the brief over. The text stays right; the date can be later than the brief. The fix is a dedicated
  last-brief time read by that class; it is handed back as an amend for a later card.
- **Q7 / F32 stays open**: who may see another rep's history. Until Ben answers, own-only.
- A lock timeout on the memory write still drops that one turn; the answer itself still returns.
- An overtaken brief is still stored (panel re-review N6), as pattern 05 says.

## Tests

- [CustomerSummaryHistoryTest](../../force-app/main/default/classes/CustomerSummaryHistoryTest.cls): listing
  order and the default limit, a limit of 3, the cap at 50 and a limit below 1; an account with no sessions; the
  own-only filter with a second rep who can read the first rep's row through a share; reopening a session with its
  turns in order and its 80-character title; an explorer turn from the panel recorded and returned, with the brief
  fields untouched; a session hidden, not deleted, once its account is no longer readable; and the timeout
  starting a new session while the earlier one keeps its title and turns.
- [CustomerSummaryMemoryTest](../../force-app/main/default/classes/CustomerSummaryMemoryTest.cls): a row saved
  before this card filled from its turns; `history()` listing only summaries, across sessions.
- [CustomerSummaryPanelControllerTest](../../force-app/main/default/classes/CustomerSummaryPanelControllerTest.cls):
  a failed explorer answer, and an answer about a non-account record, start no session.
- `tests/test_permission_sets.py`: the new class is granted, and every field the history door reads is readable
  and not editable.

## Undo

Not recorded on this page. The work deployed to `agent-probe` or ran there, but the page lists nothing to remove.
