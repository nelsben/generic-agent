/**
 * AnswerCard: one card of an answer, the typed shape of FE-18's contract (docs/research/fr2-card-architecture.md),
 * as built in Apex (docs/research/fr2-card-contract-apex.md). A card is data the service already holds, in a fixed
 * shape every surface can draw: the panel draws it, an MCP client reads it as JSON, and its `text` is the plain-text
 * fallback that says the same thing.
 *
 * Rules every card keeps:
 * - Cells, values and labels are formatted strings. No Map or Object member, so the shape is the same everywhere.
 * - A record Id appears only in `refs`. Everything else points at a record by its ref key ('o1', 'c2').
 * - `text` follows its type's rule (plainText) and never holds an Id or markup.
 * - `total` and `shown` sit on a list or a grid; `shown` is the rows or items the card holds.
 *
 * No query, DML or callout: the builders shape what a caller passes in. actionDraft and actionResult are typed here
 * and have a text rule, but nothing builds them yet (BE-27 will).
 */
public with sharing class AnswerCard {
    /** The contract version every card carries today. */
    public static final Integer CONTRACT_VERSION = 1;

    /**
     * The longest cards JSON an invocable returns. Over it, toJson gives '' (never cut JSON) and the answer text is
     * unchanged. See docs/research/fr2-card-contract-apex.md, 'The cards cap', for how the figure was chosen.
     */
    public static final Integer MAX_JSON_CHARS = 60000;
    /** The cap toJson applies; tests lower it to reach the over-the-cap path. */
    @TestVisible private static Integer maxJsonChars = MAX_JSON_CHARS;

    public static final String OK = 'OK';
    public static final String EMPTY = 'EMPTY';
    public static final String ERROR = 'ERROR';
    public static final String NOT_FOUND = 'NOT_FOUND';
    public static final String AMBIGUOUS = 'AMBIGUOUS';

    private static final String SEP = ' — ';
    private static final String DOT = ' · ';
    private static final Pattern INLINE = Pattern.compile(
        '\\*\\*([^*\\n]+)\\*\\*|\\*([^*\\s\\n][^*\\n]*)\\*|`([^`\\n]+)`|\\[([^\\]\\n]+)\\]\\(ref:([A-Za-z0-9_-]+)\\)');
    private static final Pattern BULLET = Pattern.compile('^\\s*[-•]\\s+(.*)$');
    private static final Pattern NUMBERED = Pattern.compile('^\\s*(\\d{1,3})[.)]\\s+(.*)$');
    /** A record Id at the end of a section line, as CustomerSummarySection.withId writes it. */
    private static final Pattern LINE_ID = Pattern.compile('^(.*) — ([0-9][0-9A-Za-z]{17})$');
    private static final Pattern MORE_LINE = Pattern.compile('^- …and \\d+ more not shown$');

    // ------------------------------------------------------------------ the card

    /** The card type: summary, section, text, table, metric, record, recordList, timeline, comparison, choice,
     * followups, trail, notice, error, actionDraft or actionResult. */
    @AuraEnabled public String type;
    /** The contract version, 1 today. */
    @AuraEnabled public Integer version = CONTRACT_VERSION;
    /** Unique within one answer, stable for the same content: 'sum', 'sec-open_deals', 'tbl'. */
    @AuraEnabled public String key;
    /** The heading. '' for text, notice and error cards. */
    @AuraEnabled public String title;
    /** A short line beside the title, such as the object name. */
    @AuraEnabled public String meta;
    /** OK, EMPTY, ERROR, NOT_FOUND, AMBIGUOUS, READY, NEEDS_INPUT, REFUSED or UNDONE. Absent on followups and trail. */
    @AuraEnabled public String status;
    /** The plain-text fallback, by the type's rule (plainText). Never an Id, never markup. */
    @AuraEnabled public String text;
    /** Rich text as blocks of runs. */
    @AuraEnabled public List<Block> body = new List<Block>();
    /** How many rows or records matched (lists and grids). */
    @AuraEnabled public Integer total;
    /** How many the card holds (lists and grids). */
    @AuraEnabled public Integer shown;
    /** Grid columns (table, comparison). */
    @AuraEnabled public List<Column> columns;
    /** Grid rows (table, comparison). */
    @AuraEnabled public List<Row> rows;
    /** List items (section, metric, recordList, timeline, choice, followups, trail; record's related lists). */
    @AuraEnabled public List<Item> items;
    /** Label and value pairs (record, actionDraft, actionResult). */
    @AuraEnabled public List<Field> fields;
    /** Buttons (actionDraft, actionResult). */
    @AuraEnabled public List<Control> controls;
    /** The records the card names. The only place a record Id appears. */
    @AuraEnabled public List<Ref> refs = new List<Ref>();

    /** A paragraph ('p'), bullet ('li') or numbered item ('ol'). */
    public class Block {
        @AuraEnabled public String kind;
        @AuraEnabled public List<Run> runs = new List<Run>();
    }

    /** A stretch of text. strong, em and code are set only when true; ref points at a ref key. */
    public class Run {
        @AuraEnabled public String text;
        @AuraEnabled public Boolean strong;
        @AuraEnabled public Boolean em;
        @AuraEnabled public Boolean code;
        @AuraEnabled public String ref;
    }

    /** A label and its formatted value. state 'missing' or 'choose' on a draft; choices are ref keys. */
    public class Field {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String ref;
        @AuraEnabled public String state;
        @AuraEnabled public List<String> choices;
    }

    /** A grid column. kind is text, number, currency, percent or date. */
    public class Column {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String kind;
    }

    /** A grid row: formatted cells in column order, and the ref key of the record it is, if any. */
    public class Row {
        @AuraEnabled public String ref;
        @AuraEnabled public List<String> cells = new List<String>();
    }

    /**
     * One line of a list. at is a date for a timeline; kind is a timeline kind or 'related'. status is FE-18's
     * optional per-item status; no builder sets it yet, so it stays null and out of the JSON.
     */
    public class Item {
        @AuraEnabled public String at;
        @AuraEnabled public String kind;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;
        @AuraEnabled public String status;
        @AuraEnabled public String ref;
    }

    /** A button. kind is primary, neutral or link. */
    public class Control {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String kind;
    }

    /** A record the card names: its key in this card, its Id, its object and a label for the link. */
    public class Ref {
        @AuraEnabled public String key;
        @AuraEnabled public String recordId;
        @AuraEnabled public String objectName;
        @AuraEnabled public String label;
    }

    // ------------------------------------------------------------------ builders, one per type

    /**
     * The answer's headline card: the first line is the title, the rest is rich text.
     * @param key the card key, 'sum'
     * @param status the summary's status
     * @param answer the answer text, markdown-light
     * @return the summary card
     */
    public static AnswerCard summary(String key, String status, String answer) {
        AnswerCard c = start('summary', key, status);
        c.meta = 'Account summary';
        List<Block> blocks = parse(answer, c.refs);
        c.title = blocks.isEmpty() ? '' : runsText(blocks.remove(0).runs);
        c.body = blocks;
        return finish(c);
    }

    /**
     * One Customer Summary section. A top-level '- ' line that ends with a record Id is an item: its label is the first
     * part, its detail the rest joined ' · ', its ref the record. Every other line is a literal block (section text is
     * record data, never markup); a line that ends with an Id links to it. The '…and N more' line is left out: the
     * count is total and shown.
     * @param s the section, as the service built it
     * @return its card, or null for no section
     */
    public static AnswerCard section(CustomerSummarySection s) {
        if (s == null) {
            return null;
        }
        AnswerCard c = start('section', 'sec-' + s.key, s.status);
        c.title = s.title;
        c.items = new List<Item>();
        Boolean failed = s.status == ERROR;
        c.total = failed || s.total == null ? 0 : s.total;
        c.shown = failed || s.shown == null ? 0 : s.shown;
        for (String raw : lines(s.body)) {
            String line = raw.replaceAll('\\s+$', '');
            if (String.isBlank(line) || MORE_LINE.matcher(line).matches()) {
                continue;
            }
            Matcher withId = LINE_ID.matcher(line);
            Id recordId = withId.matches() ? toId(withId.group(2)) : null;
            String content = recordId == null ? line : withId.group(1);
            if (recordId != null && !failed && content.startsWith('- ')) {
                List<String> parts = content.substring(2).split(SEP);
                Item i = newItem(parts.remove(0).trim(), null, parts.isEmpty() ? null : String.join(parts, DOT), null);
                i.ref = addRef(c.refs, recordId, i.label);
                c.items.add(i);
            } else {
                Block b = literal(content);
                if (recordId != null) {
                    b.runs[0].ref = addRef(c.refs, recordId, b.runs[0].text);
                }
                c.body.add(b);
            }
        }
        return finish(c);
    }

    /**
     * Rich text, such as the explorer's answer. Bold, italic, code and [label](ref:key) links to the card's refs.
     * @param key the card key, 'ans'
     * @param status the answer's status
     * @param markdown the text
     * @param refs the records its links may name; null for none
     * @return the text card
     */
    public static AnswerCard text(String key, String status, String markdown, List<Ref> refs) {
        AnswerCard c = start('text', key, status);
        c.title = '';
        c.refs = refs == null ? new List<Ref>() : refs;
        c.body = parse(markdown, c.refs);
        return finish(c);
    }

    /**
     * A grid of records or groups. shown is the rows it holds.
     * @param key the card key, 'tbl'
     * @param title the heading, such as the object's name
     * @param columns the columns
     * @param rows the rows, cells formatted
     * @param total how many rows matched
     * @param refs the records the rows point at
     * @return the table card
     */
    public static AnswerCard table(String key, String title, List<Column> columns, List<Row> rows, Integer total, List<Ref> refs) {
        AnswerCard c = start('table', key, OK);
        c.title = title;
        c.columns = columns == null ? new List<Column>() : columns;
        c.rows = rows == null ? new List<Row>() : rows;
        c.shown = c.rows.size();
        c.total = total == null ? c.shown : total;
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * Figures: each item is a label and its formatted value.
     * @param key the card key, 'met'
     * @param title the heading
     * @param items the figures
     * @return the metric card
     */
    public static AnswerCard metric(String key, String title, List<Item> items) {
        AnswerCard c = start('metric', key, OK);
        c.title = title;
        c.items = items == null ? new List<Item>() : items;
        return finish(c);
    }

    /**
     * One record: its fields, and the related lists it has.
     * @param key the card key, 'rec'
     * @param title the record's name
     * @param meta its object's label
     * @param fields the fields, values formatted; a lookup's ref points at its record
     * @param relatedLabels the related lists' labels
     * @param refs the records the fields point at
     * @return the record card
     */
    public static AnswerCard record(String key, String title, String meta, List<Field> fields, List<String> relatedLabels, List<Ref> refs) {
        AnswerCard c = start('record', key, OK);
        c.title = title;
        c.meta = meta;
        c.fields = fields == null ? new List<Field>() : fields;
        c.items = new List<Item>();
        for (String label : relatedLabels == null ? new List<String>() : relatedLabels) {
            Item i = newItem(label, null, null, null);
            i.kind = 'related';
            c.items.add(i);
        }
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * A list of records: a label and one detail each. shown is the items it holds.
     * @param key the card key, 'lst'
     * @param title the heading
     * @param items the records
     * @param total how many matched
     * @param refs the records the items point at
     * @return the recordList card
     */
    public static AnswerCard recordList(String key, String title, List<Item> items, Integer total, List<Ref> refs) {
        AnswerCard c = start('recordList', key, OK);
        c.title = title;
        c.items = items == null ? new List<Item>() : items;
        c.shown = c.items.size();
        c.total = total == null ? c.shown : total;
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * Dated items, newest first, each with its at and kind set.
     * @param key the card key, 'tml'
     * @param title the heading
     * @param items the dated items
     * @param refs the records they point at
     * @return the timeline card
     */
    public static AnswerCard timeline(String key, String title, List<Item> items, List<Ref> refs) {
        AnswerCard c = start('timeline', key, OK);
        c.title = title;
        c.items = items == null ? new List<Item>() : items;
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * Records side by side: the first column is the field, one column per record.
     * @param key the card key, 'cmp'
     * @param title the heading
     * @param columns the columns
     * @param rows one row per field
     * @param refs the records compared
     * @return the comparison card
     */
    public static AnswerCard comparison(String key, String title, List<Column> columns, List<Row> rows, List<Ref> refs) {
        AnswerCard c = start('comparison', key, OK);
        c.title = title;
        c.columns = columns == null ? new List<Column>() : columns;
        c.rows = rows == null ? new List<Row>() : rows;
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * Candidates to pick from when a name matches more than one record. Its status is AMBIGUOUS.
     * @param key the card key, 'cho'
     * @param title the question
     * @param items the candidates
     * @param refs the candidates' records
     * @return the choice card
     */
    public static AnswerCard choice(String key, String title, List<Item> items, List<Ref> refs) {
        AnswerCard c = start('choice', key, AMBIGUOUS);
        c.title = title;
        c.items = items == null ? new List<Item>() : items;
        c.refs = refs == null ? new List<Ref>() : refs;
        return finish(c);
    }

    /**
     * Questions to ask next, under 'Ask next'. No status.
     * @param key the card key, 'fol'
     * @param questions the questions
     * @return the followups card
     */
    public static AnswerCard followups(String key, List<String> questions) {
        AnswerCard c = start('followups', key, null);
        c.title = 'Ask next';
        c.items = new List<Item>();
        for (String q : questions == null ? new List<String>() : questions) {
            c.items.add(newItem(q, null, null, null));
        }
        return finish(c);
    }

    /**
     * The queries an answer ran, in order: each a plain description and its row count. No status.
     * @param key the card key, 'trl'
     * @param items one per query
     * @return the trail card, titled 'Ran N queries'
     */
    public static AnswerCard trail(String key, List<Item> items) {
        AnswerCard c = start('trail', key, null);
        c.items = items == null ? new List<Item>() : items;
        c.title = 'Ran ' + c.items.size() + (c.items.size() == 1 ? ' query' : ' queries');
        return finish(c);
    }

    /**
     * One fixed sentence, such as a cut list or no match. Literal text.
     * @param key the card key, 'not'
     * @param status OK, EMPTY, NOT_FOUND or another status word
     * @param message the sentence
     * @return the notice card
     */
    public static AnswerCard notice(String key, String status, String message) {
        AnswerCard c = start('notice', key, status);
        c.title = '';
        c.body = literalLines(message);
        return finish(c);
    }

    /**
     * The fixed message of a failure. Literal text; never the cause.
     * @param key the card key, 'err'
     * @param message the fixed user-facing message
     * @return the error card, status ERROR
     */
    public static AnswerCard error(String key, String message) {
        AnswerCard c = start('error', key, ERROR);
        c.title = '';
        c.body = literalLines(message);
        return finish(c);
    }

    // ------------------------------------------------------------------ parts

    /**
     * @param key the ref's key in its card
     * @param recordId the record's Id
     * @param objectName its object's API name
     * @param label the link's label
     * @return a ref
     */
    public static Ref newRef(String key, String recordId, String objectName, String label) {
        Ref r = new Ref();
        r.key = key;
        r.recordId = recordId;
        r.objectName = objectName;
        r.label = label;
        return r;
    }

    /**
     * @param label the item's label
     * @param value its formatted value, or null
     * @param detail its detail, or null
     * @param refKey the ref key of its record, or null
     * @return an item
     */
    public static Item newItem(String label, String value, String detail, String refKey) {
        Item i = new Item();
        i.label = label;
        i.value = value;
        i.detail = detail;
        i.ref = refKey;
        return i;
    }

    /**
     * @param key the column's key, such as a field path
     * @param label its heading
     * @param kind text, number, currency, percent or date
     * @return a column
     */
    public static Column newColumn(String key, String label, String kind) {
        Column col = new Column();
        col.key = key;
        col.label = label;
        col.kind = kind;
        return col;
    }

    /**
     * @param refKey the ref key of the row's record, or null
     * @param cells the formatted cells, in column order
     * @return a row
     */
    public static Row newRow(String refKey, List<String> cells) {
        Row r = new Row();
        r.ref = refKey;
        r.cells = cells == null ? new List<String>() : cells;
        return r;
    }

    /**
     * @param key the field's key, such as its API name
     * @param label its label
     * @param value its formatted value
     * @param refKey the ref key of the record a lookup points at, or null
     * @return a field
     */
    public static Field newField(String key, String label, String value, String refKey) {
        Field f = new Field();
        f.key = key;
        f.label = label;
        f.value = value;
        f.ref = refKey;
        return f;
    }

    /**
     * Adds a record to refs, keyed by its object's first letter and a count ('o1', 'c2'). The same record keeps its key.
     * @param refs the card's refs
     * @param recordId the record
     * @param label the link's label
     * @return the record's key, or null for no Id
     */
    public static String addRef(List<Ref> refs, Id recordId, String label) {
        if (recordId == null || refs == null) {
            return null;
        }
        String idText = String.valueOf(recordId);
        String objectName = String.valueOf(recordId.getSObjectType());
        String letter = objectName.left(1).toLowerCase();
        Integer sameLetter = 0;
        for (Ref r : refs) {
            if (r.recordId == idText) {
                return r.key;
            }
            if (r.key != null && r.key.startsWith(letter) && r.key.substring(1).isNumeric()) {
                sameLetter++;
            }
        }
        Ref added = newRef(letter + (sameLetter + 1), idText, objectName, label);
        refs.add(added);
        return added.key;
    }

    // ------------------------------------------------------------------ rich text

    /**
     * Text as blocks: each non-blank line is a paragraph ('p'); a '- ' or '• ' line a bullet ('li'); a '1. ' or '1) '
     * line a numbered item ('ol'). Inline: **bold**, *italic*, `code`, and [label](ref:key), a link only when key is in
     * refs. Anything else, HTML and other links included, is literal text.
     * @param text the text
     * @param refs the card's refs; null for none
     * @return the blocks, empty for no text
     */
    public static List<Block> parse(String text, List<Ref> refs) {
        Set<String> known = new Set<String>();
        for (Ref r : refs == null ? new List<Ref>() : refs) {
            known.add(r.key);
        }
        List<Block> blocks = new List<Block>();
        for (String raw : lines(text)) {
            String line = raw.replaceAll('\\s+$', '');
            if (String.isBlank(line)) {
                continue;
            }
            Matcher bullet = BULLET.matcher(line);
            Matcher numbered = NUMBERED.matcher(line);
            Block b = new Block();
            if (bullet.matches()) {
                b.kind = 'li';
                b.runs = inline(bullet.group(1), known);
            } else if (numbered.matches()) {
                b.kind = 'ol';
                b.runs = inline(numbered.group(2), known);
            } else {
                b.kind = 'p';
                b.runs = inline(line.trim(), known);
            }
            blocks.add(b);
        }
        return blocks;
    }

    private static List<Run> inline(String s, Set<String> known) {
        List<Run> runs = new List<Run>();
        Matcher m = INLINE.matcher(s);
        Integer last = 0;
        while (m.find()) {
            if (m.start() > last) {
                runs.add(run(s.substring(last, m.start())));
            }
            Run r;
            if (m.group(1) != null) {
                r = run(m.group(1));
                r.strong = true;
            } else if (m.group(2) != null) {
                r = run(m.group(2));
                r.em = true;
            } else if (m.group(3) != null) {
                r = run(m.group(3));
                r.code = true;
            } else {
                r = run(m.group(4));
                if (known.contains(m.group(5))) {
                    r.ref = m.group(5);
                }
            }
            runs.add(r);
            last = m.end();
        }
        if (last < s.length()) {
            runs.add(run(s.substring(last)));
        }
        return runs;
    }

    // ------------------------------------------------------------------ plain text, by type

    /**
     * The card's plain-text fallback, by its type's rule (FE-18's 'Plain text' column). An unknown type keeps its own
     * text.
     * @param c the card
     * @return its text, '' for no card
     */
    public static String plainText(AnswerCard c) {
        if (c == null) {
            return '';
        }
        List<String> out = new List<String>();
        List<Item> items = c.items == null ? new List<Item>() : c.items;
        switch on c.type {
            when 'text', 'summary', 'notice', 'error' {
                out.add(c.title);
                out.add(blocksText(c.body));
            }
            when 'section' {
                Boolean counted = (c.total != null && c.total != 0) || (c.shown != null && c.shown != 0);
                out.add(c.title + (counted ? ' (' + c.shown + ' of ' + c.total + ')' : ''));
                if (items.isEmpty()) {
                    out.add(blocksText(c.body));
                }
                for (Item i : items) {
                    out.add('- ' + itemLine(i));
                }
            }
            when 'table' {
                out.add(c.title);
                out.add(gridText(c));
                if (c.total != null && c.shown != null && c.total > c.shown) {
                    out.add('(' + c.shown + ' of ' + c.total + ' rows)');
                }
            }
            when 'comparison' {
                out.add(c.title);
                out.add(gridText(c));
            }
            when 'record', 'actionDraft', 'actionResult' {
                out.add(c.title + (String.isEmpty(c.meta) ? '' : DOT + c.meta));
                for (Field f : c.fields == null ? new List<Field>() : c.fields) {
                    out.add(fieldLine(f));
                }
                if (c.type == 'actionDraft') {
                    for (Item i : items) {
                        out.add('Note: ' + itemLine(i));
                    }
                    out.add(controlsLine(c.controls));
                } else if (c.type == 'actionResult') {
                    out.add(blocksText(c.body));
                }
            }
            when 'recordList' {
                out.add(c.title);
                for (Item i : items) {
                    out.add('- ' + itemLine(i));
                }
                if (c.total != null && c.shown != null && c.total > c.shown) {
                    out.add('(' + c.shown + ' of ' + c.total + ')');
                }
            }
            when 'choice', 'trail' {
                out.add(c.title);
                for (Integer n = 0; n < items.size(); n++) {
                    out.add((n + 1) + '. ' + itemLine(items[n]));
                }
            }
            when 'metric' {
                out.add(c.title);
                for (Item i : items) {
                    out.add(itemLine(i));
                }
            }
            when 'timeline' {
                out.add(c.title);
                for (Item i : items) {
                    out.add(i.at + DOT + itemLine(i));
                }
            }
            when 'followups' {
                out.add(c.title);
                for (Item i : items) {
                    out.add('- ' + i.label);
                }
            }
            when else {
                return c.text;
            }
        }
        return joinLines(out);
    }

    private static String blocksText(List<Block> blocks) {
        List<String> out = new List<String>();
        Integer n = 0;
        for (Block b : blocks == null ? new List<Block>() : blocks) {
            String t = runsText(b.runs);
            if (b.kind == 'li') {
                n = 0;
                out.add('- ' + t);
            } else if (b.kind == 'ol') {
                n++;
                out.add(n + '. ' + t);
            } else {
                n = 0;
                out.add(t);
            }
        }
        return joinLines(out);
    }

    private static String runsText(List<Run> runs) {
        String t = '';
        for (Run r : runs == null ? new List<Run>() : runs) {
            t += r.text == null ? '' : r.text;
        }
        return t;
    }

    private static String itemLine(Item i) {
        return (i.label == null ? '' : i.label)
            + (String.isEmpty(i.value) ? '' : ': ' + i.value)
            + (String.isEmpty(i.detail) ? '' : SEP + i.detail);
    }

    private static String fieldLine(Field f) {
        String value = f.value == null ? '' : f.value;
        if (f.state == 'missing' && value == '') {
            value = '(needed)';
        } else if (f.state == 'choose') {
            value = (value == '' ? '' : value + ' ') + '(choose one)';
        }
        return f.label + ': ' + value;
    }

    private static String controlsLine(List<Control> controls) {
        if (controls == null || controls.isEmpty()) {
            return null;
        }
        List<String> labels = new List<String>();
        for (Control k : controls) {
            labels.add(k.label);
        }
        return 'Options: ' + String.join(labels, ', ');
    }

    private static String gridText(AnswerCard c) {
        List<String> out = new List<String>();
        List<String> heads = new List<String>();
        for (Column col : c.columns == null ? new List<Column>() : c.columns) {
            heads.add(col.label == null ? '' : col.label);
        }
        out.add(String.join(heads, ' | '));
        for (Row r : c.rows == null ? new List<Row>() : c.rows) {
            List<String> cells = new List<String>();
            for (String cell : r.cells == null ? new List<String>() : r.cells) {
                cells.add(cell == null ? '' : cell);
            }
            out.add(String.join(cells, ' | '));
        }
        return joinLines(out);
    }

    private static String joinLines(List<String> parts) {
        List<String> kept = new List<String>();
        for (String p : parts) {
            if (String.isNotEmpty(p)) {
                kept.add(p);
            }
        }
        return String.join(kept, '\n');
    }

    // ------------------------------------------------------------------ JSON

    /**
     * The cards as JSON, nulls left out, for an invocable's cards output.
     * @param cards the cards
     * @return the JSON; '[]' for no cards; '' when it would be longer than the cap (never cut JSON)
     */
    public static String toJson(List<AnswerCard> cards) {
        String cardJson = JSON.serialize(cards == null ? new List<AnswerCard>() : cards, true);
        return cardJson.length() > maxJsonChars ? '' : cardJson;
    }

    /**
     * Cards back from toJson's JSON.
     * @param json the JSON
     * @return the cards; empty for blank or unreadable JSON, never an exception
     */
    public static List<AnswerCard> fromJson(String cardJson) {
        if (String.isBlank(cardJson)) {
            return new List<AnswerCard>();
        }
        try {
            List<AnswerCard> cards = (List<AnswerCard>) JSON.deserialize(cardJson, List<AnswerCard>.class);
            return cards == null ? new List<AnswerCard>() : cards;
        } catch (JSONException e) {
            return new List<AnswerCard>();
        } catch (TypeException e) {
            return new List<AnswerCard>();
        }
    }

    // ------------------------------------------------------------------ helpers

    private static AnswerCard start(String type, String key, String status) {
        AnswerCard c = new AnswerCard();
        c.type = type;
        c.key = key;
        c.status = status;
        return c;
    }

    private static AnswerCard finish(AnswerCard c) {
        c.text = plainText(c);
        return c;
    }

    private static List<String> lines(String text) {
        return String.isEmpty(text) ? new List<String>() : text.replace('\r\n', '\n').split('\n');
    }

    private static Run run(String text) {
        Run r = new Run();
        r.text = text;
        return r;
    }

    /** A line as one literal run: a bullet ('li'), a numbered item ('ol') or a paragraph ('p'); never markup. */
    private static Block literal(String line) {
        Block b = new Block();
        Matcher bullet = BULLET.matcher(line);
        Matcher numbered = NUMBERED.matcher(line);
        if (bullet.matches()) {
            b.kind = 'li';
            b.runs.add(run(bullet.group(1).trim()));
        } else if (numbered.matches()) {
            b.kind = 'ol';
            b.runs.add(run(numbered.group(2).trim()));
        } else {
            b.kind = 'p';
            b.runs.add(run(line.trim()));
        }
        return b;
    }

    private static List<Block> literalLines(String text) {
        List<Block> blocks = new List<Block>();
        for (String line : lines(text)) {
            if (String.isNotBlank(line)) {
                blocks.add(literal(line));
            }
        }
        return blocks;
    }

    private static Id toId(String candidate) {
        try {
            Id recordId = Id.valueOf(candidate);
            return recordId.getSObjectType() == null ? null : recordId;
        } catch (StringException e) {
            return null; // not an Id: the line stays text
        } catch (SObjectException e) {
            return null; // an Id of no object this org knows
        }
    }
}
