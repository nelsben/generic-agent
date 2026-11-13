---
id: OPS-54
title: FR2 (PARKED on its own approval): remove the old Account Brief leftovers from agent-probe — list what the org still has under the old names, then one destructive deploy of what Ben's approval names, and never a Customer_Summary component
domain: ops
tier: frontier
tier_reason: a destructive deploy to a production-classified org, where a wrong line removes a live component
status: parked
fixes: []
scope: [docs/research/fr2-leftovers-removal.md, manifest/destructive/**]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, docs/reviews/**, docs/assets/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (an org step): the evidence is docs/research/fr2-leftovers-removal.md, with the read-only listing before and after and the test counts before and after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2): the rename leaves the old Account Brief metadata in agent-probe, because a real deploy adds and never removes. The old Apex classes and their tests stay deployed, compile against the classes later cards change, and run in every deploy with RunLocalTests, so one stale test can stop a build (finding 11 in docs/reviews/fr2-plan-review.md). Removing them is a destructive deploy, which the standing approval does not cover and Ben has not approved. This card is ready for his yes.

## Done when

- **Approval first:** PARKED, do not dispatch until Ben approves the removal in chat and the brain records it. Read the row "FR2: remove old Account Brief metadata" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", change nothing in the org and hand back. Remove only the kinds of thing the row's words name; anything it does not name is listed and left
- Read first: docs/research/fr2-rename-go.md (BE-21: what a rename leaves behind), docs/research/fr2-rename-org.md (OPS-30), docs/research/fr2-agent-publish.md (OPS-51: which agent and version is active, and whether it still calls an old class) and docs/research/mcp-door-runbook.md. Load the skills salesforce-development:platform-destructive-deploy, salesforce-development:platform-metadata-deploy and agentforce-adlc:agentforce-generate first
- **List first, read-only:** everything in agent-probe under the old names that the repo no longer has, by type and name (Apex classes and tests, the component, permission sets and the group, the app, tabs and pages, the old session object, the old agent with its versions and actions, the old MCP server and client app). Print names, version numbers and statuses only, never an Id. For each item, say what still depends on it
- **What must stay:** never touch a Customer_Summary component or anything the repo has today. Never remove a class that an active agent version still calls: on NO-GO, or where OPS-51 published nothing, the Account_Brief agent and the classes its active version calls stay. The old MCP server and client app go only if the row names them and OPS-31 has merged, so a door under the new names exists. The old session object's rows are data: remove the object only if the row says so in words
- **Pinned classes (BE-21):** Customer_Summary v1, the spike version BE-21 published, calls AccountBriefResolver and AccountBriefGetAction, and so does every Account_Brief version. Per docs/research/fr2-rename-go.md the org blocks deleting an Apex class that any agent version references, and a published agent is deleted only in Setup. So those classes stay while any such version exists: leave them out of the manifest, and list them on the page as left on purpose with that reason
- **What OPS-51 found (merged 2026-11-13):** Customer_Summary v2 is the active version, and its actions call CustomerSummaryResolver, CustomerSummaryGetAction and ExploreAction. Customer_Summary v1 (now Inactive) and Account_Brief v1 and v2 (v2 still Active) call AccountBriefResolver and AccountBriefGetAction, so those two classes are pinned. Before the publish, the org reported AccountBriefGetAction as IsValid false; record its IsValid value in the listing and never recompile or change it
- **Remove, in one destructive deploy:** if the old agent is in the list to remove, deactivate it first. Build the manifest under manifest/destructive/ from the list. Validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. If the plugin's deploy hook refuses the destructive deploy, stop and hand back with its message: never work around it. If the validation fails, stop, write down what failed and hand back; never remove items one at a time to get past an error
- Write docs/research/fr2-leftovers-removal.md: the listing before, what was removed, what could not be removed and why, what was left on purpose, the local test counts before and after, and the listing after. Say whether the line about old classes in later cards ('Old classes in the org') still applies. The manifest stays in the repo as the record
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Org, agent-probe only. Never publish or activate an agent, never create a user, never touch experimental, and deploy nothing but the destructive manifest. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
