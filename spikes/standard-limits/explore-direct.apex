// BE-32 direct path, explore. Prepended by run.py with: String RUNG; String QUESTION;
// Calls the agent's own action class (ExploreAction, the 5,900-character cap) and then the panel's
// Apex entry point (CustomerSummaryPanelController.explore, no cap: the panel renders the rows itself).
// No DML. Prints one marker line of counts and booleans: no names, no Ids, no answer text.
Set<String> names = new Set<String>();
for (Opportunity o : [SELECT Name FROM Opportunity WITH USER_MODE LIMIT 200]) {
    names.add(o.Name.length() > 37 ? o.Name.left(37) : o.Name);
}

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

Long t0 = System.currentTimeMillis();
ExploreAction.Request req = new ExploreAction.Request();
req.question = QUESTION;
ExploreAction.Response a = ExploreAction.explore(new List<ExploreAction.Request>{ req })[0];
Long actionMs = System.currentTimeMillis() - t0;
String at = a.answer == null ? '' : a.answer;
Integer aCols = headerCols(at);

t0 = System.currentTimeMillis();
DataExplorer.Result p = CustomerSummaryPanelController.explore(QUESTION, null, null);
Long panelMs = System.currentTimeMillis() - t0;
Integer pText = p.answer == null ? 0 : p.answer.trim().length();
Integer pShown = 0;
Integer pTotal = 0;
Integer pCols = 0;
Integer pTable = 0;
if (!p.resultSets.isEmpty()) {
    ExploreQuery.ResultSet rs = p.resultSets[p.resultSets.size() - 1];
    pShown = rs.rows.size();
    pTotal = rs.total;
    pCols = rs.columns.size();
    // The same plain-text table ExploreAction.compose writes, with every row and no cap.
    pTable = String.join(DataExplorer.headers(rs), ' | ').length() + 2;
    for (Map<String, Object> row : rs.rows) {
        List<String> cells = new List<String>();
        for (String c : rs.columns) {
            Object v = row.get(c);
            String cell = v == null ? '' : String.valueOf(v).replaceAll('\\s+', ' ');
            cells.add(cell.length() > 40 ? cell.left(37) + '...' : cell);
        }
        pTable += 1 + String.join(cells, ' | ').length();
    }
}

System.debug('BE32D|rung=' + RUNG
    + '|actionStatus=' + a.status
    + '|actionLen=' + at.length()
    + '|actionCols=' + aCols
    + '|actionRows=' + (aCols == 0 ? 0 : tableRows(at, aCols) - 1)
    + '|actionFooter=' + footer(at)
    + '|actionNames=' + namesIn(at, names)
    + '|actionMs=' + actionMs
    + '|panelStatus=' + p.status
    + '|panelTextLen=' + pText
    + '|panelCols=' + pCols
    + '|panelRows=' + pShown
    + '|panelTotal=' + pTotal
    + '|panelRenderedLen=' + (pText + pTable)
    + '|panelMs=' + panelMs);
