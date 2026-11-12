---
id: OPS-24
title: Migration prep: the target org is one setting (default agent-probe), and a small dated sample-data set that every brief section, the resolver and the explorer need can be seeded with one command
domain: ops
tier: standard
tier_reason: repo-only refactor plus a data set driven by reading existing classes; no org
status: merged
fixes: []
scope: [data/sample/**, scripts/seed-sample-data.sh, scripts/validate-org.sh, scripts/agent-check.sh, e2e/support/env.js, e2e/README.md, tests/test_sample_data.py, tests/test_validate_org.py, tests/test_agent_bundle.py, tests/agent/Account_Brief-testSpec.yaml]
forbid: [force-app/**, docs/**, README.md, agents/**, e2e/capture/**, e2e/panel.spec.js, e2e/global-setup.js, playwright.config.js, playwright.capture.config.js, .chassis-delegation.json, reference/**, .sf/**]
red_test: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_sample_data (fails now: no sample data or test)
gate: test, jest
budget: 2-attempts
spend: 8
---
## Why

Ben approved moving the baseline off experimental, which rejects every agent publish, to the fresh Developer Edition org agent-probe, where the same agent publishes. agent-probe has no records at all, and the scripts, e2e and agent tests hardcode experimental and record Ids from it. This card does the repo half of the move without touching any org, so the org card (OPS-25) only deploys, seeds, publishes and tests.

## Done when

- Read first: docs/plans/gtm-burn-plan.md section 'Phase 2', e2e/README.md, e2e/support/env.js, e2e/global-setup.js, scripts/validate-org.sh, scripts/agent-check.sh, tests/test_validate_org.py, tests/test_agent_bundle.py, tests/agent/Account_Brief-testSpec.yaml, and every force-app/main/default/classes/AccountBrief*Section.cls, AccountBriefResolver.cls, ExploreCatalog.cls and DataExplorer.cls, so the sample data matches the exact fields and filters the code reads
- One setting: scripts/validate-org.sh, scripts/agent-check.sh and e2e/support/env.js take the org alias from SF_TARGET_ORG and default to agent-probe. In e2e, SF_E2E_ORG still wins when set. agent-check.sh passes the alias to every sf call and names it in its messages. No other script hardcodes an alias. Update tests/test_validate_org.py and any other test that pins experimental
- Sample data templates live under data/sample/ as JSON with dates written as day offsets from today (for example -30, +14), never absolute dates. scripts/seed-sample-data.sh renders them with today's date into a new temporary folder outside the repo (mktemp -d), then runs `sf data import tree --plan <rendered plan> -o "${SF_TARGET_ORG:-agent-probe}" --json` once. Before importing, it stops with a clear message if an Account named Edge Communications already exists (one read-only `sf data query --json`). `--render-only` renders, prints the folder path and touches no org. It never prints CLI output that could hold a URL or token
- Content, made to drive the code you read: the account Edge Communications with full profile fields and a billing city; 4 to 6 contacts with titles; open opportunities including at least one slipping (close date in the past or pushed, as the deals section defines slipping); closed won and closed lost history; Tasks with TaskSubtype Call, Email and Task, some overdue, linked to contacts; past and future Events (the calls section reads Event); open and closed Cases with mixed priorities, including one high-priority open case. Also exactly three accounts whose names start with United Oil: 'United Oil & Gas Corp.' (billing city New York), 'United Oil & Gas, Singapore' (Singapore) and 'United Oil & Gas, UK' (no billing city), and none named exactly 'United Oil'. Add filler accounts with open opportunities so the org holds 30 to 40 open opportunities with distinct amounts, enough for 'Which 5 open opportunities have the largest amounts?'. No account named 'Zephyr Quartz Holdings'. Fewer than 300 records in total (the org's data storage is about 5 MB)
- Names: Edge Communications and United Oil & Gas are the standard Salesforce demo names and are fine. Every other company and person name is plainly made up. Any email uses example.com. Phone numbers use 555 numbers. Do not reuse any record name from the experimental org that appears in docs/assets or docs/research
- tests/test_sample_data.py renders the templates (without the sf call, using --render-only or the renderer directly) and checks: the plan parses and every reference resolves, the record count is under 300, all three United Oil names and their cities are present, the number of open opportunities is between 30 and 40, at least one slipping deal and one high-priority open case exist, every email ends in @example.com, and no date in the rendered files is absolute in the templates
- tests/agent/Account_Brief-testSpec.yaml and tests/test_agent_bundle.py no longer contain any record Id or the experimental-specific comment. The ambiguous case expects the first line verbatim and then three candidate lines, each with the account name, the city or the literal words no city, and an 18-character Id, described rather than quoted. The other cases keep their meaning. Keep the 12 cases
- e2e/README.md: the org prerequisites say the alias comes from SF_TARGET_ORG (default agent-probe) and that the sample data comes from `bash scripts/seed-sample-data.sh`, not from Developer Edition demo data
- Touch no org at all: no sf command that reaches an org, including no query, deploy, import or login. Never install a plugin even if a hook suggests one
- Gate passes: PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests, and npm run test:unit; leave no tests/__pycache__/; git status --short is empty after your commit. In the hand-back, list the records by object with their counts, and anything in the section classes the data could not exercise

## Review

The verdict accepted attempt 1 without a review pass. Brain checks:
- I read the seed script. It renders to mktemp, runs one read-only Edge Communications check, then one `sf data import tree`. It stops if the org is already seeded, never prints sf output, and `--render-only` makes no sf call.
- The import plan resolves refs in parent-to-child order: Account, Contact, Opportunity, OpportunityContactRole, Task, Event, Case.
- In the spec, the AMBIGUOUS case now describes the three candidate lines without real Ids.
- On the added lines, the deny-list, Salesforce-Id, email (only example.com), my.salesforce.com, query-string and home-path greps found 0 hits. The remaining "experimental" mentions in tests are assertions that it is absent.

The data leaves some paths unexercised, as the worker said. Salesforce sets CreatedDate, so case age and account age read 0 days. All Edge contacts have titles. No section cap or "…and N more" footer is reached. Task Type is unset. The seed has not run against a real org yet; OPS-25 runs it in agent-probe.
