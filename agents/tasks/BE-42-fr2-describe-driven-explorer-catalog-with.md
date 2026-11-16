---
id: BE-42
title: FR2+: describe-driven explorer catalog with an admin deny list in custom metadata, field pruning and on-demand describe, keeping the per-call catalog at or under 6,000 characters
domain: backend
tier: frontier
tier_reason: changes what data the live explorer can reach; security rules and prompt cost in a production-classified org
status: merged
blocked_by: [BE-41]
fixes: []
scope: [force-app/main/default/classes/ExploreCatalog*, force-app/main/default/classes/DataExplorer*, force-app/main/default/objects/Explore_Deny_Rule__mdt/**, force-app/main/default/customMetadata/Explore_Deny_Rule.*, force-app/main/default/staticresources/AgentPrompt_Explore*, spikes/explorer-scale/results/**, docs/research/fr2-explorer-catalog.md]
forbid: [force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, mcp-door/**, data/**, e2e/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: new ExploreCatalogTest cases (a question on an object outside today's curated eight resolves, a denied object and a secret-named field are refused, the per-call catalog size cap) fail on main and pass after
gate: test, org
budget: 2-attempts
spend: 15
---
## Why

Ben gave the go for the explorer build line (BE-41 to BE-45) on 2026-11-15; it is recorded in the Approvals table. BE-31 showed the curated 8-object catalog cannot reach a custom object or any object outside the eight, and that a describe-driven catalog with a deny list can, under the same user-mode guards. Sent whole, the describe catalog tripled each call's size, so field pruning and on-demand describe are part of this card, not later. Covers ledger rows F55 and F59 in docs/plans/feature-revision-2.md.

## Done when

- **Ben's go (2026-11-15):** part of the explorer build line BE-31 proposed (BE-41 to BE-45). Do not start until Ben's go is recorded in the Approvals table of docs/plans/gtm-burn-plan.md
- Read first: docs/research/fr2-explorer-scale.md ('Catalog', 'Limits', 'Risks'), docs/research/fr2-explorer-baseline.md (BE-41), spikes/explorer-scale/prototype.apex (its catalog and deny list), the Explore* and DataExplorer classes, and docs/patterns/02-ask-anything-explorer.md. Load the skills salesforce-development:platform-apex-generate, salesforce-development:platform-custom-metadata-type-generate, salesforce-development:platform-apex-test-generate and salesforce-development:platform-metadata-deploy first
- ExploreCatalog builds the catalog from describe for the running user. A new custom metadata type holds the deny rows (object names, suffix families and field-name patterns). Its default records deny: the product's own objects (Customer_Summary_Session__c, any later product object such as Customer_Outcome__c), setup and audit objects (at least SetupAuditTrail, LoginHistory, AuthSession, PermissionSet, Profile, ApexClass, StaticResource), the suffixes __Share, History, Feed, ChangeEvent, __mdt, __e, __x, __b, __kav and __chn, and encrypted, base64, address or location compound and secret-named fields. A new custom object is denied until an admin allows it. Apex tests prove each rule, including the field rules BE-31 left without a check
- A denied object or field never reaches SOQL, whether a plan names it at the top level, in a parent path or in a semi-join; tests cover each position. User mode still applies to every query; the deny list is extra, never instead
- Field pruning and on-demand describe: the prompt carries the core objects' pruned fields (name, fields the question mentions, picklists, dates, amounts and lookups) and every other allowed object as name and label only; a plan that names an object not yet described gets an INVALID line and that object's fields on the next turn. On BE-31's 30 questions the per-call catalog stays at or under 6,000 characters (median and maximum recorded in the hand-back)
- Prompt file: before changing AgentPrompt_Explore, list every class and surface that reads it. If anything besides DataExplorer reads it, add a new static resource whose name starts with AgentPrompt_Explore (so it stays in scope) instead of editing the shared one (the OPS-30 lesson), and say which in the hand-back
- **Org rules:** `agent-probe` only, with `-o agent-probe` on every `sf` command. Never touch `experimental` or use it as a Dev Hub. Never create a user. Never sign in or out, accept consent or enter credentials. Never retrieve or commit a consumer key or secret. No Ids, usernames, emails, tokens, hostnames or query-string URLs in a file or image. No destructive deploy. No security or red-team agent test. A deploy is a validate with RunLocalTests and then a quick deploy with the confirmation marker, never `deploy start`. Never publish or activate an agent
- Org, agent-probe only, under the standing approval: validate with RunLocalTests, then quick deploy with CONFIRM_PROD=1; run BE-31's 30 questions once on the deployed explorer and record pass count, model calls, input tokens, CPU and heap next to BE-41's baseline. Gates: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, bash scripts/validate-org.sh and bash scripts/check-docs.sh (0 broken). No tests/__pycache__, and git status --short is empty after the commit

## Review

Brain review (2026-11-15). One worker attempt (opus, frontier tier, $8.48) and one hand fix to a doc sentence by the brain (c633271). The worker paused on its own org jobs, which the mod logged as paused and no-report; the brain re-ran the verifier on the real hand-back. Two reviewer passes. The brain read the DataExplorer diff and the deny-list code.

Findings:
- The explorer's catalog is now built from describe calls. The curated eight objects stay as the core; an on-demand object lists up to 30 pruned fields; up to 16 other allowed objects are named in an index.
- A plan that names an allowed object the catalog has not described yet gets an INVALID line, and the next turn's catalog lists that object's fields. This costs a turn, not a query.
- Result: one live run on the deployed explorer passed 22 of 30, against the baseline of 20, 20 and 20. The spread between runs is about 5, so this is not a proven gain. BE-45 runs the after-evaluation.
- q29 (an object outside the old catalog) now passes in 3 model calls. q09, q11 and q16 also went from fail to pass against baseline run 1; q09 and q16 already changed between baseline runs.
- q18 passed in all six baseline runs and failed here with a wrong count. The cause is not established. q20 also failed; it already changed between baseline runs.
- The per-call catalog stayed at or under 6,000 characters on all 30 questions (median 4,948, max 5,994).
- Costs in the one run: 84 model calls (median 2.5 per question); CPU median 725 ms, max 1,385 ms; heap median about 239 KB, max about 262 KB. Both are above the baseline (373 ms and about 80 KB at worst) and far below the limits.
- Deny list: a custom metadata type, Explore_Deny_Rule__mdt, with 58 default records, read with getAll() and no SOQL. It refuses every object when the list is empty, cannot be read, or holds a pattern that does not compile. Any custom object is refused unless an AllowObject record names it, and a deny beats an allow. User shows only Id, Name and Title.
- ExploreQuery is unchanged and still runs every query in user mode. The explore prompt is unchanged.
- In drill, the related child still comes from the core objects only; the parent record may be any allowed object.

Gate (mod, at c633271): Python 390 tests, 4 skipped; validate-org pass, 213 components, 438 tests. check-docs: 80 pages, 0 broken.

Org: agent-probe only. The worker validated with RunLocalTests, then quick deployed the catalog and the deny-list type and records before review. No record, user or setting was created, by the worker's account. A worktree-local target org was set for the deploy hook, then unset; the brain confirmed it is unset.

Disclosed and accepted:
- The first reviewer pass confirmed 24 rows and refuted one: the page said the catalog shows 6 picklist values per field, but 6 is only the first level and falls to 3 or none under the size cap. The brain corrected the sentence by hand after the worker's budget was spent.
- The run record's "invalid" count is 0 for q29, so the INVALID turn itself is not shown in the result rows; the code path and the 3 model calls are.
- The page's CPU explanation, and its statement that the OR, HAVING and anti-join failures are not a catalog problem, are inferences, not measurements.
- DataExplorer gained a public static RunStats (model calls and character counts, no question text) for the measurement harness.

Still open:
- q18's cause. Fewer picklist values per field is one candidate.
- Three more runs would settle whether 22 is a gain; BE-45 does that after the grammar work.

Privacy check over the full branch diff (2,161 added lines): 0 denylist hits. The pattern hits are test annotations. The URL hosts are the standard metadata and XML schema namespaces.
