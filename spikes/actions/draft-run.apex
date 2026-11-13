// BE-22 draft path, one request. run.py puts router.apex and a header in front: String REQ_ID; String REQUEST;
// String ACCOUNT. One model call, then the draft step. No DML, no savepoint (a savepoint before a callout is
// uncommitted work). Prints one marker line of codes, counts, timings and dates.
Account acct = [SELECT Id, Name FROM Account WHERE Name = :ACCOUNT WITH USER_MODE LIMIT 1];
Set<String> actions = new Set<String>{ 'create_task', 'create_event', 'log_call', 'update_contact', 'create_case', 'update_opportunity' };

Meter m = new Meter();
String reply;
String err = '';
try {
    reply = callModel(m, systemPrompt(), userPrompt(REQUEST, acct.Name));
} catch (Exception e) {
    err = e.getTypeName();
}
Map<String, Object> parsed = parseReply(reply);
String action = parsed == null ? 'unparsed' : str(parsed, 'action');
List<String> modelMissing = new List<String>();
if (parsed != null && parsed.get('missing') instanceof List<Object>) {
    for (Object o : (List<Object>) parsed.get('missing')) {
        modelMissing.add(String.valueOf(o));
    }
}

Integer cpu0 = Limits.getCpuTime();
Integer q0 = Limits.getQueries();
Long t0 = System.currentTimeMillis();
Draft d = actions.contains(action) ? buildDraft(action, acct.Id, mapOf(parsed, 'fields'), 'Event') : null;
Long draftMs = System.currentTimeMillis() - t0;

String dateValue = 'none';
Boolean contactResolved = false;
Boolean targetResolved = false;
if (d != null) {
    for (DraftField f : d.fields) {
        if (f.api == 'ActivityDate' || f.api == 'StartDateTime' || f.api == 'CloseDate') {
            dateValue = f.value.left(10);
            if (f.api == 'StartDateTime') {
                dateValue += 'T' + f.value.substring(11, 16);
            }
        }
        if (f.api == 'WhoId' || f.api == 'ContactId') {
            contactResolved = true;
        }
    }
    targetResolved = d.targetId != null;
}

// What the model put in 'contact' when the request named nobody: its shape only, never the text.
String contactWords = str(mapOf(parsed, 'fields'), 'contact');
String contactShape = contactWords == null ? 'absent' : (String.isBlank(contactWords) ? 'blank'
    : (new Set<String>{ 'null', 'none', 'unknown', 'n/a' }.contains(contactWords.toLowerCase()) ? 'placeholder:' + contactWords.toLowerCase() : 'words:' + contactWords.split(' ').size()));

List<String> parts = new List<String>{
    'id=' + REQ_ID,
    'err=' + err,
    'action=' + action,
    'modelMs=' + m.modelMs,
    'inTok=' + m.inTok,
    'outTok=' + m.outTok,
    'promptChars=' + m.promptChars,
    'replyChars=' + (reply == null ? 0 : reply.length()),
    'draftMs=' + draftMs,
    'draftCpu=' + (Limits.getCpuTime() - cpu0),
    'draftSoql=' + (Limits.getQueries() - q0),
    'dml=' + Limits.getDmlStatements(),
    'fields=' + (d == null ? 0 : d.fields.size()),
    'missing=' + (d == null ? '' : String.join(d.missing, ',')),
    'modelMissing=' + String.join(modelMissing, ','),
    'unresolved=' + (d == null ? '' : String.join(d.unresolved, ',')),
    'warnings=' + (d == null ? '' : String.join(d.warnings, ',')),
    'ready=' + (d == null ? 'n/a' : String.valueOf(d.ready())),
    'contactResolved=' + contactResolved,
    'targetResolved=' + targetResolved,
    'contactShape=' + contactShape,
    'date=' + dateValue,
    'orgToday=' + String.valueOf(Date.today()),
    'draftJsonChars=' + (d == null ? 0 : JSON.serialize(d).length())
};
System.debug(LoggingLevel.ERROR, 'BE22D|' + String.join(parts, '|').replace('\n', ' '));
