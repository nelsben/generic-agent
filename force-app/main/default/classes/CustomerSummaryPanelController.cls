/**
 * CustomerSummaryPanelController: the customerSummaryPanel LWC's only Apex door.
 *
 * One engine, two front ends: every method delegates to the same classes the agent's actions
 * call (CustomerSummaryResolver, CustomerSummary, CustomerSummaryMemory, DataExplorer). Nothing here
 * calls a model, writes prose or adds visibility: it runs with sharing and passes through.
 * getBrief and explore return each result's cards member (BE-39, AnswerCard) as the engine built it.
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
        } catch (DataExplorer.ExploreException e) {
            throw handled(e.getMessage());
        } catch (Exception e) {
            throw unexpected('drill', e);
        }
        return d;
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
