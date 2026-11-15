---
id: OPS-58
title: Coworker follow-up 2: delegation prototype — in an org with Coworker on, live turns through Coworker reach Customer_Summary, and how faithfully and how fast the summary and explore answers come back is measured against BE-32
domain: ops
tier: standard
status: merged
fixes: []
scope: [spikes/coworker/**, docs/research/fr2-coworker-spike.md, docs/assets/fr2-coworker-*.png, docs/assets/MANIFEST.md]
forbid: [force-app/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, mcp-door/**, e2e/**, data/**, spikes/cards/**, spikes/actions/**]
resources: [org-live]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

The one documented way our work reaches Coworker is delegation to an agent the user can access (docs/research/fr2-coworker-spike.md). Whether Coworker hands our requests to Customer_Summary, how much of the summary's layout and the explorer's tables survive the relay, and how long a turn takes are all unmeasured. Ben asked on 2026-11-13 for the Coworker follow-ups to run after the FR2 build. This is a spike that informs ledger F83; it changes no product surface.

## Done when

- Read first: docs/research/fr2-coworker-spike.md in full (OPS-55, OPS-56 and OPS-57), docs/research/fr2-standard-limits.md (BE-32: the questions it asked, its timings and how it counted section labels and rows) and docs/plans/feature-revision-2.md row F83. Load the skills salesforce-development:platform-metadata-deploy and agentforce-adlc:agentforce-generate first
- **Approval first.** Read the row 'FR2+: Agentforce Coworker live steps' in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with 'approved', do no live step at all: write on the page that the prototype waits on that row, and hand back. When it is approved, do only the steps the row names, in the org alias the row names, and nothing else. Approving the row does not reopen F83: say so on the page
- **Org rules.** Only the org alias the row names (or `agent-probe` if the row names it), with `-o <alias>` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user: the test user is an existing user the row names. Never sign in or out, enter credentials, or accept consent or terms beyond what the row names. Never create a connected app or External Client App, and never retrieve or commit a consumer key or secret. No destructive deploy. No security or red-team test. A deploy is a validate with RunLocalTests and then a quick deploy with CONFIRM_PROD=1, never `deploy start`. A read-only step (a query, a describe, a list) needs no row
- **Make the org ready, as far as the row allows.** Coworker is on (Ben turns it on himself, or this card does it under the row through Setup's Get Started with Agentforce Coworker page). If the org is not `agent-probe` and the row names it, deploy force-app there (validate then quick deploy), load the seed data the README's quick start loads, and publish and activate `Customer_Summary` there; if the row does not name these, hand back. The test user gets Coworker access (the Access_Ai_Search permission set group and the licence the org has) and agent access to `Customer_Summary` only (FE-20 removed agent access from the user group; grant it to this one user, never to the group). Record each grant for the Undo list
- **Live turns.** Through Coworker's Ask page, in a Chrome tab you create inside a browser session Ben has already signed in as the test user (never sign in; if the tab lands on a login page, stop and hand back), send three turns for each of three questions on one existing seed-data account: one summary ('Summarize <account>') and two explore questions taken from BE-32's set. For each turn record, as counts and timings only: whether Coworker delegated to `Customer_Summary` (its thinking steps or the reply say so) or answered itself, seconds to the first visible text and to the finished answer, how many of the summary's six section labels appear on their own line, how many table rows of the explorer answer appear against the rows our panel shows for the same question, and any timeout. Do not change any agent or topic description (that needs a publish); record them as they are, because Coworker routes on them
- **Results.** Write spikes/coworker/results/delegation.jsonl (one line per turn: question kind, turn number, delegated yes or no, the two timings, labels kept, rows kept, timeout yes or no, the date; no Ids, names of people or account names beyond the seed account's name) and a script or notes in spikes/coworker/ that say how each number was read. Add a section 'Delegation, measured' to the page with a table next to BE-32's direct and agent numbers, and update answers 3 and 4 at the top, the feature map, the options table's C and B columns where the numbers bear on them, 'What stays unproven' and 'For Ben'. Keep the recommendation unless the numbers contradict its reasons; if they do, say what and why in the hand-back and leave the call to Ben
- **Captures.** At most three screenshots of a delegated answer in Coworker, saved as docs/assets/fr2-coworker-*.png and listed in docs/assets/MANIFEST.md. Crop or blur anything that shows an Id, a username, an email, a person's name other than the seed data's or an org hostname. If you cannot remove them, take no capture and say so
- **Undo.** Remove every grant this card made (the test user's agent access, and the Coworker access unless the row says to keep it). Leave Coworker on unless the row says to turn it off. Deactivate nothing that was active before. The page's Undo section lists what was granted, what was removed, and what is left in the org (for example a deployed product in a new org); removing what is left is a destructive step and Ben's call
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. The hand-back names the org alias used, the steps taken under the row, every grant and its undo, and the turn table

## Review

Brain review (2026-11-14). Two attempts, sonnet, standard tier. The mod judged both consistent and accepted them without a reviewer pass. The brain read the diff itself.
- Attempt 1 (51fd4f7): $0.46. Ben approved the Approvals row for agent-probe that day ("Go, use agent probe org"). A new Chrome tab landed on the login page because no session was signed in, so the worker stopped. Its read-only queries found that the admin already holds Customer_Summary agent access and that no user holds Access_Ai_Search.
- Ben then signed in to agent-probe in the Claude Chrome tab group.
- Attempt 2 (c9ed60e): about $0.00. Setup's Quick Find showed nothing for "Coworker" or "Get Started", and the Agentforce pages it listed did not include Get Started with Agentforce Coworker. Per the card, the worker took no other Setup step and handed back.

Findings:
- docs/research/fr2-coworker-spike.md has a new section, "Delegation, measured". It says the delegation is not measured, and why. It records what Setup in agent-probe shows, that approving the row does not reopen F83, and the Undo list (nothing granted, removed or left in the org). The "What stays unproven" Developer Edition item now points to it.

Gate (worker): Python 390 tests, 4 skipped; check-docs 0 broken.

Org: read-only queries and Setup's search in agent-probe. Coworker was not turned on. No grant, deploy, record or turn was made. Ben's signed-in tab was left open.

Disclosed and accepted:
- The card's measurement (3 questions × 3 turns, timings, labels and rows kept) is not done. It needs an org that shows the Coworker page. This merge records only the negative result for agent-probe.
- The worker looked only through Quick Find. A Coworker page under another name is not ruled out.
- No reviewer pass ran: on a standard-tier card the mod accepted a consistent verdict directly.

Still open:
- Ben: an org that shows Get Started with Agentforce Coworker (for example a Trailhead Coworker playground), named in the Approvals row, with a session he signs in to. Then a re-cut of this measurement card.
- BE-47's in-org search door (`ConnectApi.Search`) and FE-24's local build do not need Coworker, and can run in agent-probe under the approved row.

Privacy check over the full branch diff (26 added lines): 0 denylist hits; no URLs, Ids, hostnames, emails or local paths.
