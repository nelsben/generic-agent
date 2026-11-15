---
id: OPS-57
title: Coworker follow-up 1: everything readable without a live step — the rest of the developer guide, the Enterprise Search API, the Coworker MCP server and custom Lightning types for agent answers, plus Ben's answers and a read-only inventory, all on the spike page
domain: ops
tier: standard
status: merged
fixes: []
scope: [docs/research/fr2-coworker-spike.md, spikes/coworker/**]
forbid: [force-app/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, mcp-door/**, e2e/**, data/**]
red_test: none
gate: test
budget: 2-attempts
spend: 10
---
## Why

Ben asked on 2026-11-13 for the Coworker follow-ups to be cut and run after the FR2 build. OPS-55 and OPS-56 left parts of the developer guide unread, a possible search API door unread, the Coworker MCP server's own docs unfound, and the custom Lightning type mechanics that the cards prototype (FE-24) needs. This card reads all of that without any live step, so the live cards (OPS-58, BE-47, FE-24) start from documented facts.

## Done when

- Read first: docs/research/fr2-coworker-spike.md in full (OPS-55, corrected by OPS-56), docs/research/agent-api.md, docs/research/salesforce-mcp.md and docs/research/fr2-standard-limits.md (what it says about custom Lightning types). Keep the page's status words, and use 'read in a browser' for every page you read in Chrome
- **Browser rules.** Open ONE new Chrome tab you create, and close it at the end. Never touch, read or navigate a tab that was already open. Read public pages only; never sign in, and if a page asks you to, stop reading that page and record it as 'needs sign-in'. If you have no browser tool, skip the reading steps and say so in the hand-back; do not try other ways round a 403
- **The rest of the guide.** Read in a browser the Coworker developer guide pages OPS-56 lists as NOT read (billing-considerations, geo-residency, einstein-data-usage, a-manage-search-data-home and the pages under it, manage-user-access, review-user-mapping, setup-dc1-companion, resume-rename-delete-chats, manage-conversation-history, a-monitor-home and the pages under it; every file name starts agentforce-coworker- under https://developer.salesforce.com/docs/data/agentforce-coworker/guide/). Move each fact that rests on one of them from 'unverified (search summary)' to 'read in a browser', or correct it. In particular record: who sees a user's chat history and how long it is kept, whether history is per user or per record, how user access and licences are granted, the companion-org setup and whether it changes what an org needs, and what the monitoring pages measure
- **The search API door.** Find and read Salesforce's docs for the Enterprise Search API that the limits page names (Connect API limits) and for Query Assist. Record: the REST path and whether an Apex `ConnectApi` class covers it, the auth it needs, whether Apex in the same org or an LWC may call it, what it returns (results, a summary, or both), and whether it reaches Coworker's Ask answer or only search results. If no doc is found, say which searches you ran. Add a row to the headless table and update answer 1 at the top
- **The Coworker MCP server.** Find and read Salesforce's docs for the Coworker MCP server (the one Claude and ChatGPT use). Record: its tools, its auth (the OAuth flow, the scopes, whose user context), whether an in-org Apex or LWC caller is allowed or documented, and whether it needs a connected app or External Client App. Never sign in, create an app or enter anything. Update the headless table's MCP row
- **Custom Lightning types for agent answers.** Read Salesforce's docs for custom Lightning types on agent action outputs (the 'Custom Lightning Types' page the delegation page links, and what it links for agent responses) and for Headless Experience Layer widgets. Record, as FE-24's starting point: which metadata a type needs (bundle name and files), how an action's output is tied to a type (the schema, the renderer component, any config in the agent bundle), whether the renderer may be our own LWC, whether an agent publish is needed after the type is added, and where such a type renders (standard panel, Coworker, mobile). Add a short section 'What a card in Coworker takes' to the page
- **Ben's answers.** Read the row 'FR2+: Agentforce Coworker live steps' in the Approvals table of docs/plans/gtm-burn-plan.md and the Coworker row of 'Ben's to-do from FR2' in docs/plans/feature-revision-2.md. Record on the page what Ben has answered: the org he sees Coworker in, whether Setup in `agent-probe` offers Get Started with Agentforce Coworker, and his answer on F83. Where he has not answered, say so; never guess
- **Read-only inventory.** Re-run spikes/coworker/inventory.py against `agent-probe` (it writes spikes/coworker/results/inventory.jsonl; keep the old run's counts on the page next to the new ones if they differ). If the Approvals row names another org alias and `sf org list` shows that alias connected, add an `--org` argument to the script (default `agent-probe`) and run it against that alias too, into spikes/coworker/results/inventory-<alias>.jsonl; add a Search Agent check (BotDefinition rows whose names or labels hold 'Search') and the permission set group Access_Ai_Search. Read-only only: queries and metadata lists. Never log in, and never run anything against `experimental`
- **Point the page at the cut cards.** The page's 'Proposed follow-up cards' becomes 'Follow-up cards': item 1 is this card (OPS-57), item 2 is OPS-58 (delegation prototype), item 3 is FE-24 (cards inside Coworker), item 4 is BE-47 (headless door probe), item 5 is the OPS-41 edit. Update 'What stays unproven' and 'For Ben' for what this card settled. Keep the recommendation unless a fact read here contradicts its reasons; if it does, say what and why in the hand-back and leave the recommendation for Ben
- No Ids, usernames, emails, org hostnames or query-string URLs in any file. Paraphrase; quote at most a few words where the exact words matter. Every changed claim carries a source tag, and each new source gets its own line in Sources with its title, URL and date read
- Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests passes and bash scripts/check-docs.sh reports 0 broken. No tests/__pycache__, and git status --short is empty after the commit. The hand-back lists each page read, each one that refused or needed sign-in, and every row changed

## Review

Brain review (2026-11-14). One attempt (6fff34a, $1.44, sonnet, standard tier). The mod judged it consistent and accepted it without a reviewer pass.

Findings:
- docs/research/fr2-coworker-spike.md: every page read is marked "read in a browser", and the new sources are S27 to S52 (S39 and S41 unused).
  - Pages read: billing, geo routing, data use, user access, user mapping, the companion-org setup, chats, the monitoring pages, the search-data pages, the Connect REST Search resources and `ConnectApi.Search`, Lightning types, HXL output and widgets (Beta), and the Agentforce output target.
  - History: the guide does not say who else sees a chat, how long chats are kept, or whether history is per record. Deleting a chat only hides it from Recents.
  - Search: there is a documented in-org door, Connect REST Search and the Apex class `ConnectApi.Search` (API 63.0 and later). Apex can call it as the running user. It returns an answer or keyword results. No page ties it to Coworker's Ask, so answer 1 stays "undocumented". Calling it the "Enterprise Search API" is the worker's inference and is labelled as one.
  - The Coworker MCP server: no docs were found, so its tools, auth and callers stay undocumented. The searches run are listed.
  - A new section, "What a card in Coworker takes", for FE-24:
    - A `LightningTypeBundle` with `schema.json` and a channel `renderer.json`, and our own LWC is allowed as the renderer.
    - The action output is tied to the type through `complex_data_type_name` and `is_displayable`.
    - The HXL widget route is a fallback.
    - Whether a publish is needed, and which channel Coworker reads, are not stated.
  - A new section, "What Ben has answered": nothing yet. The Approvals row is still pending with no org named.
  - "Proposed follow-up cards" is now "Follow-up cards" (OPS-57, OPS-58, FE-24, BE-47 and the OPS-41 edit). The recommendation is kept.
- spikes/coworker/inventory.py: a new `--org` argument (default `agent-probe`, unused), plus a Search Agent check and an Access_Ai_Search check.
- Inventory rerun against agent-probe only: every count matches the old run, and both new checks return 0.

Gate (worker): Python 390 tests, 4 skipped; check-docs 75 pages, 0 broken.

Org: read-only queries and lists against agent-probe. No other org was used.

Browser: one tab the worker created, closed at the end. No sign-in and no pre-existing tab.

Disclosed and accepted:
- manage-conversation-history is a 404, a page name OPS-56 listed that does not exist. The Help FAQ article showed only a blank modal. "Configure User Permissions for Unmetered Licenses" was not opened, and the Admins blog stays unverified.
- Query Assist docs were not found.
- No reviewer pass ran: on a standard-tier card the mod accepted a consistent verdict directly. The brain read the diff stat and ran the privacy check itself.

Still open:
- Ben: the org he sees Coworker in, whether Setup in agent-probe offers Get Started, and F83. OPS-58's live steps wait on the Approvals row.

Privacy check over the full branch diff (194 added lines): 0 denylist hits. The only URLs are 23 links to public developer.salesforce.com pages, with no query strings. No Ids, hostnames, emails or local paths.
