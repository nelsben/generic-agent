---
id: FE-24
title: Coworker follow-up 3: cards inside Coworker — a spike-only custom Lightning type drawn by our customerSummaryCard, on a spike copy of the agent, shown through Coworker delegation, with what renders recorded and captured
domain: frontend
tier: frontier
tier_reason: new metadata type wired to an agent output, a spike agent publish, and a live check in another surface
status: queued
fixes: []
scope: [spikes/coworker/**, docs/research/fr2-coworker-spike.md, docs/assets/fr2-coworker-*.png, docs/assets/MANIFEST.md]
forbid: [force-app/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, mcp-door/**, e2e/**, data/**, spikes/cards/**, spikes/actions/**, sfdx-project.json]
resources: [org-live]
red_test: a Jest test in spikes/coworker/ for the type's renderer wrapper fails before the wrapper exists and passes after
gate: test
budget: 2-attempts
spend: 25
---
## Why

The Coworker guide documents that a delegated agent's custom Lightning type renders as an interactive card inside Coworker. What is unproven is whether our own card envelope (FE-18, BE-39) can travel as such a type and be drawn by our shared card component (FE-22), so the same cards would show in Coworker as in our surfaces. Ben asked on 2026-11-13 for the Coworker follow-ups to run after the FR2 build; this is the prototype the spike page's follow-up 3 names.

## Done when

- Read first: docs/research/fr2-coworker-spike.md in full (OPS-57's section 'What a card in Coworker takes' is the recipe; OPS-58's 'Delegation, measured' says which org and user work), docs/research/fr2-card-architecture.md (FE-18), docs/research/fr2-card-contract-apex.md (BE-39), the customerSummaryCard component (FE-22) with its Jest tests, and the Customer_Summary agent bundle under force-app/main/default/aiAuthoringBundles/. Load the skills experience-lwc:experience-lwc-generate, experience-lwc:experience-lwc-security-validate, agentforce-adlc:agentforce-generate and salesforce-development:platform-metadata-deploy first
- **Approval first.** Read the row 'FR2+: Agentforce Coworker live steps' in the Approvals table of docs/plans/gtm-burn-plan.md. Build and test locally whatever the row's status. Deploy, publish, activate and send live messages only if the status starts with 'approved' and the row names deploying a spike Lightning type and publishing and activating a spike agent version; otherwise stop after the local build and Jest, write on the page what waits on the row, and hand back. Work only in the org alias the row names, the same org OPS-58 used
- **Org rules.** `-o <alias>` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, enter credentials, or accept consent. Never retrieve or commit a consumer key or secret. No destructive deploy. A deploy is a validate with RunLocalTests and then a quick deploy with CONFIRM_PROD=1, never `deploy start`, and deploys only the spikes package directory paths this card adds (`--source-dir spikes/coworker/...`). No Ids, usernames, emails, hostnames or query-string URLs in a file or image
- **Build, all under spikes/coworker/.** A custom Lightning type for one card type (the summary's card from BE-39), its schema matching BE-39's envelope, and a thin renderer LWC that imports nothing from force-app except by using `c-customer-summary-card` and passes the card through with `density` compact. If a Lightning type renderer cannot use a component from another package directory, copy the card component's files into the spike under a spike name and say so; never edit force-app. A spike copy of the agent, named `Customer_Summary_Coworker_Spike`, whose one action returns the summary's cards JSON with the type attached, and whose agent and topic descriptions say it answers only requests that contain the words 'card spike', so Coworker routes test turns to it and nothing else does. Never change the `Customer_Summary` bundle in force-app
- **Local tests.** Jest in spikes/coworker/ for the renderer wrapper: it renders a card from BE-39's JSON example, falls back to the card's `text` on an unknown type, has no record Id in the markup, and passes `toBeAccessible()`. Run the Lightning Web Security skill over the wrapper. Run with `npx sfdx-lwc-jest -- --roots spikes/coworker` and paste the summary line in the hand-back
- **Live, under the row.** Deploy the spike, publish and activate the spike agent, give the test user from OPS-58 agent access to the spike agent only, and send three turns through Coworker's Ask page that contain 'card spike' and name one existing seed-data account (a Chrome tab you create in a session Ben already signed in; never sign in, stop on a login page). Record for each turn: whether Coworker delegated to the spike agent, whether the card rendered as a card or fell back to markdown, whether its record links work as buttons, and the timings. Also open the same spike agent in the standard Agentforce panel once, if the org shows it, and record whether the card renders there
- **Results and page.** spikes/coworker/results/cards.jsonl (one line per turn, counts and yes or no only) and at most three captures as docs/assets/fr2-coworker-*.png listed in docs/assets/MANIFEST.md, cropped of any Id, username, email or hostname. On the page, the cards row in 'The three answers', the feature map's rich-cards row, 'What stays unproven' and 'For Ben' say whether our card renders inside Coworker, with the evidence. If it does, add a proposal for Ben: what a product version would take (a Lightning type per card type, the agent change, a publish), and that it is still through an agent, so F83 is his decision
- **Undo.** Deactivate the spike agent version and remove the test user's agent access to it. The page's Undo section lists what is left in the org (the spike type, the renderer, the spike agent): removing it is a destructive deploy and Ben's call
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes, bash scripts/check-docs.sh reports 0 broken, and the spike Jest passes. No tests/__pycache__, and git status --short is empty after the commit
