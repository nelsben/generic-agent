@IsTest
private class ExploreQueryTest {
    @TestSetup
    static void data() {
        Account acme = new Account(Name = 'Query Acme', NumberOfEmployees = 40);
        insert acme;
        insert new List<Opportunity>{
            new Opportunity(AccountId = acme.Id, Name = 'Q One', StageName = 'Closed Won', Amount = 1000, CloseDate = Date.today(), NextStep = 'Call'),
            new Opportunity(AccountId = acme.Id, Name = 'Q Two', StageName = 'Prospecting', Amount = 2000, CloseDate = Date.today()),
            new Opportunity(AccountId = acme.Id, Name = 'Q Three', StageName = 'Closed Won', Amount = 3000, CloseDate = Date.today()),
            new Opportunity(Name = 'Q Orphan', StageName = 'Prospecting', Amount = 500, CloseDate = Date.today().addYears(-3))
        };
    }

    private static ExploreQuery.ResultSet run(String planJson) {
        return ExploreQuery.run(ExplorePlan.fromJson(planJson));
    }

    @IsTest
    static void quoteAndKeywordsAreBoundNotInjected() {
        String evil = 'x\' OR Name != \'\' OR Name LIKE \'% ; DELETE FROM Account WHERE Id != null) SELECT Id FROM User --';
        ExplorePlan plan = new ExplorePlan();
        plan.objectName = 'Account';
        plan.fields = new List<String>{ 'Name' };
        ExplorePlan.Filter f = new ExplorePlan.Filter();
        f.field = 'Name';
        f.op = '=';
        f.value = evil;
        plan.filters.add(f);

        ExploreQuery.ResultSet rs = ExploreQuery.run(plan);

        Assert.areEqual(0, rs.shown);
        Assert.areEqual(0, rs.total);
        Assert.areEqual('SELECT Name, Id FROM Account WHERE Name = :b0 LIMIT 50', rs.soql);
        Assert.isFalse(rs.soql.contains('DELETE'));
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Name = 'Query Acme']);
    }

    @IsTest
    static void limitDefaultsAndClamps() {
        Assert.isTrue(run('{"object":"Opportunity","fields":["Name"]}').soql.endsWith(' LIMIT 50'));
        Assert.isTrue(run('{"object":"Opportunity","fields":["Name"],"limit":500}').soql.endsWith(' LIMIT 200'));
        Assert.isTrue(run('{"object":"Opportunity","fields":["Name"],"limit":0}').soql.endsWith(' LIMIT 50'));

        ExploreQuery.ResultSet two = run('{"object":"Opportunity","fields":["Name"],"limit":2}');
        Assert.areEqual(2, two.shown);
        Assert.areEqual(4, two.total, 'a full page counts the total');
        Assert.areEqual(2, two.rows.size());
    }

    @IsTest
    static void aggregateWithoutGroupByHasNoLimit() {
        ExploreQuery.ResultSet rs = run('{"object":"Opportunity","aggregates":[{"fn":"COUNT"},{"fn":"sum","field":"amount"}],'
            + '"filters":[{"field":"Account.Name","op":"=","value":"Query Acme"}],"orderBy":{"field":"Name"}}');

        Assert.areEqual('SELECT COUNT(Id) a0, SUM(Amount) a1 FROM Opportunity WHERE Account.Name = :b0', rs.soql);
        Assert.areEqual(new List<String>{ 'COUNT(Id)', 'SUM(Amount)' }, rs.columns);
        Assert.areEqual(1, rs.shown);
        Assert.areEqual(3, rs.rows[0].get('COUNT(Id)'));
        Assert.areEqual(6000, ((Decimal) rs.rows[0].get('SUM(Amount)')).intValue());
        Assert.isFalse(rs.rows[0].containsKey('Id'));
    }

    @IsTest
    static void aggregateOverTheRowCapIsRefusedAfterACappedCount() {
        ExploreQuery.rowCap = 2;
        ExplorePlan plan = ExplorePlan.fromJson('{"object":"Opportunity","aggregates":[{"fn":"SUM","field":"Amount"}]}');

        Test.startTest();
        try {
            ExploreQuery.run(plan);
            Assert.fail('expected RowCapException: 4 opportunities, cap 2');
        } catch (ExploreQuery.RowCapException e) {
            Assert.isTrue(e.getMessage().contains('more than 2 rows'), e.getMessage());
        }
        Integer rows = Limits.getQueryRows();
        Test.stopTest();

        Assert.areEqual(1, rows, 'only the capped pre-count ran, and a COUNT() reads one query row');
    }

    @IsTest
    static void groupedAggregateOverTheRowCapIsRefused() {
        ExploreQuery.rowCap = 3;
        try {
            run('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"},{"fn":"SUM","field":"Amount"}]}');
            Assert.fail('expected RowCapException: 4 opportunities, cap 3');
        } catch (ExploreQuery.RowCapException e) {
            Assert.isTrue(e.getMessage().contains('more than 3 rows'), e.getMessage());
        }
    }

    @IsTest
    static void aggregateWithinTheRowCapRuns() {
        ExploreQuery.rowCap = 3;

        Test.startTest();
        ExploreQuery.ResultSet rs = run('{"object":"Opportunity","aggregates":[{"fn":"SUM","field":"Amount"}],'
            + '"filters":[{"field":"Account.Name","op":"=","value":"Query Acme"}]}');
        Integer rows = Limits.getQueryRows();
        Test.stopTest();

        Assert.areEqual(6000, ((Decimal) rs.rows[0].get('SUM(Amount)')).intValue());
        Assert.areEqual(4, rows, 'pre-count (1 row) plus the aggregate (one row per record aggregated)');
    }

    @IsTest
    static void countOnlyAggregatesSkipTheRowCap() {
        ExploreQuery.rowCap = 2;
        Test.startTest();
        Integer start = Limits.getQueryRows();
        ExploreQuery.ResultSet page = run('{"object":"Opportunity","fields":["Name"],"limit":2}');
        Integer plain = Limits.getQueryRows() - start;
        start = Limits.getQueryRows();
        ExploreQuery.ResultSet total = run('{"object":"Opportunity","aggregates":[{"fn":"COUNT"}]}');
        Integer countOnly = Limits.getQueryRows() - start;
        start = Limits.getQueryRows();
        ExploreQuery.ResultSet grouped = run('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}]}');
        Integer groupedRows = Limits.getQueryRows() - start;
        Test.stopTest();

        String seen = 'plain=' + plain + ' countOnly=' + countOnly + ' grouped=' + groupedRows;
        Assert.areEqual(4, page.total);
        Assert.areEqual(3, plain, 'two rows plus one for the uncapped total COUNT(): ' + seen);
        Assert.areEqual(4, total.rows[0].get('COUNT(Id)'), 'counted 4 opportunities past a cap of 2');
        Assert.areEqual(1, countOnly, 'an ungrouped COUNT(Id) reads one row and runs no pre-count: ' + seen);
        Assert.areEqual(2, grouped.shown);
        Assert.areEqual(2, groupedRows, 'a grouped COUNT(Id) reads one row per group: ' + seen);
    }

    @IsTest
    static void aggregateWithGroupBy() {
        ExploreQuery.ResultSet rs = run('{"object":"Opportunity","fields":["StageName"],"groupBy":["stagename"],'
            + '"aggregates":[{"fn":"COUNT","field":"Id"},{"fn":"SUM","field":"Amount"}],"orderBy":{"field":"sum(amount)","dir":"desc"}}');

        Assert.areEqual('SELECT StageName g0, COUNT(Id) a0, SUM(Amount) a1 FROM Opportunity GROUP BY StageName '
            + 'ORDER BY SUM(Amount) DESC NULLS LAST LIMIT 50', rs.soql);
        Assert.areEqual(2, rs.shown);
        Assert.areEqual('Closed Won', rs.rows[0].get('StageName'));
        Assert.areEqual(4000, ((Decimal) rs.rows[0].get('SUM(Amount)')).intValue());
        Assert.areEqual(2, rs.rows[1].get('COUNT(Id)'));

        ExploreQuery.ResultSet byGroup = run('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],'
            + '"orderBy":{"field":"StageName"},"limit":1}');
        Assert.isTrue(byGroup.soql.endsWith('GROUP BY StageName ORDER BY StageName ASC LIMIT 1'), byGroup.soql);
        Assert.areEqual(1, byGroup.total, 'grouped results are not recounted');

        ExploreQuery.ResultSet byCount = run('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],'
            + '"orderBy":{"field":"COUNT()","dir":"DESC"}}');
        Assert.isTrue(byCount.soql.contains('ORDER BY COUNT(Id) DESC'), byCount.soql);
    }

    @IsTest
    static void typedFiltersAndDateLiterals() {
        String base = '{"object":"Opportunity","fields":["Name","Account.Name"],"filters":[';
        Assert.areEqual(3, run(base + '{"field":"CloseDate","op":"=","value":"this_year"},{"field":"Name","op":"LIKE","value":"Q %"}]}').shown);
        Assert.isTrue(run(base + '{"field":"CloseDate","op":"=","value":"this_year"}]}').soql.contains('CloseDate = THIS_YEAR'));
        Assert.areEqual(4, run(base + '{"field":"CreatedDate","op":">=","value":"LAST_N_DAYS: 30"}]}').shown);
        Assert.isTrue(run(base + '{"field":"CreatedDate","op":">=","value":"last_n_days:30"}]}').soql.contains('CreatedDate >= LAST_N_DAYS:30'));
        Assert.areEqual(1, run(base + '{"field":"CloseDate","op":"<","value":"' + String.valueOf(Date.today().addYears(-1)) + '"}]}').shown);
        Assert.areEqual(4, run(base + '{"field":"CreatedDate","op":">","value":"2020-01-01"}]}').shown);
        Assert.areEqual(4, run(base + '{"field":"CreatedDate","op":">","value":"2020-01-01T00:00:00Z"}]}').shown);
        Assert.areEqual(2, run(base + '{"field":"Amount","op":">=","value":2000}]}').shown);
        Assert.areEqual(1, run(base + '{"field":"Amount","op":"=","value":"500"}]}').shown);
        Assert.areEqual(2, run(base + '{"field":"StageName","op":"IN","value":["Prospecting"]}]}').shown);
        Assert.areEqual(2, run(base + '{"field":"IsWon","op":"=","value":true}]}').shown);
        Assert.areEqual(3, run(base + '{"field":"NextStep","op":"=","value":null}]}').shown);
        Assert.areEqual(3, run(base + '{"field":"Probability","op":">=","value":0},{"field":"Name","op":"!=","value":"Q Two"}]}').shown);

        Id acmeId = [SELECT Id FROM Account WHERE Name = 'Query Acme'].Id;
        Assert.areEqual(3, run(base + '{"field":"AccountId","op":"IN","value":["' + acmeId + '"]}]}').shown);
        Assert.areEqual(1, run('{"object":"Account","fields":["Name"],"filters":[{"field":"NumberOfEmployees","op":"IN","value":[40,41]},'
            + '{"field":"NumberOfEmployees","op":"<","value":"41"}]}').shown);

        ExploreQuery.ResultSet orphan = run(base + '{"field":"Name","op":"=","value":"Q Orphan"}]}');
        Assert.isNull(orphan.rows[0].get('Account.Name'), 'an empty parent lookup reads as null');
        Assert.areEqual('Name = Q Orphan', orphan.filters);
        Assert.isNotNull(orphan.rows[0].get('Id'));
        Assert.isTrue(orphan.planJson.contains('"object":"Opportunity"'));
        Assert.areEqual('no filters', run('{"object":"Opportunity","fields":["Name"]}').filters);
    }

    @IsTest
    static void invalidPlanIsRefused() {
        try {
            run('{"object":"Opportunity","fields":["Nope"]}');
            Assert.fail('expected PlanException');
        } catch (ExplorePlan.PlanException e) {
            Assert.isTrue(e.getMessage().contains('Unknown field "Nope" on Opportunity.'));
        }
    }

    private static User kiritimatiUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = 'tz' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'tzusr',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Explore Zone',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Pacific/Kiritimati',
            Username = uniq + '@example.com.exploretz'
        );
        insert u;
        return u;
    }

    @IsTest
    static void aDateOnlyValueOnADatetimeFieldIsReadInTheUsersTimeZone() {
        System.runAs(kiritimatiUser()) {
            Assert.areEqual('Pacific/Kiritimati', UserInfo.getTimeZone().getID(), 'the test needs a zone far from GMT');
            Account acct = new Account(Name = 'Zone Account');
            insert acct;
            // Noon on 2026-01-05 where the user is (UTC+14) is 22:00 GMT on the 4th.
            Test.setCreatedDate(acct.Id, Datetime.newInstance(Date.newInstance(2026, 1, 5), Time.newInstance(12, 0, 0, 0)));
            String base = '{"object":"Account","fields":["Name"],"filters":[{"field":"Name","op":"=","value":"Zone Account"},';

            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"=","value":"2026-01-05"}]}').shown, 'the day matches');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"=","value":"2026-01-04"}]}').shown, 'the GMT day does not');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"!=","value":"2026-01-05"}]}').shown);
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"!=","value":"2026-01-04"}]}').shown);
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":">=","value":"2026-01-05"}]}').shown, 'local midnight');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"<","value":"2026-01-05"}]}').shown, 'local midnight');
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"<","value":"2026-01-06"}]}').shown);
        }
    }

    @IsTest
    static void rangeOperatorsAndInCoverTheWholeLocalDayForADateOnlyValue() {
        System.runAs(kiritimatiUser()) {
            Account acct = new Account(Name = 'Zone Account');
            insert acct;
            // Noon on 2026-01-05 where the user is (UTC+14): well inside that local day, away from both midnights.
            Test.setCreatedDate(acct.Id, Datetime.newInstance(Date.newInstance(2026, 1, 5), Time.newInstance(12, 0, 0, 0)));
            String base = '{"object":"Account","fields":["Name"],"filters":[{"field":"Name","op":"=","value":"Zone Account"},';

            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":">","value":"2026-01-05"}]}').shown, '> the day excludes the day itself');
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":">","value":"2026-01-04"}]}').shown, '> the day before includes the day');
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":">=","value":"2026-01-05"}]}').shown, '>= starts at local midnight');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":">=","value":"2026-01-06"}]}').shown);
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"<","value":"2026-01-05"}]}').shown, '< stops at local midnight');
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"<","value":"2026-01-06"}]}').shown);
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"<=","value":"2026-01-05"}]}').shown, '<= includes the whole day');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"<=","value":"2026-01-04"}]}').shown);

            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"IN","value":["2026-01-05"]}]}').shown, 'IN matches any time in the day');
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"IN","value":["2026-01-03","2026-01-05"]}]}').shown);
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":"IN","value":["2026-01-03","2026-01-04"]}]}').shown);

            // Several date filters in one query keep distinct bind names.
            ExploreQuery.ResultSet both = run(base + '{"field":"CreatedDate","op":">=","value":"2026-01-05"},'
                + '{"field":"CreatedDate","op":"<=","value":"2026-01-05"}]}');
            Assert.areEqual(1, both.shown, 'through the same day, both ends');
            Assert.areEqual(0, run(base + '{"field":"CreatedDate","op":">","value":"2026-01-04"},'
                + '{"field":"CreatedDate","op":"<=","value":"2026-01-04"}]}').shown);
            Assert.areEqual(1, run(base + '{"field":"CreatedDate","op":"IN","value":["2026-01-05","2026-01-07"]},'
                + '{"field":"CreatedDate","op":"<=","value":"2026-01-05"},{"field":"CreatedDate","op":"!=","value":"2026-01-04"}]}').shown);
        }
    }

    @IsTest
    static void labelsAreDotFreeAndUniqueWhilePathsStayTheKeys() {
        ExploreQuery.ResultSet rs = run('{"object":"Opportunity","fields":["Name","Account.Name","Owner.Name"]}');

        Assert.areEqual(new List<String>{ 'Name', 'Account.Name', 'Owner.Name' }, rs.columns);
        Assert.areEqual(new List<String>{ 'Name', 'Account', 'Owner' }, rs.labels);
        Assert.isTrue(rs.rows[0].containsKey('Account.Name'), 'rows stay keyed by field path');

        ExploreQuery.ResultSet grouped = run('{"object":"Opportunity","fields":["Owner.Name"],"groupBy":["Owner.Name"],'
            + '"aggregates":[{"fn":"COUNT"},{"fn":"SUM","field":"Amount"},{"fn":"AVG","field":"Amount"}]}');
        Assert.areEqual(new List<String>{ 'Owner', 'Count', 'Sum of Amount', 'Average of Amount' }, grouped.labels);
        for (String l : grouped.labels) {
            Assert.isFalse(l.contains('.') || l.contains('('), l);
        }

        Assert.areEqual(new List<String>{ 'Owner', 'owner 2', 'Owner 3', 'Name' },
            ExploreQuery.uniqueLabels(new List<String>{ 'Owner', 'owner', 'Owner', 'Name' }));
    }
}
