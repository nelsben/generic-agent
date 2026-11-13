---
id: OPS-53
title: FR2 (PARKED until Ben reports a check): flip the README's Status rows after Ben's manual checks — the MCP sign-in and one call per tool, the microphone, VoiceOver and the non-admin run each move from 'not yet proven' to their result and date; nothing else changes
domain: ops
tier: economy
tier_reason: a few table cells changed from a list the brain writes into this card
status: parked
blocked_by: [OPS-36]
fixes: []
scope: [README.md, docs/patterns/09-outside-door-mcp.md, tests/test_readme_fr2.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, docs/ARCHITECTURE.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: none (a docs change): before this card each reported row reads 'not yet proven'; after, it reads the result and date from the 'Reported' line of this card
gate: test
budget: 2-attempts
spend: 4
---
## Why

Feature revision 2 (FR2): some proofs only Ben can make, because they need his sign-in, his voice or his ears: the MCP sign-in and a real tool call, the microphone in Chrome, a VoiceOver pass, and the user he creates for the non-admin run. The pages never claim these; they link the README's Status table, which reads 'not yet proven' until a run is recorded (findings 9 and 33 in docs/reviews/fr2-plan-review.md). This card is how a row changes once Ben has done a check.

## Done when

- PARKED: do not dispatch until Ben reports a check in chat. **Reported** (the brain writes each check here, with its result and date in Ben's words, before it dispatches this card; this line in the committed card is the record the README's rows point back to): none yet. If this line still says 'none yet', change nothing and hand back
- Read first: README.md (the 'Status' heading and its table, as OPS-36 and OPS-28 left it), docs/patterns/09-outside-door-mcp.md and tests/test_readme_fr2.py
- For each check on the 'Reported' line, and only those, change that row of the README's Status table (the 'Status' heading in README.md) from 'not yet proven' to the result and its date: 'A real MCP tool call' (the sign-in, then one call of each tool), 'The microphone in Chrome', 'VoiceOver', and 'A run as a non-admin user' (from FE-5's merged run). A check that failed is written as it was reported, not softened. No other row, and no other part of the README, changes
- If 'A real MCP tool call' is reported: on docs/patterns/09-outside-door-mcp.md, the open item for the sign-in and the first real call is closed with the date, and the 'See it' text block keeps its label unless Ben supplied a transcript to replace it. Nothing else on the page changes. If tests/test_readme_fr2.py pins the old words of a row this card changes, change only that expectation
- Run nothing in an org, and write no username, email, Id, host name or token: the result is words and a date. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
