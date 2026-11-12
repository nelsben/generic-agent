---
id: FE-18
title: FR2: card architecture spike — one typed card contract for richly formatted answers (rich text, sections, tables, records, metrics, timelines, drafts, errors) that the compact window, the rail, Agentforce's own panel and MCP clients can all show; a catalog, a prototype, a recommendation and the build cards
domain: frontend
tier: frontier
tier_reason: a design and architecture decision every surface and every skill will build on, checked against what Lightning, Agentforce and MCP clients can render
status: blocked
blocked_by: [OPS-29]
fixes: []
scope: [spikes/cards/**, sfdx-project.json, tests/test_sfdx_project.py, docs/research/fr2-card-architecture.md, docs/assets/fr2-cards-*.png]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: none (spike): the evidence is docs/research/fr2-card-architecture.md, the prototype in spikes/cards/ with its Jest tests, and the captures
gate: test, jest
budget: 2-attempts
spend: 12
---
## Why

Feature revision 2 (FR2), Ben's further note on pattern 03, looking at the panel's answers: "whenever we display text inside of any of our services, it's richly formatted and we have a card architecture that we can display", and the spike he asked for: "what does our card architecture look like for richly formatted data that's easy to read and understand and feels best in class?" Today the panel shows answers as plain text in pre-line blocks. Covers ledger row F65 in docs/plans/feature-revision-2.md and principle 2 in docs/plans/fr2-design.md.

## Done when

- **Dispatched only after Ben's go on the FR2 spikes** (the Approvals table in docs/plans/gtm-burn-plan.md), and after OPS-29, which also touches sfdx-project.json. Read first: docs/plans/feature-revision-2.md (F60 to F65), docs/plans/fr2-design.md ('Operating principles', 'Conversation design', 'Theming', 'Write actions'), docs/research/fr2-surfaces-spike.md (OPS-29), docs/patterns/01-route-gather-reduce.md, 02-ask-anything-explorer.md, 03-hotkey-panel.md and 06-agent-routing-and-verbatim-relay.md, the accountBriefPanel LWC (how answers render now) and the panel controller's DTOs. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-lwc-design-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-capability-search first
- **Catalog:** every kind of answer the product gives or will give (the summary and its sections, an explorer table, one record, a list of records, a metric or count, a timeline of activity, a comparison, follow-up chips, an action draft, an action result, an error, a "showing 50 of N" note, a query trail), each with the card that shows it best: its parts, what is pinned, what folds, how it reads at 340 px and at 640 px, and its plain-text form
- **The contract:** one typed shape (a card type, a version, a title, its fields, record links by Id kept out of view, and a plain-text fallback) that the Apex services return and every surface reads. Rich text is a small safe subset (bold, italic, lists, links to records, inline code) parsed into runs, never HTML and never lwc:inner-html. Say how a new card type is added without touching every surface
- **Each surface, with evidence:** the LWC surfaces (a prototype renderer in spikes/cards/, with Jest and jest-axe); Agentforce's own panel (what it renders for an agent reply and an action output, including custom Lightning types for action outputs, from public Salesforce docs; prove in agent-probe only what can be proven without publishing or activating an agent, and mark the rest unproven for BE-28); MCP clients (what the text and structured content look like in a client transcript, from the MCP spec and the existing door's output)
- **Best in class:** compare against two or three well-known assistant products' answer cards from their public docs or screenshots, describing patterns, never copying their names into the repo or their assets. Keep the brand variables from fr2-design.md 'Theming'
- docs/research/fr2-card-architecture.md gives the catalog, the contract (with a JSON example per card type), the per-surface findings, the recommendation, the risks and a list of proposed build cards (title, scope, the done-when in three lines). Capture docs/assets/fr2-cards-*.png of the prototype at 340 and 640 px. The brain cuts the cards and folds the contract into FE-12 and BE-28. Org work, agent-probe only, under the spikes approval: a throwaway spike package in spikes/cards/ added to sfdx-project.json for the run and removed before hand-back (tests/test_sfdx_project.py passes), deployed by validate with RunLocalTests and quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
