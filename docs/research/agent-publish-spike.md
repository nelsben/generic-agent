# Publish spike: Account_Brief version 2 from the CLI (OPS-21)

- Date: 2026-11-12, 03:34 to 03:45 UTC. Org `experimental` (Developer Edition, API 68.0).
- CLI: `@salesforce/cli` 2.157.8 (`@salesforce/agents` 2.3.1, jsforce-node 3.12.0, undici 8.12.3).
- Script: `force-app/main/default/aiAuthoringBundles/Account_Brief/Account_Brief.agent`, sha256
  prefix `fb0fc27d`. This is not the version 1 script. The org's open draft `Account_Brief_2` was
  retrieved into a scratch folder and has the same sha256 (`fb0fc27d`).
- Status words: verified (seen in a capture, the code or an org query), unverified (inference).
- Ids are replaced by `<agent id>`. SFAP request ids are cut to 8 characters. The full captures
  are in local scratch files outside the repo.

## Plain answer

- **No version 2 exists, and version 1 is still the active version.** The CLI publish, a
  first-publish of a new throwaway agent and Studio's Commit Version all failed (verified).
- **This is the real server error, captured for the first time.** Every create call to the Agent
  authoring API returns `401` with this body (verified):
  `{"expected":true,"message":"Error saving or updating agent graph","status":401,"error":"Unauthorized"}`.
  - It comes back after 3.8 to 5.6 s, both for a new version
    (`POST /einstein/ai-agent/v1.1/authoring/agents/<agent id>/versions`) and for a new agent
    (`POST .../authoring/agents`).
  - Compiling the script (`POST .../authoring/scripts`) returns 200 with the same token every time.
- **The 404 we chased was produced by the CLI's HTTP library.** jsforce treats every 401 as an
  expired session (`http-api.js` `isSessionExpired`). It refreshes the token and resends the call,
  which gets an empty 404 in about 120 ms. The CLI's fallback then tries `test.api.salesforce.com`,
  which times out on connect and prints `TypeError: fetch failed` (verified in the capture and
  the code).
  - This explains the open question in agent-publish-failure.md: why the CLI saw 404 when a manual
    replay saw 401.
- **Two hypotheses are disproved** (verified):
  - "Nothing changed": the script sent tonight differs from version 1 and still fails.
  - The open Studio draft blocks a CLI create-version: a brand-new agent with no draft fails the
    same way, and committing the draft from Studio fails too.
- **What the evidence supports:** hypothesis 1 of agent-publish-failure.md. A server-side failure
  saves the agent graph in this org for every create, through every client. The problem is not
  specific to Account_Brief or to the CLI.
- **Nobody can ship an agent version to this org from the CLI or from Studio until the server
  stops failing.** The blocker and the next decisive tests are listed below.

## What was tried, in order

The pre-checks all passed (verified):

- The bundle `-meta.xml` holds only `<bundleType>AGENT</bundleType>` with no `<target>` line.
- `.forceignore` does not cover `aiAuthoringBundles`.
- `bash scripts/agent-check.sh` passed: local compile with 0 warnings, then org validate.
- `sf agent validate authoring-bundle --api-name Account_Brief -o experimental --json` returned
  `success: true`. Its compile call returned 200.
- Every flag was checked with `--help` first. That included `--skip-retrieve` on publish and
  `--version` on activate.

**How the calls were captured.** Each publish ran with `SF_LOG_LEVEL=debug` and a Node preload
(`NODE_OPTIONS=--require <scratch>/fetch-capture.cjs`). The preload wraps undici's `fetch`, which
jsforce uses. For every call to `*.api.salesforce.com` it records the status, the timing and the
response body, and never the request headers. It also redacts JWTs and session ids.

This turned out to be needed. The CLI's debug log logs the status code only, never the body.
On this run it also wrote no lines at all to `~/.sf/sf-2026-11-12.log`.

| # | Step (approval line) | Call | Real status and body | Result |
|---|---|---|---|---|
| 1 | CLI publish of Account_Brief (approved). Open draft `Account_Brief_2` present | `sf agent publish authoring-bundle --api-name Account_Brief -o experimental --skip-retrieve --json` | compile 200, 200; `POST .../agents/<agent id>/versions` **401** after 5.6 s, body `{"expected":true,"message":"Error saving or updating agent graph","timestamp":1794454592,"path":"/v1.1/authoring/agents/<agent id>/versions","requestId":"9716b7d2…","status":401,"error":"Unauthorized"}`; jsforce refresh-and-resend: **404**, empty body, 123 ms; `test.api` connect timeout after 10.1 s | exit 10, `TypeError: fetch failed`. No version created. `git checkout` of the bundle and `git status`: clean |
| 1b | Deactivate-first, then publish once (added by the brain's note) | not run | n/a | **Skipped.** No Approvals line covers deactivating the agent (re-read in the main checkout after step 1), and corrective-plan rule 4 makes deactivation Ben's call |
| 2 | First-publish of a throwaway copy `Publish_Probe` (approved). Run from a temp project outside the repo; `developer_name` and `agent_label` changed, script otherwise identical | `sf agent publish authoring-bundle --api-name Publish_Probe -o experimental --skip-retrieve --json` | compile 200, 200; `POST .../authoring/agents` **401** after 4.6 s, same body (`"path":"/v1.1/authoring/agents"`, `requestId` `42b8e133…`); resend **404** empty, 127 ms; `test.api` connect timeout | exit 10, `fetch failed`. Queried afterwards: 0 BotDefinitions named `Publish_Probe%`; no `Publish_Probe` AiAuthoringBundle, Bot, AiAgentDefinition or GenAiPlannerBundle. Nothing to delete, so no destructive deploy and no manifest |
| 3 | Studio "Commit Version" on Account Brief, Version 2 (Draft) (approved). Claude in Chrome, own tab, closed after | Commit Version, then Commit in the "Commit this version?" modal | Toast: "We couldn't commit a version of this agent. Check Agent Script, fix any errors, and try again." The Problems panel showed 0 errors, 1 warning, 0 info (the known `knownAccountId` warning from studio-preview.md). The page's network body was not capturable, because tracking starts only when first read | Failed. The draft is unchanged and still open |
| 3b | One CLI publish of a comment-only change as version 3 (approved). Temp copy with one `#` comment line added (sha256 prefix `525a6822`); local compile clean | same command as step 1, from the temp project | compile 200, 200; `POST .../agents/<agent id>/versions` **401** after 3.8 s, same body (`requestId` `ca3062b4…`); resend **404** empty, 113 ms; `test.api` timeout | exit 10, `fetch failed`. No version created. The draft was still open, because step 3 failed, so this attempt did not test the open-draft hypothesis. Step 2 already did |
| 4 | 12-case spec against version 2 | not run | n/a | **Skipped: no version 2 exists** |
| 5 | Activate version 2, then the two-turn check and three cases | not run | n/a | **Skipped: no version 2 exists.** Version 1 was never deactivated |

## Which hypothesis the evidence supports

Each row is checked against the ranked list in `docs/research/agent-publish-failure.md`.

| Hypothesis | Verdict | Evidence |
|---|---|---|
| 1. Server-side failure creating the version, shown to the CLI as 404 | **Supported, and widened.** The failure is not limited to versions: first-publish of a new agent fails the same way. The 404 is jsforce's resend after the server's 401, not a missing route | Steps 1, 2, 3b captures. jsforce `isSessionExpired` returns true for any 401 whose body lacks two known strings |
| 2. Something added after version 1 blocks a new version (eval definition pinning v1, permission sets, app) | **Weakened in its Account_Brief form.** `Publish_Probe` has no eval definition, permission set or app and fails identically. An org-wide change is still possible (see the lead below) | Step 2 |
| 3. Tenant or routing problem | **Routing ruled out; tenant-level failure consistent.** The production endpoint answers with a real service message. Only the fallback host is unreachable, and it is internal | Steps 1 to 3b |
| 4. Draft-bundle state (the open "Version 2" draft blocks the CLI) | **Disproved as the cause.** A new agent with no draft fails the same way, and committing the draft from Studio also fails | Steps 2 and 3 |
| 5. Client or CLI version | **Ruled out.** Studio, a different client and code path, fails too | Step 3 |
| "Nothing changed" (the CLI re-sent version 1's script) | **Disproved.** Tonight's script (`fb0fc27d`) differs from version 1 and fails the same way | Step 1 |

**A lead from the setup audit trail (read-only query; unverified as a cause).**

- Version 1 published at 04:34Z on 2026-11-11. The first recorded failed publish is at 16:07Z.
- Between those times, apart from our own Apex, LWC and permission-set deploys (04:18 to 04:58Z),
  the audit trail shows two changes the platform made itself:
  - 05:45Z: "Permission set Customer 360 Data Platform Integration was converted to integration
    permission set".
  - 06:17Z: a recalculation of the `AgentforceServiceAgentUserPsg` permission set group (Data
    Space `default` removed and re-added).
- A 401 saying "Unauthorized" while saving the agent graph fits a permission or integration-user
  change on the platform side better than a script problem. Nothing tonight proves that link.

## Final org state

This is the read-only query after the last step, run at 03:44Z.
`SELECT BotDefinition.DeveloperName, DeveloperName, VersionNumber, Status, LastModifiedDate FROM BotVersion WHERE BotDefinition.DeveloperName IN ('Account_Brief','Publish_Probe') ORDER BY VersionNumber`

| Agent | Version | VersionNumber | Status | LastModifiedDate |
|---|---|---|---|---|
| Account_Brief | v1 | 1 | Active | 2026-11-11T18:02:35.000+0000 |

- totalSize is 1. Nothing named Publish_Probe exists.
- AiAuthoringBundles in the org:
  - `Account_Brief_1` (locked to v1)
  - `Account_Brief_2` (the open draft, last saved 02:36Z, sha256 `fb0fc27d`)
  - `Plesio_AgentScript_1` (an older agent, untouched)
- Nothing was deactivated, activated, deployed or deleted. The only org writes attempted were the
  four create calls above, and all of them failed.

## Test table

Not run. Step 4 needs a version 2, and none exists.

- The 12-case spec (`tests/agent/Account_Brief-testSpec.yaml`) and the two-turn
  `generateAiAgentResponse` check were not run.
- The org's `Account_Brief_Test` evaluation definition was not changed.
- The last per-case results for these exact script bytes are the Studio live preview in
  `docs/research/studio-preview.md`: 12 of 12 pass. Case 11 has the known relay note.

| Case | Result |
|---|---|
| 1 to 12 | not run (no version 2) |
| Two-turn follow-up | not run (it reaches only the active version, which is still v1) |

## How to ship an agent change from the CLI

**The exact blocker:** the Agent authoring API's save step. Any create in this org (new version,
new agent) gets
`401 {"expected":true,"message":"Error saving or updating agent graph"}`.

- The same failure happens through Studio's Commit Version.
- No CLI flag, script change or draft state changes it.
- No step below can succeed until the server accepts a create.

When it does, these are the steps. Steps 1 to 4 ran cleanly tonight; steps 5 to 9 have not been
proven in this org.

1. Check the bundle `-meta.xml` holds only `<bundleType>AGENT</bundleType>`, and that
   `.forceignore` does not cover the bundle.
2. Run `bash scripts/agent-check.sh`, which does the local compile and org validate.
3. Run `sf agent validate authoring-bundle --api-name Account_Brief -o experimental --json`.
4. Run the publish once with the capture:
   `SF_LOG_LEVEL=debug PUBLISH_CAPTURE_FILE=<scratch>/x.jsonl NODE_OPTIONS="--require <scratch>/fetch-capture.cjs" sf agent publish authoring-bundle --api-name Account_Brief -o experimental --skip-retrieve --json`.
   Never `sf project deploy start` the bundle.
5. Run `git checkout -- force-app/main/default/aiAuthoringBundles/Account_Brief` and `git status`.
   Publish writes, then removes, a temporary `<target>` line.
6. Query `BotVersion` for the new version number.
7. Run the 12-case spec, then activate with an explicit version:
   `sf agent activate --api-name Account_Brief --version <N> -o experimental --json`.
   Without `--version`, `--json` activates the latest version.
8. Run the two-turn `generateAiAgentResponse` check.
9. Roll back with `sf agent activate --api-name Account_Brief --version 1 -o experimental --json`.

## Next decisive tests (each needs Ben's go)

1. **Publish a minimal script as a new agent.** Use one `start_agent` block with no actions and
   no Apex targets. This tells whether the save fails on our action graph (Apex targets) or on
   any agent at all. It would be a second Publish_Probe-style create, so it needs its own approval.
2. **Look in Setup for the 05:45Z change.** Check the integration permission set conversion and
   the Agentforce permission set group change, and whether the Einstein/Agentforce platform user
   lost a permission.
3. **Decode the named-user JWT's claims.** Only the scopes and the app, not the signature. This
   checks for a scope change since version 1.
4. **The deactivate-first test from the brain's note**, if Ben approves the short deactivation.
   The evidence above makes it unlikely to help, because a new agent with nothing active fails the
   same way.

## Draft comment for forcedotcom/cli issue 3634 (not posted; posting is not approved)

> Same symptom on CLI 2.157.8 (`@salesforce/agents` 2.3.1), Developer Edition org, for both
> `POST /einstein/ai-agent/v1.1/authoring/agents/<id>/versions` (republish) and
> `POST /einstein/ai-agent/v1.1/authoring/agents` (first publish). I captured the HTTP responses
> by wrapping undici's fetch. The production endpoint does not return 404 first. It returns:
>
> `401 {"expected":true,"message":"Error saving or updating agent graph","path":"/v1.1/authoring/agents/<id>/versions","status":401,"error":"Unauthorized"}` (after about 4-6 s)
>
> jsforce's `HttpApi.isSessionExpired` treats any 401 as an expired session, refreshes the token
> and resends. The resend gets an empty 404 in about 120 ms (presumably because the refreshed
> token is not the named-user JWT). `requestWithEndpointFallback` then moves on to
> `test.api.salesforce.com`, whose connect timeout surfaces as `TypeError: fetch failed`. So the
> real server message is lost twice.
>
> Suggestions: (1) do not let jsforce's refresh-on-401 handle requests made with the named-user
> JWT (or add this message to the skip list); (2) fall back to `test.`/`dev.`/`stage.` only for
> internal orgs, or treat a connect error on a fallback host as "stop and report the previous
> error"; (3) include the first non-2xx body in the thrown error.
>
> Compile (`/authoring/scripts`) returns 200 with the same token. Agentforce Studio's "Commit
> Version" fails for the same agent with "We couldn't commit a version of this agent". So the
> underlying save failure looks server-side; the CLI only hides it.
