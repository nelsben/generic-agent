---
id: BE-5
title: Account profile and service health (Cases)
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/classes/AccountBriefProfileSection.cls, force-app/main/default/classes/AccountBriefProfileSection.cls-meta.xml, force-app/main/default/classes/AccountBriefProfileSectionTest.cls, force-app/main/default/classes/AccountBriefProfileSectionTest.cls-meta.xml, force-app/main/default/classes/AccountBriefCasesSection.cls, force-app/main/default/classes/AccountBriefCasesSection.cls-meta.xml, force-app/main/default/classes/AccountBriefCasesSectionTest.cls, force-app/main/default/classes/AccountBriefCasesSectionTest.cls-meta.xml]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/AccountBriefSection.cls, force-app/main/default/classes/AccountBriefResolver*]
red_test: bash scripts/validate-org.sh (the lane's section test classes are absent before; they pass after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

The gather step builds each section of the brief deterministically, in Apex with no LLM. Each section is capped so the final answer stays well under the ~6K-char relay ceiling, where the agent silently compresses output. Prompt templates later turn these blocks into prose, so every fact must be right here. The architecture reference is local and confidential; restate its patterns and never copy its client names: /Users/bennelsen/Documents/generic-agent/reference/agent-landscape-guide/guide.md. Read sections 2.4, 2.5, 5.1, 6.3 and 7.2. In this org, Gong-style calls are Event records (AccountId set, call notes in Description), and logged emails and calls are Tasks (TaskSubtype Email or Call).

## Done when

- Every class is `public with sharing`, has a header comment that includes `Read-only: no DML.`, uses apiVersion 68.0 meta, and exposes `public static AccountBriefSection build(Id accountId)` built on the AccountBriefSection DTO already in force-app/main/default/classes (fields key, title, status OK/EMPTY/ERROR, body, total, shown, plus the clip() and fmtDate() helpers). Read that file first and do not modify it
- build() never throws: any exception returns status ERROR with body `Couldn't load <title> right now.` A section with no rows returns status EMPTY, a one-sentence body, total 0 and shown 0
- Bodies are plain text: one fact per line, `- ` bullets, `n/a` for missing values, no markdown headers and no JSON. Each body is at most 1,200 characters (enforce it with clip on long fields and with row caps). Queries are bulk (no SOQL inside loops) and use bind variables
- Each class has its own *Test class (no SeeAllData) that creates the data it needs. Tests cover: OK with more rows than the cap (asserts shown == cap and total > cap), EMPTY, and the ordering rule. Assert exact body lines where it is practical
- Both gates pass: `test` and `org` (check-only deploy plus your test classes in the experimental org). Quote the `validate-org:` line in the hand-back
- AccountBriefProfileSection (key `profile`, title `Account`): one line each for Name, Type, Industry, Owner (Owner.Name), Parent (Parent.Name), Annual revenue (currency, no decimals), Employees, Location (BillingCity, BillingState, BillingCountry joined, skipping blanks), Website, Account since (fmtDate of CreatedDate), and Description (clip 300), formatted `<Label>: <value or n/a>`. total = 1 and shown = 1. A missing or inaccessible Id returns EMPTY with `Account not found or not visible to you.`
- AccountBriefCasesSection (key `cases`, title `Service health`): first line `<open> open (<high> high priority), <closed90> closed in last 90 days, oldest open <n> days`. Then open Cases (IsClosed = false) ordered by Priority (High, Medium, Low, then other) and CreatedDate ASC, capped at 5, as `- <CaseNumber> — <clip(Subject,100)> — <Priority> — <Status> — open <age> days`. When there are no open Cases but there are closed ones, the status is OK and the body says `No open cases.` after the first line

## Review

Brain review: attempt 1 was refuted for a stray sed backup file (.cls-E); attempt 2 removed it. Case priority order is applied in Apex through bounded queries. Gate line: validate-org: pass (14 components, 24 tests).
