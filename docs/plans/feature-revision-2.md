# Feature revision 2 (FR2): one branded agent, three surfaces

Ben (product stakeholder) gave this feedback on 2026-11-12 in two messages, with answers to follow-up questions. It is
the source of truth for every card titled `FR2:`. An adversarial review checks the cards against this ledger: every row
must name a card, or say it is tabled, open or Ben's own. Quotes are Ben's words, shortened. "[reference app]" stands in
for the reference application he pointed to; its patterns are written up, without its name, in
[fr2-design.md](fr2-design.md).

Roles: Ben is the product stakeholder. The brain is the designer, consultant and workflow lead, and it cuts the cards.
More notes are coming page by page, starting with the README. They are added to this ledger as new rows.

## Ledger

Status values: a card id, **tabled** (Ben deferred it), **open** (waiting on Ben's answer), **Ben** (his to do), or
**done**.

### Positioning and brand

| # | Feedback | Status |
|---|----------|--------|
| F01 | "create a generic agent that we can distribute to other customers and have teams be able to take this as an accelerator, understand what needs to be built, and then bring it to other users, other use cases, and think about Agentforce a little bit differently" | `OPS-36` |
| F02 | "one agent with a lot of sub-agent capabilities. Much like how Claude can handle and route different requests, we want one branded agent or one agentic capability top of mind" | [fr2-design.md](fr2-design.md) (one agent, many skills), `OPS-36`; also `BE-28` |
| F03 | "instead of account brief, customer summary": the branded name highlights the primary use case | `BE-21`, `BE-23`, `OPS-30` |
| F04 | "can be used in multiple different places and can be consumed by MCP" | `OPS-31` (the MCP door under the new name), `OPS-36` |
| F05 | "Users respond better to something that's branded ... more seller-friendly" | `BE-24` |
| F06 | "a salesperson can come in, grab the repo, spin it up, replace the agent name placeholder with the customer name ... and generate a compelling demo just based on easy placeholder swap outs" | `BE-24` (settings and swap guide), `OPS-36` |
| F07 | Rename internal names too, "as long as we can do it effectively. If we hit the same friction ... with publishing multiple agent versions, we can skip" it | `BE-21` (go/no-go, falls back to labels only); also `BE-23`, `OPS-30` |
| F08 | A seller can change "the company name, the agent name, the logo, the colors, the tone of the agent" | `BE-24` (name, company, logo, colours, tone in Apex prompts), `BE-28` (tone in the agent) |
| F09 | Styling stays flexible per prospect so "sales teams ... and implementation teams can easily pull in details" | `BE-24`, `FE-12` (all colours and type from theme variables) |
| F10 | Demo data and industry prospect scenarios, possibly "different GitHub repos with different options to ... populate different industry scenarios" | **tabled**, parked card `OPS-34` |
| F11 | One command or a setup page in the org for the swap | **tabled**, parked card `OPS-34` |

### Capabilities

| # | Feedback | Status |
|---|----------|--------|
| F12 | "introduce several different layers of agentic capability with our agent" | [fr2-design.md](fr2-design.md) (skills: summary, ask anything, actions), `FE-12` |
| F13 | Voice: "Sellers don't want to type ... a little microphone button in all of our windows and widgets that is able to capture voice with our custom component" | `FE-11`, `FE-12` (mic in the shared composer, so every surface has it); also `OPS-29` |
| F14 | Voice engine: reuse "[reference app]'s" capture; "Browser's built-in speech recognition is appropriate" | `FE-11`; the browser sends audio to its vendor, so the README needs a privacy line (`OPS-36`); also `OPS-29` |
| F15 | "verbally or through the chat create follow-up tasks, events ... a consideration for our architecture ... along the parallel path of ask any question" | `BE-22`, `BE-27`, `FE-14`, `BE-28` |
| F16 | First actions: "create a task, create an event ... log a call ... update contact, create case, update opportunity". "skip draft an email for now" | `BE-27`; no email drafting; also `BE-22`, `BE-28`, `FE-14` |
| F17 | "Log a call, which I think is synonymous with create an event" | **open**: `BE-27` waits for Ben's answer. The brain recommends a completed Task with type Call, because that is what Salesforce's own Log a Call saves and what activity reports count; an Event fits if calls are booked ahead and should show on the calendar. `BE-22` describes both |
| F18 | Every create or update shows a draft and writes only on Confirm (brain's recommendation, not contested) | `BE-27`, `FE-14`; also `BE-22` |
| F19 | "Across all of our surfaces, voice is still prominent ... We also need to be able to type ... quick actions ... and also conversation history" | `FE-12` (voice, typing, quick actions), `BE-26` and `FE-15` (history) |

### Surface 1: compact window (today's "terminal" panel)

| # | Feedback | Status |
|---|----------|--------|
| F20 | Pop-out moves from bottom left to bottom right. Then: "we don't want to compete with any sort of CTI connector ... these actions stack ... I'm expecting you to be able to do a spike to determine which" | `OPS-29` decides the corner, `FE-13` builds it |
| F21 | "the command press key ... to pop out" the compact agent; "a highlighted command K key to open up the agent" | `FE-13` (Cmd/Ctrl-K plus a visible launcher that shows the key); also `OPS-29` |
| F22 | "the view is really condensed and really does not scale well. We want this to feel a little bit more like Claude"; use "[reference app]" for "how ... to represent agentic conversation and agentic capability" | [fr2-design.md](fr2-design.md), `FE-12`, `FE-13` |
| F23 | "Definitely not opposed to the compact agent ... one of the agent surfaces" | `FE-13` (kept) |
| F24 | "the ability for the agent session to pop out with a button click to take up a larger part of the screen ... I like the slide in and slide out, and we want to be able to demonstrate" it | `FE-15` (expand carries the same session into the large view), `FE-13` (slide motion) |

### Surface 2: large right rail

| # | Feedback | Status |
|---|----------|--------|
| F25 | "the agent is hidden, sellers press a button, the agent pops open, and it ... pushes the content from the right-hand side of the screen to the left" | `OPS-29` (can a custom component push the page?), `FE-15` |
| F26 | "It can also be a hover over, or there could be like a minimize"; "sliding over the page is acceptable if pushing is impossible" | `OPS-29`, `FE-15` |
| F27 | "a full experience that feels like Claude built into or overlaying Salesforce ... meaningful conversations ... briefs, follow-ups, questions, and create tasks and action items" | `FE-15`, `FE-12`, `FE-14` |
| F28 | "These aren't competing ... surfaces ... having a couple of different levels of variability would be really good" | [fr2-design.md](fr2-design.md), `OPS-36`; also `FE-15` |
| F29 | Rail shows "session history, open deals, and ... prefetched information"; the key details are open deals, recent activity, cases and the last brief, plus "recent engagement ... emails, phone calls, case comments synced back to Salesforce" under recent activity | `BE-25`, `FE-15` |
| F30 | "bringing that surface to light in a larger window automatically with the button press" | `FE-15` (its own hotkey, Cmd/Ctrl-Shift-K, opens the large view directly); also `OPS-29` |
| F31 | "streamlined, it feels good to use, and we can keep things moving fast and feeling fluid" | `FE-15`, `FE-13` (motion and speed budgets), `OPS-35` |
| F32 | "show that this customer has had this interaction through history" | `BE-26`. Who can see another rep's history is **open** (asked as Q7, not answered); the card stores history per account and per user, and shows a user their own until Ben decides; also `FE-15` |
| F33 | "comfortable, not too tight, and feel like Claude or coworker inside of the right-hand window" | [fr2-design.md](fr2-design.md), `FE-15` |
| F34 | Use case: "the seller or the customer service rep that might hit a keystroke to open up the agent to see information or to expand on something that isn't on the screen" | `FE-15`, `OPS-36` |
| F35 | Two hotkeys, one for the compact pop-out and one for the larger view, not reserved by Chrome on Mac; the brain picks | `OPS-29` checks Cmd/Ctrl-K (compact) and Cmd/Ctrl-Shift-K (rail); `FE-13`, `FE-15` |

### Surface 3: embedded on the page (call centre)

| # | Feedback | Status |
|---|----------|--------|
| F36 | "embedding on a page directly. Take CTI as an example ... you would accept the call, that customer's information would populate your screen and an agentic prompt or conversation would potentially start ... embedded on the screen as a component" | **tabled**: placeholder page `OPS-32`, parked spike `OPS-33` |
| F37 | The rep is "briefed on their customer as soon as they accept the call ... account map, and variables and fields ... access to things like knowledge articles or support ... take action to follow up" | **tabled**: written into `OPS-32` and `OPS-33` |
| F38 | "table this as a much larger spike. We want to be true and realistic to how Salesforce will actually provision and be used for call center workflows ... put a placeholder in and keep it safe" | `OPS-32` (placeholder only), `OPS-33` (parked, needs Ben's go) |

### Working model and sequencing

| # | Feedback | Status |
|---|----------|--------|
| F39 | "cut new cards, do design ... build a new plan based on the feedback" | this page, [fr2-design.md](fr2-design.md), the `FR2:` cards |
| F40 | "make sure it's tagged ... so we can do an adversarial review against the cards once the plan is complete" | `OPS-37` (run on Ben's word) |
| F41 | BE-19: follow the brain's recommendation (relaunch, light touch on the panel) | `BE-20` (running) |
| F42 | Page-by-page notes, starting with the README | **open**: new rows go here, mostly into `OPS-36` |
| F43 | The original goal still stands: "testing, playwright screenshots with frontend validation, architecture reviews" | `OPS-35`, `OPS-36` |

### Chapter notes: pattern 01, route, gather, reduce

Ben's notes on [01-route-gather-reduce.md](../patterns/01-route-gather-reduce.md), 2026-11-12. "[reference guide]" stands
in for the confidential operating guide he sent; its name and client stay out of this repo.

| # | Feedback | Status |
|---|----------|--------|
| F44 | "talk about the philosophy of route, gather, reduce ... this is going into Customer 360 a little bit and how we can use Agentforce without Data Cloud to shape customer context" | `OPS-38` |
| F45 | "there's two parts of this. There's the business impact and then there's the architecture" | `OPS-38` |
| F46 | "Everyone wants deal history, service history, and an insight into the customer they're speaking with or about to speak with ... articulate ... how easy it is, how there's a narrative overlaying customer summaries that's customizable by industry" | `OPS-38` (how to change the sections and the narrative today, with an industry example); a built industry switch is **open**, see F50 |
| F47 | "how we scale that out architecturally. How do we make it super simple to build a graph of all of the data, pass it to an LLM, and make sure that the summary is accurate?" | `OPS-38` (the account's data graph, gathered as sections, and why the summary stays accurate); `BE-29` (an accuracy check that proves it) |
| F48 | "Focused LLM callouts to summarize key information, like which was articulated in the [reference guide] ... is the design pattern that we want to communicate" | `OPS-38` (pre-reduce, restated in generic terms) |
| F49 | Sequence diagrams: "incorporate auto number, colors, fonts, and build truly beautiful sequence diagrams"; auto number "so that each step can correspond with a specific number to allow the user to track"; colour "to make it look beautiful and break it up" | `OPS-38` for pattern 01; the rule for every diagram is in [fr2-design.md](fr2-design.md#diagrams), applied by `OPS-36` and each later chapter card |
| F50 | "show from the document our reduction structure ... this might not be deal history, it might not be engagement history, but it might be case history, it might be order history" | `OPS-38` (the reduction structure as a diagram and a table of swappable sections, with case history and order history as worked examples). **Open:** whether to build an industry switch (a setting that picks the sections and the narrative), or leave it to the tabled `OPS-34` |
| F51 | "talk about why you can trust this architecture and how you can scale it" | `OPS-38` |
| F52 | "cover limits and open items as part of future cards to cut" | `BE-29` (N1, N2, N3, N7 and N8 from the Apex re-review, and the accuracy check); the non-admin run stays with `FE-5` and Ben's to-do; `OPS-38` links each limit to its card |
| F53 | "having a simple header and articulating the business problem this solves and high architecture steps would be ideal" | `OPS-38` for pattern 01; the brain applies the same page shape to every pattern page ([fr2-design.md](fr2-design.md#pattern-page-shape)) |

### Chapter notes: pattern 02, ask-anything explorer

Ben's notes on [02-ask-anything-explorer.md](../patterns/02-ask-anything-explorer.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F54 | The business outcome: "typically in Agentforce, we provide a brief, we provide a summary, and each follow-up question needs to be a flow, repurposed or rebuilt with context shoved back through ... rerouting context, endless build cycles, and hours that our customer isn't counting on when they can just use Claude, which can do all of these things already" | `OPS-39` |
| F55 | "support follow-up questions to that summary we just provided organically and make sure that it scales to any object, any combination of data. And that is a core operating principle for us. So our customers aren't in an endless scale of agentic capability scaling for something as simple as a follow-up question" | [fr2-design.md](fr2-design.md#operating-principles) (principle 1); `BE-30` (follow-ups to the summary); `BE-31` (discovery: any object, any combination); `BE-28` (follow-ups in the agent); `OPS-39` (states it) |
| F56 | Pattern 02's "How it works" gets the same treatment: "beautiful sequence diagrams with auto number, with numbered steps that correspond to each" | `OPS-39`; rule in [fr2-design.md](fr2-design.md#diagrams) |
| F57 | "considering we're bringing in a bunch of different capability and surfaces, in the see it section, we want to record or highlight and capture images for each see it" | `OPS-36` (captures for every pattern page, per surface); rule in [fr2-design.md](fr2-design.md#pattern-page-shape) |
| F58 | "tackle limits and open items as our follow-up to this set of this feature, as especially as we expand it into more capability" | `BE-30` (Apex N4: the agent keeps tables read before a model failure; panel N1: drill headers as labels), `FE-12` (panel N3: show when a question is tied to the summarized account), `BE-28` (agent N3: follow-ups carry the question before; agent N6: table relay proven), `BE-31` (OR filters, deeper parent paths, long-text filters, model calls per question, catalog size); the non-admin run stays with `FE-5` |
| F59 | "make sure cards are cut for that discovery" | `BE-31` (discovery spike; it proposes the build cards, and the brain cuts them) |

### Chapter notes: pattern 03, hotkey panel

Ben's notes on [03-hotkey-panel.md](../patterns/03-hotkey-panel.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F60 | "being able to snap in, hide, display different chats brings us a level of visibility that that might not actually exist there today" | Direction kept: `FE-13` (launcher, minimize, expand), `FE-12` and `BE-26` (switching between past chats), `FE-15` (the rail); `OPS-40` tells it as the business outcome |
| F61 | "I don't think anybody is dying to use the Astro button, so that makes sense" | Decision below: the hotkey panel is the way in we lead with. Superseded by F82 and F83: Agentforce's own panel is no longer a way in. `OPS-40`, `OPS-36` |
| F62 | "make sure limits and open items are covered" | `FE-12` (row 6: one Tab stop per result list; N5: drill-line target size; N9: Esc during IME composition), `FE-13` (N4: Esc returns focus from any starting point; 14f: the app's brand block), `FE-16` (both hotkey branches, the dark theme and its contrast, screen-reader output), `FE-5` (the non-admin run, "Ask the agent" included), `FE-17` (only in apps whose utility bar holds the panel; desktop only) |
| F63 | "we might want to think about the hotkey panel and other items we should add later" | `FE-17` (discovery: what the panel could add later, ranked, with proposed cards; the brain cuts the ones Ben picks) |
| F64 | "the how it works also needs auto number with numbered suggestions down below" | `OPS-40`; rule in [fr2-design.md](fr2-design.md#diagrams) |
| F65 | A further note, on the panel's answers: "whenever we display text inside of any of our services, it's richly formatted and we have a card architecture that we can display", and a spike on "what does our card architecture look like for richly formatted data that's easy to read and understand and feels best in class?" | [fr2-design.md](fr2-design.md#operating-principles) (principle 2); `FE-18` (card architecture spike: catalog, one typed contract, each surface, proposed build cards); `FE-12` and `BE-28` build on its contract; `OPS-40` tells it |
| F66 | For the hotkey panel and every surface: "really articulate the why behind us bringing in a custom architecture and view to all of these panels and going custom instead of standard Salesforce and Agentforce". The standard launcher "doesn't scale", "there's soft limits for how many characters", and "teams decelerate when trying to incorporate lightning cards into the responses"; "a note that we need to make sure we communicate to our teams", with "the architecture of the why", drawing on the limits section of the reference guide he sent | Where it lives: decision below. `BE-32` (measures the character ceiling and checks the standard launcher and cards against public docs); `OPS-41` (chapter 00, "Why custom", with the architecture of the why); `OPS-36` links it from the top of the README and from ARCHITECTURE.md; `OPS-40` and the other surface pages link it |

### Chapter notes: pattern 04, model provider seam

Ben's notes on [04-model-provider-seam.md](../patterns/04-model-provider-seam.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F67 | Why the Models API: "prompt templates require a lot of overhead. We want to be able to accelerate very fast and not be hung up on prompt template details, especially since they don't represent the entire context of the request that gets sent to Salesforce, because of things like the trust layer" | `OPS-42` (the business problem); `BE-33` settles from public docs exactly what the trust layer and template resolution do to each path, so the page states it precisely |
| F68 | "The models API represents the direct call out to the LLM provider via Salesforce, but doesn't offer a UI, which is a kind of a trade-off" | `OPS-42` (the trade-off, said plainly) |
| F69 | "maybe we take two approaches to our package. One where we have a commented out section where our Apex code passes in a prompt template, and another one where it doesn't ... having flexibility to use prompt templates depending on the context and the team could be important" | Decision below: one tested switch per prompt, not commented-out code. `BE-33` (per-prompt settings with a prompt template source); `OPS-42` ("when a template still fits") |
| F70 | "going with an API-first approach of models API makes the most sense, especially since it's easier to vibe out. And accelerate on innovation with Claude or another AI application. Prompt templates introduce just another layer of complexity that may not need to be there" | [fr2-design.md](fr2-design.md#operating-principles) (principle 3); `OPS-42` |
| F71 | "we need auto number, we need a better design that looks good for the how it works, sequence diagram" | `OPS-42`; rule in [fr2-design.md](fr2-design.md#diagrams) |
| F72 | "limits and open items should also be explored in a little bit more detail, and cards cut" | `BE-33` (N12: the model per prompt in settings, not a constant; one provider for the whole org; the request's own maximum-token setting where the API takes one; callout time limits; the prompt template path as the second provider; a provider outside Salesforce, researched only); `BE-29` (N8: the cut marker); usage per call goes in `OPS-42`'s guide from `BE-33`'s research |
| F73 | "how to update context for your prompt call out and like what it means to use the models API, how to use it, how to tune your prompt that gets sent to the models API, and all of those things, since we're taking away prompt templates" | `OPS-42` (a builder's guide, docs/guides/models-api-prompts.md); `BE-33` (the try-a-prompt script and the prompt trace it teaches) |

### Chapter notes: pattern 05, conversation memory

Ben's notes on [05-conversation-memory.md](../patterns/05-conversation-memory.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F74 | "I believe Agentforce just released Agentforce Memories, now I think we need to research what Agentforce Memories are to see if that impacts our design at all. Maybe it's partial coverage" | `BE-34` (discovery from Salesforce's own docs, a read-only check in agent-probe, and a covered/partial/not-covered table against F75 to F78) |
| F75 | "account brief session is specific to one agent interaction. I think what we want to be able to do is create these memory records, so to speak, and history records in a more agnostic way. So whether I create a task, whether I generate a brief" | Decision below: two memories. `BE-35` (one generic outcome store against the account); `BE-27` writes an outcome for each confirmed action |
| F76 | "that brief for a customer or an account is a build artifact and an outcome that has happened that should persist against that customer for a period of time, potentially for forever" | `BE-35` (retention set per outcome type, forever for summaries by default; the purge job's schedule waits for Ben); `FE-19` (the outcomes timeline) |
| F77 | "we also want to be able to show a graph of change in customer sentiment over time" | `BE-36` (a focused model call scores sentiment at each summary, checked for accuracy); `FE-19` (the chart) |
| F78 | "we need to make sure that our past outcomes are reusable" | `BE-35` (the outcome context every surface adds when a rep opens a conversation, and "what changed since" in the next summary); `BE-26` (conversation history) |
| F79 | "this memories Agentforce feature doesn't supersede our ability to store briefs and have context and history for an agent when the rep opens up the conversation" | `BE-34` (what the platform covers and what we keep); decision below; `OPS-43` (the page says it plainly) |
| F80 | "limits and open items should be rechecked and verified that we don't need new additional work" | Rechecked. Only the summary is remembered, not the explorer: `BE-26` keeps every turn, and pinning an answer is a candidate in `FE-17`. Earlier summaries are stored but never fed to the model: `BE-35` (what changed since). Memory outlives access (N6): `BE-35` (sharing follows the account) and `BE-26` (re-checked on read). How long an agent conversation keeps its variables: `BE-34` measures it. Accepted, with reasons on the page: system mode for the session object, a lock timeout that drops one turn, and a superseded summary that is stored (it is a real outcome and now shows in the timeline). `OPS-43` lists each |
| F81 | "Same feedback as always regarding the sequence diagrams. We want auto number with explanations. We want to work on the formatting of the sequence diagram to make it look really good" | `OPS-43`; rule in [fr2-design.md](fr2-design.md#diagrams) |

### Chapter notes: pattern 06, agent routing and verbatim relay

Ben's notes on [06-agent-routing-and-verbatim-relay.md](../patterns/06-agent-routing-and-verbatim-relay.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F82 | "I don't think we want to promote using the default agent force pop-out panel. We most certainly can, but I don't think there's anything important about using it. If you decide to use number 6, that means you're not using any of the other avenues or areas to integrate AI and LLM calls into your workflow. I'd propose that we drop this" | Decision below: our surfaces are the only ways in. `OPS-44` (pattern 06 becomes a short optional appendix); `OPS-36` (the README drops it from the patterns, the diagram and the required quick start) |
| F83 | "I'm all for dropping the Astro icon button and then also the ask the agent button too. We probably don't need those two items" | `FE-20` (removes "Ask the agent", its Apex client and specs, and agent access from the user group). `BE-28` parked: the agent gets no tone, write actions, follow-up fixes or rich answers in FR2, which also retires its share of F02, F08, F15, F16, F55, F58 and F65. Agent-panel work dropped from `BE-22`, `FE-18`, `BE-27`, `BE-26`, `FE-5`, `OPS-39` and `OPS-40`; `BE-32` measures through its own caller |
| F84 | "We don't need to say is this agent force or anything like that. Like this is agent force, it's just a different skinned version of it" | Positioning in [fr2-design.md](fr2-design.md#the-product); `OPS-41` (chapter 00's header); `OPS-36`; `OPS-44` |

### Chapter notes: pattern 07, trust, access and failure

Ben's notes on [07-trust-access-and-failure.md](../patterns/07-trust-access-and-failure.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F85 | "I again don't know if this is an entire chapter. I think this is more so design philosophy than anything else" and "The question is, does it need to be its own section?" | Decision below: trust is a principle, not a chapter. Principle 5 in [fr2-design.md](fr2-design.md#operating-principles); `OPS-45` (page 07 becomes a short "Trust by design" page, out of the chapter list); the failure behaviour moves into the chapters where it happens (`OPS-38` for not found, a choice of accounts and a failed section, with the two captures; `OPS-40` for the panel's fixed sentences); `OPS-36` (the README lists the principles) |
| F86 | "How we give access to records and permission sets is an implementation detail almost" | Access becomes one step in the README's quick start and each chapter's Adopt it (`OPS-36`); `OPS-45` keeps what each permission set grants as reference, not as a story. `FE-5` proves the one step is enough for a rep (summary, explorer, prompt files and the model call), and until it passes the pages say not yet proven |
| F87 | "making sure your agent runs in with sharing, except for things where it needs system context, like memory records, seems to make sense. I would align to that" | Principle 5; `BE-37` (the rule as a test: every class with sharing, every CRM read in user mode, each system-context use named in the code with its reason); `BE-35` (reps get no field access to an outcome's text, and the outcome service reads it in system context only for its author or a type marked to share, so the rule cannot be bypassed through a list view, a report or the API, and one rep's summary text never reaches another rep's model prompt; the text then shows only in our surfaces, even to its author); `FE-19` (what a non-author sees on the timeline and the chart); `BE-26` (conversation history named as a system-context use); `BE-33` (N11: whether a rep can read the prompt files in user mode); `FE-20` (removes the agent-definition query, the other half of N11); `FE-12` (an Id-shaped number never becomes a failing drill button, lwc re-review N2) |

### Chapter notes: pattern 08, test and release lifecycle

Ben's notes on [08-test-and-release-lifecycle.md](../patterns/08-test-and-release-lifecycle.md), 2026-11-12.

| # | Feedback | Status |
|---|----------|--------|
| F88 | "we have a really awesome opportunity to build out some really cool Agentforce Testing Center suite that we can incorporate into the run" and "how we communicate how to effectively test these agents as well as part of this bundle" | Decision below: the optional agent is the test bench. `BE-38` (a capped Testing Center suite with no write actions, and one script that runs it for the active version; waits for Ben's go in the Approvals table); `OPS-28` (runs it in the scratch org, after the run without the agent); `OPS-46` (the agent track of the ladder); `OPS-47` (the chapter) |
| F89 | "playwright tests for testing front-end changes" and "From a Chromium perspective, I'm assuming that this is UI UX tests, something similar to Playwright and like what Playwright ran" | Yes: Chromium is the browser Playwright drives. `FE-21` (spec 2's intermittent failure found and fixed, both hotkey branches, a smoke subset for front-end changes); each FR2 surface card already adds its own specs |
| F90 | "any other test classes in Apex that we may have generated to like prove that this thing works well" | `OPS-47` (a "What the tests prove" table by area, and a first Apex test to copy, with the stubbed model) |
| F91 | "testing adoption, I think, is really important because we're going to be bringing some of these programmatic testing concepts to Salesforce users who haven't historically done this type of testing. Meaningful and valuable. This is not ... A review board where you have to go and present everything and you're going to get graded" | Decision below on tone. `OPS-47` (written for people new to testing: a first test to copy for each kind, and turning a bad answer into a test); `OPS-46` (the ladder in one command, one line per rung) |
| F92 | "on top of that, lets review open items" | The review of page 08's open items below; `OPS-47` writes the page's list from it |

Ben also said "it's not that thing to use other resources in salesforce"; recorded verbatim, read only as far as `OPS-47` linking Salesforce's own testing tools (Testing Center, Code Analyzer, the Apex test runner, Agentforce DX) as what the page builds on.

#### Page 08's open items, reviewed

| Open item on the page today | Now |
|---|---|
| The CLI publish fails with a 401 in the org this was first built in | Accepted as history: that org is no longer used, and `agent-probe` publishes fine. `OPS-47` keeps it as one line. The Salesforce case is drafted and is Ben's to file |
| A test definition is pinned to the agent version it was created for | Closed by `BE-38`: its script recreates the definition for the active version on every run and prints the version |
| The local checks cannot see run-time defects, such as a model rewording a reply | Accepted: that is what the Testing Center rung (`BE-38`) and the browser suite are for |
| The code scan needs Code Analyzer and Java, and only reports | Code Analyzer is installed; Java is not on this machine, so the scan does not run at all today. `OPS-46` runs the engines that need no Java and says what it skipped. Installing Java is an optional step on Ben's to-do. It stays report-only |
| The checks are check-only, so the org matches main only as of the last real deploy | Every FR2 card now deploys under the standing approval, but nothing checks for drift. `OPS-46` adds a read-only drift check |
| The browser suite has run as an admin only, on one machine, on one hotkey branch | Admin only: `FE-5` (needs Ben's non-admin user). One hotkey branch: `FE-21`. One machine: no card; nothing runs the checks automatically (there is no CI). Running them in GitHub Actions would mean storing an org login in GitHub, which is Ben's call |
| Spec 2 fails now and then, cause not found | `FE-21` |
| Publishing a new version over an active one through Studio is not proven | Accepted: the CLI is the documented path and is proven in `agent-probe`. The Studio route stays unproven; FR2 has one more publish (`OPS-30`) and it uses the CLI |
| Spec 9 ("Ask the agent") | Removed by `FE-20` |

## Decisions the brain made (Ben may overrule)

- **Default agent name:** "Customer Summary". Internal API names become `Customer_Summary` / `CustomerSummary` /
  `customerSummary`, if `BE-21` says go. A seller's brand swap changes labels, not API names.
- **What it produces:** the product is "Customer Summary"; the one-ask output is a "summary" in UI text (the button reads
  "Summarize <Account>"). Docs may still use "brief" as a verb.
- **Hotkeys:** Cmd/Ctrl-K opens the compact window (unchanged); Cmd/Ctrl-Shift-K opens the rail. `OPS-29` proves
  both reach the page and collide with nothing; if one does, it picks a replacement and records why.
- **One shared conversation component**, inside two frames now and a third later.
- **Write actions:** draft first, then Confirm. One Apex service serves the panel, and MCP once Ben says MCP may
  write.
- **Two memories** (F75, F79). The conversation stays on the existing session object (`BE-26`): short, per rep and
  per account, own-only until Ben answers F32. What the product did for a customer is a customer outcome (`BE-35`):
  one generic object in a master-detail to the account, so it persists and belongs to no single agent or session. Who
  sees an outcome follows the account, with one guard: a summary is built from what its author could read, so other
  reps see its type, date and sentiment label but not its text, unless Ben marks that type to share it. Per public
  write-ups (`BE-34` confirms from Salesforce's docs), Agentforce's Agent Memory remembers things about a user for one
  agent; it does not replace an account's history, so we keep ours and use the platform's where `BE-34` shows it
  helps.
- **One more agent publish only, for the rename** (`OPS-30`), so the optional agent keeps working. `BE-28` is parked
  (F83).
- **Every pattern page gets the same shape and diagram style** (F49, F53). Each chapter Ben comments on gets its own
  card, like `OPS-38` for pattern 01. Pages he has no notes on get the same treatment in one sweep card, cut after his
  last chapter note. The sweep card also settles final page numbers and file names (pattern 06 is now an appendix).
- **Our surfaces are the only ways in** (F61, F82, F83). The README and the pattern pages open with Cmd/Ctrl-K and the
  rail. Agentforce's own panel and "Ask the agent" are not ways in: no docs, tests or screenshots promote them, and
  reps lose agent access through the user group (`FE-20`; hiding the Agentforce icon itself is a Setup choice left
  to Ben). The registered agent stays in the repo as an optional
  add-on for a team that wants it in an Agentforce channel, renamed and published once by `OPS-30`, documented in
  one appendix page (`OPS-44`), and no longer a required step in the quick start (`OPS-28` proves the run without it). It is all Agentforce (F84): the
  product calls the platform's models through its trust layer, with our own surfaces, so no page argues about that.
- **Trust is a principle, not a chapter** (F85 to F87). It is principle 5 in fr2-design.md and one short section of
  the README. Each chapter says what runs as the user and names any system-context use in its "Why you can trust it";
  the failure behaviour sits in the chapter where it happens; granting access is one step in the quick start. Page 07
  keeps its file name for now as a one-screen "Trust by design" page that lists the rule, the named exceptions and
  what each permission set grants (`OPS-45`); the sweep card decides its final number and name. A test enforces the
  rule (`BE-37`), so a later card cannot quietly add a system-mode query.
- **The optional agent is the test bench** (F88). Testing Center tests a registered agent, so the suite runs through
  the optional agent, whose actions call the same Apex services as the panel and MCP. It tests routing and the summary
  and explorer behind them, not the panel, the rail or cards (Playwright does that) and not write actions (the agent
  has none, F83). The agent is not republished for tests: a case that fails because its script lags behind the Apex
  is a finding for Ben. A run spends model calls, so it is a named rung, not part of every card's gate, and the suite
  is capped at 20 cases. Salesforce advises running Testing Center in a sandbox; `agent-probe` has none, so the
  functional suite runs there only with Ben's go, and the full run in the scratch org (`OPS-28`). A security suite is
  not planned: it needs a non-production org and Ben's go. If Ben says no to the `agent-probe` run, the brain drops
  `BE-38` from `OPS-46`, `OPS-47`, `OPS-36` and `OPS-28` before they are dispatched, so the close does not stall.
- **Tests are a builder's tool, not a review board** (F91). Pages about testing use no grades, scorecards or sign-off
  language; they show what each check catches and give a first test to copy.
- **"Why custom" lives in one page, chapter 00** (F66): docs/patterns/00-why-custom.md, the first chapter of the
  workbook, so a team reads the why before any pattern. The README links it in its first screen ("Why not just the
  standard chat?"), ARCHITECTURE.md links it, and each surface page (03, the rail, the embedded surface) links it from
  its business problem. Its numbers come from `BE-32`'s measurements and public docs, not from the reference guide,
  which is never named.
- **Prompt templates are a switch, not commented-out code** (F69). Each prompt has a settings record; its source is
  the prompt file (the default, through the Models API) or a named prompt template. Commented-out code is never
  compiled or tested and drifts from the code around it; a switch is tested both ways and a team flips it without a
  code change. The chapter shows the switch where Ben imagined the commented section.
- **OPS-28** (README run in a new org) waits for the FR2 README pass, so it tests the README people will use.
- **If `BE-21` says NO-GO** (labels only), API names stay `Account_Brief` / `AccountBrief` / `accountBrief`. About a
  dozen later cards name the new API names in their scope (the panel folder, the session object, the permission sets,
  the agent bundle and its spec). The brain re-cuts those scopes before dispatching anything after `BE-23`.
- **Leftovers in agent-probe** after the rename (old agent, old objects, permission sets, the old MCP server and app)
  stay until Ben approves a removal. A destructive deploy is outside the standing approval.

## Ben's to-do from FR2

- Answer two approvals in docs/plans/gtm-burn-plan.md marked "pending Ben": the renamed MCP server and app
  (`OPS-31`), and tests that create and delete their own task in agent-probe. The brain recommends yes to each. The
  `BE-28` publish is no longer needed (F83).
- Answer F17 (Log a call: Task or Event). `BE-27` waits for it.
- Answer F50: build an industry switch, or leave industry scenarios with the tabled `OPS-34`. The brain recommends
  leaving it tabled: `OPS-38` shows how to change the sections and the narrative by hand, which is enough for a demo.
- Answer F32 (who sees history) before `BE-26` is dispatched. Without an answer the default stands: each rep sees only
  their own history.
- Hold the MCP sign-in (runbook steps 9 and 10) until `OPS-31` lands, or it will be redone under the new name.
- Try the microphone by hand in Chrome after `FE-12` lands. Automated browsers cannot speak to it.
- Run the short VoiceOver script in docs/research/fr2-panel-proof.md after `FE-16` lands (about five minutes).
  Automated browsers cannot hear a screen reader.
- Pick from the list of later panel additions after `FE-17` lands. The brain cuts cards for the ones picked.
- Confirm who sees customer outcomes. The brain's default: anyone who can see the account sees each outcome's type,
  date and sentiment label, and only its author sees the summary text, because the text can carry cases, deals or
  fields another rep cannot read. Ben can mark a type to share its text with everyone who sees the account (useful
  where reps share the same access). F32's own-only default stays for conversations. `BE-35` builds the default unless
  Ben says otherwise.
- Decide whether to hide the Agentforce icon for reps. `FE-20` records the Setup step that does it; the brain does
  not change it.
- Say whether MCP clients may write (create a task, log a call). Until then MCP stays read-only; `BE-27` builds the
  invocables ready for it.
- Say go to schedule the outcome purge job in agent-probe after `BE-35` lands. Until then nothing expires.
- Say go for the Testing Center suite in `agent-probe` (`BE-38`; the Approvals table). The brain recommends yes for the
  functional suite: at most 20 cases with no write actions, on one dedicated test account (a summary still records its
  session and its customer outcome), the same kind of run that passed there before. It also covers the ladder's
  `--agent` run (`OPS-46`).
- Optional: install Java 11 or later on this Mac so the code scan's Java rules run (`OPS-46` runs the rest without it).
- Optional: decide whether the checks should run automatically in GitHub Actions. That needs an org login stored as a
  GitHub secret, so no card is cut until you say so.
- Say go for the spikes, and for `OPS-37`.

## Order

1. Done: `BE-20` (merged). On Ben's word, before any build: the plan review `OPS-37`.
2. Spikes, which need no rename: `OPS-29`, `BE-21`, `BE-22`, the explorer discovery `BE-31`, and the
   standard-chat measurements `BE-32`, and the agent memory discovery `BE-34`. After `OPS-29`, the
   card architecture spike `FE-18` and the panel discovery `FE-17` (docs only).
3. Rename: `FE-20` (retire "Ask the agent") first, then `BE-23`, then `OPS-30`, then `OPS-31`.
4. Foundations: the trust rule as a test `BE-37` first (after `OPS-30`), then `BE-24`, `FE-11`, `BE-25`, `BE-29`, `BE-30`, then `BE-26` (after `BE-30`) and `BE-33` (after
   `BE-29`), the customer outcome store `BE-35`, sentiment `BE-36`, then `BE-27` (after `BE-35`).
5. Surfaces: `FE-12`, then `FE-13`, then `FE-16` and `FE-15`; `FE-19` (history and sentiment) after `FE-15` and `BE-36`; `FE-14` after `FE-12` and `BE-27`.
   Tests: the Testing Center suite `BE-38` (after `BE-29` and `BE-30`, on Ben's go); `FE-21` after `FE-13`; then the ladder `OPS-46`.
6. Close: `OPS-32`, the chapter cards (`OPS-41` for chapter 00, "Why custom", `OPS-38` for pattern 01, `OPS-39` for pattern 02, `OPS-40` for pattern 03, `OPS-42` for pattern 04, `OPS-43` for pattern 05, `OPS-44` for pattern 06 as an appendix, `OPS-45` for page 07 as a short principles page, `OPS-47` for pattern 08 as a testing workbook),
   `OPS-35`, `OPS-36`, then OPS-28.
7. Parked: `OPS-33`, `OPS-34`, `BE-28` (F83).
