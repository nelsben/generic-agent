/**
 * DataExplorer: answer a free-form data question with a capped query loop, or drill into a record.
 *
 * explore() runs the loop. Each turn the model (through AgentLlm, prompt AgentPrompt_Explore) returns
 * exactly one JSON object: {"action":"query","plan":{...}} or {"action":"answer","text":"...","followups":[...]}.
 * A plan is resolved against ExploreCatalog and run by ExploreQuery in user mode; the model never
 * writes SOQL. A reply that is not one JSON object, a plan error or a QueryException is fed back as
 * 'INVALID: <reason>' so the model corrects itself. Caps: MAX_TURNS model calls and MAX_QUERIES
 * queries per question; the prompt tells the model to answer once queries_left is 0. The model sees
 * PREVIEW_ROWS rows of each result plus the total. All wording for the model lives in the prompt file.
 * An aggregate over more than the ExploreQuery row cap is refused and fed back as INVALID too.
 * When the turns run out with result sets in hand, they are kept: the status is OK (EMPTY when no
 * set has rows) and the answer is TURN_CAP_TEXT, so the caller still shows the last result. Turns
 * that run out with nothing read, and any model failure, are ERROR.
 *
 * drill() skips the model: the record's catalog fields, or its child rows in one catalog object with
 * a lookup to it, resolved by describe.
 *
 * Read-only: no DML anywhere on this path.
 */
public with sharing class DataExplorer {
    public static final String OK = 'OK';
    public static final String EMPTY = 'EMPTY';
    public static final String ERROR = 'ERROR';

    @TestVisible private static final String ERROR_TEXT = 'I couldn\'t finish that right now. Try again in a minute.';
    @TestVisible private static final String NO_QUESTION_TEXT = 'Ask a question about your data.';
    @TestVisible private static final String TURN_CAP_TEXT =
        'I ran out of steps before I could write a full answer. Here is the last result I found; ask a narrower question for more.';
    @TestVisible private static final Integer MAX_TURNS = 5;
    @TestVisible private static final Integer MAX_QUERIES = 4;
    @TestVisible private static final Integer PREVIEW_ROWS = 20;
    @TestVisible private static final Integer MAX_FOLLOWUPS = 4;
    private static final Integer PREVIEW_CELL_CHARS = 80;
    private static final Integer REPLY_ECHO_CHARS = 1500;
    private static final Integer FOLLOWUP_CHARS = 150;
    private static final Integer HISTORY_ITEMS = 5;
    private static final Integer HISTORY_CHARS = 600;
    private static final String PROMPT = 'Explore';
    private static final Integer MAX_TOKENS = 2000;
    private static final String NONE = '(none)';

    public class ExploreException extends Exception {}

    public class Result {
        @AuraEnabled public String status;
        @AuraEnabled public String answer;
        @AuraEnabled public List<ExploreQuery.ResultSet> resultSets = new List<ExploreQuery.ResultSet>();
        /** One line per query that ran: object | filters | row count. */
        @AuraEnabled public List<String> trail = new List<String>();
        @AuraEnabled public List<String> followups = new List<String>();
    }

    /** Loop state for one question. */
    private class ExploreRun {
        Result result = new Result();
        List<String> turns = new List<String>();
        /** Queries that reached the database, whether they returned rows or threw. */
        Integer queries = 0;
    }

    // ---------------------------------------------------------------- explore

    /**
     * Answers one question. contextRecordId (optional) is the open record, given to the model as a hint.
     * historyJson (optional) is earlier turns as [{"question":"...","answer":"..."}]; anything else is ignored.
     */
    public static Result explore(String question, Id contextRecordId, String historyJson) {
        ExploreRun run = new ExploreRun();
        if (String.isBlank(question)) {
            run.result.status = EMPTY;
            run.result.answer = NO_QUESTION_TEXT;
            return run.result;
        }
        try {
            Map<String, String> vars = new Map<String, String>{
                'catalog' => ExploreCatalog.describeForPrompt(),
                'date_literals' => String.join(ExplorePlan.DATE_LITERALS, ', ') + ', '
                    + String.join(ExplorePlan.DATE_LITERALS_N, ':n, ') + ':n',
                'context' => contextText(contextRecordId),
                'history' => historyText(historyJson),
                'question' => question.trim()
            };
            for (Integer turn = 1; turn <= MAX_TURNS; turn++) {
                vars.put('turns', run.turns.isEmpty() ? NONE : String.join(run.turns, '\n\n'));
                vars.put('queries_left', String.valueOf(MAX_QUERIES - run.queries));
                String reply = AgentLlm.complete(PROMPT, vars, MAX_TOKENS);
                String outcome = step(run, reply);
                if (outcome == null) {
                    return run.result;
                }
                run.turns.add('[' + turn + '] reply: ' + clip(reply.replaceAll('\\s+', ' '), REPLY_ECHO_CHARS)
                    + '\n[' + turn + '] ' + outcome);
            }
            // The turns ran out without an answer. Keep what was read rather than throw it away.
            if (!run.result.resultSets.isEmpty()) {
                answer(run.result, TURN_CAP_TEXT, null);
                return run.result;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DataExplorer.explore failed: ' + e.getMessage());
        }
        // A model failure, or turns ran out with nothing read.
        run.result.status = ERROR;
        run.result.answer = ERROR_TEXT;
        run.result.followups.clear();
        return run.result;
    }

    /** Handles one model reply. Returns null when the question is answered, else the line the model sees next. */
    private static String step(ExploreRun run, String reply) {
        Map<String, Object> msg = parseReply(reply);
        if (msg == null) {
            return 'INVALID: the reply was not one JSON object.';
        }
        String action = msg.get('action') instanceof String ? ((String) msg.get('action')).trim().toLowerCase() : null;
        if (action == 'answer') {
            String text = msg.get('text') == null ? '' : String.valueOf(msg.get('text')).trim();
            if (String.isBlank(text)) {
                return 'INVALID: an answer needs "text".';
            }
            answer(run.result, text, msg.get('followups'));
            return null;
        }
        if (action != 'query') {
            return 'INVALID: "action" must be "query" or "answer".';
        }
        if (run.queries >= MAX_QUERIES) {
            return 'INVALID: no queries left; reply with an answer.';
        }
        if (msg.get('plan') == null) {
            return 'INVALID: a query needs a "plan" object.';
        }
        ExplorePlan plan = ExplorePlan.fromObject(msg.get('plan'));
        List<String> errors = ExplorePlan.validate(plan);
        if (!errors.isEmpty()) {
            return 'INVALID: ' + String.join(errors, ' ');
        }
        ExploreQuery.ResultSet rs;
        try {
            run.queries++;
            rs = ExploreQuery.run(plan);
        } catch (QueryException e) {
            return 'INVALID: ' + e.getMessage();
        } catch (NoAccessException e) {
            return 'INVALID: ' + e.getMessage();
        } catch (ExploreQuery.RowCapException e) {
            return 'INVALID: ' + e.getMessage();
        }
        run.result.resultSets.add(rs);
        run.result.trail.add(rs.objectName + ' | ' + rs.filters + ' | ' + rowCount(rs));
        return 'RESULT ' + rs.objectName + ' rows=' + rs.shown + ' total=' + rs.total + '\n' + preview(rs);
    }

    private static void answer(Result r, String text, Object rawFollowups) {
        Boolean anyRows = false;
        for (ExploreQuery.ResultSet rs : r.resultSets) {
            anyRows = anyRows || rs.shown > 0;
        }
        r.status = anyRows ? OK : EMPTY;
        r.answer = text;
        if (rawFollowups instanceof List<Object>) {
            for (Object o : (List<Object>) rawFollowups) {
                if (o instanceof String && String.isNotBlank((String) o) && r.followups.size() < MAX_FOLLOWUPS) {
                    r.followups.add(clip(((String) o).trim(), FOLLOWUP_CHARS));
                }
            }
        }
    }

    /** The one JSON object in a reply (code fences and text around it are tolerated), or null. */
    @TestVisible
    private static Map<String, Object> parseReply(String reply) {
        Integer start = reply == null ? -1 : reply.indexOf('{');
        Integer stop = reply == null ? -1 : reply.lastIndexOf('}');
        if (start < 0 || stop < start) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(reply.substring(start, stop + 1));
            return parsed instanceof Map<String, Object> ? (Map<String, Object>) parsed : null;
        } catch (Exception e) {
            return null;
        }
    }

    // ---------------------------------------------------------------- drill

    /**
     * Drill-down without the model. With relatedObject blank: the record's catalog fields. Otherwise:
     * rows of that catalog object whose lookup points to the record (newest first, default row limit).
     * The lookup is found by describe, never taken from the caller. Throws ExploreException when the
     * record or object is not in the catalog for this user, or no catalog lookup joins them.
     */
    public static ExploreQuery.ResultSet drill(Id recordId, String relatedObject) {
        if (recordId == null) {
            throw new ExploreException('Pick a record to drill into.');
        }
        String parentName = recordId.getSObjectType().getDescribe().getName();
        ExplorePlan plan = new ExplorePlan();

        if (String.isBlank(relatedObject)) {
            ExploreCatalog.Entry entry = ExploreCatalog.find(parentName);
            if (entry == null) {
                throw new ExploreException(parentName + ' is not in the explore catalog.');
            }
            plan.objectName = entry.name;
            plan.fields = paths(entry);
            plan.filters.add(filter('Id', recordId));
            plan.rowLimit = 1;
            return ExploreQuery.run(plan);
        }

        ExploreCatalog.Entry child = ExploreCatalog.find(relatedObject);
        if (child == null) {
            throw new ExploreException(relatedObject.trim() + ' is not in the explore catalog.');
        }
        ExploreCatalog.Field lookup = lookupTo(child, parentName);
        if (lookup == null) {
            throw new ExploreException(child.name + ' has no lookup to ' + parentName + '.');
        }
        plan.objectName = child.name;
        plan.fields = paths(child);
        plan.filters.add(filter(lookup.path, recordId));
        ExploreCatalog.Field created = child.field('CreatedDate');
        if (created != null && created.sortable) {
            plan.orderBy = new ExplorePlan.OrderBy();
            plan.orderBy.field = created.path;
            plan.orderBy.dir = 'DESC';
        }
        return ExploreQuery.run(plan);
    }

    /** The child's lookup to parentName: single-object lookups first, then catalog order. */
    @TestVisible
    private static ExploreCatalog.Field lookupTo(ExploreCatalog.Entry child, String parentName) {
        ExploreCatalog.Field polymorphic;
        for (ExploreCatalog.Field f : child.fields) {
            if (f.path == 'Id' || f.path.contains('.') || f.kind != ExploreCatalog.KIND_ID || !f.filterable) {
                continue;
            }
            if (!f.referenceTo.contains(parentName)) {
                continue;
            }
            if (f.referenceTo.size() == 1) {
                return f;
            }
            if (polymorphic == null) {
                polymorphic = f;
            }
        }
        return polymorphic;
    }

    private static List<String> paths(ExploreCatalog.Entry entry) {
        List<String> out = new List<String>();
        for (ExploreCatalog.Field f : entry.fields) {
            out.add(f.path);
        }
        return out;
    }

    private static ExplorePlan.Filter filter(String path, Id value) {
        ExplorePlan.Filter f = new ExplorePlan.Filter();
        f.field = path;
        f.op = '=';
        f.value = String.valueOf(value);
        return f;
    }

    // ---------------------------------------------------------------- prompt text

    /** object, id and name of the open record, or NONE. The name is read in user mode. */
    @TestVisible
    private static String contextText(Id recordId) {
        if (recordId == null) {
            return NONE;
        }
        Schema.DescribeSObjectResult d = recordId.getSObjectType().getDescribe();
        String line = 'object=' + d.getName() + ' id=' + recordId;
        try {
            for (Schema.SObjectField sf : d.fields.getMap().values()) {
                Schema.DescribeFieldResult fd = sf.getDescribe();
                if (fd.isNameField() && fd.isAccessible()) {
                    List<SObject> rows = Database.queryWithBinds(
                        'SELECT ' + fd.getName() + ' FROM ' + d.getName() + ' WHERE Id = :recordId LIMIT 1',
                        new Map<String, Object>{ 'recordId' => recordId }, AccessLevel.USER_MODE);
                    if (!rows.isEmpty() && rows[0].get(fd.getName()) != null) {
                        line += ' name=' + clip(String.valueOf(rows[0].get(fd.getName())), PREVIEW_CELL_CHARS);
                    }
                    break;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'DataExplorer context name not read: ' + e.getMessage());
        }
        return line;
    }

    /** The last HISTORY_ITEMS earlier turns as Q:/A: lines, or NONE. Unreadable history is ignored. */
    @TestVisible
    private static String historyText(String historyJson) {
        if (String.isBlank(historyJson)) {
            return NONE;
        }
        List<String> lines = new List<String>();
        try {
            Object parsed = JSON.deserializeUntyped(historyJson);
            List<Object> items = parsed instanceof List<Object> ? (List<Object>) parsed : new List<Object>();
            for (Integer i = Math.max(0, items.size() - HISTORY_ITEMS); i < items.size(); i++) {
                if (!(items[i] instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> m = (Map<String, Object>) items[i];
                if (m.get('question') != null) {
                    lines.add('Q: ' + clip(String.valueOf(m.get('question')), HISTORY_CHARS));
                }
                if (m.get('answer') != null) {
                    lines.add('A: ' + clip(String.valueOf(m.get('answer')), HISTORY_CHARS));
                }
            }
        } catch (Exception e) {
            return NONE;
        }
        return lines.isEmpty() ? NONE : String.join(lines, '\n');
    }

    /** Columns, then up to PREVIEW_ROWS rows, pipe-separated, each cell clipped. */
    @TestVisible
    private static String preview(ExploreQuery.ResultSet rs) {
        List<String> lines = new List<String>{ String.join(rs.columns, ' | ') };
        for (Integer i = 0; i < Math.min(PREVIEW_ROWS, rs.rows.size()); i++) {
            List<String> cells = new List<String>();
            for (String c : rs.columns) {
                Object v = rs.rows[i].get(c);
                cells.add(v == null ? '' : clip(String.valueOf(v).replaceAll('\\s+', ' '), PREVIEW_CELL_CHARS));
            }
            lines.add(String.join(cells, ' | '));
        }
        return String.join(lines, '\n');
    }

    private static String rowCount(ExploreQuery.ResultSet rs) {
        return rs.total > rs.shown ? rs.shown + ' of ' + rs.total + ' rows' : rs.shown + ' rows';
    }

    @TestVisible
    private static String clip(String s, Integer max) {
        if (s == null || s.length() <= max) {
            return s;
        }
        return s.left(max - 3) + '...';
    }
}
