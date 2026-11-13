/**
 * CustomerSummaryDealHistorySection: the 'Deal history' gather section of the Customer Summary.
 * Closed Opportunities on the account, most recent close first, plus all-time won/lost figures.
 * Read-only: no DML. Runs with sharing, so a rep sees only the deals their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 */
public with sharing class CustomerSummaryDealHistorySection implements CustomerSummarySource {
    @TestVisible private static final Integer ROW_CAP = 5;
    @TestVisible private static final Integer BODY_MAX = 1200;
    private static final Integer FOOTER_RESERVE = 40;
    private static final String KEY = 'deal_history';
    private static final String TITLE = 'Deal history';

    public String key() {
        return KEY;
    }

    public String title() {
        return TITLE;
    }

    public CustomerSummarySection build(Id accountId) {
        try {
            return load(accountId);
        } catch (Exception e) {
            return CustomerSummarySection.failed(KEY, TITLE, e);
        }
    }

    private static CustomerSummarySection load(Id accountId) {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = KEY;
        s.title = TITLE;

        Integer won = 0;
        Integer lost = 0;
        Decimal avgWon = null;
        AggregateResult[] byOutcome = [
            SELECT IsWon, COUNT(Id) n, AVG(Amount) avgAmount
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = true
            WITH USER_MODE
            GROUP BY IsWon
        ];
        for (AggregateResult a : byOutcome) {
            Integer n = (Integer) a.get('n');
            if ((Boolean) a.get('IsWon')) {
                won = n;
                avgWon = (Decimal) a.get('avgAmount');
            } else {
                lost = n;
            }
        }
        Integer total = won + lost;

        if (total == 0) {
            s.status = CustomerSummarySection.EMPTY;
            s.body = 'No closed deals on this account.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        // Whole-number percent, rounded half up: floor((200 * won + total) / (2 * total)).
        Integer pct = (200 * won + total) / (2 * total);
        String summary = won + ' won / ' + lost + ' lost all-time, win rate ' + pct + '%, average won deal '
            + (won == 0 || avgWon == null ? 'n/a' : CustomerSummarySection.money(avgWon));

        List<Opportunity> rows = [
            SELECT Id, Name, Amount, CloseDate, IsWon
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = true
            WITH USER_MODE
            ORDER BY CloseDate DESC NULLS LAST, Id
            LIMIT :ROW_CAP
        ];

        String body = summary;
        Integer shown = 0;
        for (Opportunity o : rows) {
            String line = '- ' + CustomerSummarySection.clip(o.Name, 100)
                + ' — ' + (o.IsWon ? 'Won' : 'Lost')
                + ' — ' + (o.Amount == null ? 'no amount' : CustomerSummarySection.money(o.Amount))
                + ' — closed ' + CustomerSummarySection.fmtDate(o.CloseDate);
            // The budget counts the line without its Id: what the rep reads and the model sees.
            if (CustomerSummarySection.withoutIds(body).length() + 1 + line.length() > BODY_MAX - FOOTER_RESERVE) {
                break;
            }
            // The Opportunity Id ends the line, for the panel's drill.
            body += '\n' + CustomerSummarySection.withId(line, o.Id);
            shown++;
        }
        if (shown < total) {
            body += '\n- …and ' + (total - shown) + ' more not shown';
        }

        s.status = CustomerSummarySection.OK;
        s.body = body;
        s.total = total;
        s.shown = shown;
        return s;
    }
}
