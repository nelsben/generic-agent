/**
 * Conversation memory for the Customer Summary: the one class in the Customer Summary that writes data.
 *
 * The gather and reduce steps stay read-only and DML-free; CustomerSummary calls recordAll() last, after every
 * model call, and CustomerSummaryPanelController does the same for the explorer's turns. There is no invocable
 * entry point: only the engine and the panel write memory.
 *
 * One Customer_Summary_Session__c row is one session: one user, one account. The current session of a user and
 * an account holds Session_Key__c = 18-char User Id + '_' + 18-char Account Id. A turn more than
 * sessionTimeoutMinutes after the session's last activity ends it: the ended row is re-keyed to that key plus
 * '_' + its own Id, and a new row takes the plain key, carrying the last brief forward. Turns_JSON__c holds a
 * ring buffer of the session's newest 10 turns (summaries and explorer questions), stored oldest first;
 * history() returns the summaries newest first. Reads here and every write run in system mode, because reps
 * have read-only access to the object; the rows are always the running user's own. CustomerSummaryHistory
 * lists and reopens sessions in user mode.
 *
 * Writes do not race. The rows a write will change are read with FOR UPDATE, so two writers for the same row
 * take turns. Ended sessions are re-keyed before any insert, to a key fixed by the row's own Id, so doing it
 * twice changes nothing. A row that did not exist at read time is inserted, never upserted: if another
 * transaction created it first, the insert fails with DUPLICATE_VALUE before anything else of ours is saved
 * except re-keys, and the whole write is redone once from a fresh locked read, so no turn is lost. Rows per
 * user are capped at maxRowsPerUser: after a write that created rows, the user's least recently active rows
 * beyond the cap are deleted.
 */
public with sharing class CustomerSummaryMemory {

    public static final Integer MAX_TURNS = 10;
    public static final Integer HEADLINE_MAX = 200;
    public static final Integer TITLE_MAX = 80;
    /** Turn kinds: a Customer Summary brief, or a question answered by the explorer. */
    public static final String KIND_SUMMARY = 'summary';
    public static final String KIND_EXPLORER = 'explorer';
    /** A turn this long after the session's last activity starts a new session. */
    @TestVisible private static Integer sessionTimeoutMinutes = 30;
    /** Rows kept per user across accounts; the least recently active go first. */
    @TestVisible private static Integer maxRowsPerUser = 200;
    /** Test seam: rows inserted just before the first write, as if another transaction had committed them. */
    @TestVisible private static List<Customer_Summary_Session__c> racingRows;

    /** One remembered turn, as shown in a session history. kind is null on turns saved before BE-26: a summary. */
    public class Turn {
        @AuraEnabled public String at;
        @AuraEnabled public String status;
        @AuraEnabled public String question;
        @AuraEnabled public String headline;
        @AuraEnabled public String kind;
    }

    /** One turn to save: the input to recordAll. kind is KIND_SUMMARY unless given. */
    public class Entry {
        public Id accountId;
        public String status;
        public String question;
        public String answer;
        public String kind;

        public Entry(Id accountId, String status, String question, String answer) {
            this(accountId, status, question, answer, KIND_SUMMARY);
        }

        public Entry(Id accountId, String status, String question, String answer, String kind) {
            this.accountId = accountId;
            this.status = status;
            this.question = question;
            this.answer = answer;
            this.kind = kind == KIND_EXPLORER ? KIND_EXPLORER : KIND_SUMMARY;
        }
    }

    /** Saves a summary turn to the current user's session for the account (newest 10 turns kept). */
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
            // Another transaction created a row we meant to insert. Nothing of ours was saved but re-keys of
            // ended sessions, which are idempotent: start over from a fresh locked read and append to its row.
            write(entries, keys, userId);
        }
    }

    // system-context: the product's own session rows, written for the running user; reps have no write access to the object
    private static void write(List<Entry> entries, Set<String> keys, Id userId) {
        Map<String, Customer_Summary_Session__c> rowsByKey = findRowsForUpdate(keys);
        List<Customer_Summary_Session__c> ended = new List<Customer_Summary_Session__c>();
        List<Customer_Summary_Session__c> toInsert = new List<Customer_Summary_Session__c>();
        List<Customer_Summary_Session__c> toUpdate = new List<Customer_Summary_Session__c>();
        Set<String> saved = new Set<String>();
        Datetime cutoff = Datetime.now().addMinutes(-sessionTimeoutMinutes);
        for (Entry e : entries) {
            if (e == null || e.accountId == null) {
                continue;
            }
            String key = sessionKey(userId, e.accountId);
            Customer_Summary_Session__c row = rowsByKey.get(key);
            if (row != null && !saved.contains(key) && row.Last_Activity__c != null && row.Last_Activity__c < cutoff) {
                ended.add(endSession(row));
                row = startSession(key, userId, e.accountId, row);
                rowsByKey.put(key, row);
            } else if (row == null) {
                row = startSession(key, userId, e.accountId, null);
                rowsByKey.put(key, row);
            }
            addTurn(row, e);
            if (saved.add(key)) {
                if (row.Id == null) {
                    toInsert.add(row);
                } else {
                    toUpdate.add(row);
                }
            }
        }

        if (racingRows != null) {
            List<Customer_Summary_Session__c> rival = racingRows;
            racingRows = null;
            Database.insert(rival, true, AccessLevel.SYSTEM_MODE);
        }
        // Ended sessions give up the plain key before a new session takes it.
        if (!ended.isEmpty()) {
            Database.update(ended, true, AccessLevel.SYSTEM_MODE);
        }
        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, true, AccessLevel.SYSTEM_MODE);
            purgeOverflow(userId, saved);
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, true, AccessLevel.SYSTEM_MODE);
        }
    }

    /** The ended session, re-keyed to its plain key plus its own Id, with any field a pre-BE-26 row lacks filled in. */
    private static Customer_Summary_Session__c endSession(Customer_Summary_Session__c row) {
        Customer_Summary_Session__c done = new Customer_Summary_Session__c(
            Id = row.Id,
            Session_Key__c = row.Session_Key__c + '_' + String.valueOf(row.Id)
        );
        backfill(row, parseTurns(row.Turns_JSON__c));
        done.Title__c = row.Title__c;
        done.Started__c = row.Started__c;
        done.Turn_Count__c = row.Turn_Count__c;
        return done;
    }

    /** A new session row for the key. The last brief, its question and status carry over from the previous session. */
    private static Customer_Summary_Session__c startSession(String key, Id userId, Id accountId, Customer_Summary_Session__c previous) {
        return new Customer_Summary_Session__c(
            Session_Key__c = key,
            User__c = userId,
            Account__c = accountId,
            Brief_Count__c = 0,
            Turn_Count__c = 0,
            Last_Brief__c = previous?.Last_Brief__c,
            Last_Question__c = previous?.Last_Question__c,
            Last_Status__c = previous?.Last_Status__c
        );
    }

    /**
     * Fills title and start from the oldest stored turn when a row saved before BE-26 has none, and raises the turn
     * count to at least the turns kept.
     */
    private static void backfill(Customer_Summary_Session__c row, List<Turn> turns) {
        Turn first = turns.isEmpty() ? null : turns[0];
        if (row.Title__c == null && first != null) {
            row.Title__c = title(first.question, first.kind);
        }
        if (row.Started__c == null && first != null && first.at != null) {
            try {
                row.Started__c = (Datetime) JSON.deserialize('"' + first.at + '"', Datetime.class);
            } catch (JSONException e) {
                row.Started__c = row.Last_Activity__c;
            }
        }
        if (row.Turn_Count__c == null || row.Turn_Count__c < turns.size()) {
            row.Turn_Count__c = turns.size();
        }
    }

    /** Deletes the user's least recently active rows beyond maxRowsPerUser. The rows just written are never deleted. */
    // system-context: deletes the running user's own old session rows; reps have no delete access to the object
    private static void purgeOverflow(Id userId, Set<String> justSaved) {
        Integer keep = Math.max(0, maxRowsPerUser - justSaved.size());
        List<Customer_Summary_Session__c> stale = [
            SELECT Id
            FROM Customer_Summary_Session__c
            WHERE User__c = :userId AND Session_Key__c NOT IN :justSaved
            WITH SYSTEM_MODE
            ORDER BY Last_Activity__c DESC NULLS LAST, Id
            LIMIT 200 OFFSET :keep
        ];
        if (!stale.isEmpty()) {
            Database.delete(stale, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void addTurn(Customer_Summary_Session__c row, Entry e) {
        Datetime now = Datetime.now();
        List<Turn> turns = parseTurns(row.Turns_JSON__c);
        if (row.Id != null) {
            backfill(row, turns);
        }
        Turn t = new Turn();
        t.at = now.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        t.status = e.status;
        t.question = clip(e.question, 255);
        t.headline = clip(firstLine(e.answer), HEADLINE_MAX);
        t.kind = e.kind;
        turns.add(t);
        while (turns.size() > MAX_TURNS) {
            turns.remove(0);
        }

        row.Turns_JSON__c = JSON.serialize(turns);
        row.Turn_Count__c = (row.Turn_Count__c == null ? 0 : row.Turn_Count__c) + 1;
        if (row.Started__c == null) {
            row.Started__c = now;
        }
        if (row.Title__c == null) {
            row.Title__c = title(e.question, e.kind);
        }
        row.Last_Activity__c = now;
        // The Last_* brief fields and Brief_Count__c belong to summaries; an explorer answer never replaces the brief.
        if (e.kind == KIND_SUMMARY) {
            row.Brief_Count__c = (row.Brief_Count__c == null ? 0 : row.Brief_Count__c) + 1;
            row.Last_Status__c = clip(e.status, 40);
            row.Last_Question__c = clip(e.question, 255);
            row.Last_Brief__c = clip(e.answer, 32768);
        }
    }

    /** The first question trimmed to TITLE_MAX characters; a summary asked without one is titled "Summary". */
    private static String title(String question, String kind) {
        if (String.isBlank(question)) {
            return kind == KIND_EXPLORER ? 'Question' : 'Summary';
        }
        return clip(question.normalizeSpace(), TITLE_MAX).trim();
    }

    /**
     * The current user's summary turns for the account across their newest MAX_TURNS sessions, newest first,
     * at most MAX_TURNS. Empty when there are none, or when the user can no longer read the account (N6).
     */
    public static List<Turn> history(Id accountId) {
        List<Turn> result = new List<Turn>();
        if (accountId == null || !CustomerSummaryHistory.readableAccounts(new Set<Id>{ accountId }).contains(accountId)) {
            return result;
        }
        for (Customer_Summary_Session__c row : recentRows(UserInfo.getUserId(), accountId)) {
            List<Turn> turns = parseTurns(row.Turns_JSON__c);
            for (Integer i = turns.size() - 1; i >= 0 && result.size() < MAX_TURNS; i--) {
                if (turns[i].kind == null || turns[i].kind == KIND_SUMMARY) {
                    result.add(turns[i]);
                }
            }
        }
        return result;
    }

    /** The user's newest sessions for the account, most recently active first. */
    // system-context: reads the running user's own session rows; history() re-checks the account in user mode first
    private static List<Customer_Summary_Session__c> recentRows(Id userId, Id accountId) {
        return [
            SELECT Id, Turns_JSON__c
            FROM Customer_Summary_Session__c
            WHERE User__c = :userId AND Account__c = :accountId
            WITH SYSTEM_MODE
            ORDER BY Last_Activity__c DESC NULLS LAST, Id DESC
            LIMIT :MAX_TURNS
        ];
    }

    /** The current user's last brief text for the account, or null. */
    public static String lastBrief(Id accountId) {
        if (accountId == null) {
            return null;
        }
        Customer_Summary_Session__c row = findRow(sessionKey(UserInfo.getUserId(), accountId));
        return row == null ? null : row.Last_Brief__c;
    }

    private static String sessionKey(Id userId, Id accountId) {
        return String.valueOf(userId) + '_' + String.valueOf(accountId);
    }

    private static Customer_Summary_Session__c findRow(String key) {
        return findRows(new Set<String>{ key }).get(key);
    }

    /** The rows for the keys, read without a lock: for lastBrief. */
    // system-context: reads the running user's own session rows; reps have no access to the object
    private static Map<String, Customer_Summary_Session__c> findRows(Set<String> keys) {
        return toMap([
            SELECT Id, Session_Key__c, Turns_JSON__c, Last_Brief__c, Brief_Count__c
            FROM Customer_Summary_Session__c
            WHERE Session_Key__c IN :keys
            WITH SYSTEM_MODE
        ]);
    }

    /** The rows for the keys, locked until the transaction ends: for read-modify-write. */
    // system-context: locks the running user's own session rows for a write; reps have no access to the object
    private static Map<String, Customer_Summary_Session__c> findRowsForUpdate(Set<String> keys) {
        return toMap([
            SELECT Id, Session_Key__c, Turns_JSON__c, Last_Brief__c, Last_Question__c, Last_Status__c, Brief_Count__c,
                   Turn_Count__c, Title__c, Started__c, Last_Activity__c
            FROM Customer_Summary_Session__c
            WHERE Session_Key__c IN :keys
            WITH SYSTEM_MODE
            FOR UPDATE
        ]);
    }

    private static Map<String, Customer_Summary_Session__c> toMap(List<Customer_Summary_Session__c> rows) {
        Map<String, Customer_Summary_Session__c> rowsByKey = new Map<String, Customer_Summary_Session__c>();
        for (Customer_Summary_Session__c row : rows) {
            rowsByKey.put(row.Session_Key__c, row);
        }
        return rowsByKey;
    }

    /** The stored turns, oldest first; empty for a blank or unreadable value. */
    public static List<Turn> parseTurns(String json) {
        if (String.isBlank(json)) {
            return new List<Turn>();
        }
        try {
            return (List<Turn>) System.JSON.deserialize(json, List<Turn>.class);
        } catch (JSONException e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryMemory: unreadable Turns_JSON__c, starting over: ' + e.getMessage());
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
