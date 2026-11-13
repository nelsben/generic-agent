// BE-31 no-model checks for the prototype planner: hand-written plans for each new plan position.
// Run with: python3 spikes/explorer-scale/run.py tool rejections.apex (adds harness.apex and prototype.apex).
// Each line prints the case number, what was expected, what happened, and for an accepted plan the SOQL
// text (field names and :bN bind names only) and the row count. No values, names or Ids are printed.
Cat cat = new Cat();
Meter m = new Meter();
List<List<Map<String, Object>>> steps = new List<List<Map<String, Object>>>{ new List<Map<String, Object>>() };
String semiCase = '{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId","where":{"field":"IsClosed","op":"=","value":false}}}';
List<String> cases = new List<String>{
    // rejected: objects, paths and names
    'REJ {"object":"Customer_Summary_Session__c","aggregates":[{"fn":"COUNT"}]}',
    'REJ {"object":"Account_Brief_Session__c","fields":["Name"]}',
    'REJ {"object":"AccountHistory","fields":["Field"]}',
    'REJ {"object":"No_Such__c","fields":["Name"]}',
    'REJ {"object":"Opportunity","fields":["Account.Owner.Manager.Name"]}',
    'REJ {"object":"Opportunity","fields":["Account.Owner.No_Such__c"]}',
    'REJ {"object":"Opportunity","fields":["No_Such.Name"]}',
    'REJ {"object":"Account","where":{"or":[{"field":"Industry","op":"=","value":"Energy"},{"field":"No_Such__c","op":"=","value":"x"}]}}',
    // rejected: sub (semi- and anti-joins)
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Customer_Summary_Session__c","field":"OwnerId"}}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Task","field":"AccountId"}}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Account","field":"ParentId"}}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"or":[' + semiCase + ',{"field":"Industry","op":"=","value":"Energy"}]}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"not":' + semiCase + '}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"and":[' + semiCase + ',' + semiCase + ',' + semiCase + ']}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"Subject"}}}',
    'REJ {"object":"Contact","fields":["Name"],"where":{"field":"Account.OwnerId","op":"IN","sub":{"object":"Case","field":"OwnerId"}}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"=","sub":{"object":"Case","field":"AccountId"}}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","sub":{"object":"Case","field":"AccountId","where":{"field":"No_Such__c","op":"=","value":1}}}}',
    // rejected: long text, grouping, limits, values
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Description","op":"=","value":"x"}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"or":[{"field":"Description","op":"CONTAINS","value":"x"},{"field":"Industry","op":"=","value":"Energy"}]}}',
    'REJ {"object":"Account","fields":["Name"],"orderBy":{"field":"Description","dir":"ASC"}}',
    'REJ {"object":"Account","groupBy":["Description"],"aggregates":[{"fn":"COUNT"}]}',
    'REJ {"object":"Account","fields":["Name"],"where":{"and":[{"and":[{"and":[{"and":[{"and":[{"field":"Name","op":"!=","value":null}]}]}]}]}]}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"or":[' + '{"field":"Name","op":"=","value":"a"},'.repeat(20) + '{"field":"Name","op":"=","value":"b"}]}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Name","op":"NOT LIKE","value":"a%"}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Industry","op":"IN","value":"Energy"}}',
    'REJ {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","value":{"step":2,"field":"Id"}}}',
    'REJ {"object":"Account","fields":["Name"],"children":[{"rel":"No_Such__r","fields":["Name"]}]}',
    'REJ {"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"COUNT"}],"having":[{"fn":"SUM","field":"Amount","op":">","value":1}]}',
    'REJ {"object":"Opportunity","fields":["Name"],"where":{"field":"Amount","op":">","value":"lots"}}',
    // accepted: the five shapes red-1.txt shows rejected by the deployed ExplorePlan, then the other new positions
    'OK {"object":"Case","aggregates":[{"fn":"COUNT"}],"where":{"or":[{"field":"Status","op":"=","value":"Escalated"},{"field":"Priority","op":"=","value":"High"}]}}',
    'OK {"object":"Opportunity","fields":["Name","Account.Owner.Name"],"where":{"field":"Account.Owner.IsActive","op":"=","value":true}}',
    'OK {"object":"Account","fields":["Name"],"where":{"field":"Description","op":"CONTAINS","value":"renewal"}}',
    'OK {"object":"Account","fields":["Name"],"where":' + semiCase + '}',
    'OK {"object":"Lead","aggregates":[{"fn":"COUNT"}]}',
    'OK {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"NOT IN","sub":{"object":"Opportunity","field":"AccountId"}}}',
    'OK {"object":"Contact","fields":["Name"],"where":{"and":[{"field":"AccountId","op":"IN","sub":{"object":"Case","field":"AccountId"}},{"not":{"field":"Email","op":"=","value":null}}]}}',
    'OK {"object":"Account","fields":["Name"],"children":[{"rel":"Opportunities","fields":["Name","Amount"],"where":{"field":"IsClosed","op":"=","value":false},"limit":3}]}',
    'OK {"object":"Opportunity","groupBy":["AccountId"],"aggregates":[{"fn":"COUNT"}],"where":{"field":"IsClosed","op":"=","value":false},"having":[{"fn":"COUNT","field":"","op":">","value":3}]}',
    'OK {"object":"Account","fields":["Name"],"where":{"field":"Id","op":"IN","value":{"step":1,"field":"Id"}}}',
    'OK {"object":"Account","fields":["Name"],"where":{"field":"Name","op":"=","value":"x\' OR Name != \'"}}',
    'OK {"object":"OpportunityContactRole","fields":["Role","Opportunity.Account.Name"],"where":{"field":"Contact.Account.Type","op":"=","value":"Customer - Direct"}}',
    'OK {"object":"Product2","aggregates":[{"fn":"COUNT"}],"where":{"field":"IsActive","op":"=","value":true}}'
};
Integer pass = 0;
for (Integer i = 0; i < cases.size(); i++) {
    String want = cases[i].substringBefore(' ');
    String got;
    String detail = '';
    try {
        Built b = new Planner(cat, m, steps).build((Map<String, Object>) JSON.deserializeUntyped(cases[i].substringAfter(' ')));
        ExploreQuery.ResultSet rs = runBuilt(b);
        got = 'OK';
        detail = 'rows=' + rs.shown + ' soql=' + b.soql;
    } catch (PlanException e) {
        got = 'REJ';
        detail = e.getMessage();
    } catch (Exception e) {
        got = 'ERR';
        detail = e.getTypeName() + ': ' + e.getMessage();
    }
    pass += got == want ? 1 : 0;
    System.debug(LoggingLevel.ERROR, 'REJ :: ' + (i + 1) + ' :: want=' + want + ' got=' + got + ' :: ' + detail.abbreviate(400));
}
System.debug(LoggingLevel.ERROR, 'REJ :: summary :: ' + pass + ' of ' + cases.size() + ' as expected; cpuMs=' + Limits.getCpuTime() + ' soql=' + Limits.getQueries() + ' heap=' + Limits.getHeapSize());
