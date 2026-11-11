---
id: BE-6
title: Cross-session memory: Account_Brief_Session__c per user and account, with a 10-turn history and an invocable to record each brief
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/objects/Account_Brief_Session__c/**, force-app/main/default/classes/AccountBriefMemory.cls, force-app/main/default/classes/AccountBriefMemory.cls-meta.xml, force-app/main/default/classes/AccountBriefMemoryTest.cls, force-app/main/default/classes/AccountBriefMemoryTest.cls-meta.xml]
forbid: [agents/**, .chassis-delegation.json, reference/**]
red_test: bash scripts/validate-org.sh (AccountBriefMemoryTest absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

Ben wants a consolidated view of requests across sessions: what the agent has told this user about this account over time. Each brief is saved per user and account, so a later session (agent or custom panel) can show the history and skip re-running a gather for an identical follow-up. This is the only component that writes data. The read-only gather and reduce stay DML-free, and the Flow calls this last, after the prompt template calls. Pattern source (another of Ben's projects): one record per user, a JSON ring buffer of turns capped at 10, and sticky account context that survives a new session.

## Done when

- force-app/main/default/objects/Account_Brief_Session__c/ defines a custom object (label 'Account Brief Session', name field AutoNumber `ABS-{0000}`, sharing model Private, deploymentStatus Deployed). Fields: `User__c` (Lookup(User)), `Account__c` (Lookup(Account), delete constraint SetNull), `Session_Key__c` (Text 80, External Id, Unique: the 18-char User Id + '_' + 18-char Account Id), `Turns_JSON__c` (Long Text 131072), `Last_Brief__c` (Long Text 32768), `Last_Status__c` (Text 40), `Last_Question__c` (Text 255), `Brief_Count__c` (Number 6,0, default 0) and `Last_Activity__c` (DateTime)
- force-app/main/default/classes/AccountBriefMemory.cls is `public with sharing`, and its header says it is the one class in the Account Brief that writes data. `public static void record(Id accountId, String status, String question, String answer)` upserts on Session_Key__c for UserInfo.getUserId(). It increments Brief_Count__c, sets the Last_* fields and appends `{"at": ISO datetime, "status", "question", "headline": first line of answer clipped to 200}` to Turns_JSON__c, keeping only the newest 10
- `public static List<Turn> history(Id accountId)` returns the current user's turns for that account, newest first (empty list when none). Turn is a public inner class with @AuraEnabled fields at, status, question and headline. `public static String lastBrief(Id accountId)` returns Last_Brief__c or null
- An @InvocableMethod (label 'Record Account Brief') wraps record() for Flow, with inputs accountId, status, question and answer and no outputs. It swallows and logs (System.debug) any DmlException so a memory failure never breaks a brief
- AccountBriefMemoryTest covers: first record creates one row; 12 records keep exactly 10 turns, newest first; two users on the same account get separate rows (use System.runAs with a test user); history() on an unknown account returns empty; the invocable path
- Both gates pass: `test` and `org`. Quote the `validate-org:` line in the hand-back

## Review

Brain review: accepted system mode for the memory reads and upsert. Every read and write is keyed to UserInfo.getUserId(), so a user only ever touches their own row. OPS-3's data-access permission set still grants object and field access for direct reads. Gate line: validate-org: pass (12 components, 7 tests). The base predates BE-1; merge re-runs the gates on the rebased tree.
