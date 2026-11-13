/**
 * CustomerSummaryHistory: the conversation history door (FR2, ledger F19 and F32).
 *
 * Lists a rep's past sessions for an account and reopens one. Sessions are Customer_Summary_Session__c rows,
 * written only by CustomerSummaryMemory (in system context, because reps have read-only access to the object).
 * Everything here reads in user mode: object, field and sharing access apply, and nothing is written.
 *
 * Two filters sit on top of sharing:
 * - Own-only (F32): a rep sees only the sessions they own, even one shared with them or one a role hierarchy
 *   would show. The filter is visibleOwnerId(), the one place a later brand or permission setting can widen it.
 * - Access re-checked on read (apex re-review N6): a session is returned only while the running user can still
 *   read its account. A session for an account the user has lost is hidden, never deleted.
 */
public with sharing class CustomerSummaryHistory {
    public static final Integer DEFAULT_LIMIT = 10;
    public static final Integer MAX_LIMIT = 50;
    /** Matches the panel's fixed failure line: raw exception text never reaches the panel. */
    @TestVisible private static final String ERROR_TEXT = 'I couldn\'t finish that right now. Try again in a minute.';

    /** One past session, without its turns. */
    public virtual class SessionSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String title;
        @AuraEnabled public Datetime startedAt;
        @AuraEnabled public Datetime lastActive;
        @AuraEnabled public Integer turnCount;
    }

    /** One session reopened: its summary fields and its kept turns, oldest first. */
    public class SessionDetail extends SessionSummary {
        @AuraEnabled public List<CustomerSummaryMemory.Turn> turns = new List<CustomerSummaryMemory.Turn>();
    }

    /**
     * The running user's sessions for the account, most recently active first.
     * @param accountId the account; null lists nothing
     * @param limitSize how many to list: null or below 1 means DEFAULT_LIMIT, and never more than MAX_LIMIT
     * @return title, start, last activity and turn count per session; empty when the account is not readable
     */
    @AuraEnabled
    public static List<SessionSummary> listSessions(Id accountId, Integer limitSize) {
        List<SessionSummary> out = new List<SessionSummary>();
        try {
            if (accountId == null || !readableAccounts(new Set<Id>{ accountId }).contains(accountId)) {
                return out;
            }
            Integer n = (limitSize == null || limitSize < 1) ? DEFAULT_LIMIT : Math.min(limitSize, MAX_LIMIT);
            Id ownerId = visibleOwnerId();
            for (Customer_Summary_Session__c row : [
                SELECT Id, Account__c, Title__c, Started__c, Last_Activity__c, Turn_Count__c
                FROM Customer_Summary_Session__c
                WHERE Account__c = :accountId AND OwnerId = :ownerId
                WITH USER_MODE
                ORDER BY Last_Activity__c DESC NULLS LAST, Id DESC
                LIMIT :n
            ]) {
                out.add(fill(new SessionSummary(), row));
            }
            return out;
        } catch (Exception e) {
            throw unexpected('listSessions', e);
        }
    }

    /**
     * One of the running user's sessions, with its turns in the order they happened.
     * @param sessionId a Customer_Summary_Session__c Id
     * @return the session, or null when it is not the user's own, does not exist, or its account is not readable
     */
    @AuraEnabled
    public static SessionDetail getSession(Id sessionId) {
        try {
            // No read access to Account at all hides every session before the session query names its account.
            if (sessionId == null || sessionId.getSObjectType() != Customer_Summary_Session__c.SObjectType || !accountsReadable()) {
                return null;
            }
            Id ownerId = visibleOwnerId();
            List<Customer_Summary_Session__c> rows = [
                SELECT Id, Account__c, Title__c, Started__c, Last_Activity__c, Turn_Count__c, Turns_JSON__c
                FROM Customer_Summary_Session__c
                WHERE Id = :sessionId AND OwnerId = :ownerId
                WITH USER_MODE
                LIMIT 1
            ];
            if (rows.isEmpty() || rows[0].Account__c == null
                    || !readableAccounts(new Set<Id>{ rows[0].Account__c }).contains(rows[0].Account__c)) {
                return null;
            }
            SessionDetail d = (SessionDetail) fill(new SessionDetail(), rows[0]);
            d.turns = CustomerSummaryMemory.parseTurns(rows[0].Turns_JSON__c);
            return d;
        } catch (Exception e) {
            throw unexpected('getSession', e);
        }
    }

    /**
     * The owner whose sessions a rep may see. F32 (Q7, unanswered): own-only until Ben decides, so this is the
     * running user. A later brand or permission setting widens history here, and only here.
     */
    private static Id visibleOwnerId() {
        return UserInfo.getUserId();
    }

    /**
     * The accounts among accountIds the running user can read now, in user mode (N6). Empty when the user has no
     * read access to Account at all.
     */
    public static Set<Id> readableAccounts(Set<Id> accountIds) {
        Set<Id> readable = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty() || !accountsReadable()) {
            return readable;
        }
        for (Account a : [SELECT Id FROM Account WHERE Id IN :accountIds WITH USER_MODE]) {
            readable.add(a.Id);
        }
        return readable;
    }

    private static Boolean accountsReadable() {
        return Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible();
    }

    private static SessionSummary fill(SessionSummary s, Customer_Summary_Session__c row) {
        s.id = row.Id;
        s.accountId = row.Account__c;
        s.title = row.Title__c;
        s.startedAt = row.Started__c;
        s.lastActive = row.Last_Activity__c;
        s.turnCount = row.Turn_Count__c == null ? 0 : row.Turn_Count__c.intValue();
        return s;
    }

    /** Logs the detail for the admin and hands the panel the fixed line. */
    private static AuraHandledException unexpected(String method, Exception e) {
        System.debug(LoggingLevel.ERROR, 'CustomerSummaryHistory.' + method + ': '
            + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
        AuraHandledException handled = new AuraHandledException(ERROR_TEXT);
        handled.setMessage(ERROR_TEXT);
        return handled;
    }
}
