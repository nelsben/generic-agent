/**
 * CustomerSummaryActivitySection: the `activity` gather section of the Customer Summary.
 * Tasks with AccountId = the account and ActivityDate in the last 90 days (through today).
 * Line 1 counts them by TaskSubtype (Email, Call, everything else) plus how many of them are
 * open and past due; then the 5 most recent, newest first. Counts come from aggregate SOQL.
 * Read-only: no DML. Runs with sharing, deterministic Apex, no LLM, plain text only.
 * Every Task query runs in USER_MODE: the user's sharing, object and field
 * access all apply, so the brief and the model prompt never show a Task field the user can't read.
 * System mode is not needed here: a Standard User can read every Task field queried, and the
 * optional Type field is selected only when the user can read it. A user missing read access to
 * any other queried field gets an ERROR section (fail closed) rather than a brief built around it.
 * build() never throws: any failure comes back as an ERROR section.
 */
public with sharing class CustomerSummaryActivitySection implements CustomerSummarySource {
    public static final String KEY = 'activity';
    public static final String TITLE = 'Recent activity';
    public static final Integer CAP = 5;
    private static final Integer WINDOW_DAYS = 90;

    public String key() {
        return KEY;
    }

    public String title() {
        return TITLE;
    }

    public CustomerSummarySection build(Id accountId) {
        try {
            return buildInternal(accountId);
        } catch (Exception e) {
            return CustomerSummarySection.failed(KEY, TITLE, e);
        }
    }

    private static CustomerSummarySection buildInternal(Id accountId) {
        if (accountId == null) {
            throw new IllegalArgumentException('accountId is required');
        }
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = KEY;
        s.title = TITLE;

        Date today = Date.today();
        Date since = today.addDays(-WINDOW_DAYS);

        Integer emails = 0;
        Integer calls = 0;
        Integer other = 0;
        for (AggregateResult ar : [
            SELECT TaskSubtype st, COUNT(Id) cnt
            FROM Task
            WHERE AccountId = :accountId AND ActivityDate >= :since AND ActivityDate <= :today
            WITH USER_MODE
            GROUP BY TaskSubtype
        ]) {
            Integer n = Integer.valueOf(ar.get('cnt'));
            String st = (String) ar.get('st');
            if (st == 'Email') {
                emails += n;
            } else if (st == 'Call') {
                calls += n;
            } else {
                other += n;
            }
        }
        Integer total = emails + calls + other;
        if (total == 0) {
            s.status = CustomerSummarySection.EMPTY;
            s.body = 'No tasks in the last 90 days.';
            return s;
        }

        Integer overdue = [
            SELECT COUNT()
            FROM Task
            WHERE AccountId = :accountId AND IsClosed = false AND ActivityDate >= :since AND ActivityDate < :today
            WITH USER_MODE
        ];
        // Task.Type is not present in every org, and not every user can read it, so it is only selected
        // when the describe has it and the user can read it. Under USER_MODE an unreadable field would
        // fail the whole query.
        Schema.SObjectField typeField = Schema.SObjectType.Task.fields.getMap().get('type');
        Boolean hasType = typeField != null && typeField.getDescribe().isAccessible();
        String soql = 'SELECT Id, ActivityDate, TaskSubtype, ' + (hasType ? 'Type, ' : '') + 'Subject, Who.Name '
            + 'FROM Task WHERE AccountId = :accountId AND ActivityDate >= :since AND ActivityDate <= :today '
            + 'ORDER BY ActivityDate DESC, CreatedDate DESC, Id DESC LIMIT ' + CAP;
        List<Task> recent = (List<Task>) Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'accountId' => accountId, 'since' => since, 'today' => today },
            AccessLevel.USER_MODE
        );

        List<String> lines = new List<String>();
        lines.add('90d: ' + emails + ' emails, ' + calls + ' calls, ' + other + ' other; ' + overdue + ' open tasks overdue');
        for (Task t : recent) {
            String kind = !String.isBlank(t.TaskSubtype) ? t.TaskSubtype : (hasType && !String.isBlank((String) t.get('Type')) ? (String) t.get('Type') : 'Task');
            // The Task Id ends the line, for the panel's drill.
            lines.add(CustomerSummarySection.withId('- ' + CustomerSummarySection.fmtDate(t.ActivityDate)
                + ' — ' + CustomerSummarySection.clip(kind, 30)
                + ' — ' + CustomerSummarySection.clip(t.Subject, 120)
                + ' — ' + (t.Who == null ? 'n/a' : CustomerSummarySection.clip(t.Who.Name, 40)), t.Id));
        }

        s.status = CustomerSummarySection.OK;
        s.total = total;
        s.shown = recent.size();
        s.body = String.join(lines, '\n');
        return s;
    }
}
