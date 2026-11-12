---
id: BE-4
title: People and engagement: contacts, Task activity, and call Events
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/classes/AccountBriefContactsSection.cls, force-app/main/default/classes/AccountBriefContactsSection.cls-meta.xml, force-app/main/default/classes/AccountBriefContactsSectionTest.cls, force-app/main/default/classes/AccountBriefContactsSectionTest.cls-meta.xml, force-app/main/default/classes/AccountBriefActivitySection.cls, force-app/main/default/classes/AccountBriefActivitySection.cls-meta.xml, force-app/main/default/classes/AccountBriefActivitySectionTest.cls, force-app/main/default/classes/AccountBriefActivitySectionTest.cls-meta.xml, force-app/main/default/classes/AccountBriefCallsSection.cls, force-app/main/default/classes/AccountBriefCallsSection.cls-meta.xml, force-app/main/default/classes/AccountBriefCallsSectionTest.cls, force-app/main/default/classes/AccountBriefCallsSectionTest.cls-meta.xml]
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
- AccountBriefContactsSection (key `contacts`, title `Contacts`): Contacts on the account, capped at 6, ordered by 90-day touch count DESC and then LastActivityDate DESC NULLS LAST. Touches are Tasks plus Events with that WhoId and ActivityDate in the last 90 days, counted with aggregate SOQL grouped by WhoId (no per-contact queries). Line format: `- <Name> — <Title or 'no title'> — 90d: <e> emails, <c> calls, <m> meetings — last touch <date or 'none'>`. A Contact with zero touches in 90 days gets ` (quiet)` appended
- AccountBriefActivitySection (key `activity`, title `Recent activity`): Tasks with AccountId = account and ActivityDate in the last 90 days. First line: `90d: <e> emails, <c> calls, <o> other; <n> open tasks overdue`. Then the 5 most recent as `- <date> — <TaskSubtype or Type or 'Task'> — <clip(Subject,120)> — <Who.Name or 'n/a'>`
- AccountBriefCallsSection (key `calls`, title `Calls & meetings`): Events with AccountId = account. The 5 most recent past ones (StartDateTime <= now, ordered DESC) as `- <date> — <clip(Subject,100)> — <DurationInMinutes> min — with <Who.Name or 'n/a'>`, followed by an indented ` notes: <clip(Description,300)>` line when Description is not blank (read Description in Apex; it cannot be filtered in SOQL). Then, when one exists, a final line `Next: <date> — <Subject>` for the soonest future Event. total counts past Events only

## Review

Brain review: accepted the Task.Type deviation (the field is absent in the org, so it is queried dynamically only when describe shows it). Gate line: validate-org: pass (12 components, 27 tests).
