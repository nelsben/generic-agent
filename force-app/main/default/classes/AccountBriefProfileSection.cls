/**
 * AccountBriefProfileSection: the 'Account' gather section of the Account Brief.
 * One labelled line per profile fact for the account itself.
 * Read-only: no DML. Runs with sharing, so a rep sees only an account their record access permits.
 * Plain text, one fact per line. build() never throws: a failure returns status ERROR.
 */
public with sharing class AccountBriefProfileSection implements AccountBriefSource {
    @TestVisible private static final Integer BODY_MAX = 1200;
    private static final String KEY = 'profile';
    private static final String TITLE = 'Account';

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

        List<Account> rows = [
            SELECT Name, Type, Industry, Owner.Name, Parent.Name, AnnualRevenue, NumberOfEmployees,
                BillingCity, BillingState, BillingCountry, Website, CreatedDate, Description
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            s.status = AccountBriefSection.EMPTY;
            s.body = 'Account not found or not visible to you.';
            s.total = 0;
            s.shown = 0;
            return s;
        }

        Account a = rows[0];
        List<String> lines = new List<String>{
            'Name: ' + AccountBriefSection.clip(a.Name, 100),
            'Type: ' + AccountBriefSection.clip(a.Type, 60),
            'Industry: ' + AccountBriefSection.clip(a.Industry, 60),
            'Owner: ' + AccountBriefSection.clip(a.Owner == null ? null : a.Owner.Name, 80),
            'Parent: ' + AccountBriefSection.clip(a.Parent == null ? null : a.Parent.Name, 100),
            'Annual revenue: ' + (a.AnnualRevenue == null ? 'n/a' : AccountBriefSection.money(a.AnnualRevenue)),
            'Employees: ' + (a.NumberOfEmployees == null ? 'n/a' : String.valueOf(a.NumberOfEmployees)),
            'Location: ' + location(a),
            'Website: ' + AccountBriefSection.clip(a.Website, 100),
            'Account since: ' + AccountBriefSection.fmtDate(a.CreatedDate == null ? null : a.CreatedDate.date()),
            'Description: ' + AccountBriefSection.clip(a.Description, 300)
        };

        s.status = AccountBriefSection.OK;
        s.body = String.join(lines, '\n');
        s.total = 1;
        s.shown = 1;
        return s;
    }

    /** City, state and country joined by ', ', skipping blanks; 'n/a' when all are blank. */
    private static String location(Account a) {
        List<String> parts = new List<String>();
        for (String p : new List<String>{ a.BillingCity, a.BillingState, a.BillingCountry }) {
            if (String.isNotBlank(p)) {
                parts.add(AccountBriefSection.clip(p, 40));
            }
        }
        return parts.isEmpty() ? 'n/a' : String.join(parts, ', ');
    }
}
