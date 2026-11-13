/**
 * CustomerOutcomes: the one store for what the agent produced for an account (FR2). A summary, an action taken,
 * a saved answer: each is a Customer_Outcome__c row under its account, typed by a Customer_Outcome_Type__mdt record
 * that sets how long it is kept and whether its text is shared.
 *
 * Sharing follows the account (master-detail, writeRequiresMasterRead): a rep who can read the account can add an
 * outcome to it and see the outcomes on it. What a rep sees of someone else's outcome is decided in one place,
 * view() below (F79). Reps hold no field access to the title, headline, body and sentiment reason, so those four
 * are written and read here in system context, and only ever shown through view(). Everything else is user mode.
 *
 * Writes are made after every model call (a callout after uncommitted DML fails). record() and recordAll() throw on
 * a bad input or a refused write and leave nothing behind; callers that must not fail catch and log.
 */
public with sharing class CustomerOutcomes {
    public static final String SUMMARY = 'Summary';
    public static final String ACTION = 'Action';
    public static final String SAVED_ANSWER = 'Saved_Answer';

    public static final String NOT_FOUND_TEXT = 'That outcome is not there, or you can\'t see its account.';
    public static final String NOT_YOURS_TEXT = 'Only the person who saved an outcome can remove it.';
    /** The first line of the outcome context a model sees. */
    public static final String CONTEXT_HEADER = 'Earlier outcomes on this account, newest first (yours with their headline, others by type and date only):';
    /** Non-summary outcomes in the context, after the last summary. */
    public static final Integer CONTEXT_ITEMS = 3;
    /** The context never runs past this many characters. */
    public static final Integer CONTEXT_CHARS = 900;
    private static final Integer CONTEXT_LINE_CHARS = 160;
    private static final Integer LIST_DEFAULT = 20;
    private static final Integer LIST_MAX = 200;
    private static final Integer TEXT_MAX = 255;
    private static final Integer BODY_MAX = 32768;

    /** The fixed phrase another rep sees for each kind of action, by skill. */
    private static final Map<String, String> ACTION_PHRASES = new Map<String, String>{
        'create_task' => 'Task created',
        'create_event' => 'Event created',
        'log_call' => 'Call logged',
        'update_contact' => 'Contact updated',
        'create_case' => 'Case created',
        'update_opportunity' => 'Opportunity updated'
    };
    private static final String ACTION_PHRASE_DEFAULT = 'Action taken';

    @TestVisible private static Map<String, Customer_Outcome_Type__mdt> typesForTest;
    /** Makes recordAll throw before any DML, for the callers' failure paths. */
    @TestVisible private static Boolean failWritesForTest = false;

    public class OutcomeException extends Exception {}

    /** One outcome to record. type is a type's DeveloperName or label. Text is clipped to its field's length. */
    public class Input {
        public Id accountId;
        public String type;
        public String title;
        /** Defaults to the body's first line. */
        public String headline;
        public String body;
        public String relatedRecordId;
        public String skill;
        /** Defaults to where the request came from: panel, action, api, script or test. */
        public String surface;
        public String model;
        /** Set with a summary (BE-36). Never taken from the invocable. */
        public Decimal sentimentScore;
        public String sentimentLabel;
        public String sentimentReason;

        public Input(Id accountId, String type) {
            this.accountId = accountId;
            this.type = type;
        }
    }

    /** One outcome as the running user may see it. For anyone but the author, text fields are null (F79). */
    public class Outcome {
        @AuraEnabled public Id id;
        @AuraEnabled public Id accountId;
        /** The type's DeveloperName. */
        @AuraEnabled public String type;
        @AuraEnabled public String typeLabel;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Date expires;
        /** True when the running user wrote it. */
        @AuraEnabled public Boolean mine = false;
        /** True when the text below is the outcome's own; false when it is withheld. */
        @AuraEnabled public Boolean textShown = false;
        /** The outcome's title, or a fixed phrase for its kind when the text is withheld. */
        @AuraEnabled public String title;
        @AuraEnabled public String headline;
        /** Only from getOutcome; a list carries no body. */
        @AuraEnabled public String body;
        @AuraEnabled public String relatedRecordId;
        @AuraEnabled public String skill;
        @AuraEnabled public String surface;
        @AuraEnabled public String model;
        @AuraEnabled public Decimal sentimentScore;
        @AuraEnabled public String sentimentLabel;
        @AuraEnabled public String sentimentReason;
    }

    // ------------------------------------------------------------------ types

    /** The outcome types by DeveloperName. Custom metadata, read without a query. */
    public static Map<String, Customer_Outcome_Type__mdt> types() {
        return typesForTest != null ? typesForTest : Customer_Outcome_Type__mdt.getAll();
    }

    /** The type named by DeveloperName or label, ignoring case, or null. */
    private static Customer_Outcome_Type__mdt resolveType(String name, Map<String, Customer_Outcome_Type__mdt> all) {
        if (String.isBlank(name)) {
            return null;
        }
        String wanted = name.trim();
        for (Customer_Outcome_Type__mdt t : all.values()) {
            if (wanted.equalsIgnoreCase(t.DeveloperName) || wanted.equalsIgnoreCase(t.MasterLabel)
                    || wanted.replace(' ', '_').equalsIgnoreCase(t.DeveloperName)) {
                return t;
            }
        }
        return null;
    }

    /** The expiry for an outcome of type t written today: blank retention means kept forever (null). */
    private static Date expiryFor(Customer_Outcome_Type__mdt t) {
        return t.Retention_Days__c == null ? null : Date.today().addDays(t.Retention_Days__c.intValue());
    }

    // ------------------------------------------------------------------ writing

    /** Records one outcome as the running user. Returns its Id. */
    public static Id record(Input input) {
        return recordAll(new List<Input>{ input })[0];
    }

    /**
     * Records outcomes as the running user, all or none, Ids in input order. The row is inserted in user mode,
     * so the platform refuses it when the user cannot read the account or lacks the outcome permission set;
     * the four text fields are then set in system context. Throws OutcomeException on a bad input.
     */
    public static List<Id> recordAll(List<Input> inputs) {
        List<Id> ids = new List<Id>();
        if (inputs == null || inputs.isEmpty()) {
            return ids;
        }
        Map<String, Customer_Outcome_Type__mdt> all = types();
        String surface = currentSurface();
        List<Customer_Outcome__c> rows = new List<Customer_Outcome__c>();
        for (Input i : inputs) {
            if (i == null || i.accountId == null || i.accountId.getSObjectType() != Account.SObjectType) {
                throw new OutcomeException('An outcome needs an account.');
            }
            Customer_Outcome_Type__mdt t = resolveType(i.type, all);
            if (t == null) {
                throw new OutcomeException('Unknown outcome type: ' + i.type + '.');
            }
            rows.add(new Customer_Outcome__c(
                Account__c = i.accountId,
                Outcome_Type__c = t.DeveloperName,
                Related_Record_Id__c = clip(i.relatedRecordId, 18),
                Skill__c = clip(i.skill, 80),
                Surface__c = clip(String.isBlank(i.surface) ? surface : i.surface, 40),
                Model__c = clip(i.model, 120),
                Sentiment_Score__c = i.sentimentScore,
                Sentiment_Label__c = clip(i.sentimentLabel, 40),
                Expires__c = expiryFor(t)
            ));
        }
        if (failWritesForTest) {
            throw new OutcomeException('Outcome writes are switched off for this test.');
        }
        Savepoint sp = Database.setSavepoint();
        try {
            Database.insert(rows, true, AccessLevel.USER_MODE);
            writeText(rows, inputs);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        for (Customer_Outcome__c row : rows) {
            ids.add(row.Id);
        }
        return ids;
    }

    // system-context: reps hold no field access to outcome text (F79); set only on rows just inserted as this user
    private static void writeText(List<Customer_Outcome__c> rows, List<Input> inputs) {
        List<Customer_Outcome__c> texts = new List<Customer_Outcome__c>();
        for (Integer n = 0; n < rows.size(); n++) {
            Input i = inputs[n];
            String headline = String.isNotBlank(i.headline) ? i.headline : firstLine(i.body);
            if (String.isBlank(i.title) && String.isBlank(headline) && String.isBlank(i.body) && String.isBlank(i.sentimentReason)) {
                continue;
            }
            texts.add(new Customer_Outcome__c(
                Id = rows[n].Id,
                Title__c = clip(i.title, TEXT_MAX),
                Headline__c = clip(headline, TEXT_MAX),
                Body__c = clip(i.body, BODY_MAX),
                Sentiment_Reason__c = clip(i.sentimentReason, TEXT_MAX)
            ));
        }
        if (!texts.isEmpty()) {
            Database.update(texts, true, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * Deletes one outcome. Only its author may: anyone else gets NOT_YOURS_TEXT, and an outcome the user cannot
     * see gets NOT_FOUND_TEXT. Reps hold no delete permission, so the delete itself runs in system context.
     */
    public static void remove(Id outcomeId) {
        List<Customer_Outcome__c> rows = new List<Customer_Outcome__c>();
        if (outcomeId != null && outcomeId.getSObjectType() == Customer_Outcome__c.SObjectType
                && Schema.SObjectType.Customer_Outcome__c.isAccessible()) {
            rows = [SELECT Id, CreatedById FROM Customer_Outcome__c WHERE Id = :outcomeId WITH USER_MODE LIMIT 1];
        }
        if (rows.isEmpty()) {
            throw new OutcomeException(NOT_FOUND_TEXT);
        }
        if (rows[0].CreatedById != UserInfo.getUserId()) {
            throw new OutcomeException(NOT_YOURS_TEXT);
        }
        deleteOwn(rows[0]);
    }

    // system-context: reps hold no delete on outcomes; the caller has already checked the user is the author
    private static void deleteOwn(Customer_Outcome__c row) {
        Database.delete(row, true, AccessLevel.SYSTEM_MODE);
    }

    // ------------------------------------------------------------------ reading

    /**
     * The outcomes on an account the user can see, newest first, without bodies. types filters by DeveloperName
     * or label (null or empty for all); limitSize defaults to 20 and is capped at 200. Never throws.
     */
    @AuraEnabled(cacheable=true)
    public static List<Outcome> listOutcomes(Id accountId, List<String> types, Integer limitSize) {
        Integer lim = limitSize == null || limitSize <= 0 ? LIST_DEFAULT : Math.min(limitSize, LIST_MAX);
        try {
            if (!canRead() || !accountVisible(accountId)) {
                return new List<Outcome>();
            }
            Set<String> wanted = typeNames(types);
            List<Customer_Outcome__c> rows = wanted.isEmpty()
                ? [
                    SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c, Skill__c, Surface__c, Model__c,
                        Sentiment_Score__c, Sentiment_Label__c, Expires__c, CreatedById, CreatedDate
                    FROM Customer_Outcome__c WHERE Account__c = :accountId
                    WITH USER_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT :lim
                ]
                : [
                    SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c, Skill__c, Surface__c, Model__c,
                        Sentiment_Score__c, Sentiment_Label__c, Expires__c, CreatedById, CreatedDate
                    FROM Customer_Outcome__c WHERE Account__c = :accountId AND Outcome_Type__c IN :wanted
                    WITH USER_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT :lim
                ];
            return views(rows, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerOutcomes.listOutcomes failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return new List<Outcome>();
        }
    }

    /** One outcome with its body when the user may read it, or null when it is not there or not visible. */
    @AuraEnabled
    public static Outcome getOutcome(Id outcomeId) {
        try {
            if (outcomeId == null || outcomeId.getSObjectType() != Customer_Outcome__c.SObjectType || !canRead()) {
                return null;
            }
            List<Customer_Outcome__c> rows = [
                SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c, Skill__c, Surface__c, Model__c,
                    Sentiment_Score__c, Sentiment_Label__c, Expires__c, CreatedById, CreatedDate
                FROM Customer_Outcome__c WHERE Id = :outcomeId WITH USER_MODE LIMIT 1
            ];
            if (rows.isEmpty() || !accountVisible(rows[0].Account__c)) {
                return null;
            }
            return views(rows, true)[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerOutcomes.getOutcome failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return null;
        }
    }

    /**
     * The outcome context for a model, or '' when there is nothing the user may see: CONTEXT_HEADER, the last
     * summary, then up to CONTEXT_ITEMS other outcomes, one line each, under CONTEXT_CHARS. The user's own outcomes
     * (and types that share their text) carry their headline; anyone else's carry only type and date. Never throws.
     */
    public static String contextFor(Id accountId) {
        try {
            return canRead() && accountVisible(accountId) ? context(accountId) : '';
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerOutcomes.contextFor failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return '';
        }
    }

    /** As contextFor, for a caller that has just read the account in user mode itself: one query fewer. */
    public static String contextForVisibleAccount(Id accountId) {
        try {
            return canRead() && accountId != null && accountId.getSObjectType() == Account.SObjectType ? context(accountId) : '';
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerOutcomes context failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return '';
        }
    }

    private static String context(Id accountId) {
        List<String> summaryType = new List<String>{ SUMMARY };
        List<Customer_Outcome__c> rows = [
            SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c, Skill__c, Surface__c, Model__c,
                Sentiment_Score__c, Sentiment_Label__c, Expires__c, CreatedById, CreatedDate
            FROM Customer_Outcome__c WHERE Account__c = :accountId AND Outcome_Type__c IN :summaryType
            WITH USER_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1
        ];
        Integer others = CONTEXT_ITEMS;
        rows.addAll([
            SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c, Skill__c, Surface__c, Model__c,
                Sentiment_Score__c, Sentiment_Label__c, Expires__c, CreatedById, CreatedDate
            FROM Customer_Outcome__c WHERE Account__c = :accountId AND Outcome_Type__c NOT IN :summaryType
            WITH USER_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT :others
        ]);
        if (rows.isEmpty()) {
            return '';
        }
        List<String> lines = new List<String>{ CONTEXT_HEADER };
        for (Outcome o : views(rows, false)) {
            String line = '- ' + o.typeLabel + ', ' + o.createdDate.format('yyyy-MM-dd');
            String text = o.textShown ? (String.isNotBlank(o.headline) ? o.headline : o.title) : null;
            if (String.isNotBlank(text)) {
                line += ': ' + text.replaceAll('\\s+', ' ').trim();
            }
            lines.add(clip(line, CONTEXT_LINE_CHARS));
        }
        return clip(String.join(lines, '\n'), CONTEXT_CHARS);
    }

    // ------------------------------------------------------------------ what others see (F79)

    /**
     * F79 / F87, the one rule for what a person sees of an outcome. The author, or anyone when the outcome's type
     * shares its text, sees all of it. Anyone else who can see the account sees only the type, the date, a fixed
     * phrase for the kind of outcome (never its title) and the sentiment label: never the title, headline, body,
     * record link, sentiment reason, skill, surface or model. Every read in this class goes through here.
     */
    private static Outcome view(Customer_Outcome__c row, Customer_Outcome__c text, Boolean withBody, Map<String, Customer_Outcome_Type__mdt> all) {
        Customer_Outcome_Type__mdt t = all.get(row.Outcome_Type__c);
        Outcome o = new Outcome();
        o.id = row.Id;
        o.accountId = row.Account__c;
        o.type = row.Outcome_Type__c;
        o.typeLabel = t == null ? row.Outcome_Type__c : t.MasterLabel;
        o.createdDate = row.CreatedDate;
        o.expires = row.Expires__c;
        o.sentimentLabel = row.Sentiment_Label__c;
        o.mine = row.CreatedById == UserInfo.getUserId();
        o.textShown = showsText(row, all);
        if (!o.textShown) {
            o.title = phrase(row, t);
            return o;
        }
        o.title = text == null || String.isBlank(text.Title__c) ? phrase(row, t) : text.Title__c;
        o.headline = text?.Headline__c;
        o.body = withBody ? text?.Body__c : null;
        o.sentimentReason = text?.Sentiment_Reason__c;
        o.relatedRecordId = row.Related_Record_Id__c;
        o.skill = row.Skill__c;
        o.surface = row.Surface__c;
        o.model = row.Model__c;
        o.sentimentScore = row.Sentiment_Score__c;
        return o;
    }

    /** F79: the text is shown to its author, or to anyone when its type is marked to share it. */
    private static Boolean showsText(Customer_Outcome__c row, Map<String, Customer_Outcome_Type__mdt> all) {
        Customer_Outcome_Type__mdt t = all.get(row.Outcome_Type__c);
        return row.CreatedById == UserInfo.getUserId() || (t != null && t.Share_Text__c == true);
    }

    /** The fixed phrase for an outcome's kind: never its own text. */
    private static String phrase(Customer_Outcome__c row, Customer_Outcome_Type__mdt t) {
        if (row.Outcome_Type__c == ACTION) {
            String p = String.isBlank(row.Skill__c) ? null : ACTION_PHRASES.get(row.Skill__c.trim().toLowerCase());
            return p == null ? ACTION_PHRASE_DEFAULT : p;
        }
        return t == null ? row.Outcome_Type__c : t.MasterLabel;
    }

    /** The rows as views, reading the text fields only for the rows whose text the user may see. */
    private static List<Outcome> views(List<Customer_Outcome__c> rows, Boolean withBody) {
        Map<String, Customer_Outcome_Type__mdt> all = types();
        Set<Id> readable = new Set<Id>();
        for (Customer_Outcome__c row : rows) {
            if (showsText(row, all)) {
                readable.add(row.Id);
            }
        }
        Map<Id, Customer_Outcome__c> text = readable.isEmpty() ? new Map<Id, Customer_Outcome__c>() : readText(readable, withBody);
        List<Outcome> out = new List<Outcome>();
        for (Customer_Outcome__c row : rows) {
            out.add(view(row, text.get(row.Id), withBody, all));
        }
        return out;
    }

    // system-context: reps hold no field access to outcome text (F79); read only for rows view() shows in full
    private static Map<Id, Customer_Outcome__c> readText(Set<Id> ids, Boolean withBody) {
        if (withBody) {
            return new Map<Id, Customer_Outcome__c>([
                SELECT Id, Title__c, Headline__c, Body__c, Sentiment_Reason__c FROM Customer_Outcome__c WHERE Id IN :ids WITH SYSTEM_MODE
            ]);
        }
        return new Map<Id, Customer_Outcome__c>([
            SELECT Id, Title__c, Headline__c, Sentiment_Reason__c FROM Customer_Outcome__c WHERE Id IN :ids WITH SYSTEM_MODE
        ]);
    }

    // ------------------------------------------------------------------ helpers

    /** The name of the model behind a prompt, for the Model field: the template, the setting's model, or the default. */
    public static String modelFor(String promptName) {
        try {
            AgentLlm.Setting s = AgentLlm.setting(promptName);
            if (s.isTemplate()) {
                return 'template:' + s.templateName;
            }
            return String.isBlank(s.model) ? AgentLlmModelsApi.MODEL : s.model;
        } catch (Exception e) {
            return AgentLlmModelsApi.MODEL;
        }
    }

    /** Where this request came from, as a short word. */
    @TestVisible
    private static String currentSurface() {
        Quiddity q = Request.getCurrent().getQuiddity();
        switch on q {
            when AURA, VF {
                return 'panel';
            }
            when INVOCABLE_ACTION {
                return 'action';
            }
            when REST, SOAP {
                return 'api';
            }
            when ANONYMOUS {
                return 'script';
            }
            when RUNTEST_SYNC, RUNTEST_ASYNC, RUNTEST_DEPLOY {
                return 'test';
            }
            when else {
                return String.valueOf(q).toLowerCase();
            }
        }
    }

    private static Boolean canRead() {
        return Schema.SObjectType.Customer_Outcome__c.isAccessible();
    }

    /** True when the user can read the account in user mode. Losing the account hides its outcomes (N6). */
    private static Boolean accountVisible(Id accountId) {
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType) {
            return false;
        }
        try {
            return [SELECT COUNT() FROM Account WHERE Id = :accountId WITH USER_MODE] == 1;
        } catch (QueryException e) {
            return false;
        }
    }

    private static Set<String> typeNames(List<String> names) {
        Set<String> out = new Set<String>();
        if (names == null) {
            return out;
        }
        Map<String, Customer_Outcome_Type__mdt> all = types();
        for (String n : names) {
            Customer_Outcome_Type__mdt t = resolveType(n, all);
            if (t != null) {
                out.add(t.DeveloperName);
            } else if (String.isNotBlank(n)) {
                out.add(n.trim());
            }
        }
        return out;
    }

    private static String firstLine(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        for (String line : text.split('\n')) {
            if (String.isNotBlank(line)) {
                return line.trim();
            }
        }
        return null;
    }

    private static String clip(String text, Integer max) {
        if (text == null) {
            return null;
        }
        return text.length() <= max ? text : text.left(max - 1).trim() + '…';
    }
}
