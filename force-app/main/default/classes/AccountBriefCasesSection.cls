/**
 * AccountBriefCasesSection: the 'Service health' gather section of the Account Brief.
 * A one-line tally of open, high priority and recently closed Cases, then the most urgent open Cases:
 * High, then Medium, then Low, then any other priority, oldest first within a priority.
 * Read-only: no DML. Runs with sharing, so a rep sees only the Cases their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 */
public with sharing class AccountBriefCasesSection implements AccountBriefSource {
    @TestVisible private static final Integer ROW_CAP = 5;
    @TestVisible private static final Integer BODY_MAX = 1200;
    private static final Integer CLOSED_WINDOW_DAYS = 90;
    private static final String KEY = 'cases';
    private static final String TITLE = 'Service health';
    private static final String PRIO_HIGH = 'High';
    private static final String PRIO_MEDIUM = 'Medium';
    private static final String PRIO_LOW = 'Low';
    private static final List<String> KNOWN_PRIORITIES = new List<String>{ PRIO_HIGH, PRIO_MEDIUM, PRIO_LOW };

    public String key() {
        return KEY;
    }

    public String title() {
        return TITLE;
    }

    public AccountBriefSection build(Id accountId) {
        try {
            return load(accountId);
        } catch (Exception e) {
            return AccountBriefSection.failed(KEY, TITLE, e);
        }
    }

    private static AccountBriefSection load(Id accountId) {
        AccountBriefSection s = new AccountBriefSection();
        s.key = KEY;
        s.title = TITLE;

        Datetime now = System.now();
        Datetime cutoff = now.addDays(-CLOSED_WINDOW_DAYS);

        // One grouped query gives the open count, the high count and the oldest open Case.
        Integer open = 0;
        Integer high = 0;
        Integer medium = 0;
        Integer low = 0;
        Datetime oldest = null;
        for (AggregateResult r : [
            SELECT Priority p, COUNT(Id) n, MIN(CreatedDate) oldest
            FROM Case
            WHERE AccountId = :accountId AND IsClosed = false
            WITH USER_MODE
            GROUP BY Priority
        ]) {
            Integer n = (Integer) r.get('n');
            String p = (String) r.get('p');
            open += n;
            if (p == PRIO_HIGH) {
                high = n;
            } else if (p == PRIO_MEDIUM) {
                medium = n;
            } else if (p == PRIO_LOW) {
                low = n;
            }
            Datetime groupOldest = (Datetime) r.get('oldest');
            if (oldest == null || groupOldest < oldest) {
                oldest = groupOldest;
            }
        }
        Integer other = open - high - medium - low;

        AggregateResult[] closedAgg = [
            SELECT COUNT(Id) n
            FROM Case
            WHERE AccountId = :accountId AND IsClosed = true AND ClosedDate >= :cutoff
            WITH USER_MODE
        ];
        Integer closed90 = (Integer) closedAgg[0].get('n');

        if (open == 0 && closed90 == 0) {
            AggregateResult[] anyAgg = [SELECT COUNT(Id) n FROM Case WHERE AccountId = :accountId WITH USER_MODE];
            if ((Integer) anyAgg[0].get('n') == 0) {
                s.status = AccountBriefSection.EMPTY;
                s.body = 'No cases on this account.';
                s.total = 0;
                s.shown = 0;
                return s;
            }
        }

        String oldestText = oldest == null ? 'n/a' : ageDays(oldest, now) + ' days';
        String body = open + ' open (' + high + ' high priority), ' + closed90
            + ' closed in last ' + CLOSED_WINDOW_DAYS + ' days, oldest open ' + oldestText;

        if (open == 0) {
            s.status = AccountBriefSection.OK;
            s.body = body + '\nNo open cases.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        // Priority order is applied here, not by ORDER BY Priority, which follows picklist order.
        // At most four bounded queries, each only when its bucket has rows and the cap is not yet met.
        List<Case> rows = new List<Case>();
        Integer room = ROW_CAP;
        if (high > 0) {
            rows.addAll([
                SELECT CaseNumber, Subject, Priority, Status, CreatedDate FROM Case
                WHERE AccountId = :accountId AND IsClosed = false AND Priority = :PRIO_HIGH
                WITH USER_MODE
                ORDER BY CreatedDate ASC, Id LIMIT :room
            ]);
            room = ROW_CAP - rows.size();
        }
        if (medium > 0 && room > 0) {
            rows.addAll([
                SELECT CaseNumber, Subject, Priority, Status, CreatedDate FROM Case
                WHERE AccountId = :accountId AND IsClosed = false AND Priority = :PRIO_MEDIUM
                WITH USER_MODE
                ORDER BY CreatedDate ASC, Id LIMIT :room
            ]);
            room = ROW_CAP - rows.size();
        }
        if (low > 0 && room > 0) {
            rows.addAll([
                SELECT CaseNumber, Subject, Priority, Status, CreatedDate FROM Case
                WHERE AccountId = :accountId AND IsClosed = false AND Priority = :PRIO_LOW
                WITH USER_MODE
                ORDER BY CreatedDate ASC, Id LIMIT :room
            ]);
            room = ROW_CAP - rows.size();
        }
        if (other > 0 && room > 0) {
            rows.addAll([
                SELECT CaseNumber, Subject, Priority, Status, CreatedDate FROM Case
                WHERE AccountId = :accountId AND IsClosed = false
                    AND (Priority = null OR Priority NOT IN :KNOWN_PRIORITIES)
                WITH USER_MODE
                ORDER BY CreatedDate ASC, Id LIMIT :room
            ]);
        }

        Integer shown = 0;
        for (Case c : rows) {
            body += '\n- ' + c.CaseNumber
                + ' — ' + AccountBriefSection.clip(c.Subject, 100)
                + ' — ' + AccountBriefSection.clip(c.Priority, 30)
                + ' — ' + AccountBriefSection.clip(c.Status, 40)
                + ' — open ' + ageDays(c.CreatedDate, now) + ' days';
            shown++;
        }
        if (shown < open) {
            body += '\n- …and ' + (open - shown) + ' more not shown';
        }

        s.status = AccountBriefSection.OK;
        s.body = body;
        s.total = open;
        s.shown = shown;
        return s;
    }

    /** Whole days from the Case's creation to now, by GMT calendar date. */
    private static Integer ageDays(Datetime created, Datetime now) {
        return created.dateGmt().daysBetween(now.dateGmt());
    }
}
