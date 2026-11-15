---
id: FE-28
title: Coworker round 2, card 4: in connect-24h FE-24's spike card type and agent are deployed and live, and three Coworker turns plus one standard-panel turn record whether our card envelope is drawn
domain: frontend
tier: standard
status: blocked
blocked_by: [OPS-63]
scope: [spikes/coworker/main/**, spikes/coworker/results/cards.jsonl, docs/research/fr2-coworker-spike.md, docs/assets/fr2-coworker-card-*.png, docs/assets/MANIFEST.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, spikes/coworker/apex/**, spikes/coworker/results/delegation.jsonl, spikes/coworker/results/headless.jsonl, spikes/cards/**, spikes/actions/**, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json]
resources: [chrome-connect]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

FE-24 built a custom Lightning type (coworkerSpikeSummaryCard) and a spike agent that returns our card envelope, proven only by Jest; its live steps were held because agent-probe shows no Coworker. With Coworker on in connect-24h (OPS-63), this card runs those steps once: whether Coworker and the standard panel draw our card is the open fact. It is a spike, still through an agent, so F83 applies.

## Done when

- **Org guard first, before any other step.** Run `sf org display -o connect-24h --json` and `sf org display -o agent-probe --json` and compare `result.id` and `result.username` in a shell expression that prints only SAME or DIFFERENT, never the values. If connect-24h does not resolve, or either value is the same, take no org step, say so in the hand-back and stop
- Read first: docs/research/fr2-coworker-spike.md sections 'What a card in Coworker takes', 'Cards in Coworker, built (FE-24)' and 'Delegation, measured' (OPS-63's result in connect-24h), everything under spikes/coworker/main/, and the Approvals row 'FR2+: Agentforce Coworker live steps' in docs/plans/gtm-burn-plan.md (approved for connect-24h; it names deploying a spike Lightning type and publishing and activating a spike agent version). If OPS-63 found no Coworker page, do only the standard-panel check and say so. Load the skills salesforce-development:platform-metadata-deploy, agentforce-adlc:agentforce-generate and anthropic-skills:chrome-browser first
- **Org rules.** Only `connect-24h`, with `-o connect-24h` on every `sf` command; the one exception is the guard's read-only `sf org display -o agent-probe`. Never touch agent-probe, experimental, experimental-web or my-devhub otherwise, and never use a Chrome tab on another org. Never sign in or out, enter a password or credential, or create a user: the test user is the org's existing admin user. No connected app or External Client App, no destructive deploy, no security test. Deploys go validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, never `deploy start`. Foreground waits under 10 minutes, no background jobs; diagnose a failure once rather than loop
- **Deploy and go live.** Validate and quick deploy spikes/coworker/main (its Apex test must pass in the org), publish and activate the spike agent Customer_Summary_Coworker_Spike, and give the test user agent access to it. If the deploy or publish fails on the type name or the card output (FE-24 inferred c__coworkerSpikeSummaryCard from the docs), make at most one fix under spikes/coworker/main/, rerun `npx sfdx-lwc-jest -- --roots spikes/coworker` and redeploy once; record the error class and the fix
- **Turns.** In a new Chrome tab you create (if it lands on a login page, stop and hand back), send Coworker three turns asking for a 'card spike' for the seed account OPS-62 named, and one turn to the spike agent in the standard Agentforce panel. For each turn record: whether the request reached the spike agent, whether a card was drawn by our renderer, drawn as text fallback, or not shown, which of BE-39's nine card members are visible, seconds to the finished answer, and any error. Write spikes/coworker/results/cards.jsonl (one line per turn; no Ids, people's names or account names beyond the seed account's)
- **Record.** Rename the page section to 'Cards in Coworker, built and measured (FE-24, FE-28)' and add the measured results, then update answer 3, the feature-map rows, 'What stays unproven', For Ben item 7 and follow-up item 3's status. At most three screenshots, saved as docs/assets/fr2-coworker-card-*.png and listed in docs/assets/MANIFEST.md, cropped or blurred so no Id, username, email, non-seed person's name or org hostname shows; if you cannot, take none and say so
- **Undo and hand-over.** Leave the spike agent active and the type deployed: the org expires about 24 hours after it was made, and removing them is a destructive step. The section's Undo list names what was deployed, published, activated and granted. Close every tab you created
- No org Ids, record Ids, job Ids, usernames, emails, hostnames or URLs with a query string in any file. Workers may read docs/plans/** and run scripts/check-docs.sh but edit neither
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes, `npx sfdx-lwc-jest -- --roots spikes/coworker` passes (paste its summary line in the hand-back), and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. End with the [[report]] line
