/**
 * ExplorePlan: the only query shape the model may emit, parsed from JSON.
 *
 *   { "object": "Opportunity",
 *     "fields": ["Name", "Amount"],
 *     "filters": [ { "field": "StageName", "op": "=", "value": "Closed Won" } ],   // joined by AND
 *     "orderBy": { "field": "Amount", "dir": "DESC" },
 *     "limit": 10,
 *     "groupBy": ["Owner.Name"],
 *     "aggregates": [ { "fn": "SUM", "field": "Amount" } ] }
 *
 * resolve() checks every name against ExploreCatalog for the running user and returns canonical
 * pieces: catalog field paths, a fixed operator, a fixed date literal token or a typed bind value.
 * validate() returns its plain-English errors. ExploreQuery builds SOQL only from a resolved plan,
 * so no text from the model is ever concatenated into a query. No DML, no SOQL.
 */
public with sharing class ExplorePlan {
    public class PlanException extends Exception {}

    /** Operators a filter may use. */
    public static final List<String> OPS = new List<String>{ '=', '!=', '<', '<=', '>', '>=', 'LIKE', 'IN' };
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
    private static final Integer MAX_ERRORS = 10;
    private static final Set<String> KEYS = new Set<String>{ 'object', 'fields', 'filters', 'orderby', 'limit', 'groupby', 'aggregates' };
    private static final Pattern LITERAL_SHAPE = Pattern.compile('^[A-Z][A-Z0-9_]*(:\\s*-?[0-9]+)?$');
    private static final Pattern AGGREGATE_SHAPE = Pattern.compile('^([A-Za-z]+)\\(\\s*([A-Za-z0-9_.]*)\\s*\\)$');
    private static final Pattern DATE_SHAPE = Pattern.compile('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');
    private static final Pattern DATETIME_SHAPE = Pattern.compile('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2}(\\.[0-9]{1,3})?)?(Z|[+-][0-9]{2}:?[0-9]{2})?$');

    public class Filter {
        public String field;
        public String op;
        public Object value;
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
    /** Shape problems found while parsing, reported by validate(). */
    public List<String> parseErrors = new List<String>();

    /** A plan checked against the catalog: only catalog paths, fixed tokens and typed bind values. */
    public class Resolved {
        public List<String> errors = new List<String>();
        public ExploreCatalog.Entry entry;
        public List<ExploreCatalog.Field> fields = new List<ExploreCatalog.Field>();
        public List<ResolvedFilter> filters = new List<ResolvedFilter>();
        public List<ExploreCatalog.Field> groupBy = new List<ExploreCatalog.Field>();
        public List<ResolvedAggregate> aggregates = new List<ResolvedAggregate>();
        /** ORDER BY expression built from catalog paths, or null. */
        public String orderExpr;
        public String orderDir;
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
                p.parseErrors.add('Unknown plan key "' + key + '". Use only: object, fields, filters, orderBy, limit, groupBy, aggregates.');
            }
        }
        p.objectName = text(m.get('object'));
        p.fields = strings(m.get('fields'), 'fields', p.parseErrors);
        p.groupBy = strings(m.get('groupby'), 'groupBy', p.parseErrors);

        for (Object item : asList(m.get('filters'), 'filters', p.parseErrors)) {
            if (item instanceof Map<String, Object>) {
                Map<String, Object> fm = lowerKeys((Map<String, Object>) item);
                Filter f = new Filter();
                f.field = text(fm.get('field'));
                f.op = text(fm.get('op'));
                f.value = fm.get('value');
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
            fs.add(new Map<String, Object>{ 'field' => f.field, 'op' => f.op, 'value' => f.value });
        }
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
        return JSON.serialize(m);
    }

    // ---------------------------------------------------------------- validate

    /** Plain-English problems with the plan; empty when it may run. */
    public static List<String> validate(ExplorePlan plan) {
        return resolve(plan).errors;
    }

    /** Checks the plan against the catalog and returns its canonical form (with errors, if any). */
    public static Resolved resolve(ExplorePlan plan) {
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

        for (String path : plan.fields) {
            ExploreCatalog.Field f = knownField(r, path);
            if (f != null) {
                r.fields.add(f);
            }
        }
        for (String path : plan.groupBy) {
            ExploreCatalog.Field f = knownField(r, path);
            if (f != null && !f.groupable) {
                r.errors.add(f.path + ' can\'t be used in groupBy.');
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

        for (Filter f : plan.filters) {
            resolveFilter(r, f);
        }
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

    private static ExploreCatalog.Field knownField(Resolved r, String path) {
        ExploreCatalog.Field f = r.entry.field(path);
        if (f == null) {
            r.errors.add('Unknown field "' + path + '" on ' + r.entry.name + '.');
        }
        return f;
    }

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
            f = knownField(r, a.field);
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

    private static void resolveFilter(Resolved r, Filter filter) {
        ExploreCatalog.Field f = knownField(r, filter.field);
        if (f == null) {
            return;
        }
        if (!f.filterable) {
            r.errors.add(f.path + ' can\'t be used in a filter (long text). Filter on another field.');
            return;
        }
        String op = filter.op == null ? '' : filter.op.trim().toUpperCase();
        if (!OPS.contains(op)) {
            r.errors.add('Unknown op "' + filter.op + '" on ' + f.path + '. Use one of: ' + String.join(OPS, ' ') + '.');
            return;
        }
        try {
            ResolvedFilter rf = new ResolvedFilter();
            rf.field = f;
            rf.op = op;
            rf.literal = dateLiteral(f, op, filter.value);
            if (rf.literal == null) {
                rf.bindValue = bindValue(f, op, filter.value);
                if (f.kind == ExploreCatalog.KIND_DATETIME) {
                    widenDateOnly(rf, filter.value);
                }
            }
            rf.display = f.path + ' ' + op + ' ' + (rf.literal != null ? rf.literal : display(filter.value));
            r.filters.add(rf);
        } catch (PlanException e) {
            r.errors.add(e.getMessage());
        }
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
        if (op == 'IN') {
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
            ExploreCatalog.Field f = knownField(r, wanted);
            if (f != null && !f.sortable) {
                r.errors.add(f.path + ' can\'t be used in orderBy.');
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
        if (op == 'IN' || op == 'LIKE') {
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
        if (op == 'IN') {
            if (!(value instanceof List<Object>) || ((List<Object>) value).isEmpty()) {
                throw new PlanException('IN on ' + f.path + ' needs a non-empty list of values.');
            }
            List<Object> items = (List<Object>) value;
            if (items.size() > MAX_IN_VALUES) {
                throw new PlanException('IN on ' + f.path + ' takes at most ' + MAX_IN_VALUES + ' values.');
            }
            List<Object> typed = typedList(f.kind);
            for (Object item : items) {
                if (item == null) {
                    throw new PlanException('IN on ' + f.path + ' can\'t contain null.');
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
