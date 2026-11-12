---
id: BE-2
title: Three flex prompt templates for the Account Brief: two pre-reduce summaries and the final synthesis
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/genAiPromptTemplates/AccountBrief_Summarize_Engagement.genAiPromptTemplate-meta.xml, force-app/main/default/genAiPromptTemplates/AccountBrief_Summarize_Deal_History.genAiPromptTemplate-meta.xml, force-app/main/default/genAiPromptTemplates/AccountBrief_Synthesis.genAiPromptTemplate-meta.xml]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/**]
red_test: bash scripts/validate-org.sh (the templates do not exist before; validate passes with 3 components after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

In the reduce step, prompt templates write all the prose the user reads and never query data; every fact they state arrives as an input produced deterministically upstream. Engagement and deal history are the heavy sections, so each gets a pre-reduce template, and one final template combines everything into the brief. The architecture reference is local and confidential; restate its patterns and never copy its client names: <repo>/reference/agent-landscape-guide/guide.md. Read sections 2.5, 6.3, 8.1 and 8.3. For the exact XML shape, see the retrieved example <repo>/reference/examples/<another org>/genAiPromptTemplates/Extract_Issue_Resolution_and_Summary.genAiPromptTemplate-meta.xml.

## Done when

- Three files under force-app/main/default/genAiPromptTemplates/, each with type `einstein_gpt__flex`, visibility Global, status Published, `primitive://String` inputs, and `activeVersionIdentifier` equal to `templateVersions/versionIdentifier`, ending in `_1` (keep them equal: section 8.1 of the guide). If the org rejects your identifier format, find a format that validates and record it as a choice
- AccountBrief_Summarize_Engagement: inputs `Account_Name`, `Contacts`, `Activity` and `Calls` (all required). Output: at most 1,200 characters of plain prose. It says who is engaged and who has gone quiet, the cadence and recency of touches, and what the most recent calls/meetings were about (from the call notes). It never invents a name, date, count or topic that is not in the inputs, and it says plainly when a section reads EMPTY
- AccountBrief_Summarize_Deal_History: input `Deal_History` (required). Output: at most 800 characters of plain prose covering the won/lost pattern, typical deal size and recency, using only the given figures
- AccountBrief_Synthesis: inputs `Account_Name`, `Profile`, `Open_Deals`, `Cases`, `Engagement_Summary`, `Deal_History_Summary` (required) and `User_Question` (not required). Output: plain text the agent relays verbatim, at most 4,000 characters total (the relay ceiling is about 6K; stay well under). It has a one-line headline that previews the most important real finding (never a restatement of the request), then these sections in this order, each starting with its label on its own line: `Account`, `Open deals`, `People & engagement`, `Service health`, `Deal history`, `Watch next` (2–4 bullets grounded only in the inputs). Where an input is EMPTY, the section says so in one line instead of being dropped. When User_Question is present, the headline answers it first
- Every template body explicitly instructs: use only the provided inputs; never invent facts, names, numbers or dates; no markdown headers, tables or JSON; `- ` bullets allowed; keep ids out of the prose. Inputs are referenced as `{!$Input:<Name>}`
- primaryModel: use an Anthropic Claude model alias the org accepts (try `sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet`, then other `sfdc_ai__Default*Claude*` names). Fall back to `sfdc_ai__DefaultGPT41` and then `sfdc_ai__DefaultOpenAIGPT4OmniMini` only if none validates. Use the same model on all three and record which one as a choice
- Both gates pass: `test` and `org` (check-only, so nothing is created in the org). Quote the `validate-org:` line in the hand-back. Do not deploy for real: the brain deploys templates before the Flows that call them

## Review

Brain review: accepted the departure from the card. The org caps flex templates at 5 custom inputs, so Synthesis takes Profile, Open_Deals, Cases, Relationship_Summaries (engagement + deal history summaries, labeled) and optional User_Question. The Flow card must build Relationship_Summaries with 'Engagement summary:' and 'Deal history summary:' labels. Model sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet validated. The amend line (scope+=none) is a no-op. Gate line: validate-org: pass (3 components, 0 tests).
