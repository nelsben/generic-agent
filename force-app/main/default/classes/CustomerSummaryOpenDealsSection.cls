/**
 * CustomerSummaryOpenDealsSection: the 'Open deals' gather section of the Customer Summary.
 * Open Opportunities on the account, soonest close first, with who is involved on each deal.
 * Read-only: no DML. Runs with sharing, so a rep sees only the deals their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 */
public with sharing class CustomerSummaryOpenDealsSection implements CustomerSummarySource {
    @TestVisible private static final Integer ROW_CAP = 5;
    @TestVisible private static final Integer CONTACT_CAP = 3;
    @TestVisible private static final Integer BODY_MAX = 1200;
    private static final Integer FOOTER_RESERVE = 40;
    private static final String KEY = 'open_deals';
    private static final String TITLE = 'Open deals';

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

        Date asOfDate = Date.today();

        AggregateResult[] totals = [
            SELECT COUNT(Id) n, SUM(Amount) pipeline
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
            WITH USER_MODE
        ];
        Integer total = (Integer) totals[0].get('n');
        Decimal pipeline = (Decimal) totals[0].get('pipeline');
        if (pipeline == null) {
            pipeline = 0;
        }

        if (total == 0) {
            s.status = CustomerSummarySection.EMPTY;
            s.body = 'No open deals on this account.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        AggregateResult[] overdueAgg = [
            SELECT COUNT(Id) n
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false AND CloseDate < :asOfDate
            WITH USER_MODE
        ];
        Integer overdue = (Integer) overdueAgg[0].get('n');

        List<Opportunity> rows = [
            SELECT Id, Name, StageName, Amount, CloseDate, Owner.Name
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
            WITH USER_MODE
            ORDER BY CloseDate ASC NULLS LAST, Id
            LIMIT :ROW_CAP
        ];

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : rows) {
            oppIds.add(o.Id);
        }
        Map<Id, List<OpportunityContactRole>> rolesByOpp = new Map<Id, List<OpportunityContactRole>>();
        if (!oppIds.isEmpty()) {
            for (OpportunityContactRole r : [
                SELECT OpportunityId, ContactId, Role, IsPrimary, Contact.Name
                FROM OpportunityContactRole
                WHERE OpportunityId IN :oppIds
                WITH USER_MODE
                ORDER BY IsPrimary DESC, Id
            ]) {
                List<OpportunityContactRole> bucket = rolesByOpp.get(r.OpportunityId);
                if (bucket == null) {
                    bucket = new List<OpportunityContactRole>();
                    rolesByOpp.put(r.OpportunityId, bucket);
                }
                if (bucket.size() < CONTACT_CAP) {
                    bucket.add(r);
                }
            }
        }

        String body = total + ' open, ' + CustomerSummarySection.money(pipeline) + ' total pipeline, ' + overdue + ' overdue';
        Integer shown = 0;
        // The budget counts the text without record Ids: what the rep reads and the model sees.
        Integer used = body.length();
        for (Opportunity o : rows) {
            String block = dealBlock(o, asOfDate, rolesByOpp.get(o.Id));
            Integer cost = 1 + CustomerSummarySection.withoutIds(block).length();
            if (used + cost > BODY_MAX - FOOTER_RESERVE) {
                break;
            }
            body += '\n' + block;
            used += cost;
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

    /**
     * One deal line, then up to CONTACT_CAP indented contact lines, primary first. The deal line
     * ends with the Opportunity Id and each contact line with the Contact Id, for the panel's drill.
     */
    private static String dealBlock(Opportunity o, Date asOfDate, List<OpportunityContactRole> roles) {
        Boolean overdueDeal = o.CloseDate != null && o.CloseDate < asOfDate;
        String ownerName = o.Owner == null ? null : o.Owner.Name;
        String block = CustomerSummarySection.withId('- ' + CustomerSummarySection.clip(o.Name, 100)
            + ' — ' + CustomerSummarySection.clip(o.StageName, 60)
            + ' — ' + (o.Amount == null ? 'no amount' : CustomerSummarySection.money(o.Amount))
            + ' — closes ' + CustomerSummarySection.fmtDate(o.CloseDate)
            + (overdueDeal ? ' (OVERDUE)' : '')
            + ' — owner ' + CustomerSummarySection.clip(ownerName, 60), o.Id);
        if (roles != null) {
            for (OpportunityContactRole r : roles) {
                String contactName = r.Contact == null ? null : r.Contact.Name;
                String role = String.isBlank(r.Role) ? 'no role' : CustomerSummarySection.clip(r.Role, 60);
                block += '\n' + CustomerSummarySection.withId(' • ' + CustomerSummarySection.clip(contactName, 60) + ' (' + role + ')', r.ContactId);
            }
        }
        return block;
    }
}
