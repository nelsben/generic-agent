---
id: BE-52
title: Coworker follow-up 5: read the documented ConnectApi.Search signatures and run one search call from anonymous Apex in agent-probe, recording yes, no or not reached for door 2
domain: backend
tier: standard
status: merged
scope: [spikes/coworker/apex/door2-connectapi-search.apex, spikes/coworker/results/headless.jsonl, docs/research/fr2-coworker-spike.md]
forbid: [force-app/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, mcp-door/**, e2e/**, data/**, spikes/cards/**, spikes/actions/**, sfdx-project.json]
resources: [org-live]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

BE-47 left door 2 (the in-org search API, ConnectApi.Search) as "not reached": its one guessed signature, find(String), did not compile, and the Apex reference page refused an automated read. The Approvals row 'FR2+: Agentforce Coworker live steps' is approved for agent-probe and names running the search API from anonymous Apex, so one correct call settles whether that door works.

## Done when

- Read first: docs/research/fr2-coworker-spike.md sections 'Headless door probe (BE-47)' and the Enterprise Search row, sources [S43] and [S44], and spikes/coworker/apex/door2-connectapi-search.apex. Load the skills salesforce-development:platform-apex-anonymous-run and salesforce-development:platform-apex-generate first
- Find the documented ConnectApi.Search method signatures and the result class names from Salesforce's public Apex reference ([S44]) or the Connect REST Search pages ([S43]). Try a plain fetch first; if it is refused, open the public page in a new Claude in Chrome tab you create and close (never sign in, never use or close an existing tab, stop on a login page). As a cross-check you may use the Apex language server's completion or hover on ConnectApi.Search. Record on the page which signatures the docs list, citing the source
- If a documented signature can be filled from one seed account (for example an object API name and the account's name as the term), change door2-connectapi-search.apex to it and run it ONCE against agent-probe with -o agent-probe on every command. One call, read-only, counts and status only: no Ids, record names, reply text, usernames or hostnames in any file. If it still does not compile, stop after that one try; do not guess further
- spikes/coworker/results/headless.jsonl: replace the door-2 row with the new result (status ok, refused with the error type, or not reached with the reason), keeping the other rows
- On the page: the door-2 row of the headless table, 'Answer 1 from this probe', the 'Can they call a search door?' line in the first section, to-do row 8 and 'What stays unproven' say yes, no or not reached from this evidence only. A search result that returns records does not by itself show it reaches Coworker's Ask; keep answer 1 'not proven' unless a door actually returns Coworker's answer
- Org rules: agent-probe only; never touch experimental. No records, users, grants, deploys, Setup changes or Coworker messages. Foreground waits under 10 minutes, no background jobs
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken (you may run both; edit neither). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-15). One attempt (5a75b96), sonnet, standard tier, $0.51. The mod judged it consistent and accepted it without a reviewer pass; the brain read the diff itself.

Findings:
- docs/research/fr2-coworker-spike.md: a new paragraph lists the documented `ConnectApi.Search` signatures, read in a new browser tab on the public Apex reference [S44] after the plain fetch returned 403. They are `answer` (three overloads), `findAndGroup` (three overloads) and `find(objectApiName, ConnectApi.SearchRequest)`. No one-argument `find` exists, which explains BE-47's compile error.
- spikes/coworker/apex/door2-connectapi-search.apex now calls `findAndGroup(String)` and prints counts and the top-level key names only.
- spikes/coworker/results/headless.jsonl: the door-2 row is still "not reached", with the reason.
- Door 2 and answer 1 are unchanged ("not reached", "not proven"), so nothing overclaims.

Gate (worker): Python 390 tests, 4 skipped; check-docs 0 broken.

Org: one anonymous Apex run against agent-probe. It returned CLI status 1 with no detail. The worker's one diagnostic rerun was refused by the session's permission check, and the worker did not work around it. No records, grants or deploys were made.

Disclosed and accepted:
- The live result is not known. Someone has to run the script once and read the raw output; whether to do that is Ben's call, since the permission check refused the rerun.
- The script's errMsg field prints the exception message as is. A rerun that records it should check that the message carries no record name or Id before writing it to a file.

Still open:
- Door 2: one run of the script with the raw output read, then a page and jsonl edit.

Privacy check over the full branch diff (14 added lines): 0 denylist hits; no URLs, Ids, hostnames, emails or local paths.
