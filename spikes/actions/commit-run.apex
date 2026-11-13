// BE-22 confirm path. run.py puts router.apex and a header in front: String ACCOUNT. No callout in this run.
// Everything happens inside one savepoint and is rolled back. The two updates change only records this run
// inserted inside the same savepoint (never an existing record). Each action: the draft built from the fields a chip
// or an edited draft card sends (no model), serialized as the panel would receive it, then committed from that JSON
// with AccessLevel.USER_MODE. An update is then undone from the previous values its draft carried.
// Prints one marker line per action and one for the activity check: codes, counts, timings and booleans only.
Account acct = [SELECT Id, Name FROM Account WHERE Name = :ACCOUNT WITH USER_MODE LIMIT 1];
Date today = Date.today();
String tomorrow2pm = String.valueOf(today.addDays(1)) + 'T14:00';

List<List<Object>> cases = new List<List<Object>>{
    new List<Object>{ 'task', 'create_task', 'Event', new Map<String, Object>{ 'subject' => 'BE22 spike follow-up', 'dueDate' => String.valueOf(today.addDays(4)), 'priority' => 'High', 'contact' => 'Marlowe' } },
    new List<Object>{ 'event', 'create_event', 'Event', new Map<String, Object>{ 'subject' => 'BE22 spike meeting', 'startDateTime' => tomorrow2pm, 'durationMinutes' => 30, 'contact' => 'Tessaly' } },
    new List<Object>{ 'callAsEvent', 'log_call', 'Event', new Map<String, Object>{ 'subject' => 'BE22 spike call', 'description' => 'Budget confirmed.', 'contact' => 'Percival' } },
    new List<Object>{ 'callAsTask', 'log_call', 'Task', new Map<String, Object>{ 'subject' => 'BE22 spike call', 'description' => 'Budget confirmed.', 'contact' => 'Percival' } },
    new List<Object>{ 'contact', 'update_contact', 'Event', new Map<String, Object>{ 'contact' => 'Be22spike', 'changes' => new Map<String, Object>{ 'Title' => 'BE22 spike title' } } },
    new List<Object>{ 'case', 'create_case', 'Event', new Map<String, Object>{ 'subject' => 'BE22 spike case', 'priority' => 'High', 'contact' => 'Isolde' } },
    new List<Object>{ 'opp', 'update_opportunity', 'Event', new Map<String, Object>{ 'opportunity' => 'BE22 throwaway', 'changes' => new Map<String, Object>{ 'NextStep' => 'BE22 legal review', 'CloseDate' => String.valueOf(today.addDays(60)) } } }
};

Map<String, Id> saved = new Map<String, Id>();
List<String> lines = new List<String>();
Savepoint sp = Database.setSavepoint();
try {
    // Throwaway targets for the two updates, inserted inside the savepoint.
    Database.insert(new Contact(FirstName = 'Throwaway', LastName = 'Be22spike', AccountId = acct.Id), true, AccessLevel.USER_MODE);
    Database.insert(new Opportunity(Name = 'BE22 throwaway deal', StageName = 'Prospecting', CloseDate = today.addDays(30), AccountId = acct.Id), true, AccessLevel.USER_MODE);

    for (List<Object> c : cases) {
        String label = (String) c[0];
        String action = (String) c[1];
        String logCallAs = (String) c[2];
        Map<String, Object> fields = (Map<String, Object>) c[3];

        Integer q0 = Limits.getQueries();
        Long t0 = System.currentTimeMillis();
        Draft d = buildDraft(action, acct.Id, fields, logCallAs);
        String draftJson = JSON.serialize(d);
        Long draftMs = System.currentTimeMillis() - t0;
        Integer draftSoql = Limits.getQueries() - q0;

        Integer dml0 = Limits.getDmlStatements();
        q0 = Limits.getQueries();
        Long t1 = System.currentTimeMillis();
        String err = '';
        Id rid;
        try {
            rid = commitDraft(draftJson, logCallAs);
        } catch (Exception e) {
            err = e.getTypeName();
        }
        Long commitMs = System.currentTimeMillis() - t1;
        Integer commitDml = Limits.getDmlStatements() - dml0;
        Integer commitSoql = Limits.getQueries() - q0;
        saved.put(label, rid);

        String undo = 'n/a';
        Long undoMs = 0;
        if (rid != null && d.mode == 'update') {
            Long t2 = System.currentTimeMillis();
            SObject back = Schema.getGlobalDescribe().get(d.sobjectType).newSObject(rid);
            for (String k : d.previous.keySet()) {
                String v = d.previous.get(k);
                back.put(k, v == null || v == 'null' ? null : typed(d.sobjectType, k, v));
            }
            try {
                Database.update(back, true, AccessLevel.USER_MODE);
                undo = 'ok';
            } catch (Exception e) {
                undo = e.getTypeName();
            }
            undoMs = System.currentTimeMillis() - t2;
        }
        lines.add('BE22C|id=' + label + '|action=' + action + '|object=' + d.sobjectType + '|ready=' + d.ready()
            + '|missing=' + String.join(d.missing, ',') + '|unresolved=' + String.join(d.unresolved, ',') + '|warnings=' + String.join(d.warnings, ',')
            + '|fields=' + d.fields.size() + '|draftMs=' + draftMs + '|draftSoql=' + draftSoql + '|draftJsonChars=' + draftJson.length()
            + '|err=' + err + '|saved=' + (rid != null) + '|commitMs=' + commitMs + '|commitDml=' + commitDml + '|commitSoql=' + commitSoql
            + '|undo=' + undo + '|undoMs=' + undoMs);
    }

    // Where the two Log a Call shapes land on the account's activity lists (what the activity timeline reads).
    Set<Id> ids = new Set<Id>();
    for (Id i : saved.values()) {
        if (i != null) ids.add(i);
    }
    Account withActs = [SELECT Id,
            (SELECT Id, IsTask, ActivitySubtype FROM ActivityHistories ORDER BY ActivityDate DESC, LastModifiedDate DESC LIMIT 500),
            (SELECT Id, IsTask, ActivitySubtype FROM OpenActivities ORDER BY ActivityDate ASC, LastModifiedDate DESC LIMIT 500)
        FROM Account WHERE Id = :acct.Id WITH USER_MODE];
    Map<Id, String> placedBy = new Map<Id, String>();
    for (ActivityHistory h : withActs.ActivityHistories) {
        if (ids.contains(h.Id)) placedBy.put(h.Id, 'history:' + h.ActivitySubtype);
    }
    for (OpenActivity o : withActs.OpenActivities) {
        if (ids.contains(o.Id)) placedBy.put(o.Id, 'open:' + o.ActivitySubtype);
    }
    List<String> placed = new List<String>();
    for (String label : new List<String>{ 'task', 'event', 'callAsEvent', 'callAsTask' }) {
        Id i = saved.get(label);
        placed.add(label + 'List=' + (i == null ? 'unsaved' : (placedBy.containsKey(i) ? placedBy.get(i) : 'neither')));
    }
    Id callTask = saved.get('callAsTask');
    String taskShape = 'unsaved';
    if (callTask != null) {
        Task t = [SELECT IsClosed, Status, TaskSubtype, ActivityDate FROM Task WHERE Id = :callTask WITH USER_MODE];
        taskShape = 'closed=' + t.IsClosed + ',status=' + t.Status + ',subtype=' + t.TaskSubtype + ',dueToday=' + (t.ActivityDate == today);
    }
    Id callEvent = saved.get('callAsEvent');
    String eventShape = 'unsaved';
    if (callEvent != null) {
        Event e = [SELECT StartDateTime, EndDateTime, DurationInMinutes, EventSubtype FROM Event WHERE Id = :callEvent WITH USER_MODE];
        eventShape = 'endsByNow=' + (e.EndDateTime <= Datetime.now().addMinutes(1)) + ',minutes=' + e.DurationInMinutes + ',subtype=' + e.EventSubtype;
    }
    lines.add('BE22C|id=activity|' + String.join(placed, '|') + '|callAsTask=' + taskShape + '|callAsEvent=' + eventShape);
} finally {
    Database.rollback(sp);
}

// After the rollback nothing this run wrote is left.
Integer remaining = [SELECT COUNT() FROM Task WHERE Subject LIKE 'BE22 spike%' WITH USER_MODE]
    + [SELECT COUNT() FROM Event WHERE Subject LIKE 'BE22 spike%' WITH USER_MODE]
    + [SELECT COUNT() FROM Case WHERE Subject LIKE 'BE22 spike%' WITH USER_MODE]
    + [SELECT COUNT() FROM Contact WHERE LastName = 'Be22spike' WITH USER_MODE]
    + [SELECT COUNT() FROM Opportunity WHERE Name LIKE 'BE22 throwaway%' WITH USER_MODE];
lines.add('BE22C|id=afterRollback|left=' + remaining);
for (String l : lines) {
    System.debug(LoggingLevel.ERROR, l);
}
