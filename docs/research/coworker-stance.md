# Coworker: our stance, what we tried, and when to come back (OPS-65)

## The stance

Coworker is a good fit when Salesforce is the source of truth and Coworker is the primary agent embedded in the CRM. It gives us no option to work with other tools, to be driven from a custom UI, or to be used inline from our own app page. So for this repo's scope Coworker is **tabled** (Ben, 2026-11-15). The build returns to the generic agent's own experience and connectivity features, in the `agent-probe` org.

That is a scope decision, not a finding that Coworker cannot work. Coworker **can** hand a question to our agent: 12 of 13 turns did. The three "no option" claims are weighed one by one below, each marked as a doc statement, a measured failure, or "not found".

## The three gaps, and how strong the evidence is

Written 2026-11-15. Every number and doc claim below is copied from a page or result file already in the repo. Nothing new was measured, no org was touched and no browser was opened for this page.

Three labels are used: **doc statement** (a Salesforce page says it), **measured** (we ran it and saw it), **not found** (we looked and found nothing; this is not proof of absence).

| Gap | What we have | Strength |
|---|---|---|
| **1. No option to work with other tools** | Coworker's delegation goes to Agentforce agents the user can access, up to 50, chosen from agent and topic descriptions only. Our actions reach it only through our agent. No page we read says Coworker consumes an MCP server we provide; the Coworker MCP server points the other way, letting outside clients such as Claude and ChatGPT reach Coworker. Coworker's own Search Agent "can't be modified" and changing it breaks Coworker | Doc statement for the delegation scope and the locked agent. **Not found** for Coworker calling a non-Agentforce tool or our MCP server |
| **2. No option to be driven from a custom UI** | In 30 guide pages read in a browser, none names an API, Connect class, Apex class, invocable or LWC module that sends Coworker's Ask a message. We tried two doors from Apex (BE-53, `connect-24h`): the Search Agent invocable stopped with no answer and no catchable error (cause unknown; the same script answered for our own agent in 14 s), and `ConnectApi.Search.answer` threw `System.NoAccessException`. `ConnectApi.Search.findAndGroup` works (2 result groups, under 1 s) but is search, not Ask | **Not found** in the docs. **Measured, once each**, for the two failed doors. Not tried: the Coworker MCP server, and the Agent API against the Search Agent |
| **3. No option for inline use from our own app page** | None of those guide pages documents a Coworker component, a Lightning page placement, a programmatic open, passing a record, or branding. The documented extension model is our agent and its cards shown inside Coworker's UI, not Coworker's UI inside ours. For the standard Agentforce panel (not Coworker), the Conversation Client API's `execute` "does not return the agent's textual response to your component" | **Not found** for Coworker. **Doc statement** for the standard panel's API, which is a different surface |

Our own panel reaches our own agent through the Apex invocable `generateAiAgentResponse` behind an `@AuraEnabled` method: 3 of 3 two-turn conversations kept their session (BE-56). That door needs no Coworker.

## What we tried

All live work ran in `connect-24h`, a 24-hour orgfarm org, unless the row says otherwise. Evidence links point at the page or file that holds the rows.

| Card | What was tried | Result | Evidence |
|---|---|---|---|
| OPS-63 | Three plain questions, three turns each, in Coworker, with `Customer_Summary` active and visible to the user and nothing named | **0 of 9 delegated.** Coworker answered from its own CRM search. Explore tables came through whole: 30 of 30 rows and 47 of 47 rows. The 47-row answer took 31.0 to 33.0 s. Our six section labels on their own line: 0 of 6. A summary took 13.5 to 16.3 s | [Delegation, measured](fr2-coworker-spike.md#delegation-measured); [delegation.jsonl](../../spikes/coworker/results/delegation.jsonl); [delegation-notes.md](../../spikes/coworker/delegation-notes.md) |
| OPS-64 | The same questions with the agent named, a question only our agent does, and a read of how the docs say Coworker picks an agent | **Delegated in 12 of 13 turns.** 9 of 9 when the question names the agent. 3 of 3 for the resolve-then-brief gate question with no name. 0 of 1 for plain "Summarize Edge Communications". A delegated summary took 41.4 to 46.9 s against 13.7 s when Coworker answered itself. Coworker rewrites our formatting: labels become bold lead-ins (5 or 6 of 6), at most 1 of 6 on its own line, and it adds its own blocks. Tables stayed whole (30 of 30, 47 of 47). Adding our agent as a connected agent of Coworker's agent is not offered while it is active; changed descriptions were not run | [coworker-calls-our-agent.md](coworker-calls-our-agent.md); [delegation-2.jsonl](../../spikes/coworker/results/delegation-2.jsonl) |
| BE-52 and BE-53 | The three headless doors from anonymous Apex: the Search Agent invocable, `ConnectApi.Search`, and the Coworker MCP server | Door 1: **aborted, no answer** (BE-53; in `agent-probe` there was no Search Agent to try). Door 2: `findAndGroup` works but is search; `answer` is **no access**; the earlier BE-52 try in `agent-probe` ended with a CLI status of 1, which BE-53 later traced to a compile error in our own script. Door 3: **not tried** (needs an app and a sign-in we may not create). Answer to "can our code call Coworker's Ask": **not proven** | [Headless door probe](fr2-coworker-spike.md#headless-door-probe-be-47); [headless.jsonl](../../spikes/coworker/results/headless.jsonl) |
| FE-24 and FE-28 | Our summary card as a custom Lightning type with our own renderer, shown inside Coworker | FE-24 built it as files only. FE-28 deployed it to `connect-24h`: the renderer was **rejected at deploy** (every attribute in `renderer.json` refused), the spike agent published and activated, and **no turn ran** because the agent-access grant was refused by the session's permission check. Whether Coworker draws our card is **not measured** | [Cards in Coworker, built and measured](fr2-coworker-spike.md#cards-in-coworker-built-and-measured-fe-24-fe-28); [FE-28 live steps](fr2-coworker-spike.md#fe-28-live-steps-in-connect-24h-2026-11-15-deployed-and-live-turns-not-run) |
| BE-56 | Five doors for our own UI to call the agent; one prototyped and measured | The Apex invocable works: 3 of 3 conversations kept their session on turn 2, first turn 11 to 31 s, follow-up 9 to 13 s. It cannot end a session. The Agent API also worked with a user-bound token (2 of 2 conversations, with an end call). Driving the standard panel from an LWC (`lightning/accApi`) returns no reply text. For Coworker no in-org door was found | [custom-ui-calls-agent.md](custom-ui-calls-agent.md) |
| OPS-62 | The README quick start in a new org, and what Coworker needed there | The product deployed, 149 of 149 components, and the agent published and activated; the e2e smoke rung failed. This card did not turn Coworker on. When OPS-63 looked, Coworker was already on in that org, with the Coworker licence 1 of 1 assigned to the admin user. In `agent-probe`, OPS-58 found no Coworker page in Setup, so nothing was measured there. The docs' list of what turning it on takes is under [What the docs say](#what-the-docs-say) | [fresh-org-run.md](fresh-org-run.md#clean-install-in-a-new-org-ops-62-2026-11-15); [Delegation, measured](fr2-coworker-spike.md#delegation-measured) |

## What the docs say

These are claims already cited elsewhere in the repo. Each line gives its source label in the page that holds it, and the page gives the read date and the full source entry. Labels `[S..]` are in [fr2-coworker-spike.md Sources](fr2-coworker-spike.md#sources) (read in a browser on 2026-11-13 and 2026-11-14 unless a page marks them read by a search summary). Labels `[C..]` are in [coworker-calls-our-agent.md Sources](coworker-calls-our-agent.md#sources) (read in a browser on 2026-11-15).

- **Delegation.** Coworker delegates only what it cannot complete itself, to any Agentforce agent the user can access, custom agents included, up to 50. It reads agent and topic descriptions, not topic instructions. It times out after 90 seconds. Read in a browser. [S9], [C1]
- **The Search Agent is locked.** It is preconfigured and platform-managed, and changes break Coworker. [S9], [C1]
- **No Setup list of callable agents.** The setup pages name Turn On, search data, user access and user mapping, and no delegation switch or add-agent step. [C4], [C5], [C6]
- **Cards.** A delegated agent's response can come back as a custom Lightning type card or a Headless Experience Layer widget, and Coworker shows it. Coworker's own answers stay markdown. The pages do not say which channel folder Coworker reads. [S9], [S45], [S46], [S47]
- **No embed or call API in the guide.** The 30 guide pages read in a browser name no component, placement, programmatic open, record handoff, branding, or in-org call for Ask. [S8], [S10], [S20], [S21], [S42]
- **The MCP server.** Documented only as a fact: Claude and ChatGPT reach Coworker "through MCP", generally available in November 2026. Its own docs were not found on 2026-11-14. [S1], [S4]
- **What turning it on takes.** The System Admin profile and the Agentforce Coworker Admin permission set; a Coworker licence or an Agentforce licence that includes it; Data 360 provisioned and active; Enterprise, Unlimited or Agentforce 1 Edition. Developer Edition is not among the listed editions. Per-user access goes through the permission set group `Access_Ai_Search`. [S7], [S10], [S26], [S32]
- **Price, dated 2026-11-13.** Listed at $50 per user per month, subject to change. Agent delegation is billed under the delegated agent's own terms. [S2], [S12]
- **Status.** The sources conflict on whether Coworker is generally available or in beta; this repo does not settle it. [S3], [S4], [S5], [S25]
- **Standard panel API.** `execute` does not return the agent's reply text to the calling component; desktop Lightning Experience only. [S5] in [custom-ui-calls-agent.md](custom-ui-calls-agent.md#sources)

## Not tried, and why

- **BE-55, the data search contract.** How Coworker and our panel find CRM data, run on 8 fixed questions with an answer key. Parked when Coworker was tabled. Status is queued in the task file and it has not been run: [the card](../../agents/tasks/BE-55-the-data-search-contract-how-coworker.md). Nothing in this repo measures Coworker's search method, index, freshness or sharing behaviour beyond the two OPS-63 explore questions.
- **The Coworker MCP server.** It needs a connected app or External Client App and a sign-in, which the live cards were not allowed to create or do. Its docs were not found.
- **The Agent API against the Search Agent.** Listed as a step in BE-47's card; no result is recorded for it.
- **FE-28's card render.** The renderer was rejected at deploy and the access grant was refused, so no turn ran. The two fixes named but not tried: one renderer property typed as the whole Lightning type, or the Headless Experience Layer widget route.
- **Changed agent and topic descriptions (OPS-64 way b).** Not run by choice, because naming the agent already worked.
- **Adding our agent to Coworker's agent.** Not offered while it is active. Deactivating Coworker's agent was outside Ben's go, and the docs say changing it breaks Coworker.
- **Non-admin users and other orgs.** Every live turn used one admin user in one 24-hour org, so a non-admin rep's view of Coworker is unmeasured.

## When to come back

Reopening is Ben's call. Ledger item F83 (`feature-revision-2.md`, row F83) is **still Ben's decision**: it is recorded as **tabled, not decided**.

| Change that would reopen it | First card to cut |
|---|---|
| A documented API, Connect class, Apex class or component that sends Coworker's Ask a message and returns its reply | A one-call probe from anonymous Apex in `agent-probe`, then a custom-UI door card modelled on BE-56 |
| A documented way to register or add an agent with Coworker, or a Setup list of callable agents | An OPS-64 style read of the new page, then one live turn per question |
| Custom card rendering accepted in Coworker | FE-28's re-cut: one renderer property typed as the whole Lightning type, plus the agent-access grant, then three turns |
| An MCP door we can sign in to (a Coworker MCP server with docs, and an app we may create) | A tools-list call, then one call per tool |
| Coworker seats and an org Ben names that hold Coworker for longer than 24 hours | BE-55, the data search contract, run once |
| A Coworker component for a Lightning page, or a documented programmatic open | A placement probe on one record page |

Until one of these changes, nothing in this repo relies on Coworker.
