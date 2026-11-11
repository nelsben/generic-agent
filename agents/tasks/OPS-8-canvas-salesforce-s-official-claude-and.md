---
id: OPS-8
title: Canvas Salesforce's official Claude and agent skills for Apex, LWC and Agentforce development, and recommend which to adopt, in docs/research/salesforce-skills.md
domain: ops
tier: standard
tier_reason: reading public repos and docs and summarising with sources; no code
status: merged
scope: [docs/research/salesforce-skills.md]
forbid: [force-app/**, agents/**, reference/**, .chassis-delegation.json, scripts/**, tests/**, .claude/**]
red_test: none
gate: test
budget: 2-attempts
spend: 8
---
## Why

generic-agent is meant to be a gold-plated Agentforce baseline, and we have been building it from memory and scattered docs. Salesforce now publishes agent skills (the forcedotcom/sf-skills repo replaced the retired DX MCP server) covering Apex, LWC and Agentforce work. We need an inventory of what exists and a recommendation of which skills this repo and its workers should load, so later cards stop rediscovering the platform by trial and error.

## Done when

- Research only. Change only docs/research/salesforce-skills.md. Do not install anything, do not change any Claude or CLI configuration, do not touch the org, and do NOT use the Chrome browser tools (another task is using the browser). Read docs/ARCHITECTURE.md first so you know what this repo builds: an Apex-only engine, an Agent Script agent (aiAuthoringBundles), an LWC panel, permission sets, and MCP as a planned door
- Sources: start with the GitHub repo forcedotcom/sf-skills (use `gh repo view`, `gh api repos/forcedotcom/sf-skills/git/trees/HEAD?recursive=1`, and `gh api` or raw.githubusercontent.com to read files; WebFetch works for github.com and raw.githubusercontent.com). Then search the forcedotcom, salesforcecli, salesforce and trailheadapps GitHub orgs for other skill, plugin or agent-instruction repos (`gh search repos`, `gh search code SKILL.md --owner forcedotcom` and similar), and web-search for Salesforce announcements about Claude skills, Agentforce Vibes skills, and Claude Code plugins or marketplaces from Salesforce. developer.salesforce.com returns 403 to WebFetch: do not retry it; try the same path with a .md suffix or https://developer.salesforce.com/docs/llms.txt once, and otherwise mark the page as not read
- Inventory table: every official Salesforce skill or skill bundle found, with repo and path, what it covers (one line), last commit date, how it is installed (Claude Code plugin marketplace, copying a folder into .claude/skills, npx, other), licence, and whether it is official Salesforce, Salesforce-employee personal, or community. Label community items clearly and keep them in a separate short table
- For each skill relevant to this repo, read its SKILL.md and referenced files fully (not just the title) and summarise the concrete rules it gives. Cover at least, if they exist: Apex development and testing, LWC development and Jest testing, Agentforce agent development (Agent Script, authoring bundles, `sf agent` commands: validate, preview, publish, activate, test), permission sets and metadata deploys, and MCP or API Catalog
- Agent lifecycle section: write out, from the skills and the plugin-agent docs, the exact recommended sequence for changing an already-published and active Agent Script agent and publishing a new version (commands, required flags, whether deactivation is needed, validation or preview steps before publish, what `--skip-retrieve` does), with a source for each step. This is the most important section
- Gap list: compare what the skills prescribe with how this repo is built today (read the .agent file, one Apex action class, the LWC folder, scripts/validate-org.sh and the tests folder). List concrete differences as: what the skill says, what we do, source. Do not change anything
- Recommendation: which skills to adopt for (a) the main session and (b) delegated worker briefs, the exact install steps for each as written by its source, and anything to skip with a reason. State what installing would add to or change on the machine or in the repo. Do not perform the install
- Every fact carries its source URL and a status word: documented (official source says it), verified (you read it in the repo file yourself) or unverified (community or inference). Never fill a gap from memory; write 'not found' with what you searched. Start with a 5-10 line plain answer. Keep the file under 250 lines. No client names, no content from reference/. Gate passes: test. Commit, do not push

## Review

Brain read docs/research/salesforce-skills.md at fc0e755: inventory of forcedotcom/sf-skills at a pinned commit, rules by area, an 11-step agent lifecycle with sources, a conflicts table left unresolved (deactivate before publish), a verified gap list against this repo, and an install recommendation that was not carried out. Four developer.salesforce.com pages were not read (403). Nothing was installed.
