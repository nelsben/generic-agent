@IsTest
private class CustomerSummaryOpenDealsSectionTest {
    private static String token() {
        return 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Account mkAccount() {
        Account a = new Account(Name = token() + ' Practice');
        insert a;
        return a;
    }

    private static String ownerName() {
        return [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;
    }

    @IsTest
    static void overCapShowsFiveOrderedByCloseDate() {
        Account a = mkAccount();
        String t = token();
        Date base = Date.today();
        List<Opportunity> opps = new List<Opportunity>();
        // Inserted in reverse so the ordering rule, not insert order, decides the rows.
        // Deal 1 closed three days ago, so it is the overdue one.
        for (Integer i = 7; i >= 1; i--) {
            opps.add(new Opportunity(
                AccountId = a.Id,
                Name = t + ' Deal ' + i,
                StageName = 'Prospecting',
                Amount = 1000 * i,
                CloseDate = base.addDays(i * 10 - 13)
            ));
        }
        insert opps;

        CustomerSummarySection s = new CustomerSummaryOpenDealsSection().build(a.Id);
        Assert.areEqual('open_deals', s.key);
        Assert.areEqual('Open deals', s.title);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        Assert.areEqual(7, s.total);
        Assert.areEqual(5, s.shown);
        Assert.isTrue(s.total > CustomerSummaryOpenDealsSection.ROW_CAP);
        Assert.isTrue(CustomerSummarySection.withoutIds(s.body).length() <= 1200);

        List<String> lines = CustomerSummarySection.withoutIds(s.body).split('\n');
        Assert.areEqual(7, lines.size());
        Assert.areEqual('7 open, $28,000 total pipeline, 1 overdue', lines[0]);
        Assert.areEqual(
            '- ' + t + ' Deal 1 — Prospecting — $1,000 — closes ' + CustomerSummarySection.fmtDate(base.addDays(-3))
                + ' (OVERDUE) — owner ' + ownerName(),
            lines[1]
        );
        Assert.isTrue(lines[2].startsWith('- ' + t + ' Deal 2 — Prospecting — $2,000 — closes '));
        Assert.isTrue(lines[5].startsWith('- ' + t + ' Deal 5 — Prospecting — $5,000 — closes '));
        Assert.isFalse(s.body.contains(t + ' Deal 6'));
        Assert.areEqual('- …and 2 more not shown', lines[6]);
    }

    @IsTest
    static void contactsListPrimaryFirstWithRoles() {
        Account a = mkAccount();
        String t = token();
        Opportunity o = new Opportunity(
            AccountId = a.Id,
            Name = t + ' Deal',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert o;
        Contact primary = new Contact(AccountId = a.Id, LastName = t + ' Primary');
        Contact other = new Contact(AccountId = a.Id, LastName = t + ' Other');
        insert new List<Contact>{ primary, other };
        insert new List<OpportunityContactRole>{
            new OpportunityContactRole(OpportunityId = o.Id, ContactId = other.Id, IsPrimary = false),
            new OpportunityContactRole(OpportunityId = o.Id, ContactId = primary.Id, Role = 'Decision Maker', IsPrimary = true)
        };

        CustomerSummarySection s = new CustomerSummaryOpenDealsSection().build(a.Id);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        List<String> lines = CustomerSummarySection.withoutIds(s.body).split('\n');
        Assert.areEqual(4, lines.size());
        Assert.areEqual('1 open, $0 total pipeline, 0 overdue', lines[0]);
        Assert.areEqual(
            '- ' + t + ' Deal — Prospecting — no amount — closes ' + CustomerSummarySection.fmtDate(Date.today().addDays(30))
                + ' — owner ' + ownerName(),
            lines[1]
        );
        Assert.areEqual(' • ' + t + ' Primary (Decision Maker)', lines[2]);
        Assert.areEqual(' • ' + t + ' Other (no role)', lines[3]);
    }

    @IsTest
    static void noOpenDealsIsEmpty() {
        Account a = mkAccount();
        insert new Opportunity(
            AccountId = a.Id,
            Name = token() + ' Closed',
            StageName = 'Closed Won',
            Amount = 500,
            CloseDate = Date.today().addDays(-20)
        );

        CustomerSummarySection s = new CustomerSummaryOpenDealsSection().build(a.Id);
        Assert.areEqual('open_deals', s.key);
        Assert.areEqual(CustomerSummarySection.EMPTY, s.status);
        Assert.areEqual('No open deals on this account.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);

        CustomerSummarySection none = new CustomerSummaryOpenDealsSection().build(mkAccount().Id);
        Assert.areEqual(CustomerSummarySection.EMPTY, none.status);
        Assert.areEqual(0, none.total);
    }
}
