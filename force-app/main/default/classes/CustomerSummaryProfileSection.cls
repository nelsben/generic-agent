/**
 * CustomerSummaryProfileSection: the 'Account' gather section of the Customer Summary.
 * One labelled line per profile fact for the account itself.
 * Read-only: no DML. Runs with sharing, so a rep sees only an account their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 * A field the user cannot read is left out with its line, and the last line names it; the section stays OK.
 */
public with sharing class CustomerSummaryProfileSection implements CustomerSummarySource {
    @TestVisible private static final Integer BODY_MAX = 1200;
    private static final String KEY = 'profile';
    private static final String TITLE = 'Account';

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

    /**
     * The optional Account fields, in line order, each with the plain words the left-out line uses for it.
     * Name is always selected: a user who can read Account can read its Name. A field the user cannot read
     * is not selected, its line is left out, and the last line names it (N2 in docs/reviews/apex-review-2.md).
     */
    private static final List<String> OPTIONAL_FIELDS = new List<String>{
        'Type', 'Industry', 'OwnerId', 'ParentId', 'AnnualRevenue', 'NumberOfEmployees',
        'BillingCity', 'BillingState', 'BillingCountry', 'Website', 'CreatedDate', 'Description'
    };
    private static final Map<String, String> FIELD_WORDS = new Map<String, String>{
        'Type' => 'Type', 'Industry' => 'Industry', 'OwnerId' => 'Owner', 'ParentId' => 'Parent',
        'AnnualRevenue' => 'Annual revenue', 'NumberOfEmployees' => 'Employees', 'BillingCity' => 'Billing city',
        'BillingState' => 'Billing state', 'BillingCountry' => 'Billing country', 'Website' => 'Website',
        'CreatedDate' => 'Account since', 'Description' => 'Description'
    };
    /** What the query selects for a field whose line shows a related record's name. */
    private static final Map<String, String> SELECT_AS = new Map<String, String>{
        'OwnerId' => 'Owner.Name', 'ParentId' => 'Parent.Name'
    };

    private static CustomerSummarySection load(Id accountId) {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = KEY;
        s.title = TITLE;

        Set<String> readable = new Set<String>();
        List<String> leftOut = new List<String>();
        List<String> columns = new List<String>{ 'Name' };
        for (String field : OPTIONAL_FIELDS) {
            if (CustomerSummarySection.canRead(Account.SObjectType, field)) {
                readable.add(field);
                columns.add(SELECT_AS.containsKey(field) ? SELECT_AS.get(field) : field);
            } else {
                leftOut.add(FIELD_WORDS.get(field));
            }
        }
        // The columns come only from the constant list above, never from input.
        List<Account> rows = (List<Account>) Database.queryWithBinds(
            'SELECT ' + String.join(columns, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1',
            new Map<String, Object>{ 'accountId' => accountId },
            AccessLevel.USER_MODE
        );
        if (rows.isEmpty()) {
            s.status = CustomerSummarySection.EMPTY;
            s.body = 'Account not found or not visible to you.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        s.status = CustomerSummarySection.OK;
        s.body = String.join(lines(rows[0], readable, leftOut), '\n');
        s.total = 1;
        s.shown = 1;
        return s;
    }

    /** One line per readable field, in the fixed order, then the left-out line when a field was left out. */
    private static List<String> lines(Account a, Set<String> readable, List<String> leftOut) {
        List<String> lines = new List<String>{ 'Name: ' + CustomerSummarySection.clip(a.Name, 100) };
        if (readable.contains('Type')) {
            lines.add('Type: ' + CustomerSummarySection.clip(a.Type, 60));
        }
        if (readable.contains('Industry')) {
            lines.add('Industry: ' + CustomerSummarySection.clip(a.Industry, 60));
        }
        if (readable.contains('OwnerId')) {
            lines.add('Owner: ' + CustomerSummarySection.clip(a.Owner == null ? null : a.Owner.Name, 80));
        }
        if (readable.contains('ParentId')) {
            lines.add('Parent: ' + CustomerSummarySection.clip(a.Parent == null ? null : a.Parent.Name, 100));
        }
        if (readable.contains('AnnualRevenue')) {
            lines.add('Annual revenue: ' + (a.AnnualRevenue == null ? 'n/a' : CustomerSummarySection.money(a.AnnualRevenue)));
        }
        if (readable.contains('NumberOfEmployees')) {
            lines.add('Employees: ' + (a.NumberOfEmployees == null ? 'n/a' : String.valueOf(a.NumberOfEmployees)));
        }
        if (readable.contains('BillingCity') || readable.contains('BillingState') || readable.contains('BillingCountry')) {
            lines.add('Location: ' + location(a, readable));
        }
        if (readable.contains('Website')) {
            lines.add('Website: ' + CustomerSummarySection.clip(a.Website, 100));
        }
        if (readable.contains('CreatedDate')) {
            lines.add('Account since: ' + CustomerSummarySection.fmtDate(a.CreatedDate == null ? null : a.CreatedDate.date()));
        }
        if (readable.contains('Description')) {
            lines.add('Description: ' + CustomerSummarySection.clip(a.Description, 300));
        }
        String leftOutLine = CustomerSummarySection.leftOutLine(leftOut);
        if (leftOutLine != null) {
            lines.add(leftOutLine);
        }
        return lines;
    }

    /** The readable parts of city, state and country joined by ', ', skipping blanks; 'n/a' when all are blank. */
    private static String location(Account a, Set<String> readable) {
        List<String> parts = new List<String>();
        for (String field : new List<String>{ 'BillingCity', 'BillingState', 'BillingCountry' }) {
            String p = readable.contains(field) ? (String) a.get(field) : null;
            if (String.isNotBlank(p)) {
                parts.add(CustomerSummarySection.clip(p, 40));
            }
        }
        return parts.isEmpty() ? 'n/a' : String.join(parts, ', ');
    }
}
