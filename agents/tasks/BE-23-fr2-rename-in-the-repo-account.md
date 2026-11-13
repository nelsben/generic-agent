---
id: BE-23
title: FR2: rename in the repo — Account Brief becomes Customer Summary in every API name, label and living doc (everything but the agent bundle if BE-21 said no-go); no org change
domain: backend
tier: frontier
tier_reason: repo-wide rename across Apex, LWC, agent bundle, metadata, tests and docs that must still compile
effort: medium
effort_reason: mechanical rename with a clear rule; judgement only on doc wording
status: blocked
blocked_by: [BE-21]
fixes: []
scope: [force-app/**, mcp-door/**, sfdx-project.json, tests/**, e2e/**, scripts/**, data/**, README.md, docs/ARCHITECTURE.md, docs/patterns/**, package.json, jest.config.js, playwright.config.js, spikes/rename/**]
forbid: [spikes/README.md, spikes/surface/**, spikes/actions/**, spikes/cards/**, spikes/standard-limits/**, spikes/explorer-scale/**, spikes/agent-memory/**, spikes/embedded/**, docs/research/**, docs/reviews/**, docs/plans/**, docs/assets/**, agents/**, .chassis-delegation.json, reference/**]
resources: [org-live]
red_test: a new tests/test_fr2_rename.py asserts no Account Brief name remains outside the historical folders (docs/research, docs/reviews, docs/plans, agents, spikes), docs/assets, image alt text and link text that points into a historical folder, and on NO-GO outside the agent bundle, its spec and scripts/agent-check.sh; it also asserts that CustomerSummaryPanelController and customerSummaryPanel exist; it fails on main and passes after. A second test fails if two bundles in the repo are named Customer_Summary
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2) brands the one agent as Customer Summary. Ben chose to rename internal names too, as long as agent publishing works. BE-21 decides go or no-go. This card does the mechanical repo rename, check-only, so the org card can deploy and publish it in one step. Covers ledger rows F03 and F07 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (section 'Decisions the brain made'), docs/plans/fr2-design.md and docs/research/fr2-rename-go.md (BE-21's verdict and inventory). Load the skills salesforce-development:platform-apex-generate, experience-lwc:experience-lwc-generate, agentforce-adlc:agentforce-generate and salesforce-development:platform-metadata-deploy before editing
- If fr2-rename-go.md says NO-GO: rename everything as on GO below except the agent bundle's developer name and folder, its spec's subject name and the bundle name in scripts/agent-check.sh, which stay Account_Brief. Inside the bundle the action targets follow the renamed Apex and the label reads Customer Summary; the agent in the org keeps its old label until a publish, which this card never does. Say NO-GO at the top of the hand-back. Otherwise (GO) do the full rename below
- GO: rename every API name, file and reference: AccountBrief* Apex classes and tests to CustomerSummary*; Account_Brief* (agent bundle, permission sets, permission set group, app, utility bar flexipage, Account_Brief_Session__c and its fields) to Customer_Summary*; accountBriefPanel to customerSummaryPanel; the AccountBriefOpen message channel to CustomerSummaryOpen; mcp-door names (AccountBriefMcpClient, AccountBriefMcp and the sfdx-project.json replacement filename) to CustomerSummary*. The Customer_Summary bundle in force-app replaces Account_Brief (use spikes/rename/ as the reference, then delete spikes/rename/ in this card so two bundles never share the name; change nothing else under spikes/). After FE-20 no Apex names the agent; list any that does in the hand-back. AgentPrompt_* static resources keep their names; their text follows the wording rule below
- Wording: the product and agent are 'Customer Summary'. The one-ask output is a 'summary' in UI text, and the button reads 'Summarize <Account>'. Living docs (README.md, docs/ARCHITECTURE.md, docs/patterns/*, e2e/README.md) use the new names. Historical records (docs/research/*, docs/reviews/*, docs/plans/*) keep the names they were written with. Asset files are not renamed or recaptured here; the README card recaptures them, so leave image alt text and MANIFEST.md rows naming old pictures as they are
- Tests follow: tests/*.py, Jest and e2e (spec text, selectors, support helpers) use the new names; the agent spec under the agent bundle (or tests/) is renamed with it. git grep -i -E 'account ?brief|account_brief|accountbrief' outside docs/research, docs/reviews, docs/plans, docs/assets, spikes and agents returns nothing, or each remaining hit is listed in the hand-back with the reason
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- No org change: the org gate is check-only (bash scripts/validate-org.sh). Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
