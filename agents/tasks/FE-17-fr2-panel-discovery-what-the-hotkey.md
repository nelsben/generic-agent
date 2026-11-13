---
id: FE-17
title: FR2: panel discovery — what the hotkey panel and its surfaces could add later, ranked by value to a rep and by effort, with the platform limits checked and a proposed card for each; Ben picks
domain: frontend
tier: frontier
tier_reason: product and design judgement across the surfaces, checked against Lightning's limits
status: queued
fixes: []
scope: [docs/research/fr2-panel-later.md]
forbid: [force-app/**, mcp-door/**, spikes/**, scripts/**, data/**, tests/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
red_test: none (discovery): the evidence is docs/research/fr2-panel-later.md
gate: test
budget: 2-attempts
spend: 6
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 03. He likes that the panel can "snap in, hide, display different chats", a visibility that "might not actually exist there today", and that nobody is "dying to use the Astro button". He asked to "think about the hotkey panel and other items we should add later". Two open limits belong here too: the hotkey works only inside an app whose utility bar holds the panel, and the panel is desktop only. Covers ledger rows F60, F62 and F63 in docs/plans/feature-revision-2.md.

## Done when

- Read first: docs/plans/feature-revision-2.md (all of it, so nothing already planned is proposed again), docs/plans/fr2-design.md, docs/patterns/03-hotkey-panel.md, docs/patterns/05-conversation-memory.md, docs/patterns/11-voice-input.md, docs/research/fr2-surfaces-spike.md (OPS-29) and the cards FE-12, FE-13, FE-15 and OPS-32. Load the skills salesforce-development:platform-capability-search and experience-lwc:experience-lwc-design-generate first
- docs/research/fr2-panel-later.md lists 8 to 12 candidates. Start from these, drop any that do not hold up, and add better ones: the panel in every app (the standard sales and service apps, or a one-step install that adds it to an app's utility bar); the Salesforce mobile app; switching between chats (pinned chats, or recent accounts one key away); a list of the panel's keyboard shortcuts; a pop-out window; a signal when a slow answer is ready while the panel is hidden; resizing; slash commands in the composer for the skills and actions; the panel following the record the rep opens next; pinning an answer from the explorer so it is kept on the account as a saved answer (BE-35 stores it; ledger F80). The keep-an-answer control already has a parked card, FE-23: rank it with the rest and do not propose a second card for it
- For each candidate: the rep's problem in one line, how it would work, what Lightning allows (cite the public Salesforce docs or the OPS-29 findings; mark anything unproven), effort (S, M or L), risk, what it depends on, and a proposed card (title, scope, the done-when in three lines). End with a ranked top five and why. Docs only: no org access needed, never sign in or out, never create a user, never touch experimental. The brain cuts cards only for the ones Ben picks. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
