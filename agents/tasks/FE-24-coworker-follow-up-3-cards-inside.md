---
id: FE-24
title: Coworker follow-up 3: cards inside Coworker — a spike-only custom Lightning type drawn by our customerSummaryCard, on a spike copy of the agent, shown through Coworker delegation, with what renders recorded and captured
domain: frontend
tier: frontier
tier_reason: new metadata type wired to an agent output, a spike agent publish, and a live check in another surface
status: merged
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

## Review

Brain review (2026-11-14). Three attempts, opus, frontier tier, about $4.94 in all. Three sonnet reviews cost $1.14.

Attempt history:
- Attempt 1 ($4.35): the worker built the spike and staged it, but stopped without a report.
- Attempt 2 (53f0637, $0.25): the worker committed. Its report said gate=fail because it could not get a gate host slot. The mod ran the gate itself: Python 390 tests passed, 4 skipped. The brain raised the budget so the verifier could re-judge, and a review then ran: 11 confirmed, 3 refuted, 6 unverifiable.
- Attempt 3 (516363d, $0.34): page fixes for the refuted rows. The budget was raised again for the re-judge, and its review returned 13 confirmed, 1 refuted, 5 unverifiable.
- The one refuted row was the hold, which the brain had given only in a message. The brain wrote it into the brief, raised the budget and re-judged 516363d unchanged. The third review returned 17 confirmed, 0 refuted and 7 unverifiable.

Coordinator hold: the brain told the worker, at dispatch, to do the local build and Jest only. The live steps stayed held even though the Approvals row is approved for agent-probe. The reason: OPS-58 found no Coworker page in agent-probe, so the three Coworker turns could not run there. Deploying a spike type and agent anyway would leave residue, and removing it is a destructive deploy and Ben's call. Recorded in the brief after the second review, so the last review could confirm it.

Findings:
- spikes/coworker/main/default/:
  - The Lightning type coworkerSpikeSummaryCard: schema.json points at the Apex class, and lightningDesktopGenAi/renderer.json maps the 9 members of BE-39's summary card.
  - The renderer LWC coworkerSpikeCardRenderer wraps c-customer-summary-card at compact density. It imports only lwc and lightning/navigation, and no copy of the card was needed.
  - Five Apex classes plus a test: CoworkerSpikeSummaryCard, CoworkerSpikeCardBlock, CoworkerSpikeCardRun, CoworkerSpikeCardRef, CoworkerSpikeCardAction and CoworkerSpikeCardActionTest. A name that does not resolve gets fixed notice text, so no Ids reach the card.
  - The spike agent Customer_Summary_Coworker_Spike: one action, and it answers only requests containing "card spike". Its card output names the type and is displayable.
- Jest: 2 suites, 9 tests passed; a reviewer reran them. The tests cover:
  - BE-39's example;
  - the text fallback on an unknown type;
  - no record Id in the markup, with the record link a button;
  - toBeAccessible();
  - a wiring test across the files.
- docs/research/fr2-coworker-spike.md has a new section, "Cards in Coworker, built (FE-24)". The answer, the feature-map rows, "What stays unproven" and For Ben item 7 now say the card is built and Jest-proven locally. Whether Coworker draws it is not measured. The hold is attributed to the coordinator.

Gate (mod, at 516363d): Python 390 tests, 4 skipped; check-docs 75 pages, 0 broken.

Org: no deploy, validate, publish, activation, grant or sign-in. The only org calls were read-only metadata lists against agent-probe. force-app and the Customer_Summary bundle are unchanged.

Disclosed and accepted:
- The card's live steps were not run, by coordinator hold:
  - deploy, publish and activate;
  - the three Coworker turns;
  - the standard-panel check;
  - cards.jsonl and the captures.
- The Apex has not been compiled or tested in an org.
- The type name c__coworkerSpikeSummaryCard is inferred from the docs. If it is wrong, the card falls back to text with no error.
- A known skill note says custom types may not render on the new planner.
- The worker's self-reported local checks are not recorded in the tree: the Agent Script compile, the source convert and the LWS review (0 findings).

Still open:
- A re-cut card for the live steps, run once Ben names an org that shows Coworker, or says to deploy in agent-probe anyway.

Privacy check over the full branch diff (808 added lines): 0 denylist hits. The pattern hits are only Apex annotations and Agent Script @ references. The only URL host is the standard soap.sforce.com metadata namespace. No Ids, hostnames, emails or local paths.
