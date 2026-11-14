# Working with Models API prompts

A builder's guide to the prompts behind Customer Summary: what the Models API is, where each prompt's context comes
from, how to change that context, how to tune a prompt and try it in a minute, how to check it, what it costs, how to
switch one prompt to a prompt template and back, and how to work on prompts with an AI assistant. The pattern behind
it is [Model provider seam](../patterns/04-model-provider-seam.md), which says why the product is API first.

## What the Models API is

The Models API is Salesforce's direct call to a large language model, from Apex or REST, under the Einstein Trust
Layer. There is no builder UI: the code sends messages and gets text back.

How a call is made here:

1. A feature calls `AgentLlm.complete('<Name>', values, maxTokens)`. It never builds a prompt string.
2. `AgentLlm` reads the prompt's setting record in `Agent_Prompt_Setting__mdt` (the record named `<Name>`) and the
   prompt file, the static resource `AgentPrompt_<Name>`.
3. It fills the file's `{{placeholders}}` from `values` and adds any extra system lines (the brand's company and
   tone).
4. `AgentLlmModelsApi` sends one system message and one user message to the Models API's chat generations, with the
   model named on the setting.
5. The reply comes back as text, cut at about 4 characters per token of the maximum length. Any failure is one
   `AgentLlm.LlmException`.

The six prompts, their callers and their lengths:

| Prompt file | Called by | Gets | Max tokens |
| --- | --- | --- | --- |
| `AgentPrompt_BriefEngagement` | `CustomerSummary` | the contacts, activity and calls sections | 600 |
| `AgentPrompt_BriefDealHistory` | `CustomerSummary` | the deal history section | 400 |
| `AgentPrompt_SummarySynthesis` | `CustomerSummary` | the other sections, both condensed summaries, the question, the brand lines | 1,500 |
| `AgentPrompt_Sentiment` | `CustomerSentiment` | today's date, open deals, cases and both condensed summaries | 200 |
| `AgentPrompt_Explore` | `DataExplorer` | the question, the objects and fields it may query, the conversation so far and its earlier turns' results | 2,000 |
| `AgentPrompt_ActionDraft` | `CustomerSummaryActions` | today's date, the account name and the rep's request | 400 |

What the request takes: a model name and the messages. It has no maximum-token or temperature setting, so the
length comes from the prompt's own rule ("Stay under 800 characters") and the door's character cap
([fr2-model-door.md](../research/fr2-model-door.md#generation-settings)). The Trust Layer masks personal and payment
data on the way in when masking is on in Setup, unmasks it on the way out, and scores the reply for toxicity
([fr2-model-door.md](../research/fr2-model-door.md#what-the-trust-layer-does-on-each-path)).

## Where a prompt's context comes from

A prompt's context is everything in its user part: the values code fills into its placeholders. None of it comes
from the model. For the summary, it is the gather step of [Route, gather, reduce](../patterns/01-route-gather-reduce.md):

- **Sections.** Each section is one Apex class that reads one part of the account in the rep's own access and returns
  plain text, one fact per line, with a row cap and a length cap. For example `CustomerSummaryDealHistorySection`
  reads up to 5 closed deals and caps its text at 1,200 characters.
- **The registry.** `CustomerSummary.registry` lists the sections in summary order. `CustomerSummary.PRE_REDUCES` says
  which sections are condensed by a smaller prompt first (`BriefEngagement`, `BriefDealHistory`); every other section
  goes straight to `SummarySynthesis`.
- **The placeholder names.** A section's key is its placeholder: the `deal_history` section fills `{{deal_history}}`.
  A condensing prompt's output has its own name (`{{deal_history_summary}}`, `{{engagement_summary}}`).
- **Status lines.** A section that found nothing reaches the prompt as `EMPTY: ...`, one that failed as `ERROR: ...`,
  and one that was not asked for as `EMPTY: not requested`. Record Ids are removed before any text reaches a prompt.
- **System lines.** The brand's company and tone lines, and for the summary the account's earlier outcomes, are added
  after the prompt file's system text.

The other prompts get their context from their own feature: the explorer from its query loop, the sentiment from the
summary's reduced parts, the action draft from the rep's request.

## Add or change context

Three changes cover most needs. Each one is in Apex or in a prompt file, and each is deployed like any other change.

- **A field.** Add the field to the section's query and to the line it writes. The query runs `WITH USER_MODE`, so
  the rep must be able to read the field; grant it in the data-access permission set, or the section fails closed as
  `ERROR`.
- **A section.** Write one class that implements `CustomerSummarySource`, add one line to the registry, and name the
  section in the synthesis prompt. Pattern 01 has worked examples for case history and order history
  ([Swap a section for your industry](../patterns/01-route-gather-reduce.md#swap-a-section-for-your-industry)).
- **A cap.** Each section holds its own row cap (`ROW_CAP`) and length cap (`BODY_MAX`). A higher cap gives the model
  more lines and a longer prompt. The synthesis prompt's size is the sum of the caps, so raise one cap at a time.

**Worked example: say whether each closed deal was new business or a renewal.** This is an example, not shipped
code. The deal history prompt today covers the won and lost pattern, the deal size and how recent the deals are. A
team that sells renewals wants it to say which wins were renewals.

1. **The field.** In `CustomerSummaryDealHistorySection`, add `Type` to the query of closed deals, and add it to each
   line:

```apex
// Example, not shipped code. In CustomerSummaryDealHistorySection.load():
List<Opportunity> rows = [
    SELECT Id, Name, Amount, CloseDate, IsWon, Type
    FROM Opportunity
    WHERE AccountId = :accountId AND IsClosed = true
    WITH USER_MODE
    ORDER BY CloseDate DESC NULLS LAST, Id
    LIMIT :ROW_CAP
];
// ...
String line = '- ' + CustomerSummarySection.clip(o.Name, 100)
    + ' — ' + (o.IsWon ? 'Won' : 'Lost')
    + ' — ' + (String.isBlank(o.Type) ? 'no type' : o.Type)
    + ' — ' + (o.Amount == null ? 'no amount' : CustomerSummarySection.money(o.Amount))
    + ' — closed ' + CustomerSummarySection.fmtDate(o.CloseDate);
```

2. **The access.** Check that the data-access permission set grants read on `Opportunity.Type`. If it does not, the
   section returns `ERROR` for a rep, and the summary says that part could not be loaded.
3. **The prompt.** In `AgentPrompt_BriefDealHistory`, add one line to the "Cover" list in the system part:
   `- Which wins were new business and which were renewals.` The placeholder `{{deal_history}}` stays as it is, so
   no Apex variable changes.
4. **The cap.** Each line is now a few words longer, and the body cap of 1,200 characters still holds, so a long
   history shows fewer lines and ends on "…and N more not shown". Leave the cap unless the most recent deals are
   being cut.
5. **The test.** Add an assertion to `CustomerSummaryDealHistorySectionTest` that a line carries the deal's type.
6. **Try it** with `scripts/prompt-try.apex` and `PROMPT = 'BriefDealHistory'` (see [Try it in a minute](#try-it-in-a-minute)).

A new placeholder works the same way: add `{{name}}` to the prompt's user part and put `name` in the values the
caller passes. A placeholder with no value is an error (`Prompt X needs a value for {{name}}.`), so a rename that
misses one side fails at once instead of sending an empty part.

## Tune a prompt

A prompt file is plain text with two parts:

```text
---system---
Role: one line on what this prompt does and who reads the answer.

Rules:
1. Use only the inputs in the user message. ...
2. ...

What to cover, in order. ...

Return only the ..., with no preamble and no closing remarks.
---user---
Deal history:
{{deal_history}}
```

- **The system part** says what the model is, the numbered rules, the shape of the answer and what to cover. It is
  the same for every account. Change the wording here.
- **The user part** holds only labels and placeholders. It is the data. Keep instructions out of it, so a value can
  never be read as an instruction.
- **The tone line.** The brand settings record (`Brand_Setting__mdt`, record `Default`) holds `Tone__c` and the
  company name. `SummarySynthesis` and `Explore` get them as two lines after their system text. Changing the tone
  changes the voice of every summary and explorer answer, not the facts. See
  [Brand and theming](../patterns/10-brand-and-theming.md).
- **Rules.** Keep them numbered and short, one behaviour each. The shipped prompts share three that matter: use only
  the inputs and never invent numbers, names or dates; keep record ids out; and say plainly when an input reads
  `EMPTY` or `ERROR`. Keep those three when you change a prompt. A rule that names a failure the model made ("Do not
  compute new totals unless the input states them") works better than a general one.
- **Examples.** A short example of the wanted output, in the system part, shows the shape faster than a rule does.
  Use made-up values, never a real customer's, and say it is an example so the model does not repeat its figures.
- **Length.** Two controls work together. The prompt's own rule ("Stay under 800 characters") is what the model aims
  for. `Max_Tokens__c` on the setting record sets the door's cut, at about 4 characters a token (400 tokens is about
  1,600 characters). Keep the prompt's rule well under the cut, so the cut does not fire: the door's cut adds no marker.
- **The model.** `Model__c` on the setting record names the model for that prompt, for example
  `sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet`. Blank means the fallback in `AgentLlmModelsApi.MODEL`. The model
  must be enabled for the Models API in your org. Change one prompt's model at a time, and try it.

## Try it in a minute

1. **Change the file.** Edit `force-app/main/default/staticresources/AgentPrompt_<Name>.resource`.
2. **Deploy it.** In a sandbox or scratch org, deploy that one file:

```bash
sf project deploy start --source-dir force-app/main/default/staticresources/AgentPrompt_BriefDealHistory.resource --target-org <your org>
```

   In a production org, validate with tests and then quick deploy, as for any change.
3. **Run the try script.** Set `PROMPT` (`BriefDealHistory`, `BriefEngagement` or `SummarySynthesis`) and `SAMPLE`
   (0 to 4, accounts from the seed data) at the top of `scripts/prompt-try.apex`, then:

```bash
sf apex run --file scripts/prompt-try.apex --target-org <your org> --json
```

4. **Read the lines that start `TRY|`** in the debug log in the JSON (the log escapes `|` as `&#124;`): the setting
   and source, the reply length, the gather and model time, the summary session count before and after, and the
   reply with the account's name replaced. It writes no record. `SummarySynthesis` runs the two condensing prompts
   first, so it spends 3 model calls; the others spend 1. The output for one run is on the
   [pattern page](../patterns/04-model-provider-seam.md#see-it).

**The prompt trace** shows exactly what was sent. Set `Trace__c` to true on the prompt's setting record (in Setup,
Custom Metadata Types, or in the repo and deploy). Each run of that prompt then writes lines that start
`AgentLlm trace <Name>` to the debug log at INFO: the filled system text, the filled user text and the reply length.
On the template path it writes the template name and each input instead. Record Ids become `[id]`. The filled text
holds CRM data, so turn the trace on only to debug, and off after. `AgentLlm` writes it just before the provider call,
so it shows what Apex sends to the provider.

## Check accuracy

`scripts/summary-accuracy.apex` checks that the numbers in a live summary come from the gathered sections
([fr2-summary-accuracy.md](../research/fr2-summary-accuracy.md)):

- It runs one full summary for one sample account (`SAMPLE`, 0 to 4), lists every date, dollar amount, percent and
  whole number in the answer, and looks for each one in the section text the model was given.
- It prints only counts and checks on lines that start `ACC|`, plus each unmatched value with the answer section it
  is in. It never prints a name, an Id or the answer text.
- It also checks that a section that failed is reported as not loaded, not as "none".
- Run it on all five samples after any change to the synthesis prompt or a section. The first run found 83 of 84
  numbers in a section; the other was a correct sum the model computed.
- What it cannot catch: a real number given to the wrong deal, and numbers written as words. Wording changes from run
  to run, so one clean run does not promise the next. Read a few answers yourself as well.
- It writes the product's own memory row for you and the account, as any summary does, and spends up to 4 model
  calls.

## What each call costs

- **One call is one request.** Every Models API request counts against the org's Einstein Requests, its generative
  AI usage ([fr2-model-door.md](../research/fr2-model-door.md#how-each-call-counts-against-generative-ai-usage)).
- **How it is metered is unconfirmed.** A help article says prompts are metered in 2,000-token chunks, rounded up;
  that usage shows in Digital Wallet; that Einstein Requests are used before Flex Credits; and that batch, scheduled
  and automated runs are always metered. Whether a template call counts the same is also unconfirmed. Treat each
  `AgentLlm.complete` as one request either way.
- **Per feature:**

| What a rep does | Model calls |
| --- | --- |
| One summary | up to 4: two condensing prompts (each skipped when its sections are empty), the synthesis, and the sentiment |
| One explorer question | up to 5, one per turn of its query loop |
| One action draft | 1 |
| One `prompt-try.apex` run | 1, or 3 for `SummarySynthesis` |
| One `summary-accuracy.apex` run | up to 4, as one summary |

- **Rate limits.** In production, 10,000 requests a minute per org per endpoint, lower for some models; a trial org
  150 an hour; a sandbox, from Apex, 500 an hour. Over the limit the call fails with HTTP 429, which the feature
  shows as its plain failure sentence
  ([fr2-model-door.md](../research/fr2-model-door.md#time-and-rate-limits)).
- **Time.** Model calls share one transaction's callout allowance of 120 seconds. A shorter prompt and a shorter
  answer are faster as well as cheaper.

## Switch one prompt to a template and back

The switch is a field on the prompt's setting record, so the feature code never changes. The repo ships a sample:
`Customer_Summary_Deal_History`, a flex template with one free-text input, `Deal_History`, copied from
`AgentPrompt_BriefDealHistory`. Its setting record already names it.

**To a template:**

1. **Build the template** in Prompt Builder (or copy the sample in `force-app/main/default/genAiPromptTemplates/`).
   Give it a free-text input for each value the prompt needs, and activate it.
2. **Map the inputs.** On the prompt's record, set `Template_Name__c` to the template's API name and
   `Template_Inputs__c` to `variable=Input_Name` pairs separated by `;`, for example `deal_history=Deal_History`. To
   pass the brand lines, map the variable `system_suffix` to an input.
3. **Grant access.** Anyone who runs the prompt needs the Execute Prompt Templates permission. The user group
   `Customer_Summary_User` does not grant it today, so until it does, switch a prompt only for admins and tests.
4. **Flip the source.** Set `Source__c` to `Prompt_Template` and deploy the record (or change it in Setup).
5. **Try it.** Run `scripts/prompt-try.apex` for that prompt. The first `TRY|` line now says
   `source=Prompt_Template`. On this path the maximum length is sent to the template as its own setting, and the
   door's cut stays as a backstop.

**And back:** set `Source__c` to `Static_Resource`, deploy, and run the try script again; the line says
`source=Static_Resource`. The template stays in the org, unused.

What changes for the builder on the template path: the prompt text lives in Prompt Builder, not the file, so edit it
there and activate a new version. The trace shows the template's name and inputs, not the resolved template text.

## Work on prompts with an AI assistant

Prompts are files so that a team can work on them with Claude or another AI app. A loop that works:

1. **Give it the file.** Paste the whole prompt file, both parts.
2. **Give it what was sent.** Paste the trace lines for one run, so it sees the filled user part. Check your company's
   rules first: the trace holds CRM data. Use the seed data's sample accounts, or remove names and figures.
3. **Give it a failing answer.** Paste the reply and say exactly what is wrong ("it adds the overdue amounts into a
   total no section states", "it drops Service health when cases are EMPTY").
4. **Ask for one change.** Ask for the smallest edit to the system part that fixes it, keeping every placeholder and
   the rules on inputs, ids, `EMPTY` and `ERROR`.
5. **Try it.** Deploy the file and run `scripts/prompt-try.apex` on two or three samples, not one. For the synthesis,
   run `scripts/summary-accuracy.apex` too.
6. **Keep or revert.** Keep the change only if the answers got better on every sample you tried; the file is in git,
   so reverting is one command.

An assistant that can read the repo can also do steps 1 and 5 itself: point it at the prompt file, this guide and the
try script.

[Back to the pattern page](../patterns/04-model-provider-seam.md) | [Back to the README](../../README.md)
