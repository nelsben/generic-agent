// BE-44: does SOSL find words in seed-data long text, in user mode and in system mode? Read-only: no DML.
// Prints counts only, never Ids or text. Run: sf apex run -o agent-probe -f spikes/explorer-scale/sosl-proof.apex
//
// For each term and object it prints:
//   hand   = rows whose Description holds the term (SOQL in user mode, matched in Apex, ignoring case)
//   user   = rows SOSL returns in user mode, and how many of those hold the term in Description
//   system = the same in system mode
//   age    = hours since the newest row holding the term was last modified (the search index wait)
// A control term from a Name field shows whether the index answers at all.

Map<String, List<String>> terms = new Map<String, List<String>>{
    'Account' => new List<String>{ 'renewal', 'telecom', 'support' },
    'Event' => new List<String>{ 'pricing', 'router', 'renewal' }
};

String esc(String term) {
    return String.escapeSingleQuotes(term).replaceAll('([?&|!{}\\[\\]()^~*:\\\\"+-])', '\\\\$1');
}

Integer holding(List<SObject> rows, String field, String term) {
    Integer n = 0;
    for (SObject r : rows) {
        Object v = r.get(field);
        if (v != null && String.valueOf(v).toLowerCase().contains(term.toLowerCase())) n++;
    }
    return n;
}

void search(String o, String term, String label, System.AccessLevel mode) {
    try {
        List<List<SObject>> res = Search.query('FIND \'' + esc(term) + '\' IN ALL FIELDS RETURNING ' + o + '(Id, Description) LIMIT 2000', mode);
        System.debug(LoggingLevel.ERROR, 'PROOF :: ' + o + ' "' + term + '" :: ' + label + ' rows=' + res[0].size()
            + ' holding=' + holding(res[0], 'Description', term));
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'PROOF :: ' + o + ' "' + term + '" :: ' + label + ' ' + e.getTypeName() + ': ' + e.getMessage().left(110));
    }
}

for (String o : terms.keySet()) {
    List<SObject> all = Database.query('SELECT Id, Description, LastModifiedDate FROM ' + o + ' LIMIT 2000', AccessLevel.USER_MODE);
    System.debug(LoggingLevel.ERROR, 'PROOF :: ' + o + ' :: rows visible=' + all.size());
    for (String term : terms.get(o)) {
        Integer hand = 0;
        Datetime newest;
        for (SObject r : all) {
            Object v = r.get('Description');
            if (v != null && String.valueOf(v).toLowerCase().contains(term)) {
                hand++;
                Datetime m = (Datetime) r.get('LastModifiedDate');
                if (newest == null || m > newest) newest = m;
            }
        }
        Long age = newest == null ? null : (Datetime.now().getTime() - newest.getTime()) / 3600000L;
        System.debug(LoggingLevel.ERROR, 'PROOF :: ' + o + ' "' + term + '" :: hand=' + hand + ' age_hours=' + age);
        search(o, term, 'user', AccessLevel.USER_MODE);
        search(o, term, 'system', AccessLevel.SYSTEM_MODE);
    }
}

// Control: a word from an Account name, which every search index covers.
List<Account> named = [SELECT Name FROM Account WHERE Name LIKE 'Edge%' WITH USER_MODE LIMIT 10];
System.debug(LoggingLevel.ERROR, 'PROOF :: Account name "Edge" :: hand=' + named.size());
for (Boolean userMode : new List<Boolean>{ true, false }) {
    try {
        List<List<SObject>> res = Search.query('FIND \'Edge\' IN NAME FIELDS RETURNING Account(Id) LIMIT 2000',
            userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE);
        System.debug(LoggingLevel.ERROR, 'PROOF :: Account name "Edge" :: ' + (userMode ? 'user' : 'system') + ' rows=' + res[0].size());
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'PROOF :: Account name "Edge" :: ' + e.getTypeName() + ': ' + e.getMessage().left(110));
    }
}

// Word versus substring: SOSL matches words, CONTAINS matches substrings. "renew" is inside "renewal".
for (String term : new List<String>{ 'renew', 'renew*' }) {
    try {
        String t = term.endsWith('*') ? esc(term.removeEnd('*')) + '*' : esc(term);
        List<List<SObject>> res = Search.query('FIND \'' + t + '\' IN ALL FIELDS RETURNING Account(Id, Description) LIMIT 2000', AccessLevel.USER_MODE);
        System.debug(LoggingLevel.ERROR, 'PROOF :: Account "' + term + '" :: user rows=' + res[0].size() + ' holding=' + holding(res[0], 'Description', 'renew'));
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'PROOF :: Account "' + term + '" :: ' + e.getTypeName() + ': ' + e.getMessage().left(110));
    }
}

// Part 2 (after the BE-44 deploy): the search path ExploreQuery takes past its scan cap, on the five long-text
// questions' values. ExploreQuery.searchTerm builds the search text; the hits are read again with SOQL in user
// mode and matched in Apex, as ExploreQuery does. "path" must equal "hand" from part 1 for each value.
Map<String, String> five = new Map<String, String>{
    'Account renewal' => 'Account', 'Event pricing' => 'Event', 'Account support plan' => 'Account',
    'Event router' => 'Event', 'Event renewal' => 'Event'
};
for (String k : five.keySet()) {
    String o = five.get(k);
    String value = k.substringAfter(' ');
    String term = ExploreQuery.searchTerm(value);
    List<SObject> hits = Search.query('FIND \'' + term + '\' IN ALL FIELDS RETURNING ' + o + '(Id) LIMIT 2000', AccessLevel.USER_MODE)[0];
    List<Id> ids = new List<Id>(new Map<Id, SObject>(hits).keySet());
    Integer path = holding(Database.queryWithBinds('SELECT Id, Description FROM ' + o + ' WHERE Id IN :ids',
        new Map<String, Object>{ 'ids' => ids }, AccessLevel.USER_MODE), 'Description', value);
    Integer hand = holding(Database.query('SELECT Id, Description FROM ' + o + ' LIMIT 2000', AccessLevel.USER_MODE), 'Description', value);
    System.debug(LoggingLevel.ERROR, 'PROOF :: path ' + k + ' :: search hits=' + hits.size() + ' path=' + path + ' hand=' + hand);
}
System.debug(LoggingLevel.ERROR, 'PROOF :: limits :: soql=' + Limits.getQueries() + ' sosl=' + Limits.getSoslQueries() + '/' + Limits.getLimitSoslQueries() + ' dml=' + Limits.getDmlStatements());
