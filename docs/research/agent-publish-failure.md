# Why `sf agent publish authoring-bundle` fails for Account_Brief (OPS-9)

Researched 2026-11-11 against org `experimental` (API 68.0). Status words: verified (seen in code,
log or org), documented (official source), unverified (inference or community). Diagnosis only:
nothing was published, deployed or changed in the org. Retrieves went to a scratch folder outside
the repo.

## Plain answer

- The cause is not proven. The best-supported reading is a server-side failure in the
  "create a new version" call, not a CLI bug. The CLI's own log shows that call
  (`POST api.salesforce.com/.../authoring/agents/0XxgK000002WVtxSAG/versions`) returning 404
  after about 6 seconds, then the CLI trying `test.api.salesforce.com`, which does not accept
  connections from outside Salesforce, which is what prints `TypeError: fetch failed` (verified).
- So `fetch failed` is a symptom, not the cause. It hides the real 404 body. The only real
  message we have is the manual replay's `Error saving or updating agent graph` (given as a
  known fact; not re-run).
- Trying CLI 2.154.4 and 2.157.8 was not two independent tests: both ship the same
  `@salesforce/agents` 2.3.1 and the same publish code (verified). Newer `agents` 2.4.1 exists,
  but its versions path is unchanged on GitHub main (verified), so upgrading will not help.
- Nothing local explains it: the local script is byte-identical to the org's draft bundle
  (verified).
- Recommended next step: commit a new version from the Agentforce Studio UI (steps below), which
  uses a different code path. v1 stays Active throughout. If the UI also fails, it is a platform
  or tenant problem and needs a Salesforce Support case with the request details below.

## What the publish command does (verified from code)

Files: `~/.local/share/sf/client/2.157.8-b36e90e/node_modules/@salesforce/` (plugin-agent 2.2.3,
agents 2.3.1; 2.154.4 ships plugin-agent 2.2.2 and the same agents 2.3.1).

1. `plugin-agent/lib/commands/agent/publish/authoring-bundle.js` `run()`: builds
   `Agent.init({connection, project, aabName})`, then `agent.compile()`, then
   `agent.publish(flags['skip-retrieve'])`.
2. `agents/lib/agents/scriptAgent.js` `compile()` (line ~188): `POST
   https://api.salesforce.com/einstein/ai-agent/v1.1/authoring/scripts` with the script text and
   `afScriptVersion: '2.0.0'`, using the JWT connection. `publish()` (line 223) applies string
   replacements, compiles again, then calls `ScriptAgentPublisher.publishAgentJson()`.
3. `agents/lib/connectionManager.js`: builds two connections. The "standard" one uses the normal
   org access token. The "JWT" one is the same login upgraded through
   `GET <instanceUrl>/agentforce/bootstrap/nameduser` with `Cookie: sid=<token>`
   (`utils.js` `useNamedUserJwt`, line 246). The JWT is checked for `sub`, `iss`, expiry.
4. `agents/lib/agents/scriptAgentPublisher.js` `publishAgentJson()` (lines 126-159):
   - `getPublishedBotId()` (line 330) runs `SELECT Id FROM BotDefinition WHERE
     DeveloperName='Account_Brief'` on the standard connection. A hit means "already published".
     Zero rows returns undefined. Any other error is rethrown.
   - Line 138: `url = botId ? API_URL/<botId>/versions : API_URL`, with `API_URL =
     https://api.salesforce.com/einstein/ai-agent/v1.1/authoring/agents` (line 114). Existing
     agent: new version. No agent: create agent. The choice is purely "does a BotDefinition with
     this developer name exist".
   - Body: `{ agentDefinition: <compiled JSON>, instanceConfig: { endpoint: <instance URL> } }`.
     Headers `x-client-name: afdx`. It does not reference the draft authoring bundle, v1, the
     activation state, or any other org object.
5. The POST goes through `maybe-mock.js` `request()` then `utils.js`
   `requestWithEndpointFallback()` (line 677) using the JWT connection, retry max 3. It tries
   hosts `api.`, `test.`, `dev.`, `stage.` in that order, and moves on ONLY on HTTP 404. Any
   other error, including a connect timeout, is thrown at once. If all four 404 it throws
   `AgentApiNotFound` ("Ensure the user ... has the necessary permissions").
   - So: prod 404, then `test.api.salesforce.com` connect timeout, then raw `fetch failed`.
     The prod 404 body is discarded (stored only as `cause` in the final error).
6. If the response has `botId` and `botVersionId`: `getBotVersion()` queries BotVersion, then
   `retrieveAgentMetadata()` (skipped by `--skip-retrieve`; it only retrieves AiAgentDefinition /
   Bot metadata into the project), then `deployAuthoringBundle()` which writes
   `<target>Account_Brief.vN</target>` into the local `bundle-meta.xml`, deploys the bundle, then
   removes the target. `--skip-retrieve` therefore skips only step 6's retrieve; it cannot
   affect the failing POST, which happens before it.
7. Token used: the nameduser JWT for the POST; the ordinary token only for SOQL, retrieve, deploy.
   A manual replay with the ordinary token gets an empty 404 (known fact), consistent with SFAP
   rejecting non-JWT callers (unverified inference).

The CLI's own log (`~/.sf/sf-2026-11-11.log`) for the failed runs shows, in order: scripts
compile OK (twice), "Agent is already published, botId=0XxgK000002WVtxSAG", POST `.../versions`
on `api.` returning 404 after about 5.9 s, POST on `test.` failing with no status after about
10 s (verified). The first, successful publish has no debug lines in the log, so a side-by-side
comparison is not possible (verified absence).

## Org probes (read-only, alias `experimental`)

| Probe | Result |
|---|---|
| `sf data query` BotDefinition `DeveloperName='Account_Brief'` | One row 0XxgK000002WVtxSAG, Type InternalCopilot, AgentType AgentforceEmployeeAgent, BotUserId null, BotSource None, last modified 2026-11-11 04:34:35Z (unchanged since creation). verified |
| `sf data query` BotVersion for it | One row 0X9gK0000048xtRSAQ, v1, VersionNumber 1, Active, BillingMode ActionBased, language en_US. No draft or second version row. verified |
| `sf org list metadata -m AiAuthoringBundle` | `Account_Brief_1` and `Account_Brief_2`, both 04:34:47Z. There is no bundle named plain `Account_Brief` in the org. verified |
| Retrieve both into a scratch project | `_1` has `<target>Account_Brief.v1</target>` (locked to v1). `_2` has no target (the editable draft). Both `.agent` files are byte-identical to the repo's `Account_Brief.agent`. verified |
| `sf org list metadata` GenAiPlannerBundle, AiAgentDefinition(+Version), Bot | Account_Brief_v1 planner, Account_Brief definition and Account_Brief#1 version. Nothing in progress. verified |
| Tooling API `GenAiPlannerDefinition` | Account_Brief_v1 only (for this agent). `AiAuthoringBundle` is not queryable by SOQL (`AiAuthoringBundleDefVer` unsupported); metadata listing was used instead. verified |
| Retrieve `AiEvaluationDefinition:Account_Brief_Test` | `subjectType AGENT`, `subjectName Account_Brief`, `subjectVersion v1`. A pointer to v1 by name. verified. Whether it blocks a new version is unknown |
| Retrieve `PermissionSet:Account_Brief_Agent_Access` | Only `agentAccesses{agentName Account_Brief, enabled true}`. References the agent, not a version. verified |
| Retrieve `Account_Brief_Data_Access` | Apex class access only; no agent reference. verified |
| DNS/connect check | `api.salesforce.com` answers 404 to an unauthenticated GET in 0.15 s. `test.api.salesforce.com` does not connect within 6 s. verified |

Not done: decoding the nameduser JWT claims (the helper script failed to parse the response; it was
not retried to avoid handling the token further).

## Ranked hypotheses

**1. Server-side failure creating the version (SFAP or Core), shown to the CLI as a 404.**
Rank: most likely, not proven.
- For: the replayed body with the CLI JWT returned a real service message, `Error saving or
  updating agent graph` (known fact); the 404 took about 6 s, which looks like a backend call
  that failed, not a missing route (verified timing); compile succeeds with the same JWT; the same
  unchanged script published as v1 hours earlier; identical result on two CLI builds (which share
  one library, so this is expected).
- Against: the replay gave 401 and the CLI gave 404 for what should be the same call. That is
  unexplained (maybe different token or body; unverified). No public report of the exact message
  was found.
- Cheapest test: do the same operation from the Agentforce Studio UI (next section). If the UI
  also says it cannot commit or save the agent graph, it is platform side.

**2. Something added to the org after v1 now blocks or breaks a new version.**
Candidates: AiEvaluationDefinition `Account_Brief_Test` (pins `subjectVersion v1`), the two
permission sets, the Lightning app and utility bar. Rank: plausible, no evidence either way.
- For: timing; the only changes between the working and failing publish.
- Against: no CLI or API code reads any of them before the POST (verified); no documented
  dependency; the permission set holds only an agent-name reference.
- Cheapest test: none that is read-only. The lowest-risk change test is a first-publish of a
  scratch-named copy of the script (`/authoring/agents`, not `/versions`) to see if publishing
  works at all. That creates a new agent in the org, so it needs the owner's go-ahead. Removing the
  evaluation definition is the more invasive second test.

**3. Tenant or routing problem in the Agent authoring service (not entitlement).**
Same shape as forcedotcom/cli issue 3634 (prod 404 then fallback to an internal host).
- For: that issue's analysis of the fallback matches our log exactly (verified in code).
  Its reporter later found the 404 meant "org not entitled" on a scratch org.
- Against: our org published v1 today and compile still works, so entitlement is unlikely to have
  vanished. The issue's own author could not explain the Developer Edition 404 (unverified).
- Cheapest test: re-run `sf agent validate authoring-bundle` (compile only, read-only) and retry
  later, or open the UI path. A Support case settles it.

**4. Draft-bundle state (`Account_Brief_2` vs the unpublished "naked" bundle).** Rank: low.
- sf-skills describes the lifecycle as: publish locks the current draft and the platform creates a
  new one; edits go through the naked bundle (documented, forcedotcom/sf-skills,
  `agent-metadata-and-lifecycle.md`, section 4). Our org has the draft as `Account_Brief_2`, not a
  naked `Account_Brief` (verified), and the local `bundle-meta.xml` has no target (verified).
- Against: the POST carries only the compiled JSON; the code never reads bundle state (verified).
- Cheapest test: `sf project deploy start -m AiAuthoringBundle:Account_Brief` updates the draft;
  it changes org state, so only on the owner's go-ahead.

**5. Client or CLI version.** Ruled out as a distinct cause: same library on both builds, and
GitHub main has no change to the versions path (verified). Upgrading `@salesforce/agents` to
2.4.1 would only add `--source-type` and a describe-based format probe (agents PRs 391, 378).

## Issue and web search results

| Hit | Matches us? |
|---|---|
| https://github.com/forcedotcom/cli/issues/3634 (open, labelled bug, investigating; "fetch failed", prod 404 on `/authoring/agents`, fallback to `test.api`) | Partly. Same fallback mechanism and symptom text. Their route was first-publish `/authoring/agents`; ours is `/versions`. Gives no fix. documented (issue), mechanism verified |
| Exact string `Error saving or updating agent graph`: gh issue search across the four repos (rate limited partway, so title-scan of every issue and PR in the four repos was used instead), plus web search | No hit anywhere. Not found |
| https://github.com/forcedotcom/agents/pull/391 and https://github.com/salesforcecli/plugin-agent/pull/516 | Show a republish creating "v2" works in Salesforce's own test org (documented, PR text). Not our failure |
| https://github.com/forcedotcom/agents/pull/310, pull/229, pull/350, pull/352 (publish fixes: version suffix, deploy order, missing tools, botId lookup errors) | No. Different failures |
| https://github.com/forcedotcom/cli/issues/3685 ("fetch failed" on deploy status checks) | No. Deploy, not publish |
| https://github.com/forcedotcom/sf-skills/issues/322 (validate passes, publish rejects some action types server-side) | No, but shows publish does server-side checks beyond compile. Our script is unchanged from the one that published |
| sf-skills `known-issues.md` and lifecycle doc: "deactivate any active version, then republish" for a failing publish | Partly. Deactivation was already tried by us with no change |
| Developer docs "Publish an Authoring Bundle to Your Org (Beta)" and the Agentforce DX troubleshooting page | Not read: both returned HTTP 403 to fetch. Search snippets only say only draft (unversioned) bundles can be published (unverified, snippet) |

## Recommended next action

Order: A, then (if A fails) C. B is optional and needs the owner's approval.

**A. Commit a new version in Agentforce Studio (UI path, not the failing SFAP call from the CLI).**
Documented path: sf-skills says Studio has a "create new DRAFT version" button on a published version
(lifecycle doc, section 4).
1. `sf org open agent -o experimental --authoring-bundle Account_Brief` (the old `org open
   authoring-bundle` is deprecated, per its own help), or Setup, search "Agentforce Agents".
2. Open Account Brief, open the draft version (the org's `Account_Brief_2`). Confirm the script
   text matches the repo's `Account_Brief.agent` (it did when checked, byte for byte).
3. Compile/validate in the builder, then Commit (publish) the version. Note the exact error text
   and time if it fails.
4. Do not activate until tested. Activating the new version should deactivate v1
   (documented in sf-skills; confirm before relying on it).
Risk to v1: committing adds v2 and leaves v1 Active. v1 is only affected by activating v2 or by
deactivating. If the routing fix must go live, activate v2 in the UI, test, and activate v1
again if v2 misbehaves (one-click either way; unverified).

**B. Pin the platform side (only with approval).** First-publish a copy under another API name
via the CLI to see if `/authoring/agents` works from this org. It leaves an extra agent in the
org that must be removed by hand. If it succeeds while `/versions` fails, hypothesis 1 or 3 holds
for the versions route specifically.

**C. Escalate.** Open a Salesforce Support case (Agentforce authoring) with: org id
00DgK00000VGf8bUAD, agent 0XxgK000002WVtxSAG, endpoint `POST /einstein/ai-agent/v1.1/authoring/agents/<id>/versions`,
response `401 {"message":"Error saving or updating agent graph"}` with the named-user JWT and
a 404 after about 6 s via the CLI, timestamps from `~/.sf/sf-2026-11-11.log`, and the fact that
v1 published from the same script earlier that day. Comment on forcedotcom/cli#3634 with the
same, since it is the open tracking issue (needs the owner's go-ahead to post).

Do not keep retrying the CLI publish. It cannot succeed or give a better error until the server
side changes, and each try costs about 20 s plus a likely second connect timeout.

## Still unknown

- Why the CLI sees 404 and the manual replay saw 401 for the same URL.
- Whether the Studio commit path succeeds. This is the decisive test and has not been run.
- Whether `Account_Brief_Test` (`subjectVersion v1`), the permission sets or the app/utility bar
  matter at all.
- Whether v1's 18:02:35Z last-modified time (the agent was deactivated and reactivated during
  earlier attempts) left any state behind. Not shown by the BotVersion fields read.
- The JWT's scopes and app id (not decoded).
- What the official publish and troubleshooting pages say (both returned 403).
