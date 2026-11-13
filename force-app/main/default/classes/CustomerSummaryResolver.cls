/**
 * CustomerSummaryResolver: stage one of the strict two-stage gate (resolve, then brief).
 * Turns the rep's words or the open record into exactly one Account, or says why it could not.
 * Read-only: no DML. Runs with sharing, so a rep resolves only accounts they can already see.
 *
 * Resolution order:
 *   1. knownAccountId is an Account Id the user can see: resolved, no name search.
 *   2. accountName contains a 15- or 18-char Id starting 001 (an Id pasted back after
 *      disambiguation): the first one in the text the user can see wins. All pasted Ids are
 *      looked up in one query, however many there are.
 *   3. Exact case-insensitive Name match that is unique wins.
 *   4. Name LIKE %term% (bind variable): 1 hit RESOLVED, many AMBIGUOUS, none NOT_FOUND.
 * A query error (for example no read access to Account) is ERROR with fixed text, never NOT_FOUND:
 * "no account matches" would send an admin looking for missing data instead of missing access.
 */
public with sharing class CustomerSummaryResolver {
    public static final String RESOLVED = 'RESOLVED';
    public static final String AMBIGUOUS = 'AMBIGUOUS';
    public static final String NOT_FOUND = 'NOT_FOUND';
    public static final String ERROR = 'ERROR';

    @TestVisible private static final String ERROR_TEXT = 'I couldn\'t search accounts. You may not have access to them: ask your Salesforce admin to check your access.';

    @TestVisible private static final Integer MAX_CANDIDATES = 8;
    private static final Pattern ID_IN_TEXT = Pattern.compile('(?<![A-Za-z0-9])(001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?)(?![A-Za-z0-9])');

    public class Request {
        @InvocableVariable(label='Account Name' description='The account name or Id as the user wrote it, without the rest of the request. May contain a pasted 001 Id.')
        public String accountName;
        @InvocableVariable(label='Known Account Id' description='The Id of the open account record, when the user is on one. Skips the name search.')
        public String knownAccountId;
    }

    public class Response {
        @InvocableVariable(label='Status' description='RESOLVED, AMBIGUOUS, NOT_FOUND or ERROR')
        @AuraEnabled public String status;
        @InvocableVariable(label='Account Id' description='18-character Id of the resolved account; blank unless RESOLVED')
        @AuraEnabled public String accountId;
        @InvocableVariable(label='Account Name' description='Name of the resolved account; blank unless RESOLVED')
        @AuraEnabled public String accountName;
        @InvocableVariable(label='Message' description='User-facing text. Relay it verbatim.')
        @AuraEnabled public String message;
    }

    @InvocableMethod(
        label='Resolve Account for Brief'
        description='Resolves the user\'s words or the open record to one Account: RESOLVED with its Id, AMBIGUOUS with a candidate list, or NOT_FOUND.'
    )
    public static List<Response> resolveAccounts(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null) {
            return out;
        }
        for (Request r : requests) {
            out.add(r == null ? resolve(null, null) : resolve(r.accountName, r.knownAccountId));
        }
        return out;
    }

    public static Response resolve(String accountName, String knownAccountId) {
        try {
            return resolveChecked(accountName, knownAccountId);
        } catch (QueryException e) {
            // Most often the user can't read Account or its Name. That is an access problem, not a missing account.
            System.debug(LoggingLevel.WARN, 'CustomerSummaryResolver query failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return failed();
        }
    }

    private static Response resolveChecked(String accountName, String knownAccountId) {
        // 1. The open record.
        Account byKnown = visibleAccount(knownAccountId);
        if (byKnown != null) {
            return resolved(byKnown);
        }

        if (String.isBlank(accountName)) {
            return notFoundBlank();
        }
        String term = accountName.trim();

        // 2. An Id pasted inside the text.
        Account byPasted = firstVisiblePasted(term);
        if (byPasted != null) {
            return resolved(byPasted);
        }

        // 3. Exact name (SOQL equality is case-insensitive) when unique.
        List<Account> exact = [SELECT Id, Name FROM Account WHERE Name = :term WITH USER_MODE ORDER BY Name, Id LIMIT 2];
        if (exact.size() == 1) {
            return resolved(exact[0]);
        }

        // 4. Partial name. Escape LIKE wildcards in the term, then bind it.
        // The leading wildcard stays on purpose. This step is a contains-search: a rep who types
        // "Edge" for "The Edge Company" must find it, and a prefix-first search would resolve to
        // an account that merely starts with the term and hide the others (RESOLVED instead of
        // AMBIGUOUS). The cost is bounded: the exact-name step above is the indexed fast path,
        // the candidate query has LIMIT, and the count is one extra query per name search.
        String pattern = '%' + term.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%';
        Integer total = [SELECT COUNT() FROM Account WHERE Name LIKE :pattern WITH USER_MODE];
        if (total == 0) {
            return notFound(term);
        }
        List<Account> hits = partialHits(pattern);
        if (total == 1) {
            return resolved(hits[0]);
        }
        return ambiguous(term, hits, total);
    }

    /**
     * The candidate accounts for a name pattern, with their city. A user who can't read
     * Account.BillingCity still gets the candidates, without a city, instead of an error.
     */
    private static List<Account> partialHits(String pattern) {
        try {
            return [
                SELECT Id, Name, BillingCity FROM Account
                WHERE Name LIKE :pattern
                WITH USER_MODE
                ORDER BY Name, Id
                LIMIT :MAX_CANDIDATES
            ];
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryResolver city not readable: ' + e.getTypeName() + ': ' + e.getMessage());
            return [
                SELECT Id, Name FROM Account
                WHERE Name LIKE :pattern
                WITH USER_MODE
                ORDER BY Name, Id
                LIMIT :MAX_CANDIDATES
            ];
        }
    }

    /** The Account with this Id if the string is a valid Account Id the user can see, else null. */
    private static Account visibleAccount(String rawId) {
        Id parsed = accountId(rawId);
        if (parsed == null) {
            return null;
        }
        List<Account> found = [SELECT Id, Name FROM Account WHERE Id = :parsed WITH USER_MODE LIMIT 1];
        return found.isEmpty() ? null : found[0];
    }

    /** The first Account Id in the text that the user can see, or null. One query for all of them. */
    private static Account firstVisiblePasted(String text) {
        List<Id> pasted = new List<Id>();
        Matcher m = ID_IN_TEXT.matcher(text);
        while (m.find()) {
            Id parsed = accountId(m.group(1));
            if (parsed != null) {
                pasted.add(parsed);
            }
        }
        if (pasted.isEmpty()) {
            return null;
        }
        Map<Id, Account> visible = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :pasted WITH USER_MODE]
        );
        for (Id candidate : pasted) {
            if (visible.containsKey(candidate)) {
                return visible.get(candidate);
            }
        }
        return null;
    }

    /** The string as an Account Id, or null when it is not one. */
    private static Id accountId(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            Id parsed = Id.valueOf(rawId.trim());
            return parsed.getSObjectType() == Account.SObjectType ? parsed : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static Response resolved(Account a) {
        Response r = new Response();
        r.status = RESOLVED;
        r.accountId = String.valueOf(a.Id);
        r.accountName = a.Name;
        r.message = 'Resolved: ' + a.Name;
        return r;
    }

    private static Response ambiguous(String term, List<Account> hits, Integer total) {
        List<String> lines = new List<String>{ 'Several accounts match "' + term + '". Which one?' };
        for (Account a : hits) {
            String city = cityOf(a);
            lines.add(a.Name + ' — ' + city + ' — ' + String.valueOf(a.Id));
        }
        if (total > hits.size()) {
            lines.add('…and ' + (total - hits.size()) + ' more');
        }
        Response r = new Response();
        r.status = AMBIGUOUS;
        r.message = String.join(lines, '\n');
        return r;
    }

    /** The account's city, or 'no city' when it is blank or was not queried (no read access to it). */
    private static String cityOf(Account a) {
        try {
            return String.isBlank(a.BillingCity) ? 'no city' : a.BillingCity;
        } catch (SObjectException e) {
            return 'no city';
        }
    }

    private static Response notFound(String term) {
        Response r = new Response();
        r.status = NOT_FOUND;
        r.message = 'No account matches "' + term + '". Try a fuller or different account name.';
        return r;
    }

    /** A query failed: ERROR with the fixed text, no Id and no echo of what the user typed. */
    private static Response failed() {
        Response r = new Response();
        r.status = ERROR;
        r.message = ERROR_TEXT;
        return r;
    }

    private static Response notFoundBlank() {
        Response r = new Response();
        r.status = NOT_FOUND;
        r.message = 'Which account? Give me the account\'s name.';
        return r;
    }
}
