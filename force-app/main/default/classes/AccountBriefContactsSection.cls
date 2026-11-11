/**
 * AccountBriefContactsSection: the `contacts` gather section of the Account Brief.
 * Up to 6 Contacts on the account, busiest first: 90-day touch count DESC, then
 * LastActivityDate DESC NULLS LAST, then Name. A touch is a Task or Event whose WhoId is
 * the Contact and whose ActivityDate falls in the last 90 days (through today). Touches are
 * counted with two aggregate queries grouped by WhoId, never per Contact.
 * Read-only: no DML. Runs with sharing, deterministic Apex, no LLM, plain text only.
 * build() never throws: any failure comes back as an ERROR section.
 */
public with sharing class AccountBriefContactsSection implements AccountBriefSource {
    public static final String KEY = 'contacts';
    public static final String TITLE = 'Contacts';
    public static final Integer CAP = 6;
    /** Contacts scanned for touch counts; most recently active first so busy ones are never cut. */
    private static final Integer SCAN_LIMIT = 2000;
    private static final Integer WINDOW_DAYS = 90;

    private class Row implements Comparable {
        Contact c;
        Integer touches = 0;
        Integer emails = 0;
        Integer calls = 0;
        Integer meetings = 0;

        public Integer compareTo(Object other) {
            Row o = (Row) other;
            if (touches != o.touches) {
                return touches > o.touches ? -1 : 1;
            }
            Date a = c.LastActivityDate;
            Date b = o.c.LastActivityDate;
            if (a != b) {
                if (a == null) {
                    return 1;
                }
                if (b == null) {
                    return -1;
                }
                return a > b ? -1 : 1;
            }
            Integer byName = c.Name.compareTo(o.c.Name);
            if (byName != 0) {
                return byName;
            }
            return String.valueOf(c.Id).compareTo(String.valueOf(o.c.Id));
        }
    }

    public String key() {
        return KEY;
    }

    public String title() {
        return TITLE;
    }

    public AccountBriefSection build(Id accountId) {
        try {
            return buildInternal(accountId);
        } catch (Exception e) {
            AccountBriefSection err = new AccountBriefSection();
            err.key = KEY;
            err.title = TITLE;
            err.status = AccountBriefSection.ERROR;
            err.body = 'Couldn\'t load ' + TITLE + ' right now.';
            return err;
        }
    }

    private static AccountBriefSection buildInternal(Id accountId) {
        if (accountId == null) {
            throw new IllegalArgumentException('accountId is required');
        }
        AccountBriefSection s = new AccountBriefSection();
        s.key = KEY;
        s.title = TITLE;

        Integer total = [SELECT COUNT() FROM Contact WHERE AccountId = :accountId];
        if (total == 0) {
            s.status = AccountBriefSection.EMPTY;
            s.body = 'No contacts on this account.';
            return s;
        }

        List<Contact> contacts = [
            SELECT Id, Name, Title, LastActivityDate
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY LastActivityDate DESC NULLS LAST, Name
            LIMIT :SCAN_LIMIT
        ];
        Map<Id, Row> rows = new Map<Id, Row>();
        for (Contact c : contacts) {
            Row r = new Row();
            r.c = c;
            rows.put(c.Id, r);
        }
        Set<Id> ids = rows.keySet();
        Date today = Date.today();
        Date since = today.addDays(-WINDOW_DAYS);

        for (AggregateResult ar : [
            SELECT WhoId w, TaskSubtype st, COUNT(Id) cnt
            FROM Task
            WHERE WhoId IN :ids AND ActivityDate >= :since AND ActivityDate <= :today
            GROUP BY WhoId, TaskSubtype
        ]) {
            Row r = rows.get((Id) ar.get('w'));
            Integer n = Integer.valueOf(ar.get('cnt'));
            String st = (String) ar.get('st');
            r.touches += n;
            if (st == 'Email') {
                r.emails += n;
            } else if (st == 'Call') {
                r.calls += n;
            }
        }
        for (AggregateResult ar : [
            SELECT WhoId w, COUNT(Id) cnt
            FROM Event
            WHERE WhoId IN :ids AND ActivityDate >= :since AND ActivityDate <= :today
            GROUP BY WhoId
        ]) {
            Row r = rows.get((Id) ar.get('w'));
            Integer n = Integer.valueOf(ar.get('cnt'));
            r.touches += n;
            r.meetings += n;
        }

        List<Row> sorted = rows.values();
        sorted.sort();

        List<String> lines = new List<String>();
        for (Integer i = 0; i < sorted.size() && i < CAP; i++) {
            Row r = sorted[i];
            String title = String.isBlank(r.c.Title) ? 'no title' : AccountBriefSection.clip(r.c.Title, 50);
            String line = '- ' + AccountBriefSection.clip(r.c.Name, 40)
                + ' — ' + title
                + ' — 90d: ' + r.emails + ' emails, ' + r.calls + ' calls, ' + r.meetings + ' meetings'
                + ' — last touch ' + (r.c.LastActivityDate == null ? 'none' : AccountBriefSection.fmtDate(r.c.LastActivityDate));
            if (r.touches == 0) {
                line += ' (quiet)';
            }
            lines.add(line);
        }

        s.status = AccountBriefSection.OK;
        s.total = total;
        s.shown = lines.size();
        s.body = String.join(lines, '\n');
        return s;
    }
}
