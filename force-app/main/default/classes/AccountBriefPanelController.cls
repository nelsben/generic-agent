/**
 * AccountBriefPanelController: the accountBriefPanel LWC's only Apex door.
 *
 * One engine, two front ends: every method delegates to the same classes the agent's actions
 * call (AccountBriefResolver, AccountBrief, AccountBriefMemory, DataExplorer). Nothing here
 * calls a model, writes prose or adds visibility: it runs with sharing and passes through.
 * Engine failures that carry user-facing text come back as AuraHandledException with that text.
 * Anything unexpected is logged and comes back as AuraHandledException with ERROR_TEXT, the fixed
 * line the engine uses for ERROR: raw exception text never reaches the panel.
 */
public with sharing class AccountBriefPanelController {
    @TestVisible private static final String AGENT_DEVELOPER_NAME = 'Account_Brief';
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

    /** Words or the open record to one Account: AccountBriefResolver.resolve. */
    @AuraEnabled
    public static AccountBriefResolver.Response resolve(String accountName, String recordId) {
        try {
            failIfInjected();
            return AccountBriefResolver.resolve(accountName, recordId);
        } catch (Exception e) {
            throw unexpected('resolve', e);
        }
    }

    /** The brief: AccountBrief.run. include null or empty means every source. Not cacheable: it calls out, then writes memory. */
    @AuraEnabled
    public static AccountBrief.Result getBrief(Id accountId, String question, List<String> include) {
        try {
            failIfInjected();
            return AccountBrief.run(accountId, question, include == null ? null : new Set<String>(include));
        } catch (Exception e) {
            throw unexpected('getBrief', e);
        }
    }

    /** Ask anything: DataExplorer.explore. Not cacheable: it calls out. */
    @AuraEnabled
    public static DataExplorer.Result explore(String question, Id contextRecordId, String historyJson) {
        try {
            failIfInjected();
            return DataExplorer.explore(question, contextRecordId, historyJson);
        } catch (Exception e) {
            throw unexpected('explore', e);
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

    /** The current user's earlier briefs of the account, newest first: AccountBriefMemory.history. */
    @AuraEnabled
    public static List<AccountBriefMemory.Turn> history(Id accountId) {
        try {
            failIfInjected();
            return AccountBriefMemory.history(accountId);
        } catch (Exception e) {
            throw unexpected('history', e);
        }
    }

    /** The brief's sources, keys and titles in registry order: AccountBrief.sources. */
    @AuraEnabled(cacheable=true)
    public static List<AccountBrief.SourceInfo> sources() {
        try {
            failIfInjected();
            return AccountBrief.sources();
        } catch (Exception e) {
            throw unexpected('sources', e);
        }
    }

    /** The BotDefinition Id of the Account_Brief agent, or null when the org has none or the user can't see it. */
    @AuraEnabled(cacheable=true)
    public static String agentId() {
        String developerName = AGENT_DEVELOPER_NAME;
        try {
            List<SObject> rows = Database.query(
                'SELECT Id FROM BotDefinition WHERE DeveloperName = :developerName LIMIT 1');
            return rows.isEmpty() ? null : String.valueOf(rows[0].Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'AccountBriefPanelController.agentId: ' + e.getMessage());
            return null;
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
        System.debug(LoggingLevel.ERROR, 'AccountBriefPanelController.' + method + ': '
            + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
        return handled(ERROR_TEXT);
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
