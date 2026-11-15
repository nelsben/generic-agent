---
id: OPS-63
title: Coworker round 2, card 2: in connect-24h Coworker is on, and three questions times three turns through Coworker are measured against BE-32 (OPS-58 re-cut)
domain: ops
tier: standard
status: merged
scope: [spikes/coworker/results/delegation.jsonl, spikes/coworker/delegation-notes.md, docs/research/fr2-coworker-spike.md, docs/assets/fr2-coworker-delegation-*.png, docs/assets/MANIFEST.md]
forbid: [force-app/**, data/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, spikes/coworker/main/**, spikes/coworker/apex/**, spikes/cards/**, spikes/actions/**, e2e/**, mcp-door/**, reference/**, .chassis-delegation.json]
resources: [org-connect, chrome-connect]
red_test: none
gate: test
budget: 2-attempts
spend: 25
---
## Why

OPS-58 could not measure delegation because agent-probe shows no Coworker page. Ben made connect-24h for this and gave full control of it on 2026-11-15, and OPS-62 installs the product there. This card turns Coworker on and measures whether Coworker hands our questions to Customer_Summary, how much of the answer survives, and how long a turn takes; it is a spike for ledger F83 and changes no product surface.

## Done when

- **Org guard first, before any other step.** Run `sf org display -o connect-24h --json` and `sf org display -o agent-probe --json` and compare `result.id` and `result.username` in a shell expression that prints only SAME or DIFFERENT, never the values. If connect-24h does not resolve, or either value is the same, take no org step, say so in the hand-back and stop
- Read first: docs/research/fr2-coworker-spike.md in full (its 'Delegation, measured' section is OPS-58's negative result in agent-probe), docs/research/fr2-standard-limits.md (BE-32: its questions, timings and how it counted section labels and rows), docs/research/fresh-org-run.md's OPS-62 section (what was installed and the seed account to use), and the Approvals row 'FR2+: Agentforce Coworker live steps' in docs/plans/gtm-burn-plan.md (approved for connect-24h). Approving the row does not reopen F83: say so on the page. Load the skill anthropic-skills:chrome-browser before the first browser step
- **Org rules.** Only `connect-24h`, with `-o connect-24h` on every `sf` command; the one exception is the guard's read-only `sf org display -o agent-probe`. Never touch agent-probe, experimental, experimental-web or my-devhub otherwise, and never use a Chrome tab on another org. Never sign in or out, enter a password or credential, or create a user: the test user is the org's existing admin user, the one the CLI runs as. Never create a connected app or External Client App. No destructive deploy, no security test. Foreground waits under 10 minutes, no background jobs; diagnose a failure once rather than loop
- **Turn Coworker on.** In a new Chrome tab you create (never reuse a tab you did not create; if it lands on a login page, stop and hand back), open Setup's Get Started with Agentforce Coworker page and follow its turn-on steps, accepting what Setup shows (the row allows it in this org). If Setup shows no such page under Quick Find for 'Coworker', 'Get Started' or 'Agentforce', also look in Setup's Agentforce section and the App Launcher before concluding it is absent, record what was searched, and hand back with the measurement unrun. Then give the test user Coworker access (the Access_Ai_Search permission set group, or whatever Setup names, and the licence the org has) and agent access to `Customer_Summary`. Record each step and grant
- **Live turns.** In Coworker's Ask page, on the seed account OPS-62 named, send three turns for each of three questions: one summary ('Summarize <account>') and two explore questions taken from BE-32's set. For each turn record, as counts and timings only: whether Coworker delegated to `Customer_Summary` (its thinking steps or the reply say so) or answered itself, seconds to the first visible text and to the finished answer, how many of the summary's six section labels appear on their own line, how many table rows of the explorer answer appear against the rows our panel shows for the same question (read the panel's count from the product, not from memory), and any timeout. Do not change any agent or topic description; record them as they are, because Coworker routes on them
- **Results.** Write spikes/coworker/results/delegation.jsonl (one line per turn: question kind, turn number, delegated yes or no, the two timings, labels kept, rows kept, timeout yes or no, the date; no Ids, people's names or account names beyond the seed account's) and spikes/coworker/delegation-notes.md saying how each number was read. Rewrite the page's 'Delegation, measured' section with a table beside BE-32's direct and agent numbers (keep OPS-58's agent-probe finding as one short paragraph), and update answers 3 and 4 at the top, the feature map, the options table's B and C columns where the numbers bear on them, 'What stays unproven' and 'For Ben' (items 2 to 6). Keep the recommendation unless the numbers contradict its reasons; if they do, say what and why in the hand-back and leave the call to Ben
- **Captures.** At most three screenshots of a delegated answer in Coworker, saved as docs/assets/fr2-coworker-delegation-*.png and listed in docs/assets/MANIFEST.md. Crop or blur anything showing an Id, a username, an email, a person's name other than seed data, or an org hostname; if you cannot, take none and say so
- **Undo and hand-over.** Leave Coworker on and leave the grants in place: FE-28 and BE-53 run next in this org, and the org expires about 24 hours after it was made. The page's Undo section lists what was turned on and granted and that it is left for the org's expiry. Close every tab you created
- No org Ids, record Ids, job Ids, usernames, emails, hostnames or URLs with a query string in any file. Workers may read docs/plans/** and run scripts/check-docs.sh but edit neither
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. The hand-back names each Setup step, each grant and the turn table, and ends with the [[report]] line

## Review

Brain review (2026-11-15). One attempt (4e1b5d6), sonnet, standard tier, $1.66. The mod judged it consistent and accepted it without a reviewer pass; the brain read the diff itself.

Findings:
- Coworker was already on in connect-24h: the Get Started page showed the switch on and its five setup steps complete, and the admin already held the Coworker licences, permission sets and group (moved there by the brain earlier). The run turned nothing on and granted nothing. The turn-on step and any terms it shows stay unseen.
- Delegation measured: 9 turns (3 summary, 3 of BE-32's e2, 3 of e4), each in a new chat on the seed account. Coworker delegated 0 of 9 to Customer_Summary and answered from its own CRM search.
- Coworker's explore tables were whole (30 of 30 and 47 of 47 rows against the panel's counts), but the 47-row answer took about 31 to 33 s, roughly twice BE-32's agent turn. Its summaries kept 0 of the 6 labels.
- The recommendation stays (stay custom; option C if Ben reopens F83). Reopening F83 remains Ben's call.
- spikes/coworker/results/delegation.jsonl: 9 rows. spikes/coworker/delegation-notes.md: method and timing notes. docs/research/fr2-coworker-spike.md: "Delegation, measured", answers 3 and 4, two feature-map rows, the options table, "What stays unproven", For Ben items 2 to 6, and follow-up card 6 marked done.
- The org also holds a SearchAgent agent definition, which BE-53 needs.

Gate (worker, on the gate-mac lane): Python 390 tests, 4 skipped; check-docs 0 broken. Mod: green.

Org: read-only SOQL and a read-only anonymous Apex run of the panel's explore (counts only). No DML, deploy, grant or description change. 9 Coworker chats are left in the admin's history until the org expires.

Disclosed and accepted:
- No captures: the card asked for screenshots of a delegated answer, and none was delegated.
- Summary turn 1's first-text time came from a cruder sampler and is marked inexact.
- Not tried, since the card forbade changing descriptions: naming Customer Summary in the question, other wordings, or changed descriptions.

Still open:
- Whether a question that names the agent, or a changed agent description, makes Coworker delegate. That is a new card, and changing descriptions needs a go.

Privacy check over the full branch diff (92 added lines): 0 denylist hits. Pattern hits are only the words orgfarm and Developer Edition in prose; no URLs, Ids, hostnames, emails or local paths.
