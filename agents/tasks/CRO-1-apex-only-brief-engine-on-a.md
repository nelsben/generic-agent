---
id: CRO-1
title: Apex-only brief engine on a direct model API: an LLM seam, prompts as repo text, a pluggable source registry with include flags, and one Get Brief invocable
domain: cross
tier: frontier
tier_reason: sets the architecture every later card builds on; cross-cutting refactor of seven classes plus a new model seam
status: merged
scope: [force-app/main/default/classes/AgentLlm*.cls, force-app/main/default/classes/AgentLlm*.cls-meta.xml, force-app/main/default/classes/AccountBrief.cls, force-app/main/default/classes/AccountBrief.cls-meta.xml, force-app/main/default/classes/AccountBriefTest.cls, force-app/main/default/classes/AccountBriefTest.cls-meta.xml, force-app/main/default/classes/AccountBriefSource.cls, force-app/main/default/classes/AccountBriefSource.cls-meta.xml, force-app/main/default/classes/AccountBriefGetAction.cls, force-app/main/default/classes/AccountBriefGetAction.cls-meta.xml, force-app/main/default/classes/AccountBrief*Section.cls, force-app/main/default/classes/AccountBrief*SectionTest.cls, force-app/main/default/staticresources/AgentPrompt_Brief*, force-app/main/default/genAiPromptTemplates/**, docs/ARCHITECTURE.md]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/AccountBriefResolver*.cls, force-app/main/default/classes/AccountBriefMemory*.cls, force-app/main/default/classes/AccountBriefSection.cls, force-app/main/default/objects/**]
red_test: bash scripts/validate-org.sh (AccountBriefTest and AgentLlmTest absent before; pass after)
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Ben chose Apex only (no Flows) and direct model API calls (no prompt templates) as the cleaner agent-forward pattern. This card builds the core every later card stands on: one small seam that is the only place Apex talks to a model, prompts kept as versioned text files rather than Apex strings, and one engine entry point that gathers the seven existing deterministic sections and has the model reduce them. It must be concise (one entry point) and flexible (a new source is one class and one registry line; callers pick sections with include flags; a new model provider is one class).

## Done when

- Read first: <repo>/reference/agent-landscape-guide/guide.md (the route/gather/reduce operating pattern; confidential, so never copy its client names, objects or prose into the repo), then every AccountBrief*.cls on main
- LLM seam: `AgentLlm.cls` with `public interface Provider { String complete(String systemPrompt, String userPrompt, Integer maxTokens); }` and `public static String complete(String promptName, Map<String,String> vars, Integer maxTokens)`. It loads the prompt, fills `{{name}}` placeholders, calls the active provider and returns the text. It has a `@TestVisible static Provider stub` so tests never call a model. It is the only class other code calls for a model
- Default provider `AgentLlmModelsApi.cls` calls the Salesforce Models API from Apex (aiplatform.ModelsAPI chat generations) with model `sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet`, held in one constant. It is the only class in the repo that references `aiplatform.*`. Confirm the exact request and response class names against the experimental org by compiling (check-only). If the org gate cannot compile aiplatform, stop and say so in the hand-back; do not swap in another API
- Prompts are text, not Apex strings: static resources `AgentPrompt_BriefEngagement`, `AgentPrompt_BriefDealHistory`, `AgentPrompt_BriefSynthesis` (text/plain .resource files with meta), each with a `---system---` part and a `---user---` part. Port the wording, rules, caps and section order from the three files in force-app/main/default/genAiPromptTemplates/, then delete that folder from the repo. Synthesis no longer needs the 5-input workaround, so pass engagement and deal-history summaries as separate variables. Do not delete anything from the org
- `AccountBriefSource` interface: `String key(); String title(); AccountBriefSection build(Id accountId);`. All seven section classes (Profile, OpenDeals, Cases, Contacts, Activity, Calls, DealHistory) implement it; keep or remove their static build(Id) as you see fit, with every test green
- `AccountBrief.cls` (`public with sharing`) is the brief's only entry point. It has an ordered registry, one line per source (key to class name, resolved with Type.forName). `public static Result run(Id accountId, String question, Set<String> include)`: (1) the account must be visible, else NOT_FOUND with `I can't see that account. Check the name or your access.`; (2) build only the included sources (null or empty = all; unknown keys are ignored and listed in Result.ignored); (3) reduce; (4) record memory; (5) return. Result fields, all @AuraEnabled: status (OK/EMPTY/NOT_FOUND/ERROR), message, answer, sections (List<AccountBriefSection>), ignored
- Reduce is data-driven: a small map says which source keys feed which pre-reduce prompt. contacts/activity/calls feed BriefEngagement; deal_history feeds BriefDealHistory. A pre-reduce runs only when at least one of its sources is included and not EMPTY; otherwise its output is the literal `EMPTY`. Synthesis gets every other section text, both summaries and the question. A section that wasn't included is passed as `EMPTY: not requested`; a non-OK section as `<STATUS>: <body>`
- Any model exception becomes status ERROR with answer `I couldn't finish the brief right now. Try again in a minute.`, the sections still returned, and no memory write. AccountBriefMemory.record(...) is called only after every model call and only when status is OK or EMPTY (DML before a callout fails)
- `AccountBriefGetAction.cls` has one @InvocableMethod (label 'Get Account Brief'): inputs accountId (required), userQuestion, include (comma-separated keys; list the valid keys in its description); outputs status and answer. AccountBriefResolver stays unchanged as the resolve action
- Tests use the stub, with no SeeAllData: all sources by default in registry order; include filtering (the engagement pre-reduce is skipped when none of contacts/activity/calls is included; an unknown key lands in ignored); NOT_FOUND makes no model call; a model exception gives ERROR and no memory row; the happy path writes one memory row; the invocable parses include; prompt loading fills placeholders and fails clearly on a missing prompt. AccountBrief and AgentLlm are at least 90% covered
- `docs/ARCHITECTURE.md` (80 lines or fewer, generic terms only): the route/gather/reduce picture for this repo, the class map, how to add a source, how to add a provider, where prompts live, and the rules (no prose in Apex, caps, verbatim status, DML last)
- Both gates pass: test and org. Quote the `validate-org:` line. No real deploy

## Review

Reviewer: 17 confirmed, 0 refuted, 3 unverifiable (coverage figure, no max-token field, live response shape). The brain smoke-tests a live model call after the real deploy. Amend for tests/test_sfdx_project.py granted. Gate line: validate-org: pass (40 components, 69 tests).
