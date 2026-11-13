---
id: BE-33
title: FR2: the model door grows up — per-prompt settings in custom metadata (model, length, source), an opt-in prompt template path behind the same seam, the request's own generation settings where the API takes them, a prompt trace and a try-a-prompt script for tuning
domain: backend
tier: frontier
tier_reason: changes the one door every model call goes through, adds a second provider, and settles platform facts the GTM story will quote, in a production-classified org
status: merged
fixes: []
scope: [force-app/main/default/classes/AgentLlm.cls, force-app/main/default/classes/AgentLlm.cls-meta.xml, force-app/main/default/classes/AgentLlmTest.cls, force-app/main/default/classes/AgentLlmTest.cls-meta.xml, force-app/main/default/classes/AgentLlmModelsApi.cls, force-app/main/default/classes/AgentLlmModelsApi.cls-meta.xml, force-app/main/default/classes/AgentLlmModelsApiTest.cls, force-app/main/default/classes/AgentLlmModelsApiTest.cls-meta.xml, force-app/main/default/classes/AgentLlmPromptTemplate.cls, force-app/main/default/classes/AgentLlmPromptTemplate.cls-meta.xml, force-app/main/default/classes/AgentLlmPromptTemplateTest.cls, force-app/main/default/classes/AgentLlmPromptTemplateTest.cls-meta.xml, force-app/main/default/objects/Agent_Prompt_Setting__mdt/**, force-app/main/default/customMetadata/Agent_Prompt_Setting.*, force-app/main/default/genAiPromptTemplates/**, scripts/prompt-try.apex, docs/research/fr2-model-door.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/**, force-app/main/default/staticresources/**, mcp-door/**, spikes/**, data/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new AgentLlmTest and AgentLlmPromptTemplateTest cases fail on main (no per-prompt setting, no template source, no prompt trace) and pass after
gate: test, org
budget: 2-attempts
spend: 20
---
## Why

Feature revision 2 (FR2), Ben's chapter notes on pattern 04. The product calls models through the Models API because "prompt templates require a lot of overhead"; it wants to "accelerate very fast" while "still giving teams the opportunity to incorporate in a prompt template to the call if they need to". He floated two versions of the package, one with a commented-out section where Apex passes in a prompt template. The brain's decision (ledger) is one tested switch per prompt instead of commented-out code. He also asked that the page's limits be explored and cards cut. Covers ledger rows F67, F69, F72 and F73 in docs/plans/feature-revision-2.md.

## Done when

- **Approval first:** read the row "FR2: live checks in `agent-probe`" in the Approvals table of docs/plans/gtm-burn-plan.md. If its status does not start with "approved", skip every live run in the org and say so in the hand-back; deploys under the standing row still go ahead. When it is approved: use an existing seed-data account, say in the hand-back which one, and record how many session and outcome rows the run wrote
- Read first: docs/plans/feature-revision-2.md (rows F67 to F73 and the decision on prompt templates), docs/plans/fr2-design.md ('Operating principles', 'Gotchas'), docs/patterns/04-model-provider-seam.md (its Limits and open items), docs/reviews/apex-review-2.md (N8, N11, N12, finding 13), docs/research/fr2-trust-rule.md (BE-37) and the AgentLlm classes. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-apex-test-generate, salesforce-development:platform-custom-metadata-type-generate, salesforce-development:platform-capability-search and salesforce-development:platform-metadata-deploy first
- **Settle the facts first**, from public Salesforce docs and a check in agent-probe, and write them at the top of docs/research/fr2-model-door.md: which generation settings the Apex Models API request takes in this API version (maximum tokens, temperature, others); what the Einstein Trust Layer does to a Models API call and to a prompt template call (masking, grounding, audit, retention), so the chapter can say precisely what each path shows a builder; how each call counts against the org's generative AI usage; and the callout time limits that apply
- **Per-prompt settings (N12, and "one provider for the whole org"):** a custom metadata type Agent_Prompt_Setting__mdt keyed by prompt name, with the model, the maximum length, the source (Static resource, the default, or Prompt template) and, for a template, its API name and how variables map to its inputs. A prompt with no record keeps today's behaviour. The model constant stays only as the fallback. Records for the current prompts ship with today's values
- **Prompt files for reps (N11, ledger F87):** find out from Salesforce's docs and a check as the admin whether a user holding only the user group can read the prompt files in user mode. If yes, read them in user mode and remove BE-37's marker; if not, keep the system-context read with its marker and give the reason in the doc. FE-5 proves it as a real rep. A prompt template's own access is part of the same answer
- **Length:** where the request takes a maximum-token setting, send it from the prompt's setting and keep the character cap only as a backstop. Keep BE-29's cut marker
- **The prompt template path:** AgentLlmPromptTemplate implements AgentLlm.Provider-like behaviour for a prompt whose source is Prompt template. It calls the platform's prompt template generation with the mapped inputs and returns the text through the same error type. Like the Models API provider, it is reached by class name, so the core never holds a compile-time reference to the platform API. Ship one small sample template (a copy of an existing prompt) in genAiPromptTemplates/, switched off by default, and prove it live in agent-probe by flipping its setting for one run of scripts/prompt-try.apex, then flipping it back (each flip is its own validate and quick deploy under the standing row "Production-classified deploys to `agent-probe`", and the hand-back says the setting is off again). If a template cannot be deployed or run this way, record why and stop at the tested seam
- **Tuning tools:** a prompt trace (off by default, switched on by a field on the prompt's setting record) that writes the filled system and user text and the reply length to the debug log for one prompt name, never in tests' output and never with record Ids; and scripts/prompt-try.apex, which runs one named prompt for one sample account and prints the reply, the length and the time, so a builder can change a prompt file, deploy and try it in a minute
- **A provider outside Salesforce:** in the research page only, what a provider that calls a model vendor directly (for example through a Named Credential) would gain and lose against the Models API (the trust layer, usage billing, model choice, setup). No code
- **Old classes in the org:** the old AccountBrief* classes and tests are still deployed in agent-probe and compile against these classes. Keep every signature and interface method they use. If RunLocalTests fails in an AccountBrief* class, stop and hand back; never delete, stub or redeploy an old class
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy unless this card's own Approvals row names one. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Skip any org step whose Approvals row does not start with "approved", and hand back. A read-only step (a query, a describe, a list, or a retrieve of force-app metadata to a temporary folder outside the repo) needs no row
- Tests with Assert.* cover each setting field, the fallback with no record, the template path with a stub, the trace on and off, and the generation settings in the request. Existing tests still pass. Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1. Never publish or activate an agent, never sign in or out, never create a user in the org, never touch experimental. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No record Ids, org Ids, usernames, emails, tokens or hostnames added. No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-13). One attempt (d908508). The verifier found the report consistent; a reviewer then returned 20 confirmed, 0 refuted, 7 unverifiable. Every unverifiable row is an org fact, a platform fact or a run the worker did not save: the deploys and the live run, the throwaway N11 probe, the AccountBrief* tests under RunLocalTests, the docs gate, the earlier failing validate behind the `modelName` rename, and the platform facts the doc cites.

Findings:
- New custom metadata type Agent_Prompt_Setting__mdt, keyed by prompt name: model, maximum length, source (Static_Resource by default, or Prompt_Template), template name, template inputs and a trace switch. Four records ship with today's values (BriefEngagement 600, BriefDealHistory 400, SummarySynthesis 1500, Explore 2000), the current model, the static source and the trace off. They match the call sites in CustomerSummary and DataExplorer. A prompt with no record behaves as before.
- AgentLlm gains a model provider and a template provider, a public Setting and setting(), a trace and a template path. Its existing signatures and failure messages are unchanged. A record's maximum length wins over the caller's; the 4-characters-per-token cap stays as a backstop.
- Prompt files are now read in user mode (BE-37's marker removed). The settings are read in system mode under a new marker, because the data-access set does not grant the type and permission sets were out of scope. The trust-rule page's marker table says so (scope amended for it).
- AgentLlmPromptTemplate calls the prompt-template API by class name, so the core has no compile-time tie to it, and turns every failure into the usual model-call error.
- A sample flex template, Customer_Summary_Deal_History, copies the deal-history prompt. It is unused while the setting stays on the static source, which is what the tree and the org hold.
- The trace is off by default, masks record Ids and logs the reply by length only.
- scripts/prompt-try.apex runs one prompt for one sample account and prints masked `TRY|` lines; it writes no record.
- Tests cover each setting field, the fallback, the template path with a stub, the trace on and off, and a Minimum Access test user holding the data-access set reading prompt files (created inside the test, so rolled back).
- docs/research/fr2-model-door.md puts the platform facts first; its outside-Salesforce provider section is marked unconfirmed.

Live check (worker's account, approved live-checks row, seed account): one BriefDealHistory run with the template source switched on; one model call, a 407-character reply, 0 session rows written. The setting was switched back to the static source and a retrieve read it back.

Org: three validates with RunLocalTests (365 tests each, 0 failures) and quick deploys under the standing row, each of only this card's components: the build, the switch on and the switch off. Nothing published, no user created, no AccountBrief* class touched.

Disclosed and accepted:
- The org figures are the worker's account; nothing in git shows them.
- The live run ran as the admin: the template API does not support runAs, and reps lack Execute Prompt Templates.
- A tests/__pycache__ made by the verifier's gate run was removed before merge.

Still open:
- Reps cannot run prompt templates until the user group grants Execute Prompt Templates; every setting stays on the static source until then.
- The real-rep proof of the prompt-file read waits on FE-5 (a rep login).
- The reason given for SOQL over getInstance (a 255-character cut) does not bear on this type, whose fields are all 255 characters or less; the system-mode read rests on the data-access set not granting the type.

Privacy grep over the diff (1,314 added lines): 0 hits.
