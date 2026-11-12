---
id: BE-3
title: Deals: open deals with who's involved, and closed deal history
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/classes/AccountBriefOpenDealsSection.cls, force-app/main/default/classes/AccountBriefOpenDealsSection.cls-meta.xml, force-app/main/default/classes/AccountBriefOpenDealsSectionTest.cls, force-app/main/default/classes/AccountBriefOpenDealsSectionTest.cls-meta.xml, force-app/main/default/classes/AccountBriefDealHistorySection.cls, force-app/main/default/classes/AccountBriefDealHistorySection.cls-meta.xml, force-app/main/default/classes/AccountBriefDealHistorySectionTest.cls, force-app/main/default/classes/AccountBriefDealHistorySectionTest.cls-meta.xml]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/AccountBriefSection.cls, force-app/main/default/classes/AccountBriefResolver*]
red_test: bash scripts/validate-org.sh (the lane's section test classes are absent before; they pass after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

The gather step builds each section of the brief deterministically, in Apex with no LLM. Each section is capped so the final answer stays well under the ~6K-char relay ceiling, where the agent silently compresses output. Prompt templates later turn these blocks into prose, so every fact must be right here. The architecture reference is local and confidential; restate its patterns and never copy its client names: <repo>/reference/agent-landscape-guide/guide.md. Read sections 2.4, 2.5, 5.1, 6.3 and 7.2. In this org, recorded calls are Event records (AccountId set, call notes in Description), and logged emails and calls are Tasks (TaskSubtype Email or Call).

## Done when

- Every class is `public with sharing`, has a header comment that includes `Read-only: no DML.`, uses apiVersion 68.0 meta, and exposes `public static AccountBriefSection build(Id accountId)` built on the AccountBriefSection DTO already in force-app/main/default/classes (fields key, title, status OK/EMPTY/ERROR, body, total, shown, plus the clip() and fmtDate() helpers). Read that file first and do not modify it
- build() never throws: any exception returns status ERROR with body `Couldn't load <title> right now.` A section with no rows returns status EMPTY, a one-sentence body, total 0 and shown 0
- Bodies are plain text: one fact per line, `- ` bullets, `n/a` for missing values, no markdown headers and no JSON. Each body is at most 1,200 characters (enforce it with clip on long fields and with row caps). Queries are bulk (no SOQL inside loops) and use bind variables
- Each class has its own *Test class (no SeeAllData) that creates the data it needs. Tests cover: OK with more rows than the cap (asserts shown == cap and total > cap), EMPTY, and the ordering rule. Assert exact body lines where it is practical
- Both gates pass: `test` and `org` (check-only deploy plus your test classes in the experimental org). Quote the `validate-org:` line in the hand-back
- AccountBriefOpenDealsSection (key `open_deals`, title `Open deals`): open Opportunities (IsClosed = false) on the account ordered by CloseDate ASC NULLS LAST, capped at 5. Line format: `- <Name> — <StageName> — <Amount as currency with no decimals, or 'no amount'> — closes <fmtDate(CloseDate)><' (OVERDUE)' when CloseDate < today> — owner <Owner.Name>`, followed by up to 3 indented ` • <Contact.Name> (<Role or 'no role'>)` lines from OpportunityContactRole, primary first. First line of the body: `<total> open, <sum of Amount> total pipeline, <n> overdue`
- AccountBriefDealHistorySection (key `deal_history`, title `Deal history`): closed Opportunities ordered by CloseDate DESC, capped at 5. Line format: `- <Name> — <Won|Lost> — <Amount or 'no amount'> — closed <date>`. First line: `<won> won / <lost> lost all-time, win rate <pct>%, average won deal <currency>` (use n/a when there are no won deals)

## Review

Brain review: aggregate totals and overdue are counted over all open deals, the rows are capped at 5 with OCR contacts bulk-queried, and the body is budgeted under 1,200 characters. Accepted the money helper being duplicated in both classes. Gate line: validate-org: pass (7 components, 17 tests).
