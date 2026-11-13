// BE-32 direct path, brief. Prepended by run.py with: String RUNG; String QUESTION; String ACCOUNT;
// Calls the agent's own action class (CustomerSummaryGetAction), the same Apex the panel's getBrief
// runs (CustomerSummary.run). Each call writes one session row turn (the product's own memory).
// Prints one marker line of counts and booleans: no names, no Ids, no brief text.
List<String> labels = new List<String>{ 'Account', 'Open deals', 'People & engagement', 'Service health', 'Deal history', 'Watch next' };

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

Account acct = [SELECT Id FROM Account WHERE Name = :ACCOUNT WITH USER_MODE LIMIT 1];
CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
req.accountId = acct.Id;
req.userQuestion = QUESTION;
Long t0 = System.currentTimeMillis();
CustomerSummaryGetAction.Response r = CustomerSummaryGetAction.getBriefs(new List<CustomerSummaryGetAction.Request>{ req })[0];
Long ms = System.currentTimeMillis() - t0;
String text = r.answer == null ? '' : r.answer;

System.debug('BE32B|rung=' + RUNG
    + '|actionStatus=' + r.status
    + '|actionLen=' + text.length()
    + '|lines=' + text.split('\n').size()
    + '|labels=' + labelLines(text, labels)
    + '|labelsLineStart=' + labelsWhere(text, labels, true)
    + '|labelsAnywhere=' + labelsWhere(text, labels, false)
    + '|boldMarks=' + (text.length() - text.replace('**', '').length()) / 2
    + '|bulletLines=' + (text.split('\n- ', -1).size() - 1)
    + '|ms=' + ms);
