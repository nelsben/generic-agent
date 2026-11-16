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
 * set has rows) and the answer is TURN_CAP_TEXT, so the caller still shows the last result, or
 * TURN_CAP_NO_ROWS_TEXT when that last result has no rows (callers table only the last set). Turns
 * that run out with nothing read, and any model failure, are ERROR.
 * Status (BE-58): OK when any result set has a row, or when no query ran and the answer text is not
 * blank. EMPTY means the queries found nothing: at least one ran and none returned a row. The blank
 * question is EMPTY too (NO_QUESTION_TEXT).
 *
 * Follow-ups to a summary (BE-30). When the last history item is the user's newest summary of the open
 * Account (its answer matches CustomerSummaryMemory.lastBrief), the history the model sees ends with a
 * compact summary context: the account's Id, then each summary section's records (the same section
 * builders the summary used, run again in user mode) as their line text and Id, at most
 * SUMMARY_ITEMS_PER_SECTION per section and SUMMARY_CONTEXT_CHARS in all. It travels in the existing
 * history input, so every door that passes history (the panel, the agent's Explore Data action) gets it
 * with no new parameter. It goes only into the prompt, never into the Result shown to people. A failure
 * building it drops the context, not the question.
 *
 * drill() skips the model: the record's catalog fields, or its child rows in one catalog object with
 * a lookup to it, resolved by describe. Child rows lead with the record's name (N1) and carry only
 * their shown labels and their Id.
 *
 * Both return result sets shaped for display (forDisplay): no column that holds a record Id, and plain
 * labels as column names. Rows keep their record Id for drill-down. Only the model sees the Ids.
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
    @TestVisible private static final String TURN_CAP_NO_ROWS_TEXT =
        'I ran out of steps before I could write a full answer, and my last query found no rows. Ask a narrower question.';
    @TestVisible private static final Integer MAX_TURNS = 5;
    @TestVisible private static final Integer MAX_QUERIES = 4;
    @TestVisible private static final Integer PREVIEW_ROWS = 20;
    @TestVisible private static final Integer MAX_FOLLOWUPS = 4;
    private static final Integer PREVIEW_CELL_CHARS = 80;
    private static final Integer REPLY_ECHO_CHARS = 1500;
    private static final Integer FOLLOWUP_CHARS = 150;
    private static final Integer HISTORY_ITEMS = 5;
    private static final Integer HISTORY_CHARS = 600;
    private static final String PROMPT = 'Explore_v2';
    private static final Integer MAX_TOKENS = 2000;
    private static final String NONE = '(none)';
    @TestVisible private static final Integer SUMMARY_ITEMS_PER_SECTION = 10;
    @TestVisible private static final Integer SUMMARY_CONTEXT_CHARS = 3000;
    private static final Integer SUMMARY_LINE_CHARS = 120;
    /** A summary answer shorter than this is too short to tell apart from another, so it never matches. */
    private static final Integer SUMMARY_MATCH_CHARS = 20;
    @TestVisible private static final String SUMMARY_CONTEXT_HEADER =
        'Records behind that summary (for follow-ups; ids are for plans only, never for the answer text):';
    /** A summary section line that names one record ends with ' — ' and the record's Id (CustomerSummarySection.withId). */
    private static final Pattern SUMMARY_LINE = Pattern.compile('^\\s*(.*?)\\s+—\\s+([0-9][0-9A-Za-z]{17})\\s*$');

    public class ExploreException extends Exception {}

    public class Result {
        @AuraEnabled public String status;
        @AuraEnabled public String answer;
        @AuraEnabled public List<ExploreQuery.ResultSet> resultSets = new List<ExploreQuery.ResultSet>();
        /** One line per query that ran: object | filters | row count. */
        @AuraEnabled public List<String> trail = new List<String>();
        @AuraEnabled public List<String> followups = new List<String>();
        /** The same answer as cards (BE-39): built from the members above, never from a new query or model call. */
        @AuraEnabled public List<AnswerCard> cards = new List<AnswerCard>();
    }

    /** Loop state for one question. */
    /**
     * Counts from the last explore in this transaction, for measurement (spikes/explorer-scale): model calls,
     * the catalog's characters per call, and the characters of every prompt variable sent. No question text.
     */
    public class RunStats {
        public Integer modelCalls = 0;
        public List<Integer> catalogChars = new List<Integer>();
        public Integer varChars = 0;

        void count(Map<String, String> vars) {
            modelCalls++;
            catalogChars.add(vars.get('catalog').length());
            for (String v : vars.values()) {
                varChars += v == null ? 0 : v.length();
            }
        }
    }

    /** The last run's counts; null before the first explore. */
    public static RunStats lastRun;

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
        Result r = run(question, contextRecordId, historyJson);
        for (ExploreQuery.ResultSet rs : r.resultSets) {
            forDisplay(rs);
        }
        // The panel shows every row of the last result set, so its table card holds them all.
        try {
            ExploreQuery.ResultSet last = r.resultSets.isEmpty() ? null : r.resultSets[r.resultSets.size() - 1];
            r.cards = cards(r, last == null ? 0 : last.rows.size());
        } catch (Exception e) {
            // Cards never change the answer: a failure building them leaves the text as it is.
            System.debug(LoggingLevel.ERROR, 'DataExplorer cards not built: ' + e.getTypeName() + ': ' + e.getMessage());
            r.cards = new List<AnswerCard>();
        }
        return r;
    }

    /** The loop itself. The model sees every column, Ids included, so a follow-up can query those records again. */
    private static Result run(String question, Id contextRecordId, String historyJson) {
        ExploreRun run = new ExploreRun();
        if (String.isBlank(question)) {
            run.result.status = EMPTY;
            run.result.answer = NO_QUESTION_TEXT;
            return run.result;
        }
        try {
            Map<String, String> vars = new Map<String, String>{
                'date_literals' => String.join(ExplorePlan.DATE_LITERALS, ', ') + ', '
                    + String.join(ExplorePlan.DATE_LITERALS_N, ':n, ') + ':n',
                'context' => contextText(contextRecordId) + outcomeContext(contextRecordId),
                'history' => historyText(historyJson) + summaryContext(contextRecordId, historyJson),
                'question' => question.trim()
            };
            // The brand's company and tone lines go after the explorer prompt's own system text (BE-24).
            String brandLines = BrandSettings.promptLines();
            lastRun = new RunStats();
            for (Integer turn = 1; turn <= MAX_TURNS; turn++) {
                // The catalog is rebuilt each turn: an object a plan named last turn now lists its fields (BE-42).
                vars.put('catalog', ExploreCatalog.describeForPrompt(question));
                vars.put('turns', run.turns.isEmpty() ? NONE : String.join(run.turns, '\n\n'));
                vars.put('queries_left', String.valueOf(MAX_QUERIES - run.queries));
                lastRun.count(vars);
                String reply = AgentLlm.complete(PROMPT, vars, MAX_TOKENS, brandLines);
                String outcome = step(run, reply);
                if (outcome == null) {
                    return run.result;
                }
                run.turns.add('[' + turn + '] reply: ' + clip(reply.replaceAll('\\s+', ' '), REPLY_ECHO_CHARS)
                    + '\n[' + turn + '] ' + outcome);
            }
            // The turns ran out without an answer. Keep what was read rather than throw it away.
            List<ExploreQuery.ResultSet> sets = run.result.resultSets;
            if (!sets.isEmpty()) {
                answer(run.result, sets[sets.size() - 1].shown > 0 ? TURN_CAP_TEXT : TURN_CAP_NO_ROWS_TEXT, null);
                return run.result;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DataExplorer.explore failed: ' + e.getTypeName() + ': ' + e.getMessage());
        }
        // A model failure, or turns ran out with nothing read.
        run.result.status = ERROR;
        run.result.answer = ERROR_TEXT;
        run.result.followups.clear();
        return run.result;
    }

    /**
     * An allowed object the catalog has not described yet: describe it now and send the model back to plan
     * again with its fields, which the next turn's catalog lists. Costs a turn, not a query. Null otherwise.
     */
    private static String describeOnDemand(ExplorePlan plan) {
        if (String.isBlank(plan.objectName) || ExploreCatalog.find(plan.objectName) != null) {
            return null;
        }
        ExploreCatalog.Entry e = ExploreCatalog.describe(plan.objectName);
        return e == null ? null
            : 'INVALID: ' + e.name + ' was not in the catalog yet. Its fields are listed there now; plan again with them.';
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
        String described = describeOnDemand(plan);
        if (described != null) {
            return described;
        }
        List<String> errors = ExplorePlan.validate(plan, run.result.resultSets);
        if (!errors.isEmpty()) {
            return 'INVALID: ' + String.join(errors, ' ');
        }
        ExploreQuery.ResultSet rs;
        try {
            run.queries++;
            rs = ExploreQuery.run(plan, run.result.resultSets);
        } catch (QueryException e) {
            return 'INVALID: ' + e.getMessage();
        } catch (NoAccessException e) {
            return 'INVALID: ' + e.getMessage();
        } catch (ExploreQuery.RowCapException e) {
            return 'INVALID: ' + e.getMessage();
        }
        run.result.resultSets.add(rs);
        run.result.trail.add(rs.objectName + ' | ' + withoutIds(rs.filters) + ' | ' + rowCount(rs));
        return 'RESULT ' + rs.objectName + ' rows=' + rs.shown + ' total=' + rs.total
            + ' step=' + run.result.resultSets.size() + '\n' + preview(rs);
    }

    private static void answer(Result r, String text, Object rawFollowups) {
        Boolean anyRows = false;
        for (ExploreQuery.ResultSet rs : r.resultSets) {
            anyRows = anyRows || rs.shown > 0;
        }
        // EMPTY means the queries found nothing: at least one ran and none returned a row. An answer
        // with text and no query run (a follow-up answered from history) is OK (BE-58).
        Boolean noQueryRan = r.resultSets.isEmpty();
        r.status = anyRows || (noQueryRan && String.isNotBlank(text)) ? OK : EMPTY;
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

    // ---------------------------------------------------------------- cards (BE-39)

    @TestVisible private static final String CUT_TEXT = 'Showing {0} of {1} rows. Ask with a filter to narrow it.';
    private static final Pattern AGGREGATE_LABEL = Pattern.compile('^(Sum|Average|Min|Max|Count) of (.+)$');

    /**
     * The result as cards, in order: the answer ('ans', or 'err' on ERROR); then the last result set, at most
     * maxRows of its rows, as a metric ('met', an aggregate with no groups), a recordList ('lst', records with at most
     * two shown columns) or a table ('tbl'); a notice ('not') when that card holds fewer rows than matched; the
     * trail ('trl'); the follow-ups ('fol'). maxRows is what the caller's text shows, so no card holds a row the
     * text leaves out; 0 gives no result card. Cells are formatted strings; record Ids are only in refs.
     * @param r the explorer's result, shaped for display
     * @param maxRows the most rows of the last result set a card may hold
     * @return the cards
     */
    public static List<AnswerCard> cards(Result r, Integer maxRows) {
        List<AnswerCard> out = new List<AnswerCard>();
        if (r == null) {
            return out;
        }
        out.add(r.status == ERROR ? AnswerCard.error('err', r.answer) : AnswerCard.text('ans', r.status, r.answer, null));
        ExploreQuery.ResultSet rs = r.resultSets.isEmpty() ? null : r.resultSets[r.resultSets.size() - 1];
        Integer rows = rs == null || maxRows == null ? 0 : Math.min(maxRows, rs.rows.size());
        if (rows > 0) {
            out.add(resultCard(rs, rows));
            if (rs.total > rows) {
                out.add(AnswerCard.notice('not', OK, String.format(CUT_TEXT, new List<Object>{ rows, rs.total })));
            }
        }
        if (!r.trail.isEmpty()) {
            List<AnswerCard.Item> steps = new List<AnswerCard.Item>();
            for (String line : r.trail) {
                List<String> parts = line.split(' \\| ');
                String what = parts.remove(0);
                String count = parts.isEmpty() ? null : parts.remove(parts.size() - 1);
                String filters = String.join(parts, ' | ');
                steps.add(AnswerCard.newItem(what + (String.isBlank(filters) || filters == 'no filters' ? '' : ' where ' + filters),
                    null, count, null));
            }
            out.add(AnswerCard.trail('trl', steps));
        }
        if (!r.followups.isEmpty()) {
            out.add(AnswerCard.followups('fol', r.followups));
        }
        return out;
    }

    /** The first rows of a result set as a metric, a recordList or a table. */
    private static AnswerCard resultCard(ExploreQuery.ResultSet rs, Integer rows) {
        ExploreCatalog.Entry entry = String.isBlank(rs.objectName) ? null : ExploreCatalog.find(rs.objectName);
        List<String> heads = headers(rs);
        List<String> kinds = new List<String>();
        for (Integer i = 0; i < rs.columns.size(); i++) {
            kinds.add(columnKind(entry, rs.columns[i], heads[i]));
        }
        Boolean aggregate = rs.plan != null && !rs.plan.aggregates.isEmpty();
        if (aggregate && rs.plan.groupBy.isEmpty()) {
            List<AnswerCard.Item> figures = new List<AnswerCard.Item>();
            for (Integer i = 0; i < rs.columns.size(); i++) {
                figures.add(AnswerCard.newItem(heads[i], cell(rs.rows[0].get(rs.columns[i]), kinds[i]), null, null));
            }
            return AnswerCard.metric('met', rs.objectName, figures);
        }
        List<AnswerCard.Ref> refs = new List<AnswerCard.Ref>();
        Boolean records = !aggregate && rowId(rs.rows[0]) != null;
        if (records && rs.columns.size() <= 2) {
            List<AnswerCard.Item> items = new List<AnswerCard.Item>();
            for (Integer n = 0; n < rows; n++) {
                Map<String, Object> row = rs.rows[n];
                AnswerCard.Item i = AnswerCard.newItem(cell(row.get(rs.columns[0]), kinds[0]), null,
                    rs.columns.size() > 1 ? cell(row.get(rs.columns[1]), kinds[1]) : null, null);
                i.ref = AnswerCard.addRef(refs, rowId(row), i.label);
                items.add(i);
            }
            return AnswerCard.recordList('lst', rs.objectName, items, rs.total, refs);
        }
        List<AnswerCard.Column> columns = new List<AnswerCard.Column>();
        for (Integer i = 0; i < rs.columns.size(); i++) {
            columns.add(AnswerCard.newColumn(rs.columns[i], heads[i], kinds[i]));
        }
        List<AnswerCard.Row> grid = new List<AnswerCard.Row>();
        for (Integer n = 0; n < rows; n++) {
            Map<String, Object> row = rs.rows[n];
            List<String> cells = new List<String>();
            for (Integer i = 0; i < rs.columns.size(); i++) {
                cells.add(cell(row.get(rs.columns[i]), kinds[i]));
            }
            grid.add(AnswerCard.newRow(AnswerCard.addRef(refs, rowId(row), cells.isEmpty() ? '' : cells[0]), cells));
        }
        return AnswerCard.table('tbl', rs.objectName, columns, grid, rs.total, refs);
    }

    /** The record Id a row carries for drill-down, or null (a group, or a hand-built row). */
    private static Id rowId(Map<String, Object> row) {
        Object raw = row.get('Id');
        return raw != null && isRecordId(String.valueOf(raw)) ? Id.valueOf(String.valueOf(raw)) : null;
    }

    /** A column's card kind (text, number, currency, percent or date), from its catalog field, by path or by label. */
    private static String columnKind(ExploreCatalog.Entry entry, String column, String label) {
        if (label == 'Count' || (label != null && label.startsWith('Count of '))) {
            return 'number';
        }
        Matcher m = label == null ? null : AGGREGATE_LABEL.matcher(label);
        String fieldLabel = m != null && m.matches() ? m.group(2) : label;
        ExploreCatalog.Field f = entry == null ? null : ExplorePlan.fieldAt(entry, column);
        for (ExploreCatalog.Field candidate : entry == null || f != null ? new List<ExploreCatalog.Field>() : entry.fields) {
            if (candidate.label == fieldLabel) {
                f = candidate;
                break;
            }
        }
        switch on f?.type {
            when 'currency' {
                return 'currency';
            }
            when 'percent' {
                return 'percent';
            }
            when 'double', 'integer', 'long' {
                return 'number';
            }
            when 'date', 'datetime' {
                return 'date';
            }
            when else {
                return 'text';
            }
        }
    }

    /** One value as a card cell: money as $1,250, a percent with %, a date as yyyy-MM-dd, a flag as Yes or No. */
    private static String cell(Object v, String kind) {
        if (v == null) {
            return '';
        }
        if (v instanceof Date) {
            return CustomerSummarySection.fmtDate((Date) v);
        }
        if (v instanceof Datetime) {
            return ((Datetime) v).format('yyyy-MM-dd HH:mm');
        }
        if (v instanceof Boolean) {
            return (Boolean) v ? 'Yes' : 'No';
        }
        if (v instanceof Decimal || v instanceof Integer || v instanceof Long || v instanceof Double) {
            Decimal d = Decimal.valueOf(String.valueOf(v));
            return kind == 'currency' ? CustomerSummarySection.money(d) : d.format() + (kind == 'percent' ? '%' : '');
        }
        return String.valueOf(v);
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
            ExploreCatalog.Entry entry = ExploreCatalog.describe(parentName);
            if (entry == null) {
                throw new ExploreException(parentName + ' is not in the explore catalog.');
            }
            plan.objectName = entry.name;
            plan.fields = paths(entry);
            plan.filters.add(filter('Id', recordId));
            plan.rowLimit = 1;
            return forDisplay(ExploreQuery.run(plan));
        }

        // Related rows come from the described catalog only (the core objects), as before BE-42; the record
        // itself may be any allowed object, so a row from an object described on demand can still be opened.
        ExploreCatalog.Entry child = ExploreCatalog.find(relatedObject);
        if (child == null) {
            throw new ExploreException(relatedObject.trim() + ' is not in the explore catalog.');
        }
        ExploreCatalog.Field lookup = lookupTo(child, parentName);
        if (lookup == null) {
            throw new ExploreException(child.name + ' has no lookup to ' + parentName + '.');
        }
        plan.objectName = child.name;
        plan.fields = nameFirst(child, lookup, paths(child));
        plan.filters.add(filter(lookup.path, recordId));
        ExploreCatalog.Field created = child.field('CreatedDate');
        if (created != null && created.sortable) {
            plan.orderBy = new ExplorePlan.OrderBy();
            plan.orderBy.field = created.path;
            plan.orderBy.dir = 'DESC';
        }
        return shownKeysOnly(forDisplay(ExploreQuery.run(plan)));
    }

    /**
     * The paths with the one that names a child row moved to the front, so the row's button reads as the
     * record (N1): the object's own name field (Name, CaseNumber, Subject), or, for an object without one
     * such as OpportunityContactRole, the name of the record on the other side of the drill (the contact
     * of a role drilled from its deal). Otherwise the order is unchanged.
     */
    private static List<String> nameFirst(ExploreCatalog.Entry child, ExploreCatalog.Field lookup, List<String> paths) {
        Map<String, Schema.SObjectField> described = Schema.getGlobalDescribe().get(child.name).getDescribe().fields.getMap();
        String lead;
        for (String path : paths) {
            Schema.SObjectField sf = path.contains('.') ? null : described.get(path.toLowerCase());
            if (sf != null && sf.getDescribe().isNameField()) {
                lead = path;
                break;
            }
        }
        if (lead == null) {
            Schema.SObjectField back = described.get(lookup.path.toLowerCase());
            String backRelationship = back == null ? null : back.getDescribe().getRelationshipName();
            for (String path : paths) {
                if (path.endsWith('.Name') && !path.substringBefore('.').equalsIgnoreCase(backRelationship)) {
                    lead = path;
                    break;
                }
            }
        }
        if (lead == null) {
            return paths;
        }
        List<String> out = new List<String>{ lead };
        for (String path : paths) {
            if (path != lead) {
                out.add(path);
            }
        }
        return out;
    }

    /** Each row reduced to its shown columns and its record Id: no API path keys, no raw lookup Ids (N1). */
    private static ExploreQuery.ResultSet shownKeysOnly(ExploreQuery.ResultSet rs) {
        for (Integer i = 0; i < rs.rows.size(); i++) {
            Map<String, Object> row = new Map<String, Object>();
            for (String c : rs.columns) {
                row.put(c, rs.rows[i].get(c));
            }
            if (rs.rows[i].containsKey('Id')) {
                row.put('Id', rs.rows[i].get('Id'));
            }
            rs.rows[i] = row;
        }
        return rs;
    }

    // ---------------------------------------------------------------- display

    /**
     * The result set as callers show it. Columns that hold a record Id (Id, or a field ending in Id
     * such as AccountId or WhoId) are dropped, and every other column is named by its plain label
     * (Account, not Account.Name), because the panel shows column names as headers. Rows keep every
     * key they had, the record Id under 'Id' included for drill-down, and gain each label as a key.
     * A label that is already another column's key or 'Id' keeps its path, so no value is overwritten.
     */
    @TestVisible
    private static ExploreQuery.ResultSet forDisplay(ExploreQuery.ResultSet rs) {
        if (rs == null) {
            return rs;
        }
        ExploreCatalog.Entry entry = String.isBlank(rs.objectName) ? null : ExploreCatalog.find(rs.objectName);
        List<String> shown = headers(rs);
        Set<String> keys = new Set<String>(rs.columns);
        keys.add('Id');
        List<String> columns = new List<String>();
        for (Integer i = 0; i < rs.columns.size(); i++) {
            String path = rs.columns[i];
            if (holdsId(entry, path)) {
                continue;
            }
            String label = String.isBlank(shown[i]) ? path : shown[i];
            String key = label.equals(path) || !keys.contains(label) ? label : path;
            if (!key.equals(path)) {
                for (Map<String, Object> row : rs.rows) {
                    row.put(key, row.get(path));
                }
            }
            columns.add(key);
        }
        rs.columns = columns;
        rs.labels = columns.clone();
        return rs;
    }

    private static final Pattern ID_LIST = Pattern.compile('\\(([^()]*)\\)');
    private static final Pattern ID_WORD = Pattern.compile('\\b[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?\\b');

    /**
     * The trail's filter text with record Ids out of sight: a list made only of Ids becomes
     * '(N records)' and any other Id 'a record'. A follow-up filters on the earlier rows' Ids.
     */
    @TestVisible
    private static String withoutIds(String filters) {
        if (String.isBlank(filters)) {
            return filters;
        }
        String out = '';
        Integer last = 0;
        Matcher m = ID_LIST.matcher(filters);
        while (m.find()) {
            List<String> items = m.group(1).split(',');
            Boolean allIds = true;
            for (String item : items) {
                allIds = allIds && isRecordId(item.trim());
            }
            if (allIds) {
                out += filters.substring(last, m.start()) + '(' + items.size() + (items.size() == 1 ? ' record)' : ' records)');
                last = m.end();
            }
        }
        filters = out + filters.substring(last);
        out = '';
        last = 0;
        m = ID_WORD.matcher(filters);
        while (m.find()) {
            if (isRecordId(m.group())) {
                out += filters.substring(last, m.start()) + 'a record';
                last = m.end();
            }
        }
        return out + filters.substring(last);
    }

    /** A 15 or 18 character record Id. Words without a digit are never taken for one. */
    private static Boolean isRecordId(String s) {
        if (s == null || (s.length() != 15 && s.length() != 18) || !s.isAlphanumeric() || !s.containsAny('0123456789')) {
            return false;
        }
        try {
            return Id.valueOf(s) != null;
        } catch (Exception e) {
            return false;
        }
    }

    /** True when the column shows a record Id: Id, a field whose name ends in Id, or a catalog id field. */
    private static Boolean holdsId(ExploreCatalog.Entry entry, String path) {
        String last = path.contains('.') ? path.substringAfterLast('.') : path;
        if (last.equalsIgnoreCase('Id') || last.endsWith('Id')) {
            return true;
        }
        ExploreCatalog.Field f = entry == null ? null : ExplorePlan.fieldAt(entry, path);
        return f != null && f.kind == ExploreCatalog.KIND_ID;
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

    /**
     * The account's earlier outcomes for the model (BE-35), on new lines after the context line, or '' when the
     * open record is not an Account or there is nothing the user may see. Anyone but an outcome's author gets
     * its type and date only (CustomerOutcomes, F79). Read-only.
     */
    @TestVisible
    private static String outcomeContext(Id recordId) {
        if (recordId == null || recordId.getSObjectType() != Account.SObjectType) {
            return '';
        }
        String ctx = CustomerOutcomes.contextFor(recordId);
        return String.isBlank(ctx) ? '' : '\n' + ctx;
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

    /**
     * The summary context for a follow-up, or '' when the last history item is not the user's newest
     * summary of contextRecordId (an Account). Starts on a new line so it follows the history text.
     */
    @TestVisible
    private static String summaryContext(Id contextRecordId, String historyJson) {
        if (contextRecordId == null || contextRecordId.getSObjectType() != Account.SObjectType || String.isBlank(historyJson)) {
            return '';
        }
        try {
            Object parsed = JSON.deserializeUntyped(historyJson);
            List<Object> items = parsed instanceof List<Object> ? (List<Object>) parsed : new List<Object>();
            Object last = items.isEmpty() ? null : items[items.size() - 1];
            Object answer = last instanceof Map<String, Object> ? ((Map<String, Object>) last).get('answer') : null;
            if (!(answer instanceof String) || !isLastSummary((String) answer, CustomerSummaryMemory.lastBrief(contextRecordId))) {
                return '';
            }
            List<CustomerSummarySection> sections = new List<CustomerSummarySection>();
            for (CustomerSummarySource src : SUMMARY_SOURCES) {
                sections.add(src.build(contextRecordId));
            }
            return '\n' + summaryLines(contextRecordId, sections);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'DataExplorer summary context not built: ' + e.getTypeName() + ': ' + e.getMessage());
            return '';
        }
    }

    /**
     * The summary sections whose lines name records. Profile is left out: it is the account itself.
     * Keep in step with CustomerSummary's registry when a source that lists records is added.
     */
    private static final List<CustomerSummarySource> SUMMARY_SOURCES = new List<CustomerSummarySource>{
        new CustomerSummaryOpenDealsSection(),
        new CustomerSummaryCasesSection(),
        new CustomerSummaryContactsSection(),
        new CustomerSummaryActivitySection(),
        new CustomerSummaryCallsSection(),
        new CustomerSummaryDealHistorySection()
    };

    /**
     * True when the history answer is the stored summary, or its start (a caller may clip it and add
     * '...'). Whitespace is compared collapsed. A very short answer never matches.
     */
    @TestVisible
    private static Boolean isLastSummary(String historyAnswer, String storedSummary) {
        if (String.isBlank(historyAnswer) || String.isBlank(storedSummary)) {
            return false;
        }
        String said = historyAnswer.normalizeSpace().removeEnd('...').removeEnd('…').trim();
        return said.length() >= SUMMARY_MATCH_CHARS && storedSummary.normalizeSpace().startsWith(said);
    }

    /**
     * The context text: the account, then each section that names records, as its title and one line per
     * record (the line's text clipped, then id=). Capped per section and in all; a cut says so.
     */
    @TestVisible
    private static String summaryLines(Id accountId, List<CustomerSummarySection> sections) {
        List<String> lines = new List<String>{ SUMMARY_CONTEXT_HEADER, 'Account: the open record, id=' + accountId };
        Integer used = lines[0].length() + lines[1].length() + 2;
        for (CustomerSummarySection s : sections) {
            if (s == null || s.status != CustomerSummarySection.OK || String.isBlank(s.body)) {
                continue;
            }
            List<String> items = new List<String>();
            Integer more = 0;
            for (String line : s.body.split('\n')) {
                Matcher m = SUMMARY_LINE.matcher(line);
                if (!m.matches()) {
                    continue;
                }
                String item = '- ' + clip(m.group(1).removeStart('-').removeStart('•').trim(), SUMMARY_LINE_CHARS) + ' id=' + m.group(2);
                if (items.size() >= SUMMARY_ITEMS_PER_SECTION || used + item.length() + 1 > SUMMARY_CONTEXT_CHARS - 40) {
                    more++;
                    continue;
                }
                items.add(item);
                used += item.length() + 1;
            }
            if (items.isEmpty()) {
                continue;
            }
            String title = String.isBlank(s.title) ? s.key : s.title;
            lines.add(title + ':');
            lines.addAll(items);
            used += title.length() + 2;
            if (more > 0) {
                String note = '(' + more + ' more not listed)';
                lines.add(note);
                used += note.length() + 1;
            }
        }
        return String.join(lines, '\n');
    }

    /** The column labels, or the columns themselves when a hand-built result set has none. */
    public static List<String> headers(ExploreQuery.ResultSet rs) {
        return rs.labels.size() == rs.columns.size() ? rs.labels : rs.columns;
    }

    /** Column labels, then up to PREVIEW_ROWS rows, pipe-separated, each cell clipped. Rows are read by column path. */
    @TestVisible
    private static String preview(ExploreQuery.ResultSet rs) {
        List<String> lines = new List<String>{ String.join(headers(rs), ' | ') };
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
