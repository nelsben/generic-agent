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
try {
    // The result type name is not used here (round 1 failed on it as an invalid type); the output is read from its JSON form.
    String json = JSON.serialize(ConnectApi.Search.find(term));
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(json);
    Object groups = parsed.get('results');
    resultCount = groups instanceof List<Object> ? ((List<Object>) groups).size() : 0;
} catch (Exception e) {
    status = 'exception';
    errType = e.getTypeName();
    errMsg = e.getMessage();
}
Integer secs = Integer.valueOf((System.now().getTime() - t0) / 1000);
System.debug('BE47|door=2|target=ConnectApi.Search.find|status=' + status + '|errType=' + errType + '|errMsg=' + errMsg + '|resultCount=' + resultCount + '|summary=none-by-find|seconds=' + secs);
