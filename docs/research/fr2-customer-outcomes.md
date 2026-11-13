# FR2: customer outcomes (BE-35)

- Date: 2026-11-13. Org `agent-probe` only; every `sf` command named it.
- Ledger rows: F75, F76, F78 and F80 in [feature-revision-2.md](../plans/feature-revision-2.md), with F79 (what
  others see) and principle 5 (F87, field access) from [fr2-design.md](../plans/fr2-design.md). Closes N6 (memory
  outlives access) in [apex-review-2.md](../reviews/apex-review-2.md).
- Read first: [fr2-agent-memory.md](fr2-agent-memory.md) (BE-34). This card follows its recommendation: keep our own
  store of outcomes against the account, because neither Agent Memory nor Data 360's agentic memory keys anything
  to an account, keeps it per type, or reaches the panel, the rail or MCP. Where it differs: nowhere in substance;
  this card adds a second permission set (see [Field access](#field-access)).
- The conversation history is BE-26's ([fr2-conversation-history.md](fr2-conversation-history.md)). Sentiment is
  BE-36's: this card stores its score, label and reason, and BE-36 fills them.

## Plain answer

- **One row is one outcome**: a summary, an action taken or a saved answer, kept against its account in
  `Customer_Outcome__c`. Nothing on it is specific to one agent or one session.
- **Sharing follows the account.** The account is the outcome's master, so a rep who can read the account sees its
  outcomes, and a rep who loses the account loses them (N6).
- **What others see (F79).** The author sees everything. Anyone else who can see the account sees the type, the
  date, a fixed phrase for the kind of outcome ("Task created", never the task's subject) and the sentiment label.
  Our surfaces never show them the title, headline, body, record link or sentiment reason, unless the type's custom
  metadata record is marked to share its text. The title, headline, body and reason are also closed to them
  everywhere else; the record link is a plain field the outcome set can read (see [Field access](#field-access)). That is off for all three types as shipped; Ben decides per type.
- **Retention by type.** Summaries are kept forever; actions and saved answers for two years. A batch deletes
  expired outcomes. It is scheduled by a script that was **not** run in agent-probe (its Approvals row is not
  approved).
- **Reuse.** Every new summary and every explorer question about an open account gets a short outcome context: the
  last summary's headline and date, then the last few other outcomes. The panel, the rail and both MCP tools get it
  with no change to a door.

## Design

| Piece | What it is |
|---|---|
| `Customer_Outcome__c` | Auto-numbered (`CO-000001`), master-detail to Account (`Account__c`, child relationship `Customer_Outcomes`), sharing controlled by parent, reports on |
| Fields | `Outcome_Type__c` (the type's DeveloperName), `Title__c`, `Headline__c`, `Body__c` (long text, 32,768), `Related_Record_Id__c` (an Id as text, 18), `Skill__c`, `Surface__c`, `Model__c`, `Sentiment_Score__c` (5,2), `Sentiment_Label__c`, `Sentiment_Reason__c`, `Expires__c` (date; blank is forever) |
| `Customer_Outcome_Type__mdt` | `Retention_Days__c` (blank is forever) and `Share_Text__c` (off by default). Records: `Summary` (forever), `Action` (730 days), `Saved_Answer`, labelled "Saved answer" (730 days) |
| `CustomerOutcomes` | `record(Input)` and `recordAll(List<Input>)`, `remove(outcomeId)`, `listOutcomes(accountId, types, limitSize)` (cacheable), `getOutcome(outcomeId)`, `contextFor(accountId)`, and `view()`, the one place the F79 rule lives |
| `CustomerOutcomeSaveAnswer` | Invocable "Save Answer": an account, an optional title and the answer. It writes a Saved answer and nothing else, and takes no sentiment fields. It is for a team's own agent or flow; it is not an MCP tool in FR2 |
| `CustomerOutcomeRetentionBatch` | Batch and Schedulable, `without sharing` under a `// system-context:` marker, because the purge must see every rep's outcomes. Deletes rows with `Expires__c` before today |
| `scripts/schedule-outcome-retention.apex` | Schedules the batch daily at 02:30 if it is not already scheduled. Not run in agent-probe |
| Report type "Customer Outcomes with Account" | Base object `Customer_Outcome__c`; columns for the type, skill, surface, model, sentiment score and label, expiry, created date and by, the account's name and owner. It leaves out the title, headline, body, sentiment reason and record link |

**The type** is matched by DeveloperName or label, so a caller may say `Saved_Answer` or "saved answer". A type
with no record is refused, and new types need only a new custom metadata record.

**Surface** is filled from the request's origin when the caller leaves it blank. Lightning (the panel) is `panel`,
an invocable action (the MCP tools and the agent) is `action`, REST or SOAP is `api`, anonymous Apex is `script`
and a test run is `test`.

**The summary write.** `CustomerSummary` collects one Summary input per brief (the title is the rep's question, or
"Summary"; the body is the answer; the headline is its first line). It records them in one `recordAll` call at the
end, after every model call and after the memory write, in its own try and catch. A failed write is logged and the
summary still returns. An EMPTY brief (an account with no activity) is recorded too, because the rep did ask; an
error is not.

### What writeRequiresMasterRead means

On a master-detail field, `writeRequiresMasterRead` sets the sharing access needed on the master record to create,
edit or delete the detail. With `true`, **Read** access to the account is enough; with `false`, the default, a user
needs **Read/Write** on the account. The Setup label is "Sharing Setting: Read Only" against "Read/Write".

The reason here is that a rep who can only read an account still asks for its summary, and the summary must still
be recorded. The test `aReadOnlyRepStillHasTheirOutcomeRecorded` writes one as a rep whose only Account permission is
Read, and so does `CustomerSummaryTest.aReadOnlyRepsSummaryIsStillRecorded` through a whole summary. agent-probe's
account sharing is Public Read/Write, so in this org the setting matters only for an org with tighter sharing.

### Field access

Principle 5 (F87): reps hold **no** field access to the title, headline, body or sentiment reason. The rule on
what others see then cannot be bypassed through a list view, the record page, a report or the API.
`CustomerOutcomes` writes those four fields, and reads them only for rows `view()` shows in full, in system context
under `// system-context:` markers. Every other field, and the row itself, is read and written in user mode, so
the platform still checks the account. The test `noRepGetsTheTextFromAUserModeQuery` shows that neither the author
nor another rep can read any of the four fields in a user-mode query.

**So the text shows only in our surfaces, even to its author.** An author who opens an outcome on the record page,
or in a report, sees no title, headline, body or reason; the panel and the outcome context show them.

**A second permission set.** The platform refuses Read on a master-detail child unless the same permission set
grants Read on the master (Account). The data-access set grants no Account access, and adding it there broke
BE-26's test of a rep who loses the account. So the outcome access lives in its own set,
`Customer_Summary_Outcome_Access`: Read on Account, Read and Create on `Customer_Outcome__c`, and read and edit on
the eight non-text fields. It grants no edit, no delete, no View All and no class. One of those eight is
`Related_Record_Id__c`: our surfaces and the report type withhold it from anyone but the author, but a rep with
the set can read it through the API, a list view or the record page. The card closes only the four text fields;
closing the link too would mean moving it into system context like them. The data-access set gains class
access to `CustomerOutcomes` and `CustomerOutcomeSaveAnswer` only.

Reps need both sets. A rep with only the data-access set still gets every summary, with no outcome context and no
outcome recorded, and the failed write is logged (`aRepWithoutTheOutcomeSetStillGetsTheSummary`). Adding the
outcome set to the product's permission set group is a follow-up for the card that owns the group. Admins without
the set are in the same position, because new fields come with no field access for any profile.

**Remove.** `remove(outcomeId)` reads the row in user mode, refuses anyone but its author, then deletes in system
context, because reps hold no Delete. It is for BE-27's undo, and is not exposed to Lightning.

### The outcome context

```
Earlier outcomes on this account, newest first (yours with their headline, others by type and date only):
- Summary, 2026-11-13: Renewal on track.
- Action, 2026-11-12: Task created: Call Dana about the renewal
- Saved answer, 2026-11-10
```

- The last summary, then up to 3 other outcomes, one line each, at most 160 characters a line and 900 in all
  (`theContextIsCapped`).
- A line carries a headline only when `view()` would show its text: the rep's own outcome, or a type marked to
  share. Anyone else's outcome adds only its type and date, so one rep's headline never reaches another rep's
  model prompt (`oneRepsHeadlineNeverReachesAnotherRepsContext`). The body is never in the context.
- `CustomerSummary` adds it to the synthesis prompt's system text, after the brand lines, so a new summary can say
  what changed since the last one. `DataExplorer` adds it to the explore prompt's `{{context}}` value when the
  open record is an account.

### Storage per outcome

Salesforce counts about 2 KB of data storage for most custom object rows, whatever their content. So an outcome
costs about 2 KB: 1,000 summaries a month is about 2 MB a month, kept forever. An action or saved answer costs the
same for its two years. The 32,768-character body does not change the count.

### Governor cost

Only the DML count is asserted by a test; the SOQL counts are read from the code.

| Path | SOQL | DML statements |
|---|---|---|
| A summary's outcome context (`CustomerSummary`, the account already read) | 2, plus 1 when any line is the rep's own | 0 |
| The summary write, once per invocation, however many briefs | 0 (the types come from custom metadata, no query) | 3: a savepoint, the insert, the text update |
| The explorer's outcome context | 3, plus 1 when any line is the rep's own | 0 |
| `listOutcomes` / `getOutcome` | 2 or 3 / 2 or 3 | 0 |

Asserted in `threeRequestsMakeNoModelCallAfterDml`: three briefs in one invocation make 4 DML statements, the
memory upsert and the one outcome write. Every model call still runs before any DML.

## Proof that the MCP path receives the context

The explorer is approved as an MCP tool (the Approvals row "FR2: the explorer as an MCP tool for outside
clients"). The MCP door's two tools map to Apex invocables (see [mcp-door-runbook.md](mcp-door-runbook.md)):
`get_account_summary` to `CustomerSummaryGetAction`, and `ask_anything` to `ExploreAction`. The context is built
inside the shared services those actions call, so the door needed no change. Two tests prove it through the
actions themselves:

- `CustomerSummaryTest.aNewSummaryThroughTheActionSeesTheLastSummarysHeadlineAndDate`: a second summary through
  `CustomerSummaryGetAction` has `- Summary, <today>: Headline finding.` in its synthesis system text, and not the
  body.
- `DataExplorerTest.theActionSeesTheOpenAccountsOutcomeContext`: a question through `ExploreAction` with an
  account open has the context header and the last summary's headline in its prompt, and not the body.

No MCP client was signed in for this card, so the proof is these tests, not a live MCP call.

**Follow-up:** a separate MCP tool to list an account's outcomes is not in FR2.

## Live check

Under the approved row "FR2: live checks in `agent-probe`", after the validate (RunLocalTests, 408 tests, 0
failures) and quick deploy of this card's components only. The account was the seed account Edge Communications.
Each step was a separate anonymous Apex run, as the developer user, printing types and counts only.

- **Setup:** the developer user was given `Customer_Summary_Outcome_Access`. Its permission set group does not
  include the set yet (see [Field access](#field-access)), and without it no outcome is recorded.
- **Before:** 0 outcomes and 2 session rows on the account.
- **Summary 1:** `CustomerSummary.run`, status OK. The outcome context before it was empty.
- **Summary 2:** status OK. The outcome context before it had 2 lines: the header and the last summary.
- **Saved answer:** through the invocable `CustomerOutcomeSaveAnswer.save`; it succeeded.
- **`listOutcomes`:** 3 outcomes, `Summary` 2 and `Saved_Answer` 1, all the running user's own. The context
  after them is 3 lines and 311 characters.
- **After:** 3 outcome rows (2 Summary, 1 Saved answer, surface `script`) and 3 session rows. The run added one
  session with 2 turns, since both summaries fell inside one 30-minute session.

The retention batch was not run or scheduled.

## Tests

`CustomerOutcomesTest` covers each type and its retention, a type with its own retention, unknown types, the batch
(only expired rows, and every rep's rows), the schedule, a read-only rep's write, a rep without the outcome set,
sharing through the account, an author who loses the account, what the author and what others see, a type marked
to share, user-mode queries, remove, the invocable, listing and the context. `CustomerSummaryTest` adds the summary
write and its failure path, a read-only rep, a rep without the outcome set and the MCP proof; `DataExplorerTest`
adds the explorer's context and its MCP proof. The session memory tests are unchanged and pass.

agent-probe's account sharing is Public Read/Write, so no sharing rule can hide an account there. A rep who
"cannot see the account" in these tests is one without Account Read, which is the only way to hide one in this org.
