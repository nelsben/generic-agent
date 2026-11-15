# FR2: Agentforce Coworker against what Customer Summary builds (OPS-55)

Researched 2026-11-13 (OPS-55, corrected by OPS-56) and extended on 2026-11-14 (OPS-57: the rest of the guide, the search
API, the Coworker MCP server, custom Lightning types, Ben's answers and a re-run of the org check). The org check ran in
`agent-probe`, read-only: queries, describes and metadata lists only. Nothing was enabled, assigned, sent, deployed, published or changed. Ids, usernames and hostnames are
left out. Read with [feature-revision-2.md](../plans/feature-revision-2.md) (row F83) and
[fr2-design.md](../plans/fr2-design.md#operating-principles).

**Status words used on this page.**

- **read**: a Salesforce page fetched on 2026-11-13. The fetch tool hands back a small model's reading of the page,
  not the raw page, so "read" is one step short of reading it in a browser.
- **read in a browser**: the page text was read in Chrome by the brain on 2026-11-13 and re-read by OPS-56 the same
  day (the ten pages first listed under [Sources](#sources)), and read in Chrome on 2026-11-14 by OPS-57 (every other
  page marked so in Sources). The guide refuses automated fetches (HTTP 403), so this is the page's own text, not a
  small model's reading of it.
- **unverified (search summary)**: a page that was not read in a browser, or the Salesforce Admins blog and a Salesforce
  Help article, which a browser could not show. Facts from those come from search-engine summaries of them. They are
  not quoted. OPS-57 read every guide page that OPS-56 listed as not read, so no guide page is left in this state.
- **secondary**: a third-party page.
- **general Agentforce, not confirmed for Coworker**: a platform feature that no Coworker source says applies to
  Coworker.
- **verified**: seen in `agent-probe` by this run.

Quote marks mark words the fetch returned as the page's own. Exact text was asked for only on the pricing page [S2]
and on a second pass of the Trailhead unit [S6]; other quotes are as the fetch gave them. Without quote marks, a
line is a paraphrase. Every source has its
own line in [Sources](#sources).

## The answer to Ben's two questions

1. **Can our components call Coworker's Ask? Not proven.** Undocumented, and the BE-47 headless probe (2026-11-14, [table below](#headless-door-probe-be-47)) reached no Coworker door. The Search Agent is absent there, the Apex class `ConnectApi.Search` resolves but its `find(String)` method did not compile, and the Coworker MCP server was not tried. None of the guide pages read in a browser (30 pages now) names an API, Connect class, Apex class, invocable or LWC module that sends Coworker's Ask a message from inside the org [S8], [S20], [S21], [S42]. The one programmatic door Salesforce names is the Coworker MCP server, which serves outside AI clients such as Claude and ChatGPT (GA November 2026 per [S4]); its own docs were searched for on 2026-11-14 and not found. The documented in-org search door is the Connect REST Search resources and the Apex class `ConnectApi.Search` (API 63.0 and later), which Apex can call as the running user; that is the likely meaning of the limits page's "Enterprise Search API (search results)" (inference), and no page ties it to Coworker's data sources or its Ask answer [S23], [S43], [S44]. **Can they call a search door? Not reached.** The probe did not get a working call to any search door.
2. **Can we build our own UI around it? Undocumented.** None of the guide pages read in a browser documents a Coworker component, a Lightning page placement, a programmatic open, passing a record, a keyboard shortcut or branding; this rests on the browser reading of those pages and the guide's index [S10], [S9], [S42]. The guide describes an Ask page, toolbar tabs and a Quick Pages tab [S10], [S25]. Ben said he sees Coworker as a standalone app and tab; `agent-probe` has no such app or tab (see the check below). **The extension model the guide documents is our agent and its Lightning type cards shown inside Coworker's UI, not Coworker's UI inside ours** [S9].
3. **What can run inside Coworker is other agents, and their cards.** Coworker hands a request it cannot complete to any Agentforce agent the user can access, custom agents included, and routes on agent and topic descriptions only [S9]. So our Apex reaches Coworker's UI only through the `Customer_Summary` agent. When a delegated agent's response is configured to return a custom Lightning type or a Headless Experience Layer widget, Coworker shows that interactive card; otherwise it shows a markdown summary [S9]. **Cards from a delegated agent are documented.** Whether our own card envelope travels as a custom Lightning type is the open part; what it takes is under [What a card in Coworker takes](#what-a-card-in-coworker-takes).
4. **Either way in is an agent.** That is what ledger row F83 ruled out, and BE-32 measured an agent turn at 13 to 33 seconds for an explore question against 5 to 9 seconds direct. Reopening F83 for Coworker is Ben's decision.
5. **What comes free:** history, Teams, iOS and desktop, search over Slack, Google and Microsoft 365, Skills, and record creates and updates with Confirm. **Not covered:** our fixed summary, outcomes and sentiment, the hotkey window, the rail, the brand and the model seam. Keep FR2's custom build, and prove Coworker in an org before dropping anything.

## What Coworker is

| Question | Answer | Status and source |
|---|---|---|
| What it is | Salesforce's AI teammate: a user delegates work in natural language, and it plans the steps and coordinates Agentforce agents, flows and business actions, returning results for review | read [S1], [S3] |
| Product status | **Not stated as GA on a guide page; the sources still conflict.** Of the guide pages read in a browser, only "Create a Quick Page with Agentforce Coworker (Beta)" has Beta in its title [S25]. Turn On, Search, Ask, and Update Records, Search Agent and Agent Delegation, Billing Considerations and Make Slack Searchable do not [S7], [S10], [S9], [S12], [S13], and the Turn On page mentions no Beta Services Terms. The guide for Headless Experience Layer widgets, which Coworker's cards can use, is itself marked Beta [S47]. The earlier search summaries that showed "(Beta)" titles may be older copies. The 4 August 2026 blog's header says Coworker "is Generally Available" while its availability section says it "is in beta for Salesforce today" [S5]. The 4 November 2026 news story and the 5 November press release use no beta wording [S3], [S4]. This page does not settle it | read in a browser [S7], [S9], [S10], [S25]; read [S3], [S4], [S5] |
| Surface: Lightning | An Ask button next to the global search bar: "Click Ask next to the Salesforce global search bar" [S6]. The guide documents an Ask page with a side panel holding chats and a New chat control. Search and Ask each open in a toolbar tab. Closing an Ask tab does not delete the conversation, and only one recent Ask chat opens at a time. A link under the global search bar switches between Coworker and Standard Search [S10]. Quick Pages, which Coworker builds from a request, show on their own Quick Pages tab [S25] | read [S6]; read in a browser [S10], [S25] |
| Surface: Salesforce mobile app | The Trailhead unit says Coworker is accessible in Salesforce Lightning, Salesforce Mobile and more [S6]. The developer guide says the Search and Ask toolbar tabs are not available in the Salesforce mobile app [S10]. Field Service, Consumer Goods Cloud and Life Sciences Cloud mobile apps are expected in December 2026 [S4] | read [S6], [S4]; read in a browser [S10] |
| Surface: Microsoft Teams, iOS app, Mac and Windows desktop app | Generally available in November 2026 | read [S4], as of 2026-11-05 |
| Surface: Claude and ChatGPT | Through the Coworker MCP server: "as well as in Claude and ChatGPT through MCP". The MCP server is GA in November 2026 | read [S1], [S4] |
| Surface: Slack | A data source that can be made searchable [S6], [S13]. The August blog describes the same teammate in a Slack standup, with no date. No Coworker page lists Slack as a surface with a date | read [S5], [S6]; unverified [S13] |
| Licence and price (dated 2026-11-13) | "Agentforce Coworker User License", "$50", "USD/User/Month". Includes "All Coworker searches included" and "30 MBs of indexing per user per month". The page "is subject to change" | read [S2] |
| Billing | Seat-based and usage-based pricing can coexist in one org, and billing follows each user's licence. Seats: Agentforce Coworker for Enterprise or Unlimited Edition (per user per month, unmetered, with 30 MB of indexing per user per month pooled across the org, unused allowance not rolled over; cannot be bought alongside Agentforce 1 Edition or Agentforce for Sales, Service or Industries), or those Agentforce licences themselves, which include unmetered Coworker access. Usage-based: Flex Credits, Einstein Requests or Data Services Credits. Under a seat, CRM, Slack and federated-source queries are included, and so are Data 360 queries Coworker triggers; a Data 360 query a delegated agent triggers consumes credits. **Agent delegation is billed under the delegated agent's own terms.** Indexing beyond the pooled allowance consumes credits, and saving a Data 360 search source creates an index that can consume credits. Turning a source off or removing it does not stop the index consuming credits. A free trial for Flex Credits customers is GA in November 2026 | read in a browser [S12], [S7], [S37], [S40]; read [S4] |
| How it is enabled | The Turn On page lists the System Admin profile and the Agentforce Coworker Admin permission set. Setup, Quick Find "Agentforce Coworker", Get Started with Agentforce Coworker, Turn On, then Confirm in the window that appears; Einstein turns on with it [S7]. "Access to Agentforce Coworker is controlled through the Permission Set Group for Agentforce Coworker" [S6]. The Turn On page read in a browser lists a Confirm step and no terms. Earlier search summaries said turning on requires Beta Services Terms; what Setup actually shows is unverified. Turning on also creates an Identity Resolution ruleset that maps a user across CRM, Slack and Google by email or federated ID, viewable under User Mappings in Setup [S31]; CRM is added as a source on its own, and Data 360 objects, Slack and Google Workspace are optional extra sources [S37], [S13], [S38] | read in a browser [S7], [S31], [S37], [S13], [S38]; read [S6] |
| Who can use it | User access is through the permission set group whose API name is Access_Ai_Search [S10], [S32]. **How it is granted:** an admin with the System Admin profile and the Agentforce Coworker Admin permission set goes to Setup, Get Started with Agentforce Coworker, Manage Users, Manage, and on the Agentforce Coworker tab selects users and clicks Assign. For the Coworker Enterprise or Unlimited licence, the same users are also assigned on an Agentforce Coworker Unmetered User tab. For usage-based or Agentforce seats, the user holds Agentforce Coworker User; Agentforce 1 or Sales, Service or Industries seats also hold Unmetered User-Based AI, and the page says to finish "Configure User Permissions for Unmetered Licenses" first (that page was not read). Removing access means removing those permission sets from the user [S26]. Older names (AI Search) also appear in the guide | read in a browser [S10], [S26], [S32]; the user permission set name also read in [S15] |
| Licences and requirements | Seat-based access needs an Agentforce 1 Edition licence, an Agentforce for Sales, Service or Industries licence, or an Agentforce Coworker for Enterprise or for Unlimited Edition licence. Usage-based access needs entitlements of Flex Credits, Einstein Requests or Data Services Credits. Overall access needs Data Cloud or Data 360 provisioned and activated [S7] | read in a browser [S7] |
| Editions | Enterprise, Unlimited and Agentforce 1 Editions [S7], [S10]. The guide home says Coworker is not supported in Government Cloud Plus and warns not to turn it on there [S8] | read in a browser [S7], [S8], [S10]; read [S15] |
| Developer Edition | **Not among the listed editions** (Enterprise, Unlimited, Agentforce 1) [S7]. So whether an ordinary Developer Edition can turn Coworker on is undocumented. The Trailhead playground is the one Developer Edition route a source names: "a custom playground that contains Agentforce Coworker and our sample data", which it describes as a Developer Edition org tied to a Trailhead account [S6] | read in a browser [S7]; read [S6] |
| Data 360 | **Required for overall access per the Turn On page** [S7]; the guide home says Coworker is "Powered by Data 360" [S8], as does [S1]. [S15] said the Data 360 connector is optional and that CRM and Slack work without extra setup; that is the older reading, kept as what [S15] said. A secondary source says Data 360 must be enabled first [S16]. The companion-org page says Coworker can be set up in a Data Cloud One companion org: turn Coworker on in the home org first (and, optionally, make Data 360 objects searchable there), then in the companion org check that the connection is Active, the companion sync Succeeded and the data space's initialization Active, and set a Data Cloud Governance policy on the shared data space (Allow All Objects for most setups). If Coworker is already on in the home org, share that org's data space or use a home org without it [S11]. **For this repo that changes nothing unless an org is a Data Cloud One companion**; whether `agent-probe` is one is not readable by query | read in a browser [S7], [S8], [S11]; read [S1], [S15]; secondary [S16] |
| What it searches | Salesforce CRM by default: accounts, opportunities, contacts, cases and custom objects. Optional: Slack, Data 360 objects, and Google Drive, Gmail and Google Calendar, which each user connects and which are searched at query time. Microsoft 365 connectivity is listed as available now | read [S6], [S4] |
| What it indexes | 30 MB of indexing per user per month comes with the licence. What exactly is indexed, and how the CRM is indexed, is not stated on a page read | read [S2] |
| Whose access its answers use | "Regardless of which sources you enable, Agentforce Coworker never bypasses your security model." "Sharing rules, profiles, permission sets, and policies for Data 360 all apply." Field-level security is named only by a secondary source [S17]. For record updates, permissions are checked only when the user confirms (paraphrase of [S6]) | read [S6]; secondary [S17] |
| Writes | Coworker creates as well as updates records, up to 15 per command. An admin turns on the Agent Actions toggle in Coworker setup. An update shows current values beside proposed values. A new record shows mapped field values and related records. The user can refine the proposal before confirming. Coworker can propose a change the user has no permission to make, and it fails when applied [S10]. It can currently create or modify Salesforce CRM records only, and Salesforce's own log-a-call example proposes a new Task [S22]. Trailhead says the user clicks "Confirm" [S6]. The Japanese launch blog lists sending email, updating deal status and creating tasks [S15]. The access page adds: the toggle is Agent Actions on the Salesforce CRM source in the Add Existing Data table; an admin cannot limit it to users, objects or fields; Coworker checks only field-level required fields, not page-layout ones; it can skip field dependencies and validation rules, which then fail on confirm; and Salesforce keeps no dedicated audit log for what it changes, so standard field history does not tell Coworker's changes from a user's [S14] | read in a browser [S10], [S22], [S14]; read [S6], [S15] |
| History, Skills and later features | "Returns to prior Agentforce Coworker interactions via the History panel ..." (excerpt). Conversation History continues across Salesforce, Teams and the new apps. Skills are reusable, shareable workflows made from a conversation. Daily Digest and scheduled tasks are expected in December 2026 | read [S6], [S4] |
| Chat history: who sees it, how long, per user or per record | The guide saves chats in the Ask page side panel under Recents, titles them automatically, and lets the user reopen, rename or delete them. Deleting hides a chat from Recents but "doesn't delete the underlying data"; a deleted chat cannot be restored from Coworker. Recent searches in the search bar are not chat history [S32]. **Not stated on any page read:** who besides the user can see a chat, how long chats are kept, and whether history is ever scoped to a record. The page shows one list of chats per user, not a per-record view (my reading of how the page is written, not a stated rule). An admin route does exist: with Einstein Audit and Feedback data collection on, the LLM's responses for Coworker can be queried in Data 360 by anyone with Query Editor permission, and every request is recorded with a user and a timestamp [S35], [S34]. The guessed page name for a separate history-management page does not exist (the guide's index has none), so the "manage conversation history" page OPS-56 listed is recorded as not found | read in a browser [S32], [S34], [S35], [S42] |
| Models and where inference runs | Coworker uses Claude Haiku 4.5 to classify and route queries and Claude Sonnet 4.6 to synthesize answers, on Anthropic via AWS Bedrock. It follows the Agentforce geo-aware routing: it can fall back to US infrastructure where no local deployment exists or on an outage. The Einstein Setup toggle Enable In-Region Model Requests Only stops that, and makes requests fail in Brazil, Canada, India, Israel, Korea, Singapore and Switzerland. The page notes the Anthropic routing doc names only Haiku and treats Sonnet the same way [S28] | read in a browser [S28] |
| What data Einstein uses | Search terms, search results, CRM objects and connected sources, plus usage data (engagements, record IDs, org metadata); the page marks Coworker as using a global model, and points to the org's data-use controls [S29] | read in a browser [S29] |
| What the monitoring pages measure | Three things. Adoption in Data 360: the AI Agent Generative AI Usage object records each Coworker request with a user ID and timestamp (filter on the Coworker feature name), for active users, adoption rate and trends; it holds IDs not names. Responses in Data 360: the Einstein Audit and Feedback objects hold the LLM's responses, with tool calls mixed into the raw JSON; it needs audit data collection turned on. Credits in Digital Wallet: a Consumption by Feature report filtered to Coworker; seat users do not consume Flex Credits for CRM, Slack, federated or Data 360 queries, and Digital Wallet does not track those [S33], [S34], [S35], [S36] | read in a browser [S33], [S34], [S35], [S36] |

## The three answers

### 1. Headless call: can our LWC or Apex send Coworker a message and get its answer? Undocumented

None of the ten pages read in a browser names an API, Connect class, Apex class, invocable or LWC module that sends Coworker's Ask a message from inside the org, and the guide's index (every page title in Sources) shows no API or developer-extension page. The answer rests on that reading, not on search summaries. The answer for Ask stays: undocumented.

| Path | What the sources say | Status |
|---|---|---|
| A Coworker API, Connect class, Apex class, invocable or LWC module for Ask | None named on any of the ten pages read in a browser. The Trailhead unit says Coworker is "designed headless-first, meaning it isn't tied to any single UI" and "operates via APIs and meets your teams in the surfaces where they already work". It names no API. A headless design is not a documented door for our code | read in a browser [S8], [S20], [S21], [S7], [S22], [S23], [S10], [S9], [S24], [S25]; read [S6] |
| The Enterprise Search API (search results) | **A documented in-org door for search, not for Coworker's Ask.** The limits page lists an "Enterprise Search API (search results)" whose limits are the Connect API limits, a "Query Assist (suggestions)" limit, and a Search Agent limit of 100 requests a minute: the Search Agent uses the Agentforce Models API, with several model calls per query plan [S23]. **The docs found (OPS-57):** the Connect REST API Search resources, from API 63.0: a natural-language answer (`/connect/search/sobjects/answer`, and per object `/connect/search/sobjects/{objectApiName}/answer`), keyword result groups (`/connect/search/sobjects/result-groups`) and per-object results (`/connect/search/sobjects/{objectApiName}/results`, POST). **Apex:** the class `ConnectApi.Search` covers all of them (`answer`, `findAndGroup`, `find`, each with a `setTest` method) [S43], [S44]. **Auth:** Apex runs as the calling user; the REST resources are ordinary Connect REST calls, which count toward the org's API request allocation [S52]. **Apex in the same org:** yes, by the class. **An LWC:** no page says; the ordinary route is an Apex wrapper (general platform practice, not stated). **Returns:** the answer resources return an answer (the sample shows content, a generation reference and metadata); the results and result-group resources return records. They are separate calls, not one call with both. **Conditions:** the answer resources need search answers turned on in Einstein Search settings and do not support Search Manager customizations; the results resources can take a Search Manager configuration name [S43]. **Whether it reaches Coworker's Ask answer: not documented.** No page ties these resources to Coworker's data sources, its Search Agent or its answers, and that the limits page means these resources is my inference. **Query Assist:** no doc found; searches run on 2026-11-14: Connect REST API and Query Assist with Enterprise Search, the Connect REST reference index, and the Apex reference for ConnectApi search classes | read in a browser [S23], [S43], [S44], [S52] |
| The Coworker MCP server | Documented as a fact, for outside MCP clients: Claude and ChatGPT reach Coworker "through MCP" [S1]. It is GA in November 2026 [S4]. **Its own docs were not found on 2026-11-14.** Searches run: the Salesforce developer site for a Coworker MCP guide, Coworker with MCP and Claude or ChatGPT setup (twice), and the guide's own index, which lists no MCP page among the 30 pages read. Only Salesforce's general MCP pages (Agentforce acting as an MCP client, hosted MCP servers, the HXL widgets that can render in Claude, ChatGPT and Slackbot [S48]) and pages about another company's product named Coworker came back. So the tools, the OAuth flow, the scopes, whose user context it runs in, whether an in-org Apex or LWC caller is allowed, and whether it needs a connected app or External Client App are all **undocumented**. Nothing was signed in to or created | read [S1], [S4]; read in a browser [S42] |
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
| Our cards | **Documented yes, through a delegated agent and a custom Lightning type.** When a delegated agent's response is configured to return a custom Lightning type or a Headless Experience Layer widget, Coworker shows that interactive card and its card links as they appear in Lightning Experience; without that configuration it shows a markdown summary. Coworker's own answers stay in markdown, and the guide says a team does not build a separate user interface for Coworker [S9]. **Built, not measured (FE-24, 2026-11-14):** a spike Lightning type that carries our card envelope (FE-18, BE-39), its renderer drawn by our card component, and a spike agent are built under `spikes/coworker/main` and pass Jest locally. Whether Coworker draws the card is not measured, because `agent-probe` shows no Coworker page, so nothing was deployed. It is still through an agent, so F83 still applies. Coworker's own answers also come as tables, bullet lists or "Rich Card" layouts [S15]. Where Lightning types render otherwise is in [fr2-standard-limits.md](fr2-standard-limits.md) | Built locally by FE-24 (see [Cards in Coworker, built (FE-24)](#cards-in-coworker-built-fe-24)). What waits: an org that shows Coworker, then deploy, publish, activate and the three turns; the mechanics are under [What a card in Coworker takes](#what-a-card-in-coworker-takes) | read in a browser [S9]; read [S15]; built and Jest-proven locally, not measured in Coworker |
| Skills | **Undocumented as a developer extension.** Skills are reusable workflows that users save from a conversation and share. Trailhead says they "combine instructions, context, agents, and tools into shareable workflows for your org" (excerpt). Whether a team could ship a Skill as metadata is undocumented | none | read [S6], [S4] |

## What a card in Coworker takes

FE-24's starting point, from Salesforce's pages read in a browser on 2026-11-14. Salesforce says a delegated agent's response can come back as a custom Lightning type (CLT) card or a Headless Experience Layer (HXL) widget, and Coworker shows it instead of converting it to markdown [S9]. The rest is the general Agentforce mechanics those pages link. Everything here is through an agent, so F83 applies. Related rows for the standard panel are in [fr2-standard-limits.md](fr2-standard-limits.md).

| Question | Answer | Source |
|---|---|---|
| Metadata a type needs | A `LightningTypeBundle` (API 64.0 and later) in the project's `lightningTypes` folder: one folder per type, named for the type, with a required `schema.json`. For an output card from an Apex action, the schema's `lightning:type` points at the Apex class as an `@apexClassType` reference, and the structure is projected from the class's `@AuraEnabled` fields. The Apex class must be top-level, `global`, with `@JsonAccess(serializable='always' deserializable='always')`, and the page says no inner classes (the HXL example uses an inner class; the two pages disagree, as [fr2-standard-limits.md](fr2-standard-limits.md) already notes). Adding fields is safe; renaming or deleting the class, or changing or removing a field, breaks it | read in a browser [S45], [S46] |
| How an action's output is tied to a type | In Agent Script, the action's output parameter has type `object` with `complex_data_type_name` naming the type, and `is_displayable` must be True for a custom type to show. In the builder, Agentforce Assets, Actions, the output, Show in conversation, then Output Rendering with the type chosen; the type must be deployed first, and the agent page reloaded. The action must use Apex classes as input or output. No page has the model choosing a card | read in a browser [S51], [S47], [S50] |
| The renderer | In a channel folder inside the type, `renderer.json` with a `componentOverrides` entry (the `$` key for one item, or `collection` for a list) naming an LWC as `c/<name>`, and an `attributes` map from type properties to the LWC's public properties (the `{!$attrs.name}` form). The folder for the Lightning Experience employee agent is `lightningDesktopGenAi`; mobile is `lightningMobileGenAi` | read in a browser [S45], [S46] |
| May the renderer be our own LWC | **Yes.** It is an ordinary LWC, with the target `lightning__AgentforceOutput` in its meta file, at most one `sourceType` naming the type, and `@api` properties matching the map. A component bound to a custom type works only with that type | read in a browser [S46], [S49] |
| The HXL widget alternative | A `UiWidgetBundle` (API 67.0 and later, in the `uiWidgets` folder) with a composition file, a widget configuration file and a schema file; the type's `renderer.json` then sits at the type's root beside `schema.json`, with no channel folder, and references `@widget/c/<name>`. Types that reference widgets are defined in the DX project, not in Setup. The same widget can render in the Lightning Experience employee agent and, through MCP, in ChatGPT, Claude and Slackbot. Buttons can send a follow-up message to the agent. The HXL guide is Beta | read in a browser [S47], [S48] |
| Config in the agent bundle | The Agent Script action carries `complex_data_type_name` and `is_displayable` (above), so for an Agent Script agent the tie lives in the agent bundle. A misnamed type falls back to plain text with no error | read in a browser [S51]; [fr2-standard-limits.md](fr2-standard-limits.md) |
| Is an agent publish needed after the type is added | **Not stated on any page read.** The pages require the type to be deployed before it is chosen, and the builder page says to reload the agent page after saving the action. That the Agent Script tie needs a new agent version, as every agent change in this repo does (BE-21), is my inference, not a documented rule | not stated; inference |
| Where such a type renders | Per the type pages: the employee agent in Lightning Experience, the employee agent on mobile, the service agent through Enhanced Chat v2 (desktop and mobile), and Experience Builder (object-based types only; no Apex-based types; no `renderer.json`). **Coworker:** the delegation page says Coworker shows CLT cards and HXL widgets from a delegated agent, with card links as they appear in Lightning Experience, but does not say which channel folder Coworker reads. Coworker's Search and Ask tabs are not in the Salesforce mobile app [S10], so cards in Coworker on mobile are not documented | read in a browser [S45], [S46], [S9], [S10] |
| Advice for FE-24 | Start with the LWC override in `lightningDesktopGenAi`, because FE-18's card is an LWC, and watch whether Coworker draws it. If it shows as plain text, the HXL widget route is the documented one for surfaces beyond the standard panel. Either way, the test answers the unproven part of [S9]: whether our own envelope travels as a type | recommendation for the card, not a source fact |

## What Ben has answered

Read on 2026-11-14 from the Approvals table of [gtm-burn-plan.md](../plans/gtm-burn-plan.md) (row "FR2+: Agentforce Coworker live steps") and the Coworker row of "Ben's to-do from FR2" in [feature-revision-2.md](../plans/feature-revision-2.md).

| Question | What is recorded |
|---|---|
| The org Ben sees Coworker in | **`agent-probe`, approved 2026-11-14.** Ben's words: "Go, use agent probe org". The Approvals row "FR2+: Agentforce Coworker live steps" in [gtm-burn-plan.md](../plans/gtm-burn-plan.md) records it as approved for `agent-probe`, and names running the agent invocable and the search API from anonymous Apex. Approving it does not reopen F83. Ben said earlier, as recorded above, that he sees Coworker as a standalone app and tab; `agent-probe` has no such app or tab |
| Whether Setup in `agent-probe` offers Get Started with Agentforce Coworker | **Not answered.** It is still the look in For Ben, item 2; the to-do row lists it as optional |
| His answer on F83 | **Not answered.** The to-do row says F83 stands for now. His chat words that cut these cards ("great, lets cut cards for the coworker work, but continue our build otherwise") cut the cards and are not a go for the live steps, and the Approvals row says approving the live steps does not reopen F83 |

The live steps are approved for `agent-probe` (2026-11-14). The live steps that the approval names are the only ones any card may run; OPS-58 found no Coworker page there, so its live steps did not run.

## Feature map

Each row is something Customer Summary has built or plans in FR2. Free means a Coworker source covers it with no
build; partly means it covers some of it.

| Customer Summary feature | With Coworker | Source | What adopting it would lose or need rebuilt |
|---|---|---|---|
| The sourced account summary (seven sources, two pre-reduces, fixed sections; pattern 01) | **Partly.** Coworker answers questions about an account with cited sources. It has no fixed summary shape. Our summary could reach it through the agent, but BE-32 found the agent relays its layout loosely (1 of 6 section labels on its own line) | read [S15], [S6]; [fr2-standard-limits.md](fr2-standard-limits.md) | The fixed, sourced sections unless relayed through the agent, plus the "Summarize <Account>" one-click |
| Ask-anything explorer with drill-down (pattern 02, BE-31) | **Partly.** Coworker searches CRM objects including custom ones, answers in tables, and lets a user preview a cited record. Aggregates, a deny list, row counts and drill-down to related records are not documented | read [S6], [S15] | Our plan grammar, the admin deny list (BE-31), the guarantee that the model never writes SOQL, and the drill-down buttons |
| Conversation history a rep can return to (BE-26, FE-22) | **Free.** A History panel, and Conversation History across Salesforce, Teams and the apps | read [S6], [S4]; read in a browser [S32] | History scoped per account, and the access re-check on read. Who sees a Coworker chat, how long it is kept and whether it is per user or per record are not stated [S32] |
| Customer outcomes and sentiment (BE-35, BE-36, FE-19) | **Not covered.** No Coworker source describes storing what was done against the account. The Trailhead exercise gets a sentiment score by asking another agent | read [S6] | Nothing lost; the outcome store would still be ours to build |
| Voice input (FE-11, merged) | **Undocumented.** No Coworker source names a microphone or dictation | not found | The shared mic in every surface |
| Write actions with draft, Confirm and Undo (BE-22, BE-27, FE-14) | **Partly.** Create and update with Confirm, up to 15 records in one command, off until an admin turns on the Agent Actions toggle. The user can refine a proposal before confirming, which is documented now [S10]. Email is named in a blog [S15]. Undo is still undocumented. Salesforce's own log-a-call example creates a Task [S22], which bears on ledger F17 (Ben's decision; nothing else about F17 changes here) | read in a browser [S10], [S22]; read [S15] | Undo from stored previous values, the editable draft card, the fixed six-action set and the verb pre-check (BE-22) |
| Rich cards (FE-18, BE-39, FE-22) | **Partly.** Tables, bullets and "Rich Card" layouts of Coworker's own, and documented yes for a delegated agent's custom Lightning type card. Our card envelope as a spike Lightning type is built and Jest-proven locally (FE-24); whether Coworker draws it is not measured, because `agent-probe` shows no Coworker page. Still through an agent, so F83 applies | read in a browser [S9]; read [S15]; built locally (FE-24) | One card contract read by every surface, including MCP |
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
| Search Agent check (added 2026-11-14) | BotDefinition rows with Search in the name or label: 0. Permission set group named Access_Ai_Search: 0 |
| Agents (BotDefinition) | 2, both ours: `Account_Brief` and `Customer_Summary`, each type `InternalCopilot`, agent type `AgentforceEmployeeAgent`, version 2 active and version 1 inactive. No Search Agent and no Coworker agent |
| Agent metadata | 4 planner bundles and 2 agent definitions, all ours; 0 AI applications |

**Nothing Coworker exists in `agent-probe`**, so the org part stops here. There is also no Coworker app or tab, which matters because Ben said he sees Coworker as a standalone app and tab; the guide describes an Ask page, toolbar tabs and a Quick Pages tab [S10], [S25]. Neither agent is Coworker's. Whether
the Agent API could open a session on them is the open question already in [agent-api.md](agent-api.md): it excludes
only the "Agentforce (Default)" type, and Employee-type support is unproven there. The in-org invocable worked for
`Account_Brief` in that run. No session was opened by this card.

**Re-run, 2026-11-14 (OPS-57).** The same script ran again against `agent-probe` with the Search Agent and Access_Ai_Search checks added. Every count is the same as the 2026-11-13 run (edition, 0 Coworker permission sets, groups, licences, apps and tabs of 253, 4 Tooling objects, 3 search metadata types of 285, 2 agents with 4 versions, 4 planner bundles, 2 agent definitions, 0 AI applications). Only the date and the two new rows changed. The Approvals row names no org other than `agent-probe`, so no second-org run was made, and the script's new `--org` argument was not used with another alias.

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
on (card OPS-58) would show whether delegation relays our summary and explorer well enough to make B worth
weighing. B drops the brand swap, the hotkey window and the rail, which are the demo, and it rests on two undocumented
answers (1 and 2). No queued card changes until Ben decides F83 and one of the For Ben steps below has run.

## What stays unproven

- Whether Coworker is GA or beta in Lightning: no guide page states GA, and the sources conflict. Of 30 pages read, only the Quick Page title says Beta.
- Whether an ordinary Developer Edition can turn Coworker on: `agent-probe`'s Setup search shows no Coworker page (see [Delegation, measured](#delegation-measured)); a page under another name is not ruled out.
- Any in-org programmatic call to Coworker's Ask (answer 1): still unproven after the BE-47 probe, which reached no Coworker door. The Connect search class did not compile with `find(String)` in `agent-probe`, so whether another `ConnectApi.Search` signature works is unproven, and so is whether it returns what Coworker's own search returns. Whether Apex can be a client of the Coworker MCP server is unproven (docs not found; not tried).
- Any embed, hotkey, record context or branding for Coworker's UI (answer 2).
- What Setup shows when turning on (the Turn On page lists a Confirm step and no terms).
- Whether Coworker delegates to a custom Employee agent built in Agent Script, and how faithfully it relays the reply.
  A community thread doubts that Coworker's planner hands off to newer custom agents; it is not linked here because
  its URL carries an Id, and it is not evidence.
- Coworker's turn latency, alone and when delegating (the guide's 90-second limit is documented [S9]; BE-32's turns fit inside it).
- Whether Coworker draws our own card envelope (FE-18, BE-39) as a custom Lightning type. FE-24 built the type, its renderer and a spike agent, and Jest proves them locally, but nothing was deployed: `agent-probe` shows no Coworker page, so there was nowhere to look. Also unproven until a deploy and a publish: that the Apex compiles in an org, that the agent publishes with the type named as written, and that the type renders at all on the new planner. That a delegated agent's custom Lightning type card shows in Coworker is documented [S9]; it is still through an agent, so F83 applies.
- Field-level security in Coworker's own answers (secondary source only), and Undo for its writes (refining a proposal before Confirm is documented [S10]).
- Whether Coworker's actions draw Flex Credits under a seat licence (search summary of the billing page, and a
  secondary source that advises getting it in writing).
- Who besides the user can see a Coworker chat, how long chats are kept, and whether history is per record (the history page is silent), and whether an agent publish is needed after a type is added (not stated).
- Which channel folder Coworker reads for a card, and whether a Coworker card shows on mobile.
- Whether `agent-probe` is a Data Cloud One companion org, and what the unmetered-licence permission page (not read) adds for Agentforce seats.
- Everything this page still marks unverified (search summary): the Salesforce Admins blog and a Salesforce Help FAQ article that a browser could not show. No guide page is left in that state.

## For Ben

Each step needs Ben's go. None was taken in this card.

| # | Step | What it would prove |
|---|---|---|
| 1 | **Decide F83 for Coworker:** may an agent be a way in when the door is Coworker? | Whether options B and C are open at all |
| 2 | Look in `agent-probe` Setup for Get Started with Agentforce Coworker. A look, without turning it on. Still unanswered (see [What Ben has answered](#what-ben-has-answered)) | Whether this Developer Edition org is offered Coworker; the query check cannot see that |
| 3 | Create a Trailhead Coworker playground under his own Trailhead account, and follow the unit's own turn-on steps there | A free org that contains Coworker, so the UI facts can be seen: tab or panel, history, cards, mic, shortcut |
| 4 | Turn Coworker on in an org we hold. The Turn On page read in a browser lists a Confirm step and no terms [S7]; what Setup actually shows, and whether any terms appear, is unverified | Availability. Whether a Search Agent appears as a BotDefinition and what type it is (the guide says it appears in the agent list in Setup [S9]). What Setup offers |
| 5 | Assign the Coworker licence and permission set group to one test user, and give that user agent access (part of FE-20 undone for one user) | The rep's experience, and what Coworker can reach under a rep's access |
| 6 | Send Coworker a live message that should go to `Customer_Summary`, three or so times | Delegation, how faithfully the summary and an explore table are relayed, and the latency against BE-32's numbers |
| 7 | A prototype deploy and agent version with a custom Lightning type on one action. **Built locally by FE-24, not deployed** (see [Cards in Coworker, built (FE-24)](#cards-in-coworker-built-fe-24)). What waits: an org that shows Coworker (item 3 or 4), then a deploy of `spikes/coworker/main`, a publish and an activation of the spike agent, agent access for the test user, and the three turns | A delegated agent's Lightning type card showing in Coworker is documented yes [S9]. This proves whether our own card envelope travels as a Lightning type and is drawn by our card component. Still through an agent, so F83 applies |
| 8 | A live headless try: the Agent API against the Search Agent, an MCP client against the Coworker MCP server, or `ConnectApi.Search` from anonymous Apex | Partly run by BE-47 (2026-11-14, see [Headless door probe](#headless-door-probe-be-47)): the Search Agent is absent in `agent-probe`, `ConnectApi.Search.find(String)` did not compile (not reached), and the MCP server was not tried. Still open: another `ConnectApi.Search` signature, and the MCP server's OAuth route, which needs Ben's go before any app is created |
| 9 | Ask the account executive: price under our agreements, Flex Credit draw for Agent Actions (the billing page covers queries and delegation, not record writes), Developer Edition and sandbox availability, chat retention and who can see a chat, and GA status in Lightning | The dated licence facts this page could only read from public pages |

## Delegation, measured

**Not measured (OPS-58, attempts 1 and 2, 2026-11-14): Setup in `agent-probe` has no Coworker page.** The Approvals row
"FR2+: Agentforce Coworker live steps" is approved for `agent-probe` (Ben, 2026-11-14). Approving it does not reopen
ledger F83.

- **Attempt 1** stopped at the login page: no browser session was signed in.
- **Attempt 2** used a Chrome session Ben had signed in to `agent-probe` as the org admin, the test user. In a tab the
  run created, Setup's Quick Find showed "No matching items found" for "Coworker" and for "Get Started". Searching
  "Agentforce" listed Agentforce pages (for example "Setup with Agentforce", which is a different feature), and none was
  Get Started with Agentforce Coworker. Setup's home page offered only a prompt to set up Setup with an Agent. This
  answers the open item "whether an ordinary Developer Edition can turn Coworker on": this one shows no way to,
  through Setup's search. The page may live under a name the search does not match; this run did not look further.
- Per the card, no other Setup step was taken. Nothing was turned on, granted, deployed or changed, no turn was sent,
  and the run's tab was closed (Ben's signed-in tab was left open).
- The admin already holds agent access to `Customer_Summary` through the product's own permission sets; no
  Access_Ai_Search permission set group was found assigned to any user.

The three questions times three turns are therefore unrun, and there are no timings to put beside BE-32's. To go on,
Ben picks another org that shows the Coworker page (For Ben item 3, a Trailhead Coworker playground), names it in the
Approvals row, and signs in there as the test user.

**Undo.** Granted: nothing. Removed: nothing. Left in the org: nothing.

## Headless door probe (BE-47)

Run 2026-11-14 in `agent-probe` as the org's admin user, from anonymous Apex. Scripts are in [spikes/coworker/apex](../../spikes/coworker/apex/) and results are in [headless.jsonl](../../spikes/coworker/results/headless.jsonl). Approved by the Approvals row "FR2+: Agentforce Coworker live steps" (Ben, 2026-11-14), which names the agent invocable and the search API from anonymous Apex. Nothing was deployed, granted, created or signed in to; no DML was run. Ids, names and session Ids are left out.

| Door | Target | Result | Evidence and reason |
|---|---|---|---|
| 1. Search Agent through `generateAiAgentResponse` | the platform Search Agent | **not tried: no Search Agent in this org** | A read-only `BotDefinition` query for Search in the developer name or label returned 0 rows. Turning Coworker on is what would create it, and Setup shows no Coworker page here ([Delegation, measured](#delegation-measured)). |
| 1 control. The same invocable against our own agent | `Customer_Summary` | **yes, the control works** | One turn, status ok, reply of 3,087 characters, which names the seed account, 36 seconds. A session came back and was not ended (see Undo). This shows the invocable path works for our agent, not for Coworker. |
| 2. Enterprise Search through the Apex class `ConnectApi.Search` | `find(String)`, one call, the seed account name as the term | **not reached (our call did not compile)** | Two compile attempts and no run reached data. Round 1: `Invalid type: ConnectApi.SearchResults`. Round 2: `Method does not exist or incorrect signature: find(String) from the type ConnectApi.Search`. The class resolves in this org at API 68.0, but the one-argument `find` does not. The documented signatures could not be read: the Apex reference page refused the automated read (HTTP 403), so no further signature was guessed. The answer resource (the summary) was not called. |
| 3. Coworker MCP server | tools-list | **not tried: needs an OAuth client for an outside MCP client** | OPS-57 found no in-org route. The server is for outside clients, and reaching it needs a connected app or External Client App, which this card may not create. Its docs were not found, so the scopes and user context are unknown. Never signed in. |

**Answer 1 from this probe: not proven.** No door answered from Apex: the Search Agent is absent, the `ConnectApi.Search` call did not compile, and the MCP server was not tried. The control only proves that our own agent answers from Apex, as it did for `Account_Brief`.

**Proposal for Ben, if a door works later.** None works yet, so there is nothing to build on. The next step for door 2 is to read the documented `ConnectApi.Search` signatures (the Apex reference page refused the automated read) and then run one call in a separate card. Any Coworker door from our code would make Coworker a way in, which is F83 and Ben's decision.

## Cards in Coworker, built (FE-24)

Built 2026-11-14 as files only. Nothing was deployed, validated, published, activated or granted, and no agent was
contacted. The only org calls were read-only metadata lists in `agent-probe`. They showed that the org already holds
our card component, and that it holds no Lightning type bundles yet, which means the type is supported. **Whether
Coworker draws the card is not measured**, because `agent-probe` shows no Coworker page ([Delegation, measured](#delegation-measured)).

| Part | Where, under `spikes/coworker/main/default` | What it does |
|---|---|---|
| Lightning type `coworkerSpikeSummaryCard` | `lightningTypes/coworkerSpikeSummaryCard/schema.json` | Points at the Apex class as an `@apexClassType` reference |
| Renderer config | `lightningTypes/coworkerSpikeSummaryCard/lightningDesktopGenAi/renderer.json` | Names the renderer LWC and maps each type member to one of its `@api` properties |
| Renderer LWC `coworkerSpikeCardRenderer` | `lwc/coworkerSpikeCardRenderer` | Target `lightning__AgentforceOutput`, one `sourceType`. It rebuilds the card and draws it with our card component (`c-customer-summary-card`) at density compact. A record link opens the record by Id through navigation; no Id goes in the markup |
| Apex type `CoworkerSpikeSummaryCard` and its parts | `classes/CoworkerSpikeSummaryCard.cls`, `CoworkerSpikeCardBlock`, `CoworkerSpikeCardRun`, `CoworkerSpikeCardRef` | Top-level `global` classes with `@JsonAccess`, members exactly those of BE-39's summary card (type, version, key, title, meta, status, text, body, refs) |
| Apex action `CoworkerSpikeCardAction` and its test | `classes/CoworkerSpikeCardAction.cls`, `CoworkerSpikeCardActionTest.cls` | Resolves the account name and returns the summary card. A name that does not resolve gets a fixed notice card, so the resolver's message (which can carry Ids) never reaches the card |
| Spike agent `Customer_Summary_Coworker_Spike` | `aiAuthoringBundles/Customer_Summary_Coworker_Spike` | An Employee agent that answers only "card spike" requests with one action. Its `card` output names the type through `complex_data_type_name` and is displayable |

The renderer uses the card component from `force-app` and does not copy it. The org has one namespace, so the
component resolves once deployed beside it, and Jest resolves it across package folders. `force-app` and the
`Customer_Summary` agent are unchanged.

**What was checked locally.**

- Jest: `npx sfdx-lwc-jest -- --roots spikes/coworker`, 2 suites, 9 tests passed. They show that the renderer draws BE-39's
  published summary example, falls back to the card's text for an unknown type, puts no record Id in the markup, and
  passes `toBeAccessible()`. A wiring test checks that the Apex members, `renderer.json`, the renderer's properties and
  the agent's action agree with BE-39's keys.
- The Lightning Web Security review of the renderer: no findings.
- The spike agent compiled locally with no diagnostics (`@sf-agentscript/agentforce` 2.9.27).
- `sf project convert source` over the spike folder succeeded, so the metadata is shaped correctly. It found one agent bundle, six Apex classes, one LWC and one Lightning type. The converted copy was deleted.
- Not checked: the Apex is not compiled in an org, and its test class has not run.

**What waits, in order.** Each step needs Ben's go (For Ben, item 7).

1. An org that shows Coworker (For Ben, item 3 or 4).
2. A validate with local tests and a quick deploy of `spikes/coworker/main`. It needs our card component, the resolver and
   the summary action already in that org.
3. A publish and an activation of `Customer_Summary_Coworker_Spike`, and agent access for the test user.
4. Three turns through Coworker that ask for a "card spike" for the seed account, plus one in the standard panel as a
   control. Each turn is recorded in a `cards.jsonl` with no Ids, with one capture.
5. A deactivation of the spike agent, and an Undo list that says so.

**Risks named before a deploy.**

- The type name in the agent is written `c__coworkerSpikeSummaryCard`, which is inferred from the type pages and not
  confirmed by a publish. A misnamed type falls back to plain text with no error.
- A known issue in the Agent Script skill says custom Lightning types may not render on the new planner. If that
  happens, the HXL widget route is next ([What a card in Coworker takes](#what-a-card-in-coworker-takes)).

There are no `cards.jsonl` rows and no captures, because no turn ran.

## Follow-up cards

The brain cut these on 2026-11-13. Card 1 ran on 2026-11-14.

1. **OPS-57: everything readable without a live step.** Done: the rest of the developer guide, the Enterprise Search
   API, the Coworker MCP server (docs not found), custom Lightning types and HXL widgets for agent answers, Ben's
   answers (none yet), and a re-run of the read-only inventory. It replaces the earlier "availability read" idea in
   its read-only parts; the availability look still needs Ben (For Ben, item 2 or 3).
2. **OPS-58: delegation prototype.** Scope: `spikes/coworker/**` and a new section on this page. Needs F83
   reopened for the spike, the Approvals row "FR2+: Agentforce Coworker live steps" and For Ben items 4 to 6.
   - Done when three live turns per question (one summary, two explore questions) go through Coworker to
     `Customer_Summary`, with results logged as counts and timings, like BE-32's.
   - Done when relay fidelity (rows, section labels) and latency are compared with BE-32's direct and agent numbers.
   - Done when the agent access granted for the test is removed again, and an Undo list says so.
3. **FE-24: cards inside Coworker.** Scope: `spikes/coworker/**`, a spike-only Lightning type and agent version. Needs
   OPS-58's result and For Ben item 7. Start from [What a card in Coworker takes](#what-a-card-in-coworker-takes).
   - Done when one action's output carries our card envelope as a custom Lightning type drawn by our card component, and the page records whether Coworker shows it. Delegated-agent Lightning type cards are documented yes [S9]; this tests our envelope (FE-18, BE-39), and it is still through an agent, so F83 applies.
   - Done when one capture or Ben's screenshot shows the result.
   - Done when the spike's agent version is deactivated, and an Undo list says so.
   - Status (2026-11-14): built locally, not measured. See [Cards in Coworker, built (FE-24)](#cards-in-coworker-built-fe-24).
4. **BE-47: headless door probe.** Scope: `spikes/coworker/**`. Needs For Ben item 8. The reading half is done by OPS-57
   (the search API docs are read, and the Coworker MCP server's docs were searched for and not found), so this card is
   the live half.
   - Done when one Agent API start-session against the Search Agent is tried, and its status code and message are
     recorded with no Ids.
   - Done when `ConnectApi.Search` is called from anonymous Apex in the org Ben names, and whether its answer or results
     match what Coworker's own search returns is recorded [S44].
   - Done when answer 1 on this page reads yes or no, with the evidence.
   - Status (2026-11-14): run. Answer 1 is not proven; no door answered. See [Headless door probe](#headless-door-probe-be-47).
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

**Guide pages read in a browser by OPS-57** (Chrome, 2026-11-14; these are the pages OPS-56 listed as not read, plus
the pages that hang under them; each title is the page's own). Page names that were guessed and did not exist: a
"manage conversation history" page (the browser showed a 404; the guide's index has no such page).

- [S26] Add or Remove User Access in Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-manage-user-access.html
- [S11] Set Up Agentforce Coworker in a Companion Org:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-setup-dc1-companion.html
- [S12] Billing Considerations for Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-billing-considerations.html
- [S13] Make Slack Searchable in Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-connect-to-new-data-sources.html
- [S14] Give Users Access to Create and Update Records with Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-allow-coworker-update-records.html
- [S28] Geo-Aware Routing for Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-geo-residency.html
- [S29] Einstein and Data Usage in Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-einstein-data-usage.html
- [S30] Manage Agentforce Coworker Search Data (Optional):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-manage-search-data-home.html
- [S31] Review Agentforce Coworker User Mapping:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-review-user-mapping.html
- [S32] Resume, Rename, or Delete Chats in Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-resume-rename-delete-chats.html
- [S33] Monitor Agentforce Coworker Metrics:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-monitor-home.html
- [S34] Query Agentforce Coworker Usage and Adoption Data in Data 360:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-query-usage-data.html
- [S35] Review Agentforce Coworker Responses in Data 360:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-query-audit-trail.html
- [S36] Monitor Agentforce Coworker Credit Consumption in Digital Wallet:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-monitor-consumption.html
- [S37] Make Data 360 Objects Searchable in Agentforce Coworker:
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-connect-to-existing-data-sources.html
- [S38] Make Google Workspace Apps Searchable in Agentforce Coworker, and Connect Your Google Account to Agentforce Coworker (two pages, both read):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-google-make-searchable-fed-search.html
- [S40] Turn Off or Remove a Data Source in Agentforce Coworker, and Rename a Data Source in Agentforce Coworker (two pages, both read):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-turn-off-remove-source.html
- [S42] Use Agentforce Coworker (the guide section page that lists the experience pages):
  https://developer.salesforce.com/docs/data/agentforce-coworker/guide/agentforce-coworker-a-manage-experience-home.html

**Other Salesforce pages read in a browser by OPS-57** (Chrome, 2026-11-14):

- [S43] Connect REST API (Core), Search Resources section (Connect REST API Developer Guide, v68.0 reference):
  https://developer.salesforce.com/docs/platform/connect-rest-api/references/connect-rest-api-core
- [S44] Search Class (Apex Reference Guide, ConnectApi):
  https://developer.salesforce.com/docs/platform/apex-ref/references/apex-ref/apex-connectapi-search-static-methods.html
- [S45] Core Concepts of Custom Lightning Types (Lightning Types Developer Guide; the page the delegation page links as "Custom Lightning Types"):
  https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-core.html
- [S46] Apex-Based Custom Lightning Types (Lightning Types Developer Guide):
  https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-apex.html
- [S47] Use HXL Widgets as Agentforce Action Output (Headless Experience Layer Developer Guide, Beta):
  https://developer.salesforce.com/docs/platform/hxl/guide/agentforce-action-output.html
- [S48] Build Rich UI Experiences with HXL Widgets (Headless Experience Layer Developer Guide, Beta):
  https://developer.salesforce.com/docs/platform/hxl/guide/hxl-rich-ui.html
- [S49] lightning__AgentforceOutput Target (Lightning Web Components Developer Guide):
  https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-agentforce-output.html
- [S50] Customize the Agent Action UI with Lightning Types (Agentforce Developer Guide):
  https://developer.salesforce.com/docs/ai/agentforce/guide/lightning-types.html
- [S51] Agent Script actions reference (Agentforce Developer Guide):
  https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html
- [S52] API Request Limits and Allocations (Salesforce Developer Limits and Allocations Quick Reference):
  https://developer.salesforce.com/docs/platform/salesforce-app-limits-cheatsheet/guide/salesforce-app-limits-platform-api.html

**Not readable or not used:**

- The Salesforce Admins blog post "Meet Your Users' New AI Teammate: Introducing Agentforce Coworker" refused the
  fetch (403), and its only URL found carries a query string.
- The Salesforce Help article "FAQs: Agentforce Coworker General Info and Troubleshooting" (article 005387735): a
  browser showed only a blank "Modal Body" with no text, so nothing from it is used.
- Search results for the Coworker MCP server returned only general Agentforce MCP pages and another company's
  product; none is used as a source for Coworker.

**Guide pages not read:** none among those OPS-56 listed. One page the guide names, "Configure User Permissions for Unmetered Licenses", was not opened.

**General Agentforce, not confirmed for Coworker:**

- [S18] Agentforce Conversation Client API: https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html
  (read for BE-32, see [fr2-standard-limits.md](fr2-standard-limits.md))
- [S19] Agentforce Conversation Client Web SDK (Beta):
  https://developer.salesforce.com/docs/platform/accsdk/guide/acc-sdk-overview.html (search summary only)
- The Agent API and `generateAiAgentResponse` ([agent-api.md](agent-api.md)), Hosted MCP Servers
  ([salesforce-mcp.md](salesforce-mcp.md)) and custom Lightning types
  ([fr2-standard-limits.md](fr2-standard-limits.md)) are from earlier pages; the Lightning type and HXL pages were re-read by OPS-57 and are [S45] to [S51].

**Secondary:**

- [S16] Agentforce Coworker: A Technical Deep Dive into Salesforce's New AI Teammate (Salesforce Ben, 2026-09-28,
  updated 2026-10-22), read:
  https://www.salesforceben.com/agentforce-coworker-a-technical-deep-dive-into-salesforces-new-ai-teammate/
- [S17] Agentforce Coworker 2026 guide (Salesforce Dictionary), search summary only:
  https://salesforcedictionary.com/blogs/agentforce-coworker-2026-guide
- Pages from coworker.ai are about a different company's product and are not used.

## Undo

Nothing to undo. The org checks (2026-11-13 and the 2026-11-14 re-run) ran queries, describes and metadata lists only. Nothing was enabled, assigned,
deployed, published, activated, created or changed, and no agent or session was contacted.


**BE-47 headless probe (2026-11-14).** Granted: nothing. Deployed: nothing. Created: no user, no connected app, no External Client App, no Named Credential, no auth provider. DML: none. Session left open: one, from the `Customer_Summary` control turn ([Headless door probe](#headless-door-probe-be-47)). The invocable has no end call, and the Agent API end call needs a token this card does not get, so the session was not ended and expires on the platform's own timer (the expiry time is not found in [agent-api.md](agent-api.md)).

**FE-24 cards build (2026-11-14).** Nothing was left in any org. Only read-only metadata lists ran in `agent-probe`. Deployed, published, activated, granted, created: nothing.
