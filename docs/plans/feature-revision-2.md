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

## Decisions the brain made (Ben may overrule)

- **Default agent name:** "Customer Summary". Internal API names become `Customer_Summary` / `CustomerSummary` /
  `customerSummary`, if `BE-21` says go. A seller's brand swap changes labels, not API names.
- **What it produces:** the product is "Customer Summary"; the one-ask output is a "summary" in UI text (the button reads
  "Summarize <Account>"). Docs may still use "brief" as a verb.
- **Hotkeys:** Cmd/Ctrl-K opens the compact window (unchanged); Cmd/Ctrl-Shift-K opens the rail. `OPS-29` proves
  both reach the page and collide with nothing; if one does, it picks a replacement and records why.
- **One shared conversation component**, inside two frames now and a third later.
- **Write actions:** draft first, then Confirm. One Apex service serves the panel, the agent and MCP.
- **Conversation history:** extend the existing session object and pattern 05 rather than add a new object.
- **Agent publishes are batched:** one for the rename, one for tone plus actions.
- **Every pattern page gets the same shape and diagram style** (F49, F53). Each chapter Ben comments on gets its own
  card, like `OPS-38` for pattern 01. Pages he has no notes on get the same treatment in one sweep card, cut after his
  last chapter note.
- **OPS-28** (README run in a new org) waits for the FR2 README pass, so it tests the README people will use.
- **If `BE-21` says NO-GO** (labels only), API names stay `Account_Brief` / `AccountBrief` / `accountBrief`. About a
  dozen later cards name the new API names in their scope (the panel folder, the session object, the permission sets,
  the agent bundle and its spec). The brain re-cuts those scopes before dispatching anything after `BE-23`.
- **Leftovers in agent-probe** after the rename (old agent, old objects, permission sets, the old MCP server and app)
  stay until Ben approves a removal. A destructive deploy is outside the standing approval.

## Ben's to-do from FR2

- Answer three approvals in docs/plans/gtm-burn-plan.md marked "pending Ben": the `BE-28` publish, the renamed MCP
  server and app (`OPS-31`), and tests that create and delete their own task in agent-probe. The brain recommends yes
  to each.
- Answer F17 (Log a call: Task or Event). `BE-27` waits for it.
- Answer F50: build an industry switch, or leave industry scenarios with the tabled `OPS-34`. The brain recommends
  leaving it tabled: `OPS-38` shows how to change the sections and the narrative by hand, which is enough for a demo.
- Answer F32 (who sees history) before `BE-26` is dispatched. Without an answer the default stands: each rep sees only
  their own history.
- Hold the MCP sign-in (runbook steps 9 and 10) until `OPS-31` lands, or it will be redone under the new name.
- Try the microphone by hand in Chrome after `FE-12` lands. Automated browsers cannot speak to it.
- Say go for the spikes, and for `OPS-37`.

## Order

1. Running: `BE-20`. On Ben's word, before any build: the plan review `OPS-37`.
2. Spikes, which need no rename: `OPS-29`, `BE-21`, `BE-22`, and the explorer discovery `BE-31`.
3. Rename: `BE-23`, then `OPS-30`, then `OPS-31`.
4. Foundations: `BE-24`, `FE-11`, `BE-25`, `BE-26`, `BE-27`, `BE-29`, `BE-30`.
5. Surfaces: `FE-12`, then `FE-13`, then `FE-15`; `FE-14` after `FE-12` and `BE-27`; `BE-28` (one publish) after
   `BE-27`.
6. Close: `OPS-32`, the chapter cards (`OPS-38` for pattern 01, `OPS-39` for pattern 02), `OPS-35`, `OPS-36`, then OPS-28.
7. Parked: `OPS-33`, `OPS-34`.
