// BE-31 prototype (engine 'v2'): a describe-driven catalog with a deny list, and a plan grammar with
// OR/NOT groups, two-level parent paths, semi- and anti-joins, child lists, CONTAINS on long text,
// HAVING and step references. Every name in a plan is checked against describe for the running user;
// SOQL text is built only from describe names, fixed operators, date literal tokens and local aliases;
// every value is a bind variable. Queries run in user mode. Read-only: no DML.
// Anonymous Apex allows no static members, so state lives in a Cat instance.

public class PlanException extends Exception {}

public class FieldRef {
    public String path;
    public String label;
    public DescribeFieldResult fd;
    public Boolean longText = false;
}

public class Cat {
    public Map<String, SObjectType> g = Schema.getGlobalDescribe();
    public Map<String, DescribeSObjectResult> objs = new Map<String, DescribeSObjectResult>();
    public Map<String, Map<String, DescribeFieldResult>> rels = new Map<String, Map<String, DescribeFieldResult>>();
    // The admin's deny list (custom metadata in a build): the product's own records, and system families.
    public Set<String> denyObjects = new Set<String>{ 'customer_summary_session__c', 'account_brief_session__c', 'customer_outcome__c', 'staticresource', 'apexclass', 'setupaudittrail', 'loginhistory', 'authsession', 'permissionset', 'profile' };
    public List<String> denySuffixes = new List<String>{ '__share', 'history', 'feed', 'changeevent', '__mdt', '__e', '__x', '__b', '__kav', '__chn' };
    public Pattern denyField = Pattern.compile('(?i).*(password|secret|token|ssn|taxid|creditcard|bankaccount).*');
    public Set<String> noise = new Set<String>{ 'isdeleted', 'systemmodstamp', 'lastvieweddate', 'lastreferenceddate', 'photourl', 'jigsaw', 'jigsawcompanyid', 'cleanstatus', 'masterrecordid', 'connectionreceivedid', 'connectionsentid', 'recordvisibilityid' };

    public DescribeSObjectResult obj(String name) {
        String k = name == null ? '' : name.trim().toLowerCase();
        if (objs.containsKey(k)) {
            return objs.get(k);
        }
        DescribeSObjectResult d = null;
        Boolean denied = denyObjects.contains(k) || !g.containsKey(k);
        for (String s : denySuffixes) {
            denied = denied || k.endsWith(s);
        }
        if (!denied) {
            d = g.get(k).getDescribe();
            if (!d.isAccessible() || !d.isQueryable() || d.isDeprecatedAndHidden()) {
                d = null;
            }
        }
        objs.put(k, d);
        return d;
    }

    public DescribeFieldResult field(DescribeSObjectResult d, String name) {
        SObjectField sf = d.fields.getMap().get(name.toLowerCase());
        if (sf == null) {
            return null;
        }
        DescribeFieldResult fd = sf.getDescribe();
        DisplayType t = fd.getType();
        if (!fd.isAccessible() || fd.isEncrypted() || t == DisplayType.BASE64 || t == DisplayType.ENCRYPTEDSTRING
            || t == DisplayType.ADDRESS || t == DisplayType.LOCATION || denyField.matcher(fd.getName()).matches()) {
            return null;
        }
        return fd;
    }

    public Map<String, DescribeFieldResult> lookups(DescribeSObjectResult d) {
        String k = d.getName().toLowerCase();
        if (!rels.containsKey(k)) {
            Map<String, DescribeFieldResult> m = new Map<String, DescribeFieldResult>();
            for (SObjectField sf : d.fields.getMap().values()) {
                DescribeFieldResult fd = sf.getDescribe();
                if (fd.getRelationshipName() != null && fd.isAccessible()) {
                    m.put(fd.getRelationshipName().toLowerCase(), fd);
                }
            }
            rels.put(k, m);
        }
        return rels.get(k);
    }

    // A field, or up to two lookups then a field. Each hop must be readable and point to an allowed object.
    public FieldRef path(DescribeSObjectResult d, String p) {
        List<String> parts = (p == null ? '' : p.trim()).split('\\.');
        if (parts.size() > 3 || String.isBlank(p)) {
            throw new PlanException('"' + p + '" goes more than two lookups deep.');
        }
        List<String> canon = new List<String>();
        List<String> label = new List<String>();
        List<DescribeSObjectResult> at = new List<DescribeSObjectResult>{ d };
        for (Integer i = 0; i < parts.size() - 1; i++) {
            DescribeFieldResult lk = null;
            List<DescribeSObjectResult> next = new List<DescribeSObjectResult>();
            for (DescribeSObjectResult a : at) {
                DescribeFieldResult f = lookups(a).get(parts[i].toLowerCase());
                if (f != null && lk == null) {
                    lk = f;
                    for (SObjectType t : f.getReferenceTo()) {
                        DescribeSObjectResult td = obj(String.valueOf(t));
                        if (td != null) {
                            next.add(td);
                        }
                    }
                }
            }
            if (lk == null || next.isEmpty()) {
                throw new PlanException('Unknown lookup "' + parts[i] + '" in "' + p + '".');
            }
            canon.add(lk.getRelationshipName());
            label.add(lk.getLabel().removeEnd(' ID'));
            at = next;
        }
        for (DescribeSObjectResult a : at) {
            DescribeFieldResult fd = field(a, parts[parts.size() - 1]);
            if (fd != null) {
                FieldRef r = new FieldRef();
                canon.add(fd.getName());
                if (!(label.size() > 0 && fd.getName() == 'Name')) {
                    label.add(fd.getLabel());
                }
                r.path = String.join(canon, '.');
                r.label = String.join(label, ' ');
                r.fd = fd;
                r.longText = !fd.isFilterable() && fd.getType() == DisplayType.TEXTAREA;
                return r;
            }
        }
        throw new PlanException('Unknown field "' + p + '" on ' + d.getName() + '.');
    }

    public ChildRelationship child(DescribeSObjectResult d, String rel) {
        for (ChildRelationship c : d.getChildRelationships()) {
            if (c.getRelationshipName() != null && c.getRelationshipName().equalsIgnoreCase(rel)
                && obj(String.valueOf(c.getChildSObject())) != null) {
                return c;
            }
        }
        throw new PlanException('Unknown child list "' + rel + '" on ' + d.getName() + '.');
    }

    // One catalog line: fields with type and marks, lookups as Name->Object, child lists to other catalog objects.
    public String line(DescribeSObjectResult d, Set<String> inPrompt) {
        List<String> parts = new List<String>();
        List<String> look = new List<String>();
        for (SObjectField sf : d.fields.getMap().values()) {
            DescribeFieldResult fd = field(d, sf.getDescribe().getName());
            if (fd == null || noise.contains(fd.getName().toLowerCase())) {
                continue;
            }
            String t = String.valueOf(fd.getType()).toLowerCase();
            if (fd.getType() == DisplayType.PICKLIST) {
                List<String> v = new List<String>();
                for (PicklistEntry pe : fd.getPicklistValues()) {
                    if (pe.isActive() && v.size() < 8) {
                        v.add(pe.getValue());
                    }
                }
                t += ': ' + String.join(v, '|');
            }
            if (!fd.isFilterable()) {
                t += ', long';
            }
            parts.add(fd.getName() + '(' + t + ')');
            if (fd.getRelationshipName() != null) {
                List<String> to = new List<String>();
                for (SObjectType rt : fd.getReferenceTo()) {
                    to.add(String.valueOf(rt));
                }
                look.add(fd.getRelationshipName() + '->' + String.join(to, '|'));
            }
        }
        List<String> kids = new List<String>();
        for (ChildRelationship c : d.getChildRelationships()) {
            String cn = String.valueOf(c.getChildSObject());
            if (c.getRelationshipName() != null && inPrompt.contains(cn.toLowerCase())) {
                kids.add(c.getRelationshipName() + '(' + cn + '.' + c.getField().getDescribe().getName() + ')');
            }
        }
        return d.getName() + ': ' + String.join(parts, ', ') + '\n  lookups: ' + String.join(look, ', ') + '\n  children: ' + String.join(kids, ', ');
    }

    // The objects for this question: the core set, plus allowed objects whose API name holds a word of the question.
    public List<String> pick(String question, Meter m) {
        List<String> core = new List<String>{ 'Account', 'Contact', 'Opportunity', 'OpportunityContactRole', 'Case', 'Task', 'Event', 'User' };
        Set<String> coreKeys = new Set<String>();
        for (String c : core) {
            coreKeys.add(c.toLowerCase());
        }
        Set<String> words = new Set<String>();
        for (String w : question.toLowerCase().split('[^a-z0-9]+')) {
            if (w.length() >= 5) {
                words.add(w.removeEnd('s'));
            }
        }
        List<String> extra = new List<String>();
        for (String k : g.keySet()) {
            String flat = k.removeEnd('__c').replace('_', '');
            Integer hits = 0;
            for (String w : words) {
                hits += flat.contains(w) ? 1 : 0;
            }
            if (hits > 0 && !coreKeys.contains(k) && obj(k) != null) {
                extra.add(k);
            }
        }
        m.shapes.put('extraCandidates', extra.size());
        List<String> ranked = new List<String>();
        for (String k : extra) {
            ranked.add(String.valueOf(1000 + k.length()) + k);
        }
        ranked.sort();
        List<String> out = core.clone();
        for (String k : ranked) {
            if (out.size() < core.size() + 6) {
                out.add(obj(k.substring(4)).getName());
            }
        }
        return out;
    }
}

public class Built {
    public String obj;
    public String soql;
    public String countSoql;
    public Map<String, Object> binds = new Map<String, Object>();
    public List<String> cols = new List<String>();
    public List<String> labels = new List<String>();
    public List<String> aliases = new List<String>();
    public List<String> kids = new List<String>();
    public List<List<String>> longs = new List<List<String>>();
    public Boolean agg = false;
    public Boolean countOnly = false;
    public Integer lim;
    public Integer semis = 0;
    public Integer conds = 0;
}

public class Planner {
    public Cat cat;
    public Meter m;
    public List<List<Map<String, Object>>> steps;
    public Built b;
    public Planner(Cat c, Meter mt, List<List<Map<String, Object>>> s) {
        cat = c;
        m = mt;
        steps = s;
    }

    void shape(String k) {
        m.shapes.put(k, (m.shapes.get(k) ?? 0) + 1);
    }

    String bind(Object v) {
        String k = 'b' + b.binds.size();
        b.binds.put(k, v);
        return ':' + k;
    }

    Object typed(FieldRef f, Object v) {
        DisplayType t = f.fd.getType();
        if (v == null || v instanceof List<Object> || v instanceof Map<String, Object>) {
            throw new PlanException('The value for ' + f.path + ' must be a single value.');
        }
        String s = String.valueOf(v).trim();
        try {
            if (t == DisplayType.BOOLEAN) {
                return Boolean.valueOf(s);
            }
            if (t == DisplayType.DOUBLE || t == DisplayType.CURRENCY || t == DisplayType.PERCENT || t == DisplayType.INTEGER) {
                return Decimal.valueOf(s);
            }
            if (t == DisplayType.DATE) {
                return Date.valueOf(s);
            }
            if (t == DisplayType.DATETIME) {
                return s.length() == 10 ? Datetime.newInstance(Date.valueOf(s), Time.newInstance(0, 0, 0, 0)) : (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
            }
            if (t == DisplayType.ID || t == DisplayType.REFERENCE) {
                return Id.valueOf(s);
            }
        } catch (Exception e) {
            throw new PlanException('"' + s + '" does not fit ' + f.path + ' (' + t + ').');
        }
        return String.valueOf(v);
    }

    String literal(FieldRef f, Object v) {
        DisplayType t = f.fd.getType();
        if ((t != DisplayType.DATE && t != DisplayType.DATETIME) || !(v instanceof String)) {
            return null;
        }
        String s = ((String) v).trim().toUpperCase();
        if (ExplorePlan.DATE_LITERALS.contains(s)) {
            return s;
        }
        List<String> p = s.split(':');
        if (p.size() == 2 && ExplorePlan.DATE_LITERALS_N.contains(p[0]) && p[1].trim().isNumeric() && Integer.valueOf(p[1].trim()) <= 1000) {
            return p[0] + ':' + Integer.valueOf(p[1].trim());
        }
        return null;
    }

    public String expr(DescribeSObjectResult d, Object node, Integer depth, Boolean top) {
        if (!(node instanceof Map<String, Object>) || depth > 4) {
            throw new PlanException('"where" parts must be conditions or groups, at most 4 deep.');
        }
        Map<String, Object> n = (Map<String, Object>) node;
        for (String g : new List<String>{ 'and', 'or' }) {
            if (n.get(g) instanceof List<Object>) {
                if (g == 'or') {
                    shape('or');
                }
                List<String> parts = new List<String>();
                for (Object c : (List<Object>) n.get(g)) {
                    String e = expr(d, c, depth + 1, top && g == 'and');
                    if (e != null) {
                        parts.add(e);
                    }
                }
                return parts.isEmpty() ? null : '(' + String.join(parts, ' ' + g.toUpperCase() + ' ') + ')';
            }
        }
        if (n.containsKey('not')) {
            shape('not');
            return '(NOT (' + expr(d, n.get('not'), depth + 1, false) + '))';
        }
        if (++b.conds > 20) {
            throw new PlanException('Use at most 20 conditions.');
        }
        FieldRef f = cat.path(d, (String) n.get('field'));
        String op = String.valueOf(n.get('op') ?? '').trim().toUpperCase();
        Object v = n.get('value');
        if (f.path.countMatches('.') == 2) {
            shape('depth2');
        }
        if (n.get('sub') instanceof Map<String, Object>) {
            return semi(d, f, op, (Map<String, Object>) n.get('sub'), top);
        }
        if (v instanceof Map<String, Object> && ((Map<String, Object>) v).containsKey('step')) {
            return stepRef(f, op, (Map<String, Object>) v);
        }
        if (op == 'CONTAINS') {
            if (!f.longText) {
                return f.path + ' LIKE ' + bind('%' + String.valueOf(v).replace('%', '\\%').replace('_', '\\_') + '%');
            }
            if (!top) {
                throw new PlanException('CONTAINS on long text ' + f.path + ' must be at the top level of "where".');
            }
            shape('longText');
            b.longs.add(new List<String>{ f.path, String.valueOf(v).toLowerCase() });
            return null;
        }
        if (!f.fd.isFilterable()) {
            throw new PlanException(f.path + ' is long text: use CONTAINS.');
        }
        if (op == 'IN' || op == 'NOT IN') {
            if (!(v instanceof List<Object>) || ((List<Object>) v).isEmpty() || ((List<Object>) v).size() > 200) {
                throw new PlanException(op + ' on ' + f.path + ' needs a list of 1 to 200 values.');
            }
            List<Object> out = new List<Object>();
            for (Object o : (List<Object>) v) {
                out.add(typed(f, o));
            }
            return f.path + ' ' + op + ' ' + bind(retype(out));
        }
        if (!new Set<String>{ '=', '!=', '<', '<=', '>', '>=', 'LIKE' }.contains(op)) {
            throw new PlanException('Unknown op "' + op + '" on ' + f.path + '.');
        }
        String lit = literal(f, v);
        if (lit != null) {
            return f.path + ' ' + op + ' ' + lit;
        }
        return f.path + ' ' + op + ' ' + (v == null ? 'null' : bind(typed(f, v)));
    }

    // A typed list, so IN binds compare like for like.
    Object retype(List<Object> vals) {
        if (!vals.isEmpty() && vals[0] instanceof Id) {
            List<Id> o = new List<Id>();
            for (Object x : vals) {
                o.add((Id) x);
            }
            return o;
        }
        if (!vals.isEmpty() && vals[0] instanceof Decimal) {
            List<Decimal> o = new List<Decimal>();
            for (Object x : vals) {
                o.add((Decimal) x);
            }
            return o;
        }
        List<String> o = new List<String>();
        for (Object x : vals) {
            o.add(String.valueOf(x));
        }
        return o;
    }

    String semi(DescribeSObjectResult d, FieldRef left, String op, Map<String, Object> sub, Boolean top) {
        DescribeSObjectResult sd = cat.obj((String) sub.get('object'));
        if (sd == null) {
            throw new PlanException('Unknown object "' + sub.get('object') + '" in "sub".');
        }
        if (!top) {
            throw new PlanException('"sub" must be at the top level of "where", not inside "or" or "not".');
        }
        if (++b.semis > 2) {
            throw new PlanException('Use "sub" at most twice.');
        }
        if (sd.getName() == d.getName() || sd.getName() == 'Task' || sd.getName() == 'Event') {
            throw new PlanException(sd.getName() + ' can\'t be in "sub"; query it first and use a step value.');
        }
        if (left.path.contains('.') || (left.fd.getType() != DisplayType.ID && left.fd.getType() != DisplayType.REFERENCE)) {
            throw new PlanException('"sub" needs Id or a lookup on ' + d.getName() + '.');
        }
        FieldRef right = cat.path(sd, (String) sub.get('field'));
        if (right.path.contains('.') || right.fd.getType() != DisplayType.REFERENCE) {
            throw new PlanException(right.path + ' is not a lookup on ' + sd.getName() + '.');
        }
        if (op != 'IN' && op != 'NOT IN') {
            throw new PlanException('"sub" takes IN or NOT IN.');
        }
        shape(op == 'IN' ? 'semi' : 'anti');
        String w = sub.get('where') == null ? null : expr(sd, sub.get('where'), 1, false);
        return left.path + ' ' + op + ' (SELECT ' + right.path + ' FROM ' + sd.getName() + (w == null ? '' : ' WHERE ' + w) + ')';
    }

    String stepRef(FieldRef f, String op, Map<String, Object> v) {
        Integer n = Integer.valueOf(v.get('step'));
        if (n < 1 || n > steps.size() || (op != 'IN' && op != 'NOT IN')) {
            throw new PlanException('A step value needs IN or NOT IN and an earlier query (1 to ' + steps.size() + ').');
        }
        String key = String.valueOf(v.get('field') ?? 'Id');
        Set<Id> ids = new Set<Id>();
        for (Map<String, Object> r : steps[n - 1]) {
            Object x = r.get(key);
            if (x instanceof Id && ids.size() < 500) {
                ids.add((Id) x);
            }
        }
        shape('step');
        return f.path + ' ' + op + ' ' + bind(new List<Id>(ids));
    }

    public Built build(Map<String, Object> p) {
        b = new Built();
        DescribeSObjectResult d = cat.obj((String) p.get('object'));
        if (d == null) {
            throw new PlanException('Unknown object "' + p.get('object') + '".');
        }
        b.obj = d.getName();
        m.objects.add(b.obj);
        List<String> sel = new List<String>();
        List<String> groups = new List<String>();
        for (Object o : (List<Object>) (p.get('groupBy') ?? new List<Object>())) {
            FieldRef f = cat.path(d, (String) o);
            if (!f.fd.isGroupable()) {
                throw new PlanException(f.path + ' can\'t be grouped.');
            }
            groups.add(f.path);
            sel.add(f.path + ' g' + b.cols.size());
            b.aliases.add('g' + b.cols.size());
            b.cols.add(f.path);
            b.labels.add(f.label);
        }
        List<String> aggs = new List<String>();
        b.countOnly = p.get('aggregates') instanceof List<Object> && !((List<Object>) p.get('aggregates')).isEmpty();
        for (Object o : (List<Object>) (p.get('aggregates') ?? new List<Object>())) {
            Map<String, Object> a = (Map<String, Object>) o;
            String fn = String.valueOf(a.get('fn')).toUpperCase();
            if (!new Set<String>{ 'COUNT', 'SUM', 'AVG', 'MIN', 'MAX' }.contains(fn)) {
                throw new PlanException('Unknown aggregate "' + fn + '".');
            }
            String fp = String.isBlank((String) a.get('field')) ? 'Id' : cat.path(d, (String) a.get('field')).path;
            aggs.add(fn + '(' + fp + ')');
            b.countOnly = b.countOnly && fn == 'COUNT' && fp == 'Id';
            sel.add(fn + '(' + fp + ') a' + b.cols.size());
            b.aliases.add('a' + b.cols.size());
            b.cols.add(fn + '(' + fp + ')');
            b.labels.add(fn.toLowerCase().capitalize() + (fp == 'Id' ? '' : ' of ' + fp));
        }
        b.agg = !aggs.isEmpty() || !groups.isEmpty();
        if (!b.agg) {
            for (Object o : (List<Object>) (p.get('fields') ?? new List<Object>())) {
                FieldRef f = cat.path(d, (String) o);
                if (!b.cols.contains(f.path)) {
                    b.cols.add(f.path);
                    b.labels.add(f.label);
                    sel.add(f.path);
                    if (f.path.countMatches('.') == 2) {
                        shape('depth2');
                    }
                }
            }
            if (!b.cols.contains('Id')) {
                sel.add('Id');
            }
            for (Object o : (List<Object>) (p.get('children') ?? new List<Object>())) {
                Map<String, Object> c = (Map<String, Object>) o;
                ChildRelationship cr = cat.child(d, (String) c.get('rel'));
                DescribeSObjectResult cd = cat.obj(String.valueOf(cr.getChildSObject()));
                List<String> cf = new List<String>{ 'Id' };
                for (Object x : (List<Object>) (c.get('fields') ?? new List<Object>())) {
                    String fp = cat.path(cd, (String) x).path;
                    if (!cf.contains(fp)) {
                        cf.add(fp);
                    }
                }
                String w = c.get('where') == null ? null : expr(cd, c.get('where'), 1, false);
                Integer cl = Math.min(10, Integer.valueOf(c.get('limit') ?? 5));
                if (b.kids.size() == 2) {
                    throw new PlanException('Use at most 2 child lists.');
                }
                sel.add('(SELECT ' + String.join(cf, ', ') + ' FROM ' + cr.getRelationshipName() + (w == null ? '' : ' WHERE ' + w) + ' LIMIT ' + cl + ')');
                b.kids.add(cr.getRelationshipName());
                shape('children');
            }
        }
        if (sel.isEmpty()) {
            throw new PlanException('List at least one field, or use aggregates.');
        }
        Object wn = p.get('where') ?? (p.get('filters') instanceof List<Object> ? new Map<String, Object>{ 'and' => p.get('filters') } : null);
        String w = wn == null ? null : expr(d, wn, 1, true);
        if (!b.longs.isEmpty() && b.agg) {
            throw new PlanException('CONTAINS on long text can\'t be combined with aggregates.');
        }
        for (List<String> lt : b.longs) {
            if (!sel.contains(lt[0])) {
                sel.add(lt[0]);
            }
        }
        String fromWhere = ' FROM ' + b.obj + (w == null ? '' : ' WHERE ' + w);
        b.countSoql = 'SELECT COUNT()' + fromWhere;
        String q = 'SELECT ' + String.join(sel, ', ') + fromWhere;
        if (!groups.isEmpty()) {
            q += ' GROUP BY ' + String.join(groups, ', ');
            List<String> hv = new List<String>();
            for (Object o : (List<Object>) (p.get('having') ?? new List<Object>())) {
                Map<String, Object> h = (Map<String, Object>) o;
                String e = String.valueOf(h.get('fn')).toUpperCase() + '(' + (String.isBlank((String) h.get('field')) ? 'Id' : cat.path(d, (String) h.get('field')).path) + ')';
                String op = String.valueOf(h.get('op'));
                if (!aggs.contains(e) || !new Set<String>{ '=', '!=', '<', '<=', '>', '>=' }.contains(op)) {
                    throw new PlanException('"having" must use one of the aggregates and a comparison.');
                }
                Decimal hvv = Decimal.valueOf(String.valueOf(h.get('value')));
                hv.add(e + ' ' + op + ' ' + bind(e.startsWith('COUNT') ? (Object) hvv.intValue() : hvv));
                shape('having');
            }
            q += hv.isEmpty() ? '' : ' HAVING ' + String.join(hv, ' AND ');
        }
        Map<String, Object> ob = p.get('orderBy') instanceof Map<String, Object> ? (Map<String, Object>) p.get('orderBy') : null;
        if (ob != null && ob.get('field') != null && !(b.agg && groups.isEmpty())) {
            String obf = String.valueOf(ob.get('field')).trim();
            String ox = null;
            for (String a : aggs) {
                ox = a.equalsIgnoreCase(obf.replace('()', '(Id)')) ? a : ox;
            }
            if (ox == null) {
                FieldRef f = cat.path(d, obf);
                if (!f.fd.isSortable()) {
                    throw new PlanException(obf + ' can\'t be sorted.');
                }
                ox = f.path;
            }
            q += ' ORDER BY ' + ox + (String.valueOf(ob.get('dir')).toUpperCase() == 'DESC' ? ' DESC NULLS LAST' : ' ASC');
        }
        if (!(b.agg && groups.isEmpty())) {
            Integer l = p.get('limit') == null ? 50 : Integer.valueOf(p.get('limit'));
            b.lim = Math.max(1, Math.min(200, l));
            q += ' LIMIT ' + (b.longs.isEmpty() ? b.lim : 2001);
        }
        b.soql = q;
        return b;
    }
}

Object valueAt(SObject r, String path) {
    List<String> parts = path.split('\\.');
    SObject at = r;
    for (Integer i = 0; i < parts.size() - 1 && at != null; i++) {
        at = at.getSObject(parts[i]);
    }
    return at == null ? null : at.get(parts[parts.size() - 1]);
}

// Runs a built plan in user mode. Long-text CONTAINS is applied here, over at most 2,000 scanned rows.
ExploreQuery.ResultSet runBuilt(Built b) {
    if (b.agg && !b.countOnly && Database.countQueryWithBinds(b.countSoql + ' LIMIT 10001', b.binds, AccessLevel.USER_MODE) > 10000) {
        throw new PlanException('That would read more than 10000 rows. Add filters to narrow it.');
    }
    List<SObject> recs = Database.queryWithBinds(b.soql, b.binds, AccessLevel.USER_MODE);
    if (!b.longs.isEmpty() && recs.size() > 2000) {
        throw new PlanException('Searching long text would scan more than 2000 rows. Add filters to narrow it.');
    }
    ExploreQuery.ResultSet rs = new ExploreQuery.ResultSet();
    rs.objectName = b.obj;
    rs.columns = b.cols.clone();
    rs.labels = b.labels.clone();
    rs.columns.addAll(b.kids);
    rs.labels.addAll(b.kids);
    Integer matched = 0;
    for (SObject r : recs) {
        Boolean keep = true;
        for (List<String> lt : b.longs) {
            keep = keep && String.valueOf(valueAt(r, lt[0]) ?? '').toLowerCase().contains(lt[1]);
        }
        if (!keep) {
            continue;
        }
        matched++;
        if (b.lim != null && rs.rows.size() >= b.lim) {
            continue;
        }
        Map<String, Object> row = new Map<String, Object>();
        for (Integer i = 0; i < b.cols.size(); i++) {
            row.put(b.cols[i], b.agg ? r.get(b.aliases[i]) : valueAt(r, b.cols[i]));
        }
        for (String k : b.kids) {
            row.put(k, r.getSObjects(k) == null ? 0 : r.getSObjects(k).size());
        }
        if (!b.agg) {
            row.put('Id', r.Id);
        }
        rs.rows.add(row);
    }
    rs.shown = rs.rows.size();
    rs.total = b.longs.isEmpty() ? rs.shown : matched;
    if (!b.agg && b.longs.isEmpty() && b.lim != null && rs.shown >= b.lim) {
        rs.total = Database.countQueryWithBinds(b.countSoql, b.binds, AccessLevel.USER_MODE);
    }
    return rs;
}
