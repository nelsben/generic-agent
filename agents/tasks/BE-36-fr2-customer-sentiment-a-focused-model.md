---
id: BE-36
title: FR2: customer sentiment — a focused model call scores the customer's sentiment from the gathered activity, cases and deals at each summary, stored on the summary's outcome with a label and a one-line reason, checked for accuracy on sample accounts
domain: backend
tier: frontier
tier_reason: a new model judgement customers will see as a trend line, so its accuracy and its failure mode matter
status: merged
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

## Review

Brain review (2026-11-14). One attempt (574945a). The verifier found the report consistent, and a sonnet review returned 18 confirmed, 0 refuted, 5 unverifiable. The unverifiable rows are the live-run results, the org row counts, the org deploy figures, the first prompt's wording (only one commit exists) and the real-time behaviour of the 90 s model-time cap.

Findings:
- New class CustomerSentiment makes one focused model call per summary, after the synthesis. It reads open deals, cases, the engagement summary, the deal history summary and today's date. It sends no profile, account name or outcome context, and Max_Tokens is 200.
- It stores a score from -2 to +2, a label (At risk, Concerned, Neutral, Positive, Very positive) and a one-line reason on the summary's outcome.
- The reply must be strict JSON {score,label,reason}. One code fence around it is tolerated. The label must match the score, and the reason must be one line of at most 255 characters. Any malformed reply or model failure leaves all three empty and never throws.
- Sparse data: when no evidence section is OK, Apex skips the call and stores "Not enough activity". The prompt also returns it when fewer than two signals of activity are present. Absence of deals or cases does not count as a signal.
- A partial or failed summary gets no sentiment.
- Budget: at most one sentiment call per brief, so 4 model calls per summary and 12 at the 3-brief cap. The call is skipped once the transaction's model time reaches 90 s.
- CustomerSummary changes only private members; the Result/Response shape is unchanged.
- New Agent_Prompt_Setting.Sentiment record and AgentPrompt_Sentiment static resource (Static_Resource source).
- New scripts/sentiment-check.apex: read-only, no DML.
- New doc docs/research/fr2-sentiment.md.
- CustomerSentimentTest has 35 test methods covering each score, sparse data, malformed output, model failure and the time budget.

Gate (verifier at 574945a): 176 Python tests, validate-org pass (146 components, 422 tests). Worker: check-docs 63 pages, 0 broken.

Org (worker's account): two scoped validates with RunLocalTests (515 tests, 0 failures each), each followed by a quick deploy under the standing row. The second deployed only the revised static resource.

Live check, under the approved live-checks row (worker's account): 3 seed accounts, 3 runs each, on two prompt versions.
- Agreement with the expected direction set before the runs: 6 of 9 on the first prompt, 5 of 9 on the second.
- Edge Communications was At risk 6 of 6.
- United Oil & Gas, UK was Positive 3 of 3 on the first prompt. After the rule-4 fix it returned Not enough activity twice and no score once.
- Brindlewick Hydroponics was Positive 3 of 3, then Concerned 3 of 3. Its records sum to Neutral under the rubric, so the model's arithmetic is unstable.
- The prompt was changed after seeing the results, and the doc says so.
- The doc recommends showing the label but not charting the score until Apex does the arithmetic.

Org writes outside the deploy: Customer_Summary_Session__c went from 9 to 12, and Customer_Outcome__c from 31 to 49. No records were inserted or backdated, and no user was created.

Disclosed and accepted:
- The org and live figures are the worker's account; nothing in git shows them.
- The org gate was moved to the background automatically; the worker was told to wait for it and then report.
- The worktree's gitignored .sf/config.json was set to agent-probe for the deploy hook, then unset.
- The worker made two gate fix rounds, both within the stop rule: a missing meta file, and a null assert message plus a prompt count changed from 3 to 4.
- A tests/__pycache__ made by the gate runs was removed before review and before merge.

Still open:
- The score is not steady enough to chart. Moving the arithmetic to Apex (the model returns signal counts, Apex sums them) is a candidate follow-up card, and the trend graph should wait for it.
- e2e/README.md still says a summary makes 3 model calls; it is now 4.
- Outcome rows on the seed accounts keep accumulating; deleting them, or scheduling the purge job, is Ben's call.

Privacy grep over the diff (1,098 added lines): 0 hits.
