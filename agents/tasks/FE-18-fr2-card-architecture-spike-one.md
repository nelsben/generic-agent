---
id: FE-18
title: FR2: card architecture spike — one typed card contract for richly formatted answers (rich text, sections, tables, records, metrics, timelines, drafts, errors) that the compact window, the rail and MCP clients can all show; a catalog, a prototype, a recommendation and the build cards
domain: frontend
tier: frontier
tier_reason: a design and architecture decision every surface and every skill will build on, checked against what Lightning, Agentforce and MCP clients can render
status: merged
fixes: []
scope: [spikes/cards/**, docs/research/fr2-card-architecture.md, docs/assets/fr2-cards-*.png]
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

- **Approval first:** read the row "FR2: spikes in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back
- Read first: docs/plans/feature-revision-2.md (F60 to F65), docs/plans/fr2-design.md ('Operating principles', 'Conversation design', 'Theming', 'Write actions'), docs/research/fr2-surfaces-spike.md (OPS-29), docs/patterns/01-route-gather-reduce.md, 02-ask-anything-explorer.md, 03-hotkey-panel.md and 06-agent-routing-and-verbatim-relay.md, the conversation core customerSummaryConversation (FE-12: how answers, inline summary sections, the explorer table, the query trail, follow-up chips and the typed action-draft field render now, and its public interface, which must not change), the customerSummaryPanel frame, and CustomerSummaryPanelController's DTOs. Also read docs/research/fr2-actions-spike.md (BE-22: the draft and result shapes the action cards must carry) and docs/research/fr2-standard-limits.md (BE-32: what the standard Agentforce chat does to a layout, for the page's comparison only). Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-lwc-design-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-capability-search first
- **Catalog:** every kind of answer the product gives or will give (the summary and its sections, an explorer table, one record, a list of records, a metric or count, a timeline of activity, a comparison, follow-up chips, an action draft, an action result, an error, a "showing 50 of N" note, a query trail), each with the card that shows it best: its parts, what is pinned, what folds, how it reads at 340 px and at 640 px, and its plain-text form
- **The contract:** one typed shape (a card type, a version, a title, its fields, record links by Id kept out of view, and a plain-text fallback) that the Apex services return and every surface reads. Rich text is a small safe subset (bold, italic, lists, links to records, inline code) parsed into runs, never HTML and never lwc:inner-html. Say how a new card type is added without touching every surface
- **Each surface, with evidence:** the LWC surfaces (a prototype renderer in spikes/cards/, with Jest and jest-axe); Agentforce's own panel is out of scope (ledger F83; BE-32 records what it can show, for chapter 00 only); MCP clients (what the text and structured content look like in a client transcript, from the MCP spec and the existing door's output)
- **Best in class:** compare against two or three well-known assistant products' answer cards from their public docs or screenshots, describing patterns, never copying their names into the repo or their assets. Keep the brand variables from fr2-design.md 'Theming'
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- docs/research/fr2-card-architecture.md gives the catalog, the contract (with a JSON example per card type), the per-surface findings, the recommendation, the risks and a list of proposed build cards (title, scope, the done-when in three lines) for whatever BE-39 (the contract in the Apex services) and FE-22 (the rendering) do not already cover. Capture docs/assets/fr2-cards-*.png of the prototype at 340 and 640 px. The contract goes into the research page; BE-39 and FE-22 build from it. Do not edit sfdx-project.json: spikes/cards/ sits inside the non-default 'spikes' package directory OPS-50 added. Run Jest with an explicit roots argument that names the spike folder. Org work, agent-probe only, under the spikes row: deploy the prototype with --source-dir spikes/cards, by validate with RunLocalTests and then quick deploy with CONFIRM_PROD=1. The page ends with an 'Undo' list of everything this card left in agent-probe and how to remove each item. Never publish or activate an agent, never sign in or out, never create a user, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). Two attempts.

- Attempt 1 (c7b25d8): 20 confirmed, 1 refuted, 6 unverifiable. Refuted: the constructed MCP transcript called `resolve_account` with a `query` input that does not exist; the resolver takes `accountName` and `knownAccountId`.
- Attempt 2 (c3fb009): 17 confirmed, 0 refuted, 2 unverifiable. It corrected every tool input and output name in the transcript against the invocables, listed the six captures in docs/assets/MANIFEST.md (scope amend granted by the brain), and made every row of the page's grammar table a literal Jest vector. The reviewer re-ran spike Jest: 87 of 87.

The brain read the page outside the JSON examples and viewed the 640 px explorer and actions captures; the reviewer viewed the 340 px summary and actions captures. Findings:
- 19 answer kinds map to 16 card types drawn by 6 layouts (prose, list, fields, grid, metric, chips). A new type usually needs a view builder, an Apex builder and a plain-text rule, and no surface change.
- One flat envelope: no Map or Object member, string cells, record Ids only in `refs`. Every card carries a plain `text` that never holds an Id.
- Rich text is parsed into runs and bound as text. The prototype has no inner-html and builds no href; a record link is a button that fires `cardopen`.
- The prototype (four cardSpike* bundles) renders every type at 340 and 640 px, with three fallbacks and zero axe violations in Jest.
- Recommendation: one shared `customerSummaryCard` for FE-22; BE-39 builds the envelope as written; over MCP the cards travel as JSON text next to today's unchanged text.
- The MCP door has no explorer tool, and no door tool has ever been called, so the page's transcript is constructed, not observed.
- The resolver's AMBIGUOUS message already puts each candidate's record Id in its text, so an MCP client receives Ids there today. A choice card would move them into `refs`.

Org: the spike tab FR2_Cards_Spike, the permission set FR2_Cards_Spike_Access and the four cardSpike* bundles were deployed to agent-probe (validate with RunLocalTests, then quick deploy) and are left there. Removing them is a destructive deploy and Ben's call.

Disclosed and accepted:
- The deploy results, the permission set assignment, the 640 px overflow count and the first-capture layout problem are the worker's account; nothing in git shows them.
- The six captures are device-scale crops taken by the spike's own capture spec, not by `npm run capture`.
- The worktree's gitignored .sf/config.json was set to agent-probe so the deploy gate would run.

Still open:
- The example table reads "Showing 6 of 212 rows" while the notice under it reads "Showing 50 of 212 rows"; the fixtures disagree.
- The draft fixture shows Confirm as the primary control while a field is still "Needed"; FE-14 decides whether Confirm is disabled until the draft is READY.
- The page's Findings say the AMBIGUOUS message carries Ids and, two sentences on, "nothing puts an Id in the text"; the second means card text.
- Two parsers (Apex and JS) can drift; the page proposes one shared vectors file, or parsing in Apex only.
- The cards JSON is about 4.5 times the size of the text for a 6-row table and needs its own cap on an MCP output.
- Three proposed build cards (shared rich-text vectors; the resolver and the drill return cards; one real MCP call) are not cut yet.
- The prototype has no loading state and has not been tried against a real conversation turn (FE-22).

Privacy grep over the full diff (4,075 added lines): 0 hits. The captures show sample data only.
