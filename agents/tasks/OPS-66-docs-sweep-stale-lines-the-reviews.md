---
id: OPS-66
title: Docs sweep: stale lines the reviews left (trust table, model-call count, Undo lists, captures rows, small headers)
domain: ops
tier: standard
effort: low
effort_reason: mechanical docs corrections with named lines
status: queued
scope: [docs/research/fr2-*.md, docs/assets/MANIFEST.md, docs/patterns/_diagram-theme.md, docs/patterns/13-write-actions.md, scripts/summary-accuracy.apex, e2e/capture/10-rail.capture.js, force-app/main/default/classes/CustomerSummaryMemory.cls, tests/test_docs_sweep.py]
forbid: [README.md, docs/plans/**, docs/reviews/**, agents/**, force-app/main/default/lwc/**, e2e/*.spec.js, e2e/support/**, e2e/global-setup.js, mcp-door/**, reference/**, docs/research/fr2-explorer-catalog.md, docs/research/fr2-explorer-scale.md, docs/research/fr2-explorer-grammar.md, docs/research/fr2-explorer-long-text.md, docs/research/fr2-explorer-after.md]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

The build review (docs/reviews/fr2-build-review.md L1, L2, L4, L12) and the OPS-36, OPS-42 and OPS-52 hand-backs left a set of docs lines that no longer match the build. A GTM reader trips on each one. None of them needs the org.

## Done when

- L1: docs/research/fr2-trust-rule.md's system-context table lists CustomerOutcomes (each of its system-context markers, with its reason as the code comment gives it) and CustomerOutcomeRetentionBatch, and the history read's reason matches the current code comment. Every row is checked against `grep -rn 'system-context' force-app/main/default/classes` and the page says the date it was checked
- L2: the two comments at CustomerSummaryMemory.cls:314 and :325 no longer say reps have no access to the object; they say what is true (Customer_Summary_Data_Access grants reps read; the service reads in system context to scope rows to the running user's own sessions, or whatever the code shows). Comment-only change: no code line changes, and the card does not deploy (the next org card's deploy carries it)
- L4: docs/research/fr2-model-door.md:53 and scripts/summary-accuracy.apex:5 and :9 say a summary is up to 4 model calls (two pre-reduces, the sentiment call and the synthesis), checked against CustomerSummary.cls
- L12: every docs/research/fr2-*.md page has a heading matching ^#.*undo (case-insensitive). A page whose work changed nothing in an org says so in one line under that heading; a page whose work did change an org lists what to remove, taken from the page itself or its card's Review section (agents/tasks/, read only), never invented. The two explorer pages BE-43 to BE-45 own are left alone and named in the hand-back
- The e2e/capture/10-rail.capture.js header comment (a comment-only change) no longer says nothing is written to the org: its question writes the product's own session row (OPS-52)
- docs/assets/MANIFEST.md and docs/research/fr2-captures.md no longer list README.md under 'Old, still linked' for brief-flow.gif and e2e-report.png if README.md no longer links them (check with grep; if it still links them, leave the rows and say so)
- docs/research/fr2-quick-start-change.md's folder list matches the README's quick-start folder list, or says plainly that the README's list is the current one
- docs/patterns/_diagram-theme.md's 'For the next card that tries' paragraph no longer asks for a run that has been done; it keeps the note that the Mermaid CDN render check is held until Ben answers (OPS-61). Do not run that render check
- docs/patterns/13-write-actions.md states the door's two-action limit (create a task, log a call; the panel keeps six), as OPS-59 built it
- New tests/test_docs_sweep.py pins L1 (both names in the trust table), L4 (no 'up to 3' in the two files) and L12 (each fr2-*.md page that exists at this card's base, listed by name in the test, not by glob, has an undo heading, except the two explorer pages; new explorer pages BE-43 to BE-45 write are not covered); gates PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken) pass; no tests/__pycache__ left
- No org command is run. No Id, username, email, hostname or local path is written. The hand-back lists any item it could not settle
