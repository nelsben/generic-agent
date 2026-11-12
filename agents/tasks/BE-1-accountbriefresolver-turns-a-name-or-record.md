---
id: BE-1
title: AccountBriefResolver turns a name or record Id into one Account (RESOLVED / AMBIGUOUS / NOT_FOUND), plus the shared AccountBriefSection DTO
domain: backend
tier: standard
status: merged
scope: [force-app/main/default/classes/AccountBriefSection.cls, force-app/main/default/classes/AccountBriefSection.cls-meta.xml, force-app/main/default/classes/AccountBriefResolver.cls, force-app/main/default/classes/AccountBriefResolver.cls-meta.xml, force-app/main/default/classes/AccountBriefResolverTest.cls, force-app/main/default/classes/AccountBriefResolverTest.cls-meta.xml]
forbid: [agents/**, .chassis-delegation.json, scripts/**, reference/**]
red_test: bash scripts/validate-org.sh (AccountBriefResolverTest absent before; passes after)
gate: test, org
budget: 2-attempts
spend: 10
---
## Why

The Account Brief agent uses a strict two-stage gate: resolve the account, then brief it, and never brief without a resolved Id. This card builds the resolve stage and the DTO every gather section returns, so the gather cards can run in parallel against one contract. The architecture reference is local and confidential; restate its patterns and never copy its client names: <repo>/reference/agent-landscape-guide/guide.md. Read sections 2.1, 2.3, 4.2 and 5.1 first.

## Done when

- force-app/main/default/classes/AccountBriefSection.cls (+ -meta.xml, apiVersion 68.0, status Active) is a `public with sharing class`. Public fields: `String key`, `String title`, `String status` (one of the public static final String constants OK, EMPTY and ERROR on the class), `String body` (a plain-text block, never JSON and never null; EMPTY sections carry one human sentence such as 'No open cases.'), `Integer total` (rows that matched) and `Integer shown` (rows rendered after the cap). Also `public static String clip(String s, Integer maxChars)`, which returns 'n/a' for blank input, trims, collapses whitespace and newlines to single spaces, and cuts to maxChars with a trailing '…'. Plus a `public static String fmtDate(Date d)` returning yyyy-MM-dd or 'n/a'
- force-app/main/default/classes/AccountBriefResolver.cls (+ meta) is `public with sharing`, and its header comment says `Read-only: no DML.` It exposes one @InvocableMethod (label 'Resolve Account for Brief', description saying it resolves the user's words or the open record to one Account). Its inner Request class has @InvocableVariable `accountName` (String) and `knownAccountId` (String). Its inner Response class has `status` (RESOLVED, AMBIGUOUS or NOT_FOUND), `accountId` (String, 18-char), `accountName` and `message` (user-facing text the agent relays verbatim). The class also exposes `public static Response resolve(String accountName, String knownAccountId)` so the LWC controller can call it directly
- Resolution order: (1) a non-blank knownAccountId that is an Account Id the user can see resolves directly, with no name search. (2) If accountName contains a 15- or 18-char Id starting with 001 (a user pasting an Id back after disambiguation), that Id wins. (3) An exact case-insensitive Name match wins if it is unique. (4) Otherwise Name LIKE %term% using a bind variable on the trimmed term (no string-concatenated SOQL): 1 hit = RESOLVED, more = AMBIGUOUS, 0 = NOT_FOUND. Blank input = NOT_FOUND with message `Which account? Give me its name or open the account record.`
- RESOLVED message: `Resolved: <Name>`. AMBIGUOUS message: first line `Several accounts match "<term>". Which one?`, then at most 8 candidates ordered by Name, one per line as `<Name> — <BillingCity or 'no city'> — <18-char Id>`, then `…and <n> more` when more than 8 matched. NOT_FOUND message: `No account matches "<term>". Try the full name or open the account and ask again.`
- force-app/main/default/classes/AccountBriefResolverTest.cls (+ meta) covers: known Id; Id pasted inside text; an exact name winning over partial matches; AMBIGUOUS with 10 matches (asserts 8 lines plus `…and 2 more`); NOT_FOUND; blank input; and AccountBriefSection.clip/fmtDate. It creates its own data (no SeeAllData) and uses Assert.areEqual / Assert.isTrue
- Both gates pass: `test` and `org` (check-only deploy plus AccountBriefResolverTest in the experimental org). Quote the `validate-org:` line in the hand-back

## Review

Brain review: resolution order, bound LIKE with escaped wildcards, 8-candidate AMBIGUOUS list and fixed messages match the card. Gate line quoted: validate-org: pass (3 components, 11 tests).
