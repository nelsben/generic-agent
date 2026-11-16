/**
 * ExploreQuery: builds and runs one query from an ExplorePlan.
 *
 * Read-only: no DML.
 *
 * run() resolves the plan itself (ExplorePlan.resolve) and refuses one with errors, so no caller can
 * skip the catalog check. The SOQL text is assembled only from the resolved plan: catalog field paths,
 * fixed operators and date literal tokens, aliases and integers made here. Every filter value is a
 * bind variable. The row limit defaults to DEFAULT_LIMIT and is clamped to MAX_LIMIT; an aggregate
 * without groupBy returns one row and has no LIMIT. Queries run in user mode, so the user's object,
 * field and sharing access all apply. When a plain query fills its limit, one COUNT() query gives the total.
 *
 * Grammar v2 (BE-43): the WHERE clause is built from the resolved tree (groups in parentheses, NOT as
 * (NOT (...)), a semi- or anti-join as a sub-select), child lists are sub-selects in the field list,
 * HAVING binds its values too, and binds are named :b0, :b1, ... in the order they appear. CONTAINS on
 * long text, which the platform can't filter, reads at most TEXT_SCAN candidate rows and keeps those whose
 * text holds the value, ignoring case; total is then the number that matched.
 *
 * Long text past the scan cap (BE-44). When more than TEXT_SCAN rows match the other filters, a SOSL search
 * in user mode narrows them: the value's words, each as a word start (renewal*), ANDed, over the object's
 * own fields, at most SEARCH_CAP records. The same query then reads only those records (Id IN :bN) and the
 * same Apex match keeps the ones whose text holds the value, so a word found in another field never counts.
 * It throws RowCapException, saying how many rows it scanned and that there is no full count, when the search
 * fills SEARCH_CAP or can't narrow the value (no word of two or more letters or digits, a parent path, an
 * object search doesn't cover). The search finds word starts only, and a record saved in the last few
 * minutes may not be in the index yet (docs/research/fr2-explorer-long-text.md).
 *
 * Row cap. A LIMIT on an aggregate limits the groups returned, not the records aggregated, and every
 * aggregated record counts toward the 50,000 query-row limit, whose LimitException cannot be caught.
 * So an aggregate first runs a COUNT() with LIMIT rowCap + 1, and when more than rowCap records match
 * it throws RowCapException instead of running. A COUNT() reads one query row however many records
 * match, and a COUNT(Id) aggregate reads one row per group it returns (ExploreQueryTest measures
 * both). So the pre-count is cheap, the plain total COUNT() needs no cap, and an aggregate whose only
 * functions are COUNT(Id) skips the pre-count: its groups are bounded by the LIMIT. One question runs at most DataExplorer.MAX_QUERIES (4) queries, each reading at most
 * ROW_CAP + 1 rows, so a whole question stays under 50,000 rows; the cap also shrinks to what is left
 * of the transaction's row limit.
 */
public with sharing class ExploreQuery {
    public static final Integer DEFAULT_LIMIT = 50;
    public static final Integer MAX_LIMIT = 200;
    public static final Integer ROW_CAP = 10000;
    /** CONTAINS on long text reads at most this many candidate rows, then matches them in Apex. */
    public static final Integer TEXT_SCAN = 2000;
    /** Past the scan cap, a search narrows the candidates to at most this many records (SOSL's own maximum). */
    public static final Integer SEARCH_CAP = 2000;

    /** The row cap in force. Tests lower it. */
    @TestVisible private static Integer rowCap = ROW_CAP;
    /** The long-text scan cap in force. Tests lower it. */
    @TestVisible private static Integer textScan = TEXT_SCAN;
    /** The search cap in force. Tests lower it. */
    @TestVisible private static Integer searchCap = SEARCH_CAP;

    /** Thrown instead of running an aggregate that would read more than the row cap. */
    public class RowCapException extends Exception {}

    /** One query's result, for the model preview, the trail and the UI. */
    public class ResultSet {
        @AuraEnabled public String objectName;
        @AuraEnabled public List<String> columns = new List<String>();
        /** A plain label per column (no dots), same order, unique. For text shown to people and the model; rows stay keyed by columns. */
        @AuraEnabled public List<String> labels = new List<String>();
        /** One map per row, keyed by column. Plain (non-aggregate) rows also carry the record Id under 'Id'. */
        @AuraEnabled public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        /** Rows matching the filters (a COUNT() when the limit was reached), or groups returned. */
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer shown = 0;
        /** The filters in readable form, for the trail. */
        @AuraEnabled public String filters;
        /** The SOQL text that ran, with :bN bind names in place of values. */
        @AuraEnabled public String soql;
        @AuraEnabled public String planJson;
        public ExplorePlan plan;
    }

    @TestVisible
    private class Built {
        String soql;
        String countSoql;
        Map<String, Object> binds = new Map<String, Object>();
        List<String> columns = new List<String>();
        List<String> labels = new List<String>();
        /** Aggregate queries: the alias each column is read from. */
        List<String> aliases = new List<String>();
        /** Columns that hold a child list: the cell is its row count. */
        Set<String> childColumns = new Set<String>();
        /** CONTAINS on long text, matched after the query. */
        List<ExplorePlan.TextMatch> textMatches = new List<ExplorePlan.TextMatch>();
        Boolean aggregate = false;
        /** Every aggregate is COUNT(Id): reads one query row per group, so it needs no row cap. */
        Boolean countOnly = false;
        Integer rowLimit;
        String filters;
        /** The text query in parts, so a search can add Id IN :bN: SELECT ... FROM X, the WHERE clause, ORDER BY. */
        String selectFrom;
        String whereClause;
        String orderClause = '';
        /** The next bind number: binds are named in the order they appear in the text. */
        Integer next = 0;
    }

    /** Resolves, builds and runs the plan. Throws ExplorePlan.PlanException when the plan has errors. */
    public static ResultSet run(ExplorePlan plan) {
        return run(plan, null);
    }

    /** run() for a plan whose step values read the question's earlier results (ExplorePlan.resolve). */
    public static ResultSet run(ExplorePlan plan, List<ResultSet> steps) {
        ExplorePlan.Resolved r = ExplorePlan.resolve(plan, steps);
        if (!r.errors.isEmpty()) {
            throw new ExplorePlan.PlanException(String.join(r.errors, ' '));
        }
        Built b = build(r);
        if (b.aggregate && !b.countOnly) {
            Integer cap = effectiveCap();
            if (Database.countQueryWithBinds(b.countSoql + ' LIMIT ' + (cap + 1), b.binds, AccessLevel.USER_MODE) > cap) {
                throw new RowCapException('That would read more than ' + cap + ' rows. Add filters to narrow it.');
            }
        }
        List<SObject> records = Database.queryWithBinds(b.soql, b.binds, AccessLevel.USER_MODE);
        Integer matched;
        if (!b.textMatches.isEmpty()) {
            if (records.size() > textScan) {
                records = searched(r, b);
            }
            records = matching(records, b.textMatches);
            matched = records.size();
        }

        ResultSet rs = new ResultSet();
        rs.objectName = r.entry.name;
        rs.columns = b.columns;
        rs.labels = b.labels;
        rs.soql = b.soql;
        rs.filters = b.filters;
        rs.plan = plan;
        rs.planJson = plan.toJson();
        for (SObject rec : records) {
            if (b.rowLimit != null && rs.rows.size() >= b.rowLimit) {
                break;
            }
            rs.rows.add(row(b, rec));
        }
        rs.shown = rs.rows.size();
        rs.total = matched != null ? matched : rs.shown;
        if (matched == null && !b.aggregate && b.rowLimit != null && rs.shown >= b.rowLimit) {
            rs.total = Database.countQueryWithBinds(b.countSoql, b.binds, AccessLevel.USER_MODE);
        }
        return rs;
    }

    private static Map<String, Object> row(Built b, SObject rec) {
        Map<String, Object> row = new Map<String, Object>();
        for (Integer i = 0; i < b.columns.size(); i++) {
            String c = b.columns[i];
            if (b.aggregate) {
                row.put(c, rec.get(b.aliases[i]));
            } else if (b.childColumns.contains(c)) {
                List<SObject> kids = rec.getSObjects(c);
                row.put(c, kids == null ? 0 : kids.size());
            } else {
                row.put(c, valueAt(rec, c));
            }
        }
        if (!b.aggregate) {
            row.put('Id', rec.Id);
        }
        return row;
    }

    /**
     * Past the scan cap: a search in user mode finds the records holding the words, and the same query reads
     * only those. Throws RowCapException when the search can't narrow the value or fills its cap.
     */
    private static List<SObject> searched(ExplorePlan.Resolved r, Built b) {
        String term = searchable(r) ? searchTerms(b.textMatches) : null;
        if (term == null) {
            throw capped(textScan, 'More rows match the other filters, and a search can\'t narrow this value.');
        }
        // term holds only letters, digits, spaces and *, and the object name comes from the catalog.
        List<SObject> hits = Search.query('FIND \'' + term + '\' IN ALL FIELDS RETURNING ' + r.entry.name
            + '(Id) LIMIT ' + searchCap, AccessLevel.USER_MODE)[0];
        if (hits.size() >= searchCap) {
            throw capped(searchCap, 'The search found ' + searchCap + ' or more records with those words, the most it reads.');
        }
        String name = bind(b, new List<Id>(new Map<Id, SObject>(hits).keySet()));
        b.soql = b.selectFrom + (b.whereClause == '' ? ' WHERE ' : b.whereClause + ' AND ') + 'Id IN :' + name
            + b.orderClause + ' LIMIT ' + searchCap;
        b.filters += ' (narrowed by search)';
        return Database.queryWithBinds(b.soql, b.binds, AccessLevel.USER_MODE);
    }

    private static RowCapException capped(Integer scanned, String why) {
        return new RowCapException('CONTAINS on long text stopped at its cap after scanning ' + scanned
            + ' rows, so there is no full count. ' + why + ' Add filters to narrow it.');
    }

    /** A search covers the object's own fields only, and only an object the platform can search. */
    private static Boolean searchable(ExplorePlan.Resolved r) {
        for (ExplorePlan.TextMatch t : r.textMatches) {
            if (t.field.path.contains('.')) {
                return false;
            }
        }
        List<Schema.DescribeSObjectResult> d = Schema.describeSObjects(new List<String>{ r.entry.name });
        return !d.isEmpty() && d[0].isSearchable();
    }

    private static String searchTerms(List<ExplorePlan.TextMatch> matches) {
        List<String> terms = new List<String>();
        for (ExplorePlan.TextMatch t : matches) {
            String one = searchTerm(t.text);
            if (one == null) {
                return null;
            }
            terms.add(one);
        }
        return String.join(terms, ' ');
    }

    /**
     * The SOSL text for one value: its words of two or more letters or digits, lower case, each as a word
     * start (renewal*), joined by spaces, which SOSL ANDs. AND, OR and NOT are SOSL operators, so they are
     * dropped. Null when no word is left. Nothing else of the value reaches the search text.
     */
    public static String searchTerm(String text) {
        List<String> words = new List<String>();
        for (String w : (text == null ? '' : text.toLowerCase()).split('[^\\p{L}\\p{N}]+')) {
            if (w.length() >= 2 && w != 'and' && w != 'or' && w != 'not') {
                words.add(w + '*');
            }
        }
        return words.isEmpty() ? null : String.join(words, ' ');
    }

    /** The records whose long text holds every CONTAINS value, ignoring case. */
    private static List<SObject> matching(List<SObject> records, List<ExplorePlan.TextMatch> matches) {
        List<SObject> out = new List<SObject>();
        for (SObject rec : records) {
            Boolean all = true;
            for (ExplorePlan.TextMatch t : matches) {
                Object v = valueAt(rec, t.field.path);
                all = all && v != null && String.valueOf(v).toLowerCase().contains(t.text.toLowerCase());
            }
            if (all) {
                out.add(rec);
            }
        }
        return out;
    }

    /** rowCap, or less when the transaction has fewer query rows left (one goes to the pre-count). */
    private static Integer effectiveCap() {
        Integer left = Limits.getLimitQueryRows() - Limits.getQueryRows();
        return Math.max(0, Math.min(rowCap, left - 1));
    }

    /** The SOQL for a resolved plan. Only catalog paths, fixed tokens and local names reach the text. */
    @TestVisible
    private static Built build(ExplorePlan.Resolved r) {
        Built b = new Built();
        b.aggregate = !r.aggregates.isEmpty() || !r.groupBy.isEmpty();
        b.rowLimit = r.rowLimit;
        b.textMatches = r.textMatches;

        List<String> selects = new List<String>();
        if (b.aggregate) {
            for (Integer i = 0; i < r.groupBy.size(); i++) {
                selects.add(r.groupBy[i].path + ' g' + i);
                b.columns.add(r.groupBy[i].path);
                b.labels.add(r.groupBy[i].label);
                b.aliases.add('g' + i);
            }
            b.countOnly = !r.aggregates.isEmpty();
            for (Integer i = 0; i < r.aggregates.size(); i++) {
                b.countOnly = b.countOnly && r.aggregates[i].expr == 'COUNT(Id)';
                selects.add(r.aggregates[i].expr + ' a' + i);
                b.columns.add(r.aggregates[i].expr);
                b.labels.add(aggregateLabel(r.aggregates[i]));
                b.aliases.add('a' + i);
            }
        } else {
            Set<String> seen = new Set<String>();
            for (ExploreCatalog.Field f : r.fields) {
                if (seen.add(f.path)) {
                    b.columns.add(f.path);
                    b.labels.add(f.label);
                    selects.add(f.path);
                }
            }
            if (seen.add('Id')) {
                selects.add('Id');
            }
            for (ExplorePlan.TextMatch t : r.textMatches) {
                if (seen.add(t.field.path)) {
                    selects.add(t.field.path);
                }
            }
            for (ExplorePlan.ResolvedChild c : r.children) {
                selects.add('(' + childSelect(b, c) + ')');
                b.columns.add(c.rel);
                b.labels.add(c.rel);
                b.childColumns.add(c.rel);
            }
        }

        List<String> trail = new List<String>();
        String whereClause = '';
        if (r.whereTree != null) {
            whereClause = ' WHERE ' + clause(b, r.whereTree, true);
            trail.add(readable(r.whereTree, true));
        }
        for (ExplorePlan.TextMatch t : r.textMatches) {
            trail.add(t.field.path + ' CONTAINS ' + t.text);
        }
        b.filters = trail.isEmpty() ? 'no filters' : String.join(trail, ' AND ');

        String fromWhere = ' FROM ' + r.entry.name + whereClause;
        String soql = 'SELECT ' + String.join(selects, ', ') + fromWhere;
        b.selectFrom = 'SELECT ' + String.join(selects, ', ') + ' FROM ' + r.entry.name;
        b.whereClause = whereClause;
        if (!r.groupBy.isEmpty()) {
            List<String> groups = new List<String>();
            for (ExploreCatalog.Field g : r.groupBy) {
                groups.add(g.path);
            }
            soql += ' GROUP BY ' + String.join(groups, ', ');
        }
        if (!r.havingFilters.isEmpty()) {
            List<String> parts = new List<String>();
            for (ExplorePlan.ResolvedHaving h : r.havingFilters) {
                String name = bind(b, h.bindValue);
                parts.add(h.aggregate.expr + ' ' + h.op + ' :' + name);
            }
            soql += ' HAVING ' + String.join(parts, ' AND ');
        }
        if (r.orderExpr != null) {
            b.orderClause = ' ORDER BY ' + r.orderExpr + (r.orderDir == 'DESC' ? ' DESC NULLS LAST' : ' ASC');
            soql += b.orderClause;
        }
        if (!r.textMatches.isEmpty()) {
            // Long text is matched in Apex, so read every candidate, up to the scan cap plus one to detect more.
            soql += ' LIMIT ' + String.valueOf(textScan + 1);
        } else if (r.rowLimit != null) {
            soql += ' LIMIT ' + String.valueOf(r.rowLimit);
        }
        b.soql = soql;
        b.labels = uniqueLabels(b.labels);
        b.countSoql = 'SELECT COUNT()' + fromWhere;
        return b;
    }

    private static String bind(Built b, Object value) {
        String name = 'b' + b.next++;
        b.binds.put(name, value);
        return name;
    }

    /** (SELECT Id, fields FROM Relationship WHERE ... LIMIT n): relationship and paths from the catalog. */
    private static String childSelect(Built b, ExplorePlan.ResolvedChild c) {
        List<String> paths = new List<String>{ 'Id' };
        Set<String> seen = new Set<String>{ 'Id' };
        for (ExploreCatalog.Field f : c.fields) {
            if (seen.add(f.path)) {
                paths.add(f.path);
            }
        }
        return 'SELECT ' + String.join(paths, ', ') + ' FROM ' + c.rel
            + (c.whereTree == null ? '' : ' WHERE ' + clause(b, c.whereTree, true))
            + ' LIMIT ' + String.valueOf(c.rowLimit);
    }

    /** A WHERE clause from the resolved tree. Groups are parenthesised; the root AND is not. */
    private static String clause(Built b, ExplorePlan.Node n, Boolean root) {
        if (n.kind == ExplorePlan.NODE_FILTER) {
            return condition(b, n.filter);
        }
        if (n.kind == ExplorePlan.NODE_SUB) {
            ExplorePlan.ResolvedSub s = n.sub;
            return s.left.path + ' ' + s.op + ' (SELECT ' + s.right.path + ' FROM ' + s.entry.name
                + (s.whereTree == null ? '' : ' WHERE ' + clause(b, s.whereTree, true)) + ')';
        }
        List<String> parts = new List<String>();
        for (ExplorePlan.Node c : n.children) {
            parts.add(clause(b, c, false));
        }
        if (n.kind == ExplorePlan.NODE_NOT) {
            // A group child is already in parentheses; a single condition gets its own.
            return parts.size() == 1 && n.children[0].kind != ExplorePlan.NODE_FILTER
                ? '(NOT ' + parts[0] + ')'
                : '(NOT (' + String.join(parts, ' AND ') + '))';
        }
        if (n.kind == ExplorePlan.NODE_OR) {
            return '(' + String.join(parts, ' OR ') + ')';
        }
        return root ? String.join(parts, ' AND ') : '(' + String.join(parts, ' AND ') + ')';
    }

    /** The trail's readable form of the same tree. */
    private static String readable(ExplorePlan.Node n, Boolean root) {
        if (n.kind == ExplorePlan.NODE_FILTER) {
            return n.filter.display;
        }
        if (n.kind == ExplorePlan.NODE_SUB) {
            ExplorePlan.ResolvedSub s = n.sub;
            return s.left.path + ' ' + s.op + ' (' + s.entry.name + ' ' + s.right.path
                + (s.whereTree == null ? '' : ' where ' + readable(s.whereTree, true)) + ')';
        }
        List<String> parts = new List<String>();
        for (ExplorePlan.Node c : n.children) {
            parts.add(readable(c, false));
        }
        if (n.kind == ExplorePlan.NODE_NOT) {
            return parts.size() == 1 && n.children[0].kind != ExplorePlan.NODE_FILTER
                ? 'NOT ' + parts[0]
                : 'NOT (' + String.join(parts, ' AND ') + ')';
        }
        if (n.kind == ExplorePlan.NODE_OR) {
            return '(' + String.join(parts, ' OR ') + ')';
        }
        return root ? String.join(parts, ' AND ') : '(' + String.join(parts, ' AND ') + ')';
    }

    /** One condition, every value bound. */
    private static String condition(Built b, ExplorePlan.ResolvedFilter f) {
        String p = f.field.path;
        if (f.literal != null) {
            return p + ' ' + f.op + ' ' + f.literal;
        }
        Integer i = b.next++;
        if (f.bindValueEnd != null) {
            // A whole day on a Datetime field: a range, never a match on the one instant of midnight.
            b.binds.put('b' + i, f.bindValue);
            b.binds.put('e' + i, f.bindValueEnd);
            return f.op == '='
                ? '(' + p + ' >= :b' + i + ' AND ' + p + ' < :e' + i + ')'
                : '(' + p + ' < :b' + i + ' OR ' + p + ' >= :e' + i + ' OR ' + p + ' = null)';
        }
        if (f.bindValueEnds != null) {
            // IN on a Datetime field with date-only items: each one is a whole-day range.
            List<Object> starts = (List<Object>) f.bindValue;
            List<String> parts = new List<String>();
            for (Integer j = 0; j < starts.size(); j++) {
                b.binds.put('b' + i + '_' + j, starts[j]);
                if (f.bindValueEnds[j] == null) {
                    parts.add(p + ' = :b' + i + '_' + j);
                } else {
                    b.binds.put('e' + i + '_' + j, f.bindValueEnds[j]);
                    parts.add('(' + p + ' >= :b' + i + '_' + j + ' AND ' + p + ' < :e' + i + '_' + j + ')');
                }
            }
            String anyDay = '(' + String.join(parts, ' OR ') + ')';
            return f.op == 'NOT IN' ? '(NOT ' + anyDay + ')' : anyDay;
        }
        b.binds.put('b' + i, f.bindValue);
        return p + ' ' + (f.bindOp != null ? f.bindOp : f.op) + ' :b' + i;
    }

    /** Count, Sum of Amount, Average of Account Industry: no dots, no parentheses. */
    private static String aggregateLabel(ExplorePlan.ResolvedAggregate a) {
        String fn = a.fn == 'AVG' ? 'Average' : a.fn.left(1) + a.fn.substring(1).toLowerCase();
        return a.fn == 'COUNT' && a.field.path == 'Id' ? fn : fn + ' of ' + a.field.label;
    }

    /** The labels with repeats numbered (Owner, Owner 2), so two columns never share one. Case-insensitive. */
    @TestVisible
    private static List<String> uniqueLabels(List<String> labels) {
        Set<String> taken = new Set<String>();
        List<String> out = new List<String>();
        for (String l : labels) {
            String candidate = l;
            Integer n = 2;
            while (!taken.add(candidate.toLowerCase())) {
                candidate = l + ' ' + n++;
            }
            out.add(candidate);
        }
        return out;
    }

    /** A field or a parent path (one or two lookups) off a record; null when a lookup on the way is empty. */
    @TestVisible
    private static Object valueAt(SObject rec, String path) {
        List<String> parts = path.split('\\.');
        SObject cur = rec;
        for (Integer i = 0; i < parts.size() - 1 && cur != null; i++) {
            cur = cur.getSObject(parts[i]);
        }
        return cur == null ? null : cur.get(parts[parts.size() - 1]);
    }
}
