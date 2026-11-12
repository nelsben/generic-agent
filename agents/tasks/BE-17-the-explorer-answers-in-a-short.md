---
id: BE-17
title: The explorer answers in a short lead and leaves the rows to the table: the plain question "Which 5 open opportunities have the largest amounts?" fits question, answer and table header in the 340x480 panel, in agent-probe, with the explore assets recaptured
domain: backend
tier: frontier
tier_reason: prompt change shipped to a live org with a regression gate on the published agent and a by-eye recapture
status: queued
fixes: []
scope: [force-app/main/default/staticresources/AgentPrompt_Explore.resource, tests/test_explore_prompt.py, e2e/capture/04-explore.capture.js, docs/assets/explore-answer.png, docs/assets/explore-drill.gif, docs/assets/drill-view.png, docs/assets/MANIFEST.md, docs/patterns/02-ask-anything-explorer.md, docs/research/explore-prompt-1.md]
forbid: [force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, force-app/main/default/permissionsetgroups/**, scripts/**, data/**, agents/**, README.md, docs/plans/**, docs/reviews/**, e2e/panel.spec.js, e2e/support/**, playwright.config.js, playwright.capture.config.js, reference/**, .chassis-delegation.json]
resources: [org-live]
red_test: the explore capture with the plain question 'Which 5 open opportunities have the largest amounts?' fails its fit check in agent-probe before the prompt change (FE-10 run 1: 450 px needed against a 273 px box), and tests/test_explore_prompt.py fails on main
gate: test, jest, org
budget: 2-attempts
spend: 25
---
## Why

FE-10 found that the explorer writes every row into its answer text, against its own prompt rule 9 ("summarize rather than list every row"). Because of that, the explore capture had to add "Answer in one sentence." to its question to keep the table in view. A GTM screenshot should show the product answering the question a rep would actually type. The same prompt drives the published agent's explore path, so the agent spec must still pass.

## Done when

- Read first: force-app/main/default/staticresources/AgentPrompt_Explore.resource, force-app/main/default/classes/DataExplorer.cls (how the prompt is loaded and what the model sees), e2e/capture/04-explore.capture.js, e2e/capture/kit.js, e2e/README.md, docs/assets/MANIFEST.md, docs/patterns/02-ask-anything-explorer.md, docs/research/agent-iteration-1.md (spec table, and how the spec was run on v2) and docs/research/org-migration.md 'Stand the baseline up in a fresh org'. Load the skills salesforce-development:platform-metadata-deploy and agentforce-adlc:agentforce-test before any sf command
- Red first: in e2e/capture/04-explore.capture.js the question becomes exactly 'Which 5 open opportunities have the largest amounts?', and its comment about the tailored question is removed. Run only that capture file once against agent-probe before changing the prompt, and record its fit-check failure (needed px against box px) in the hand-back. If it unexpectedly fits, record that and continue
- Prompt: change rule 9 of AgentPrompt_Explore.resource so the answer text opens with one or two sentences that answer the question directly (a count, a total, the top item, or what stands out). It does not repeat the names and values of the rows the table will show, and it names at most three records. Every other rule keeps its meaning, and the output JSON format does not change. At most two prompt revisions in the org. tests/test_explore_prompt.py (new) asserts the new rule text and that rules 1 to 11 are all still present
- Org, agent-probe only, per the Approvals line 'Phase 2: cut and work new agent or design iteration cards in the new org': deploy only the staticresource. Validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1, relaying Ben's standing approval for agent-probe deploys. Never publish or activate an agent, never sign in or out, never touch the org this was first built in
- Measured: after the deploy, ask the plain question 3 times through the panel (the capture file or the e2e support helpers). The question, the answer and the table header row fit in the scroll box in 3 of 3 runs. Record each answer's text and the needed px against the box px. If the second revision still misses, redeploy the original resource the same way, revert the prompt and capture changes in git, record the evidence, and hand back gate=fail
- No regression: one full npm run test:e2e passes 8 of 8 (if spec 2 flakes on focus as FE-9 recorded, rerun it once and report both). The Account_Brief agent spec (tests/agent/Account_Brief-testSpec.yaml) is run once against the active version 2, the way agent-iteration-1.md ran it, and passes 16 of 16. If it passes fewer, redeploy the original resource, revert, and hand back
- Recapture only explore-answer.png, explore-drill.gif and drill-view.png, with that one capture file (SF_TARGET_ORG=agent-probe), keeping all the privacy machinery: masking, the 0.5 s checks, the all-frames checks and the 1 fps by-eye frame read. Every other file in docs/assets/ stays byte-identical (check with git diff --stat). Read each new PNG and every GIF frame at 1 fps by eye, and say in the hand-back what each one shows
- MANIFEST.md rows and the alt text and captions in docs/patterns/02-ask-anything-explorer.md match the new images exactly, and quote the plain question. Write docs/research/explore-prompt-1.md: the rule 9 change, the before and after answers, the fit numbers, the e2e and spec results, and the deploy steps in order. No record Ids, org Ids, usernames, emails, tokens, instance hostnames or URLs with query strings in any file or image
- Budget: about 30 model calls in the org (3 measured runs, the capture, e2e and the 16-case spec). Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, npm run test:unit, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit
