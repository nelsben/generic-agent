@IsTest
private class AccountBriefDealHistorySectionTest {
    private static String token() {
        return 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Account mkAccount() {
        Account a = new Account(Name = token() + ' Practice');
        insert a;
        return a;
    }

    @IsTest
    static void overCapShowsFiveNewestFirst() {
        Account a = mkAccount();
        String t = token();
        Date base = Date.today();
        List<Opportunity> opps = new List<Opportunity>();
        // Deals 1 to 4 are won with amounts 1000 to 4000; deals 5 to 7 are lost with no amount.
        // Inserted oldest first so the ordering rule, not insert order, decides the rows.
        for (Integer i = 7; i >= 1; i--) {
            opps.add(new Opportunity(
                AccountId = a.Id,
                Name = t + ' Deal ' + i,
                StageName = i <= 4 ? 'Closed Won' : 'Closed Lost',
                Amount = i <= 4 ? 1000 * i : null,
                CloseDate = base.addDays(-10 * i)
            ));
        }
        insert opps;

        AccountBriefSection s = AccountBriefDealHistorySection.build(a.Id);
        Assert.areEqual('deal_history', s.key);
        Assert.areEqual('Deal history', s.title);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(7, s.total);
        Assert.areEqual(5, s.shown);
        Assert.isTrue(s.total > AccountBriefDealHistorySection.ROW_CAP);
        Assert.isTrue(s.body.length() <= 1200);

        List<String> lines = s.body.split('\n');
        Assert.areEqual(7, lines.size());
        // 4 won / 3 lost, win rate 4/7 = 57%, average won deal (1000+2000+3000+4000)/4 = $2,500.
        Assert.areEqual('4 won / 3 lost all-time, win rate 57%, average won deal $2,500', lines[0]);
        Assert.areEqual(
            '- ' + t + ' Deal 1 — Won — $1,000 — closed ' + AccountBriefSection.fmtDate(base.addDays(-10)),
            lines[1]
        );
        Assert.areEqual(
            '- ' + t + ' Deal 4 — Won — $4,000 — closed ' + AccountBriefSection.fmtDate(base.addDays(-40)),
            lines[4]
        );
        Assert.areEqual(
            '- ' + t + ' Deal 5 — Lost — no amount — closed ' + AccountBriefSection.fmtDate(base.addDays(-50)),
            lines[5]
        );
        Assert.isFalse(s.body.contains(t + ' Deal 6'));
        Assert.areEqual('- …and 2 more not shown', lines[6]);
    }

    @IsTest
    static void lostOnlyShowsZeroPercentAndNaAverage() {
        Account a = mkAccount();
        String t = token();
        insert new List<Opportunity>{
            new Opportunity(AccountId = a.Id, Name = t + ' Lost A', StageName = 'Closed Lost', Amount = 100, CloseDate = Date.today().addDays(-5)),
            new Opportunity(AccountId = a.Id, Name = t + ' Lost B', StageName = 'Closed Lost', Amount = 200, CloseDate = Date.today().addDays(-6))
        };

        AccountBriefSection s = AccountBriefDealHistorySection.build(a.Id);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(2, s.total);
        Assert.areEqual(2, s.shown);
        List<String> lines = s.body.split('\n');
        Assert.areEqual('0 won / 2 lost all-time, win rate 0%, average won deal n/a', lines[0]);
        Assert.areEqual(3, lines.size());
    }

    @IsTest
    static void noClosedDealsIsEmpty() {
        Account a = mkAccount();
        insert new Opportunity(
            AccountId = a.Id,
            Name = token() + ' Still open',
            StageName = 'Prospecting',
            Amount = 900,
            CloseDate = Date.today().addDays(40)
        );

        AccountBriefSection s = AccountBriefDealHistorySection.build(a.Id);
        Assert.areEqual('deal_history', s.key);
        Assert.areEqual(AccountBriefSection.EMPTY, s.status);
        Assert.areEqual('No closed deals on this account.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);

        AccountBriefSection none = AccountBriefDealHistorySection.build(mkAccount().Id);
        Assert.areEqual(AccountBriefSection.EMPTY, none.status);
        Assert.areEqual(0, none.total);
    }
}
