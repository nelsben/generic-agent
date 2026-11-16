@IsTest
private class ExplorePlanTest {
    /** The validation errors for a plan written as JSON, joined. */
    private static String errors(String planJson) {
        return String.join(ExplorePlan.validate(ExplorePlan.fromJson(planJson)), ' | ');
    }

    private static String filterErrors(String filterJson) {
        return errors('{"object":"Opportunity","fields":["Name"],"filters":[' + filterJson + ']}');
    }

    private static void has(String actual, String expected) {
        Assert.isTrue(actual.contains(expected), 'expected "' + expected + '" in: ' + actual);
    }

    @IsTest
    static void aValidPlanHasNoErrors() {
        Assert.areEqual('', errors('{"Object":"opportunity","fields":"name","filters":[{"field":"stagename","op":"in","value":["Closed Won"]}],'
            + '"orderBy":"Amount","limit":"10"}'));
        ExplorePlan p = ExplorePlan.fromJson('{"object":"Opportunity","fields":["Name"],"orderBy":"Amount","limit":10.0}');
        Assert.areEqual(10, p.rowLimit);
        Assert.areEqual('Amount', p.orderBy.field);
        ExplorePlan.Resolved r = ExplorePlan.resolve(p);
        Assert.areEqual('Amount', r.orderExpr);
        Assert.areEqual('ASC', r.orderDir);
        Map<String, Object> round = (Map<String, Object>) JSON.deserializeUntyped(p.toJson());
        Assert.areEqual('Opportunity', round.get('object'));
        Assert.areEqual('Amount', ((Map<String, Object>) round.get('orderBy')).get('field'));
    }

    @IsTest
    static void shapeErrors() {
        Assert.areEqual(new List<String>{ 'The plan is missing.' }, ExplorePlan.validate(null));
        has(errors('not json'), 'The plan is not valid JSON.');
        has(errors('[1]'), 'The plan must be a JSON object.');
        has(errors('{"object":"Account","fields":["Name"],"select":"x"}'), 'Unknown plan key "select".');
        has(errors('{"fields":["Name"]}'), 'Name one object in "object".');
        has(errors('{"object":"Account","fields":["Name"],"filters":{"a":1}}'), '"filters" must be a list.');
        has(errors('{"object":"Account","fields":["Name"],"filters":["x"]}'), 'Each filter must be an object');
        has(errors('{"object":"Account","aggregates":["x"]}'), 'Each aggregate must be an object');
        has(errors('{"object":"Account","fields":[1]}'), '"fields" must list field names as text.');
        has(errors('{"object":"Account","fields":["Name"],"orderBy":5}'), 'orderBy must be an object');
        has(errors('{"object":"Account","fields":["Name"],"limit":"ten"}'), 'limit must be a whole number.');
        has(errors('{"object":"Account","fields":["Name"],"limit":2.5}'), 'limit must be a whole number.');
        has(errors('{"object":"Account"}'), 'List at least one field');
    }

    @IsTest
    static void unknownNamesAreRejected() {
        has(errors('{"object":"Lead","fields":["Name"]}'), 'Unknown object "Lead". Use one of: Account,');
        has(errors('{"object":"Opportunity","fields":["Name","Secret__c"]}'), 'Unknown field "Secret__c" on Opportunity.');
        has(errors('{"object":"Opportunity","fields":["Owner.Email"]}'), 'Unknown field "Owner.Email"');
    }

    @IsTest
    static void filterErrorsArePlainEnglish() {
        has(filterErrors('{"field":"Description","op":"=","value":"x"}'), 'Description is long text: use CONTAINS at the top level of "where"');
        has(filterErrors('{"field":"Name","op":"NOT LIKE","value":"x"}'), 'Unknown op "NOT LIKE" on Name. Use one of: = != < <= > >= LIKE IN NOT IN CONTAINS.');
        has(filterErrors('{"field":"Name","op":"IN","value":"x"}'), 'IN on Name needs a list of 1 to 200 values.');
        has(filterErrors('{"field":"Name","op":"IN","value":[]}'), 'IN on Name needs a list of 1 to 200 values.');
        has(filterErrors('{"field":"Name","op":"IN","value":["a",null]}'), 'IN on Name can\'t contain null.');
        has(filterErrors('{"field":"Name","op":"IN","value":[["a"]]}'), 'Each value for Name must be a single value.');
        has(filterErrors('{"field":"Name","op":"=","value":["a"]}'), 'must be a single value; use IN for a list.');
        has(filterErrors('{"field":"Name","op":"<","value":{"a":1}}'), 'The value for Name must be a single value.');
        has(filterErrors('{"field":"Amount","op":"<","value":null}'), 'Only = and != can compare Amount to null.');
        has(filterErrors('{"field":"Amount","op":"LIKE","value":"1%"}'), 'LIKE needs a text field; Amount is currency.');
        has(filterErrors('{"field":"IsWon","op":">","value":true}'), 'IsWon takes only =, != or IN.');
        has(filterErrors('{"field":"IsWon","op":"=","value":"yes"}'), 'IsWon takes true or false.');
        has(filterErrors('{"field":"AccountId","op":"=","value":"not-an-id"}'), '"not-an-id" is not a record id');
        has(filterErrors('{"field":"Amount","op":"=","value":"lots"}'), 'Amount takes a number; "lots" is not one.');
        has(filterErrors('{"field":"CloseDate","op":"=","value":"31/01/2026"}'), 'CloseDate takes a date as YYYY-MM-DD, or a date literal');
        has(filterErrors('{"field":"CreatedDate","op":"=","value":"soon-ish"}'), 'or YYYY-MM-DDThh:mm:ssZ');

        List<Object> many = new List<Object>();
        for (Integer i = 0; i <= ExplorePlan.MAX_IN_VALUES; i++) {
            many.add('v' + i);
        }
        has(filterErrors('{"field":"Name","op":"IN","value":' + JSON.serialize(many) + '}'), 'IN on Name takes at most 200 values.');

        String accountErrors = errors('{"object":"Account","fields":["Name"],"filters":[{"field":"NumberOfEmployees","op":"=","value":1.5}]}');
        has(accountErrors, 'NumberOfEmployees takes a whole number.');
    }

    @IsTest
    static void dateLiteralsComeFromTheFixedList() {
        has(filterErrors('{"field":"CloseDate","op":"=","value":"LAST_N_FORTNIGHTS:2"}'), 'Unknown date literal "LAST_N_FORTNIGHTS:2". Use one of: YESTERDAY, TODAY');
        has(filterErrors('{"field":"CloseDate","op":"=","value":"SOMEDAY"}'), 'Unknown date literal "SOMEDAY"');
        has(filterErrors('{"field":"CloseDate","op":"=","value":"LAST_N_DAYS:0"}'), 'Unknown date literal');
        has(filterErrors('{"field":"CloseDate","op":"=","value":"LAST_N_DAYS:99999999999"}'), 'Unknown date literal');
        has(filterErrors('{"field":"CloseDate","op":"IN","value":"TODAY"}'), 'IN can\'t be used with a date literal on CloseDate.');
        Assert.areEqual('', filterErrors('{"field":"CloseDate","op":">=","value":"next_n_quarters:2"}'));
        // On a text field a literal-looking value is just text, and is bound.
        Assert.areEqual('', filterErrors('{"field":"Name","op":"=","value":"TODAY"}'));

        ExploreCatalog.Field closeDate = ExploreCatalog.find('Opportunity').field('CloseDate');
        Assert.areEqual('N_DAYS_AGO:7', ExplorePlan.dateLiteral(closeDate, '=', 'n_days_ago:7'));
        Assert.isNull(ExplorePlan.dateLiteral(closeDate, '=', '2026-01-31'));
        Assert.isNull(ExplorePlan.dateLiteral(closeDate, '=', 5));
        Assert.areEqual(Date.newInstance(2026, 1, 31), ExplorePlan.bindValue(closeDate, '=', '2026-01-31'));
    }

    @IsTest
    static void aggregateErrors() {
        has(errors('{"object":"Opportunity","fields":["Name"],"aggregates":[{"fn":"COUNT"}]}'),
            'Plain fields and aggregates can\'t be mixed without groupBy.');
        has(errors('{"object":"Opportunity","fields":["Name"],"groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}]}'),
            'Name is in fields but not in groupBy.');
        has(errors('{"object":"Opportunity","groupBy":["Description"],"aggregates":[{"fn":"COUNT"}]}'), 'Description can\'t be grouped.');
        has(errors('{"object":"Opportunity","aggregates":[{"fn":"MEDIAN","field":"Amount"}]}'), 'Unknown aggregate function "MEDIAN".');
        has(errors('{"object":"Opportunity","aggregates":[{"fn":"SUM","field":"Name"}]}'), 'SUM needs a number field; Name is string.');
        has(errors('{"object":"Opportunity","aggregates":[{"fn":"MAX","field":"Description"}]}'), 'Description can\'t be used with MAX.');
        has(errors('{"object":"Opportunity","aggregates":[{"fn":"SUM"}]}'), 'SUM needs a field.');
        has(errors('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],"orderBy":{"field":"Amount"}}'),
            'With groupBy, orderBy must be a groupBy field or one of the aggregates');
        has(errors('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],"orderBy":{"field":"SUM(Amount)"}}'),
            'With groupBy, orderBy must be');
        Assert.areEqual('', errors('{"object":"Opportunity","aggregates":[{"fn":"COUNT"}],"orderBy":{"field":"Description","dir":"DESC"}}'),
            'orderBy is ignored for a one-row aggregate');
        ExplorePlan.Resolved r = ExplorePlan.resolve(ExplorePlan.fromJson('{"object":"Opportunity","aggregates":[{"fn":"AVG","field":"Amount"}]}'));
        Assert.isNull(r.rowLimit, 'no LIMIT on an aggregate without groupBy');
        Assert.areEqual('AVG(Amount)', r.aggregates[0].expr);
    }

    @IsTest
    static void orderByErrors() {
        has(errors('{"object":"Opportunity","fields":["Name"],"orderBy":{"field":"Amount","dir":"UP"}}'), 'orderBy dir must be ASC or DESC.');
        has(errors('{"object":"Opportunity","fields":["Name"],"orderBy":{"field":"Description"}}'), 'Description can\'t be sorted.');
        has(errors('{"object":"Opportunity","fields":["Name"],"orderBy":{"field":"Nope"}}'), 'Unknown field "Nope"');
    }

    @IsTest
    static void errorsAreCapped() {
        List<String> fields = new List<String>();
        for (Integer i = 0; i < 15; i++) {
            fields.add('Bad' + i);
        }
        List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson('{"object":"Account","fields":' + JSON.serialize(fields) + '}'));
        Assert.areEqual(10, errs.size());
    }

    // ---------------------------------------------------------------- BE-43: plan grammar v2

    private static final String SEMI = '{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId",'
        + '"where":{"field":"IsClosed","op":"=","value":false}}}';

    @IsTest
    static void anOrGroupIsAccepted() {
        Assert.areEqual('', errors('{"object":"Case","aggregates":[{"fn":"COUNT"}],"where":{"or":['
            + '{"field":"Status","op":"=","value":"Escalated"},{"field":"Priority","op":"=","value":"High"}]}}'));
    }

    @IsTest
    static void aTwoLevelParentPathIsAccepted() {
        Assert.areEqual('', errors('{"object":"Opportunity","fields":["Name","Account.Owner.Name"],'
            + '"where":{"field":"Account.Owner.Title","op":"!=","value":null}}'));
    }

    @IsTest
    static void aSemiJoinIsAccepted() {
        Assert.areEqual('', errors('{"object":"Account","fields":["Name"],"where":' + SEMI + '}'));
    }

    @IsTest
    static void aThirdSemiJoinIsRefused() {
        has(errors('{"object":"Account","fields":["Name"],"where":{"and":[' + SEMI + ',' + SEMI + ',' + SEMI + ']}}'),
            'Use "sub" at most twice.');
    }

    @IsTest
    static void orderByOnLongTextIsRefused() {
        has(errors('{"object":"Account","fields":["Name"],"orderBy":{"field":"Description","dir":"ASC"}}'),
            'Description can\'t be sorted.');
    }
}
