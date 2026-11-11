# Salesforce official skills for Apex, LWC and Agentforce: what exists and what to adopt

Researched 2026-11-11. Status words (card definition): documented = an official source says it;
verified = I read it in this repo's files myself; unverified = community source or inference.
Everything under "documented" below was read in a sparse clone of forcedotcom/sf-skills at commit
`0c7cb93` (2026-11-06) unless marked "partially read". Base URLs: `SFS/` =
`https://github.com/forcedotcom/sf-skills/blob/0c7cb93/plugins/builder/`, `PA/` =
`https://github.com/salesforcecli/plugin-agent/blob/main/`, `AG/` =
`https://github.com/forcedotcom/agents/blob/d421ce9d/` (sha is the repo head on 2026-11-10).

## Plain answer

1. The official source is `forcedotcom/sf-skills` (Apache-2.0, repo description: "Optimized for
   Agentforce Vibes, compatible with all AI tools"). It is a Claude Code plugin marketplace of 21
   plugins, about 440 SKILL.md files. It replaced the retired DX MCP server (archived, end of life
   2026-11-02).
2. Two plugins matter here: `salesforce-development` (v2.7.0: Apex, Apex tests, permission sets,
   metadata deploy, SOQL, deploy gate hooks) and `agentforce-adlc` (v0.14.0: Agent Script authoring,
   validate, preview, publish, activate, test). `experience-lwc` (v0.3.0) covers LWC and Jest.
3. The lifecycle for changing a published, active agent is only partly settled. The sources
   disagree on whether you must deactivate first. See the lifecycle section; I did not resolve it.
4. Recommendation: main session installs `salesforce-development` + `agentforce-adlc` from the
   `salesforce` marketplace. Workers get named skill folders and references, not whole plugins,
   because the plugin hooks and an auto-activating agent can fight chassis flows.
5. Not done: no install, no org contact, no config change. Python 3.9.6 on this machine is below the
   `agentforce-generate` frontmatter minimum (3.10).
6. The skills contain internal contradictions (listed below). Copy none of the flag spellings
   without checking `sf <cmd> --help`.

## What I searched, and what I could not read

- documented: `gh api` tree and file reads of forcedotcom/sf-skills; orgs forcedotcom, salesforcecli,
  salesforce, trailheadapps listed via `gh api orgs/<org>/repos`. The GitHub search API
  (`gh search repos`) was rate-limited (HTTP 403), so repo sweeps used the listing endpoint and
  earlier `gh search code` results. Name-matched repos I saw but did not inspect: informatica
  plugins under forcedotcom (third party), aggregator sites (vibeindex.ai, claudemarketplaces.com).
- Not read (developer.salesforce.com returns 403, not retried): `https://developer.salesforce.com/docs/platform/salesforce-skills-plugins/guide/overview.html`,
  `https://developer.salesforce.com/docs/ai/agentforce/guide/skills-plugins.html`,
  `https://developer.salesforce.com/blogs/2026/08/headless-development-with-skills-and-a-claude-code-plugin`
  (blog dated 2026-08-19 per search snippet), `https://www.salesforce.com/headless/agent-skills-plugins/`.
  No single launch announcement located.
- `forcedotcom/afv-library` resolves to `forcedotcom/sf-skills` (`gh api` full_name), so it is one repo.

## Inventory (official, plugin level)

All rows: repo `forcedotcom/sf-skills`, licence Apache-2.0, label official Salesforce, install via
Claude Code plugin (see Recommendation) or `npx skills add forcedotcom/sf-skills` (README, documented).
Source for every row: `https://github.com/forcedotcom/sf-skills/blob/0c7cb93/.claude-plugin/marketplace.json`.

| Plugin (path under plugins/builder/) | Version | Covers | Last commit | Read |
|---|---|---|---|---|
| salesforce-development | 2.7.0 | 38 skills: Apex generate/test/run/logs, permission sets, metadata deploy/retrieve, SOQL, flows, H360, LSP; `salesforce-dev` agent; hooks; MCP | 2026-11-06 | README + 5 skills in full |
| agentforce-adlc | 0.14.0 | Agent Script generate, test, observe, persona, bot-upgrade, architecture, d360 | 2026-11-06 | README + generate SKILL and references |
| experience-lwc | 0.3.0 | LWC generate (PICKLES, 165-point SLDS 2 rubric), Jest, a11y, security | 2026-11-04 | generate + Jest refs, partially read |
| salesforce-code-quality | 0.2.0 | Code Analyzer, architecture review; no hooks | not recorded | README only |
| integration, platform-lightning-widgets | 0.3.0 | Named credentials/callouts; widgets incl. `platform-mcp-tool-widget-coordinate` | 2026-10-30 | titles only |
| dx-org-lifecycle, dx-devops, dx-packaging, dx-isv-partner, platform-trust-security, platform-observability, test-drive | various | DevOps, packaging, security, observability | n/a | not read |
| education-cloud, commerce-b2b, consumer-goods, service-itsm, service-omni, service-engagement, mobile-development, experience-react, experience-cms | various | Industry and channel areas | n/a | not read |

Other official-but-not-dev: `salesforce/salesforce-skills` (Apache-2.0, sales-role Cowork plugins,
pushed 2026-11-09). Reference, not skills: `trailheadapps/agent-script-recipes` (Apache-2.0, has
AGENTS.md, 2026-11-03), `salesforce/agentscript` (the language), `forcedotcom/agents` (library),
`salesforcecli/plugin-agent` (v2.3.0, 2026-11-10). Retired: `forcedotcom/mcp` and
`salesforcecli/mcp` (archived; `https://github.com/forcedotcom/mcp/issues/46`).
README warning (documented): "Expect frequent changes. Skills and plugins may be renamed,
restructured, or removed between releases."

Community and Salesforce-employee personal (separate, unverified as official):

| Repo | Licence | Label | Note |
|---|---|---|---|
| Jaganpro/sf-skills | MIT | Salesforce-employee personal, ARCHIVED | Migrated to afv-library, now sf-skills |
| SalesforceAIResearch/agentforce-adlc | "Other" | Salesforce research org, pushed 2026-09-12 | What claude-plugins-official pins |
| vibeindex.ai, claudemarketplaces.com and similar | n/a | community aggregators | Not inspected |

## Rules by area (documented unless noted)

Apex, `SFS/salesforce-development/skills/platform-apex-generate/SKILL.md`:
- Hard stops: no SOQL or DML in loops, a sharing keyword on every class, no hardcoded IDs, handle
  exceptions, bind variables in dynamic SOQL, no `@future` (Queueable with Finalizer), avoid
  `System.debug` in main paths.
- Defaults: `with sharing`, USER_MODE (default at API 67+), ApexDoc on public methods, API 66.0
  minimum, Named Credentials for callouts.
- Invocable methods: `public static`, take `List<Request>`, return `List<Response>`; Response should
  carry isSuccess, errorMessage, errorType; `@InvocableVariable` needs a label.
- Validate phase: Code Analyzer (`sf code-analyzer run`, fix sev0 to sev2), then run Apex tests.

Apex tests, `platform-apex-test-generate` and `platform-apex-test-run`:
- One behaviour per method, bulk tests, `@TestSetup` delegating to a TestDataFactory, `Assert` class
  only (no `System.assert*`), mock HTTP callouts, Test.startTest/stopTest, Given/When/Then,
  methods under 30 lines. 75% coverage minimum, 90%+ recommended. Run the smallest set first.
  The "251 records" bulk size was seen only through a loose regex; not cited as a rule.

LWC and Jest, `SFS/experience-lwc/skills/experience-lwc-generate/` (partially read):
- PICKLES design framework, 165-point SLDS 2 scoring rubric, wire/Apex/GraphQL/LMS guidance.
- Jest: `@salesforce/sfdx-lwc-jest`, a `jest.config.js` built on `jestConfig`, a `test:unit` script
  in package.json, tests in `__tests__/`. `references/jest-testing.md` cites a community author's
  patterns (James Simone), so treat its advanced patterns as community-derived.
- `experience-lwc-accessibility-jest-run` (read): Sa11y tests need `@sa11y/jest`; the Bazel mode is
  for Salesforce core only and is irrelevant here.

Agentforce, `SFS/agentforce-adlc/skills/agentforce-generate/SKILL.md` and `references/`:
- Always `--json` as the first flag; never `2>&1`; run `sf config get target-org --json` first.
- Run the local compiler `node <skill-dir>/scripts/index-agent.mjs <agent-file>` before org validation.
- Stay draft-first. Publish and activate are explicit release actions that need user approval.
- Agent Script: 4-space indent, never nested `if`. Metadata: AiAuthoringBundle = `<Name>.agent` +
  `<Name>.bundle-meta.xml`; publish creates Bot, BotVersion, GenAiPlannerBundle.
- Release gate: validate passes, live preview covers every routing branch, traces confirm routing
  and a FunctionStep, user approves, Data Cloud permset if there is a `knowledge:` block.
- Tests: `sf agent test create --spec specs/<Agent>-testSpec.yaml --api-name <N> --force-overwrite`,
  then `sf agent test run --api-name <N> --wait 5 --json`. Tests run against activated agents only.
  `sf agent generate test-spec` without `--from-definition` is interactive; do not use agentically.
- Known issue 18: GenAiPlannerBundle deploy fails while the agent is active.
- Requirements: sf >= 2.139.6, node >= 20, python3 >= 3.10 (README says 3.9+; frontmatter wins).

Permission sets, `platform-permission-set-generate`: set fullName, label and description; least
privilege; no required fields in fieldPermissions; supports `<agentAccesses>` (agentName, enabled).

Deploys, `platform-metadata-deploy`: classify org via `sf org list`; dry-run first; never
`sf project deploy start` against production (validate then quick-deploy, RunLocalTests default);
order objects/fields, permsets, Apex, Flows as Draft, activation. The plugin deploy gate hook
requires one literal deploy per shell call, no inline cd or export, and for production the whole
reply `confirm production deploy to <alias>` (valid ten minutes, one deploy).

MCP and API Catalog: `references/mcp-management-reference.md` (agentforce-generate, read in part)
covers `sf agent mcp` commands: register a server in the API Catalog, whitelist assets, OAuth via
stdin. Every command is "developer preview". `platform-headless-360-integrate`: H360 is a
Salesforce-hosted MCP server with four tools (discover, describe, dispatch_readonly, dispatch), off
by default, writes confirm-before-write. `experience-app-mcp-*` and widget skills: not read. No
dedicated API Catalog skill beyond these was found. Our hosted-server findings are in
`docs/research/salesforce-mcp.md`.

## Agent lifecycle: changing a published, active Agent Script agent

Proposed sequence, each step with its source and status. Where sources disagree, see the conflicts
table after it; nothing there is resolved by inference.

| # | Step | Command and flags | Source | Status |
|---|---|---|---|---|
| 1 | Confirm org | `sf config get target-org --json` | SFS/agentforce-adlc/skills/agentforce-generate/SKILL.md rule | documented |
| 2 | Edit the `.agent` file, compile locally | `node <skill-dir>/scripts/index-agent.mjs <file>` | same SKILL.md | documented |
| 3 | Deploy backing code, scoped | `sf project deploy start --json --metadata ApexClass Flow -o <org>` (never a bare deploy) | agentforce-generate references/deploy-reference.md | documented |
| 4 | Validate | `sf agent validate authoring-bundle --json --api-name X -o <org>` | PA/messages/agent.validate.authoring-bundle.md | documented |
| 5 | Preview | `sf agent preview start --json --authoring-bundle X --use-live-actions` (or `--simulate-actions`); `send` and `end` need `--authoring-bundle`, `--session-id`, `-u`; traces in `.sfdx/agents/<Bundle>/sessions/<id>/traces/` | SKILL.md + PA/messages/agent.preview.start.md | documented |
| 6 | Deactivate | `sf agent deactivate --json --api-name X -o <org>` | see conflict 1 | conflicting, unverified whether needed |
| 7 | Publish | `sf agent publish authoring-bundle --json --api-name X -o <org>` (add `--skip-retrieve` in CI only) | PA/messages/agent.publish.authoring-bundle.md; local `sf agent publish authoring-bundle --help` (CLI 2.157.8) | documented |
| 8 | Find the new version | retrieve `AiAuthoringBundle:X` and read `<target>`, or query BotVersion; publish output does not give it | agent-metadata-and-lifecycle.md | documented |
| 9 | Activate | `sf agent activate --json --api-name X --version N -o <org>`; without `--version` and with `--json` the latest is activated | local `sf agent activate --help` (CLI 2.157.8) | documented |
| 10 | Verify | `sf agent preview start --json --api-name X`; `sf agent test run --api-name X --wait 5 --json` | SKILL.md | documented |
| 11 | Rollback | deactivate, query BotVersion, `sf agent activate --version <previous>` | deploy-reference.md (flag spelled wrong, see conflict 4) | documented |

Publish internals, `AG/src/agents/scriptAgentPublisher.ts` (read): if the Bot exists it POSTs
`ai-agent/v1.1/authoring/agents/<botId>/versions`, else creates the first version; it then
retrieves the agent metadata (unless skip-retrieve), temporarily writes `<target>Name.vN</target>`
into bundle-meta.xml, deploys the AiAuthoringBundle, and removes the target locally. The code has
no deactivate call and no active-status check (status: documented).

`--skip-retrieve` (documented: local `--help`, PA messages, forcedotcom/cli release notes, and the
publisher source): skips only the retrieve of the new Bot, BotVersion and GenAi metadata back into
the DX project. The bundle deploy with the temporary `<target>` still runs. Neither agentforce-generate
nor its references mention the flag; `agent-deployment-guide.md` uses it in its CI script.

Conflicts between sources (all documented; reconciliation unverified):

| # | Topic | Source A says | Source B says |
|---|---|---|---|
| 1 | Deactivate before publishing? | `SFS/salesforce-development/skills/platform-metadata-deploy/references/agent-deployment-guide.md`: "Deactivation required before making changes"; its update flow is deactivate, deploy, validate, publish, activate. `PA/messages/agent.deactivate.md`: "To make changes to an agent ... you must deactivate it." | agentforce-generate `agent-metadata-and-lifecycle.md`: publish creates an INACTIVE version and activating a new version deactivates the old one; deactivate is listed only for a publish failure or changing `default_agent_user`. The publisher source has no active check. |
| 2 | Does validate contact the org? | `salesforce-cli-for-agents.md`: local files only, no org contact | `PA/src/commands/agent/validate/authoring-bundle.ts` and messages: required `target-org`, HTTP 404/500 error codes. My read: the skill text is outdated. |
| 3 | Deploy before publish? | CLI reference section 5: backing code "must be deployed" | lifecycle section 5: publish is "self-contained". Likely both true: publish deploys the bundle, not your Apex. |
| 4 | Activate version flag | `--version` (PA messages and local `--help`) | `--version-number` in deploy-reference.md rollback snippet. `--help` settles it: `--version`. |

What decides conflict 1 is one test: publish a new version of an active agent in the sandbox.
I did not run it (no org contact allowed). Until then, step 6 is the safe path but costs downtime.
Other facts (documented): activating deactivates the old version, one version is active at a time;
each publish adds a version; retrieving the bundle after publish sets `<target>` and locks it
(recover by removing `<target>` and redeploying); `default_agent_user` can only change while
inactive; "Internal Error" on publish is usually the access user, a missing `outputs:` block on an
action, or structural drift; retry once after 60 seconds.

## Gap list: skill says / we do / source

| # | Skill says | We do | Source | Status |
|---|---|---|---|---|
| 1 | LWC needs Jest: sfdx-lwc-jest, package.json, jest.config.js, `__tests__` | none of these; `.forceignore` ignores `**/__tests__/**` | `lwc/accountBriefPanel/`, `.forceignore` | verified |
| 2 | Current API version | LWC js-meta `apiVersion` 64.0, project 68.0 | `accountBriefPanel.js-meta.xml`, `sfdx-project.json` | verified |
| 3 | Response carries isSuccess, errorMessage, errorType | `AccountBriefResolver.Response` has status, accountId, accountName, message | `AccountBriefResolver.cls` | verified; deliberate design, fair divergence |
| 4 | TestDataFactory called from `@TestSetup` | no TestDataFactory; 3 files use `@TestSetup` | `classes/` | verified |
| 5 | `Assert` class only | `AccountBriefMemoryTest.cls` lines 37-39 use `System.assertEquals` (17 other tests use `Assert.`) | that file | verified |
| 6 | Test spec in `specs/` at project root | `tests/agent/Account_Brief-testSpec.yaml` | `tests/agent/` | verified |
| 7 | Permission set needs a description | `Account_Brief_Agent_Access` has a label, no `<description>` | permissionsets/ | verified |
| 8 | Compile locally with `index-agent.mjs` first | no local compile step in `scripts/validate-org.sh` | script | verified |
| 9 | `sf agent validate` and live preview before publish | `validate-org.sh` is a check-only deploy of all `force-app` including the bundle; no validate, preview, publish or activate script | script | verified |
| 10 | Scope deploys with `--metadata`, keep the bundle out of routine deploys | `--source-dir force-app` includes aiAuthoringBundles (dry-run only) | script | verified |
| 11 | Code Analyzer on every Apex change | no such step | `scripts/`, `tests/` | verified |
| 12 | Agent Spec file | none; `docs/ARCHITECTURE.md` plays that role | docs/ | verified |
| 13 | Production gate and validate-then-quick-deploy | script targets `experimental` only | script | verified, not a gap for now |

Checked and not gaps: CSS hex values are `var(--slds-g-color-...)` fallbacks, which the skill asks
for. `System.debug` appears only in 4 non-test classes (AccountBrief, AccountBriefMemory,
AccountBriefPanelController, DataExplorer) at ERROR or WARN level on failure messages; the skill
bans it in "main paths" and I did not confirm each sits in a catch block (partially read). `public`
invocable classes: our live probe showed the org lists them as `APEX_ACTION` without `global`
(see `docs/research/salesforce-mcp.md`), so the docs' `global` rule is not a gap yet. The .agent file
follows the skill's rules I checked (4-space indent, no nested `if`, outputs blocks, no `knowledge:`).

## Recommendation

(a) Main session: install `salesforce-development` and `agentforce-adlc`. Add `experience-lwc` when
the Jest card starts; `salesforce-code-quality` is optional (Code Analyzer). Pick one marketplace.
I recommend `salesforce` (documented, README): `claude-plugins-official` pins `agentforce-adlc` to
the SalesforceAIResearch repo at sha `09bf1539` (2026-09-12, licence "Other") while `salesforce`
carries 0.14.0 under Apache-2.0. Exact steps as written in the README:
1. `/plugin marketplace add forcedotcom/sf-skills`
2. `/plugin install salesforce-development@salesforce`
3. `/plugin install agentforce-adlc@salesforce` (skills namespaced, e.g. `/agentforce-adlc:agentforce-generate`)
4. Verify: `/plugin`, `/salesforce-development:status`, `/salesforce-development:setup`.
Alternative from the README: `/plugin install salesforce-development@claude-plugins-official`
(pre-registered; auto-updates; pins can lag). Disable the other copy if switching.
Uninstall: `/plugin uninstall salesforce-development@salesforce`, then `/plugin marketplace remove salesforce`.
Needs Claude Code 2.1.222+ (local 2.1.322, ok), sf CLI (local 2.157.8, ok), Node LTS (local v26.7.0,
ok), Python 3.8+ for hooks and 3.10+ for agentforce-generate (local 3.9.6: short; verified).
pnpm and corepack (listed in generate's cliTools) were not checked.

(b) Worker briefs: point workers at named files, not plugins: agentforce-generate `SKILL.md`,
`references/deploy-reference.md`, `references/agent-metadata-and-lifecycle.md`;
`platform-apex-generate`, `platform-apex-test-generate`, `platform-permission-set-generate`.
Reason (documented hooks, inference on interaction): the plugin installs SessionStart,
PreToolUse (production deploy gate, Apex diagnostics gate), PostToolUse, Stop hooks, an agent that
auto-activates in sfdx-project.json repos, and local telemetry. Chassis workers run their own gate
and never touch production, so the gate flow adds friction. `npx skills add forcedotcom/sf-skills`
is the README's route for non-Claude agents; I did not verify what it writes or where, so no flags
beyond the README form.

Skip: the other industry plugins, experience-react, persona and d360 and architecture-analyze
skills (no use now), agentforce-bot-upgrade (no Einstein Bot here), the archived Jaganpro repo,
and the retired DX MCP servers. Do not copy the `--version-number` snippet or the "validate is local"
claim.

What installing changes (documented from plugin README, none done): plugin cache under
`~/.claude/plugins`, hooks that run python3, MCP servers (metadata ones on by default, H360 off),
an LSP host, telemetry (local; only a numeric rating leaves the machine), the auto-activating
`salesforce-dev` agent. Nothing is written to this repo. Currently no Salesforce plugin is installed
(`known_marketplaces.json`: claude-plugins-official, universal-modder, runpod).
