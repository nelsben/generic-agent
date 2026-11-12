/**
 * ExploreCatalog: the curated objects and fields the data explorer may read.
 *
 * CURATED maps an object API name to its allowed field paths. A path is a field on the object or a
 * one-level parent path (relationship name + '.' + parent field, e.g. Owner.Name). Every object and
 * field is describe-checked for the running user: an object that is not accessible or not in the org
 * is dropped, and so is any field that is not accessible or not present. Fields the platform cannot
 * filter on (long text) are kept for display but marked not filterable.
 *
 * Names are kept as strings, never Schema tokens, so a field missing from an org is dropped, not a
 * compile error. Built once per user per transaction. Adding an object is one entry in CURATED.
 * No DML, no SOQL.
 */
public with sharing class ExploreCatalog {
    /** The curated catalog: object -> allowed field paths, in display order. */
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

    /** Picklist values shown per field in describeForPrompt(). */
    private static final Integer PICKLIST_VALUES_SHOWN = 12;

    /** One object the user may read, with its readable fields. */
    public class Entry {
        public String name;
        public String label;
        public List<Field> fields = new List<Field>();
        public Map<String, Field> byPath = new Map<String, Field>();

        /** The field for a path, matched case-insensitively, or null. */
        public Field field(String path) {
            return String.isBlank(path) ? null : byPath.get(path.trim().toLowerCase());
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
    }

    public static final String KIND_TEXT = 'text';
    public static final String KIND_ID = 'id';
    public static final String KIND_BOOLEAN = 'boolean';
    public static final String KIND_INTEGER = 'integer';
    public static final String KIND_LONG = 'long';
    public static final String KIND_NUMBER = 'number';
    public static final String KIND_DATE = 'date';
    public static final String KIND_DATETIME = 'datetime';

    /** Per transaction, per running user: lower-case object name -> Entry. */
    private static Map<Id, Map<String, Entry>> cache = new Map<Id, Map<String, Entry>>();

    /** The catalog entries the running user may read, in CURATED order. */
    public static List<Entry> entries() {
        return build().values();
    }

    /** The entry for an object name, matched case-insensitively, or null if not in the catalog for this user. */
    public static Entry find(String objectName) {
        return String.isBlank(objectName) ? null : build().get(objectName.trim().toLowerCase());
    }

    /**
     * The catalog as compact text for the prompt: one line per object, each field as path(type),
     * with picklist values and a 'no filter' mark where they apply.
     */
    public static String describeForPrompt() {
        List<String> lines = new List<String>();
        for (Entry e : entries()) {
            List<String> parts = new List<String>();
            for (Field f : e.fields) {
                List<String> notes = new List<String>{ f.type };
                if (!f.picklistValues.isEmpty()) {
                    notes.add(String.join(f.picklistValues, '|'));
                }
                if (!f.filterable) {
                    notes.add('no filter');
                }
                parts.add(f.path + '(' + String.join(notes, ': ') + ')');
            }
            lines.add(e.name + ': ' + String.join(parts, ', '));
        }
        return String.join(lines, '\n');
    }

    private static Map<String, Entry> build() {
        Id userId = UserInfo.getUserId();
        Map<String, Entry> built = cache.get(userId);
        if (built != null) {
            return built;
        }
        built = new Map<String, Entry>();
        Map<String, Schema.SObjectType> described = Schema.getGlobalDescribe();
        for (String objectName : CURATED.keySet()) {
            Entry e = describeObject(described.get(objectName.toLowerCase()), CURATED.get(objectName));
            if (e != null) {
                built.put(e.name.toLowerCase(), e);
            }
        }
        cache.put(userId, built);
        return built;
    }

    private static Entry describeObject(Schema.SObjectType t, List<String> paths) {
        if (t == null) {
            return null;
        }
        Schema.DescribeSObjectResult d = t.getDescribe();
        if (!d.isAccessible() || !d.isQueryable()) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = d.fields.getMap();
        Map<String, Schema.DescribeFieldResult> byRelationship = new Map<String, Schema.DescribeFieldResult>();
        for (Schema.SObjectField sf : fieldMap.values()) {
            Schema.DescribeFieldResult fd = sf.getDescribe();
            if (fd.getRelationshipName() != null) {
                byRelationship.put(fd.getRelationshipName().toLowerCase(), fd);
            }
        }

        Entry e = new Entry();
        e.name = d.getName();
        e.label = d.getLabel();
        for (String path : paths) {
            Field f = path.contains('.') ? describeParentPath(path, byRelationship) : describeField(fieldMap.get(path.toLowerCase()));
            if (f != null && e.field(f.path) == null) {
                e.add(f);
            }
        }
        return e.fields.isEmpty() ? null : e;
    }

    private static Field describeField(Schema.SObjectField sf) {
        if (sf == null) {
            return null;
        }
        Schema.DescribeFieldResult fd = sf.getDescribe();
        if (!fd.isAccessible()) {
            return null;
        }
        Field f = fromDescribe(fd);
        f.path = fd.getName();
        f.label = plainLabel(fd.getLabel(), fd.getName());
        return f;
    }

    /**
     * A one-level parent path: the lookup must be readable and the parent field readable on at least
     * one object the lookup points to (polymorphic lookups such as Owner, Who and What point to several).
     */
    private static Field describeParentPath(String path, Map<String, Schema.DescribeFieldResult> byRelationship) {
        List<String> parts = path.split('\\.');
        if (parts.size() != 2) {
            return null;
        }
        Schema.DescribeFieldResult lookup = byRelationship.get(parts[0].toLowerCase());
        if (lookup == null || !lookup.isAccessible()) {
            return null;
        }
        for (Schema.SObjectType target : lookup.getReferenceTo()) {
            Schema.DescribeSObjectResult td = target.getDescribe();
            Schema.SObjectField sf = td.isAccessible() ? td.fields.getMap().get(parts[1].toLowerCase()) : null;
            if (sf == null || !sf.getDescribe().isAccessible()) {
                continue;
            }
            Schema.DescribeFieldResult fd = sf.getDescribe();
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
            f.referenceTo.add(t.getDescribe().getName());
        }
        if (dt == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry p : fd.getPicklistValues()) {
                if (p.isActive() && f.picklistValues.size() < PICKLIST_VALUES_SHOWN) {
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
}
