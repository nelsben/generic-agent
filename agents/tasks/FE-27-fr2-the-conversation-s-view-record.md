---
id: FE-27
title: FR2: the conversation's View record link opens the record from the compact window and from the rail — one e2e click proves it, and a dead link is routed through the panel
domain: frontend
tier: standard
tier_reason: one e2e probe and, only if dead, an event route copied from FE-15's rail pattern; method decided in the card
status: queued
fixes: []
scope: [force-app/main/default/lwc/customerSummaryConversation/**, force-app/main/default/lwc/customerSummaryPanel/**, e2e/**, docs/research/fr2-panel-proof.md]
forbid: [force-app/main/default/lwc/customerSummaryCard/**, force-app/main/default/lwc/customerSummaryRail/**, force-app/main/default/lwc/customerSummaryVoiceInput/**, force-app/main/default/classes/**, force-app/main/default/aiAuthoringBundles/**, force-app/main/default/objects/**, force-app/main/default/flexipages/**, scripts/**, tests/**, agents/**, docs/plans/**, docs/patterns/**, README.md, .chassis-delegation.json, reference/**, sfdx-project.json]
resources: [org-live]
red_test: the new e2e test that View record in the rail lands on the record page; if it already passes on agent-probe the card is test-only and says so
gate: test, jest, org
budget: 2-attempts
spend: 10
---
## Why

customerSummaryConversation's View record button (handleViewRecord) calls NavigationMixin.Navigate from inside the stage that the panel moves onto document.body. FE-15 found that rail rows could not navigate from that stage and routed them through a cancelable railopenrecord event that customerSummaryPanel handles; the conversation's own link was never clicked in a test and may do nothing in either surface.

## Done when

- A new e2e test drills into a seed record in the compact window, clicks View record, and asserts the page lands on that record's page (the URL path holds /lightning/r/ and the record page header shows the drilled record's name). A second test does the same with the conversation expanded into the rail. Both run on the mac and windows projects.
- First run both tests against agent-probe as it is now and record in the hand-back whether each passed or failed before any change.
- If either fails: handleViewRecord first dispatches a cancelable, bubbling, composed event named csopenrecord with detail { recordId } and navigates itself only when no listener called preventDefault. customerSummaryPanel listens for csopenrecord on the conversation it places (in both the compact window and the rail) and navigates with the same standard__recordPage call that handleRailOpenRecord uses; share one private method between the two handlers rather than duplicating it. If both pass on the first run, change no force-app file and say so.
- Jest: a conversation test that View record dispatches csopenrecord with the drilled recordId and does not navigate when the event is prevented, and navigates when it is not; a panel test that csopenrecord from the conversation calls Navigate with standard__recordPage and the recordId. Skip these only when no force-app file changed.
- Any changed bundle is validated with RunLocalTests and quick deployed to agent-probe with CONFIRM_PROD=1, deploying only the changed bundles (--source-dir). The full Playwright suite runs once after the deploy, and its summary line is in the hand-back.
- docs/research/fr2-panel-proof.md gains one dated line under the panel findings: what the first run showed and what changed (or that nothing needed to change).
- The rail component, the card component, any Apex class and the brand colours are unchanged. No capture is added. No Id, username, email or hostname appears in any committed file or test name.
