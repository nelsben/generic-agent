---
id: FE-2
title: Account Brief Lightning app with a utility bar that hosts the accountBriefPanel, visible through the data-access permission set
domain: frontend
tier: standard
tier_reason: two metadata files plus a permission entry, with a shape that must be taken from the org
status: merged
scope: [force-app/main/default/applications/Account_Brief.app-meta.xml, force-app/main/default/flexipages/Account_Brief_UtilityBar.flexipage-meta.xml, force-app/main/default/permissionsets/Account_Brief_Data_Access.permissionset-meta.xml, tests/test_app.py]
forbid: [agents/**, .chassis-delegation.json, reference/**, force-app/main/default/classes/**, force-app/main/default/lwc/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/permissionsets/Account_Brief_Agent_Access.permissionset-meta.xml]
red_test: python3 -m unittest tests.test_app (absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 8
---
## Why

The custom panel is built and deployed but sits in no app, so it has never been seen in a real utility bar: the Cmd/Ctrl-K hotkey, the focus trap and the 340px layout are unverified. A baseline that is passed around should bring its own app and utility bar instead of editing a standard app.

## Done when

- Org alias is `experimental`. Do not deploy; the org gate is a check-only validation and the brain deploys after merge. Do not edit any standard app
- Find the metadata shape the org accepts by retrieving one existing Lightning app that has a utility bar, and its UtilityBar flexipage, from experimental into a scratch folder outside the repo (mktemp -d). Copy no names from it into the repo
- Account_Brief_UtilityBar.flexipage-meta.xml: a flexipage of type UtilityBar with one utility item, the custom component accountBriefPanel, label 'Account Brief', panel width 340, panel height 480, an icon from the standard utility set, and not set to start automatically
- Account_Brief.app-meta.xml: a Lightning app (standard navigation, Large form factor) labelled 'Account Brief', with tabs Home, Account, Opportunity, Contact and Case, and its utility bar set to Account_Brief_UtilityBar
- Account_Brief_Data_Access gains one applicationVisibilities entry for the Account_Brief app (visible true, not default). Change nothing else in that file. The agent-access permission set is not touched
- tests/test_app.py (stdlib unittest, XML parsing): the flexipage is type UtilityBar and references accountBriefPanel; the app references Account_Brief_UtilityBar; the data-access permission set makes the app visible. The existing tests still pass
- In the hand-back say whether the accountBriefPanel component needs anything changed to load in a utility bar (it is out of scope here; report only), and name any property the flexipage sets on the component
- Gates pass: test and org. Quote the `validate-org:` line. Commit, do not push

## Review

Brain read at 7c666ee: UtilityBar flexipage hosts accountBriefPanel with decorator properties (eager false, 340x480, icon chat, label Account Brief); Lightning app with Home, Account, Opportunity, Contact, Case and that utility bar; data-access permission set gains one applicationVisibilities entry and nothing else. Org gate passed (60 components, 115 tests). Unverified until deploy: hotkey, focus trap and layout in a live utility bar.
