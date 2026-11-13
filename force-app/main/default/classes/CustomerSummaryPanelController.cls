/**
 * CustomerSummaryPanelController: the customerSummaryPanel LWC's only Apex door.
 *
 * One engine, two front ends: every method delegates to the same classes the agent's actions
 * call (CustomerSummaryResolver, CustomerSummary, CustomerSummaryMemory, DataExplorer). Nothing here
 * calls a model, writes prose or adds visibility: it runs with sharing and passes through.
 * getBrief and explore return each result's cards member (BE-39, AnswerCard) as the engine built it.
 * drill adds its own cards member (BE-46): a record card for one record, the explorer's card for related rows.
 * explore also keeps the explorer's turn in the rep's conversation history (BE-26): an OK or EMPTY answer about
 * an Account is saved through CustomerSummaryMemory after the engine's last callout, as the brief's turns are.
 * Engine failures that carry user-facing text come back as AuraHandledException with that text.
 * Anything unexpected is logged and comes back as AuraHandledException with ERROR_TEXT, the fixed
 * line the engine uses for ERROR: raw exception text never reaches the panel.
 */
public with sharing class CustomerSummaryPanelController {
    /** Matches DataExplorer's fixed ERROR text (docs/ARCHITECTURE.md: ERROR carries fixed user-facing text). */
    @TestVisible private static final String ERROR_TEXT = 'I couldn\'t finish that right now. Try again in a minute.';
    /** Test seam: when set, every @AuraEnabled call below throws it before delegating. */
    @TestVisible private static Exception failure;

    /** A drill-down: the rows drill() returned and, for a single record, the catalog objects that look up to it. */
    public class Drill {
        @AuraEnabled public ExploreQuery.ResultSet result;
        /** Catalog objects with a lookup to the record, in catalog order. Empty for a related-rows drill. */
        @AuraEnabled public List<String> related = new List<String>();
        /**
         * The same drill as cards (BE-46), built from the rows above with no new query: a record card for a single
         * record, or the table or recordList card the explorer draws for the same result set for a related-rows drill.
         * Empty when the drill found no rows, or when building the card failed. Record Ids are only in refs.
         */
        @AuraEnabled public List<AnswerCard> cards = new List<AnswerCard>();
    }

    /** Words or the open record to one Account: CustomerSummaryResolver.resolve. */
    @AuraEnabled
    public static CustomerSummaryResolver.Response resolve(String accountName, String recordId) {
        try {
            failIfInjected();
            return CustomerSummaryResolver.resolve(accountName, recordId);
        } catch (Exception e) {
            throw unexpected('resolve', e);
        }
    }

    /** The brief: CustomerSummary.run. include null or empty means every source. Not cacheable: it calls out, then writes memory. */
    @AuraEnabled
    public static CustomerSummary.Result getBrief(Id accountId, String question, List<String> include) {
        try {
            failIfInjected();
            return CustomerSummary.run(accountId, question, include == null ? null : new Set<String>(include));
        } catch (Exception e) {
            throw unexpected('getBrief', e);
        }
    }

    /** Ask anything: DataExplorer.explore, then the turn is remembered. Not cacheable: it calls out, then writes memory. */
    @AuraEnabled
    public static DataExplorer.Result explore(String question, Id contextRecordId, String historyJson) {
        DataExplorer.Result r;
        try {
            failIfInjected();
            r = DataExplorer.explore(question, contextRecordId, historyJson);
        } catch (Exception e) {
            throw unexpected('explore', e);
        }
        rememberExplorerTurn(question, contextRecordId, r);
        return r;
    }

    /**
     * Saves an explorer turn to the session for its account, last, after every callout. Only an OK or EMPTY answer
     * about an Account is kept, as with the brief. A failed write is logged and the answer still returns.
     */
    private static void rememberExplorerTurn(String question, Id contextRecordId, DataExplorer.Result r) {
        if (r == null || contextRecordId == null || contextRecordId.getSObjectType() != Account.SObjectType
                || (r.status != DataExplorer.OK && r.status != DataExplorer.EMPTY)) {
            return;
        }
        try {
            CustomerSummaryMemory.recordAll(new List<CustomerSummaryMemory.Entry>{
                new CustomerSummaryMemory.Entry(contextRecordId, r.status, question, r.answer, CustomerSummaryMemory.KIND_EXPLORER)
            });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerSummaryMemory.recordAll failed for an explorer turn: '
                + e.getTypeName() + ': ' + e.getMessage());
        }
    }

    /**
     * Drill-down without the model: DataExplorer.drill, plus the related objects for a record drill.
     * ExploreException text is the engine's own fixed plain-English line, so it passes through;
     * QueryException, NoAccessException and anything else get ERROR_TEXT.
     */
    @AuraEnabled
    public static Drill drill(Id recordId, String relatedObject) {
        Drill d = new Drill();
        try {
            failIfInjected();
            d.result = DataExplorer.drill(recordId, relatedObject);
            if (String.isBlank(relatedObject)) {
                d.related = relatedObjects(recordId.getSObjectType().getDescribe().getName());
            }
            d.cards = drillCards(d.result, String.isBlank(relatedObject), d.related);
        } catch (DataExplorer.ExploreException e) {
            throw handled(e.getMessage());
        } catch (Exception e) {
            throw unexpected('drill', e);
        }
        return d;
    }

    /**
     * The drill's rows as one card, from data the drill already holds. Never throws: a failure is logged and
     * leaves no card, because the rows the panel draws today do not depend on it.
     */
    @TestVisible
    private static List<AnswerCard> drillCards(ExploreQuery.ResultSet rs, Boolean singleRecord, List<String> related) {
        List<AnswerCard> out = new List<AnswerCard>();
        try {
            if (rs == null || rs.rows.isEmpty()) {
                return out;
            }
            // The explorer's own builder draws the rows (formatted cells, refs), so a drill and an explorer answer agree.
            DataExplorer.Result asExplored = new DataExplorer.Result();
            asExplored.status = DataExplorer.OK;
            asExplored.answer = '';
            asExplored.resultSets.add(rs);
            List<AnswerCard> drawn = DataExplorer.cards(asExplored, rs.rows.size());
            if (drawn.size() < 2) {
                return out;
            }
            out.add(singleRecord ? recordCard(rs, drawn[1], related) : drawn[1]);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerSummaryPanelController drill cards not built: '
                + e.getTypeName() + ': ' + e.getMessage());
            return new List<AnswerCard>();
        }
        return out;
    }

    /**
     * One record as a record card: the object's name field is the title, the object's label the meta, each other shown
     * column a field (blank values left out), each lookup's record in refs, and each related object a related item.
     * grid is the explorer's table (or recordList) card for the same one-row result set, which holds the formatted cells.
     */
    private static AnswerCard recordCard(ExploreQuery.ResultSet rs, AnswerCard grid, List<String> related) {
        ExploreCatalog.Entry entry = ExploreCatalog.find(rs.objectName);
        Map<String, Object> row = rs.rows[0];
        Map<String, Schema.SObjectField> described = Schema.getGlobalDescribe().get(rs.objectName).getDescribe().fields.getMap();
        ExploreCatalog.Field nameField;
        Map<String, Id> lookupIds = new Map<String, Id>();
        for (ExploreCatalog.Field f : entry == null ? new List<ExploreCatalog.Field>() : entry.fields) {
            if (f.path.contains('.') || f.path == 'Id') {
                continue;
            }
            Schema.SObjectField sf = described.get(f.path.toLowerCase());
            if (nameField == null && sf != null && sf.getDescribe().isNameField()) {
                nameField = f;
            }
            Object raw = row.get(f.path);
            if (f.kind == ExploreCatalog.KIND_ID && raw != null) {
                try {
                    // A lookup's Id field is labelled 'Account ID'; the column that shows its record is 'Account'.
                    lookupIds.put(f.label.removeEnd(' ID'), Id.valueOf(String.valueOf(raw)));
                } catch (Exception e) {
                    // not an Id: the field stays text
                }
            }
        }
        String objectLabel = entry == null ? rs.objectName : entry.label;
        Object named = nameField == null ? null : row.get(nameField.path);
        String title = named == null || String.isBlank(String.valueOf(named)) ? objectLabel : String.valueOf(named);

        List<AnswerCard.Ref> refs = new List<AnswerCard.Ref>();
        List<AnswerCard.Field> fields = new List<AnswerCard.Field>();
        Boolean grid2 = grid.type == 'table';
        List<String> heads = DataExplorer.headers(rs);
        for (Integer i = 0; i < rs.columns.size(); i++) {
            String label = grid2 ? grid.columns[i].label : heads[i];
            String value = grid2 ? grid.rows[0].cells[i] : (row.get(rs.columns[i]) == null ? '' : String.valueOf(row.get(rs.columns[i])));
            if (String.isBlank(value) || (nameField != null && label == nameField.label)) {
                continue;
            }
            Id target = lookupIds.get(label);
            fields.add(AnswerCard.newField(rs.columns[i], label, value, target == null ? null : AnswerCard.addRef(refs, target, value)));
        }

        List<String> relatedLabels = new List<String>();
        Map<String, Schema.SObjectType> types = Schema.getGlobalDescribe();
        for (String name : related == null ? new List<String>() : related) {
            Schema.SObjectType t = types.get(name);
            relatedLabels.add(t == null ? name : t.getDescribe().getLabelPlural());
        }
        return AnswerCard.record('rec', title, objectLabel, fields, relatedLabels, refs);
    }

    /** The current user's earlier briefs of the account, newest first, while the account is readable: CustomerSummaryMemory.history. */
    @AuraEnabled
    public static List<CustomerSummaryMemory.Turn> history(Id accountId) {
        try {
            failIfInjected();
            return CustomerSummaryMemory.history(accountId);
        } catch (Exception e) {
            throw unexpected('history', e);
        }
    }

    /** The brief's sources, keys and titles in registry order: CustomerSummary.sources. */
    @AuraEnabled(cacheable=true)
    public static List<CustomerSummary.SourceInfo> sources() {
        try {
            failIfInjected();
            return CustomerSummary.sources();
        } catch (Exception e) {
            throw unexpected('sources', e);
        }
    }

    /** Catalog objects with a filterable direct lookup to parentName: the objects drill(recordId, x) accepts. */
    @TestVisible
    private static List<String> relatedObjects(String parentName) {
        List<String> out = new List<String>();
        for (ExploreCatalog.Entry e : ExploreCatalog.entries()) {
            for (ExploreCatalog.Field f : e.fields) {
                if (f.path != 'Id' && !f.path.contains('.') && f.kind == ExploreCatalog.KIND_ID
                        && f.filterable && f.referenceTo.contains(parentName)) {
                    out.add(e.name);
                    break;
                }
            }
        }
        return out;
    }

    private static void failIfInjected() {
        if (failure != null) {
            throw failure;
        }
    }

    /** Logs the detail for the admin and hands the panel the fixed line. */
    private static AuraHandledException unexpected(String method, Exception e) {
        System.debug(LoggingLevel.ERROR, 'CustomerSummaryPanelController.' + method + ': '
            + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
        return handled(ERROR_TEXT);
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
