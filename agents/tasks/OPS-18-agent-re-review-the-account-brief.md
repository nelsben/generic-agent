---
id: OPS-18
title: Agent re-review: the Account_Brief agent script, its test spec and the release lifecycle
domain: ops
tier: frontier
tier_reason: architecture judgement across security, limits and adoption; cited as GTM evidence
status: queued
scope: [docs/reviews/agent-review-2.md]
forbid: [force-app/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
red_test: none
gate: test
budget: 3-attempts
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
- Layer: force-app/main/default/aiAuthoringBundles/**, tests/agent/**, scripts/agent-check.sh, docs/research/studio-preview.md, docs/research/agent-publish-failure.md. Earlier review: docs/reviews/agent-review.md. Say what a team must do, in order, to ship an agent change safely, given what the local gate cannot see
