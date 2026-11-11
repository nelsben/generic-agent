/**
 * Cross-session memory for the Account Brief.
 *
 * This is the one class in the Account Brief that writes data. The gather and reduce
 * steps stay read-only and DML-free; the Flow calls record() last, after the prompt
 * template calls. One Account_Brief_Session__c row exists per user and account (keyed by
 * Session_Key__c = 18-char User Id + '_' + 18-char Account Id). Turns_JSON__c holds a ring
 * buffer of the newest 10 turns, stored oldest first; history() returns them newest first.
 * Queries and the upsert run in system mode (the row is keyed to the running user, so a user only
 * ever reads and writes their own memory) so no field-level permission set is needed to use it.
 */
public with sharing class AccountBriefMemory {

    public static final Integer MAX_TURNS = 10;
    public static final Integer HEADLINE_MAX = 200;

    /** One remembered brief request, as shown in a session history. */
    public class Turn {
        @AuraEnabled public String at;
        @AuraEnabled public String status;
        @AuraEnabled public String question;
        @AuraEnabled public String headline;
    }

    /** Flow input for the Record Account Brief action. */
    public class Request {
        @InvocableVariable(label='Account Id' required=true)
        public Id accountId;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Question')
        public String question;
        @InvocableVariable(label='Answer')
        public String answer;
    }

    /** Flow entry point. A memory failure is logged and swallowed so it never breaks a brief. */
    @InvocableMethod(label='Record Account Brief' description='Saves this brief to the current user\'s memory for the account.')
    public static void recordFromFlow(List<Request> requests) {
        if (requests == null) {
            return;
        }
        for (Request r : requests) {
            if (r == null) {
                continue;
            }
            try {
                record(r.accountId, r.status, r.question, r.answer);
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'AccountBriefMemory.record failed: ' + e.getMessage());
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'AccountBriefMemory.record error: ' + e.getMessage());
            }
        }
    }

    /** Upserts the current user's row for the account and appends this turn (newest 10 kept). */
    public static void record(Id accountId, String status, String question, String answer) {
        if (accountId == null) {
            return;
        }
        Id userId = UserInfo.getUserId();
        String key = sessionKey(userId, accountId);

        Account_Brief_Session__c row = findRow(key);
        if (row == null) {
            row = new Account_Brief_Session__c(
                Session_Key__c = key,
                User__c = userId,
                Account__c = accountId,
                Brief_Count__c = 0
            );
        }

        List<Turn> turns = parseTurns(row.Turns_JSON__c);
        Turn t = new Turn();
        t.at = Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        t.status = status;
        t.question = clip(question, 255);
        t.headline = clip(firstLine(answer), HEADLINE_MAX);
        turns.add(t);
        while (turns.size() > MAX_TURNS) {
            turns.remove(0);
        }

        row.Turns_JSON__c = JSON.serialize(turns);
        row.Brief_Count__c = (row.Brief_Count__c == null ? 0 : row.Brief_Count__c) + 1;
        row.Last_Status__c = clip(status, 40);
        row.Last_Question__c = clip(question, 255);
        row.Last_Brief__c = clip(answer, 32768);
        row.Last_Activity__c = Datetime.now();

        Database.upsert(new List<Account_Brief_Session__c>{ row }, Account_Brief_Session__c.Session_Key__c, true, AccessLevel.SYSTEM_MODE);
    }

    /** The current user's turns for the account, newest first. Empty when there are none. */
    public static List<Turn> history(Id accountId) {
        List<Turn> result = new List<Turn>();
        if (accountId == null) {
            return result;
        }
        Account_Brief_Session__c row = findRow(sessionKey(UserInfo.getUserId(), accountId));
        if (row == null) {
            return result;
        }
        List<Turn> turns = parseTurns(row.Turns_JSON__c);
        for (Integer i = turns.size() - 1; i >= 0; i--) {
            result.add(turns[i]);
        }
        return result;
    }

    /** The current user's last brief text for the account, or null. */
    public static String lastBrief(Id accountId) {
        if (accountId == null) {
            return null;
        }
        Account_Brief_Session__c row = findRow(sessionKey(UserInfo.getUserId(), accountId));
        return row == null ? null : row.Last_Brief__c;
    }

    private static String sessionKey(Id userId, Id accountId) {
        return String.valueOf(userId) + '_' + String.valueOf(accountId);
    }

    private static Account_Brief_Session__c findRow(String key) {
        List<Account_Brief_Session__c> rows = [
            SELECT Id, Session_Key__c, Turns_JSON__c, Last_Brief__c, Brief_Count__c
            FROM Account_Brief_Session__c
            WHERE Session_Key__c = :key
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Turn> parseTurns(String json) {
        if (String.isBlank(json)) {
            return new List<Turn>();
        }
        try {
            return (List<Turn>) System.JSON.deserialize(json, List<Turn>.class);
        } catch (JSONException e) {
            System.debug(LoggingLevel.WARN, 'AccountBriefMemory: unreadable Turns_JSON__c, starting over: ' + e.getMessage());
            return new List<Turn>();
        }
    }

    private static String firstLine(String text) {
        if (text == null) {
            return null;
        }
        String trimmed = text.trim();
        Integer nl = trimmed.indexOf('\n');
        return (nl >= 0 ? trimmed.substring(0, nl) : trimmed).trim();
    }

    private static String clip(String text, Integer max) {
        if (text == null || text.length() <= max) {
            return text;
        }
        return text.substring(0, max);
    }
}
