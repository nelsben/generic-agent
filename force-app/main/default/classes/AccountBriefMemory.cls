/**
 * Cross-session memory for the Account Brief.
 *
 * This is the one class in the Account Brief that writes data. The gather and reduce
 * steps stay read-only and DML-free; AccountBrief calls recordAll() last, after every model
 * call. There is no invocable entry point: only the engine writes memory. One Account_Brief_Session__c row exists per user and account (keyed by
 * Session_Key__c = 18-char User Id + '_' + 18-char Account Id). Turns_JSON__c holds a ring
 * buffer of the newest 10 turns, stored oldest first; history() returns them newest first.
 * Queries and writes run in system mode (the row is keyed to the running user, so a user only
 * ever reads and writes their own memory) so no field-level permission set is needed to use it.
 *
 * Writes do not race. The rows a write will change are read with FOR UPDATE, so two writers for the
 * same row take turns. A row that did not exist at read time is inserted, never upserted: if another
 * transaction created it first, the insert fails with DUPLICATE_VALUE and the whole write is redone
 * once from a fresh locked read, so neither turn is lost. Rows per user are capped at maxRowsPerUser:
 * after a write that created rows, the user's least recently active rows beyond the cap are deleted.
 */
public with sharing class AccountBriefMemory {

    public static final Integer MAX_TURNS = 10;
    public static final Integer HEADLINE_MAX = 200;
    /** Rows kept per user across accounts; the least recently active go first. */
    @TestVisible private static Integer maxRowsPerUser = 200;
    /** Test seam: rows inserted just before the first write, as if another transaction had committed them. */
    @TestVisible private static List<Account_Brief_Session__c> racingRows;

    /** One remembered brief request, as shown in a session history. */
    public class Turn {
        @AuraEnabled public String at;
        @AuraEnabled public String status;
        @AuraEnabled public String question;
        @AuraEnabled public String headline;
    }

    /** One brief turn to save: the input to recordAll. */
    public class Entry {
        public Id accountId;
        public String status;
        public String question;
        public String answer;

        public Entry(Id accountId, String status, String question, String answer) {
            this.accountId = accountId;
            this.status = status;
            this.question = question;
            this.answer = answer;
        }
    }

    /** Saves the current user's row for the account and appends this turn (newest 10 kept). */
    public static void record(Id accountId, String status, String question, String answer) {
        recordAll(new List<Entry>{ new Entry(accountId, status, question, answer) });
    }

    /**
     * Saves several turns with one locked query, one insert and one update. Turns for the same account go to the same row,
     * in list order. Null entries and entries without an accountId are skipped. Callers that also call
     * a model run this after their last callout, because a callout after DML fails.
     */
    public static void recordAll(List<Entry> entries) {
        Id userId = UserInfo.getUserId();
        Set<String> keys = new Set<String>();
        for (Entry e : entries == null ? new List<Entry>() : entries) {
            if (e != null && e.accountId != null) {
                keys.add(sessionKey(userId, e.accountId));
            }
        }
        if (keys.isEmpty()) {
            return;
        }
        try {
            write(entries, keys, userId);
        } catch (DmlException e) {
            if (e.getNumDml() == 0 || e.getDmlType(0) != System.StatusCode.DUPLICATE_VALUE) {
                throw e;
            }
            // Another transaction created a row we meant to insert. Nothing of ours was saved:
            // inserts run first, so start over from a fresh locked read and append to its row.
            write(entries, keys, userId);
        }
    }

    private static void write(List<Entry> entries, Set<String> keys, Id userId) {
        Map<String, Account_Brief_Session__c> rowsByKey = findRowsForUpdate(keys);
        List<Account_Brief_Session__c> toInsert = new List<Account_Brief_Session__c>();
        List<Account_Brief_Session__c> toUpdate = new List<Account_Brief_Session__c>();
        Set<String> saved = new Set<String>();
        for (Entry e : entries) {
            if (e == null || e.accountId == null) {
                continue;
            }
            String key = sessionKey(userId, e.accountId);
            Account_Brief_Session__c row = rowsByKey.get(key);
            Boolean isNew = row == null;
            if (isNew) {
                row = new Account_Brief_Session__c(
                    Session_Key__c = key,
                    User__c = userId,
                    Account__c = e.accountId,
                    Brief_Count__c = 0
                );
                rowsByKey.put(key, row);
            }
            addTurn(row, e);
            if (saved.add(key)) {
                if (isNew) {
                    toInsert.add(row);
                } else {
                    toUpdate.add(row);
                }
            }
        }

        if (racingRows != null) {
            List<Account_Brief_Session__c> rival = racingRows;
            racingRows = null;
            Database.insert(rival, true, AccessLevel.SYSTEM_MODE);
        }
        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, true, AccessLevel.SYSTEM_MODE);
            purgeOverflow(userId, saved);
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, true, AccessLevel.SYSTEM_MODE);
        }
    }

    /** Deletes the user's least recently active rows beyond maxRowsPerUser. The rows just written are never deleted. */
    private static void purgeOverflow(Id userId, Set<String> justSaved) {
        Integer keep = Math.max(0, maxRowsPerUser - justSaved.size());
        List<Account_Brief_Session__c> stale = [
            SELECT Id
            FROM Account_Brief_Session__c
            WHERE User__c = :userId AND Session_Key__c NOT IN :justSaved
            WITH SYSTEM_MODE
            ORDER BY Last_Activity__c DESC NULLS LAST, Id
            LIMIT 200 OFFSET :keep
        ];
        if (!stale.isEmpty()) {
            Database.delete(stale, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void addTurn(Account_Brief_Session__c row, Entry e) {
        List<Turn> turns = parseTurns(row.Turns_JSON__c);
        Turn t = new Turn();
        t.at = Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        t.status = e.status;
        t.question = clip(e.question, 255);
        t.headline = clip(firstLine(e.answer), HEADLINE_MAX);
        turns.add(t);
        while (turns.size() > MAX_TURNS) {
            turns.remove(0);
        }

        row.Turns_JSON__c = JSON.serialize(turns);
        row.Brief_Count__c = (row.Brief_Count__c == null ? 0 : row.Brief_Count__c) + 1;
        row.Last_Status__c = clip(e.status, 40);
        row.Last_Question__c = clip(e.question, 255);
        row.Last_Brief__c = clip(e.answer, 32768);
        row.Last_Activity__c = Datetime.now();
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
        return findRows(new Set<String>{ key }).get(key);
    }

    /** The rows for the keys, read without a lock: for history and lastBrief. */
    private static Map<String, Account_Brief_Session__c> findRows(Set<String> keys) {
        return toMap([
            SELECT Id, Session_Key__c, Turns_JSON__c, Last_Brief__c, Brief_Count__c
            FROM Account_Brief_Session__c
            WHERE Session_Key__c IN :keys
            WITH SYSTEM_MODE
        ]);
    }

    /** The rows for the keys, locked until the transaction ends: for read-modify-write. */
    private static Map<String, Account_Brief_Session__c> findRowsForUpdate(Set<String> keys) {
        return toMap([
            SELECT Id, Session_Key__c, Turns_JSON__c, Last_Brief__c, Brief_Count__c
            FROM Account_Brief_Session__c
            WHERE Session_Key__c IN :keys
            WITH SYSTEM_MODE
            FOR UPDATE
        ]);
    }

    private static Map<String, Account_Brief_Session__c> toMap(List<Account_Brief_Session__c> rows) {
        Map<String, Account_Brief_Session__c> rowsByKey = new Map<String, Account_Brief_Session__c>();
        for (Account_Brief_Session__c row : rows) {
            rowsByKey.put(row.Session_Key__c, row);
        }
        return rowsByKey;
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
