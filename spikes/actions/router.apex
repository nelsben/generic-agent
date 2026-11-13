// BE-22 router prototype (spike, never deployed). run.py puts a header in front and a mode file after it, and
// runs the whole thing as one anonymous Apex transaction in agent-probe.
// It is the shape the build card's CustomerSummaryActions takes, written as anonymous Apex:
//   classify(): one Models API call turns a sentence into an action and its fields, as JSON (the seam's provider
//               and model, called directly so the meter can read tokens; AgentLlm itself needs a deployed prompt file)
//   buildDraft(): resolves people and deals from the account in user mode, validates each field against describe,
//               and returns a draft. No DML.
//   commitDraft(): re-validates a draft that came back as JSON and writes it with AccessLevel.USER_MODE.
// Prints counts, timings, booleans and dates only: no names, no Ids, no record text.

public class Meter {
    public Integer calls = 0;
    public Integer inTok = 0;
    public Integer outTok = 0;
    public Long modelMs = 0;
    public Integer promptChars = 0;
    public String code = '';
}

public class DraftField {
    public String api;
    public String label;
    public String value;
    public DraftField(String api, String label, String value) {
        this.api = api;
        this.label = label;
        this.value = value;
    }
}

// What the panel shows on the draft card and sends back on Confirm. 'inputJson' is what the user (or the model) gave;
// commitDraft rebuilds from it, so a changed 'fields' list on the way back can do nothing on its own.
public class Draft {
    public String action;
    public String sobjectType;
    public String mode;               // create or update
    public Id accountId;
    public Id targetId;               // the record an update changes
    public String inputJson;          // JSON text: JSON.deserialize cannot fill an Object-typed member
    public List<DraftField> fields = new List<DraftField>();
    public List<String> missing = new List<String>();
    public List<String> unresolved = new List<String>();
    public List<String> warnings = new List<String>();
    public Map<String, String> previous = new Map<String, String>();
    public Boolean ready() {
        return missing.isEmpty() && unresolved.isEmpty() && warnings.isEmpty();
    }
}

String systemPrompt() {
    return String.join(new List<String>{
        'You turn one request from a salesperson into one CRM action. Reply with one JSON object and nothing else.',
        'Actions and their fields:',
        '- create_task: subject, dueDate (YYYY-MM-DD), priority (High, Normal or Low), contact (the person\'s name as said)',
        '- create_event: subject, startDateTime (YYYY-MM-DDTHH:MM, 24-hour local time), durationMinutes, contact',
        '- log_call: subject, description (what was said on the call), contact',
        '- update_contact: contact, changes (an object of field to new value; allowed fields: Title, Phone, MobilePhone, Email, Department)',
        '- create_case: subject, description, priority (High, Medium or Low), contact',
        '- update_opportunity: opportunity (the deal\'s name as said), changes (allowed fields: StageName, CloseDate as YYYY-MM-DD, NextStep, Amount as a number)',
        'If the request is a question, or anything that is not one of these actions, reply {"action":"none"}.',
        'Rules: use only what the request says and never invent a value. Leave out a field the request does not give, and list each required field it lacks in "missing". Work out relative dates from today\'s date. Keep names as said; do not look them up.',
        'Required: create_task subject and dueDate; create_event subject and startDateTime; log_call contact; update_contact contact and changes; create_case subject; update_opportunity opportunity and changes.',
        'Shape: {"action":"...","fields":{...},"missing":["..."]}'
    }, '\n');
}

String userPrompt(String request, String accountName) {
    Date today = Date.today();
    String weekday = Datetime.newInstance(today, Time.newInstance(12, 0, 0, 0)).format('EEEE');
    return 'Today is ' + String.valueOf(today) + ' (' + weekday + '). The open account is ' + accountName + '.\nRequest: ' + request;
}

// One model call through the Models API, metered. Same provider class and model as AgentLlmModelsApi.
String callModel(Meter m, String sys, String usr) {
    aiplatform.ModelsAPI_ChatMessageRequest s = new aiplatform.ModelsAPI_ChatMessageRequest();
    s.role = 'system';
    s.content = sys;
    aiplatform.ModelsAPI_ChatMessageRequest u = new aiplatform.ModelsAPI_ChatMessageRequest();
    u.role = 'user';
    u.content = usr;
    aiplatform.ModelsAPI_ChatGenerationsRequest body = new aiplatform.ModelsAPI_ChatGenerationsRequest();
    body.messages = new List<aiplatform.ModelsAPI_ChatMessageRequest>{ s, u };
    aiplatform.ModelsAPI.createChatGenerations_Request req = new aiplatform.ModelsAPI.createChatGenerations_Request();
    req.modelName = AgentLlmModelsApi.MODEL;
    req.body = body;
    Long t0 = System.currentTimeMillis();
    Object resp = new aiplatform.ModelsAPI().createChatGenerations(req);
    m.modelMs += System.currentTimeMillis() - t0;
    m.calls++;
    m.promptChars += sys.length() + usr.length();
    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(resp));
    Map<String, Object> det = (Map<String, Object>) ((Map<String, Object>) root.get('Code200')).get('generationDetails');
    try {
        Map<String, Object> usage = (Map<String, Object>) ((Map<String, Object>) ((Map<String, Object>) det.get('parameters')).get('properties')).get('usage');
        m.inTok += (Integer) usage.get('inputTokenCount');
        m.outTok += (Integer) usage.get('outputTokenCount');
    } catch (Exception e) {
        m.code = 'no-usage';
    }
    return (String) ((Map<String, Object>) ((List<Object>) det.get('generations'))[0]).get('content');
}

// The one JSON object in a reply, or null.
Map<String, Object> parseReply(String reply) {
    Integer a = reply == null ? -1 : reply.indexOf('{');
    Integer b = reply == null ? -1 : reply.lastIndexOf('}');
    if (a < 0 || b <= a) {
        return null;
    }
    try {
        return (Map<String, Object>) JSON.deserializeUntyped(reply.substring(a, b + 1));
    } catch (Exception e) {
        return null;
    }
}

String str(Map<String, Object> m, String key) {
    Object v = m == null ? null : m.get(key);
    return v == null ? null : String.valueOf(v).trim();
}

Map<String, Object> mapOf(Map<String, Object> m, String key) {
    Object v = m == null ? null : m.get(key);
    return v instanceof Map<String, Object> ? (Map<String, Object>) v : new Map<String, Object>();
}

// Which object each action writes. log_call is the open decision (F17): 'Event' as Ben said, or 'Task'.
String targetObject(String action, String logCallAs) {
    Map<String, String> m = new Map<String, String>{
        'create_task' => 'Task', 'create_event' => 'Event', 'log_call' => logCallAs,
        'update_contact' => 'Contact', 'create_case' => 'Case', 'update_opportunity' => 'Opportunity'
    };
    return m.get(action);
}

// One contact on the account whose first, last or full name matches the words, in user mode. Null when 0 or 2+.
Contact resolveContact(Id accountId, String words, Draft d) {
    if (String.isBlank(words)) {
        return null;
    }
    String w = words.toLowerCase().trim();
    List<Contact> hits = new List<Contact>();
    for (Contact c : [SELECT Id, FirstName, LastName, Title, Phone, MobilePhone, Email, Department FROM Contact
                      WHERE AccountId = :accountId WITH USER_MODE ORDER BY LastName LIMIT 200]) {
        String first = c.FirstName == null ? '' : c.FirstName.toLowerCase();
        String last = c.LastName == null ? '' : c.LastName.toLowerCase();
        if (w == first || w == last || w == (first + ' ' + last).trim()) {
            hits.add(c);
        }
    }
    if (hits.size() != 1) {
        d.unresolved.add('contact:' + (hits.isEmpty() ? 'none' : 'several'));
        return null;
    }
    return hits[0];
}

// One open opportunity on the account whose name contains the words, in user mode. Null when 0 or 2+.
Opportunity resolveOpportunity(Id accountId, String words, Draft d) {
    if (String.isBlank(words)) {
        return null;
    }
    String w = words.toLowerCase().replace('the ', '').trim();
    List<Opportunity> hits = new List<Opportunity>();
    for (Opportunity o : [SELECT Id, Name, StageName, CloseDate, NextStep, Amount FROM Opportunity
                          WHERE AccountId = :accountId AND IsClosed = false WITH USER_MODE LIMIT 200]) {
        if (o.Name.toLowerCase().contains(w)) {
            hits.add(o);
        }
    }
    if (hits.size() != 1) {
        d.unresolved.add('opportunity:' + (hits.isEmpty() ? 'none' : 'several'));
        return null;
    }
    return hits[0];
}

// Adds one field to the draft after checking, against the running user's describe, that it can be written and
// that a picklist value is one of the field's values.
void put(Draft d, String api, Object value) {
    if (value == null || (value instanceof String && String.isBlank((String) value))) {
        return;
    }
    Schema.SObjectField f = Schema.getGlobalDescribe().get(d.sobjectType).getDescribe().fields.getMap().get(api);
    if (f == null) {
        d.warnings.add('nofield:' + api);
        return;
    }
    Schema.DescribeFieldResult r = f.getDescribe();
    Boolean writable = d.mode == 'create' ? r.isCreateable() : r.isUpdateable();
    if (!writable) {
        d.warnings.add('readonly:' + api);
        return;
    }
    if (r.getType() == Schema.DisplayType.PICKLIST) {
        Set<String> allowed = new Set<String>();
        for (Schema.PicklistEntry p : r.getPicklistValues()) {
            if (p.isActive()) {
                allowed.add(p.getValue());
            }
        }
        if (!allowed.contains(String.valueOf(value))) {
            d.warnings.add('badvalue:' + api);
            return;
        }
    }
    d.fields.add(new DraftField(api, r.getLabel(), String.valueOf(value)));
}

Date toDate(String s, Draft d, String name) {
    if (String.isBlank(s)) {
        return null;
    }
    try {
        return Date.valueOf(s.left(10));
    } catch (Exception e) {
        d.warnings.add('baddate:' + name);
        return null;
    }
}

Datetime toDatetime(String s, Draft d, String name) {
    if (String.isBlank(s) || s.length() < 16) {
        if (String.isNotBlank(s)) {
            d.warnings.add('baddatetime:' + name);
        }
        return null;
    }
    try {
        Date day = Date.valueOf(s.left(10));
        Integer h = Integer.valueOf(s.substring(11, 13));
        Integer mi = Integer.valueOf(s.substring(14, 16));
        return Datetime.newInstance(day, Time.newInstance(h, mi, 0, 0));
    } catch (Exception e) {
        d.warnings.add('baddatetime:' + name);
        return null;
    }
}

// The draft step: no DML. Resolves names in the account, validates every field, and lists what is missing.
Draft buildDraft(String action, Id accountId, Map<String, Object> fields, String logCallAs) {
    Draft d = new Draft();
    d.action = action;
    d.accountId = accountId;
    Map<String, Object> f = fields == null ? new Map<String, Object>() : fields;
    d.inputJson = JSON.serialize(f);
    d.sobjectType = targetObject(action, logCallAs);
    d.mode = action.startsWith('update_') ? 'update' : 'create';
    if (action == 'create_task' || action == 'log_call' || action == 'create_event' || action == 'create_case') {
        Contact who = resolveContact(accountId, str(f, 'contact'), d);
        String whoField = d.sobjectType == 'Case' ? 'ContactId' : 'WhoId';
        if (who != null) {
            put(d, whoField, who.Id);
        }
        put(d, d.sobjectType == 'Case' ? 'AccountId' : 'WhatId', accountId);
    }
    if (action == 'create_task') {
        put(d, 'Subject', str(f, 'subject'));
        Date due = toDate(str(f, 'dueDate'), d, 'dueDate');
        put(d, 'ActivityDate', due == null ? null : String.valueOf(due));
        put(d, 'Priority', str(f, 'priority') == null ? 'Normal' : str(f, 'priority'));
        put(d, 'Status', 'Not Started');
        if (str(f, 'subject') == null) d.missing.add('subject');
        if (due == null) d.missing.add('dueDate');
    } else if (action == 'create_event') {
        put(d, 'Subject', str(f, 'subject'));
        Datetime start = toDatetime(str(f, 'startDateTime'), d, 'startDateTime');
        put(d, 'StartDateTime', start == null ? null : start.format('yyyy-MM-dd\'T\'HH:mm'));
        String minutes = str(f, 'durationMinutes');
        put(d, 'DurationInMinutes', minutes == null ? '30' : minutes);
        if (str(f, 'subject') == null) d.missing.add('subject');
        if (start == null) d.missing.add('startDateTime');
    } else if (action == 'log_call') {
        put(d, 'Subject', str(f, 'subject') == null ? 'Call' : str(f, 'subject'));
        put(d, 'Description', str(f, 'description'));
        if (d.sobjectType == 'Task') {
            // What Salesforce's own Log a Call saves: a completed Task with the Call subtype, dated today.
            put(d, 'TaskSubtype', 'Call');
            put(d, 'Status', 'Completed');
            put(d, 'ActivityDate', String.valueOf(Date.today()));
        } else {
            // An Event that ends now: a past calendar entry for a call that just happened.
            Datetime ended = Datetime.now();
            put(d, 'StartDateTime', ended.addMinutes(-15).format('yyyy-MM-dd\'T\'HH:mm'));
            put(d, 'DurationInMinutes', '15');
        }
        if (str(f, 'contact') == null) d.missing.add('contact');
    } else if (action == 'update_contact') {
        Contact c = resolveContact(accountId, str(f, 'contact'), d);
        Map<String, Object> changes = mapOf(f, 'changes');
        Set<String> allow = new Set<String>{ 'Title', 'Phone', 'MobilePhone', 'Email', 'Department' };
        if (c != null) {
            d.targetId = c.Id;
            for (String k : changes.keySet()) {
                if (!allow.contains(k)) {
                    d.warnings.add('notallowed:' + k);
                    continue;
                }
                d.previous.put(k, String.valueOf(c.get(k)));
                put(d, k, changes.get(k));
            }
        }
        if (str(f, 'contact') == null) d.missing.add('contact');
        if (changes.isEmpty()) d.missing.add('changes');
    } else if (action == 'create_case') {
        put(d, 'Subject', str(f, 'subject'));
        put(d, 'Description', str(f, 'description'));
        put(d, 'Priority', str(f, 'priority') == null ? 'Medium' : str(f, 'priority'));
        if (str(f, 'subject') == null) d.missing.add('subject');
    } else if (action == 'update_opportunity') {
        Opportunity o = resolveOpportunity(accountId, str(f, 'opportunity'), d);
        Map<String, Object> changes = mapOf(f, 'changes');
        Set<String> allow = new Set<String>{ 'StageName', 'CloseDate', 'NextStep', 'Amount' };
        if (o != null) {
            d.targetId = o.Id;
            for (String k : changes.keySet()) {
                if (!allow.contains(k)) {
                    d.warnings.add('notallowed:' + k);
                    continue;
                }
                Object v = changes.get(k);
                if (k == 'CloseDate') {
                    Date cd = toDate(String.valueOf(v), d, 'CloseDate');
                    v = cd == null ? null : String.valueOf(cd);
                }
                d.previous.put(k, String.valueOf(o.get(k)));
                put(d, k, v);
            }
        }
        if (str(f, 'opportunity') == null) d.missing.add('opportunity');
        if (changes.isEmpty()) d.missing.add('changes');
    }
    return d;
}

// The value a draft field holds, typed for its sObject field.
Object typed(String sobjectType, String api, String value) {
    Schema.DisplayType t = Schema.getGlobalDescribe().get(sobjectType).getDescribe().fields.getMap().get(api).getDescribe().getType();
    if (t == Schema.DisplayType.DATE) return Date.valueOf(value);
    if (t == Schema.DisplayType.DATETIME) {
        Date day = Date.valueOf(value.left(10));
        return Datetime.newInstance(day, Time.newInstance(Integer.valueOf(value.substring(11, 13)), Integer.valueOf(value.substring(14, 16)), 0, 0));
    }
    if (t == Schema.DisplayType.INTEGER) return Integer.valueOf(value);
    if (t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.PERCENT) return Decimal.valueOf(value);
    if (t == Schema.DisplayType.REFERENCE || t == Schema.DisplayType.ID) return Id.valueOf(value);
    return value;
}

// Confirm: the draft comes back as JSON. It is rebuilt from its input (so names, allow-lists and describe checks run
// again in this transaction) and written with AccessLevel.USER_MODE. Returns the saved record's Id.
Id commitDraft(String draftJson, String logCallAs) {
    Draft sent = (Draft) JSON.deserialize(draftJson, Draft.class);
    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(sent.inputJson);
    Draft d = buildDraft(sent.action, sent.accountId, input, logCallAs);
    if (!d.ready()) {
        throw new IllegalArgumentException('draft not ready');
    }
    SObject rec = Schema.getGlobalDescribe().get(d.sobjectType).newSObject(d.targetId);
    for (DraftField f : d.fields) {
        rec.put(f.api, typed(d.sobjectType, f.api, f.value));
    }
    if (d.mode == 'create') {
        return Database.insert(rec, true, AccessLevel.USER_MODE).getId();
    }
    return Database.update(rec, true, AccessLevel.USER_MODE).getId();
}
