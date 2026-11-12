---
id: OPS-19
title: The repo reads as a GTM workbook: a README front door and one page per architecture pattern, each with outcome, sequence diagram, evidence slots and adoption steps
domain: ops
tier: frontier
tier_reason: business-facing writing that must stay faithful to the code across nine patterns
status: queued
fixes: []
scope: [README.md, docs/patterns/**, docs/assets/MANIFEST.md, docs/ARCHITECTURE.md]
forbid: [force-app/**, tests/**, scripts/**, e2e/**, agents/**, docs/plans/**, docs/reviews/**, docs/research/**, .chassis-delegation.json, reference/**]
red_test: none
gate: test
budget: 3-attempts
spend: 25
---
## Why

This repo is the baseline of what good Agentforce looks like and has to sell itself to a business reader and then satisfy an architect. Today the README is four lines and wrongly lists Flows and Prompt Templates. Each architecture pattern needs a page that starts from the business outcome and ends with how to adopt it, with diagrams GitHub renders and fixed slots for the screenshots and GIFs a later card captures.

## Done when

- Read docs/ARCHITECTURE.md, docs/plans/corrective-plan.md, every file in docs/research/ and docs/reviews/, the agent script, e2e/README.md and the Apex and LWC source before writing. Write only what the repo proves. Never read or quote reference/. Never name a customer, a person or a company other than Salesforce and Anthropic, and never write record Ids, org Ids, usernames or URLs with query strings
- Audience: the README and the first screen of every pattern page are for a sales or business leader who has not seen the code; the rest of each page is for a Salesforce architect. Plain words, short sentences, no hype words, no claims without a pointer to a test, a review or a recorded run. Where something is designed but not yet proven (a run as a non-admin user, a real MCP tool call, the panel calling the registered agent), label it 'Not yet proven' in a visible callout
- README.md: one-sentence promise; a 'what you get' table of the nine patterns with the business outcome of each and a link; one hero GIF slot (docs/assets/brief-flow.gif); a single top-level Mermaid diagram of the whole system; 'see it in 5 minutes' steps (deploy, assign the two permission sets, open the app, press the hotkey); how it is tested (Python, Apex, Jest, Playwright, agent test spec, Studio preview) with the real commands; repo map; status table of proven versus not yet proven. Remove the wrong Flows and Prompt Templates line
- docs/patterns/ has these nine pages, each named exactly: 01-route-gather-reduce.md, 02-ask-anything-explorer.md, 03-hotkey-panel.md, 04-model-provider-seam.md, 05-conversation-memory.md, 06-agent-routing-and-verbatim-relay.md, 07-trust-access-and-failure.md, 08-test-and-release-lifecycle.md, 09-outside-door-mcp.md
- Every pattern page has these sections in this order: The outcome (what a seller, manager or admin gets, in two or three sentences); The problem it removes; How it works (a Mermaid sequenceDiagram with real class, action and component names from this repo, then at most eight numbered steps); See it (the asset slots below); Why you can trust it (the tests and review findings that cover it, with relative links); Adopt it (numbered steps to reuse the pattern in another org, with the files to copy and the one or two places to change); Limits and open items
- Asset slots, embedded with relative paths and descriptive alt text, exactly these names under docs/assets/: 01 uses brief-flow.gif and panel-brief.png; 02 uses explore-answer.png, explore-drill.gif and drill-view.png; 03 uses hotkey-open.gif and panel-sections-open.png; 05 uses memory-followup.png; 06 uses agent-brief.png and agent-explore.png; 07 uses not-found.png and ambiguous.png; 08 uses e2e-report.png; 04 and 09 are diagram only. Do not create the image files; a later card captures them. List every slot in docs/assets/MANIFEST.md with file name, what it must show, and which page uses it
- Mermaid: every diagram is a fenced mermaid block that parses. Check each one with `npx --yes @mermaid-js/mermaid-cli@11 -i <file> -o <tmp>.svg` writing only to a temporary folder outside the repo, and fix any that fail. Use sequenceDiagram for flows and flowchart LR for the system map; no more than twelve participants per diagram
- docs/ARCHITECTURE.md stays the engineer reference: fix anything now wrong (finding 9's permission set, memory cap, removed recordFromFlow, explorer date handling, the deterministic explore run) and link each section to its pattern page
- Gate passes: python3 -m unittest discover -s tests with PYTHONDONTWRITEBYTECODE=1; leave no tests/__pycache__/; git status --short is empty after your commit. Never touch the org, never install a plugin even if a hook suggests one
- MANIFEST.md has a status column, and every row starts as 'not captured'; FE-7 changes it to 'captured'. The README hero and each page embed the slot as written above; OPS-22 removes any slot still 'not captured'
