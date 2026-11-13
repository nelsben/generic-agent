// BE-31 engine 'current': a replay of DataExplorer.run (same prompt file, catalog, ExplorePlan, ExploreQuery,
// caps and feedback lines) with each model call metered. Only the loop is copied; every check and query
// is the deployed code.
Meter m = new Meter();
Outcome o = new Outcome();
Long t0 = System.currentTimeMillis();
String raw = [SELECT Body FROM StaticResource WHERE Name = 'AgentPrompt_Explore' LIMIT 1].Body.toString();
String sysT = raw.substringBetween('---system---', '---user---').trim() + '\n\n' + (BrandSettings.promptLines() ?? '');
String usrT = raw.substringAfter('---user---').trim();
Map<String, String> vars = new Map<String, String>{
    'catalog' => ExploreCatalog.describeForPrompt(),
    'date_literals' => String.join(ExplorePlan.DATE_LITERALS, ', ') + ', ' + String.join(ExplorePlan.DATE_LITERALS_N, ':n, ') + ':n',
    'context' => '(none)', 'history' => '(none)', 'question' => QUESTION
};
List<String> turns = new List<String>();
List<ExploreQuery.ResultSet> sets = new List<ExploreQuery.ResultSet>();
Integer queries = 0;
Boolean answered = false;
try {
    for (Integer turn = 1; turn <= 5 && !answered; turn++) {
        vars.put('turns', turns.isEmpty() ? '(none)' : String.join(turns, '\n\n'));
        vars.put('queries_left', String.valueOf(4 - queries));
        String reply = callModel(m, fillPrompt(sysT, vars), fillPrompt(usrT, vars));
        Map<String, Object> msg = parseReply(reply);
        String outcome;
        String action = msg != null && msg.get('action') instanceof String ? ((String) msg.get('action')).trim().toLowerCase() : null;
        if (msg == null) {
            outcome = 'INVALID: the reply was not one JSON object.';
        } else if (action == 'answer' && String.isNotBlank(String.valueOf(msg.get('text') ?? ''))) {
            o.answer = String.valueOf(msg.get('text'));
            answered = true;
            break;
        } else if (action != 'query') {
            outcome = 'INVALID: "action" must be "query" or "answer".';
        } else if (queries >= 4) {
            outcome = 'INVALID: no queries left; reply with an answer.';
        } else {
            ExplorePlan plan = ExplorePlan.fromObject(msg.get('plan'));
            List<String> errors = ExplorePlan.validate(plan);
            if (!errors.isEmpty()) {
                outcome = 'INVALID: ' + String.join(errors, ' ');
            } else {
                try {
                    queries++;
                    ExploreQuery.ResultSet rs = ExploreQuery.run(plan);
                    sets.add(rs);
                    m.objects.add(rs.objectName);
                    List<String> lines = new List<String>{ String.join(DataExplorer.headers(rs), ' | ') };
                    for (Integer i = 0; i < Math.min(20, rs.rows.size()); i++) {
                        List<String> cells = new List<String>();
                        for (String c : rs.columns) {
                            Object v = rs.rows[i].get(c);
                            cells.add(v == null ? '' : String.valueOf(v).replaceAll('\\s+', ' ').abbreviate(80));
                        }
                        lines.add(String.join(cells, ' | '));
                    }
                    outcome = 'RESULT ' + rs.objectName + ' rows=' + rs.shown + ' total=' + rs.total + '\n' + String.join(lines, '\n');
                } catch (Exception e) {
                    outcome = 'INVALID: ' + e.getMessage();
                }
            }
        }
        if (outcome.startsWith('INVALID')) {
            m.invalid++;
        }
        turns.add('[' + turn + '] reply: ' + reply.replaceAll('\\s+', ' ').abbreviate(1500) + '\n[' + turn + '] ' + outcome);
    }
    Boolean anyRows = false;
    for (ExploreQuery.ResultSet rs : sets) {
        anyRows = anyRows || rs.shown > 0;
    }
    o.status = answered || !sets.isEmpty() ? (anyRows ? 'OK' : 'EMPTY') : 'ERROR';
} catch (Exception e) {
    o.status = 'ERROR';
    m.codes.add('model:' + e.getTypeName());
}
Long wall = System.currentTimeMillis() - t0;
Integer soqlCount = Limits.getQueries(), cpu = Limits.getCpuTime(), heap = Limits.getHeapSize(), rows = Limits.getQueryRows();
o.sets = sets.size();
o.queries = queries;
if (!sets.isEmpty()) {
    o.lastRows = sets[sets.size() - 1].rows;
    o.lastTotal = sets[sets.size() - 1].total;
}
report(QID, 'current', REF, o, m, soqlCount, cpu, heap, rows, wall);
