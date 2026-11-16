/**
 * The 44 plan shapes of spikes/explorer-scale/rejections.apex (BE-31), each with the outcome recorded in
 * spikes/explorer-scale/results/rejections.txt: REJ plans are refused before any query with the reason
 * shown, OK plans run. Messages are those of ExplorePlan; where it words a reason differently from the
 * prototype, the fragment here is ExplorePlan's.
 */
@IsTest
private class ExplorePlanRejectionTest {
    private static final String SEMI = '{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId",'
        + '"where":{"field":"IsClosed","op":"=","value":false}}}';

    /** The prototype ran with one earlier step that returned no rows. */
    private static List<ExploreQuery.ResultSet> oneEmptyStep() {
        return new List<ExploreQuery.ResultSet>{ new ExploreQuery.ResultSet() };
    }

    private static void refused(Integer n, String planJson, String expected) {
        // Lead and Product2 are described on demand, as DataExplorer does before it validates.
        ExploreCatalog.describe('Lead');
        ExploreCatalog.describe('Product2');
        List<String> errors = ExplorePlan.validate(ExplorePlan.fromJson(planJson), oneEmptyStep());
        String all = String.join(errors, ' | ');
        Assert.isFalse(errors.isEmpty(), 'case ' + n + ' should be refused');
        Assert.isTrue(all.contains(expected), 'case ' + n + ': expected "' + expected + '" in: ' + all);
    }

    private static ExploreQuery.ResultSet accepted(Integer n, String planJson) {
        ExploreCatalog.describe('Lead');
        ExploreCatalog.describe('Product2');
        ExplorePlan plan = ExplorePlan.fromJson(planJson);
        List<String> errors = ExplorePlan.validate(plan, oneEmptyStep());
        Assert.isTrue(errors.isEmpty(), 'case ' + n + ' should run: ' + String.join(errors, ' | '));
        return ExploreQuery.run(plan, oneEmptyStep());
    }

    @IsTest
    static void cases1To8ObjectsPathsAndNamesAreRefused() {
        refused(1, '{"object":"Customer_Summary_Session__c","aggregates":[{"fn":"COUNT"}]}', 'Unknown object "Customer_Summary_Session__c"');
        // Case 2 named the product's retired session object; any object that no longer exists is refused the same way.
        refused(2, '{"object":"Retired_Session__c","fields":["Name"]}', 'Unknown object "Retired_Session__c"');
        refused(3, '{"object":"AccountHistory","fields":["Field"]}', 'Unknown object "AccountHistory"');
        refused(4, '{"object":"No_Such__c","fields":["Name"]}', 'Unknown object "No_Such__c"');
        refused(5, '{"object":"Opportunity","fields":["Account.Owner.Manager.Name"]}', '"Account.Owner.Manager.Name" goes more than two lookups deep.');
        refused(6, '{"object":"Opportunity","fields":["Account.Owner.No_Such__c"]}', 'Unknown field "Account.Owner.No_Such__c" on Opportunity.');
        refused(7, '{"object":"Opportunity","fields":["No_Such.Name"]}', 'Unknown lookup "No_Such" in "No_Such.Name".');
        refused(8, '{"object":"Account","where":{"or":[{"field":"Industry","op":"=","value":"Energy"},'
            + '{"field":"No_Such__c","op":"=","value":"x"}]}}', 'Unknown field "No_Such__c" on Account.');
    }

    @IsTest
    static void cases9To18BadSemiJoinsAreRefused() {
        refused(9, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Customer_Summary_Session__c","field":"OwnerId"}}}',
            'Unknown object "Customer_Summary_Session__c" in "sub".');
        refused(10, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Task","field":"AccountId"}}}',
            'Task can\'t be in "sub"; query it first and use a step value.');
        refused(11, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Account","field":"ParentId"}}}',
            'Account can\'t be in "sub"; query it first and use a step value.');
        refused(12, '{"object":"Account","fields":["Name"],"where":{"or":[' + SEMI + ',{"field":"Industry","op":"=","value":"Energy"}]}}',
            '"sub" must be at the top level of "where", not inside "or" or "not".');
        refused(13, '{"object":"Account","fields":["Name"],"where":{"not":' + SEMI + '}}',
            '"sub" must be at the top level of "where", not inside "or" or "not".');
        refused(14, '{"object":"Account","fields":["Name"],"where":{"and":[' + SEMI + ',' + SEMI + ',' + SEMI + ']}}',
            'Use "sub" at most twice.');
        refused(15, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"Subject"}}}',
            'Subject is not a lookup on Case.');
        refused(16, '{"object":"Contact","fields":["Name"],"where":{"field":"Account.OwnerId","op":"IN","sub":{"object":"Case","field":"OwnerId"}}}',
            '"sub" needs Id or a lookup on Contact.');
        refused(17, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"=","sub":{"object":"Case","field":"AccountId"}}}',
            '"sub" takes IN or NOT IN.');
        refused(18, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId",'
            + '"where":{"field":"No_Such__c","op":"=","value":1}}}}', 'Unknown field "No_Such__c" on Case.');
    }

    @IsTest
    static void cases19To30LongTextLimitsAndValuesAreRefused() {
        refused(19, '{"object":"Account","fields":["Name"],"where":{"field":"Description","op":"=","value":"x"}}',
            'Description is long text: use CONTAINS');
        refused(20, '{"object":"Account","fields":["Name"],"where":{"or":[{"field":"Description","op":"CONTAINS","value":"x"},'
            + '{"field":"Industry","op":"=","value":"Energy"}]}}', 'CONTAINS on long text Description must be at the top level of "where".');
        refused(21, '{"object":"Account","fields":["Name"],"orderBy":{"field":"Description","dir":"ASC"}}', 'Description can\'t be sorted.');
        refused(22, '{"object":"Account","groupBy":["Description"],"aggregates":[{"fn":"COUNT"}]}', 'Description can\'t be grouped.');
        refused(23, '{"object":"Account","fields":["Name"],"where":{"and":[{"and":[{"and":[{"and":[{"and":['
            + '{"field":"Name","op":"!=","value":null}]}]}]}]}]}}', '"where" parts must be conditions or groups, at most 4 deep.');
        refused(24, '{"object":"Account","fields":["Name"],"where":{"or":[' + '{"field":"Name","op":"=","value":"a"},'.repeat(20)
            + '{"field":"Name","op":"=","value":"b"}]}}', 'Use at most 20 conditions.');
        refused(25, '{"object":"Account","fields":["Name"],"where":{"field":"Name","op":"NOT LIKE","value":"a%"}}', 'Unknown op "NOT LIKE" on Name.');
        refused(26, '{"object":"Account","fields":["Name"],"where":{"field":"Industry","op":"IN","value":"Energy"}}',
            'IN on Industry needs a list of 1 to 200 values.');
        refused(27, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","value":{"step":2,"field":"Id"}}}',
            'A step value needs IN or NOT IN and an earlier query (1 to 1).');
        refused(28, '{"object":"Account","fields":["Name"],"children":[{"rel":"No_Such__r","fields":["Name"]}]}',
            'Unknown child list "No_Such__r" on Account.');
        refused(29, '{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],'
            + '"having":[{"fn":"SUM","field":"Amount","op":">","value":1}]}', '"having" must use one of the aggregates and a comparison.');
        refused(30, '{"object":"Opportunity","fields":["Name"],"where":{"field":"Amount","op":">","value":"lots"}}',
            'Amount takes a number; "lots" is not one.');
    }

    @IsTest
    static void cases31To37OrPathsTextAndSemiJoinsRun() {
        Assert.areEqual('SELECT COUNT(Id) a0 FROM Case WHERE (Status = :b0 OR Priority = :b1)', accepted(31,
            '{"object":"Case","aggregates":[{"fn":"COUNT"}],"where":{"or":[{"field":"Status","op":"=","value":"Escalated"},'
            + '{"field":"Priority","op":"=","value":"High"}]}}').soql);
        // Case 32 filtered on Account.Owner.IsActive. BE-42's deny list now limits User to Id, Name and Title,
        // so the same two-lookup shape filters on Title, and IsActive is refused like any field the catalog hides.
        Assert.areEqual('SELECT Name, Account.Owner.Name, Id FROM Opportunity WHERE Account.Owner.Title != :b0 LIMIT 50', accepted(32,
            '{"object":"Opportunity","fields":["Name","Account.Owner.Name"],"where":{"field":"Account.Owner.Title","op":"!=","value":null}}').soql);
        refused(32, '{"object":"Opportunity","fields":["Name"],"where":{"field":"Account.Owner.IsActive","op":"=","value":true}}',
            'Unknown field "Account.Owner.IsActive" on Opportunity.');
        Assert.areEqual('SELECT Name, Id, Description FROM Account LIMIT 2001', accepted(33,
            '{"object":"Account","fields":["Name"],"where":{"field":"Description","op":"CONTAINS","value":"renewal"}}').soql);
        Assert.areEqual('SELECT Name, Id FROM Account WHERE Id IN (SELECT AccountId FROM Case WHERE IsClosed = :b0) LIMIT 50', accepted(34,
            '{"object":"Account","fields":["Name"],"where":' + SEMI + '}').soql);
        Assert.areEqual('SELECT COUNT(Id) a0 FROM Lead', accepted(35, '{"object":"Lead","aggregates":[{"fn":"COUNT"}]}').soql);
        Assert.areEqual('SELECT Name, Id FROM Account WHERE Id NOT IN (SELECT AccountId FROM Opportunity) LIMIT 50', accepted(36,
            '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"NOT IN","sub":{"object":"Opportunity","field":"AccountId"}}}').soql);
        Assert.areEqual('SELECT Name, Id FROM Contact WHERE AccountId IN (SELECT AccountId FROM Case) AND (NOT (Email = :b0)) LIMIT 50',
            accepted(37, '{"object":"Contact","fields":["Name"],"where":{"and":[{"field":"AccountId","op":"IN","sub":{"object":"Case","field":"AccountId"}},'
            + '{"not":{"field":"Email","op":"=","value":null}}]}}').soql);
    }

    @IsTest
    static void cases38To43ChildrenHavingStepsAndPathsRun() {
        Assert.areEqual('SELECT Name, Id, (SELECT Id, Name, Amount FROM Opportunities WHERE IsClosed = :b0 LIMIT 3) FROM Account LIMIT 50',
            accepted(38, '{"object":"Account","fields":["Name"],"children":[{"rel":"Opportunities","fields":["Name","Amount"],'
            + '"where":{"field":"IsClosed","op":"=","value":false},"limit":3}]}').soql);
        Assert.areEqual('SELECT AccountId g0, COUNT(Id) a0 FROM Opportunity WHERE IsClosed = :b0 GROUP BY AccountId HAVING COUNT(Id) > :b1 LIMIT 50',
            accepted(39, '{"object":"Opportunity","groupBy":["AccountId"],"aggregates":[{"fn":"COUNT"}],"where":{"field":"IsClosed","op":"=","value":false},'
            + '"having":[{"fn":"COUNT","field":"","op":">","value":3}]}').soql);
        ExploreQuery.ResultSet fromStep = accepted(40, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","value":{"step":1,"field":"Id"}}}');
        Assert.areEqual('SELECT Name, Id FROM Account WHERE Id IN :b0 LIMIT 50', fromStep.soql);
        Assert.areEqual(0, fromStep.shown, 'an empty step matches nothing');
        Assert.areEqual('SELECT Name, Id FROM Account WHERE Name = :b0 LIMIT 50', accepted(41,
            '{"object":"Account","fields":["Name"],"where":{"field":"Name","op":"=","value":"x\' OR Name != \'"}}').soql);
        Assert.areEqual('SELECT Role, Opportunity.Account.Name, Id FROM OpportunityContactRole WHERE Contact.Account.Type = :b0 LIMIT 50', accepted(42,
            '{"object":"OpportunityContactRole","fields":["Role","Opportunity.Account.Name"],"where":{"field":"Contact.Account.Type","op":"=","value":"Customer - Direct"}}').soql);
        Assert.areEqual('SELECT COUNT(Id) a0 FROM Product2 WHERE IsActive = :b0', accepted(43,
            '{"object":"Product2","aggregates":[{"fn":"COUNT"}],"where":{"field":"IsActive","op":"=","value":true}}').soql);
    }

    @IsTest
    static void case44ASetupAndAuditObjectIsRefused() {
        refused(44, '{"object":"SetupAuditTrail","fields":["Action"]}', 'Unknown object "SetupAuditTrail"');
    }

    // ---------------------------------------------------------------- the refusals the platform needs, one each

    @IsTest
    static void anEventInnerSelectIsRefused() {
        refused(0, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Event","field":"AccountId"}}}',
            'Event can\'t be in "sub"; query it first and use a step value.');
    }

    @IsTest
    static void aSemiJoinInsideAChildListOrAnotherSemiJoinIsRefused() {
        refused(0, '{"object":"Account","fields":["Name"],"children":[{"rel":"Contacts","fields":["Name"],'
            + '"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"ContactId"}}}]}',
            '"sub" can\'t be nested inside another "sub" or a child list.');
        refused(0, '{"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId",'
            + '"where":{"field":"ContactId","op":"IN","sub":{"object":"Opportunity","field":"ContactId"}}}}}',
            '"sub" can\'t be nested inside another "sub" or a child list.');
    }

    @IsTest
    static void groupByOnLongTextIsRefusedBeforeAnyQuery() {
        Integer before = Limits.getQueries();
        refused(0, '{"object":"Case","groupBy":["Description"],"aggregates":[{"fn":"COUNT"}]}', 'Description can\'t be grouped.');
        refused(0, '{"object":"Case","fields":["Subject"],"orderBy":{"field":"Description","dir":"DESC"}}', 'Description can\'t be sorted.');
        Assert.areEqual(before, Limits.getQueries(), 'refused before any query ran');
    }

    @IsTest
    static void containsOnLongTextIsRefusedWithAggregates() {
        refused(0, '{"object":"Account","aggregates":[{"fn":"COUNT"}],"where":{"field":"Description","op":"CONTAINS","value":"x"}}',
            'CONTAINS on long text Description can\'t be used with groupBy or aggregates.');
    }
}
