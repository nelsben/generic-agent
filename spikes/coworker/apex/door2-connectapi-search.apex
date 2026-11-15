// BE-47 door 2, one call to the Connect Apex search class (ConnectApi.Search, API 63.0 and later, OPS-57).
// Runs as the calling user with no new app, secret or sign-in. Reads one seed account (SOQL only) and searches its name once.
// Prints result lines only: no Ids, no record names, no reply text. Output lines start with BE47| for the recorder.
Account a = [SELECT Name FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity) ORDER BY LastModifiedDate DESC LIMIT 1];
String term = a.Name;
Long t0 = System.now().getTime();
String status = 'ok';
String errType = '';
String errMsg = '';
Integer resultCount = 0;
String keys = '';
try {
    // BE-52: documented signature findAndGroup(String q) returns ConnectApi.SearchResultGroups (Apex reference, API 63.0). Output is read from its JSON form, counts only.
    String json = JSON.serialize(ConnectApi.Search.findAndGroup(term));
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(json);
    Object groups = parsed.get('searchResultGroups');
    resultCount = groups instanceof List<Object> ? ((List<Object>) groups).size() : 0;
    keys = String.join(new List<String>(parsed.keySet()), ',');
} catch (Exception e) {
    status = 'exception';
    errType = e.getTypeName();
    errMsg = e.getMessage();
}
Integer secs = Integer.valueOf((System.now().getTime() - t0) / 1000);
System.debug('BE47|door=2|target=ConnectApi.Search.findAndGroup(String)|status=' + status + '|errType=' + errType + '|errMsg=' + errMsg + '|resultCount=' + resultCount + '|topKeys=' + keys + '|summary=none|seconds=' + secs);
