/**
 * CustomerSummaryCallsSection: the `calls` gather section of the Customer Summary.
 * Recorded calls and meetings are Event records with AccountId = the account; call notes
 * live in Description. Shows the 5 most recent past Events (StartDateTime <= now, newest
 * first), each followed by an indented notes line when Description is not blank, then the
 * soonest future Event as a final `Next:` line. total counts past Events only. Description is
 * read in Apex (long text cannot be filtered in SOQL). Whole Event blocks are dropped from the
 * end, never cut mid-line, if the body would pass 1,200 characters.
 * Read-only: no DML. Runs with sharing, deterministic Apex, no LLM, plain text only.
 * build() never throws: any failure comes back as an ERROR section.
 */
public with sharing class CustomerSummaryCallsSection implements CustomerSummarySource {
    public static final String KEY = 'calls';
    public static final String TITLE = 'Calls & meetings';
    public static final Integer CAP = 5;
    public static final Integer MAX_BODY = 1200;

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

        DateTime nowDt = DateTime.now();
        Integer total = [SELECT COUNT() FROM Event WHERE AccountId = :accountId AND StartDateTime <= :nowDt WITH USER_MODE];
        List<Event> upcoming = [
            SELECT Id, StartDateTime, Subject
            FROM Event
            WHERE AccountId = :accountId AND StartDateTime > :nowDt
            WITH USER_MODE
            ORDER BY StartDateTime ASC, Id ASC
            LIMIT 1
        ];
        if (total == 0 && upcoming.isEmpty()) {
            s.status = CustomerSummarySection.EMPTY;
            s.body = 'No calls or meetings logged.';
            return s;
        }

        String nextLine = null;
        if (!upcoming.isEmpty()) {
            Event nx = upcoming[0];
            nextLine = CustomerSummarySection.withId('Next: ' + CustomerSummarySection.fmtDate(nx.StartDateTime.date())
                + ' — ' + CustomerSummarySection.clip(nx.Subject, 100), nx.Id);
        }

        // Notes and who attended are optional: a user who cannot read Description or WhoId still gets the
        // calls, and the last line says what was left out (N2 in docs/reviews/apex-review-2.md).
        Boolean hasNotes = CustomerSummarySection.canRead(Event.SObjectType, 'Description');
        Boolean hasWho = CustomerSummarySection.canRead(Event.SObjectType, 'WhoId');
        List<String> leftOut = new List<String>();
        if (!hasNotes) {
            leftOut.add('Call notes');
        }
        if (!hasWho) {
            leftOut.add('Who attended');
        }
        String leftOutLine = CustomerSummarySection.leftOutLine(leftOut);

        List<String> blocks = new List<String>();
        if (total > 0) {
            // The optional columns come only from the two checks above, never from input.
            List<Event> past = (List<Event>) Database.queryWithBinds(
                'SELECT Id, StartDateTime, Subject, DurationInMinutes' + (hasNotes ? ', Description' : '') + (hasWho ? ', Who.Name' : '')
                    + ' FROM Event WHERE AccountId = :accountId AND StartDateTime <= :nowDt'
                    + ' ORDER BY StartDateTime DESC, Id DESC LIMIT ' + CAP,
                new Map<String, Object>{ 'accountId' => accountId, 'nowDt' => nowDt },
                AccessLevel.USER_MODE
            );
            // Keep room for the Next and left-out lines, then add whole blocks while they fit. The budget counts
            // the text without record Ids: what the rep reads and the model sees.
            Integer budget = MAX_BODY - (nextLine == null ? 0 : CustomerSummarySection.withoutIds(nextLine).length() + 1)
                - (leftOutLine == null ? 0 : leftOutLine.length() + 1);
            Integer used = 0;
            for (Event ev : past) {
                // The Event Id ends the event's first line, for the panel's drill; the notes line carries none.
                String block = CustomerSummarySection.withId('- ' + CustomerSummarySection.fmtDate(ev.StartDateTime.date())
                    + ' — ' + CustomerSummarySection.clip(ev.Subject, 100)
                    + ' — ' + (ev.DurationInMinutes == null ? 'n/a' : String.valueOf(ev.DurationInMinutes)) + ' min'
                    + (hasWho ? ' — with ' + (ev.Who == null ? 'n/a' : CustomerSummarySection.clip(ev.Who.Name, 40)) : ''), ev.Id);
                if (hasNotes && !String.isBlank(ev.Description)) {
                    block += '\n notes: ' + CustomerSummarySection.clip(ev.Description, 300);
                }
                Integer cost = CustomerSummarySection.withoutIds(block).length() + (blocks.isEmpty() ? 0 : 1);
                if (used + cost > budget) {
                    break;
                }
                used += cost;
                blocks.add(block);
            }
        }

        List<String> lines = new List<String>();
        if (blocks.isEmpty()) {
            lines.add('No past calls or meetings logged.');
        } else {
            lines.addAll(blocks);
        }
        if (nextLine != null) {
            lines.add(nextLine);
        }
        if (leftOutLine != null) {
            lines.add(leftOutLine);
        }

        s.status = CustomerSummarySection.OK;
        s.total = total;
        s.shown = blocks.size();
        s.body = String.join(lines, '\n');
        return s;
    }
}
