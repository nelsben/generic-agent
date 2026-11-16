/**
 * ExplorePlan: the only query shape the model may emit, parsed from JSON (grammar v2, BE-43).
 *
 *   { "object": "Opportunity",
 *     "fields": ["Name", "Amount", "Account.Owner.Name"],                         // up to two lookups deep
 *     "filters": [ { "field": "StageName", "op": "=", "value": "Closed Won" } ],   // joined by AND
 *     "where": { "or": [ {condition}, { "and": [...] }, { "not": {condition} } ] }, // ANDed with filters
 *     "orderBy": { "field": "Amount", "dir": "DESC" },
 *     "limit": 10,
 *     "groupBy": ["Owner.Name"],
 *     "aggregates": [ { "fn": "SUM", "field": "Amount" } ],
 *     "having": [ { "fn": "COUNT", "field": "", "op": ">", "value": 3 } ],
 *     "children": [ { "rel": "Cases", "fields": ["Subject"], "where": {...}, "limit": 5 } ] }
 *
 * A condition is { "field", "op", "value" }, with op one of OPS. Two special forms:
 *   - a semi- or anti-join: { "field": "Id", "op": "IN" | "NOT IN", "sub": { "object", "field", "where" } };
 *   - a step value: { "field": "AccountId", "op": "IN", "value": { "step": 1, "field": "Id" } } reads the
 *     record ids of an earlier query of the same question (resolve(plan, steps)).
 * CONTAINS on a text field is LIKE '%value%'; on long text it is a post-filter ExploreQuery applies.
 *
 * resolve() checks every name against ExploreCatalog for the running user and returns canonical
 * pieces: catalog field paths, a fixed operator, a fixed date literal token or a typed bind value.
 * validate() returns its plain-English errors, each one a fixed line the model can act on. ExploreQuery
 * builds SOQL only from a resolved plan, so no text from the model is ever concatenated into a query.
 * The platform rules a plan must meet (measured in spikes/explorer-scale/soql-rules.apex) are checked
 * here, before any query runs: at most 2 "sub", only at the top level, never nested, never on Task or
 * Event or the same object; no filter, ORDER BY or GROUP BY on long text. No DML, no SOQL.
 */
public with sharing class ExplorePlan {
    public class PlanException extends Exception {}

    /** Operators a filter may use. */
    public static final List<String> OPS = new List<String>{ '=', '!=', '<', '<=', '>', '>=', 'LIKE', 'IN', 'NOT IN', 'CONTAINS' };
    /** Comparisons "having" may use. */
    public static final List<String> COMPARISONS = new List<String>{ '=', '!=', '<', '<=', '>', '>=' };
    /** Aggregate functions. COUNT with no field counts Id. */
    public static final List<String> FUNCTIONS = new List<String>{ 'COUNT', 'SUM', 'AVG', 'MIN', 'MAX' };
    /** Date literals a Date or Datetime filter may use as its value. */
    public static final List<String> DATE_LITERALS = new List<String>{
        'YESTERDAY', 'TODAY', 'TOMORROW',
        'LAST_WEEK', 'THIS_WEEK', 'NEXT_WEEK',
        'LAST_MONTH', 'THIS_MONTH', 'NEXT_MONTH',
        'LAST_90_DAYS', 'NEXT_90_DAYS',
        'LAST_QUARTER', 'THIS_QUARTER', 'NEXT_QUARTER',
        'LAST_YEAR', 'THIS_YEAR', 'NEXT_YEAR',
        'LAST_FISCAL_QUARTER', 'THIS_FISCAL_QUARTER', 'NEXT_FISCAL_QUARTER',
        'LAST_FISCAL_YEAR', 'THIS_FISCAL_YEAR', 'NEXT_FISCAL_YEAR'
    };
    /** Date literals that take a count, written NAME:n with n from 1 to MAX_LITERAL_N. */
    public static final List<String> DATE_LITERALS_N = new List<String>{
        'LAST_N_DAYS', 'NEXT_N_DAYS', 'N_DAYS_AGO',
        'LAST_N_WEEKS', 'NEXT_N_WEEKS', 'N_WEEKS_AGO',
        'LAST_N_MONTHS', 'NEXT_N_MONTHS', 'N_MONTHS_AGO',
        'LAST_N_QUARTERS', 'NEXT_N_QUARTERS', 'N_QUARTERS_AGO',
        'LAST_N_YEARS', 'NEXT_N_YEARS', 'N_YEARS_AGO'
    };
    public static final Integer MAX_LITERAL_N = 1000;
    public static final Integer MAX_IN_VALUES = 200;
    /** "sub" (semi- and anti-joins) per plan: the platform allows two. */
    public static final Integer MAX_SUBS = 2;
    /** Conditions per plan, counting those in "sub" and child lists. */
    public static final Integer MAX_CONDITIONS = 20;
    /** How deep "and", "or" and "not" groups may nest. */
    public static final Integer MAX_GROUP_DEPTH = 4;
    public static final Integer MAX_CHILD_LISTS = 2;
    public static final Integer CHILD_LIMIT = 5;
    public static final Integer MAX_CHILD_LIMIT = 10;
    public static final Integer MAX_HAVING = 5;
    private static final Integer MAX_ERRORS = 10;
    private static final Set<String> KEYS = new Set<String>{
        'object', 'fields', 'filters', 'where', 'orderby', 'limit', 'groupby', 'aggregates', 'having', 'children'
    };
    /** Objects the platform refuses as the inner select of a semi-join. */
    private static final Set<String> NO_SUB_OBJECTS = new Set<String>{ 'task', 'event' };
    private static final String DEPTH_ERROR = '"where" parts must be conditions or groups, at most ' + MAX_GROUP_DEPTH + ' deep.';
    private static final Pattern LITERAL_SHAPE = Pattern.compile('^[A-Z][A-Z0-9_]*(:\\s*-?[0-9]+)?$');
    private static final Pattern AGGREGATE_SHAPE = Pattern.compile('^([A-Za-z]+)\\(\\s*([A-Za-z0-9_.]*)\\s*\\)$');
    private static final Pattern DATE_SHAPE = Pattern.compile('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');
    private static final Pattern DATETIME_SHAPE = Pattern.compile('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2}(\\.[0-9]{1,3})?)?(Z|[+-][0-9]{2}:?[0-9]{2})?$');

    public class Filter {
        public String field;
        public String op;
        public Object value;
        /** A semi- or anti-join: { "object", "field", "where" }, as parsed. */
        public Object sub;
    }

    public class OrderBy {
        public String field;
        public String dir;
    }

    public class Aggregate {
        public String fn;
        public String field;
    }

    /** JSON "object". */
    public String objectName;
    public List<String> fields = new List<String>();
    public List<Filter> filters = new List<Filter>();
    public OrderBy orderBy;
    /** JSON "limit". */
    public Integer rowLimit;
    public List<String> groupBy = new List<String>();
    public List<Aggregate> aggregates = new List<Aggregate>();
    /** "and", "or" and "not" groups listed in "filters", as parsed. */
    public List<Object> filterGroups = new List<Object>();
    /** JSON "where": one condition or group, as parsed. */
    public Object whereNode;
    /** JSON "having", as parsed. */
    public List<Object> havingFilters = new List<Object>();
    /** JSON "children", as parsed. */
    public List<Object> children = new List<Object>();
    /** Shape problems found while parsing, reported by validate(). */
    public List<String> parseErrors = new List<String>();

    /** A plan checked against the catalog: only catalog paths, fixed tokens and typed bind values. */
    public class Resolved {
        public List<String> errors = new List<String>();
        public ExploreCatalog.Entry entry;
        public List<ExploreCatalog.Field> fields = new List<ExploreCatalog.Field>();
        /** Every condition on the plan's own object, flat, wherever it sits in the tree. */
        public List<ResolvedFilter> filters = new List<ResolvedFilter>();
        /** The WHERE clause as a tree (null when there is none). The query is built from this. */
        public Node whereTree;
        /** CONTAINS on long text: matched in Apex after the query, ANDed with the WHERE clause. */
        public List<TextMatch> textMatches = new List<TextMatch>();
        public List<ExploreCatalog.Field> groupBy = new List<ExploreCatalog.Field>();
        public List<ResolvedAggregate> aggregates = new List<ResolvedAggregate>();
        public List<ResolvedHaving> havingFilters = new List<ResolvedHaving>();
        public List<ResolvedChild> children = new List<ResolvedChild>();
        /** ORDER BY expression built from catalog paths, or null. */
        public String orderExpr;
        public String orderDir;
        public Integer rowLimit;
    }

    public static final String NODE_AND = 'and';
    public static final String NODE_OR = 'or';
    public static final String NODE_NOT = 'not';
    public static final String NODE_FILTER = 'filter';
    public static final String NODE_SUB = 'sub';

    /** One part of a WHERE clause: a group of children, a condition or a semi-join. */
    public class Node {
        public String kind;
        public List<Node> children = new List<Node>();
        public ResolvedFilter filter;
        public ResolvedSub sub;
    }

    /** left op (SELECT right FROM entry WHERE whereTree). */
    public class ResolvedSub {
        public ExploreCatalog.Field left;
        public String op;
        public ExploreCatalog.Entry entry;
        public ExploreCatalog.Field right;
        public Node whereTree;
    }

    /** A case-insensitive substring match on a long text field, applied in Apex. */
    public class TextMatch {
        public ExploreCatalog.Field field;
        public String text;
    }

    public class ResolvedHaving {
        public ResolvedAggregate aggregate;
        public String op;
        public Object bindValue;
    }

    /** A child list: (SELECT Id, fields FROM rel WHERE whereTree LIMIT rowLimit). */
    public class ResolvedChild {
        public String rel;
        public ExploreCatalog.Entry entry;
        public List<ExploreCatalog.Field> fields = new List<ExploreCatalog.Field>();
        public Node whereTree;
        public Integer rowLimit;
    }

    public class ResolvedFilter {
        public ExploreCatalog.Field field;
        public String op;
        /** A DATE_LITERALS token rebuilt by this class, or null when the value is bound. */
        public String literal;
        public Object bindValue;
        /**
         * Set only for = or != on a Datetime field with a date-only value: the start of the next day in the
         * running user's time zone. bindValue is then the start of that day, and the filter is the range
         * [bindValue, bindValueEnd).
         */
        public Datetime bindValueEnd;
        /**
         * Set only for > or <= on a Datetime field with a date-only value: the operator to run (>= or <)
         * against bindValue, which is then the start of the next day, so the whole day is covered.
         */
        public String bindOp;
        /**
         * Set only for IN on a Datetime field: one entry per bindValue item, the start of the next day when
         * that item is date-only (the item matches [start, end)), or null when it is a full datetime.
         */
        public List<Datetime> bindValueEnds;
        /** For the trail only, never for the query. */
        public String display;
    }

    public class ResolvedAggregate {
        public String fn;
        public ExploreCatalog.Field field;
        /** FN(path), e.g. SUM(Amount). */
        public String expr;
    }

    // ---------------------------------------------------------------- parse

    /** Parses one plan from JSON text. Never throws: shape problems land in parseErrors. */
    public static ExplorePlan fromJson(String text) {
        Object raw;
        try {
            raw = JSON.deserializeUntyped(text);
        } catch (Exception e) {
            ExplorePlan p = new ExplorePlan();
            p.parseErrors.add('The plan is not valid JSON.');
            return p;
        }
        return fromObject(raw);
    }

    /** Parses one plan from deserialized JSON. Never throws: shape problems land in parseErrors. */
    public static ExplorePlan fromObject(Object raw) {
        ExplorePlan p = new ExplorePlan();
        if (!(raw instanceof Map<String, Object>)) {
            p.parseErrors.add('The plan must be a JSON object.');
            return p;
        }
        Map<String, Object> m = lowerKeys((Map<String, Object>) raw);
        for (String key : m.keySet()) {
            if (!KEYS.contains(key)) {
                p.parseErrors.add('Unknown plan key "' + key + '". Use only: object, fields, filters, where, orderBy, limit, '
                    + 'groupBy, aggregates, having, children.');
            }
        }
        p.objectName = text(m.get('object'));
        p.fields = strings(m.get('fields'), 'fields', p.parseErrors);
        p.groupBy = strings(m.get('groupby'), 'groupBy', p.parseErrors);
        p.whereNode = m.get('where');
        p.havingFilters = asList(m.get('having'), 'having', p.parseErrors);
        p.children = asList(m.get('children'), 'children', p.parseErrors);

        for (Object item : asList(m.get('filters'), 'filters', p.parseErrors)) {
            if (item instanceof Map<String, Object> && isGroup(lowerKeys((Map<String, Object>) item))) {
                p.filterGroups.add(item);
            } else if (item instanceof Map<String, Object>) {
                Map<String, Object> fm = lowerKeys((Map<String, Object>) item);
                Filter f = new Filter();
                f.field = text(fm.get('field'));
                f.op = text(fm.get('op'));
                f.value = fm.get('value');
                f.sub = fm.get('sub');
                p.filters.add(f);
            } else {
                p.parseErrors.add('Each filter must be an object with field, op and value.');
            }
        }

        for (Object item : asList(m.get('aggregates'), 'aggregates', p.parseErrors)) {
            if (item instanceof Map<String, Object>) {
                Map<String, Object> am = lowerKeys((Map<String, Object>) item);
                Aggregate a = new Aggregate();
                a.fn = text(am.get('fn'));
                a.field = text(am.get('field'));
                p.aggregates.add(a);
            } else {
                p.parseErrors.add('Each aggregate must be an object with fn and field.');
            }
        }

        Object ob = m.get('orderby');
        if (ob instanceof Map<String, Object>) {
            Map<String, Object> om = lowerKeys((Map<String, Object>) ob);
            p.orderBy = new OrderBy();
            p.orderBy.field = text(om.get('field'));
            p.orderBy.dir = text(om.get('dir'));
        } else if (ob instanceof String && String.isNotBlank((String) ob)) {
            p.orderBy = new OrderBy();
            p.orderBy.field = (String) ob;
        } else if (ob != null) {
            p.parseErrors.add('orderBy must be an object with field and dir.');
        }

        Object lim = m.get('limit');
        if (lim != null) {
            try {
                Decimal d = Decimal.valueOf(String.valueOf(lim).trim());
                if (d.scale() > 0 && d != d.round(System.RoundingMode.DOWN)) {
                    throw new PlanException();
                }
                p.rowLimit = d.intValue();
            } catch (Exception e) {
                p.parseErrors.add('limit must be a whole number.');
            }
        }
        return p;
    }

    /** The plan as JSON with the model's key names, for display. */
    public String toJson() {
        List<Object> fs = new List<Object>();
        for (Filter f : filters) {
            Map<String, Object> fm = new Map<String, Object>{ 'field' => f.field, 'op' => f.op, 'value' => f.value };
            if (f.sub != null) {
                fm.put('sub', f.sub);
            }
            fs.add(fm);
        }
        fs.addAll(filterGroups);
        List<Object> ags = new List<Object>();
        for (Aggregate a : aggregates) {
            ags.add(new Map<String, Object>{ 'fn' => a.fn, 'field' => a.field });
        }
        Map<String, Object> m = new Map<String, Object>{
            'object' => objectName, 'fields' => fields, 'filters' => fs,
            'groupBy' => groupBy, 'aggregates' => ags, 'limit' => rowLimit
        };
        if (orderBy != null) {
            m.put('orderBy', new Map<String, Object>{ 'field' => orderBy.field, 'dir' => orderBy.dir });
        }
        if (whereNode != null) {
            m.put('where', whereNode);
        }
        if (!havingFilters.isEmpty()) {
            m.put('having', havingFilters);
        }
        if (!children.isEmpty()) {
            m.put('children', children);
        }
        return JSON.serialize(m);
    }

    private static Boolean isGroup(Map<String, Object> lowered) {
        return lowered.containsKey(NODE_AND) || lowered.containsKey(NODE_OR) || lowered.containsKey(NODE_NOT);
    }

    // ---------------------------------------------------------------- validate

    /** Plain-English problems with the plan; empty when it may run. */
    public static List<String> validate(ExplorePlan plan) {
        return resolve(plan, null).errors;
    }

    /** validate() for a plan whose step values read the earlier results of the same question. */
    public static List<String> validate(ExplorePlan plan, List<ExploreQuery.ResultSet> steps) {
        return resolve(plan, steps).errors;
    }

    /** Checks the plan against the catalog and returns its canonical form (with errors, if any). */
    public static Resolved resolve(ExplorePlan plan) {
        return resolve(plan, null);
    }

    /**
     * resolve() with the question's earlier results, oldest first, for step values. A step value's record
     * ids are written into the plan itself, so the plan's JSON replays without the steps.
     */
    public static Resolved resolve(ExplorePlan plan, List<ExploreQuery.ResultSet> steps) {
        Resolved r = new Resolved();
        if (plan == null) {
            r.errors.add('The plan is missing.');
            return r;
        }
        r.errors.addAll(plan.parseErrors);

        if (String.isBlank(plan.objectName)) {
            r.errors.add('Name one object in "object".');
            return cap(r);
        }
        r.entry = ExploreCatalog.find(plan.objectName);
        if (r.entry == null) {
            List<String> names = new List<String>();
            for (ExploreCatalog.Entry e : ExploreCatalog.entries()) {
                names.add(e.name);
            }
            r.errors.add('Unknown object "' + plan.objectName + '". Use one of: ' + String.join(names, ', ') + '.');
            return cap(r);
        }

        Boolean grouped = !plan.groupBy.isEmpty();
        Boolean aggregated = !plan.aggregates.isEmpty();
        Walk w = new Walk(r, steps);
        w.aggregated = grouped || aggregated;

        for (String path : plan.fields) {
            ExploreCatalog.Field f = knownField(r, r.entry, path);
            if (f != null) {
                r.fields.add(f);
            }
        }
        for (String path : plan.groupBy) {
            ExploreCatalog.Field f = knownField(r, r.entry, path);
            if (f != null && !f.groupable) {
                r.errors.add(f.path + ' can\'t be grouped.');
            } else if (f != null) {
                r.groupBy.add(f);
            }
        }
        for (Aggregate a : plan.aggregates) {
            resolveAggregate(r, a);
        }

        if (!grouped && !aggregated && plan.fields.isEmpty()) {
            r.errors.add('List at least one field in "fields", or use aggregates.');
        }
        if (aggregated && !grouped && !plan.fields.isEmpty()) {
            r.errors.add('Plain fields and aggregates can\'t be mixed without groupBy. Move the fields to groupBy or drop them.');
        }
        if (grouped) {
            Set<String> groupPaths = new Set<String>();
            for (ExploreCatalog.Field g : r.groupBy) {
                groupPaths.add(g.path);
            }
            for (ExploreCatalog.Field f : r.fields) {
                if (!groupPaths.contains(f.path)) {
                    r.errors.add(f.path + ' is in fields but not in groupBy. With groupBy, every field must be grouped.');
                }
            }
        }

        resolveWhere(w, plan);
        resolveHaving(w, plan, grouped);
        resolveChildren(w, plan);
        resolveOrderBy(r, plan, grouped, aggregated);

        // Row limit: default, clamped. A plain aggregate (no groupBy) returns one row and gets no LIMIT.
        if (!(aggregated && !grouped)) {
            Integer lim = plan.rowLimit == null || plan.rowLimit < 1 ? ExploreQuery.DEFAULT_LIMIT : plan.rowLimit;
            r.rowLimit = Math.min(lim, ExploreQuery.MAX_LIMIT);
        }
        return cap(r);
    }

    private static Resolved cap(Resolved r) {
        while (r.errors.size() > MAX_ERRORS) {
            r.errors.remove(r.errors.size() - 1);
        }
        return r;
    }

    /** What one resolve() shares while it walks the plan: counts that span "where", "sub" and child lists. */
    private class Walk {
        Resolved r;
        List<ExploreQuery.ResultSet> steps;
        Boolean aggregated = false;
        Integer conditions = 0;
        Integer subs = 0;

        Walk(Resolved r, List<ExploreQuery.ResultSet> steps) {
            this.r = r;
            this.steps = steps == null ? new List<ExploreQuery.ResultSet>() : steps;
        }

        void error(String message) {
            if (!r.errors.contains(message)) {
                r.errors.add(message);
            }
        }
    }

    private static ExploreCatalog.Field knownField(Resolved r, ExploreCatalog.Entry e, String path) {
        return pathField(e, path, r.errors);
    }

    // ---------------------------------------------------------------- paths

    /** Per transaction: user and lower-case object:path -> a two-lookup field, or null when refused. */
    private static Map<String, ExploreCatalog.Field> deepPaths = new Map<String, ExploreCatalog.Field>();
    /** Per transaction: lower-case object -> lower-case relationship name -> lookup field name. */
    private static Map<String, Map<String, String>> lookupsByObject = new Map<String, Map<String, String>>();
    /** Per transaction: lower-case object -> lower-case child relationship name -> relationship. */
    private static Map<String, Map<String, Schema.ChildRelationship>> childrenByObject = new Map<String, Map<String, Schema.ChildRelationship>>();

    /**
     * The catalog field for a path on an entry: an own field, a parent field (Account.Name) or a field two
     * lookups away (Account.Owner.Name). Null when it is unknown or not allowed for the running user.
     */
    public static ExploreCatalog.Field fieldAt(ExploreCatalog.Entry e, String path) {
        return pathField(e, path, null);
    }

    private static ExploreCatalog.Field pathField(ExploreCatalog.Entry e, String path, List<String> errors) {
        String p = path == null ? '' : path.trim();
        List<String> parts = p.split('\\.');
        if (parts.size() > 3) {
            addError(errors, '"' + p + '" goes more than two lookups deep.');
            return null;
        }
        ExploreCatalog.Field f = parts.size() == 3 ? twoLookups(e, parts) : e.field(p);
        if (f == null) {
            addError(errors, parts.size() > 1 && lookupField(e.name, parts[0]) == null
                ? 'Unknown lookup "' + parts[0] + '" in "' + p + '".'
                : 'Unknown field "' + p + '" on ' + e.name + '.');
        }
        return f;
    }

    private static void addError(List<String> errors, String message) {
        if (errors != null && !errors.contains(message)) {
            errors.add(message);
        }
    }

    /**
     * Lookup.Lookup.Field: the first lookup must be allowed and point to one object, and the rest a parent
     * path that object's own catalog entry allows. Filterable, sortable and groupable only when the first
     * lookup is too, as for a one-level parent path.
     */
    private static ExploreCatalog.Field twoLookups(ExploreCatalog.Entry e, List<String> parts) {
        String key = UserInfo.getUserId() + ':' + e.name.toLowerCase() + ':' + String.join(parts, '.').toLowerCase();
        if (deepPaths.containsKey(key)) {
            return deepPaths.get(key);
        }
        ExploreCatalog.Field result;
        String lookupName = lookupField(e.name, parts[0]);
        ExploreCatalog.Field lookup = lookupName == null ? null : e.field(lookupName);
        ExploreCatalog.Field via = e.field(parts[0] + '.Id');
        if (lookup != null && via != null && lookup.kind == ExploreCatalog.KIND_ID && lookup.referenceTo.size() == 1) {
            ExploreCatalog.Entry target = ExploreCatalog.describe(lookup.referenceTo[0]);
            ExploreCatalog.Field rest = target == null ? null : target.field(parts[1] + '.' + parts[2]);
            if (rest != null) {
                String parent = lookup.label.endsWith(' ID') && lookup.label.length() > 3 ? lookup.label.left(lookup.label.length() - 3) : lookup.label;
                result = new ExploreCatalog.Field();
                result.path = via.path.substringBefore('.') + '.' + rest.path;
                result.type = rest.type;
                result.label = parent + ' ' + rest.label;
                result.kind = rest.kind;
                result.filterable = rest.filterable && lookup.filterable;
                result.sortable = rest.sortable && lookup.sortable;
                result.groupable = rest.groupable && lookup.groupable;
                result.aggregatable = rest.aggregatable;
                result.referenceTo = rest.referenceTo;
                result.picklistValues = rest.picklistValues;
            }
        }
        deepPaths.put(key, result);
        return result;
    }

    /** The lookup field behind a relationship name on an object (Account -> AccountId), or null. */
    private static String lookupField(String objectName, String relationship) {
        String key = objectName.toLowerCase();
        if (!lookupsByObject.containsKey(key)) {
            Map<String, String> byName = new Map<String, String>();
            for (Schema.SObjectField sf : Schema.describeSObjects(new List<String>{ objectName })[0].fields.getMap().values()) {
                Schema.DescribeFieldResult fd = sf.getDescribe();
                if (fd.getRelationshipName() != null) {
                    byName.put(fd.getRelationshipName().toLowerCase(), fd.getName());
                }
            }
            lookupsByObject.put(key, byName);
        }
        return lookupsByObject.get(key).get(relationship.toLowerCase());
    }

    /** True for a field the platform can't filter, sort or group because it is long text. */
    @TestVisible
    private static Boolean isLongText(ExploreCatalog.Field f) {
        return f != null && !f.filterable && f.type == 'textarea';
    }

    // ---------------------------------------------------------------- aggregates

    private static void resolveAggregate(Resolved r, Aggregate a) {
        String fn = a.fn == null ? '' : a.fn.trim().toUpperCase();
        if (!FUNCTIONS.contains(fn)) {
            r.errors.add('Unknown aggregate function "' + a.fn + '". Use COUNT, SUM, AVG, MIN or MAX.');
            return;
        }
        ExploreCatalog.Field f;
        if (String.isBlank(a.field) && fn == 'COUNT') {
            f = r.entry.field('Id');
        } else if (String.isBlank(a.field)) {
            r.errors.add(fn + ' needs a field.');
            return;
        } else {
            f = knownField(r, r.entry, a.field);
        }
        if (f == null) {
            return;
        }
        Boolean numeric = f.kind == ExploreCatalog.KIND_NUMBER || f.kind == ExploreCatalog.KIND_INTEGER || f.kind == ExploreCatalog.KIND_LONG;
        if ((fn == 'SUM' || fn == 'AVG') && !numeric) {
            r.errors.add(fn + ' needs a number field; ' + f.path + ' is ' + f.type + '.');
            return;
        }
        if (fn != 'COUNT' && !f.aggregatable) {
            r.errors.add(f.path + ' can\'t be used with ' + fn + '.');
            return;
        }
        ResolvedAggregate ra = new ResolvedAggregate();
        ra.fn = fn;
        ra.field = f;
        ra.expr = fn + '(' + f.path + ')';
        r.aggregates.add(ra);
    }

    /** "having": each item names one of the aggregates, a comparison and a value, all bound. */
    private static void resolveHaving(Walk w, ExplorePlan plan, Boolean grouped) {
        if (plan.havingFilters.isEmpty()) {
            return;
        }
        if (plan.havingFilters.size() > MAX_HAVING) {
            w.error('Use at most ' + MAX_HAVING + ' "having" conditions.');
            return;
        }
        String bad = '"having" must use one of the aggregates and a comparison.';
        for (Object item : plan.havingFilters) {
            Map<String, Object> hm = item instanceof Map<String, Object> ? lowerKeys((Map<String, Object>) item) : null;
            if (hm == null || !grouped) {
                w.error(hm == null ? bad : '"having" needs groupBy.');
                continue;
            }
            String fn = upper(text(hm.get('fn')));
            String path = text(hm.get('field'));
            String op = upper(text(hm.get('op')));
            ResolvedAggregate match;
            for (ResolvedAggregate a : w.r.aggregates) {
                if (a.fn == fn && (String.isBlank(path) ? a.field.path == 'Id' : a.field.path.equalsIgnoreCase(path))) {
                    match = a;
                }
            }
            if (match == null || !COMPARISONS.contains(op)) {
                w.error(bad);
                continue;
            }
            try {
                ResolvedHaving h = new ResolvedHaving();
                h.aggregate = match;
                h.op = op;
                h.bindValue = fn == 'COUNT' ? (Object) wholeNumber(hm.get('value')) : scalar(match.field, hm.get('value'));
                w.r.havingFilters.add(h);
            } catch (PlanException e) {
                w.error(e.getMessage());
            }
        }
    }

    private static Integer wholeNumber(Object value) {
        try {
            Decimal d = Decimal.valueOf(String.valueOf(value).trim());
            if (d == d.round(System.RoundingMode.DOWN)) {
                return d.intValue();
            }
        } catch (Exception e) {
            // fall through to the plain-English error
        }
        throw new PlanException('"having" on COUNT takes a whole number.');
    }

    // ---------------------------------------------------------------- where

    /** "filters" (joined by AND), the groups listed there and "where", ANDed into one tree. */
    private static void resolveWhere(Walk w, ExplorePlan plan) {
        Node root = new Node();
        root.kind = NODE_AND;
        for (Filter f : plan.filters) {
            addChild(root, condition(w, w.r.entry, f, null, true, false));
        }
        for (Object g : plan.filterGroups) {
            addChild(root, node(w, w.r.entry, g, 0, true, false));
        }
        if (plan.whereNode != null) {
            addChild(root, node(w, w.r.entry, plan.whereNode, 0, true, false));
        }
        w.r.whereTree = root.children.isEmpty() ? null : root.children.size() == 1 ? root.children[0] : root;
    }

    /** Adds a part to a group; an AND inside an AND joins its parent's list. */
    private static void addChild(Node parent, Node child) {
        if (child == null) {
            return;
        }
        if (child.kind == NODE_AND && parent.kind == NODE_AND) {
            parent.children.addAll(child.children);
        } else {
            parent.children.add(child);
        }
    }

    /**
     * One "where" part. groups is how many groups enclose it; top is true while only ANDs lead to it from
     * the root; inner is true inside a "sub" or a child list. Null when it adds nothing or has errors.
     */
    private static Node node(Walk w, ExploreCatalog.Entry e, Object raw, Integer groups, Boolean top, Boolean nested) {
        if (!(raw instanceof Map<String, Object>)) {
            w.error(DEPTH_ERROR);
            return null;
        }
        Map<String, Object> original = (Map<String, Object>) raw;
        Map<String, Object> m = lowerKeys(original);
        if (!isGroup(m)) {
            if (!m.containsKey('field') && !m.containsKey('sub')) {
                w.error(DEPTH_ERROR);
                return null;
            }
            Filter f = new Filter();
            f.field = text(m.get('field'));
            f.op = text(m.get('op'));
            f.value = m.get('value');
            f.sub = m.get('sub');
            return condition(w, e, f, original, top, nested);
        }
        if (groups >= MAX_GROUP_DEPTH) {
            w.error(DEPTH_ERROR);
            return null;
        }
        String kind = m.containsKey(NODE_AND) ? NODE_AND : m.containsKey(NODE_OR) ? NODE_OR : NODE_NOT;
        Object body = m.get(kind);
        List<Object> items = body instanceof List<Object> ? (List<Object>) body : new List<Object>{ body };
        Node n = new Node();
        n.kind = kind;
        for (Object item : items) {
            addChild(n, node(w, e, item, groups + 1, top && kind == NODE_AND, nested));
        }
        if (n.children.isEmpty()) {
            return null;
        }
        return kind != NODE_NOT && n.children.size() == 1 ? n.children[0] : n;
    }

    /** One condition: a semi-join, a long-text match, or a filter with a typed bind value. */
    private static Node condition(Walk w, ExploreCatalog.Entry e, Filter f, Map<String, Object> original, Boolean top, Boolean nested) {
        w.conditions++;
        if (w.conditions > MAX_CONDITIONS) {
            w.error('Use at most ' + MAX_CONDITIONS + ' conditions.');
            return null;
        }
        if (f.sub != null) {
            return subNode(w, e, f, top, nested);
        }
        ExploreCatalog.Field field = knownField(w.r, e, f.field);
        if (field == null) {
            return null;
        }
        String op = upper(f.op);
        if (!OPS.contains(op)) {
            w.error('Unknown op "' + f.op + '" on ' + field.path + '. Use one of: ' + String.join(OPS, ' ') + '.');
            return null;
        }
        Boolean longText = isLongText(field);
        if (op == 'CONTAINS' && longText) {
            textMatch(w, field, f.value, top, nested);
            return null;
        }
        if (!field.filterable) {
            w.error(longText
                ? field.path + ' is long text: use CONTAINS at the top level of "where", or filter on another field.'
                : field.path + ' can\'t be used in a filter.');
            return null;
        }
        try {
            ResolvedFilter rf = op == 'CONTAINS' ? containsFilter(field, f.value) : filter(w, field, op, f, original);
            if (!nested) {
                w.r.filters.add(rf);
            }
            Node n = new Node();
            n.kind = NODE_FILTER;
            n.filter = rf;
            return n;
        } catch (PlanException ex) {
            w.error(ex.getMessage());
            return null;
        }
    }

    /** CONTAINS on long text: the platform can't filter it, so ExploreQuery matches it after the query. */
    private static void textMatch(Walk w, ExploreCatalog.Field field, Object value, Boolean top, Boolean nested) {
        if (nested || !top) {
            w.error('CONTAINS on long text ' + field.path + ' must be at the top level of "where".');
        } else if (w.aggregated) {
            w.error('CONTAINS on long text ' + field.path + ' can\'t be used with groupBy or aggregates.');
        } else if (!(value instanceof String) || String.isBlank((String) value)) {
            w.error('CONTAINS on ' + field.path + ' needs text to look for.');
        } else {
            TextMatch t = new TextMatch();
            t.field = field;
            t.text = (String) value;
            w.r.textMatches.add(t);
        }
    }

    /** CONTAINS on a filterable text field: LIKE with the value's own % and _ escaped. */
    private static ResolvedFilter containsFilter(ExploreCatalog.Field field, Object value) {
        if (field.kind != ExploreCatalog.KIND_TEXT) {
            throw new PlanException('CONTAINS needs a text field; ' + field.path + ' is ' + field.type + '.');
        }
        if (!(value instanceof String) || String.isBlank((String) value)) {
            throw new PlanException('CONTAINS on ' + field.path + ' needs text to look for.');
        }
        String s = (String) value;
        ResolvedFilter rf = new ResolvedFilter();
        rf.field = field;
        rf.op = 'LIKE';
        rf.bindValue = '%' + s.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%';
        rf.display = field.path + ' CONTAINS ' + s;
        return rf;
    }

    private static ResolvedFilter filter(Walk w, ExploreCatalog.Field f, String op, Filter filter, Map<String, Object> original) {
        ResolvedFilter rf = new ResolvedFilter();
        rf.field = f;
        rf.op = op;
        Object value = filter.value;
        if (value instanceof Map<String, Object> && lowerKeys((Map<String, Object>) value).containsKey('step')) {
            List<Id> ids = stepIds(w, f, op, lowerKeys((Map<String, Object>) value));
            rf.bindValue = ids;
            rf.display = f.path + ' ' + op + ' ' + display(ids);
            if (!ids.isEmpty()) {
                writeBack(filter, original, ids);
            }
            return rf;
        }
        rf.literal = dateLiteral(f, op, value);
        if (rf.literal == null) {
            rf.bindValue = bindValue(f, op, value);
            if (f.kind == ExploreCatalog.KIND_DATETIME) {
                widenDateOnly(rf, value);
            }
        }
        rf.display = f.path + ' ' + op + ' ' + (rf.literal != null ? rf.literal : display(value));
        return rf;
    }

    /**
     * The record ids an earlier result holds in one column, for IN or NOT IN. Refused when that result
     * showed only some of its rows and was not sorted, since its ids would then be an arbitrary part.
     */
    private static List<Id> stepIds(Walk w, ExploreCatalog.Field f, String op, Map<String, Object> ref) {
        Integer n = toInt(ref.get('step'));
        Integer have = w.steps.size();
        if ((op != 'IN' && op != 'NOT IN') || n == null || n < 1 || n > have) {
            throw new PlanException(have == 0
                ? 'A step value needs IN or NOT IN and an earlier query; this is the first query.'
                : 'A step value needs IN or NOT IN and an earlier query (1 to ' + have + ').');
        }
        if (f.kind != ExploreCatalog.KIND_ID) {
            throw new PlanException('A step value needs a record id field; ' + f.path + ' is ' + f.type + '.');
        }
        ExploreQuery.ResultSet rs = w.steps[n - 1];
        String want = String.isBlank(text(ref.get('field'))) ? 'Id' : text(ref.get('field'));
        String column;
        Boolean hasId = rs.rows.isEmpty() || rs.rows[0].containsKey('Id');
        if (want.equalsIgnoreCase('Id') && hasId) {
            column = 'Id';
        }
        for (String c : rs.columns) {
            if (column == null && c.equalsIgnoreCase(want)) {
                column = c;
            }
        }
        if (column == null) {
            throw new PlanException('Step ' + n + ' has no column "' + want + '". Use one of: '
                + (hasId ? 'Id, ' : '') + String.join(rs.columns, ', ') + '.');
        }
        if (rs.total > rs.shown && (rs.plan == null || rs.plan.orderBy == null)) {
            throw new PlanException('Step ' + n + ' showed ' + rs.shown + ' of ' + rs.total
                + ' rows, so its ids are only some of them. Use "sub" or narrow that query.');
        }
        List<Id> ids = new List<Id>();
        Set<Id> seen = new Set<Id>();
        for (Map<String, Object> row : rs.rows) {
            Object v = row.get(column);
            if (v == null) {
                continue;
            }
            Id value;
            try {
                value = Id.valueOf(String.valueOf(v));
            } catch (Exception e) {
                throw new PlanException('Step ' + n + ' column ' + column + ' does not hold record ids.');
            }
            if (seen.add(value)) {
                ids.add(value);
            }
        }
        if (ids.size() > MAX_IN_VALUES) {
            throw new PlanException(op + ' on ' + f.path + ' takes at most ' + MAX_IN_VALUES + ' values.');
        }
        return ids;
    }

    /** Writes a step value's ids into the plan, so its JSON (planJson) replays without the steps. */
    private static void writeBack(Filter filter, Map<String, Object> original, List<Id> ids) {
        List<Object> values = new List<Object>();
        for (Id i : ids) {
            values.add(String.valueOf(i));
        }
        if (original == null) {
            filter.value = values;
            return;
        }
        String key = 'value';
        for (String k : original.keySet()) {
            if (k.equalsIgnoreCase('value')) {
                key = k;
            }
        }
        original.put(key, values);
    }

    /** A semi- or anti-join. The platform rules: see the class comment. */
    private static Node subNode(Walk w, ExploreCatalog.Entry e, Filter f, Boolean top, Boolean nested) {
        Map<String, Object> sm = f.sub instanceof Map<String, Object> ? lowerKeys((Map<String, Object>) f.sub) : null;
        if (sm == null) {
            w.error('"sub" must be an object with object, field and where.');
            return null;
        }
        String objectName = text(sm.get('object'));
        ExploreCatalog.Entry se = String.isBlank(objectName) ? null : ExploreCatalog.describe(objectName);
        if (se == null) {
            w.error('Unknown object "' + objectName + '" in "sub".');
            return null;
        }
        if (nested) {
            w.error('"sub" can\'t be nested inside another "sub" or a child list.');
            return null;
        }
        if (!top) {
            w.error('"sub" must be at the top level of "where", not inside "or" or "not".');
            return null;
        }
        w.subs++;
        if (w.subs > MAX_SUBS) {
            w.error('Use "sub" at most twice.');
            return null;
        }
        if (NO_SUB_OBJECTS.contains(se.name.toLowerCase()) || se.name == e.name) {
            w.error(se.name + ' can\'t be in "sub"; query it first and use a step value.');
            return null;
        }
        ExploreCatalog.Field left = String.isBlank(f.field) ? null : fieldAt(e, f.field);
        if (left == null || left.kind != ExploreCatalog.KIND_ID || !left.filterable || left.path.contains('.')) {
            w.error('"sub" needs Id or a lookup on ' + e.name + '.');
            return null;
        }
        String rightName = text(sm.get('field'));
        ExploreCatalog.Field right = String.isBlank(rightName) || rightName.contains('.') ? null : se.field(rightName);
        if (right == null || right.kind != ExploreCatalog.KIND_ID || right.path == 'Id') {
            w.error((String.isBlank(rightName) ? '(no field)' : rightName) + ' is not a lookup on ' + se.name + '.');
            return null;
        }
        Set<String> targets = left.path == 'Id' ? new Set<String>{ e.name } : new Set<String>(left.referenceTo);
        Boolean meets = false;
        for (String t : right.referenceTo) {
            meets = meets || targets.contains(t);
        }
        if (!meets) {
            w.error(se.name + '.' + right.path + ' does not point to the records ' + e.name + '.' + left.path + ' holds.');
            return null;
        }
        String op = upper(f.op);
        if (op != 'IN' && op != 'NOT IN') {
            w.error('"sub" takes IN or NOT IN.');
            return null;
        }
        ResolvedSub rs = new ResolvedSub();
        rs.left = left;
        rs.op = op;
        rs.entry = se;
        rs.right = right;
        rs.whereTree = sm.get('where') == null ? null : node(w, se, sm.get('where'), 0, false, true);
        Node n = new Node();
        n.kind = NODE_SUB;
        n.sub = rs;
        return n;
    }

    // ---------------------------------------------------------------- children

    /** Child lists: a relationship of the plan's object whose child object and lookup the catalog allows. */
    private static void resolveChildren(Walk w, ExplorePlan plan) {
        if (plan.children.isEmpty()) {
            return;
        }
        if (w.aggregated) {
            w.error('Child lists work only without groupBy and aggregates.');
            return;
        }
        if (plan.children.size() > MAX_CHILD_LISTS) {
            w.error('Use at most ' + MAX_CHILD_LISTS + ' child lists.');
            return;
        }
        Map<String, Schema.ChildRelationship> rels = childRelationships(w.r.entry.name);
        for (Object item : plan.children) {
            Map<String, Object> cm = item instanceof Map<String, Object> ? lowerKeys((Map<String, Object>) item) : null;
            if (cm == null) {
                w.error('Each child list must be an object with rel, fields, where and limit.');
                continue;
            }
            String rel = text(cm.get('rel'));
            Schema.ChildRelationship cr = rel == null ? null : rels.get(rel.toLowerCase());
            ExploreCatalog.Entry ce = cr == null ? null : ExploreCatalog.describe(String.valueOf(cr.getChildSObject()));
            if (ce == null || ce.field(cr.getField().getDescribe().getName()) == null) {
                w.error('Unknown child list "' + rel + '" on ' + w.r.entry.name + '. Use one of: ' + childNames(rels) + '.');
                continue;
            }
            ResolvedChild c = new ResolvedChild();
            c.rel = cr.getRelationshipName();
            c.entry = ce;
            for (String path : strings(cm.get('fields'), 'fields', w.r.errors)) {
                ExploreCatalog.Field f = knownField(w.r, ce, path);
                if (f != null) {
                    c.fields.add(f);
                }
            }
            c.whereTree = cm.get('where') == null ? null : node(w, ce, cm.get('where'), 0, false, true);
            Integer lim = toInt(cm.get('limit'));
            c.rowLimit = lim == null || lim < 1 ? CHILD_LIMIT : Math.min(lim, MAX_CHILD_LIMIT);
            w.r.children.add(c);
        }
    }

    private static Map<String, Schema.ChildRelationship> childRelationships(String objectName) {
        String key = objectName.toLowerCase();
        if (!childrenByObject.containsKey(key)) {
            Map<String, Schema.ChildRelationship> byName = new Map<String, Schema.ChildRelationship>();
            for (Schema.ChildRelationship cr : Schema.describeSObjects(new List<String>{ objectName })[0].getChildRelationships()) {
                if (cr.getRelationshipName() != null) {
                    byName.put(cr.getRelationshipName().toLowerCase(), cr);
                }
            }
            childrenByObject.put(key, byName);
        }
        return childrenByObject.get(key);
    }

    /** Up to 12 child lists to catalog objects already described, by name. */
    private static String childNames(Map<String, Schema.ChildRelationship> rels) {
        List<String> names = new List<String>();
        for (Schema.ChildRelationship cr : rels.values()) {
            if (ExploreCatalog.find(String.valueOf(cr.getChildSObject())) != null) {
                names.add(cr.getRelationshipName());
            }
        }
        names.sort();
        while (names.size() > 12) {
            names.remove(names.size() - 1);
        }
        return names.isEmpty() ? '(none)' : String.join(names, ', ');
    }

    private static Boolean isDateOnly(Object value) {
        return value instanceof String && DATE_SHAPE.matcher(((String) value).trim()).matches();
    }

    /**
     * A date-only value on a Datetime field means the whole local day. = and != become a range, > and <=
     * move to the start of the next day, and each date-only IN item gets its own end.
     */
    private static void widenDateOnly(ResolvedFilter rf, Object value) {
        String op = rf.op;
        if (op == 'IN' || op == 'NOT IN') {
            List<Datetime> ends = new List<Datetime>();
            Boolean hasDay = false;
            for (Object item : (List<Object>) value) {
                if (isDateOnly(item)) {
                    ends.add(startOfDay(Date.valueOf(((String) item).trim()).addDays(1)));
                    hasDay = true;
                } else {
                    ends.add(null);
                }
            }
            rf.bindValueEnds = hasDay ? ends : null;
            return;
        }
        if (!isDateOnly(value)) {
            return;
        }
        Datetime nextDay = startOfDay(Date.valueOf(((String) value).trim()).addDays(1));
        if (op == '=' || op == '!=') {
            rf.bindValueEnd = nextDay;
        } else if (op == '>') {
            rf.bindOp = '>=';
            rf.bindValue = nextDay;
        } else if (op == '<=') {
            rf.bindOp = '<';
            rf.bindValue = nextDay;
        }
    }

    private static void resolveOrderBy(Resolved r, ExplorePlan plan, Boolean grouped, Boolean aggregated) {
        if (plan.orderBy == null || String.isBlank(plan.orderBy.field)) {
            return;
        }
        String dir = plan.orderBy.dir == null ? 'ASC' : plan.orderBy.dir.trim().toUpperCase();
        if (dir != 'ASC' && dir != 'DESC') {
            r.errors.add('orderBy dir must be ASC or DESC.');
            return;
        }
        if (aggregated && !grouped) {
            return; // one row: nothing to order
        }
        String wanted = plan.orderBy.field.trim();
        if (!grouped) {
            ExploreCatalog.Field f = knownField(r, r.entry, wanted);
            if (f != null && !f.sortable) {
                r.errors.add(f.path + ' can\'t be sorted.');
            } else if (f != null) {
                r.orderExpr = f.path;
                r.orderDir = dir;
            }
            return;
        }
        for (ExploreCatalog.Field g : r.groupBy) {
            if (g.path.equalsIgnoreCase(wanted)) {
                r.orderExpr = g.path;
                r.orderDir = dir;
                return;
            }
        }
        Matcher m = AGGREGATE_SHAPE.matcher(wanted);
        if (m.matches()) {
            String fn = m.group(1).toUpperCase();
            String path = m.group(2);
            for (ResolvedAggregate a : r.aggregates) {
                Boolean sameField = String.isBlank(path) ? a.field.path == 'Id' : a.field.path.equalsIgnoreCase(path);
                if (a.fn == fn && sameField) {
                    r.orderExpr = a.expr;
                    r.orderDir = dir;
                    return;
                }
            }
        }
        r.errors.add('With groupBy, orderBy must be a groupBy field or one of the aggregates, written like SUM(Amount).');
    }

    // ---------------------------------------------------------------- values

    /**
     * The canonical date literal for a Date or Datetime filter whose value is written like one, or null
     * when the value is not a literal (it is then bound). The token is rebuilt from DATE_LITERALS and a
     * parsed integer, never copied from the model. Throws PlanException for an unknown literal.
     */
    @TestVisible
    private static String dateLiteral(ExploreCatalog.Field f, String op, Object value) {
        if (f.kind != ExploreCatalog.KIND_DATE && f.kind != ExploreCatalog.KIND_DATETIME) {
            return null;
        }
        if (!(value instanceof String)) {
            return null;
        }
        String s = ((String) value).trim().toUpperCase();
        if (!LITERAL_SHAPE.matcher(s).matches()) {
            return null;
        }
        if (op == 'IN' || op == 'NOT IN' || op == 'LIKE') {
            throw new PlanException(op + ' can\'t be used with a date literal on ' + f.path + '.');
        }
        Integer colon = s.indexOf(':');
        if (colon < 0) {
            Integer i = DATE_LITERALS.indexOf(s);
            if (i < 0) {
                throw badLiteral(value);
            }
            return DATE_LITERALS[i];
        }
        Integer i = DATE_LITERALS_N.indexOf(s.substring(0, colon));
        Integer n;
        try {
            n = Integer.valueOf(s.substring(colon + 1).trim());
        } catch (Exception e) {
            n = 0;
        }
        if (i < 0 || n < 1 || n > MAX_LITERAL_N) {
            throw badLiteral(value);
        }
        return DATE_LITERALS_N[i] + ':' + String.valueOf(n);
    }

    private static PlanException badLiteral(Object value) {
        return new PlanException('Unknown date literal "' + value + '". Use one of: ' + String.join(DATE_LITERALS, ', ')
            + ', or ' + String.join(DATE_LITERALS_N, ':n, ') + ':n with n from 1 to ' + MAX_LITERAL_N + '.');
    }

    /** The typed value to bind for a filter. Throws PlanException with a plain-English reason. */
    @TestVisible
    private static Object bindValue(ExploreCatalog.Field f, String op, Object value) {
        if (op == 'IN' || op == 'NOT IN') {
            if (!(value instanceof List<Object>) || ((List<Object>) value).isEmpty()) {
                throw new PlanException(op + ' on ' + f.path + ' needs a list of 1 to ' + MAX_IN_VALUES + ' values.');
            }
            List<Object> items = (List<Object>) value;
            if (items.size() > MAX_IN_VALUES) {
                throw new PlanException(op + ' on ' + f.path + ' takes at most ' + MAX_IN_VALUES + ' values.');
            }
            List<Object> typed = typedList(f.kind);
            for (Object item : items) {
                if (item == null) {
                    throw new PlanException(op + ' on ' + f.path + ' can\'t contain null.');
                }
                typed.add(scalar(f, item));
            }
            return typed;
        }
        if (value instanceof List<Object> || value instanceof Map<String, Object>) {
            throw new PlanException('The value for ' + f.path + ' must be a single value' + (op == '=' ? '; use IN for a list.' : '.'));
        }
        if (value == null) {
            if (op != '=' && op != '!=') {
                throw new PlanException('Only = and != can compare ' + f.path + ' to null.');
            }
            return null;
        }
        if (op == 'LIKE') {
            if (f.kind != ExploreCatalog.KIND_TEXT) {
                throw new PlanException('LIKE needs a text field; ' + f.path + ' is ' + f.type + '.');
            }
            return String.valueOf(value);
        }
        if ((f.kind == ExploreCatalog.KIND_BOOLEAN || f.kind == ExploreCatalog.KIND_ID) && op != '=' && op != '!=') {
            throw new PlanException(f.path + ' takes only =, != or IN.');
        }
        return scalar(f, value);
    }

    private static List<Object> typedList(String kind) {
        if (kind == ExploreCatalog.KIND_ID) {
            return new List<Id>();
        }
        if (kind == ExploreCatalog.KIND_BOOLEAN) {
            return new List<Boolean>();
        }
        if (kind == ExploreCatalog.KIND_INTEGER) {
            return new List<Integer>();
        }
        if (kind == ExploreCatalog.KIND_LONG) {
            return new List<Long>();
        }
        if (kind == ExploreCatalog.KIND_NUMBER) {
            return new List<Decimal>();
        }
        if (kind == ExploreCatalog.KIND_DATE) {
            return new List<Date>();
        }
        if (kind == ExploreCatalog.KIND_DATETIME) {
            return new List<Datetime>();
        }
        return new List<String>();
    }

    private static Object scalar(ExploreCatalog.Field f, Object value) {
        if (value instanceof List<Object> || value instanceof Map<String, Object>) {
            throw new PlanException('Each value for ' + f.path + ' must be a single value.');
        }
        String s = String.valueOf(value).trim();
        String kind = f.kind;
        if (kind == ExploreCatalog.KIND_TEXT) {
            return String.valueOf(value);
        }
        if (kind == ExploreCatalog.KIND_ID) {
            try {
                return Id.valueOf(s);
            } catch (Exception e) {
                throw new PlanException('"' + s + '" is not a record id, so it can\'t be compared to ' + f.path + '.');
            }
        }
        if (kind == ExploreCatalog.KIND_BOOLEAN) {
            if (s.equalsIgnoreCase('true') || s.equalsIgnoreCase('false')) {
                return Boolean.valueOf(s);
            }
            throw new PlanException(f.path + ' takes true or false.');
        }
        if (kind == ExploreCatalog.KIND_DATE || kind == ExploreCatalog.KIND_DATETIME) {
            return dateValue(f, s);
        }
        Decimal d;
        try {
            d = Decimal.valueOf(s);
        } catch (Exception e) {
            throw new PlanException(f.path + ' takes a number; "' + s + '" is not one.');
        }
        if (kind == ExploreCatalog.KIND_NUMBER) {
            return d;
        }
        if (d != d.round(System.RoundingMode.DOWN)) {
            throw new PlanException(f.path + ' takes a whole number.');
        }
        return kind == ExploreCatalog.KIND_INTEGER ? (Object) d.intValue() : (Object) d.longValue();
    }

    /** Midnight at the start of the date in the running user's time zone. */
    private static Datetime startOfDay(Date d) {
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
    }

    private static Object dateValue(ExploreCatalog.Field f, String s) {
        try {
            if (DATE_SHAPE.matcher(s).matches()) {
                Date d = Date.valueOf(s);
                // A date-only value on a Datetime field means that day where the user is, not in GMT.
                return f.kind == ExploreCatalog.KIND_DATE ? (Object) d : (Object) startOfDay(d);
            }
            if (f.kind == ExploreCatalog.KIND_DATETIME && DATETIME_SHAPE.matcher(s).matches()) {
                return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
            }
        } catch (Exception e) {
            // fall through to the plain-English error
        }
        throw new PlanException(f.path + ' takes a date as YYYY-MM-DD'
            + (f.kind == ExploreCatalog.KIND_DATETIME ? ' or YYYY-MM-DDThh:mm:ssZ' : '') + ', or a date literal such as TODAY or LAST_N_DAYS:30.');
    }

    // ---------------------------------------------------------------- helpers

    private static String display(Object value) {
        if (value == null) {
            return 'null';
        }
        if (value instanceof List<Object>) {
            List<String> parts = new List<String>();
            for (Object o : (List<Object>) value) {
                parts.add(String.valueOf(o));
            }
            return '(' + String.join(parts, ', ') + ')';
        }
        return String.valueOf(value);
    }

    private static Map<String, Object> lowerKeys(Map<String, Object> m) {
        Map<String, Object> out = new Map<String, Object>();
        for (String k : m.keySet()) {
            out.put(k.toLowerCase(), m.get(k));
        }
        return out;
    }

    private static String text(Object value) {
        return value == null ? null : String.valueOf(value).trim();
    }

    private static String upper(String value) {
        return value == null ? '' : value.trim().toUpperCase();
    }

    /** A whole number from JSON, or null when there is none. */
    private static Integer toInt(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(value).trim()).intValue();
        } catch (Exception e) {
            return null;
        }
    }

    private static List<Object> asList(Object value, String key, List<String> errors) {
        if (value == null) {
            return new List<Object>();
        }
        if (value instanceof List<Object>) {
            return (List<Object>) value;
        }
        errors.add('"' + key + '" must be a list.');
        return new List<Object>();
    }

    private static List<String> strings(Object value, String key, List<String> errors) {
        List<String> out = new List<String>();
        if (value instanceof String) {
            value = new List<Object>{ value };
        }
        for (Object item : asList(value, key, errors)) {
            if (item instanceof String && String.isNotBlank((String) item)) {
                out.add(((String) item).trim());
            } else {
                errors.add('"' + key + '" must list field names as text.');
            }
        }
        return out;
    }
}
