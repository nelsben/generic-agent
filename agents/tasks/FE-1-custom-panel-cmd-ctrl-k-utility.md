---
id: FE-1
title: Custom panel: Cmd/Ctrl-K utility-bar LWC with a brief view, ask-anything exploration, click-to-drill tables, follow-up chips, a query trail, history and an Ask-the-agent bridge
domain: frontend
tier: frontier
tier_reason: largest UI card keyboard and focus handling, three views, drill navigation and the accApi bridge
status: merged
scope: [force-app/main/default/lwc/accountBriefPanel/**, force-app/main/default/messageChannels/AccountBriefOpen.messageChannel-meta.xml, force-app/main/default/classes/AccountBriefPanelController.cls, force-app/main/default/classes/AccountBriefPanelController.cls-meta.xml, force-app/main/default/classes/AccountBriefPanelControllerTest.cls, force-app/main/default/classes/AccountBriefPanelControllerTest.cls-meta.xml, force-app/main/default/classes/AccountBriefSection.cls, force-app/main/default/classes/AccountBriefResolver.cls]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/aiAuthoringBundles/**]
red_test: bash scripts/validate-org.sh (AccountBriefPanelControllerTest absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 25
---
## Why

Ben wants a custom UI, not the chat icon: a hotkey-opened panel with inline AI summary cards where the user can ask anything and drill into anything, modelled on a panel from another of his projects. That panel uses a document keydown listener for Cmd/Ctrl-K and Esc that yields on defaultPrevented, a composer stopPropagation focus trap on this.template so Lightning's single-key shortcuts don't fire, the lightning__UtilityBar target, follow-up chips that submit as new questions, and a visible 'ran N queries' trail. One engine, two front ends: the controller calls the same Apex as the agent (AccountBriefResolver, AccountBrief.run, DataExplorer).

## Done when

- Read docs/ARCHITECTURE.md and the engine classes on main first; use their real method and field names
- force-app/main/default/classes/AccountBriefPanelController.cls is `public with sharing` with @AuraEnabled methods that only delegate: resolve(accountName, recordId); getBrief(accountId, question, include); explore(question, contextRecordId, historyJson); drill(recordId, relatedObject); history(accountId); sources() (registry keys and titles); agentId() (BotDefinition Id for DeveloperName 'Account_Brief' or null). No model calls of its own. Its test uses the AgentLlm stub
- force-app/main/default/lwc/accountBriefPanel/ targets lightning__UtilityBar and lightning__RecordPage and reads the page's recordId and object. connectedCallback adds a document keydown listener: Cmd/Ctrl-K focuses the composer, Esc blurs or closes, and events with defaultPrevented are skipped. Opening the utility goes through lightning/platformUtilityBarApi inside try/catch. disconnectedCallback removes the listener. The composer keydown calls stopPropagation, and the focus trap is registered on this.template
- Brief view: on an Account page a 'Brief this account' button (and auto-resolve of recordId); otherwise typing an account name with a leading `/brief ` runs resolve then getBrief. AMBIGUOUS shows the candidates as buttons that re-resolve by Id; NOT_FOUND and ERROR show the text verbatim. The answer renders as a summary card (first line as header, rest pre-line, never as HTML), then one card per section with a status badge and `<shown> of <total>`, with include chips from sources()
- Ask anything: any other composer text calls explore with the page's recordId (or the briefed account) as context and the last few turns as historyJson. The reply renders as the answer text, each result set as a lightning-datatable or simple table, a collapsed 'Ran N queries' trail, and follow-up chips that submit their text as the next question
- Drill-down without the model: clicking a row calls drill(recordId) and shows the record's fields as a card with buttons for its related objects, which call drill(recordId, relatedObject). Record lines in brief sections that carry an Id drill the same way. A breadcrumb lets the user step back. A 'View record' link navigates with NavigationMixin
- Loading shows a lightning-spinner. Conversation turns stay in the panel for the session. An 'Earlier briefs' list comes from history()
- An Ask the agent button imports `lightning/accApi` and opens or executes with agentId() and the current question; hidden when agentId() is null. If the module won't compile in the org gate, remove it and say so
- SLDS only, no external libraries, usable at a 340px width. force-app/main/default/messageChannels/AccountBriefOpen.messageChannel-meta.xml (fields recordId, prompt) exists and the panel runs the prompt when a message arrives
- Every field the panel reads must reach it: AccountBriefSection and AccountBriefResolver's result classes have no @AuraEnabled today. Add `@AuraEnabled` to their public fields (annotation only, no other change to those two classes), and confirm in the controller test that a JSON.serialize of each returned object carries the fields the panel uses
- Gates pass: test and org. Quote the `validate-org:` line. No real deploy

## Review

Second independent review at b577928 after the hand-back wording was corrected: 32 confirmed, 0 refuted. Unverified until tried in a live org: the lightning/accApi export names and argument order, the utility-bar API usage, Cmd/Ctrl-K and the focus trap in a real utility bar, and usability at 340px. The org gate does not check lightning/* export names.
