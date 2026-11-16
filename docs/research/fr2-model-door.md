# FR2: the model door (BE-33)

`AgentLlm` is the one door to a model. BE-33 puts a setting on each prompt, adds a second way to run one (a Prompt Builder
template), and adds a trace and a try script. This page has the platform facts first, then what was built, then the live run.

Facts marked **unconfirmed** come from search summaries or inference, not from a page read in full. Developer docs are
linked. Help articles are named by title only, because their links carry the article in a query string.

## The facts

### Generation settings

| Path | What the request takes | Max tokens | Temperature |
| --- | --- | --- | --- |
| Models API from Apex (`aiplatform.ModelsAPI.createChatGenerations`), used by `AgentLlmModelsApi` | `modelName`, plus a body with `messages`, `localization` and `tags`. The org (API 68.0) also serialises a `contentModeration` field. | no | no |
| Prompt template (`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`), used by `AgentLlmPromptTemplate` | `inputParams` (each key is `Input:<name>`), `isPreview`, and `additionalConfig` with `applicationName` (required), `maxTokens`, `temperature`, `stopSequences`, `numGenerations`, `frequencyPenalty`, `presencePenalty`, `enablePiiMasking` | yes | yes |

- The public Models API OpenAPI file has no max-token, temperature, stop-sequence or penalty field. A test pins this:
  `AgentLlmModelsApiTest.theRequestCarriesNoGenerationSettings` fails if the body gains a field.
- So on the Models API path, the length is the character cap in `AgentLlm` (about 4 characters a token). On the template
  path, `maxTokens` is sent, and the cap stays as a backstop.
- Sources: [Models API Apex classes](https://developer.salesforce.com/docs/ai/agentforce/references/models-apex-api/models-apex-reference.html),
  [Models API REST reference](https://developer.salesforce.com/docs/ai/agentforce/references/models-api),
  [EinsteinLLM class](https://developer.salesforce.com/docs/platform/apex-ref/references/apex-ref/apex-connectapi-einsteinllm-static-methods.html),
  [EinsteinPromptTemplateGenerationsInput](https://developer.salesforce.com/docs/platform/apex-ref/references/apex-ref/apex-connectapi-input-einstein-prompt-template-generations.html),
  [EinsteinLlmAdditionalConfigInput](https://developer.salesforce.com/docs/platform/apex-ref/references/apex-ref/apex-connectapi-input-einstein-llm-additional-config.html),
  [Resolve a prompt template](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/connectapi-examples-resolve-prompt-template.html).

### What the Trust Layer does on each path

| | Models API | Prompt template |
| --- | --- | --- |
| Masking | PII and PCI are masked and the reply unmasked, when masking is on in Setup and the locale is supported. There is no per-call switch. With masking on, context is limited to 65,536 tokens. | The same org setting, plus `enablePiiMasking` per call. Masking details come back in the response. |
| Grounding | None. The prompt is whatever Apex sends, so the caller grounds it: section text built in user mode, record Ids removed. (Inference: the docs describe grounding only for templates.) | Merge fields and data providers resolve as the running user. `Customer_Summary_Deal_History` has no merge fields: its one input is free text built by Apex, so it grounds exactly as the file path does. |
| Toxicity | Scored by default, returned in `contentQuality`. | Scored, returned on each generation item. |
| Audit | Masking events and scores go to the audit trail in Data 360, if audit and feedback are set up (unconfirmed: needs Data 360, appears within 24 hours, uses Data 360 credits). | The same. |
| Retention | Zero data retention at third-party model providers. | The same. |

Sources: [Data masking with Models API](https://developer.salesforce.com/docs/ai/agentforce/guide/models-api-data-masking.html),
[Toxicity scoring with Models API](https://developer.salesforce.com/docs/ai/agentforce/guide/models-api-toxicity-scoring.html),
help article "Einstein Trust Layer", help article "Set Up Einstein Generative AI Audit and Feedback" (unconfirmed).

### How each call counts against generative AI usage

- Every Models API request is subject to Einstein Requests usage and billing
  ([Access Models API with Apex](https://developer.salesforce.com/docs/ai/agentforce/guide/access-models-api-with-apex.html)).
- Unconfirmed (help article "Metering for Agentforce and Generative AI Usage"):
  - Prompts are metered in 2,000-token chunks, rounded up.
  - Usage shows in Digital Wallet. Einstein Requests are used up before Flex Credits.
  - Batch, scheduled and Automated Process runs are always metered.
- Unconfirmed: whether a template call and a Models API call count the same way. Treat each `AgentLlm.complete` as one
  request either way.
- One summary is up to 4 requests (two pre-reduces, the synthesis and the sentiment call). One `prompt-try.apex` run is 1 request (3 for
  SummarySynthesis).

### Time and rate limits

- Apex callouts ([Callout limits](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-callouts-timeouts.html)):
  - 10 s default and 120 s maximum per callout.
  - 120 s in total per transaction, and 100 callouts per transaction.
  - No callout after uncommitted DML in the same transaction.
  - The Models API Apex methods are subject to these.
- The template call is not counted as an Apex callout. In the live run below, a 5.2 s template call left "Number of
  callouts: 0" in the debug log. It still spends wall time, and it still cannot follow uncommitted DML (unconfirmed for the
  template call).
- Models API rate limits ([Rate limits](https://developer.salesforce.com/docs/ai/agentforce/guide/models-api-rate-limits.html)):
  - Production: 10,000 requests a minute per org per endpoint, lower for some models.
  - Trial orgs: 150 generation requests an hour.
  - Sandbox, from Apex: 500 an hour.
  - Over the limit returns HTTP 429.

## The prompt setting

`Agent_Prompt_Setting__mdt` has one record per prompt, named after the prompt (the same name as `AgentPrompt_<name>`).

| Field | Meaning | Empty means |
| --- | --- | --- |
| `Model__c` | Model API name for the Models API path, for example `sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet` | `AgentLlmModelsApi.MODEL`, the fallback |
| `Max_Tokens__c` | Maximum reply length in tokens. It wins over the caller's value. Sent to the template; on the Models API path it sets the character cap. | the caller's value |
| `Source__c` | `Static_Resource` (Static resource, the default) or `Prompt_Template` (Prompt template) | Static resource |
| `Template_Name__c` | Prompt template API name, used when Source is Prompt template | an error on the template path |
| `Template_Inputs__c` | `variable=Input_Name` pairs separated by `;`, for example `deal_history=Deal_History`. The variable `system_suffix` carries the brand lines. | no inputs |
| `Trace__c` | Writes the filled prompt and the reply length to the debug log | off |

- A prompt with no record runs exactly as before.
- Records ship for BriefEngagement (600), BriefDealHistory (400), SummarySynthesis (1500) and Explore (2000), each with
  today's model, the static-resource source and the trace off. These are the lengths the callers pass today.
- BriefDealHistory's record also names the sample template and its input, so switching it over is one field.
- Change a record in Setup, Custom Metadata Types, or in the repo with a validate and a quick deploy.
- `AgentLlm` reads the records with SOQL in system mode, once per transaction. Why not user mode: see the next section.
  SOQL, not `getInstance`, because `getInstance` returns only the first 255 characters of each field.
- Tests never read the org's records unless a test asks for them, so a changed record cannot break another class's test.

## Prompt files for reps (N11)

The question: can a rep who holds only the user group (`Customer_Summary_User`, which holds only
`Customer_Summary_Data_Access`) read the prompt files in user mode?

A throwaway Apex test, never saved and run only in a check-only validate, created test users and ran the reads as each one.

| Read | Standard User, no set | Minimum Access, no set | Minimum Access + data-access set |
| --- | --- | --- | --- |
| `StaticResource` `WITH USER_MODE` | reads | reads | reads |
| A custom metadata type `WITH USER_MODE` | fails ("not supported") | fails | reads, for a type the set grants |
| A custom metadata type by `getInstance` | reads | reads | reads |

- Answer: yes. `AgentLlm.loadPrompt` now reads the prompt files `WITH USER_MODE`, and BE-37's `system-context` marker
  is gone. `AgentLlmTest.aRepWithTheUserGroupsDataSetReadsPromptFilesAndSettings` proves it in every validate, as a
  Minimum Access user holding the data-access set. FE-5 proves it as a real rep.
- The new setting type is read in system mode, under a marker. The data-access set does not grant it, and permission
  sets were outside this card. Adding read access to `Agent_Prompt_Setting__mdt` in `Customer_Summary_Data_Access` would
  let the read move to user mode: a follow-up for the card that owns the permission set.
- A prompt template has its own access, and it is not covered. Running one needs the Execute Prompt Templates
  permission, from the Prompt Template User set or Customize Application (unconfirmed: help articles "Enable Prompt
  Builder" and "Give Users Access to a Prompt Template"). The user group grants no user permission at all. So:
  - The template path works for an admin today, which is what the live run used.
  - Before any prompt is switched to a template for reps, the user group needs Execute Prompt Templates. Until then, keep
    every setting on Static resource.
  - Connect in Apex does not support `System.runAs`
    ([Testing ConnectApi code](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/connectapi-testingapex.html)),
    so a template run as a rep can only be proved live (FE-5), not in an Apex test.

## The template path

- `AgentLlmPromptTemplate` implements `AgentLlm.TemplateProvider`. `AgentLlm` reaches it by class name, as it reaches
  `AgentLlmModelsApi`.
- It sends each mapped input as `Input:<name>`, `isPreview` false, and `applicationName` `PromptTemplateGenerationsInvocable`
  with `maxTokens`. It returns the first generation's text.
- Every failure is an `AgentLlm.LlmException`, with the cause kept: a blank name, a failed call, no text, an unknown
  variable, or a bad input map.
- The sample template `Customer_Summary_Deal_History` (flex, one free-text input `Deal_History`, Published) is a copy of
  the BriefDealHistory prompt file. It is in the org, and nothing uses it while BriefDealHistory's Source is Static resource.
- In tests, a provider stub wins over a template source unless a template stub is set, so no existing test calls a template.

## The trace

- Set `Trace__c` on one prompt's record. Each run of that prompt then writes lines starting `AgentLlm trace <prompt>` to the
  debug log at INFO:
  - On the file path: the filled system text, the filled user text and the reply length.
  - On the template path: the template name, each input and the reply length.
- Record Ids, 15 or 18 characters, become `[id]`.
- It never writes in a test run. Tests read the lines from a list instead.
- The filled text holds CRM data, so turn the trace on only to debug, and off after.

## Trying one prompt

`scripts/prompt-try.apex` runs one prompt for one sample account. Set `PROMPT` (BriefDealHistory, BriefEngagement or
SummarySynthesis) and `SAMPLE` (0 to 4) at the top, then:

```
sf apex run --file scripts/prompt-try.apex --target-org agent-probe --json
```

- It builds the variables from the gather sections the way `CustomerSummary` does, and calls `AgentLlm.complete`, so the
  prompt's setting applies.
- It prints `TRY|` lines: the setting and source, the reply length, the gather and model time, the summary session count
  before and after, and the reply with the account's name replaced.
- It writes no record.

## The live run (2026-11-13, agent-probe)

- Deploys, each a validate with RunLocalTests and then a quick deploy (365 tests, 0 failures each time):
  1. This card's 18 components (the classes, the setting type and its four records, the sample template).
  2. BriefDealHistory's Source set to Prompt template.
  3. Set back to Static resource. A retrieve afterwards read `Static_Resource` from the org.
- One run of `prompt-try.apex` with BriefDealHistory, on sample 1, the seed account Edge Communications. It printed:
  - `setting=true source=Prompt_Template model_calls=1`
  - `reply_chars=407 gather_ms=94 model_ms=5222`
  - `sessions_before=5 sessions_after=5`
  - The reply was plain prose about the won and lost pattern and the deal sizes, inside the prompt's 800-character rule.
- Rows written: 0 summary sessions (5 before and after) and 0 outcome rows (there is no outcome object in the org yet).
- Debug log limits: 5 SOQL queries, 0 DML, 0 callouts.

## A provider outside Salesforce

Research only: nothing here is built. Everything in this section is **unconfirmed**: it was not read on a Salesforce page
for this card.

| | Model registered in Einstein Studio (bring your own model), reached through the Models API | Direct callout from Apex through a Named Credential |
| --- | --- | --- |
| Code change | None: put the registered model's API name in `Model__c` | A new `AgentLlm.ModelProvider` class, named in `PROVIDER_CLASS` or chosen by a new setting |
| Trust Layer | Applies, as for Salesforce-hosted models (masking, toxicity, audit). Zero retention depends on your contract with the provider. | None. No masking, toxicity scoring or audit trail, and retention is whatever the provider's terms say. The sections still reach it with record Ids removed. |
| Usage billing | Still counted as generative AI usage in Salesforce, and also billed by the provider | Not metered by Salesforce. Billed only by the provider. |
| Model choice | Models that Einstein Studio supports for registration | Any model with an HTTP API |
| Setup | Einstein Studio: add the model with the provider's endpoint and key, then use its API name | An External Credential holding the key, a Named Credential for the endpoint, and principal access granted in a permission set (which reps would need too). Callout limits apply in full. |

For this product, the first shape keeps the Trust Layer and needs no code. Prefer it unless a model is
needed that Einstein Studio cannot register.

## Undo

Not recorded on this page. The work deployed to `agent-probe` or ran there, but the page lists nothing to remove.
