/**
 * CustomerSummaryContext: what the rail prefetches when it opens on an account (FR2, F29).
 * One cacheable call returns the open deals, the recent activity (tasks, calls, events, synced emails and
 * case comments), the open cases and the running user's last stored summary for the account.
 *
 * Runs as the signed-in user: the class is `with sharing` and every query runs WITH USER_MODE, so object,
 * field and record access all apply. Each list loads on its own: a list the user cannot read (no EmailMessage
 * access, say) comes back empty and its key is named in `unavailable`; the other lists still load.
 * The account is read first; an account the user cannot see gives an empty context.
 * Read-only: no DML. One call uses at most 8 SOQL queries, one per list plus the account check.
 * The DTO keeps record Ids so the rail can open records; no text field carries an Id.
 */
public with sharing class CustomerSummaryContext {
    public static final Integer DEAL_CAP = 5;
    public static final Integer ACTIVITY_CAP = 10;
    public static final Integer CASE_CAP = 5;
    public static final Integer TEXT_MAX = 140;
    public static final Integer SUMMARY_LINES = 3;
    /** Open cases ranked in Apex by priority; past this many open cases the oldest are ranked. */
    @TestVisible private static final Integer CASE_SCAN = 200;
    /** Tasks fetched before synced emails replace the tasks they were logged as. */
    private static final Integer TASK_SCAN = 20;

    public static final String DEALS = 'openDeals';
    public static final String TASKS = 'tasks';
    public static final String EVENTS = 'events';
    public static final String EMAILS = 'emails';
    public static final String CASE_COMMENTS = 'caseComments';
    public static final String CASES = 'openCases';
    public static final String SUMMARY = 'lastSummary';

    private static final String FAILED_TEXT = 'I couldn\'t load this account\'s context right now. Try again in a minute.';
    private static final List<String> PRIORITY_ORDER = new List<String>{ 'High', 'Medium', 'Low' };

    /** Test seam: list keys that fail as if the user could not read their object. */
    @TestVisible private static Set<String> unreadable = new Set<String>();

    /** Everything the rail shows for one account. Lists are never null. */
    public class Context {
        @AuraEnabled public List<Deal> openDeals = new List<Deal>();
        @AuraEnabled public List<Activity> recentActivity = new List<Activity>();
        @AuraEnabled public List<CaseRow> openCases = new List<CaseRow>();
        /** The running user's newest stored summary for the account, or null. */
        @AuraEnabled public LastSummary lastSummary;
        /** Keys of the parts that could not load for this user (DEALS, TASKS, EVENTS, EMAILS, CASE_COMMENTS, CASES, SUMMARY). */
        @AuraEnabled public List<String> unavailable = new List<String>();
    }

    /** One open Opportunity. */
    public class Deal {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date closeDate;
    }

    /** One recent item: kind is call, task, event, email or case_comment. */
    public class Activity implements Comparable {
        /** The record the rail opens: the task, event or email, or a case comment's case. */
        @AuraEnabled public Id recordId;
        @AuraEnabled public String kind;
        /** The subject, or an excerpt of the body when there is none; at most TEXT_MAX characters. */
        @AuraEnabled public String text;
        @AuraEnabled public Date activityDate;
        /** The contact or lead on a task or event, an email's sender, a case comment's author. */
        @AuraEnabled public String who;
        private Datetime sortKey;

        /** Newest first; ties go to the larger Id, so the order never depends on query order. */
        public Integer compareTo(Object other) {
            Activity that = (Activity) other;
            if (sortKey != that.sortKey) {
                return sortKey > that.sortKey ? -1 : 1;
            }
            String mine = String.valueOf(recordId);
            String theirs = String.valueOf(that.recordId);
            return mine == theirs ? 0 : (mine > theirs ? -1 : 1);
        }
    }

    /** One open Case. */
    public class CaseRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
    }

    /** The first lines of the running user's newest stored summary for the account. */
    public class LastSummary {
        @AuraEnabled public Datetime summaryDate;
        @AuraEnabled public String firstLines;
    }

    private class UnreadableException extends Exception {}

    /**
     * The rail's context for one account, in the running user's access.
     * @param accountId the Account the rail is open on; null or an account the user cannot see gives an empty context
     * @return the context; never null
     * @throws AuraHandledException with fixed text if something unexpected fails
     */
    @AuraEnabled(cacheable=true)
    public static Context getContext(Id accountId) {
        try {
            return load(accountId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerSummaryContext failed: ' + e.getTypeName() + ': ' + e.getMessage());
            throw new AuraHandledException(FAILED_TEXT);
        }
    }

    private static Context load(Id accountId) {
        Context ctx = new Context();
        if (accountId == null || !canSeeAccount(accountId)) {
            return ctx;
        }
        ctx.openDeals = openDeals(accountId, ctx);
        ctx.openCases = openCases(accountId, ctx);
        ctx.recentActivity = recentActivity(accountId, ctx);
        ctx.lastSummary = lastSummary(accountId, ctx);
        return ctx;
    }

    /** True when the user can read the account. No Account access at all reads as not visible. */
    private static Boolean canSeeAccount(Id accountId) {
        try {
            return ![SELECT Id FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1].isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    private static void check(String key) {
        if (unreadable.contains(key)) {
            throw new UnreadableException(key + ' is not readable');
        }
    }

    private static void markUnavailable(Context ctx, String key, Exception e) {
        ctx.unavailable.add(key);
        System.debug(LoggingLevel.WARN, 'CustomerSummaryContext left out ' + key + ': ' + e.getTypeName());
    }

    /** Open deals, soonest close first: the same rows as the Open deals section. */
    private static List<Deal> openDeals(Id accountId, Context ctx) {
        List<Deal> result = new List<Deal>();
        try {
            check(DEALS);
            for (Opportunity o : [
                SELECT Id, Name, StageName, Amount, CloseDate
                FROM Opportunity
                WHERE AccountId = :accountId AND IsClosed = false
                WITH USER_MODE
                ORDER BY CloseDate ASC NULLS LAST, Id
                LIMIT :DEAL_CAP
            ]) {
                Deal d = new Deal();
                d.recordId = o.Id;
                d.name = o.Name;
                d.stage = o.StageName;
                d.amount = o.Amount;
                d.closeDate = o.CloseDate;
                result.add(d);
            }
        } catch (Exception e) {
            markUnavailable(ctx, DEALS, e);
        }
        return result;
    }

    /** Open cases, most urgent first (High, Medium, Low, then any other), oldest first within a priority. */
    private static List<CaseRow> openCases(Id accountId, Context ctx) {
        List<CaseRow> result = new List<CaseRow>();
        try {
            check(CASES);
            List<Case> rows = [
                SELECT Id, CaseNumber, Subject, Status, Priority
                FROM Case
                WHERE AccountId = :accountId AND IsClosed = false
                WITH USER_MODE
                ORDER BY CreatedDate ASC, Id
                LIMIT :CASE_SCAN
            ];
            // Priority order is applied here, not by ORDER BY Priority, which follows picklist order.
            List<List<Case>> buckets = new List<List<Case>>();
            for (Integer i = 0; i <= PRIORITY_ORDER.size(); i++) {
                buckets.add(new List<Case>());
            }
            for (Case c : rows) {
                Integer rank = PRIORITY_ORDER.indexOf(c.Priority);
                buckets[rank < 0 ? PRIORITY_ORDER.size() : rank].add(c);
            }
            for (List<Case> bucket : buckets) {
                for (Case c : bucket) {
                    if (result.size() == CASE_CAP) {
                        return result;
                    }
                    CaseRow row = new CaseRow();
                    row.recordId = c.Id;
                    row.caseNumber = c.CaseNumber;
                    row.subject = c.Subject;
                    row.status = c.Status;
                    row.priority = c.Priority;
                    result.add(row);
                }
            }
        } catch (Exception e) {
            markUnavailable(ctx, CASES, e);
        }
        return result;
    }

    /**
     * The newest ACTIVITY_CAP items across tasks, events, emails and case comments. Task and Event AccountId is set
     * by the platform from the related record or the contact, so activity on the account's contacts is included.
     * A synced email is logged both as an EmailMessage and as a Task (EmailMessage.ActivityId); the email replaces
     * its task, so it shows once, with its body when it has no subject.
     */
    private static List<Activity> recentActivity(Id accountId, Context ctx) {
        Map<Id, Activity> taskItems = tasks(accountId, ctx);
        List<Activity> items = new List<Activity>();
        items.addAll(events(accountId, ctx));
        items.addAll(emails(accountId, taskItems, ctx));
        items.addAll(taskItems.values());
        items.addAll(caseComments(accountId, ctx));
        items.sort();
        List<Activity> newest = new List<Activity>();
        for (Integer i = 0; i < items.size() && i < ACTIVITY_CAP; i++) {
            newest.add(items[i]);
        }
        return newest;
    }

    /** Past and current tasks (ActivityDate through today), keyed by Task Id. A future due date is not activity. */
    private static Map<Id, Activity> tasks(Id accountId, Context ctx) {
        Map<Id, Activity> items = new Map<Id, Activity>();
        Date today = Date.today();
        try {
            check(TASKS);
            for (Task t : [
                SELECT Id, Subject, ActivityDate, TaskSubtype, CreatedDate, Who.Name
                FROM Task
                WHERE AccountId = :accountId AND ActivityDate <= :today
                WITH USER_MODE
                ORDER BY ActivityDate DESC, CreatedDate DESC, Id DESC
                LIMIT :TASK_SCAN
            ]) {
                String kind = t.TaskSubtype == 'Call' ? 'call' : (t.TaskSubtype == 'Email' || t.TaskSubtype == 'ListEmail' ? 'email' : 'task');
                // A task has a date, not a time: it sorts at the time of day it was created.
                Datetime at = Datetime.newInstance(t.ActivityDate, t.CreatedDate.time());
                items.put(t.Id, item(t.Id, kind, t.Subject, at, t.Who?.Name));
            }
        } catch (Exception e) {
            markUnavailable(ctx, TASKS, e);
        }
        return items;
    }

    /** Past events (started by now), newest first. */
    private static List<Activity> events(Id accountId, Context ctx) {
        List<Activity> items = new List<Activity>();
        Datetime nowDt = Datetime.now();
        try {
            check(EVENTS);
            for (Event ev : [
                SELECT Id, Subject, StartDateTime, Who.Name
                FROM Event
                WHERE AccountId = :accountId AND StartDateTime <= :nowDt
                WITH USER_MODE
                ORDER BY StartDateTime DESC, Id DESC
                LIMIT :ACTIVITY_CAP
            ]) {
                items.add(item(ev.Id, 'event', ev.Subject, ev.StartDateTime, ev.Who?.Name));
            }
        } catch (Exception e) {
            markUnavailable(ctx, EVENTS, e);
        }
        return items;
    }

    /** Emails related to the account, or logged as one of its tasks (which reaches emails with its contacts). */
    private static List<Activity> emails(Id accountId, Map<Id, Activity> taskItems, Context ctx) {
        List<Activity> items = new List<Activity>();
        Set<Id> taskIds = taskItems.keySet();
        try {
            check(EMAILS);
            for (EmailMessage em : [
                SELECT Id, Subject, TextBody, MessageDate, CreatedDate, FromName, ActivityId
                FROM EmailMessage
                WHERE RelatedToId = :accountId OR ActivityId IN :taskIds
                WITH USER_MODE
                ORDER BY MessageDate DESC NULLS LAST, Id DESC
                LIMIT :ACTIVITY_CAP
            ]) {
                if (em.ActivityId != null) {
                    taskItems.remove(em.ActivityId);
                }
                String text = String.isBlank(em.Subject) ? em.TextBody : em.Subject;
                Datetime at = em.MessageDate == null ? em.CreatedDate : em.MessageDate;
                items.add(item(em.Id, 'email', text, at, em.FromName));
            }
        } catch (Exception e) {
            markUnavailable(ctx, EMAILS, e);
        }
        return items;
    }

    /** Comments on the account's cases, newest first; each opens its case. */
    private static List<Activity> caseComments(Id accountId, Context ctx) {
        List<Activity> items = new List<Activity>();
        try {
            check(CASE_COMMENTS);
            for (CaseComment cc : [
                SELECT Id, ParentId, CommentBody, CreatedDate, CreatedById, CreatedBy.Name
                FROM CaseComment
                WHERE Parent.AccountId = :accountId
                WITH USER_MODE
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT :ACTIVITY_CAP
            ]) {
                items.add(item(cc.ParentId, 'case_comment', cc.CommentBody, cc.CreatedDate, commentAuthor(cc)));
            }
        } catch (Exception e) {
            markUnavailable(ctx, CASE_COMMENTS, e);
        }
        return items;
    }

    /**
     * The comment's author. The platform can return no CreatedBy row for a CaseComment (seen in Apex tests), and
     * a lookup of the user would be a ninth query, so the running user's own comments fall back to their name.
     */
    private static String commentAuthor(CaseComment cc) {
        if (cc.CreatedBy != null && String.isNotBlank(cc.CreatedBy.Name)) {
            return cc.CreatedBy.Name;
        }
        return cc.CreatedById == UserInfo.getUserId() ? UserInfo.getName() : null;
    }

    private static Activity item(Id recordId, String kind, String text, Datetime at, String who) {
        Activity a = new Activity();
        a.recordId = recordId;
        a.kind = kind;
        a.text = CustomerSummarySection.clip(text, TEXT_MAX);
        a.sortKey = at;
        a.activityDate = at?.date();
        a.who = who;
        return a;
    }

    /**
     * The running user's own stored summary for the account: the memory row keyed by user and account, read in
     * user mode (the data-access permission set grants read on it, and the row is the user's own).
     */
    private static LastSummary lastSummary(Id accountId, Context ctx) {
        Id userId = UserInfo.getUserId();
        String sessionKey = String.valueOf(userId) + '_' + String.valueOf(accountId);
        try {
            check(SUMMARY);
            List<Customer_Summary_Session__c> rows = [
                SELECT Last_Brief__c, Last_Activity__c
                FROM Customer_Summary_Session__c
                WHERE Session_Key__c = :sessionKey AND User__c = :userId
                WITH USER_MODE
                LIMIT 1
            ];
            if (rows.isEmpty() || String.isBlank(rows[0].Last_Brief__c)) {
                return null;
            }
            LastSummary s = new LastSummary();
            s.summaryDate = rows[0].Last_Activity__c;
            s.firstLines = firstLines(rows[0].Last_Brief__c);
            return s;
        } catch (Exception e) {
            markUnavailable(ctx, SUMMARY, e);
            return null;
        }
    }

    /** The first SUMMARY_LINES non-blank lines, trimmed, joined by newlines. */
    private static String firstLines(String text) {
        List<String> kept = new List<String>();
        for (String line : text.split('\n')) {
            if (String.isNotBlank(line)) {
                kept.add(line.trim());
                if (kept.size() == SUMMARY_LINES) {
                    break;
                }
            }
        }
        return String.join(kept, '\n');
    }
}
