// BE-31 harness: shared by every engine. run.py puts a header in front (QUESTION, QID, REF_JSON) and an
// engine file after it, strips comments and runs the whole thing as one anonymous Apex transaction.
// Read-only: no DML. Prints one line, 'BE31 :: {json}', with counts, statuses and limits only:
// no record names, no record Ids, no answer text.

public class Meter {
    public Integer calls = 0;
    public Integer inTok = 0;
    public Integer outTok = 0;
    public Long modelMs = 0;
    public Integer invalid = 0;
    public Integer promptChars = 0;
    public Map<String, Integer> shapes = new Map<String, Integer>();
    public Set<String> objects = new Set<String>();
    public List<String> codes = new List<String>();
}

public class Outcome {
    public String status;
    public Integer queries = 0;
    public List<Map<String, Object>> lastRows = new List<Map<String, Object>>();
    public Integer lastTotal = 0;
    public Integer sets = 0;
    public String answer = '';
}

// One model call through the Models API, metered (calls, tokens, time). Same model as AgentLlmModelsApi.
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
        m.codes.add('no-usage');
    }
    String text = (String) ((Map<String, Object>) ((List<Object>) det.get('generations'))[0]).get('content');
    return text.length() > 8000 ? text.left(8000) : text;
}

// The one JSON object in a reply, as DataExplorer.parseReply reads it.
Map<String, Object> parseReply(String reply) {
    Integer a = reply == null ? -1 : reply.indexOf('{');
    Integer b = reply == null ? -1 : reply.lastIndexOf('}');
    if (a < 0 || b < a) {
        return null;
    }
    try {
        Object o = JSON.deserializeUntyped(reply.substring(a, b + 1));
        return o instanceof Map<String, Object> ? (Map<String, Object>) o : null;
    } catch (Exception e) {
        return null;
    }
}

String fillPrompt(String t, Map<String, String> vars) {
    for (String k : vars.keySet()) {
        t = t.replace('{{' + k + '}}', vars.get(k) == null ? '' : vars.get(k));
    }
    return t;
}

// ---------------------------------------------------------------- grading

Set<Id> idsIn(List<Map<String, Object>> rows, SObjectType t) {
    Set<Id> out = new Set<Id>();
    for (Map<String, Object> r : rows) {
        for (Object v : r.values()) {
            if (v instanceof Id && (t == null || ((Id) v).getSObjectType() == t)) {
                out.add((Id) v);
            } else if (v instanceof String && (((String) v).length() == 18 || ((String) v).length() == 15)) {
                try {
                    Id i = Id.valueOf((String) v);
                    if (t == null || i.getSObjectType() == t) {
                        out.add(i);
                    }
                } catch (Exception e) {
                    // not an Id
                }
            }
        }
    }
    return out;
}

Boolean numberSeen(Decimal want, Outcome o) {
    if (want == null) {
        return false;
    }
    String txt = o.answer.replace(',', '').replace('$', '');
    Decimal r0 = want.setScale(0, System.RoundingMode.HALF_UP);
    if (Pattern.compile('(^|[^0-9.])' + r0 + '([^0-9]|\\.0|$)').matcher(txt).find()) {
        return true;
    }
    for (Map<String, Object> row : o.lastRows) {
        for (Object v : row.values()) {
            if ((v instanceof Decimal || v instanceof Integer || v instanceof Double || v instanceof Long)
                && Math.abs(Decimal.valueOf(String.valueOf(v)) - want) <= Math.max(0.5, Math.abs(want) * 0.005)) {
                return true;
            }
        }
    }
    // A correct empty result: nothing matched and the reference is 0.
    if (want == 0 && o.sets > 0 && o.lastRows.isEmpty()) {
        return true;
    }
    return o.lastRows.size() > 0 && o.lastTotal == want && o.lastRows.size() < 200 && o.lastRows[0].containsKey('Id');
}

Set<Id> refIds(List<Object> soqls, String containsField, String containsText) {
    Set<Id> prev = new Set<Id>();
    Set<Id> out = new Set<Id>();
    for (Object q : soqls) {
        Map<String, Object> binds = new Map<String, Object>{ 'prev' => prev };
        out = new Set<Id>();
        for (SObject r : Database.queryWithBinds((String) q, binds, AccessLevel.USER_MODE)) {
            if (containsField != null && !String.valueOf(r.get(containsField) ?? '').toLowerCase().contains(containsText)) {
                continue;
            }
            Map<String, Object> f = r.getPopulatedFieldsAsMap();
            for (String k : f.keySet()) {
                if (f.get(k) instanceof Id && (k == 'Id' || soqls.size() > 1)) {
                    out.add((Id) f.get(k));
                }
            }
        }
        prev = out;
    }
    return out;
}

// PASS when the engine's last table (or, for a number, its answer or a cell) matches an independent query.
String grade(Map<String, Object> ref, Outcome o, Meter m) {
    String kind = (String) ref.get('kind');
    List<Object> soqls = ref.get('soql') instanceof List<Object> ? (List<Object>) ref.get('soql') : new List<Object>{ ref.get('soql') };
    if (kind == 'refuse') {
        return m.objects.contains((String) ref.get('object')) ? 'FAIL:reached' : 'PASS';
    }
    if (o.status == 'ERROR') {
        return 'FAIL:error';
    }
    if (kind == 'count' || kind == 'sum') {
        Decimal v = kind == 'count' ? Database.countQuery((String) soqls[0], AccessLevel.USER_MODE) : (Decimal) Database.query((String) soqls[0], AccessLevel.USER_MODE)[0].get('v');
        m.codes.add('ref=' + v);
        return numberSeen(v, o) ? 'PASS' : 'FAIL:number';
    }
    if (kind == 'groups') {
        for (SObject g : Database.query((String) soqls[0], AccessLevel.USER_MODE)) {
            Boolean hit = false;
            Decimal v = Decimal.valueOf(String.valueOf(g.get('v')));
            for (Map<String, Object> row : o.lastRows) {
                Boolean key = false, val = false;
                for (Object c : row.values()) {
                    key = key || (c != null && (String.valueOf(c) == String.valueOf(g.get('k')) || String.valueOf(c) == String.valueOf(g.get('n'))));
                    val = val || (c != null && !(c instanceof String) && !(c instanceof Id) && Math.abs(Decimal.valueOf(String.valueOf(c)) - v) <= 0.5);
                }
                hit = hit || (key && val);
            }
            if (!hit) {
                return 'FAIL:groups';
            }
        }
        return 'PASS';
    }
    Set<Id> want = refIds(soqls, (String) ref.get('containsField'), (String) ref.get('containsText'));
    SObjectType t = Schema.getGlobalDescribe().get((String) ref.get('object')).getDescribe().getSObjectType();
    Set<Id> got = idsIn(o.lastRows, t);
    if (want.isEmpty()) {
        return got.isEmpty() ? 'PASS' : 'FAIL:set';
    }
    return got.equals(want) ? 'PASS' : (got.containsAll(want) ? 'FAIL:superset' : 'FAIL:set');
}

void report(String qid, String engine, Map<String, Object> ref, Outcome o, Meter m, Integer soqlCount, Integer cpu, Integer heap, Integer rows, Long wall) {
    String verdict;
    try {
        verdict = grade(ref, o, m);
    } catch (Exception e) {
        verdict = 'FAIL:grader ' + e.getTypeName();
    }
    Map<String, Object> out = new Map<String, Object>{
        'q' => qid, 'engine' => engine, 'verdict' => verdict, 'status' => o.status,
        'modelCalls' => m.calls, 'inTokens' => m.inTok, 'outTokens' => m.outTok, 'modelMs' => m.modelMs,
        'invalid' => m.invalid, 'promptChars' => m.promptChars, 'shapes' => m.shapes, 'objects' => new List<String>(m.objects),
        'codes' => m.codes, 'queries' => o.queries, 'soql' => soqlCount, 'queryRows' => rows, 'cpuMs' => cpu,
        'heapBytes' => heap, 'wallMs' => wall, 'sets' => o.sets, 'lastRows' => o.lastRows.size(),
        'answered' => String.isNotBlank(o.answer)
    };
    System.debug(LoggingLevel.ERROR, 'BE31 :: ' + JSON.serialize(out));
}
