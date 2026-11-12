---
id: BE-13
title: Explorer: a date-only value on a Datetime field covers the whole day for >, >=, <, <= and IN, not just = and !=
domain: backend
tier: standard
tier_reason: one bounded fix with exact semantics given and an existing test to copy
status: merged
fixes: [BE-12]
scope: [force-app/main/default/classes/ExplorePlan.cls, force-app/main/default/classes/ExploreQuery.cls, force-app/main/default/classes/ExploreQueryTest.cls, force-app/main/default/classes/ExplorePlanTest.cls]
forbid: [force-app/main/default/aiAuthoringBundles/**, force-app/main/default/lwc/**, force-app/main/default/permissionsets/**, tests/**, scripts/**, docs/**, agents/**, .chassis-delegation.json, reference/**]
red_test: the new ExploreQueryTest methods for >, <=, and IN on a date-only value fail on main and pass after, via bash scripts/validate-org.sh
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

BE-12 made = and != treat a date-only value on a Datetime field as the whole local day, but left the range operators and IN bound at local midnight. The independent review found that "<= 2024-03-31" drops almost all of the 31st, "> 2024-03-01" includes most of the 1st, and IN matches only the instant of midnight, so "through March 31" questions silently undercount.

## Done when

- Read ExplorePlan.cls (around lines 371-375 and 596) and ExploreQuery.cls (around lines 152-160) and the existing date test in ExploreQueryTest.cls (the Pacific/Kiritimati user test) first. Read the salesforce-development skills platform-apex-generate and platform-apex-test-generate (SKILL.md under ~/.claude/plugins/cache/salesforce/salesforce-development/<version>/skills/)
- For a date-only value on a Datetime field, in the running user's time zone: `>` means >= the start of the next day; `>=` means >= the start of that day; `<` means < the start of that day; `<=` means < the start of the next day; `IN` matches any time within any of the listed days. `=` and `!=` keep their BE-12 behaviour. Date fields and full datetime values are unchanged
- Values stay bound (no string concatenation of user or model text into SOQL), and bind names do not collide when one query has several date filters
- New tests in ExploreQueryTest.cls, run as a user in a far-from-UTC time zone as the existing test does, prove each of >, >=, <, <= and IN against real records, including two date filters in one query. They use Assert.*, and they fail before the fix
- No invocable signature, label or description changes. Gates pass: `python3 -m unittest discover -s tests` (run with PYTHONDONTWRITEBYTECODE=1, leave no tests/__pycache__/) and `bash scripts/validate-org.sh` (check-only; never a real deploy, never run all local tests in the org). `git status --short` is empty when you report. Never install a plugin, even if a hook suggests one

## Review

No separate reviewer pass (small follow-up to BE-12's independent review, which specified these semantics). Gates green: 54 Python tests, check-only deploy with 146 Apex tests; the new test failed on main first.
