---
id: BE-36
title: FR2: customer sentiment — a focused model call scores the customer's sentiment from the gathered activity, cases and deals at each summary, stored on the summary's outcome with a label and a one-line reason, checked for accuracy on sample accounts
domain: backend
tier: frontier
tier_reason: a new model judgement customers will see as a trend line, so its accuracy and its failure mode matter
status: queued
fixes: []
scope: [force-app/main/default/classes/CustomerSentiment.cls, force-app/main/default/classes/CustomerSentiment.cls-meta.xml, force-app/main/default/classes/CustomerSentimentTest.cls, force-app/main/default/classes/CustomerSentimentTest.cls-meta.xml, force-app/main/default/classes/CustomerSummary.cls, force-app/main/default/classes/CustomerSummaryTest.cls, force-app/main/default/staticresources/AgentPrompt_Sentiment.resource, force-app/main/default/staticresources/AgentPrompt_Sentiment.resource-meta.xml, force-app/main/default/customMetadata/Agent_Prompt_Setting.*, scripts/sentiment-check.apex, docs/research/fr2-sentiment.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, mcp-door/**, spikes/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new CustomerSentimentTest cases fail on main (the class does not exist) and pass after
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 05: "we also want to be able to show a graph of change in customer sentiment over time". Each summary already gathers the activity, cases and deals that sentiment comes from, so one focused model call can score it, following the focused-call pattern of pattern 01. Covers ledger row F77 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md (rows F74 to F80), docs/plans/fr2-design.md ('Operating principles'), docs/patterns/01-route-gather-reduce.md, docs/research/fr2-customer-outcomes.md (BE-35), docs/research/fr2-model-door.md (BE-33) and docs/research/fr2-summary-accuracy.md (BE-29). Load the skills salesforce-development:platform-apex-generate and salesforce-development:platform-apex-test-generate first
- A prompt AgentPrompt_Sentiment, with its own prompt setting (BE-33), takes the gathered sections already reduced for the summary (no new queries) and returns a score from -2 (at risk) to +2 (very positive), a label and one plain-English reason that names the evidence (for example "two escalated cases and a slipped renewal"). Sparse data returns "Not enough activity" with no score, never a guess. CustomerSentiment parses it strictly; anything malformed is stored as no score, and the summary still returns
- CustomerSummary runs it in the same reduce step as the other focused calls, within the model-call budget BE-29 left, and writes it onto the summary's outcome (BE-35). Tests with Assert.* and a scripted model cover each score, sparse data, malformed output, a model failure, and the budget
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- **Accuracy:** scripts/sentiment-check.apex scores sample accounts in agent-probe whose expected direction is known (for example one with escalated cases and one with recent wins), three runs each, and prints only the expected and returned label per run. Use only existing seed-data accounts; never insert or backdate a record to make a case. Record agreement and run-to-run stability in docs/research/fr2-sentiment.md, with a recommendation on whether the score is steady enough to chart. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit
