---
id: OPS-61
title: FR2 (PARKED until Ben says whether loading Mermaid from a CDN in Chromium is allowed): run the render check on every diagram in docs/patterns/ and docs/ARCHITECTURE.md, and replace each page's "not render-checked" limit with the result
domain: ops
tier: economy
tier_reason: one script run and a one-line Limits edit per page
status: parked
blocked_by: [OPS-48, OPS-36, OPS-49]
fixes: []
scope: [docs/patterns/**, docs/ARCHITECTURE.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/assets/**, README.md, tests/**, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: none (a docs change): before this card the pages carry a 'not render-checked' limit; after, each carries the check's result
gate: test
budget: 2-attempts
spend: 3
---
## Why

Since OPS-38 the pattern cards have asked for a render check on every diagram, but the brain told the workers on OPS-40, OPS-41, OPS-43, OPS-47, OPS-48 and others not to run it until Ben answers whether a worker may load Mermaid from a CDN in headless Chromium. Each of those pages carries a "has not been render-checked" limit. This card holds that one item, so those limits can name it instead of saying "no card yet".

## Done when

- Run first only after Ben's answer is recorded in the Approvals table of docs/plans/gtm-burn-plan.md; if he said no, the brain rewrites this card around a local check (for example a vendored Mermaid) before it is dispatched
- The render check written up in docs/patterns/_diagram-theme.md ('Render check') runs over every ```mermaid block in docs/patterns/*.md and docs/ARCHITECTURE.md, and the hand-back gives one line per page: the page, its number of diagrams, and ok or the error
- Every 'has not been render-checked' or 'render check ... was not run' limit on a page whose diagrams all pass is replaced with one line saying the diagrams parse and render locally on the check's date, and that how they draw in GitHub's light and dark themes is still checked by eye; a page with a failing diagram keeps its limit, names the error, and the diagram is fixed only if the fix is a syntax change that keeps every message and step number
- _diagram-theme.md's 'Render check' section gains one dated line with the result; nothing else on any page changes, and each page's own test still passes
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
