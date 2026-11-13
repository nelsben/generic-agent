---
id: OPS-32
title: FR2: embedded surface placeholder — docs/patterns/14-embedded-surface.md records the call-centre vision (accept a call, get briefed, account map, knowledge, follow-up) as a safe, clearly labelled future pattern; no code
domain: ops
tier: standard
tier_reason: one docs page from recorded feedback and public product names
status: blocked
blocked_by: [BE-23]
fixes: []
scope: [docs/patterns/14-embedded-surface.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json, docs/ARCHITECTURE.md]
red_test: none (docs only): before the card no page carries rows F36 to F38; after, docs/patterns/14-embedded-surface.md exists and starts with the placeholder status line
gate: test
budget: 2-attempts
spend: 4
---
## Why

Feature revision 2 (FR2): Ben wants the agent embedded on a page for call-centre work, but said to "table this as a much larger spike ... true and realistic to how Salesforce will actually provision and be used for call center workflows ... put a placeholder in and keep it safe". Covers ledger rows F36, F37 and F38 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F36 to F38), docs/plans/fr2-design.md ('Surfaces') and docs/ARCHITECTURE.md. Load the skill salesforce-development:platform-capability-search first and use it (and public Salesforce docs only) to name, without claiming they work here, the platform pieces a real build would have to fit: Service Cloud Voice or a partner CTI through Open CTI, the Omni-Channel work item and the call-accepted event, the console record page, and Knowledge
- Write docs/patterns/14-embedded-surface.md with a plain 'Status: placeholder, not built' line at the top; the story Ben told (call accepted, customer info populates, the agent briefs, account map and key fields, chat, knowledge articles, follow-up actions) in his words where quoted; how it would reuse customerSummaryConversation, the summary skill, the context call and the write actions; the questions the later spike must answer (which telephony products, which event starts the brief, what a rep is allowed to see, latency budget while a caller waits, licences); and what is deliberately not done. No setup steps that a reader could mistake for working instructions. The page names roles, not people: quote the words without naming who said them. Page 14 is a placeholder, so fr2-design.md exempts it from the full page shape
- Do not edit docs/ARCHITECTURE.md or README.md: OPS-49 and OPS-36 link the page, and until then nothing has to. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
