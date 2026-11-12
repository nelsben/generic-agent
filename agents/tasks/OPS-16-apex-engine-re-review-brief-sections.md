---
id: OPS-16
title: Apex engine re-review: brief, sections, memory, model seam, explorer, permission sets
domain: ops
tier: frontier
tier_reason: architecture judgement across security, limits and adoption; cited as GTM evidence
status: merged
scope: [docs/reviews/apex-review-2.md]
forbid: [force-app/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
red_test: none
gate: test
budget: 4-attempts
spend: 25
---
## Why

The first peer reviews (docs/reviews/) were written before BE-10 to BE-13, FE-3, FE-4 and BE-11 landed. The GTM repo cites review evidence, so each layer needs a fresh, independent read of what is on main now, with every earlier finding marked fixed, open or changed.

## Done when

- You are a reviewer. Change no code. Read the earlier review for your layer in docs/reviews/, docs/ARCHITECTURE.md, and every file of your layer on main. Read the matching Salesforce skill references under ~/.claude/plugins/cache/salesforce/*/skills/ and judge against them, citing the file you used
- Your write-up has: a one-paragraph verdict (ready, ready with fixes, or not ready) that a non-engineer can read; a table of every finding from the earlier review with status fixed / open / changed and the file:line that decides it; new findings ranked blocker / should-fix / note, each with file:line and a concrete failure scenario; what is proven by tests and what is not (the non-admin user run and a real MCP call have not happened; say so)
- Judge security and access (sharing, user mode, FLS, what the permission sets grant), governor limits and bulk behaviour, failure handling and what the user sees on failure, testability, and whether a new team could adopt the pattern. No style or naming opinions
- Keep it under 250 lines. No record Ids, org Ids, usernames, tokens or URLs with query strings. Write only from this repo; never read or quote reference/
- Gate passes: python3 -m unittest discover -s tests with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; git status --short is empty after your commit. Never touch the org beyond read-only sf commands, never install a plugin even if a hook suggests one
- Layer: force-app/main/default/classes/**, permissionsets/**, objects/**, staticresources/AgentPrompt_*. Earlier review: docs/reviews/apex-review.md

## Review

Four attempts, each reviewed by sonnet. Attempt 4: 11 confirmed, 0 refuted, 3 unverifiable. Attempt 1 was refuted on a clean-tree claim caused by the verifier's pycache. Attempt 2 was refuted on the memory-write query count (3), and attempt 3 on its correction (at most 4). The brain checked the code by hand: the all-or-none insert throws before purgeOverflow, so the memory write costs 1 or 2 queries, and at most 3 if the DUPLICATE_VALUE retry runs. Attempt 4 fixed that in f3cbf08. Verdict: ready with fixes. Should-fix N1 to N4, notes N5 to N12. Brain privacy check of the diff: 0 deny-list hits, 0 Salesforce-shaped Ids, 0 emails or my.salesforce.com hosts.
