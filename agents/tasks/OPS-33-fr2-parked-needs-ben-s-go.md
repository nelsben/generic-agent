---
id: OPS-33
title: FR2 (PARKED, needs Ben's go): embedded call-centre spike — prove how a Customer Summary component starts a brief when a call is accepted, using the telephony setup Salesforce really provisions
domain: ops
tier: frontier
tier_reason: contact-centre provisioning in a live org with licence and feature questions
status: parked
blocked_by: [OPS-32]
fixes: []
scope: [spikes/embedded/**, docs/research/fr2-embedded-spike.md]
forbid: [force-app/**, mcp-door/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: none (spike): the evidence is docs/research/fr2-embedded-spike.md
gate: test
budget: 2-attempts
spend: 25
---
## Why

Feature revision 2 (FR2): Ben tabled the embedded call-centre surface "as a much larger spike" that must be "true and realistic to how Salesforce will actually provision and be used for call center workflows". This card holds that spike so it is not lost; it is not to be dispatched until Ben says go and names the telephony setup (Service Cloud Voice, a partner CTI, or a simulator). Covers ledger rows F36, F37 and F38 in docs/plans/feature-revision-2.md.

## Done when

- PARKED: do not dispatch until Ben says go in chat and names the telephony setup and the org. When he does, the brain rewrites this card's done-when from docs/patterns/14-embedded-surface.md's open questions before dispatch
- Read first: docs/plans/feature-revision-2.md (rows F36 to F38), docs/patterns/14-embedded-surface.md and docs/plans/fr2-design.md
- The spike answers, with evidence from a real org: which event tells a component a call was accepted, how the caller's account is found, whether the shared conversation can start a summary unprompted within the rep's first seconds, what the rep may see under their licence and sharing, and what Knowledge returns for the account's open cases. Code lives in spikes/embedded/ only; findings in docs/research/fr2-embedded-spike.md
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Never touch experimental, and never create a user. Never buy, enable or trial a paid feature or accept terms without Ben's go in chat. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
