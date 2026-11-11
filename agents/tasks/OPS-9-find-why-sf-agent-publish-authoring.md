---
id: OPS-9
title: Find why `sf agent publish authoring-bundle` fails for Account_Brief in experimental and what the correct republish path is, in docs/research/agent-publish-failure.md
domain: ops
tier: standard
tier_reason: diagnosis from open-source CLI code, issues and read-only probes; one doc file
status: merged
scope: [docs/research/agent-publish-failure.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**, .claude/**]
red_test: none
gate: test
budget: 2-attempts
spend: 8
---
## Why

Publishing a new version of the Account_Brief agent fails every time, on CLI 2.154.4 and 2.157.8, with the agent active or deactivated, and even for the unchanged script that published as version 1 earlier the same day. A routing fix is finished but cannot go live. We need the cause from primary sources (the CLI plugin's code and issues) rather than more retries.

## Done when

- Diagnosis only. Change only docs/research/agent-publish-failure.md. Do NOT publish, activate, deactivate, deploy or change anything in the org, do not change CLI or Claude configuration, and do NOT use the Chrome browser tools (another task is using the browser). Read-only org commands against alias `experimental` are allowed: sf data query (including --use-tooling-api), sf org display with output filtered to non-secret fields, sf org list metadata, `sf agent validate authoring-bundle` if it exists and is read-only, and --help output of any sf agent command. Never print an access token
- Known facts, do not re-derive: org `experimental` is a Developer Edition on API 68.0. Agent Account_Brief (BotDefinition 0XxgK000002WVtxSAG, Agent Script authoring bundle at force-app/main/default/aiAuthoringBundles/Account_Brief, type AgentforceEmployeeAgent) has one BotVersion, v1, Active, published by the same command earlier on 2026-11-11. Now `sf agent publish authoring-bundle -o experimental -n Account_Brief --skip-retrieve --json` fails with `TypeError: fetch failed` whose cause is a connect timeout to the fallback host test.api.salesforce.com, after the first host api.salesforce.com returned 404. A manual replay of the publish body at POST https://api.salesforce.com/einstein/ai-agent/v1.1/authoring/agents/0XxgK000002WVtxSAG/versions with the CLI's JWT returned 401 {"message":"Error saving or updating agent graph"}; with the ordinary org token an empty 404. The compile call (/authoring/scripts) succeeds. It fails the same on CLI 2.154.4 and 2.157.8, with the agent active or deactivated, and for the unchanged v1 script. Between the working publish and the failures the org gained: permission sets Account_Brief_Agent_Access and Account_Brief_Data_Access (assigned to the admin), an AiEvaluationDefinition Account_Brief_Test created by `sf agent test create`, and later a Lightning app and utility bar
- Read the publish code path in the open-source CLI: the installed plugin under ~/.local/share/sf/client/*/node_modules/@salesforce/plugin-agent and @salesforce/agents (read the JS that implements publish authoring-bundle: which endpoints it calls in which order, how it chooses between creating a new agent and creating a new version of an existing one, how it finds the existing agent, what it does on 404, what --skip-retrieve skips, which token it uses). Cross-check with the GitHub repos salesforcecli/plugin-agent and forcedotcom/agents (gh api, raw.githubusercontent.com). Quote file paths and the relevant lines
- Search for the error: GitHub issues in salesforcecli/plugin-agent, forcedotcom/agents, forcedotcom/cli and forcedotcom/sf-skills for 'Error saving or updating agent graph', 'fetch failed' with publish, 404 on versions, and republishing an active agent; plus two or three web searches. Also read what forcedotcom/sf-skills says about publishing a new version of an existing Agent Script agent. Give each hit a URL and say whether it matches our symptoms
- Read-only org probes to test hypotheses, each recorded with command and result: BotDefinition and BotVersion rows for Account_Brief (all fields that could matter, such as status and any draft or in-progress version), GenAiPlannerBundle / GenAiPlannerDefinition and AiAuthoringBundle records and their versions via Tooling API or sf org list metadata, whether a draft or locked authoring bundle version exists, whether the AiEvaluationDefinition or the agent-access permission set references the agent version in a way that could block a new version, and whether local source differs from what is in the org (a retrieve into a scratch folder outside the repo is allowed)
- Write docs/research/agent-publish-failure.md: a 5-10 line plain answer first; then what the publish command actually does step by step (from the code); ranked hypotheses for the failure, each with the evidence for and against and the single cheapest test that would confirm it; the recommended next action, as exact commands or exact Agent Builder UI steps, with any risk to the active v1 stated; and what is still unknown. Mark each claim verified (you saw it in code or the org), documented (official source) or unverified (inference or community). Do not present a guess as the cause
- Keep the file under 200 lines. No tokens or secrets, no client names, no names of other apps or agents in the org, no content from reference/. Gate passes: test. Commit, do not push

## Review

Brain read docs/research/agent-publish-failure.md at 444527c: the publish path is traced from the installed CLI code and the CLI log; cause is not proven and the doc says so. Key facts: the failing call is POST .../authoring/agents/<botId>/versions returning 404 after ~6 s, the fallback to test.api.salesforce.com produces the misleading 'fetch failed'; both CLI builds ship the same @salesforce/agents 2.3.1, so the CLI update was not an independent test; local script equals the org draft. Next test is committing a version from Agentforce Studio. The doc carries the org Id; remove before the repo is shared.
