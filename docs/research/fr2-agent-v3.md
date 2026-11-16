# FR2+: Customer_Summary v3, the resolve_account descriptions name ERROR (BE-60)

- Date: 2026-11-16, 22:44 to 22:50 UTC. Org `agent-probe`. Every `sf` command ran with `-o agent-probe`.
- Approval: the row "FR2+: fix the `resolve_account` output descriptions" in the Approvals table of
  [gtm-burn-plan.md](../plans/gtm-burn-plan.md) reads "approved (Ben, 2026-11-16, in chat ...)" (verified on
  origin/main before any org step).
- Read first: [fr2-agent-publish.md](fr2-agent-publish.md) (how v2 was published and activated) and
  [fr2-testing-center.md](fr2-testing-center.md). BE-38 found the lag: `resolve_account` returns `ERROR` when
  the account search fails (BE-29) and the instructions handle it, but the descriptions listed three statuses.
- No Ids, usernames, hostnames or URLs are written here. Counts only.

## The change

In `Customer_Summary.agent`, the two places that list `resolve_account`'s status values now name all four:

- The action description ends "RESOLVED, AMBIGUOUS, NOT_FOUND or ERROR (the account search failed)."
- The `status` output description reads "RESOLVED, AMBIGUOUS, NOT_FOUND or ERROR. ERROR means the account search
  failed: say so, never claim nothing was found."

No other wording changed. New test `test_resolve_account_status_lists_name_all_four_statuses` in
`tests/test_agent_bundle.py` failed on main (ERROR missing) and passes now.

## Versions

| When | Version 1 | Version 2 | Version 3 |
|---|---|---|---|
| Before (22:44Z) | Inactive | **Active** | none |
| After the publish (22:45:22Z) | Inactive | Active | Inactive |
| After the activation (22:45:35Z) | Inactive | Inactive | **Active** |

## What was done

| Step | Time (UTC) | Result |
|---|---|---|
| `bash scripts/agent-check.sh` | 22:44:45 | pass: local compile 0 warnings, org validate ok |
| `sf agent publish authoring-bundle --api-name Customer_Summary -o agent-probe --json` | 22:44:52 to 22:45:22 | success, 3 deployed, 13 retrieved |
| `sf agent activate --api-name Customer_Summary --version 3 -o agent-probe --json` | 22:45:31 to 22:45:35 | success, version 3 |
| Check after activation: one turn from Apex asking for a summary of Gallowglass Textiles | 22:45:44 to 22:46:12 | `isSuccess` true, a 1458-character summary came back |
| `bash scripts/agent-test.sh --org agent-probe` | 22:46:15 to 22:50:11 | see below |

The publish retrieved the metadata back into the working tree (no `--skip-retrieve`): it reformatted the bundle
`-meta.xml`, touched three Apex class files and added `aiAgents` and `aiAgentDefinitionVersions` folders. All were
restored or removed before the commit; only the `.agent` change stays.

## Suite on version 3

`agent-test: Customer_Summary version 3 (active)`, 16 cases:

- subagent: 15 passed, 0 failed (1 case sets no subagent, not counted)
- actions: 16 passed, 0 failed
- outcome: 16 passed, 0 failed
- **47 of 47 assertions passed.** No failed case.

## What the runs wrote

`Customer_Outcome__c` rows on Gallowglass Textiles (read-only count): **12 before**, **19 after**. That is 7 new
rows: 1 from the check-after-activation turn and 6 from the suite's six summary cases.

## Undo

Version 2 is Inactive and kept. To go back: `sf agent activate --api-name Customer_Summary --version 2 -o agent-probe --json`
(this makes v3 Inactive). The version 3 metadata cannot be deleted through the CLI; see
[fr2-agent-publish.md](fr2-agent-publish.md#undo). The 7 outcome rows are the rows a summary always writes and are
left as they are.
