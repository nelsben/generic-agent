// BE-31: SOQL and SOSL rules checked against the platform, not from memory. Read-only.
// 'ORDER BY Description' on Case was dropped from the list: it throws System.UnexpectedException
// ("field 'Description' can not be sorted in a query call"), which no catch block stops, so it ends the run.
// Each probe prints OK with a row count, or the platform's exception type and the first words of its message.
Map<String, String> probes = new Map<String, String>{
    'semi-join alone' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Case WHERE IsClosed = false)',
    'semi-join OR plain condition' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Case) OR Type = \'Prospect\'',
    'semi-join AND (plain OR plain)' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Case) AND (Type = \'Prospect\' OR Industry = \'Energy\')',
    'two semi-joins' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Case) AND Id IN (SELECT AccountId FROM Opportunity)',
    'three semi-joins' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Case) AND Id IN (SELECT AccountId FROM Opportunity) AND Id IN (SELECT AccountId FROM Contact)',
    'nested semi-join' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN (SELECT OpportunityId FROM OpportunityContactRole))',
    'NOT around a semi-join' => 'SELECT Id FROM Account WHERE NOT (Id IN (SELECT AccountId FROM Case))',
    'anti-join' => 'SELECT Id FROM Account WHERE Id NOT IN (SELECT AccountId FROM Opportunity)',
    'semi-join on Task.AccountId' => 'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Task)',
    'semi-join on Task.WhatId' => 'SELECT Id FROM Account WHERE Id IN (SELECT WhatId FROM Task)',
    'anti-join on Task with date' => 'SELECT Id FROM Account WHERE Id NOT IN (SELECT WhatId FROM Task WHERE ActivityDate = LAST_N_DAYS:30)',
    'semi-join on Event.WhatId' => 'SELECT Id FROM Account WHERE Id IN (SELECT WhatId FROM Event)',
    'semi-join with left side a parent path' => 'SELECT Id FROM Contact WHERE Account.Id IN (SELECT AccountId FROM Case)',
    'semi-join on a lookup (not Id)' => 'SELECT Id FROM Contact WHERE AccountId IN (SELECT AccountId FROM Case WHERE IsClosed = false)',
    'semi-join same object' => 'SELECT Id FROM Account WHERE Id IN (SELECT ParentId FROM Account)',
    'semi-join inside OR group' => 'SELECT Id FROM Account WHERE (Id IN (SELECT AccountId FROM Case) OR Industry = \'Energy\') AND Type = \'Prospect\'',
    'parent path depth 2' => 'SELECT Account.Owner.Name FROM Contact',
    'parent path depth 3' => 'SELECT Account.Owner.Manager.Name FROM Contact',
    'parent path depth 5' => 'SELECT Contact.Account.Owner.Manager.CreatedBy.Name FROM OpportunityContactRole',
    'parent path depth 6' => 'SELECT Contact.Account.Owner.Manager.CreatedBy.Manager.Name FROM OpportunityContactRole',
    'filter on depth-2 path' => 'SELECT Id FROM Case WHERE Account.Owner.IsActive = true',
    'child subquery' => 'SELECT Id, (SELECT Id FROM Cases WHERE IsClosed = false LIMIT 5) FROM Account',
    'child subquery with aggregate' => 'SELECT Id, (SELECT COUNT(Id) FROM Cases) FROM Account',
    'child subquery two levels' => 'SELECT Id, (SELECT Id, (SELECT Id FROM OpportunityContactRoles) FROM Opportunities) FROM Account',
    'child subquery on activities' => 'SELECT Id, (SELECT Id FROM ActivityHistories LIMIT 5) FROM Account LIMIT 5',
    'long text in WHERE' => 'SELECT Id FROM Case WHERE Description LIKE \'%refund%\'',
    'polymorphic TYPEOF' => 'SELECT TYPEOF What WHEN Account THEN Industry END FROM Task',
    'GROUP BY ROLLUP' => 'SELECT StageName, COUNT(Id) FROM Opportunity GROUP BY ROLLUP(StageName)',
    'HAVING' => 'SELECT AccountId, COUNT(Id) FROM Opportunity GROUP BY AccountId HAVING COUNT(Id) > 3'
};
for (String label : probes.keySet()) {
    try {
        Integer n = Database.query(probes.get(label), AccessLevel.USER_MODE).size();
        System.debug(LoggingLevel.ERROR, 'RULE :: ' + label + ' :: OK rows=' + n);
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'RULE :: ' + label + ' :: ' + e.getTypeName() + ': ' + e.getMessage().replaceAll('\\s+', ' ').left(110));
    }
}
// Binds inside a semi-join subquery and inside a child subquery.
try {
    Map<String, Object> b = new Map<String, Object>{ 'b0' => false, 'b1' => 'Prospect' };
    Integer n = Database.queryWithBinds('SELECT Id, (SELECT Id FROM Cases WHERE IsClosed = :b0) FROM Account WHERE Id IN (SELECT AccountId FROM Case WHERE IsClosed = :b0) AND Type = :b1', b, AccessLevel.USER_MODE).size();
    System.debug(LoggingLevel.ERROR, 'RULE :: binds in semi-join and child subquery :: OK rows=' + n);
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'RULE :: binds in semi-join and child subquery :: ' + e.getTypeName() + ': ' + e.getMessage().left(110));
}
// SOSL in user mode, with the term escaped (SOSL has no bind variables in dynamic Search.query).
for (String term : new List<String>{ 'router', 'refund', 'calibration' }) {
    try {
        String safe = String.escapeSingleQuotes(term).replaceAll('([?&|!{}\\[\\]()^~*:\\\\"+-])', '\\\\$1');
        List<List<SObject>> r = Search.query('FIND \'' + safe + '\' IN ALL FIELDS RETURNING Case(Id), Task(Id), Opportunity(Id) LIMIT 50', AccessLevel.USER_MODE);
        System.debug(LoggingLevel.ERROR, 'RULE :: SOSL user mode term#' + term.length() + ' :: OK case=' + r[0].size() + ' task=' + r[1].size() + ' opp=' + r[2].size());
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'RULE :: SOSL user mode :: ' + e.getTypeName() + ': ' + e.getMessage().left(110));
    }
}
// Which long-text fields in the core objects hold any text (a positive case for the long-text questions).
for (String o : new List<String>{ 'Account', 'Opportunity', 'Case', 'Task', 'Event', 'Contact' }) {
    Integer withText = 0, total = 0;
    for (SObject r : Database.query('SELECT Description FROM ' + o + ' LIMIT 2000', AccessLevel.USER_MODE)) {
        total++;
        if (String.isNotBlank((String) r.get('Description'))) withText++;
    }
    System.debug(LoggingLevel.ERROR, 'RULE :: long text ' + o + '.Description :: ' + withText + ' of ' + total + ' have text');
}
// Custom objects in the org: API names and row counts only.
for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
    Schema.DescribeSObjectResult d = t.getDescribe(SObjectDescribeOptions.DEFERRED);
    if (d.isCustom() && d.getName().endsWith('__c')) {
        Integer n = d.isQueryable() && d.isAccessible() ? Database.countQuery('SELECT COUNT() FROM ' + d.getName() + ' LIMIT 50000', AccessLevel.USER_MODE) : -1;
        System.debug(LoggingLevel.ERROR, 'RULE :: custom object ' + d.getName() + ' :: rows=' + n);
    }
}
