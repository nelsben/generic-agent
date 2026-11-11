/**
 * AccountBriefResolver: stage one of the strict two-stage gate (resolve, then brief).
 * Turns the rep's words or the open record into exactly one Account, or says why it could not.
 * Read-only: no DML. Runs with sharing, so a rep resolves only accounts they can already see.
 *
 * Resolution order:
 *   1. knownAccountId is an Account Id the user can see: resolved, no name search.
 *   2. accountName contains a 15- or 18-char Id starting 001 (an Id pasted back after
 *      disambiguation): that Id wins.
 *   3. Exact case-insensitive Name match that is unique wins.
 *   4. Name LIKE %term% (bind variable): 1 hit RESOLVED, many AMBIGUOUS, none NOT_FOUND.
 */
public with sharing class AccountBriefResolver {
    public static final String RESOLVED = 'RESOLVED';
    public static final String AMBIGUOUS = 'AMBIGUOUS';
    public static final String NOT_FOUND = 'NOT_FOUND';

    @TestVisible private static final Integer MAX_CANDIDATES = 8;
    private static final Pattern ID_IN_TEXT = Pattern.compile('(?<![A-Za-z0-9])(001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?)(?![A-Za-z0-9])');

    public class Request {
        @InvocableVariable(label='Account Name' description='The account name or words the user gave, copied character for character. May contain a pasted 001 Id.')
        public String accountName;
        @InvocableVariable(label='Known Account Id' description='The Id of the open account record, when the user is on one. Skips the name search.')
        public String knownAccountId;
    }

    public class Response {
        @InvocableVariable(label='Status' description='RESOLVED, AMBIGUOUS or NOT_FOUND')
        public String status;
        @InvocableVariable(label='Account Id' description='18-character Id of the resolved account; blank unless RESOLVED')
        public String accountId;
        @InvocableVariable(label='Account Name' description='Name of the resolved account; blank unless RESOLVED')
        public String accountName;
        @InvocableVariable(label='Message' description='User-facing text. Relay it verbatim.')
        public String message;
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
        Matcher m = ID_IN_TEXT.matcher(term);
        while (m.find()) {
            Account byPasted = visibleAccount(m.group(1));
            if (byPasted != null) {
                return resolved(byPasted);
            }
        }

        // 3. Exact name (SOQL equality is case-insensitive) when unique.
        List<Account> exact = [SELECT Id, Name FROM Account WHERE Name = :term ORDER BY Name, Id LIMIT 2];
        if (exact.size() == 1) {
            return resolved(exact[0]);
        }

        // 4. Partial name. Escape LIKE wildcards in the term, then bind it.
        String pattern = '%' + term.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%';
        Integer total = [SELECT COUNT() FROM Account WHERE Name LIKE :pattern];
        if (total == 0) {
            return notFound(term);
        }
        List<Account> hits = [
            SELECT Id, Name, BillingCity FROM Account
            WHERE Name LIKE :pattern
            ORDER BY Name, Id
            LIMIT :MAX_CANDIDATES
        ];
        if (total == 1) {
            return resolved(hits[0]);
        }
        return ambiguous(term, hits, total);
    }

    /** The Account with this Id if the string is a valid Account Id the user can see, else null. */
    private static Account visibleAccount(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }
        Id parsed;
        try {
            parsed = Id.valueOf(rawId.trim());
        } catch (Exception e) {
            return null;
        }
        if (parsed.getSObjectType() != Account.SObjectType) {
            return null;
        }
        List<Account> found = [SELECT Id, Name FROM Account WHERE Id = :parsed LIMIT 1];
        return found.isEmpty() ? null : found[0];
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
            String city = String.isBlank(a.BillingCity) ? 'no city' : a.BillingCity;
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

    private static Response notFound(String term) {
        Response r = new Response();
        r.status = NOT_FOUND;
        r.message = 'No account matches "' + term + '". Try the full name or open the account and ask again.';
        return r;
    }

    private static Response notFoundBlank() {
        Response r = new Response();
        r.status = NOT_FOUND;
        r.message = 'Which account? Give me its name or open the account record.';
        return r;
    }
}
