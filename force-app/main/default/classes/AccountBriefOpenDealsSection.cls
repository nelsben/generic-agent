/**
 * AccountBriefOpenDealsSection: the 'Open deals' gather section of the Account Brief.
 * Open Opportunities on the account, soonest close first, with who is involved on each deal.
 * Read-only: no DML. Runs with sharing, so a rep sees only the deals their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 */
public with sharing class AccountBriefOpenDealsSection implements AccountBriefSource {
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

    public AccountBriefSection build(Id accountId) {
        try {
            return load(accountId);
        } catch (Exception e) {
            AccountBriefSection s = new AccountBriefSection();
            s.key = KEY;
            s.title = TITLE;
            s.status = AccountBriefSection.ERROR;
            s.body = 'Couldn\'t load ' + TITLE + ' right now.';
            s.total = 0;
            s.shown = 0;
            return s;
        }
    }

    private static AccountBriefSection load(Id accountId) {
        AccountBriefSection s = new AccountBriefSection();
        s.key = KEY;
        s.title = TITLE;

        Date asOfDate = Date.today();

        AggregateResult[] totals = [
            SELECT COUNT(Id) n, SUM(Amount) pipeline
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
        ];
        Integer total = (Integer) totals[0].get('n');
        Decimal pipeline = (Decimal) totals[0].get('pipeline');
        if (pipeline == null) {
            pipeline = 0;
        }

        if (total == 0) {
            s.status = AccountBriefSection.EMPTY;
            s.body = 'No open deals on this account.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        AggregateResult[] overdueAgg = [
            SELECT COUNT(Id) n
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false AND CloseDate < :asOfDate
        ];
        Integer overdue = (Integer) overdueAgg[0].get('n');

        List<Opportunity> rows = [
            SELECT Id, Name, StageName, Amount, CloseDate, Owner.Name
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
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
                SELECT OpportunityId, Role, IsPrimary, Contact.Name
                FROM OpportunityContactRole
                WHERE OpportunityId IN :oppIds
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

        String body = total + ' open, ' + money(pipeline) + ' total pipeline, ' + overdue + ' overdue';
        Integer shown = 0;
        for (Opportunity o : rows) {
            String block = dealBlock(o, asOfDate, rolesByOpp.get(o.Id));
            if (body.length() + 1 + block.length() > BODY_MAX - FOOTER_RESERVE) {
                break;
            }
            body += '\n' + block;
            shown++;
        }
        if (shown < total) {
            body += '\n- …and ' + (total - shown) + ' more not shown';
        }

        s.status = AccountBriefSection.OK;
        s.body = body;
        s.total = total;
        s.shown = shown;
        return s;
    }

    /** One deal line, then up to CONTACT_CAP indented contact lines, primary first. */
    private static String dealBlock(Opportunity o, Date asOfDate, List<OpportunityContactRole> roles) {
        Boolean overdueDeal = o.CloseDate != null && o.CloseDate < asOfDate;
        String ownerName = o.Owner == null ? null : o.Owner.Name;
        String block = '- ' + AccountBriefSection.clip(o.Name, 100)
            + ' — ' + AccountBriefSection.clip(o.StageName, 60)
            + ' — ' + (o.Amount == null ? 'no amount' : money(o.Amount))
            + ' — closes ' + AccountBriefSection.fmtDate(o.CloseDate)
            + (overdueDeal ? ' (OVERDUE)' : '')
            + ' — owner ' + AccountBriefSection.clip(ownerName, 60);
        if (roles != null) {
            for (OpportunityContactRole r : roles) {
                String contactName = r.Contact == null ? null : r.Contact.Name;
                String role = String.isBlank(r.Role) ? 'no role' : AccountBriefSection.clip(r.Role, 60);
                block += '\n • ' + AccountBriefSection.clip(contactName, 60) + ' (' + role + ')';
            }
        }
        return block;
    }

    /** Whole currency units with grouping and a '$' prefix, e.g. $1,250,000. Rounds half up. */
    private static String money(Decimal amount) {
        Decimal rounded = amount.setScale(0, System.RoundingMode.HALF_UP);
        String digits = String.valueOf(rounded.abs().longValue());
        String grouped = '';
        Integer len = digits.length();
        for (Integer i = 0; i < len; i++) {
            if (i > 0 && Math.mod(len - i, 3) == 0) {
                grouped += ',';
            }
            grouped += digits.substring(i, i + 1);
        }
        return (rounded < 0 ? '-' : '') + '$' + grouped;
    }
}
