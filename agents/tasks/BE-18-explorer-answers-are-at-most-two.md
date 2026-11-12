---
id: BE-18
title: Explorer answers are at most two sentences on four question shapes (list, count, single record, follow-up), in agent-probe, with the explore assets recaptured
domain: backend
tier: frontier
tier_reason: prompt change shipped to a live org, measured across question shapes, with a regression gate on the published agent
status: merged
scope: [force-app/main/default/staticresources/AgentPrompt_Explore.resource, tests/test_explore_prompt.py, e2e/capture/04-explore.capture.js, docs/assets/explore-answer.png, docs/assets/explore-drill.gif, docs/assets/drill-view.png, docs/assets/MANIFEST.md, docs/patterns/02-ask-anything-explorer.md, docs/research/explore-prompt-2.md, docs/research/explore-prompt-1.md]
forbid: [force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, force-app/main/default/permissionsetgroups/**, scripts/**, data/**, agents/**, README.md, docs/plans/**, docs/reviews/**, e2e/panel.spec.js, e2e/support/**, playwright.config.js, playwright.capture.config.js, reference/**, .chassis-delegation.json, sfdx-project.json]
resources: [org-live]
red_test: the measured baseline on main fails the bar: BE-17 recorded three-sentence answers on the list question, and tests/test_explore_prompt.py fails on main once it asserts the new rule 9 text
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

BE-17's rule 9 rewrite kept the table as the answer, but every answer still ran to three sentences, named one or two rows and mentioned the owner, against the rule's "one or two sentences". Ben asked for another iteration. A GTM reader should get a short, direct lead on any question shape, not only the capture question.

## Done when

- Read first: force-app/main/default/staticresources/AgentPrompt_Explore.resource, force-app/main/default/classes/DataExplorer.cls (how the prompt is loaded and what the model sees, including how earlier turns are passed), tests/test_explore_prompt.py, e2e/capture/04-explore.capture.js, e2e/capture/kit.js, e2e/support/ (read only), docs/research/explore-prompt-1.md (BE-17's run: the five recorded answers and the deploy steps), docs/research/agent-iteration-1.md (how the spec ran on v2), docs/assets/MANIFEST.md and docs/patterns/02-ask-anything-explorer.md. Load the skills salesforce-development:platform-metadata-deploy and agentforce-adlc:agentforce-test before any sf command
- The four question shapes, asked through the panel on the Edge Communications account page in agent-probe: (L) list 'Which 5 open opportunities have the largest amounts?'; (C) count 'How many open opportunities are there?'; (S) single record 'What is the largest open opportunity?'; (F) follow-up, asked right after L in the same panel session, 'Which of those close in 2027?'. Measurement scripts live only in .delegation/BE-18/ (gitignored) and are never committed
- Sentence counting rule, applied to the answer text only (not the table or caption): split on '.', '!' or '?' followed by whitespace or end of text; a '.' between two digits ($1.4, 2.5) or inside a dotted abbreviation (Inc., Corp., Ltd., e.g., i.e., vs.) does not end a sentence; a line starting with '- ' or a digit followed by '.' counts as one sentence each. Record each answer's text and its count
- Red first: measure all four shapes once each on main's prompt and record the counts. This baseline is the red evidence
- The bar, on the final prompt, 3 runs of each of the four shapes (12 answers): every answer is at most two sentences by the rule above; no answer names more than one record for L and F (S names exactly the one record it asks about); no answer mentions an owner, Sample Owner or any user unless the question asks about owners; C states the number in the first sentence; F uses the earlier result (it answers about the five from L, not all opportunities). A one-row total and facts from an earlier query still go in the text, as BE-17 kept them
- Prompt: change only rule 9 of AgentPrompt_Explore.resource (wording of your choice, record it) and, only if needed, add one example in rule 9 of a good two-sentence lead. Every other rule keeps its meaning and the output JSON format and template variables do not change. At most three prompt revisions in the org; if revision 3 misses the bar, keep the best revision that does not regress BE-17 (answer plus table header still fit the 273 px box on L), record every revision's counts, and hand back gate=fail with the evidence rather than looping. tests/test_explore_prompt.py asserts the new rule 9 text and that rules 1 to 11 are still present
- Org, agent-probe only, under the Approvals line 'Production-classified deploys to agent-probe ... standing': deploy only the staticresource. Validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, relaying Ben's standing approval. Never publish or activate an agent, never sign in or out, never touch the org this was first built in (experimental)
- Fit: on L the question, the answer and the table header row fit in the panel scroll box in 3 of 3 runs; record needed px against box px
- No regression: one full npm run test:e2e passes 8 of 8 (if spec 2 flakes on focus as FE-9 recorded, rerun it once and report both). The Account_Brief agent spec (tests/agent/Account_Brief-testSpec.yaml) is run once against the active version 2, after the e2e run finishes (not overlapping it), and passes 16 of 16 on replies and actions; report topic separately (case 12 is the known false failure). If the spec regresses, redeploy the original resource the same way, revert, and hand back
- Recapture only explore-answer.png, explore-drill.gif and drill-view.png with e2e/capture/04-explore.capture.js (SF_TARGET_ORG=agent-probe), keeping the privacy machinery (masking, the 0.5 s checks, the all-frames checks). Remove any console.log of answer text that BE-17 added to that capture file. Every other file in docs/assets/ stays byte-identical (git diff --stat). Read each new PNG and every GIF frame at 1 fps by eye and say in the hand-back what each shows
- MANIFEST.md rows and the alt text and captions in docs/patterns/02-ask-anything-explorer.md match the new images exactly. Write docs/research/explore-prompt-2.md: the rule 9 change, the baseline and final answers for all four shapes with their sentence counts, the fit numbers, the e2e and spec results, and the deploy steps in order; add one line at the top of explore-prompt-1.md pointing to it. No record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings in any file or image
- Budget: about 40 model calls in the org. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

# BE-18 hand check (attempt 2, a764276)

Accepted after a hand check.

- Bar met 12/12 across the four shapes (L, C, S, F): every answer is at most two sentences. L fits the 273 px box at 158 px.
- No regression: e2e 8/8. Agent spec replies 16/16, actions 16/16, topic 15/16. Case 12 is the topic miss. Case 2 is the brief path and does not load the explore prompt (only DataExplorer.cls loads it), so it is not a regression of this card.
- Amend granted for DataExplorer.cls and its test. Explorer and drill tables no longer show Id columns and use catalog labels (Account, Stage, Close Date). Row Ids stay in the rows for drill-down. The trail shows "Id IN (5 records)" or "a record", never raw Ids. Five new Apex tests cover this, and 159/159 tests passed on deploy.
- Reviewers refuted two claims across two passes.
  - For the F follow-up, the panel shows two tables: the five-row rerun and the 2 matches, not only the 2 matches. explore-prompt-2.md made the same claim. The brain fixed it in d08338d: the research page now describes both tables, notes that rule 9's "the system shows the last result's rows as a table" does not match either, and lists the extra table and the raw amounts under Still open.
  - The other refuted claim was a tests/__pycache__ directory. The gate run created it after the worker committed, and it was removed before merge.
- Privacy grep of the 689 added lines found nothing: denylist 0, Ids 0, emails 0, hosts 0, query-string URLs 0, home paths 0, experimental 0.
- Assets viewed: explore-answer.png, drill-view.png and every frame of explore-drill.gif. Each uses sample data, a masked owner, masked emails and 555 phone numbers, with no Id column.
- Budget: the worker overran the ~45-call estimate (36 calls plus 2 deploys plus spec runs) across two attempts.
- Left open for a follow-up card:
  - the F follow-up also shows the rerun table, and the structural fix is to pass the earlier result's Ids in history;
  - amounts show as raw numbers ("293920") in the table and drill view;
  - a group-by on an id field shows only counts.
