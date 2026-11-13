// BE-32 agent path: one first turn of the active Customer_Summary agent through the
// generateAiAgentResponse invocable action, on a new session. Prepended by run.py with:
// String RUNG; String QUESTION;
// No DML here (a brief turn makes the agent's own action write one session row). Prints one marker
// line of counts and booleans: no names, no Ids, no reply text, no session Id.
Set<String> names = new Set<String>();
for (Opportunity o : [SELECT Name FROM Opportunity WITH USER_MODE LIMIT 200]) {
    names.add(o.Name.length() > 37 ? o.Name.left(37) : o.Name);
}
List<String> labels = new List<String>{ 'Account', 'Open deals', 'People & engagement', 'Service health', 'Deal history', 'Watch next' };

Integer pipes(String line) {
    return line.length() - line.replace('|', '').length();
}

// A plain table line has cols - 1 pipes; a markdown one starts with a pipe and has cols + 1.
Integer tableRows(String text, Integer cols) {
    Integer n = 0;
    for (String line : text.split('\n')) {
        String t = line.trim();
        if (t.contains('---')) {
            continue;
        }
        Integer p = pipes(t);
        if ((p == cols - 1 && !t.startsWith('|')) || (p == cols + 1 && t.startsWith('|'))) {
            n++;
        }
    }
    return n;
}

Integer headerCols(String text) {
    for (String line : text.split('\n')) {
        String t = line.trim();
        if (t.contains(' | ')) {
            return t.startsWith('|') ? pipes(t) - 1 : pipes(t) + 1;
        }
    }
    return 0;
}

String footer(String text) {
    Matcher m = Pattern.compile('\\((\\d+) of (\\d+) rows\\)').matcher(text);
    return m.find() ? m.group(1) + '/' + m.group(2) : 'none';
}

Integer namesIn(String text, Set<String> names) {
    Integer n = 0;
    for (String s : names) {
        if (text.contains(s)) {
            n++;
        }
    }
    return n;
}

Integer labelLines(String text, List<String> labels) {
    Set<String> lines = new Set<String>();
    for (String line : text.split('\n')) {
        lines.add(line.trim().removeEnd(':'));
    }
    Integer n = 0;
    for (String l : labels) {
        if (lines.contains(l)) {
            n++;
        }
    }
    return n;
}

// Where each section label sits: anywhere in the text, or at the start of a line (with or without
// markdown bold or a heading mark). Tells a reformatted section from a dropped one.
Integer labelsWhere(String text, List<String> labels, Boolean lineStart) {
    Integer n = 0;
    for (String l : labels) {
        Boolean hit = false;
        for (String line : text.split('\n')) {
            String t = line.trim().removeStart('#').removeStart('#').trim().removeStart('**').trim();
            if (lineStart ? t.startsWith(l) : line.contains(l)) {
                hit = true;
            }
        }
        if (hit) {
            n++;
        }
    }
    return n;
}

Invocable.Action act = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Customer_Summary');
act.setInvocationParameter('userMessage', QUESTION);
Long t0 = System.currentTimeMillis();
String ok = 'false';
String raw = '';
String err = 'none';
try {
    Invocable.Action.Result r = act.invoke()[0];
    ok = String.valueOf(r.isSuccess());
    Object o = r.getOutputParameters().get('agentResponse');
    raw = o == null ? '' : String.valueOf(o);
    if (r.getErrors() != null && !r.getErrors().isEmpty()) {
        err = 'action-error';
    }
} catch (Exception e) {
    err = e.getTypeName();
}
Long ms = System.currentTimeMillis() - t0;

// The reply comes as {"type":"Text","value":"..."}; count the text inside, not the JSON escaping.
String text = raw;
String envelope = 'none';
try {
    Object parsed = JSON.deserializeUntyped(raw);
    if (parsed instanceof Map<String, Object>) {
        Map<String, Object> m = (Map<String, Object>) parsed;
        envelope = String.valueOf(m.get('type'));
        text = m.get('value') == null ? '' : String.valueOf(m.get('value'));
    }
} catch (Exception e) {
    envelope = 'not-json';
}
Integer cols = headerCols(text);
String lower = text.toLowerCase();

System.debug('BE32A|rung=' + RUNG
    + '|ok=' + ok
    + '|err=' + err
    + '|envelope=' + envelope
    + '|rawLen=' + raw.length()
    + '|replyLen=' + text.length()
    + '|lines=' + text.split('\n').size()
    + '|cols=' + cols
    + '|rows=' + (cols == 0 ? 0 : tableRows(text, cols) - 1)
    + '|markdownTable=' + text.contains('|---')
    + '|footer=' + footer(text)
    + '|names=' + namesIn(text, names)
    + '|labels=' + labelLines(text, labels)
    + '|labelsLineStart=' + labelsWhere(text, labels, true)
    + '|labelsAnywhere=' + labelsWhere(text, labels, false)
    + '|boldMarks=' + (text.length() - text.replace('**', '').length()) / 2
    + '|bulletLines=' + (text.split('\n- ', -1).size() - 1)
    + '|endsWithQuestion=' + text.trim().endsWith('?')
    + '|fallbackLine=' + (lower.contains('something went wrong') || lower.contains('i can brief you on an account'))
    + '|ms=' + ms);
