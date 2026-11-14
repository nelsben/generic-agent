---
id: OPS-49
title: FR2: docs/ARCHITECTURE.md rewritten for Customer Summary — three ways in and the optional agent, one service behind each skill, the card contract, the trust rule with each system-context use, and the pattern list from the index
domain: ops
tier: standard
tier_reason: one page rewritten from research pages and an index that already exist
status: merged
fixes: []
scope: [docs/ARCHITECTURE.md, tests/test_architecture_doc.py]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, e2e/**, agents/**, docs/plans/**, docs/research/**, docs/reviews/**, docs/patterns/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: tests/test_architecture_doc.py fails before this card (the page has no link to chapter 00 or page 14, still shows the agent as a way in, and its pattern list does not match docs/patterns/README.md) and passes after
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2): docs/ARCHITECTURE.md is the one page that shows how the whole product fits together, and every chapter links it. The rename (BE-23) changes its names, but no card rewrote it for what FR2 built: three surfaces, the card contract, customer outcomes, the trust rule and an agent that is now optional (finding 7 in docs/reviews/fr2-plan-review.md).

## Done when

- Read first: docs/plans/fr2-design.md, docs/patterns/README.md (the index OPS-48 wrote) and every page it lists, docs/patterns/_diagram-theme.md, the current docs/ARCHITECTURE.md, and the research pages docs/research/fr2-trust-rule.md (BE-37), docs/research/fr2-card-contract-apex.md (BE-39), docs/research/fr2-card-architecture.md (FE-18), docs/research/fr2-rail-context.md (BE-25), docs/research/fr2-conversation-history.md (BE-26), docs/research/fr2-customer-outcomes.md (BE-35), docs/research/fr2-model-door.md (BE-33) and docs/research/fr2-agent-publish.md (OPS-51)
- Rewrite docs/ARCHITECTURE.md under the Customer Summary names: what the product is in three sentences; the three ways in (the compact window, the right rail, and the outside door over MCP, whose tools are Apex actions) and the optional agent as an add-on and test bench, never as a way in; one Apex service behind each skill (summary, ask anything, act) and every way in calling it; the card contract every surface reads; the two memories (conversation history and customer outcomes); the model door; and brand settings. Each part is a few plain lines and a link to its pattern page
- One component diagram of the shared conversation core and its frames, and one sequence diagram of a question from a surface to an answer with cards. Both follow fr2-design.md 'Diagrams' and copy the theme block from docs/patterns/_diagram-theme.md; check each with the render check written up in docs/patterns/_diagram-theme.md (OPS-38) and say so in the hand-back
- **Trust:** a part that says what runs as the signed-in user and lists each system-context use with its reason, taken from docs/research/fr2-trust-rule.md and no wider than that page. The page never says a run is proven or not yet proven: it links the README's Status table (the 'Status' heading in README.md). It names roles, not people, and links no card file
- **The pattern list** is copied from docs/patterns/README.md: the same titles in the same order, with 06 shown as an appendix, 07 as a principles page and 14 as a placeholder. The page links chapter 00 (why custom) near the top and page 14 where it names the embedded surface. Old names appear only as link text that points at a historical page
- tests/test_architecture_doc.py checks that every page in the index is linked exactly once with its title, that chapter 00 and page 14 are linked, that the page does not present the built-in panel or "Ask the agent" as a way in, that each sequence diagram starts with autonumber and carries the theme block, and that every system-context use named in docs/research/fr2-trust-rule.md appears on the page. Never claim 'any object' or 'any combination' beyond what pattern 02 lists as proven. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
- **Prompt name (OPS-30):** the summary's synthesis prompt is now the static resource `AgentPrompt_SummarySynthesis`, not `AgentPrompt_BriefSynthesis`, which stays in the org only for the old code (docs/research/fr2-rename-org.md, "The fix"). Write the new name wherever this page names the synthesis prompt
- **The user group (FE-20):** ARCHITECTURE.md says the user permission set group holds only the data-access set and no agent access, as FE-20 left it in force-app/main/default/permissionsetgroups; no line still says it holds the agent access set

## Review

Brain review (2026-11-14). One attempt (58eee29, $0.79). The verifier found the report consistent and the gate green and returned next=accept with no reviewer pass. The brain read the page's headings and its key phrases.

Findings:
- docs/ARCHITECTURE.md is rewritten under the Customer Summary names. It covers:
  - what the product is;
  - the three ways in (the compact window, the right rail and MCP), with the optional agent named an add-on and a test bench, "never a way in";
  - one service behind each skill (CustomerSummary, DataExplorer, CustomerSummaryActions), with a summary making up to 4 model calls;
  - the card contract, two diagrams (one flowchart and one sequence diagram with `autonumber`), the two memories, the model door, brand settings, add a source, trust, tests and release, the pattern list, and limits.
- The pattern list is a table copied from docs/patterns/README.md, with the same order and titles. It is the only place that links pages 01 to 13. Pages 00 and 14 are linked a second time on purpose.
- The trust part carries the two standard lines and the five system-context uses from fr2-trust-rule.md. One sentence notes that later cards added outcome text and the expiry purge, which page 07 lists.
- The "Add a source" heading is kept, because pattern 01 links its anchor.
- The page links the README Status table and never says "proven". No old product name remains.
- New tests/test_architecture_doc.py pins all of the above. Red evidence: red-1.txt, 25 of 26 checks failing or erroring on the old page.

Gate (verifier at 58eee29): Python 357 tests, 4 skipped. Worker: check-docs 0 broken.

Disclosed and accepted:
- The user group holds the data-access set and the outcome-access set, and no agent access. The brief said "only the data-access set", but the group's metadata and tests/test_access_group.py hold both, and the worker followed the source.
- The diagrams are not render-checked. The brain told the worker not to run the Mermaid CDN check until Ben answers. The Limits part says so and names OPS-61 (parked).
- A tests/__pycache__ made by the gate runs was removed before merge.

Still open:
- The render check (OPS-61).
- fr2-trust-rule.md's table lacks the two later system-context uses (OPS-35 L1); fold into a follow-up card.

Privacy check over the full branch diff at 58eee29 (440 added lines): 0 denylist hits. The only match is a test asserting that no home path appears. No URLs, Ids, local paths or job Ids.
