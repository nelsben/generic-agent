/**
 * ExploreCatalog: the objects and fields the data explorer may read, built from describe for the running user.
 *
 * Any object the user can read and query may be explored, minus the deny list in Explore_Deny_Rule__mdt:
 * named objects (the product's own, setup and audit), suffix families (__Share, History, Feed, ...),
 * field-name patterns (password, secret, token, ...) and field types (encrypted, base64, address and
 * location compounds). A custom object is denied until an Allow Object row names it; a deny always beats
 * an allow. The deny list fails closed: an empty or unreadable list allows no object at all. The deny
 * list is extra: every query still runs in user mode (ExploreQuery).
 *
 * The core objects (CORE) are described up front; their listed fields are the curated paths below. Any
 * other allowed object is described on demand, the first time a plan names it (describe()), and lists
 * its name field, picklists, dates, amounts, flags and lookups. Entry.field() also resolves any other
 * allowed field, or a one-level parent path, so a plan may name a field the prompt did not show.
 *
 * describeForPrompt(question) is the per-call catalog: the described objects with pruned fields (the name,
 * the fields the question mentions, picklists, dates, amounts, flags and lookups), then other allowed
 * objects as name and label only. It never exceeds MAX_PROMPT_CHARS.
 *
 * Names are kept as strings, never Schema tokens, so a field missing from an org is dropped, not a
 * compile error. Built once per user per transaction. No DML. The deny rules are read with getAll().
 */
public with sharing class ExploreCatalog {
    /** The core objects: object -> listed field paths, in display order. Always described. */
    @TestVisible private static final Map<String, List<String>> CURATED = new Map<String, List<String>>{
        'Account' => new List<String>{
            'Id', 'Name', 'Type', 'Industry', 'Rating', 'AnnualRevenue', 'NumberOfEmployees',
            'BillingCity', 'BillingState', 'BillingCountry', 'OwnerId', 'Owner.Name',
            'CreatedDate', 'LastActivityDate', 'Description'
        },
        'Contact' => new List<String>{
            'Id', 'Name', 'FirstName', 'LastName', 'Title', 'Department', 'Email', 'Phone', 'LeadSource',
            'AccountId', 'Account.Name', 'OwnerId', 'Owner.Name', 'CreatedDate', 'LastActivityDate'
        },
        'Opportunity' => new List<String>{
            'Id', 'Name', 'StageName', 'Amount', 'CloseDate', 'Probability', 'Type', 'LeadSource',
            'ForecastCategoryName', 'IsClosed', 'IsWon', 'NextStep', 'AccountId', 'Account.Name',
            'OwnerId', 'Owner.Name', 'CreatedDate', 'LastActivityDate', 'Description'
        },
        'OpportunityContactRole' => new List<String>{
            'Id', 'Role', 'IsPrimary', 'OpportunityId', 'Opportunity.Name', 'ContactId', 'Contact.Name', 'CreatedDate'
        },
        'Case' => new List<String>{
            'Id', 'CaseNumber', 'Subject', 'Status', 'Priority', 'Origin', 'Type', 'Reason', 'IsClosed',
            'AccountId', 'Account.Name', 'ContactId', 'Contact.Name', 'OwnerId', 'Owner.Name',
            'CreatedDate', 'ClosedDate', 'Description'
        },
        'Task' => new List<String>{
            'Id', 'Subject', 'Status', 'Priority', 'Type', 'TaskSubtype', 'ActivityDate', 'IsClosed',
            'AccountId', 'Account.Name', 'WhoId', 'Who.Name', 'WhatId', 'What.Name', 'OwnerId', 'Owner.Name',
            'CreatedDate', 'Description'
        },
        'Event' => new List<String>{
            'Id', 'Subject', 'Type', 'Location', 'StartDateTime', 'EndDateTime', 'ActivityDate',
            'AccountId', 'Account.Name', 'WhoId', 'Who.Name', 'WhatId', 'What.Name', 'OwnerId', 'Owner.Name',
            'CreatedDate', 'Description'
        },
        'User' => new List<String>{ 'Id', 'Name', 'Title' }
    };

    /** The per-call catalog never exceeds this many characters. */
    public static final Integer MAX_PROMPT_CHARS = 6000;
    /** Picklist values kept per field. */
    private static final Integer PICKLIST_VALUES_KEPT = 12;
    /** Other objects shown as name and label in the prompt, at most. */
    private static final Integer INDEX_NAMES = 16;
    /** Fields an on-demand object lists, at most (the name and Id always among them). */
    private static final Integer LISTED_FIELDS = 30;
    /** Other objects worth naming even when the question does not mention them, if the user may read them. */
    private static final List<String> COMMON = new List<String>{
        'Lead', 'Campaign', 'CampaignMember', 'Contract', 'Order', 'Asset', 'Product2', 'Pricebook2',
        'OpportunityLineItem', 'Quote', 'UserRole'
    };
    /** System fields no question needs, left out of listed fields and the prompt (still resolvable). */
    private static final Set<String> NOISE = new Set<String>{
        'isdeleted', 'systemmodstamp', 'lastvieweddate', 'lastreferenceddate', 'photourl', 'jigsaw',
        'jigsawcompanyid', 'cleanstatus', 'masterrecordid', 'connectionreceivedid', 'connectionsentid',
        'recordvisibilityid', 'lastmodifiedbyid', 'lastmodifieddate', 'createdbyid', 'geocodeaccuracy',
        'isarchived', 'recurrenceactivityid', 'isrecurrence', 'isreminderset', 'reminderdatetime',
        'isvisibleinselfservice', 'isprivate', 'hasoptedoutoffax', 'lastcurequestdate', 'lastcuupdatedate',
        'emailbounceddate', 'emailbouncedreason', 'isemailbounced', 'dandbcompanyid', 'operatinghoursid'
    };
    /** Question words that never name a field or an object. */
    private static final Set<String> STOP = new Set<String>{
        'what', 'which', 'when', 'where', 'show', 'list', 'many', 'much', 'have', 'with', 'that', 'this',
        'from', 'there', 'their', 'than', 'they', 'were', 'does', 'over', 'last', 'most', 'each', 'every',
        'into', 'about', 'more', 'less', 'some', 'only', 'give', 'tell', 'count', 'total', 'them', 'between',
        'next', 'year', 'month', 'week', 'days', 'quarter', 'today', 'open', 'records', 'record', 'name', 'names'
    };

    public static final String RULE_OBJECT = 'Object';
    public static final String RULE_SUFFIX = 'Suffix';
    public static final String RULE_FIELD_PATTERN = 'FieldPattern';
    public static final String RULE_FIELD_TYPE = 'FieldType';
    public static final String RULE_ONLY_FIELDS = 'OnlyFields';
    public static final String RULE_ALLOW_OBJECT = 'AllowObject';

    /** Tests: the deny rows to use instead of the org's records. */
    @TestVisible private static List<Explore_Deny_Rule__mdt> rulesForTest;
    /** Tests: reading the deny list throws, as an unreadable list would. */
    @TestVisible private static Boolean failReadForTest = false;

    /** One object the user may read, with its listed fields. field() also resolves the object's other allowed fields. */
    public class Entry {
        public String name;
        public String label;
        public List<Field> fields = new List<Field>();
        public Map<String, Field> byPath = new Map<String, Field>();
        /** lower-case field name -> describe, for every field of the object. */
        private Map<String, Schema.DescribeFieldResult> described = new Map<String, Schema.DescribeFieldResult>();
        /** lower-case relationship name -> the lookup's describe. */
        private Map<String, Schema.DescribeFieldResult> byRelationship = new Map<String, Schema.DescribeFieldResult>();
        /** Paths resolved outside the listed fields, null when refused. */
        private Map<String, Field> resolved = new Map<String, Field>();

        /** The field for a path, matched case-insensitively, or null when it is not there or not allowed. */
        public Field field(String path) {
            if (String.isBlank(path)) {
                return null;
            }
            String key = path.trim().toLowerCase();
            if (byPath.containsKey(key)) {
                return byPath.get(key);
            }
            if (!resolved.containsKey(key)) {
                resolved.put(key, key.contains('.') ? parentField(this, key) : ownField(this, key));
            }
            return resolved.get(key);
        }

        public void add(Field f) {
            fields.add(f);
            byPath.put(f.path.toLowerCase(), f);
        }
    }

    /** One readable field path. kind is the value type the explorer binds: see KIND_* below. */
    public class Field {
        public String path;
        public String type;
        /** Plain column label for tables and the model: no dots, e.g. Account, Owner, Account Industry. */
        public String label;
        public String kind;
        public Boolean filterable = false;
        public Boolean sortable = false;
        public Boolean groupable = false;
        public Boolean aggregatable = false;
        /** Reference fields: the object types this lookup points to. */
        public List<String> referenceTo = new List<String>();
        public List<String> picklistValues = new List<String>();
        /** The object's name field (Name, CaseNumber, Subject). */
        public Boolean isName = false;
    }

    public static final String KIND_TEXT = 'text';
    public static final String KIND_ID = 'id';
    public static final String KIND_BOOLEAN = 'boolean';
    public static final String KIND_INTEGER = 'integer';
    public static final String KIND_LONG = 'long';
    public static final String KIND_NUMBER = 'number';
    public static final String KIND_DATE = 'date';
    public static final String KIND_DATETIME = 'datetime';

    /** The deny list, parsed once per transaction. */
    private class Rules {
        Boolean usable = false;
        Set<String> objects = new Set<String>();
        List<String> suffixes = new List<String>();
        Set<String> allowed = new Set<String>();
        /** lower-case object ('' for every object) -> patterns / types. */
        Map<String, List<Pattern>> patterns = new Map<String, List<Pattern>>();
        Map<String, Set<String>> types = new Map<String, Set<String>>();
        Map<String, Set<String>> onlyFields = new Map<String, Set<String>>();
    }

    private static Rules loadedRules;
    private static Map<String, Schema.SObjectType> globalTypes;
    /** Per transaction, per running user: lower-case object name -> Entry (core first, then on demand). */
    private static Map<Id, Map<String, Entry>> cache = new Map<Id, Map<String, Entry>>();
    /** Per transaction: allowed objects outside the catalog, as [name, label], shortest name first. */
    private static List<List<String>> otherObjects;

    /** The described entries the running user may read: the core objects, then any described on demand. */
    public static List<Entry> entries() {
        return build().values();
    }

    /** The described entry for an object name, matched case-insensitively, or null if not described for this user. */
    public static Entry find(String objectName) {
        return String.isBlank(objectName) ? null : build().get(objectName.trim().toLowerCase());
    }

    /**
     * The entry for an object, describing it now if it is allowed and not yet described (on-demand describe).
     * Null when the object is denied, missing, or not readable and queryable for the running user.
     */
    public static Entry describe(String objectName) {
        Entry e = find(objectName);
        if (e != null || String.isBlank(objectName)) {
            return e;
        }
        Schema.DescribeSObjectResult d = allowedObject(objectName.trim());
        e = d == null ? null : describeObject(d, null);
        if (e != null) {
            build().put(e.name.toLowerCase(), e);
        }
        return e;
    }

    /** True when the object passes the deny list and the running user may read and query it. */
    public static Boolean isAllowed(String objectName) {
        return String.isNotBlank(objectName) && allowedObject(objectName.trim()) != null;
    }

    /** The catalog for the prompt with no question: describeForPrompt(null). */
    public static String describeForPrompt() {
        return describeForPrompt(null);
    }

    /**
     * The per-call catalog as compact text: one line per described object (each field as path(type), with
     * picklist values and a 'no filter' mark where they apply), then other allowed objects as name: label.
     * At most MAX_PROMPT_CHARS characters: picklist values, then the index, then fields shrink to fit.
     */
    public static String describeForPrompt(String question) {
        Set<String> words = questionWords(question);
        List<Integer[]> levels = new List<Integer[]>{
            new Integer[]{ 6, INDEX_NAMES, 1 }, new Integer[]{ 3, INDEX_NAMES, 1 },
            new Integer[]{ 0, 8, 1 }, new Integer[]{ 0, 4, 0 }
        };
        String text = '';
        for (Integer[] level : levels) {
            text = render(words, level[0], level[1], level[2] == 1);
            if (text.length() <= MAX_PROMPT_CHARS) {
                return text;
            }
        }
        // Last resort: whole lines, then whole fields, from the end.
        while (text.length() > MAX_PROMPT_CHARS && text.contains('\n')) {
            text = text.substringBeforeLast('\n');
        }
        if (text.length() > MAX_PROMPT_CHARS) {
            text = text.left(MAX_PROMPT_CHARS).substringBeforeLast(', ');
        }
        return text;
    }

    // ---------------------------------------------------------------- prompt text

    private static String render(Set<String> words, Integer valuesShown, Integer indexNames, Boolean allListed) {
        List<String> lines = new List<String>();
        for (Entry e : entries()) {
            List<String> parts = new List<String>();
            for (Field f : shownFields(e, words, allListed)) {
                parts.add(fieldText(f, words, valuesShown));
            }
            lines.add(e.name + ': ' + String.join(parts, ', '));
        }
        List<String> names = new List<String>();
        for (List<String> o : indexFor(words, indexNames)) {
            names.add(o[0] == o[1] ? o[0] : o[0] + ' (' + o[1] + ')');
        }
        if (!names.isEmpty()) {
            lines.add('Other objects (fields listed after a plan names one): ' + String.join(names, ', '));
        }
        return String.join(lines, '\n');
    }

    /** The pruned fields: Id, the name, picklists, dates, amounts, flags, lookups, and every field the question mentions. */
    private static List<Field> shownFields(Entry e, Set<String> words, Boolean allListed) {
        List<Field> out = new List<Field>();
        Set<String> seen = new Set<String>();
        for (Field f : e.fields) {
            if (allListed ? pruneKeeps(f) : (f.path == 'Id' || f.isName || f.path.endsWith('.Name'))) {
                out.add(f);
                seen.add(f.path.toLowerCase());
            }
        }
        for (Field f : mentioned(e, words)) {
            if (!seen.contains(f.path.toLowerCase())) {
                out.add(f);
                seen.add(f.path.toLowerCase());
            }
        }
        return out;
    }

    private static Boolean pruneKeeps(Field f) {
        return f.path == 'Id' || f.isName || f.path.endsWith('.Name') || f.kind == KIND_ID || f.kind == KIND_DATE
            || f.kind == KIND_DATETIME || f.kind == KIND_BOOLEAN || f.type == 'picklist' || f.type == 'currency';
    }

    /** Fields of the object, or of a core parent through a listed lookup, whose name or label has a question word. */
    private static List<Field> mentioned(Entry e, Set<String> words) {
        List<Field> out = new List<Field>();
        if (words.isEmpty()) {
            return out;
        }
        for (String key : e.described.keySet()) {
            if (mentions(words, key, e.described.get(key).getLabel()) && e.field(key) != null) {
                out.add(e.field(key));
            }
        }
        for (Field lookup : e.fields) {
            if (lookup.kind != KIND_ID || lookup.path == 'Id' || lookup.path.contains('.') || lookup.referenceTo.size() != 1) {
                continue;
            }
            Entry parent = CURATED.containsKey(lookup.referenceTo[0]) ? find(lookup.referenceTo[0]) : null;
            Schema.DescribeFieldResult fd = e.described.get(lookup.path.toLowerCase());
            if (parent == null || parent === e || fd == null || fd.getRelationshipName() == null) {
                continue;
            }
            for (String key : parent.described.keySet()) {
                if (key != 'name' && mentions(words, key, parent.described.get(key).getLabel())) {
                    Field f = e.field(fd.getRelationshipName() + '.' + key);
                    if (f != null) {
                        out.add(f);
                    }
                }
            }
        }
        return out;
    }

    private static Boolean mentions(Set<String> words, String apiName, String label) {
        if (NOISE.contains(apiName)) {
            return false;
        }
        String haystack = apiName.toLowerCase() + ' ' + (label == null ? '' : label.toLowerCase());
        for (String w : words) {
            if (haystack.contains(w)) {
                return true;
            }
        }
        return false;
    }

    private static String fieldText(Field f, Set<String> words, Integer valuesShown) {
        List<String> notes = new List<String>{ f.type };
        if (!f.picklistValues.isEmpty() && valuesShown > 0) {
            List<String> first = new List<String>();
            List<String> rest = new List<String>();
            for (String v : f.picklistValues) {
                if (mentions(words, '', v)) {
                    first.add(v);
                } else {
                    rest.add(v);
                }
            }
            first.addAll(rest);
            while (first.size() > valuesShown) {
                first.remove(first.size() - 1);
            }
            notes.add(String.join(first, '|'));
        }
        if (!f.filterable) {
            notes.add('no filter');
        }
        return f.path + '(' + String.join(notes, ': ') + ')';
    }

    /** Lower-case words of four letters or more that are not stop words, singular too. */
    @TestVisible
    private static Set<String> questionWords(String question) {
        Set<String> out = new Set<String>();
        if (String.isBlank(question)) {
            return out;
        }
        for (String w : question.toLowerCase().split('[^a-z0-9]+')) {
            if (w.length() < 4 || STOP.contains(w)) {
                continue;
            }
            if (w.endsWith('ies') && w.length() > 4) {
                w = w.left(w.length() - 3) + 'y';
            } else if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) {
                w = w.left(w.length() - 1);
            }
            if (w.length() >= 4 && !STOP.contains(w)) {
                out.add(w);
            }
        }
        return out;
    }

    /** Other allowed objects for the index: the question's matches first, then COMMON, at most max. */
    private static List<List<String>> indexFor(Set<String> words, Integer max) {
        List<List<String>> out = new List<List<String>>();
        Set<String> taken = new Set<String>(build().keySet());
        for (Boolean matching : new List<Boolean>{ true, false }) {
            for (List<String> o : others()) {
                if (out.size() >= max) {
                    return out;
                }
                Boolean hit = !words.isEmpty() && mentions(words, o[0].toLowerCase(), o[1]);
                Boolean common = COMMON.contains(o[0]);
                if (!taken.contains(o[0].toLowerCase()) && (matching ? hit : common)) {
                    out.add(o);
                    taken.add(o[0].toLowerCase());
                }
            }
        }
        return out;
    }

    /** Every allowed object outside the core, as [name, label], shortest name first. */
    private static List<List<String>> others() {
        if (otherObjects != null) {
            return otherObjects;
        }
        Map<Integer, List<List<String>>> byLength = new Map<Integer, List<List<String>>>();
        Rules r = rules();
        for (String lower : globalTypes().keySet()) {
            if (CURATED.containsKey(lower) || !nameAllowed(r, lower)) {
                continue;
            }
            Schema.DescribeSObjectResult d = readable(globalTypes().get(lower));
            if (d == null) {
                continue;
            }
            Integer len = d.getName().length();
            if (!byLength.containsKey(len)) {
                byLength.put(len, new List<List<String>>());
            }
            byLength.get(len).add(new List<String>{ d.getName(), plainLabel(d.getLabel(), d.getName()) });
        }
        List<Integer> lengths = new List<Integer>(byLength.keySet());
        lengths.sort();
        otherObjects = new List<List<String>>();
        for (Integer len : lengths) {
            otherObjects.addAll(byLength.get(len));
        }
        return otherObjects;
    }

    // ---------------------------------------------------------------- deny list

    /**
     * The deny list from Explore_Deny_Rule__mdt. getAll() reads the product's own configuration, never rep
     * data, and it can only take access away. Fails closed: when the list is empty, unreadable or holds a
     * pattern that does not compile, no object is allowed.
     */
    private static Rules rules() {
        if (loadedRules != null) {
            return loadedRules;
        }
        Rules r = new Rules();
        try {
            if (failReadForTest) {
                throw new CatalogException('The deny list could not be read.');
            }
            List<Explore_Deny_Rule__mdt> rows = rulesForTest != null ? rulesForTest : Explore_Deny_Rule__mdt.getAll().values();
            for (Explore_Deny_Rule__mdt row : rows) {
                addRule(r, row);
            }
            r.usable = !rows.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ExploreCatalog: deny list not read, so every object is refused: ' + e.getMessage());
            r = new Rules();
        }
        loadedRules = r;
        return r;
    }

    private static void addRule(Rules r, Explore_Deny_Rule__mdt row) {
        String value = row.Value__c == null ? '' : row.Value__c.trim().toLowerCase();
        String scope = row.Object__c == null ? '' : row.Object__c.trim().toLowerCase();
        if (value == '') {
            return;
        }
        if (row.Rule_Type__c == RULE_OBJECT) {
            r.objects.add(value);
        } else if (row.Rule_Type__c == RULE_SUFFIX) {
            r.suffixes.add(value);
        } else if (row.Rule_Type__c == RULE_ALLOW_OBJECT) {
            r.allowed.add(value);
        } else if (row.Rule_Type__c == RULE_FIELD_PATTERN) {
            if (!r.patterns.containsKey(scope)) {
                r.patterns.put(scope, new List<Pattern>());
            }
            r.patterns.get(scope).add(Pattern.compile(value));
        } else if (row.Rule_Type__c == RULE_FIELD_TYPE) {
            if (!r.types.containsKey(scope)) {
                r.types.put(scope, new Set<String>());
            }
            r.types.get(scope).add(value);
        } else if (row.Rule_Type__c == RULE_ONLY_FIELDS && scope != '') {
            Set<String> only = new Set<String>();
            for (String f : value.split(',')) {
                only.add(f.trim());
            }
            r.onlyFields.put(scope, only);
        }
    }

    /** Object-name rules: deny names and suffixes, custom families only when allowed. A deny beats an allow. */
    private static Boolean nameAllowed(Rules r, String lower) {
        if (!r.usable || r.objects.contains(lower)) {
            return false;
        }
        for (String suffix : r.suffixes) {
            if (lower.endsWith(suffix)) {
                return false;
            }
        }
        return !lower.contains('__') || r.allowed.contains(lower);
    }

    /** Tests: the object-name rules alone, for names no org holds (Ping__e, Widget__c). */
    @TestVisible
    private static Boolean nameAllowed(String objectName) {
        return nameAllowed(rules(), objectName.trim().toLowerCase());
    }

    /** The object's describe when the deny list allows it and the running user may read and query it. */
    private static Schema.DescribeSObjectResult allowedObject(String objectName) {
        String lower = objectName.toLowerCase();
        return nameAllowed(rules(), lower) ? readable(globalTypes().get(lower)) : null;
    }

    private static Schema.DescribeSObjectResult readable(Schema.SObjectType t) {
        if (t == null) {
            return null;
        }
        Schema.DescribeSObjectResult d = t.getDescribe(SObjectDescribeOptions.DEFERRED);
        Boolean ok = d.isAccessible() && d.isQueryable() && !d.isCustomSetting() && !d.isDeprecatedAndHidden();
        return ok ? d : null;
    }

    /** Field rules: type (encrypted, base64, address, location), name or label pattern, and an object's only-fields list. */
    @TestVisible
    private static Boolean fieldDenied(String objectName, String fieldName, String label, String typeName, Boolean encrypted) {
        Rules r = rules();
        String obj = objectName.toLowerCase();
        String name = fieldName.toLowerCase();
        if (!r.usable || (r.onlyFields.containsKey(obj) && !r.onlyFields.get(obj).contains(name))) {
            return true;
        }
        for (String scope : new List<String>{ '', obj }) {
            Set<String> types = r.types.get(scope);
            if (types != null && (types.contains(typeName.toLowerCase()) || (encrypted && types.contains('encrypted')))) {
                return true;
            }
            for (Pattern p : r.patterns.containsKey(scope) ? r.patterns.get(scope) : new List<Pattern>()) {
                if (p.matcher(name).find() || p.matcher(label == null ? '' : label.toLowerCase()).find()) {
                    return true;
                }
            }
        }
        return false;
    }

    private static Boolean fieldAllowed(String objectName, Schema.DescribeFieldResult fd) {
        return fd.isAccessible()
            && !fieldDenied(objectName, fd.getName(), fd.getLabel(), String.valueOf(fd.getType()), fd.isEncrypted());
    }

    // ---------------------------------------------------------------- describe

    private static Map<String, Schema.SObjectType> globalTypes() {
        if (globalTypes == null) {
            globalTypes = Schema.getGlobalDescribe();
        }
        return globalTypes;
    }

    private static Map<String, Entry> build() {
        Id userId = UserInfo.getUserId();
        Map<String, Entry> built = cache.get(userId);
        if (built != null) {
            return built;
        }
        built = new Map<String, Entry>();
        cache.put(userId, built);
        for (String objectName : CURATED.keySet()) {
            Schema.DescribeSObjectResult d = allowedObject(objectName);
            Entry e = d == null ? null : describeObject(d, CURATED.get(objectName));
            if (e != null) {
                built.put(e.name.toLowerCase(), e);
            }
        }
        return built;
    }

    /** Describes one allowed object. paths: the listed fields; null lists the type-pruned set. */
    private static Entry describeObject(Schema.DescribeSObjectResult d, List<String> paths) {
        Entry e = new Entry();
        e.name = d.getName();
        e.label = d.getLabel();
        for (Schema.SObjectField sf : d.fields.getMap().values()) {
            Schema.DescribeFieldResult fd = sf.getDescribe();
            e.described.put(fd.getName().toLowerCase(), fd);
            if (fd.getRelationshipName() != null) {
                e.byRelationship.put(fd.getRelationshipName().toLowerCase(), fd);
            }
        }
        for (String path : paths != null ? paths : prunedPaths(e)) {
            Field f = e.field(path);
            if (f != null && !e.byPath.containsKey(f.path.toLowerCase())) {
                e.add(f);
            }
        }
        return e.fields.isEmpty() ? null : e;
    }

    /** An on-demand object's listed paths: Id, the name field, then picklists, dates, amounts, flags and lookups (with their Name). */
    private static List<String> prunedPaths(Entry e) {
        List<String> head = new List<String>();
        List<String> rest = new List<String>();
        for (Schema.DescribeFieldResult fd : e.described.values()) {
            String key = fd.getName().toLowerCase();
            Schema.DisplayType dt = fd.getType();
            if (key == 'id' || fd.isNameField()) {
                head.add(fd.getName());
            } else if (!NOISE.contains(key) && (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.DATE
                    || dt == Schema.DisplayType.DATETIME || dt == Schema.DisplayType.CURRENCY
                    || dt == Schema.DisplayType.BOOLEAN || dt == Schema.DisplayType.REFERENCE)) {
                rest.add(fd.getName());
                if (dt == Schema.DisplayType.REFERENCE && fd.getRelationshipName() != null && fd.getReferenceTo().size() == 1) {
                    rest.add(fd.getRelationshipName() + '.Name');
                }
            }
        }
        head.addAll(rest);
        while (head.size() > LISTED_FIELDS) {
            head.remove(head.size() - 1);
        }
        return head;
    }

    private static Field ownField(Entry e, String key) {
        Schema.DescribeFieldResult fd = e.described.get(key);
        if (fd == null || !fieldAllowed(e.name, fd)) {
            return null;
        }
        Field f = fromDescribe(fd);
        f.path = fd.getName();
        f.label = plainLabel(fd.getLabel(), fd.getName());
        f.isName = fd.isNameField();
        return f;
    }

    /**
     * A one-level parent path: the lookup must be allowed, and the parent field allowed on at least one
     * allowed object the lookup points to (polymorphic lookups such as Owner, Who and What point to several).
     */
    private static Field parentField(Entry e, String key) {
        List<String> parts = key.split('\\.');
        if (parts.size() != 2) {
            return null;
        }
        Schema.DescribeFieldResult lookup = e.byRelationship.get(parts[0]);
        if (lookup == null || !fieldAllowed(e.name, lookup)) {
            return null;
        }
        for (Schema.SObjectType target : lookup.getReferenceTo()) {
            Schema.DescribeSObjectResult td = allowedObject(String.valueOf(target));
            Schema.SObjectField sf = td == null ? null : td.fields.getMap().get(parts[1]);
            Schema.DescribeFieldResult fd = sf == null ? null : sf.getDescribe();
            if (fd == null || !fieldAllowed(td.getName(), fd)) {
                continue;
            }
            Field f = fromDescribe(fd);
            f.path = lookup.getRelationshipName() + '.' + fd.getName();
            f.label = parentLabel(lookup.getLabel(), lookup.getRelationshipName(), fd.getLabel(), fd.getName());
            f.filterable = f.filterable && lookup.isFilterable();
            f.sortable = f.sortable && lookup.isSortable();
            f.groupable = f.groupable && lookup.isGroupable();
            return f;
        }
        return null;
    }

    /** A label with no dot (a dotted name reads as a web address downstream), or fallback when it is blank. */
    @TestVisible
    private static String plainLabel(String label, String fallback) {
        String clean = label == null ? '' : label.replace('.', ' ').replaceAll('\\s+', ' ').trim();
        return clean == '' ? fallback : clean;
    }

    /**
     * The label of a parent field: the parent's label (the lookup's label without its trailing ' ID'),
     * plus the field label unless the field is Name. Account.Name is Account, Account.Industry is Account Industry.
     */
    @TestVisible
    private static String parentLabel(String lookupLabel, String relationship, String fieldLabel, String fieldName) {
        String parent = plainLabel(lookupLabel, relationship);
        if (parent.endsWith(' ID') && parent.length() > 3) {
            parent = parent.left(parent.length() - 3);
        }
        return fieldName == 'Name' ? parent : parent + ' ' + plainLabel(fieldLabel, fieldName);
    }

    private static Field fromDescribe(Schema.DescribeFieldResult fd) {
        Schema.DisplayType dt = fd.getType();
        Field f = new Field();
        f.type = String.valueOf(dt).toLowerCase();
        f.kind = kindOf(dt);
        f.filterable = fd.isFilterable();
        f.sortable = fd.isSortable();
        f.groupable = fd.isGroupable();
        f.aggregatable = fd.isAggregatable();
        for (Schema.SObjectType t : fd.getReferenceTo()) {
            f.referenceTo.add(String.valueOf(t));
        }
        if (dt == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry p : fd.getPicklistValues()) {
                if (p.isActive() && f.picklistValues.size() < PICKLIST_VALUES_KEPT) {
                    f.picklistValues.add(p.getValue());
                }
            }
        }
        return f;
    }

    private static String kindOf(Schema.DisplayType dt) {
        if (dt == Schema.DisplayType.ID || dt == Schema.DisplayType.REFERENCE) {
            return KIND_ID;
        }
        if (dt == Schema.DisplayType.BOOLEAN) {
            return KIND_BOOLEAN;
        }
        if (dt == Schema.DisplayType.INTEGER) {
            return KIND_INTEGER;
        }
        if (dt == Schema.DisplayType.LONG) {
            return KIND_LONG;
        }
        if (dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.PERCENT) {
            return KIND_NUMBER;
        }
        if (dt == Schema.DisplayType.DATE) {
            return KIND_DATE;
        }
        if (dt == Schema.DisplayType.DATETIME) {
            return KIND_DATETIME;
        }
        return KIND_TEXT;
    }

    /** Tests: forget the deny list and every described object, so the next call reads them again. */
    @TestVisible
    private static void reset() {
        loadedRules = null;
        otherObjects = null;
        cache = new Map<Id, Map<String, Entry>>();
    }

    public class CatalogException extends Exception {}
}
