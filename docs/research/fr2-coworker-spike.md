# FR2: Agentforce Coworker against what Customer Summary builds (OPS-55)

Researched 2026-11-13. The org check ran the same day in `agent-probe`, read-only: queries, describes and metadata
lists only. Nothing was enabled, assigned, sent, deployed, published or changed. Ids, usernames and hostnames are
left out. Read with [feature-revision-2.md](../plans/feature-revision-2.md) (row F83) and
[fr2-design.md](../plans/fr2-design.md#operating-principles).

**Status words used on this page.**

- **read**: a Salesforce page fetched on 2026-11-13. The fetch tool hands back a small model's reading of the page,
  not the raw page, so "read" is one step short of reading it in a browser.
- **read in a browser**: the page text was read in Chrome on 2026-11-13 by the brain, and re-read by this card
  (OPS-56) the same day for all ten pages listed under [Sources](#sources). The guide refuses automated fetches
  (HTTP 403), so this is the guide's own text, not a small model's reading of it.
- **unverified (search summary)**: a page of Salesforce's Coworker developer guide that was not read in a browser
  (the ten read pages are listed in Sources; the rest are named there), or the Salesforce Admins blog. Both refused
  every automated fetch on 2026-11-13. Facts from those pages come from search-engine summaries of them. They are
  not quoted.
- **secondary**: a third-party page.
- **general Agentforce, not confirmed for Coworker**: a platform feature that no Coworker source says applies to
  Coworker.
- **verified**: seen in `agent-probe` by this run.

Quote marks mark words the fetch returned as the page's own. Exact text was asked for only on the pricing page [S2]
and on a second pass of the Trailhead unit [S6]; other quotes are as the fetch gave them. Without quote marks, a
line is a paraphrase. Every source has its
own line in [Sources](#sources).

## The answer to Ben's two questions

1. **Can our components call Coworker? Undocumented.** None of the ten guide pages read in a browser names an API, Connect class, Apex class, invocable or LWC module that sends Coworker's Ask a message from inside the org, and the guide's index (those ten page titles) shows no API or developer-extension page. This answer now rests on that reading, not on search summaries [S8], [S20], [S21]. The one programmatic door Salesforce names is the Coworker MCP server, which serves outside AI clients such as Claude and ChatGPT (GA November 2026 per [S4]). One new lead: the limits page lists an "Enterprise Search API (search results)" under the Connect API limits, so search results may have a Connect API door. Its own docs were not read, and whether Apex or an LWC may call it is not stated [S23].
2. **Can we build our own UI around it? Undocumented.** None of the ten pages documents a Coworker component, a Lightning page placement, a programmatic open, passing a record, a keyboard shortcut or branding; this rests on the browser reading of those pages and the guide's index [S10], [S9]. The guide describes an Ask page, toolbar tabs and a Quick Pages tab [S10], [S25]. Ben said he sees Coworker as a standalone app and tab; `agent-probe` has no such app or tab (see the check below). **The extension model the guide documents is our agent and its Lightning type cards shown inside Coworker's UI, not Coworker's UI inside ours** [S9].
3. **What can run inside Coworker is other agents, and their cards.** Coworker hands a request it cannot complete to any Agentforce agent the user can access, custom agents included, and routes on agent and topic descriptions only [S9]. So our Apex reaches Coworker's UI only through the `Customer_Summary` agent. When a delegated agent's response is configured to return a custom Lightning type or a Headless Experience Layer widget, Coworker shows that interactive card; otherwise it shows a markdown summary [S9]. **Cards from a delegated agent are documented.** Whether our own card envelope travels as a custom Lightning type is the open part.
4. **Either way in is an agent.** That is what ledger row F83 ruled out, and BE-32 measured an agent turn at 13 to 33 seconds for an explore question against 5 to 9 seconds direct. Reopening F83 for Coworker is Ben's decision.
5. **What comes free:** history, Teams, iOS and desktop, search over Slack, Google and Microsoft 365, Skills, and record creates and updates with Confirm. **Not covered:** our fixed summary, outcomes and sentiment, the hotkey window, the rail, the brand and the model seam. Keep FR2's custom build, and prove Coworker in an org before dropping anything.

## What Coworker is

| Question | Answer | Status and source |
|---|---|---|
| What it is | Salesforce's AI teammate: a user delegates work in natural language, and it plans the steps and coordinates Agentforce agents, flows and business actions, returning results for review | read [S1], [S3] |
| Product status | **Not stated as GA on a guide page; the sources still conflict.** Of the ten guide pages read in a browser, only "Create a Quick Page with Agentforce Coworker (Beta)" has Beta in its title [S25]. Turn On, Search, Ask, and Update Records, and Search Agent and Agent Delegation do not [S7], [S10], [S9], and the Turn On page mentions no Beta Services Terms. The earlier search summaries that showed "(Beta)" titles may be older copies. The 4 August 2026 blog's header says Coworker "is Generally Available" while its availability section says it "is in beta for Salesforce today" [S5]. The 4 November 2026 news story and the 5 November press release use no beta wording [S3], [S4]. This page does not settle it | read in a browser [S7], [S9], [S10], [S25]; read [S3], [S4], [S5] |
| Surface: Lightning | An Ask button next to the global search bar: "Click Ask next to the Salesforce global search bar" [S6]. The guide documents an Ask page with a side panel holding chats and a New chat control. Search and Ask each open in a toolbar tab. Closing an Ask tab does not delete the conversation, and only one recent Ask chat opens at a time. A link under the global search bar switches between Coworker and Standard Search [S10]. Quick Pages, which Coworker builds from a request, show on their own Quick Pages tab [S25] | read [S6]; read in a browser [S10], [S25] |
| Surface: Salesforce mobile app | The Trailhead unit says Coworker is accessible in Salesforce Lightning, Salesforce Mobile and more [S6]. The developer guide says the Search and Ask toolbar tabs are not available in the Salesforce mobile app [S10]. Field Service, Consumer Goods Cloud and Life Sciences Cloud mobile apps are expected in December 2026 [S4] | read [S6], [S4]; read in a browser [S10] |
| Surface: Microsoft Teams, iOS app, Mac and Windows desktop app | Generally available in November 2026 | read [S4], as of 2026-11-05 |
| Surface: Claude and ChatGPT | Through the Coworker MCP server: "as well as in Claude and ChatGPT through MCP". The MCP server is GA in November 2026 | read [S1], [S4] |
| Surface: Slack | A data source that can be made searchable [S6], [S13]. The August blog describes the same teammate in a Slack standup, with no date. No Coworker page lists Slack as a surface with a date | read [S5], [S6]; unverified [S13] |
| Licence and price (dated 2026-11-13) | "Agentforce Coworker User License", "$50", "USD/User/Month". Includes "All Coworker searches included" and "30 MBs of indexing per user per month". The page "is subject to change" | read [S2] |
| Billing | Seat-based, or usage-based through Flex Credits, Einstein Requests or Data Services Credits (the Turn On page [S7] lists all three; the billing page [S12] was not read). Searching Salesforce CRM or Slack uses no credits under a seat; sources added through Data 360 use credits. A free trial for Flex Credits customers is GA in November 2026 | unverified (search summary) [S12]; read in a browser [S7]; read [S4] |
| How it is enabled | The Turn On page lists the System Admin profile and the Agentforce Coworker Admin permission set. Setup, Quick Find "Agentforce Coworker", Get Started with Agentforce Coworker, Turn On, then Confirm in the window that appears; Einstein turns on with it [S7]. "Access to Agentforce Coworker is controlled through the Permission Set Group for Agentforce Coworker" [S6]. The Turn On page read in a browser lists a Confirm step and no terms. Earlier search summaries said turning on requires Beta Services Terms; what Setup actually shows is unverified | read in a browser [S7]; read [S6] |
| Who can use it | User access is through the permission set group whose API name is Access_Ai_Search [S10]. Users need the Agentforce Coworker User permission set and permission set licence, and admins a setup permission set licence (search summary of the user-access page [S26], not read). Older names (AI Search) also appear in the guide | read in a browser [S10]; unverified (search summary) [S26]; the user permission set name read in [S15] |
| Licences and requirements | Seat-based access needs an Agentforce 1 Edition licence, an Agentforce for Sales, Service or Industries licence, or an Agentforce Coworker for Enterprise or for Unlimited Edition licence. Usage-based access needs entitlements of Flex Credits, Einstein Requests or Data Services Credits. Overall access needs Data Cloud or Data 360 provisioned and activated [S7] | read in a browser [S7] |
| Editions | Enterprise, Unlimited and Agentforce 1 Editions [S7], [S10]. The guide home says Coworker is not supported in Government Cloud Plus and warns not to turn it on there [S8] | read in a browser [S7], [S8], [S10]; read [S15] |
| Developer Edition | **Not among the listed editions** (Enterprise, Unlimited, Agentforce 1) [S7]. So whether an ordinary Developer Edition can turn Coworker on is undocumented. The Trailhead playground is the one Developer Edition route a source names: "a custom playground that contains Agentforce Coworker and our sample data", which it describes as a Developer Edition org tied to a Trailhead account [S6] | read in a browser [S7]; read [S6] |
| Data 360 | **Required for overall access per the Turn On page** [S7]; the guide home says Coworker is "Powered by Data 360" [S8], as does [S1]. [S15] said the Data 360 connector is optional and that CRM and Slack work without extra setup; that is the older reading, kept as what [S15] said. A secondary source says Data 360 must be enabled first [S16]. A search summary says setup needs a Data 360 admin role, and the guide has a page on setup in a companion org [S11] | read in a browser [S7], [S8]; read [S1], [S15]; secondary [S16]; unverified [S11] |
| What it searches | Salesforce CRM by default: accounts, opportunities, contacts, cases and custom objects. Optional: Slack, Data 360 objects, and Google Drive, Gmail and Google Calendar, which each user connects and which are searched at query time. Microsoft 365 connectivity is listed as available now | read [S6], [S4] |
| What it indexes | 30 MB of indexing per user per month comes with the licence. What exactly is indexed, and how the CRM is indexed, is not stated on a page read | read [S2] |
| Whose access its answers use | "Regardless of which sources you enable, Agentforce Coworker never bypasses your security model." "Sharing rules, profiles, permission sets, and policies for Data 360 all apply." Field-level security is named only by a secondary source [S17]. For record updates, permissions are checked only when the user confirms (paraphrase of [S6]) | read [S6]; secondary [S17] |
| Writes | Coworker creates as well as updates records, up to 15 per command. An admin turns on the Agent Actions toggle in Coworker setup. An update shows current values beside proposed values. A new record shows mapped field values and related records. The user can refine the proposal before confirming. Coworker can propose a change the user has no permission to make, and it fails when applied [S10]. It can currently create or modify Salesforce CRM records only, and Salesforce's own log-a-call example proposes a new Task [S22]. Trailhead says the user clicks "Confirm" [S6]. The Japanese launch blog lists sending email, updating deal status and creating tasks [S15]. The access page [S14] was not read | read in a browser [S10], [S22]; read [S6], [S15]; unverified [S14] |
| History, Skills and later features | "Returns to prior Agentforce Coworker interactions via the History panel ..." (excerpt). Conversation History continues across Salesforce, Teams and the new apps. Skills are reusable, shareable workflows made from a conversation. Daily Digest and scheduled tasks are expected in December 2026 | read [S6], [S4] |

## The three answers

### 1. Headless call: can our LWC or Apex send Coworker a message and get its answer? Undocumented

None of the ten pages read in a browser names an API, Connect class, Apex class, invocable or LWC module that sends Coworker's Ask a message from inside the org, and the guide's index (every page title in Sources) shows no API or developer-extension page. The answer rests on that reading, not on search summaries. The answer for Ask stays: undocumented.

| Path | What the sources say | Status |
|---|---|---|
| A Coworker API, Connect class, Apex class, invocable or LWC module for Ask | None named on any of the ten pages read in a browser. The Trailhead unit says Coworker is "designed headless-first, meaning it isn't tied to any single UI" and "operates via APIs and meets your teams in the surfaces where they already work". It names no API. A headless design is not a documented door for our code | read in a browser [S8], [S20], [S21], [S7], [S22], [S23], [S10], [S9], [S24], [S25]; read [S6] |
| The Enterprise Search API (search results) | **New lead, for search results, not Ask.** The limits page lists an "Enterprise Search API (search results)" whose limits are the Connect API limits, a "Query Assist (suggestions)" limit, and a Search Agent limit of 100 requests a minute: the Search Agent uses the Agentforce Models API, with several model calls per query plan. So search results may have a Connect API door. That API's own docs were not read, and whether Apex or an LWC may call it is not stated | read in a browser [S23] |
| The Coworker MCP server | Documented, for outside MCP clients: Claude and ChatGPT reach Coworker "through MCP" [S1]. It is GA in November 2026 [S4]. Its own docs were not found. Whether Apex in the same org could act as an MCP client of it (auth, scopes, user context) is **undocumented** | read [S1], [S4] |
| The Agent API or `generateAiAgentResponse` against Coworker's agent | Turning Coworker on creates a platform-managed Search Agent that cannot be modified and that appears in the Agentforce agent list in Setup [S9]. That is the reason this try is possible; it is still untried. Whether the Agent API or the invocable can open a session on that agent is **undocumented**. Both paths are general Agentforce, not confirmed for Coworker; our proof of them is [agent-api.md](agent-api.md) | read in a browser [S9] |
| The Agentforce Conversation Client API (`lightning/accApi`) | Opens, closes or sends an utterance to the standard Agentforce panel, and "does not return the agent's textual response to your component" ([fr2-standard-limits.md](fr2-standard-limits.md)). General Agentforce, not confirmed for Coworker. Even on the standard panel it returns no answer, so it is not a headless call | [S18] |

**Ledger F83, plainly.** A headless call to Coworker makes an agent the way in. F83 ruled that out ("dropping the
Astro icon button and then also the ask the agent button"). BE-32 measured it as slow: 13 to 33 seconds an explore
turn through the agent against 5 to 9 seconds direct, and 31 to 36 seconds a brief turn against 22 to 25
([fr2-standard-limits.md](fr2-standard-limits.md)). Coworker adds its own routing on top. The guide says Coworker
times out if it cannot hand a request to an agent within 90 seconds, and tells builders to keep sub-agent responses well inside 90 seconds [S9]. BE-32's measured turns (13 to 33 seconds an explore turn, 31 to 36 seconds a brief turn, both through the agent) fit inside that; Coworker's own latency on top is unmeasured. **This is a decision for
Ben.** This page does not route around F83, and it does not treat F83 as settled either way.

### 2. Embed: can Coworker's own UI sit inside our page, panel or utility item? Undocumented

None of the ten pages read in a browser documents a Coworker component, a Lightning page placement, a programmatic open, passing a record, a keyboard shortcut or branding. The answer rests on that reading and the guide's index. The extension model the guide documents is our agent and its Lightning type cards shown inside Coworker's UI, not Coworker's UI inside ours [S9].

| Question | Answer | Status |
|---|---|---|
| Placed in our page, panel or utility item | No source documents a Coworker component, an embeddable Coworker UI, or a Lightning page placement. Coworker's own entry is the Ask button by global search, and its answers open in a toolbar tab [S10] | read [S6]; read in a browser [S10] |
| Opened from our hotkey with the record as context | No source documents a shortcut, a programmatic open, or passing a record. `lightning/accApi` drives the standard Agentforce panel, and the beta Web SDK embeds an agent in a non-Lightning host; both are general Agentforce, not confirmed for Coworker | [S18], [S19] |
| Themed with a brand | No source documents a name, logo or colour change for Coworker. Branding tokens exist for the general Agentforce Web SDK only ([fr2-standard-limits.md](fr2-standard-limits.md)) | not found |

### 3. Extend: can our actions, our MCP door and our cards run inside Coworker? Actions and cards yes, through an agent only; the rest undocumented

| Part | Answer | What it takes | Status |
|---|---|---|---|
| Our Apex actions (the summary, the explorer, the BE-22 draft and commit pair) | **Yes, through an agent.** Coworker "routes requests to any enabled AI agents that can and surfaces their responses back in one place" (excerpt). Our actions already sit behind the `Customer_Summary` agent | The agent active, reps given agent access again (FE-20 removed it), and good agent and topic descriptions. Coworker routes on agent and topic descriptions only, not on topic instructions, to up to 50 agents. During delegation it streams the agent's thinking steps, and shows a confirmation and waits for approval when a delegated topic asks for one [S9]. The draft and commit pair is not in the agent: BE-28, parked under F83, would have to add it | read [S6]; read in a browser [S9] |
| Our actions directly, without an agent | **Undocumented.** No source says Coworker calls a custom Apex invocable, a flow or a custom action of our own except through an agent | none | not found |
| Our MCP door (Customer Summary's actions to outside clients) | **Undocumented.** The Coworker MCP server exposes Coworker outward. No source says Coworker consumes an MCP server we provide. Those are two directions, and only the outward one is documented | none | read [S1], [S4] |
| Our cards | **Documented yes, through a delegated agent and a custom Lightning type.** When a delegated agent's response is configured to return a custom Lightning type or a Headless Experience Layer widget, Coworker shows that interactive card and its card links as they appear in Lightning Experience; without that configuration it shows a markdown summary. Coworker's own answers stay in markdown, and the guide says a team does not build a separate user interface for Coworker [S9]. **Unproven:** whether our own card envelope (FE-18, BE-39) can travel as a custom Lightning type drawn by our card component, in an org with Coworker on. It is still through an agent, so F83 still applies. Coworker's own answers also come as tables, bullet lists or "Rich Card" layouts [S15]. Where Lightning types render otherwise is in [fr2-standard-limits.md](fr2-standard-limits.md) | A prototype would need a Lightning type on one action and a new agent version (proposed card 3) | read in a browser [S9]; read [S15] |
| Skills | **Undocumented as a developer extension.** Skills are reusable workflows that users save from a conversation and share. Trailhead says they "combine instructions, context, agents, and tools into shareable workflows for your org" (excerpt). Whether a team could ship a Skill as metadata is undocumented | none | read [S6], [S4] |

## Feature map

Each row is something Customer Summary has built or plans in FR2. Free means a Coworker source covers it with no
build; partly means it covers some of it.

| Customer Summary feature | With Coworker | Source | What adopting it would lose or need rebuilt |
|---|---|---|---|
| The sourced account summary (seven sources, two pre-reduces, fixed sections; pattern 01) | **Partly.** Coworker answers questions about an account with cited sources. It has no fixed summary shape. Our summary could reach it through the agent, but BE-32 found the agent relays its layout loosely (1 of 6 section labels on its own line) | read [S15], [S6]; [fr2-standard-limits.md](fr2-standard-limits.md) | The fixed, sourced sections unless relayed through the agent, plus the "Summarize <Account>" one-click |
| Ask-anything explorer with drill-down (pattern 02, BE-31) | **Partly.** Coworker searches CRM objects including custom ones, answers in tables, and lets a user preview a cited record. Aggregates, a deny list, row counts and drill-down to related records are not documented | read [S6], [S15] | Our plan grammar, the admin deny list (BE-31), the guarantee that the model never writes SOQL, and the drill-down buttons |
| Conversation history a rep can return to (BE-26, FE-22) | **Free.** A History panel, and Conversation History across Salesforce, Teams and the apps | read [S6], [S4] | History scoped per account, and the access re-check on read. How Coworker scopes its history (per user, per record) is undocumented |
| Customer outcomes and sentiment (BE-35, BE-36, FE-19) | **Not covered.** No Coworker source describes storing what was done against the account. The Trailhead exercise gets a sentiment score by asking another agent | read [S6] | Nothing lost; the outcome store would still be ours to build |
| Voice input (FE-11, merged) | **Undocumented.** No Coworker source names a microphone or dictation | not found | The shared mic in every surface |
| Write actions with draft, Confirm and Undo (BE-22, BE-27, FE-14) | **Partly.** Create and update with Confirm, up to 15 records in one command, off until an admin turns on the Agent Actions toggle. The user can refine a proposal before confirming, which is documented now [S10]. Email is named in a blog [S15]. Undo is still undocumented. Salesforce's own log-a-call example creates a Task [S22], which bears on ledger F17 (Ben's decision; nothing else about F17 changes here) | read in a browser [S10], [S22]; read [S15] | Undo from stored previous values, the editable draft card, the fixed six-action set and the verb pre-check (BE-22) |
| Rich cards (FE-18, BE-39, FE-22) | **Partly.** Tables, bullets and "Rich Card" layouts of Coworker's own, and documented yes for a delegated agent's custom Lightning type card. Whether our card envelope travels as a Lightning type is unproven; still through an agent, so F83 applies | read in a browser [S9]; read [S15] | One card contract read by every surface, including MCP |
| The Cmd/Ctrl-K compact window (FE-13, merged) | **Not covered.** Coworker opens from its Ask button; no keyboard shortcut is documented on any page read | read [S6]; read in a browser [S10] | The hotkey from any page, and the corner launcher OPS-29 placed |
| The rail (Cmd/Ctrl-Shift-K, FE-15) | **Not covered.** Coworker answers open in a toolbar tab, not a side rail | read in a browser [S10]; secondary [S16] | The slide-over rail beside the record, and its prefetched context (BE-25) |
| Brand theming (BE-24, merged) | **Undocumented.** Coworker is itself the product name; no name, logo or colour setting is documented | not found | The seller's brand swap (F05 to F09), the core of the demo story |
| The MCP door (pattern 09, OPS-31) | **Partly, the other way round.** The Coworker MCP server lets Claude and ChatGPT reach Coworker. Whether it can carry our actions is undocumented | read [S1], [S4] | Outside clients calling our exact actions with our output, unless Coworker delegates to our agent for them |
| User-mode access, no stack traces (principle 5, BE-37) | **Partly.** Coworker "never bypasses your security model"; sharing, profiles and permission sets apply. Field-level security is named only by a secondary source. A timeout after 90 seconds without a handoff tells the user to rephrase or try again [S9] | read [S6]; read in a browser [S9]; secondary [S17] | Our named system-context exceptions and the test that enforces them (BE-37) do not reach inside Coworker's own agent |
| Model seam and prompt files (pattern 04, BE-33) | **Not covered.** Coworker's Search Agent is platform-managed and cannot be modified [S9]. No model choice or prompt file is documented | read in a browser [S9] | Choosing the model, prompts a team edits and deploys in minutes, and the prompt-template switch (F69) |

**What Coworker has that FR2 has not planned:**

| Coworker capability | Source |
|---|---|
| Microsoft Teams, an iOS app and Mac and Windows desktop apps (GA November 2026) | read [S4] |
| Search across Slack, Google Workspace and Microsoft 365, and Data 360 objects, beside the CRM | read [S6], [S4] |
| Routing one request across many agents, up to 50, on agent and topic descriptions only | read [S6]; read in a browser [S9] |
| Quick Pages: Coworker builds a React-based page from a request and shows it on a Quick Pages tab (Beta) | read in a browser [S25] |
| Skills: reusable workflows a user saves and shares with a team | read [S6], [S4] |
| A conversation carried across devices and surfaces | read [S4] |
| Daily Digest and scheduled tasks (expected December 2026) | read [S4] |
| Approval and audit for supported operations | read [S3] |
| A search mode that returns ranked results and a short summary | read in a browser [S10] |
| Turn-on in Setup with no code; the unit says it works with CRM data at once, with no implementation work | read [S6] |

## agent-probe check

Run by [inventory.py](../../spikes/coworker/inventory.py) with `-o agent-probe` on every `sf` call. The output is in
[inventory.jsonl](../../spikes/coworker/results/inventory.jsonl): names and counts only (verified, 2026-11-13).

| Check | Result |
|---|---|
| Org edition | Developer Edition, not a sandbox |
| Permission sets named Coworker or AI Search | 0 |
| Permission set groups named Coworker or AI Search | 0. The inventory's word list already covered `Ai_Search` and found 0, which fits `Access_Ai_Search` (the group the Search and Ask page names [S10]) being absent |
| Permission set licences named Coworker or AI Search | 0. Of 11 licences labelled Agentforce, Einstein, Data Cloud or Agent, none is named Coworker or AI Search. A "Data Cloud" licence is present. Two are named "Einstein AI Skills" and "Einstein AI Skills Manager"; whether they relate to Coworker's Skills is unproven |
| User licences named Coworker | 0 |
| Apps (AppMenuItem) and custom applications named Coworker | 0 and 0 |
| Tabs named Coworker or AI Search | 0 of 253 tabs |
| Metadata types with Coworker or Search in the name | 0 with Coworker. Three search types (`DataObjectSearchIndexConf`, `SearchCustomization`, `SearchOrgWideObjectConfig`), of 285 types |
| Settings entries | `Search` only; none named Coworker |
| Objects with Coworker in the name (Tooling) | 4: `CoworkerConceptShare`, `CoworkerConceptOwnerSharingRule`, `CoworkerMemoryShare` and `CoworkerMemoryOwnerSharingRule`. They look like platform schema present in every org of this release (inference; BE-34 saw the memory pair, [fr2-agent-memory.md](fr2-agent-memory.md)). They do not show that Coworker is on |
| Agents (BotDefinition) | 2, both ours: `Account_Brief` and `Customer_Summary`, each type `InternalCopilot`, agent type `AgentforceEmployeeAgent`, version 2 active and version 1 inactive. No Search Agent and no Coworker agent |
| Agent metadata | 4 planner bundles and 2 agent definitions, all ours; 0 AI applications |

**Nothing Coworker exists in `agent-probe`**, so the org part stops here. There is also no Coworker app or tab, which matters because Ben said he sees Coworker as a standalone app and tab; the guide describes an Ask page, toolbar tabs and a Quick Pages tab [S10], [S25]. Neither agent is Coworker's. Whether
the Agent API could open a session on them is the open question already in [agent-api.md](agent-api.md): it excludes
only the "Agentforce (Default)" type, and Employee-type support is unproven there. The in-org invocable worked for
`Account_Brief` in that run. No session was opened by this card.

**Not readable by query:** whether the Setup page Get Started with Agentforce Coworker is offered in this Developer
Edition org (Developer Edition is not among the editions the Turn On page lists [S7]). That is Ben's look ([For Ben](#for-ben), item 2).

## Options

| | A. Stay custom | B. Coworker as the surface, our engine plugged in | C. Both: our surfaces lead, Coworker as an extra door |
|---|---|---|---|
| What it is | FR2 as planned: the compact window, the rail and MCP, on our Apex | Reps use Coworker's Ask button. Our summary, explorer and actions reach it as the `Customer_Summary` agent | FR2 as planned. Teams that own Coworker also reach our agent from Coworker, as the optional agent reaches other channels today |
| Agent as a way in (F83) | No | **Yes**: the only way in | **Yes**, as an optional extra door |
| Cost | The plan as costed before the waves ran: 50 cards to dispatch, about $614 at one attempt each. The rail lands after 21 cards (about $285), write actions after 26 (about $370), history and sentiment after 29 (about $410) (ledger, "Order"). No new licence | $50 per user per month for the Coworker licence (pricing page, 2026-11-13), Data 360 consumption for any added sources, and every agent change needs a publish (BE-21, OPS-51 friction). Rebuild work: BE-28 unparked (write actions, rich answers and tone in the agent), Lightning types for cards, and agent access restored for reps (undoing part of FE-20). Turns are slower (BE-32), with Coworker's routing on top | Plan A, plus one prototype card after Ben's go, plus the Coworker licence for any team that wants that door |
| What it drops from FR2 | Nothing | The rail (FE-15) and its context (BE-25), history (BE-26, FE-22), the hotkey window's role (FE-13, merged), voice in our surfaces (FE-11, merged), brand swap as the demo (BE-24, merged), and our card contract (FE-18, BE-39, FE-14) | Nothing |
| Queued cards it changes | OPS-41 (chapter 00 "Why custom") can cite this page for "why not Coworker" | Almost every wave 4 to 6 card. FE-15, FE-22, BE-26, BE-25, FE-14 and BE-27 dropped or rewritten. FE-18 and BE-39 re-aimed at Lightning types. BE-28 unparked. OPS-36, OPS-41, OPS-44 and OPS-49 rewritten. BE-38 (the agent test bench) moves onto the critical path | OPS-44 (the agent appendix names Coworker as one channel), OPS-41 (one comparison), OPS-36 (one line). A new prototype card |
| What it rests on | Proven in `agent-probe` (OPS-29, BE-22, BE-31, BE-32) | Undocumented answers 1 and 2, and an unproven delegation in any org we hold | Same as B for the extra door only. The card question is no longer open on Salesforce's side (documented [S9]), only on ours: whether our envelope travels as a Lightning type |

## Recommendation

**Stay custom for FR2 (option A) while F83 stands.** Nothing in the guide pages read in a browser shows that Coworker can host our UI or be
called by it, and the one documented way our work reaches Coworker, cards included, is through an agent [S9]. F83 currently rules that out.
The extension model the guide documents is our agent and its Lightning type cards shown inside Coworker's UI, not Coworker's UI inside ours.

**If Ben reopens F83 for Coworker, take option C, not B.** C keeps every proven surface and adds Coworker as an extra
door, through the optional agent the repo already keeps for other channels. For C the card question is no longer open on Salesforce's side
(documented [S9]), only on ours: whether our card envelope travels as a Lightning type. Only a prototype in an org with Coworker
on (proposed card 2) would show whether delegation relays our summary and explorer well enough to make B worth
weighing. B drops the brand swap, the hotkey window and the rail, which are the demo, and it rests on two undocumented
answers (1 and 2). No queued card changes until Ben decides F83 and one of the For Ben steps below has run.

## What stays unproven

- Whether Coworker is GA or beta in Lightning: no guide page states GA, and the sources conflict.
- Whether an ordinary Developer Edition such as `agent-probe` can turn Coworker on (it is not a listed edition).
- Any in-org programmatic call to Coworker's Ask (answer 1), whether Apex can be a client of the Coworker MCP server, and whether Apex or an LWC may call the Connect API door for search results.
- Any embed, hotkey, record context or branding for Coworker's UI (answer 2).
- What Setup shows when turning on (the Turn On page lists a Confirm step and no terms).
- Whether Coworker delegates to a custom Employee agent built in Agent Script, and how faithfully it relays the reply.
  A community thread doubts that Coworker's planner hands off to newer custom agents; it is not linked here because
  its URL carries an Id, and it is not evidence.
- Coworker's turn latency, alone and when delegating (the guide's 90-second limit is documented [S9]; BE-32's turns fit inside it).
- Whether our own card envelope (FE-18, BE-39) can travel as a custom Lightning type drawn by our card component, in an org with Coworker on. That a delegated agent's custom Lightning type card shows in Coworker is documented [S9]; it is still through an agent, so F83 applies.
- Field-level security in Coworker's own answers (secondary source only), and Undo for its writes (refining a proposal before Confirm is documented [S10]).
- Whether Coworker's actions draw Flex Credits under a seat licence (search summary of the billing page, and a
  secondary source that advises getting it in writing).
- Everything this page marks unverified (search summary). Each one rests on a guide page not read in a browser (listed in Sources).

## For Ben

Each step needs Ben's go. None was taken in this card.

| # | Step | What it would prove |
|---|---|---|
| 1 | **Decide F83 for Coworker:** may an agent be a way in when the door is Coworker? | Whether options B and C are open at all |
| 2 | Look in `agent-probe` Setup for Get Started with Agentforce Coworker. A look, without turning it on | Whether this Developer Edition org is offered Coworker; the query check cannot see that |
| 3 | Create a Trailhead Coworker playground under his own Trailhead account, and follow the unit's own turn-on steps there | A free org that contains Coworker, so the UI facts can be seen: tab or panel, history, cards, mic, shortcut |
| 4 | Turn Coworker on in an org we hold. The Turn On page read in a browser lists a Confirm step and no terms [S7]; what Setup actually shows, and whether any terms appear, is unverified | Availability. Whether a Search Agent appears as a BotDefinition and what type it is (the guide says it appears in the agent list in Setup [S9]). What Setup offers |
| 5 | Assign the Coworker licence and permission set group to one test user, and give that user agent access (part of FE-20 undone for one user) | The rep's experience, and what Coworker can reach under a rep's access |
| 6 | Send Coworker a live message that should go to `Customer_Summary`, three or so times | Delegation, how faithfully the summary and an explore table are relayed, and the latency against BE-32's numbers |
| 7 | A prototype deploy and agent version with a custom Lightning type on one action | A delegated agent's Lightning type card showing in Coworker is documented yes [S9]. This proves whether our own card envelope travels as a Lightning type and is drawn by our card component. Still through an agent, so F83 applies |
| 8 | A live headless try: the Agent API against the Search Agent, or an MCP client against the Coworker MCP server | Answer 1, in practice |
| 9 | Ask the account executive: price under our agreements, Flex Credit draw for actions, Developer Edition and sandbox availability, and GA status in Lightning | The dated licence facts this page could only read from public pages |

## Proposed follow-up cards

The brain cuts cards from this list.

1. **OPS: Coworker availability read.** Scope: `docs/research/fr2-coworker-spike.md`, `spikes/coworker/**`. Needs
   For Ben item 2 or 3.
   - Done when the page records whether `agent-probe` or a Trailhead Coworker playground offers Coworker, with
     Ben's screenshot or his words.
   - Done when the read-only inventory is re-run against the playground, if Ben links it, and records a Search Agent's
     type and status.
   - Done when the "What stays unproven" list is updated, and nothing is turned on by the worker.
2. **OPS: Coworker delegation prototype.** Scope: `spikes/coworker/**` and a new section on this page. Needs F83
   reopened and For Ben items 4 to 6.
   - Done when three live turns per question (one summary, two explore questions) go through Coworker to
     `Customer_Summary`, with results logged as counts and timings, like BE-32's.
   - Done when relay fidelity (rows, section labels) and latency are compared with BE-32's direct and agent numbers.
   - Done when the agent access granted for the test is removed again, and an Undo list says so.
3. **FE: Cards inside Coworker.** Scope: `spikes/coworker/**`, a spike-only Lightning type and agent version. Needs
   card 2's result and For Ben item 7.
   - Done when one action's output carries our card envelope as a custom Lightning type drawn by our card component, and the page records whether Coworker shows it. Delegated-agent Lightning type cards are documented yes [S9]; this tests our envelope (FE-18, BE-39), and it is still through an agent, so F83 applies.
   - Done when one capture or Ben's screenshot shows the result.
   - Done when the spike's agent version is deactivated, and an Undo list says so.
4. **BE: Headless door probe.** Scope: `spikes/coworker/**`. Needs For Ben item 8.
   - Done when one Agent API start-session against the Search Agent is tried, and its status code and message are
     recorded with no Ids.
   - Done when the Coworker MCP server's docs are read, and whether an in-org Apex client is allowed is recorded.
   - Done when the Connect API docs for the Enterprise Search API (search results) are read, and whether Apex or an LWC may call it is recorded [S23].
   - Done when answer 1 on this page reads yes or no, with the evidence.
5. **OPS-41 edit, not a new card.** Chapter 00 ("Why custom") gains a short "Why not Coworker" paragraph that links
   this page and states F83 as Ben's decision.

## Sources

Read on 2026-11-13. Prices and availability are as the page stated on that date.

**Salesforce pages, read in full:**

- [S1] Agentforce Coworker (product page): https://www.salesforce.com/agentforce/coworker/
- [S2] Agentforce Pricing: https://www.salesforce.com/agentforce/pricing/
- [S3] Agentforce Coworker surpasses 185k users (title as the search result gave it; Salesforce News, 2026-11-04):
  https://www.salesforce.com/news/stories/agentforce-coworker-surpasses-185k-users/
- [S4] Salesforce's Agentforce Coworker Usage Soars 21x in Three Months as Enterprises Delegate Real Work to AI
  (press release, Singapore edition, 2026-11-05):
  https://www.salesforce.com/ap/news/press-releases/2026/11/05/sg-salesforces-agentforce-coworker-usage-soars-21x-in-three-months-as-enterprises-delegate-real-work-to-ai/
- [S5] Meet Agentforce Coworker: your AI teammate everywhere. And it actually does the work. (Salesforce blog,
  2026-08-04):
  https://www.salesforce.com/blog/agentforce-coworker-salesforce-ai-teammate/
- [S6] Trailhead, Quick Start: Agentforce Coworker, unit "Enable and Use Agentforce Coworker in Your CRM":
  https://trailhead.salesforce.com/content/learn/modules/quick-start-agentforce-coworker/explore-agentforce-coworker
- [S15] CRM evolves from an input tool to a conversational partner: Agentforce Coworker launches (translated title;
  Salesforce Japan blog, 2026-06-10, read in Japanese):
  https://www.salesforce.com/jp/blog/jp-introducing-agentforce-coworker/

**Salesforce developer guide for Agentforce Coworker, ten pages read in a browser** (Chrome, 2026-11-13, by the brain,
and re-read by OPS-56 the same day). Each title is the page's own:

- [S8] Agentforce Coworker (guide home), read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-home.html
- [S20] About Agentforce Coworker, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-about-home.html
- [S21] Set Up Agentforce Coworker, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-setup-home.html
- [S7] Turn On Agentforce Coworker, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-turn-on-infrastructure.html
- [S22] Agentforce Coworker Benefits and Use Cases, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-benefits-and-use-cases.html
- [S23] Agentforce Coworker Limits and Guidelines, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-limits-and-guidelines.html
- [S10] Search, Ask, and Update Records with Agentforce Coworker, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-navigate-the-experience.html
- [S9] Search Agent and Agent Delegation in Agentforce Coworker, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-customize-delegate-agent.html
- [S24] Customize the Agentforce Coworker Results and Layout, read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-customize-results-and-layout.html
- [S25] Create a Quick Page with Agentforce Coworker (Beta), read in a browser:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-create-quick-page.html

**Guide pages NOT read** (every row that rests only on one of these keeps unverified (search summary); all refused the
fetch, HTTP 403): billing-considerations, geo-residency, einstein-data-usage, a-manage-search-data-home and its
children, manage-user-access, review-user-mapping, setup-dc1-companion, resume-rename-delete-chats,
manage-conversation-history and a-monitor-home.

- [S26] Add or Remove User Access in Agentforce Coworker (title from a search summary):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-manage-user-access.html
- [S11] Set Up Agentforce Coworker in a Companion Org:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-setup-dc1-companion.html
- [S12] Billing Considerations for Agentforce Coworker (Beta, per a search summary):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-billing-considerations.html
- [S13] Make Slack Searchable in Agentforce Coworker (Beta, per a search summary; not among the pages read):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-connect-to-new-data-sources.html
- [S14] Give Users Access to Create and Update Records with Agentforce Coworker (not among the pages read):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-allow-coworker-update-records.html
- Not used: the Salesforce Admins blog post "Meet Your Users' New AI Teammate: Introducing Agentforce Coworker"
  refused the fetch (403), and its only URL found carries a query string.

**General Agentforce, not confirmed for Coworker:**

- [S18] Agentforce Conversation Client API: https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html
  (read for BE-32, see [fr2-standard-limits.md](fr2-standard-limits.md))
- [S19] Agentforce Conversation Client Web SDK (Beta):
  https://developer.salesforce.com/docs/platform/accsdk/guide/acc-sdk-overview.html (search summary only)
- The Agent API and `generateAiAgentResponse` ([agent-api.md](agent-api.md)), Hosted MCP Servers
  ([salesforce-mcp.md](salesforce-mcp.md)) and custom Lightning types
  ([fr2-standard-limits.md](fr2-standard-limits.md)) are from earlier pages, not re-read.

**Secondary:**

- [S16] Agentforce Coworker: A Technical Deep Dive into Salesforce's New AI Teammate (Salesforce Ben, 2026-09-28,
  updated 2026-10-22), read:
  https://www.salesforceben.com/agentforce-coworker-a-technical-deep-dive-into-salesforces-new-ai-teammate/
- [S17] Agentforce Coworker 2026 guide (Salesforce Dictionary), search summary only:
  https://salesforcedictionary.com/blogs/agentforce-coworker-2026-guide
- Pages from coworker.ai are about a different company's product and are not used.

## Undo

Nothing to undo. The org check ran queries, describes and metadata lists only. Nothing was enabled, assigned,
deployed, published, activated, created or changed, and no agent or session was contacted.
