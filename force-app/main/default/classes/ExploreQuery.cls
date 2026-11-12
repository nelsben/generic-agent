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

    /** The row cap in force. Tests lower it. */
    @TestVisible private static Integer rowCap = ROW_CAP;

    /** Thrown instead of running an aggregate that would read more than the row cap. */
    public class RowCapException extends Exception {}

    /** One query's result, for the model preview, the trail and the UI. */
    public class ResultSet {
        @AuraEnabled public String objectName;
        @AuraEnabled public List<String> columns = new List<String>();
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
        /** Aggregate queries: the alias each column is read from. */
        List<String> aliases = new List<String>();
        Boolean aggregate = false;
        /** Every aggregate is COUNT(Id): reads one query row per group, so it needs no row cap. */
        Boolean countOnly = false;
        Integer rowLimit;
        String filters;
    }

    /** Resolves, builds and runs the plan. Throws ExplorePlan.PlanException when the plan has errors. */
    public static ResultSet run(ExplorePlan plan) {
        ExplorePlan.Resolved r = ExplorePlan.resolve(plan);
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

        ResultSet rs = new ResultSet();
        rs.objectName = r.entry.name;
        rs.columns = b.columns;
        rs.soql = b.soql;
        rs.filters = b.filters;
        rs.plan = plan;
        rs.planJson = plan.toJson();
        for (SObject rec : records) {
            Map<String, Object> row = new Map<String, Object>();
            for (Integer i = 0; i < b.columns.size(); i++) {
                row.put(b.columns[i], b.aggregate ? rec.get(b.aliases[i]) : valueAt(rec, b.columns[i]));
            }
            if (!b.aggregate) {
                row.put('Id', rec.Id);
            }
            rs.rows.add(row);
        }
        rs.shown = rs.rows.size();
        rs.total = rs.shown;
        if (!b.aggregate && b.rowLimit != null && rs.shown >= b.rowLimit) {
            rs.total = Database.countQueryWithBinds(b.countSoql, b.binds, AccessLevel.USER_MODE);
        }
        return rs;
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

        List<String> selects = new List<String>();
        if (b.aggregate) {
            for (Integer i = 0; i < r.groupBy.size(); i++) {
                selects.add(r.groupBy[i].path + ' g' + i);
                b.columns.add(r.groupBy[i].path);
                b.aliases.add('g' + i);
            }
            b.countOnly = !r.aggregates.isEmpty();
            for (Integer i = 0; i < r.aggregates.size(); i++) {
                b.countOnly = b.countOnly && r.aggregates[i].expr == 'COUNT(Id)';
                selects.add(r.aggregates[i].expr + ' a' + i);
                b.columns.add(r.aggregates[i].expr);
                b.aliases.add('a' + i);
            }
        } else {
            Set<String> seen = new Set<String>();
            for (ExploreCatalog.Field f : r.fields) {
                if (seen.add(f.path)) {
                    b.columns.add(f.path);
                    selects.add(f.path);
                }
            }
            if (!seen.contains('Id')) {
                selects.add('Id');
            }
        }

        List<String> conditions = new List<String>();
        List<String> readable = new List<String>();
        for (Integer i = 0; i < r.filters.size(); i++) {
            ExplorePlan.ResolvedFilter f = r.filters[i];
            if (f.literal != null) {
                conditions.add(f.field.path + ' ' + f.op + ' ' + f.literal);
            } else {
                b.binds.put('b' + i, f.bindValue);
                conditions.add(f.field.path + ' ' + f.op + ' :b' + i);
            }
            readable.add(f.display);
        }
        b.filters = readable.isEmpty() ? 'no filters' : String.join(readable, ' AND ');

        String fromWhere = ' FROM ' + r.entry.name + (conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND '));
        String soql = 'SELECT ' + String.join(selects, ', ') + fromWhere;
        if (!r.groupBy.isEmpty()) {
            List<String> groups = new List<String>();
            for (ExploreCatalog.Field g : r.groupBy) {
                groups.add(g.path);
            }
            soql += ' GROUP BY ' + String.join(groups, ', ');
        }
        if (r.orderExpr != null) {
            soql += ' ORDER BY ' + r.orderExpr + (r.orderDir == 'DESC' ? ' DESC NULLS LAST' : ' ASC');
        }
        if (r.rowLimit != null) {
            soql += ' LIMIT ' + String.valueOf(r.rowLimit);
        }
        b.soql = soql;
        b.countSoql = 'SELECT COUNT()' + fromWhere;
        return b;
    }

    /** A field or one-level parent path off a record; null when the parent lookup is empty. */
    @TestVisible
    private static Object valueAt(SObject rec, String path) {
        Integer dot = path.indexOf('.');
        if (dot < 0) {
            return rec.get(path);
        }
        SObject parent = rec.getSObject(path.substring(0, dot));
        return parent == null ? null : parent.get(path.substring(dot + 1));
    }
}
