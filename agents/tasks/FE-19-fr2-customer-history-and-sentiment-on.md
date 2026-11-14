---
id: FE-19
title: FR2: customer history and sentiment on screen — a timeline of the account's outcomes and a sentiment-over-time chart, in the rail and as an account page component, built from the card contract
domain: frontend
tier: standard
tier_reason: a display of stored data through the card contract, with a chart and accessibility checks
status: queued
fixes: []
scope: [force-app/main/default/lwc/customerSummaryHistoryTimeline/**, force-app/main/default/lwc/customerSummarySentimentChart/**, force-app/main/default/lwc/customerSummaryRail/**, e2e/**, docs/assets/fr2-history-*.png]
forbid: [force-app/main/default/classes/**, force-app/main/default/objects/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, spikes/**, scripts/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new Jest tests for customerSummaryHistoryTimeline and customerSummarySentimentChart fail on main (the components do not exist) and pass after
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 05: outcomes "should persist against that customer", and "we also want to be able to show a graph of change in customer sentiment over time". Covers ledger rows F76 and F77 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (rows F74 to F80), docs/plans/fr2-design.md ('Conversation design', 'Theming', 'Accessibility'), docs/research/fr2-card-architecture.md (FE-18), docs/research/fr2-card-contract-apex.md (BE-39), docs/research/fr2-customer-outcomes.md (BE-35) and docs/research/fr2-sentiment.md (BE-36; if it says the score is not steady enough to chart, show the labels only and say so). Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-accessibility-validate, experience-lwc:experience-lwc-security-validate and salesforce-development:platform-flexipage-generate first
- **Timeline:** customerSummaryHistoryTimeline lists the account's outcomes newest first through FE-18's timeline card (type, date, title, the related record as a link; if FE-22 built the shared customerSummaryCard component, render the card with it and add no second renderer, and do not edit that component), with a filter by type and "show more". Opening a summary shows its text to its author, or to anyone when its type shares it; anyone else sees its type, date and sentiment label and a short note that the text stays with its author (BE-35's rule, ledger F87)
- **Sentiment chart:** customerSummarySentimentChart draws sentiment over time from the summaries' scores as an inline SVG line (no external library), points labelled with date and label, the reason on focus or hover only where the viewer may see it (the author, or a type that shares its text; otherwise the label alone), a text table alternative for screen readers, and colours from the --cs-* variables with WCAG AA contrast. Fewer than two points shows a plain note instead of a chart. Use only existing sample data and outcomes written by real summaries. Never insert or backdate a record for a capture; show the empty state instead
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Both sit in the rail's context area (FE-15). Both expose the record-page target. Placing them on a page is a step in the swap guide, not in this card. Jest covers both with empty, one-point and many-point data and zero jest-axe violations; an e2e spec opens each in the rail. Tag one spec for FE-21's smoke subset (the tag is in e2e/README.md). Paste the Playwright summary line in the hand-back. Capture docs/assets/fr2-history-timeline.png and docs/assets/fr2-history-sentiment.png at 1440x900. Every still and GIF is taken through e2e/capture/kit.js. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
