// BE-31 engine 'v2': the same loop, caps and feedback as engine-current, with the prototype's catalog
// (describe-driven, deny list, pruned per question) and plan grammar. The deployed prompt is reused;
// only the PLAN grammar section and rules 1 and 2 are swapped.
Meter m = new Meter();
Outcome o = new Outcome();
Long t0 = System.currentTimeMillis();
Cat cat = new Cat();
String raw = [SELECT Body FROM StaticResource WHERE Name = 'AgentPrompt_Explore' LIMIT 1].Body.toString();
String sysT = raw.substringBetween('---system---', '---user---').trim() + '\n\n' + (BrandSettings.promptLines() ?? '');
String grammar = 'PLAN is a JSON object with these keys:\n'
    + '- "object": one object name from the catalog.\n'
    + '- "fields": field paths, e.g. ["Name","Amount","Account.Name","Account.Owner.Name"]. A path follows at most two lookups, using the names after "lookups:".\n'
    + '- "where": one condition, or a group {"and":[...]}, {"or":[...]} or {"not":...} of conditions and groups, at most 4 deep and 20 conditions in all.\n'
    + '  - A condition is {"field":"...","op":"...","value":...}. op is one of = != < <= > >= LIKE IN, NOT IN, CONTAINS.\n'
    + '  - IN and NOT IN take a list. LIKE takes text with % wildcards. CONTAINS takes a word or phrase; it is the only op for a field marked "long", and then it must sit at the top level of "where", joined by AND.\n'
    + '  - Dates are "YYYY-MM-DD", or one of these date literals: {{date_literals}}. Replace n with a number, e.g. LAST_N_DAYS:30. Use null with = or != to test for an empty field.\n'
    + '  - Related records: {"field":"Id","op":"IN" or "NOT IN","sub":{"object":"Case","field":"AccountId","where":...}} keeps the records whose Id (or a lookup field of this object) is, or is not, among that lookup on the other object, e.g. accounts with an open case. At most 2, at the top level only (joined by AND, never inside or or not), never on Task or Event, never the same object.\n'
    + '  - Earlier results: "value":{"step":1,"field":"Id"} with IN or NOT IN uses the values of that column in the rows of query 1 of this question. Use it for Task and Event, and for questions in steps, e.g. the top 5 first, then a condition on those.\n'
    + '- "children": up to 2 child lists on a plain query, {"rel":"Cases","fields":["Subject"],"where":...,"limit":5}, using the names after "children:".\n'
    + '- "orderBy": {"field":"...","dir":"ASC" or "DESC"} (optional). "limit": rows (optional; default 50, at most 200).\n'
    + '- "groupBy": field paths (optional). "aggregates": a list of {"fn":"COUNT"|"SUM"|"AVG"|"MIN"|"MAX","field":"..."} (optional; COUNT with no field counts records). "having": with groupBy, a list of {"fn":"COUNT","field":"","op":">","value":3}, each one of the aggregates.\n'
    + '  - With aggregates and no groupBy, leave "fields" empty: you get one row of totals. With groupBy, "fields" must be in "groupBy". To order groups by an aggregate, write it like "SUM(Amount)" in orderBy.\n\n';
sysT = sysT.substringBefore('PLAN is a JSON object') + grammar + 'Rules:' + sysT.substringAfter('Rules:');
sysT = sysT.replace(sysT.substringBetween('Rules:\n', '3. '), '1. Use only object, field, lookup and child names that appear in the catalog, spelled as shown. If the question needs an object that is not in the catalog, say you cannot reach it.\n2. A query has one object, but it can read parent fields through lookups, test related records with "sub", and use earlier results with "step".\n');
String usrT = raw.substringAfter('---user---').trim();
List<String> objs = cat.pick(QUESTION, m);
Set<String> inPrompt = new Set<String>();
for (String n : objs) {
    inPrompt.add(n.toLowerCase());
}
List<String> catLines = new List<String>();
for (String n : objs) {
    catLines.add(cat.line(cat.obj(n), inPrompt));
}
m.shapes.put('catalogObjects', objs.size());
m.shapes.put('catalogChars', String.join(catLines, '\n').length());
Map<String, String> vars = new Map<String, String>{
    'catalog' => String.join(catLines, '\n'),
    'date_literals' => String.join(ExplorePlan.DATE_LITERALS, ', ') + ', ' + String.join(ExplorePlan.DATE_LITERALS_N, ':n, ') + ':n',
    'context' => '(none)', 'history' => '(none)', 'question' => QUESTION
};
List<String> turns = new List<String>();
List<ExploreQuery.ResultSet> sets = new List<ExploreQuery.ResultSet>();
List<List<Map<String, Object>>> steps = new List<List<Map<String, Object>>>();
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
        } else if (!(msg.get('plan') instanceof Map<String, Object>)) {
            outcome = 'INVALID: "plan" must be a JSON object.';
        } else {
            try {
                Built b = new Planner(cat, m, steps).build((Map<String, Object>) msg.get('plan'));
                queries++;
                ExploreQuery.ResultSet rs = runBuilt(b);
                sets.add(rs);
                steps.add(rs.rows);
                List<String> lines = new List<String>{ String.join(rs.labels, ' | ') };
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
                m.codes.add(e.getTypeName());
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
report(QID, 'v2', REF, o, m, soqlCount, cpu, heap, rows, wall);
