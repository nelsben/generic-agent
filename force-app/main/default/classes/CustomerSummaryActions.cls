/**
 * CustomerSummaryActions: the write-action service (BE-27, docs/patterns/13-write-actions.md). Six actions, each in
 * two separate server calls: draft, which checks and resolves everything and writes nothing, and commitDraft, which
 * writes exactly what the draft showed, once the user confirms.
 *
 * - Every query and every write runs in user mode, so the platform applies object access, field-level security and
 *   sharing. A rep can do here only what they could do on the record page.
 * - draft resolves words to values in code ('next Tuesday' to a date, 'Maria' to a contact on this account). A name
 *   that matches no one comes back unresolved, and two matches come back as a choice: never a guess.
 * - The draft carries its resolved input (inputJson). commitDraft rebuilds the draft from it, checks it again as the
 *   user, and writes only a READY draft. A model call and a write never share a transaction (a callout after DML
 *   throws), so draftFromText, the one path that calls the model, never writes.
 * - After a write, one Action outcome is recorded on the account (CustomerOutcomes). A failed outcome is logged and
 *   never undoes the action.
 * - An update returns an undo token that carries the previous values itself. undo restores them within 15 seconds,
 *   as the user, under the same allow-list, and removes the outcome. A created record has no undo.
 *
 * The panel reaches this through CustomerSummaryPanelController; MCP or an agent through the two invocables
 * (CustomerSummaryActionDraftAction, CustomerSummaryActionCommitAction). The actions as data are in
 * CustomerSummaryActionCatalog, and words to records and dates in CustomerSummaryActionResolver.
 */
public with sharing class CustomerSummaryActions {
    /**
     * F17 (docs/plans/feature-revision-2.md): a logged call is written as a completed Task with subtype Call. Ben chose
     * a Task on 2026-11-16: it is what the standard Log a Call quick action saves, and activity reports filter on
     * TaskSubtype. BE-22 measured both shapes (a 15-minute Event and a completed Task both land in the account's
     * activity history). To switch back to an Event, change 'Task' to 'Event' on this line; nothing else changes.
     */
    public static final String LOG_CALL_AS = 'Task';
    @TestVisible private static String logCallAs = LOG_CALL_AS;

    public static final String READY = 'READY';
    public static final String NEEDS_INPUT = 'NEEDS_INPUT';
    public static final String NOT_AN_ACTION = 'NOT_AN_ACTION';
    public static final String REFUSED = 'REFUSED';
    public static final String ERROR = 'ERROR';
    public static final String OK = 'OK';

    /** How long an update can be undone. */
    public static final Integer UNDO_SECONDS = 15;
    /** A logged call ends now and starts this many minutes before. */
    public static final Integer CALL_MINUTES = 15;
    /** An event with no end or length said runs this long. */
    public static final Integer EVENT_MINUTES = 30;
    /** The prompt file draftFromText runs: the static resource AgentPrompt_ActionDraft. */
    public static final String PROMPT = 'ActionDraft';
    private static final Integer PROMPT_TOKENS = 400;
    private static final Integer TOKEN_VERSION = 1;

    public static final String NOT_AN_ACTION_TEXT = 'That reads as a question, not an action, so nothing was drafted.';
    public static final String NO_ACCOUNT_TEXT = 'That account is not there, or you can\'t see it.';
    public static final String UNKNOWN_ACTION_TEXT = 'That is not an action this can take.';
    public static final String BAD_INPUT_TEXT = 'That draft could not be read, so nothing was drafted.';
    public static final String MODEL_TEXT = 'I couldn\'t draft that right now. Try again, or pick the action from the list.';
    public static final String SAVED_TEXT = 'Saved as you, with your access.';
    public static final String UNDO_OFFER_TEXT = 'Undo is offered for 15 seconds.';
    public static final String NOTHING_SAVED_TEXT = 'Nothing was saved.';
    public static final String SAVE_FAILED_TEXT = 'That couldn\'t be saved right now, so nothing was saved. Try again in a minute.';
    public static final String UNDO_BAD_TEXT = 'That undo is not valid, so nothing was changed.';
    public static final String UNDO_EXPIRED_TEXT = 'Undo is no longer offered for that change, so nothing was changed.';
    public static final String UNDONE_TEXT = 'Undone: the previous values are back.';
    public static final String UNDO_FAILED_TEXT = 'That couldn\'t be undone right now, so nothing was changed.';

    private static final Pattern EMAIL = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    private static final Set<String> ACCESS_CODES = new Set<String>{
        'INSUFFICIENT_ACCESS_OR_READONLY', 'INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY', 'INSUFFICIENT_ACCESS'
    };
    private static final Set<String> PLAIN_CODES = new Set<String>{
        'FIELD_CUSTOM_VALIDATION_EXCEPTION', 'STRING_TOO_LONG', 'INVALID_EMAIL_ADDRESS', 'REQUIRED_FIELD_MISSING',
        'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST', 'FIELD_INTEGRITY_EXCEPTION', 'NUMBER_OUTSIDE_VALID_RANGE'
    };
    private static final Map<String, String> CHANGE_LABELS = new Map<String, String>{
        'Title' => 'Title', 'Phone' => 'Phone', 'MobilePhone' => 'Mobile', 'Email' => 'Email', 'Department' => 'Department',
        'StageName' => 'Stage', 'CloseDate' => 'Close date', 'NextStep' => 'Next step', 'Amount' => 'Amount'
    };

    /** Test seam: the moment the service counts from. */
    @TestVisible private static Datetime nowForTest;

    /** @return the object log_call writes, 'Task' by default or 'Event' (F17) */
    public static String logCallObject() {
        return logCallAs == 'Event' ? 'Event' : 'Task';
    }

    // ------------------------------------------------------------------ shapes

    /** A drafted action: what would be written, as the user sees it. No record exists yet. */
    public class Draft {
        /** READY, NEEDS_INPUT, NOT_AN_ACTION, REFUSED or ERROR. */
        @AuraEnabled public String status;
        /** The action's name, such as create_task. */
        @AuraEnabled public String action;
        /** 'Create a task'. */
        @AuraEnabled public String actionLabel;
        @AuraEnabled public String objectName;
        @AuraEnabled public String objectLabel;
        /** create or update. */
        @AuraEnabled public String mode;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        /** The record an update changes; null for a create. */
        @AuraEnabled public Id targetId;
        /** The record an update changes, by name; for a create, the account it goes on. */
        @AuraEnabled public String targetLabel;
        /** The resolved input as JSON: what commitDraft writes from. Dates are ISO, people and deals are Ids. */
        @AuraEnabled public String inputJson;
        @AuraEnabled public List<Field> fields = new List<Field>();
        /** API names of the required fields with no value. */
        @AuraEnabled public List<String> missing = new List<String>();
        @AuraEnabled public List<String> warnings = new List<String>();
        /** Why it was refused, or not an action; null otherwise. */
        @AuraEnabled public String message;
        /** The draft as BE-39's actionDraft card; empty for NOT_AN_ACTION. */
        @AuraEnabled public List<AnswerCard> cards = new List<AnswerCard>();
    }

    /** One field of a draft. */
    public class Field {
        /** The field's API name; 'Id' for the record an update changes; 'changes' for an update with none. */
        @AuraEnabled public String api;
        @AuraEnabled public String label;
        /** What is written: text, a yyyy-MM-dd date, a yyyy-MM-ddTHH:mm time or a record Id. Null when unset. */
        @AuraEnabled public String value;
        /** What the user sees: a name for a record, never an Id. */
        @AuraEnabled public String display;
        /** For an update: the value before, as the user sees it; 'blank' for none. */
        @AuraEnabled public String previous;
        /** True when value is a record Id. */
        @AuraEnabled public Boolean lookup = false;
        @AuraEnabled public Boolean required = false;
        /** True when required and unset. */
        @AuraEnabled public Boolean missing = false;
        /** Why the value said could not be used, in plain words. */
        @AuraEnabled public String error;
        /** The words the request gave, when they did not resolve to one value. */
        @AuraEnabled public String said;
        /** The records the words match, when more than one does. */
        @AuraEnabled public List<Choice> choices = new List<Choice>();
    }

    /** One record a name could mean. */
    public class Choice {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
    }

    /** What a commit or an undo did. */
    public class Result {
        /** OK, REFUSED or ERROR. */
        @AuraEnabled public String status;
        @AuraEnabled public String action;
        /** 'Task created', 'Contact updated', 'Change undone' or 'Not saved'. */
        @AuraEnabled public String title;
        @AuraEnabled public String objectName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public Id recordId;
        /** The record's name or subject. */
        @AuraEnabled public String label;
        /** The record's page, as a path in this org. */
        @AuraEnabled public String linkPath;
        /** For an update only: pass to undo within 15 seconds. */
        @AuraEnabled public String undoToken;
        @AuraEnabled public String message;
        @AuraEnabled public List<Field> fields = new List<Field>();
        /** The result as BE-39's actionResult card. */
        @AuraEnabled public List<AnswerCard> cards = new List<AnswerCard>();
    }

    /** What an undo token carries. Nothing is stored between commit and undo. */
    private class UndoToken {
        Integer v;
        String action;
        Id accountId;
        Id targetId;
        Long at;
        Map<String, String> previous;
        Id outcomeId;
    }

    /** A draft with the record it would write and the previous values, which stay out of the JSON. */
    private class Built {
        Draft d = new Draft();
        CustomerSummaryActionCatalog.Spec spec;
        Map<String, Schema.SObjectField> fieldMap;
        SObject rec;
        Map<String, Object> input;
        Map<String, Object> resolved = new Map<String, Object>();
        Map<String, String> previous = new Map<String, String>();
        Date today;
    }

    // ------------------------------------------------------------------ draft

    /**
     * Checks and resolves one action and returns it as a draft. No DML and no callout.
     * @param actionType create_task, create_event, log_call, update_contact, create_case or update_opportunity
     * @param accountId the open account
     * @param input the action's fields by the prompt's keys (subject, dueDate, priority, contact, startDateTime,
     *        endDateTime, durationMinutes, description, opportunity, changes) or a draft's resolved keys
     *        (contactId, opportunityId and ISO dates)
     * @return READY, NEEDS_INPUT (a field to fill or a choice to make) or REFUSED (with a plain message)
     */
    public static Draft draft(String actionType, Id accountId, Map<String, Object> input) {
        Draft d = build(actionType, accountId, input).d;
        d.cards = new List<AnswerCard>{ AnswerCard.actionDraft(d) };
        return d;
    }

    /**
     * As draft, with the input as JSON text (the panel and the invocable pass it so).
     * @param actionType the action's name
     * @param accountId the open account
     * @param inputJson a JSON object, or blank for none
     * @return the draft; REFUSED when the JSON is not an object
     */
    public static Draft draftJson(String actionType, Id accountId, String inputJson) {
        Map<String, Object> input = String.isBlank(inputJson) ? new Map<String, Object>() : asMap(inputJson);
        if (input == null) {
            return refusedDraft(actionType, accountId, BAD_INPUT_TEXT);
        }
        return draft(actionType, accountId, input);
    }

    /**
     * A typed or spoken sentence to one drafted action, through the model seam (AgentLlm, prompt ActionDraft).
     * The pre-check runs first: text whose first real word is not an action verb is NOT_AN_ACTION with no model call,
     * so the caller can treat it as a question. Never writes, so its callout never meets a DML.
     * @param accountId the open account
     * @param text the request, such as 'create a follow-up for next Tuesday'
     * @return the draft, NOT_AN_ACTION, REFUSED for an account the user cannot see, or ERROR when the model failed
     */
    public static Draft draftFromText(Id accountId, String text) {
        if (!CustomerSummaryActionCatalog.looksLikeAction(text)) {
            return notAnAction(accountId);
        }
        Account a = visibleAccount(accountId);
        if (a == null) {
            return refusedDraft(null, accountId, NO_ACCOUNT_TEXT);
        }
        Map<String, Object> reply;
        try {
            Datetime n = now();
            reply = asMap(AgentLlm.complete(PROMPT, new Map<String, String>{
                'today' => n.format('yyyy-MM-dd'),
                'weekday' => n.format('EEEE'),
                'account_name' => a.Name,
                'request' => text.trim()
            }, PROMPT_TOKENS));
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryActions.draftFromText: model call failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return errorDraft(accountId);
        }
        if (reply == null) {
            return errorDraft(accountId);
        }
        String action = reply.get('action') == null ? null : String.valueOf(reply.get('action')).trim().toLowerCase();
        if (String.isBlank(action) || action == 'none' || CustomerSummaryActionCatalog.find(action) == null) {
            return notAnAction(accountId);
        }
        Map<String, Object> fields = asMap(reply.get('fields'));
        Draft d = build(action, accountId, onlyNamed(fields == null ? new Map<String, Object>() : fields, text)).d;
        d.cards = new List<AnswerCard>{ AnswerCard.actionDraft(d) };
        return d;
    }

    // ------------------------------------------------------------------ commit

    /**
     * Writes a draft the user confirmed, as the user. The draft is rebuilt from its action, account and inputJson and
     * checked again, so a changed or stale draft writes nothing it would not show; only a READY draft is written.
     * Then one Action outcome is recorded on the account; a failed outcome is logged and the write stands.
     * @param sent the draft as draft returned it
     * @return OK with the record, its label and link path (and, for an update, an undo token); REFUSED or ERROR with
     *         a plain message and nothing written
     */
    public static Result commitDraft(Draft sent) {
        if (sent == null) {
            return notSaved(null, REFUSED, BAD_INPUT_TEXT);
        }
        Map<String, Object> input = String.isBlank(sent.inputJson) ? new Map<String, Object>() : asMap(sent.inputJson);
        if (input == null) {
            return notSaved(null, REFUSED, BAD_INPUT_TEXT);
        }
        Built b = build(sent.action, sent.accountId, input);
        if (b.d.status != READY) {
            return notSaved(b, REFUSED, NOTHING_SAVED_TEXT + ' ' + (b.d.status == REFUSED ? b.d.message : needsText(b.d)));
        }
        try {
            if (b.spec.isUpdate()) {
                Database.update(b.rec, true, AccessLevel.USER_MODE);
            } else {
                Database.insert(b.rec, true, AccessLevel.USER_MODE);
            }
        } catch (DmlException e) {
            return notSaved(b, ACCESS_CODES.contains(String.valueOf(e.getDmlType(0))) ? REFUSED : ERROR, saveMessage(b, e));
        } catch (Exception e) {
            return notSaved(b, failureStatus(e), failureMessage(b, e, SAVE_FAILED_TEXT));
        }
        Result r = resultOf(b, OK);
        r.title = b.spec.done;
        r.recordId = b.rec.Id;
        r.label = recordLabel(b);
        r.linkPath = linkPath(b.spec.objectName, r.recordId);
        Id outcomeId = recordOutcome(b, r);
        r.message = SAVED_TEXT;
        if (b.spec.isUpdate()) {
            r.undoToken = token(b, outcomeId);
            r.message += ' ' + UNDO_OFFER_TEXT;
        }
        r.cards = new List<AnswerCard>{ AnswerCard.actionResult(r) };
        return r;
    }

    /**
     * As commitDraft, with the draft as JSON text (the panel and the invocable pass it so).
     * @param draftJson a draft as JSON
     * @return the result; REFUSED when the JSON is not a draft
     */
    public static Result commitJson(String draftJson) {
        Draft d;
        try {
            d = String.isBlank(draftJson) ? null : (Draft) JSON.deserialize(draftJson, Draft.class);
        } catch (Exception e) {
            d = null; // not a draft: refused below
        }
        return commitDraft(d);
    }

    // ------------------------------------------------------------------ undo

    /**
     * Restores the values an update changed, as the user, within UNDO_SECONDS of the commit, and removes the outcome
     * it recorded. The token carries the values; they must be on the action's allow-list and the record on the
     * token's account, so a changed token can do nothing the user could not do by an update.
     * @param undoToken the token commitDraft returned
     * @return OK, or REFUSED with a plain message and nothing changed
     */
    public static Result undo(String undoToken) {
        UndoToken t = readToken(undoToken);
        CustomerSummaryActionCatalog.Spec spec = t == null ? null : CustomerSummaryActionCatalog.find(t.action);
        if (spec == null || !spec.isUpdate() || t.accountId == null || t.targetId == null || t.at == null
                || t.previous == null || t.previous.isEmpty()
                || String.valueOf(t.targetId.getSObjectType()) != spec.objectName) {
            return undoRefused(spec, UNDO_BAD_TEXT);
        }
        Long age = now().getTime() - t.at;
        if (age < 0 || age > UNDO_SECONDS * 1000) {
            return undoRefused(spec, UNDO_EXPIRED_TEXT);
        }
        if (!new Set<String>(spec.allowed).containsAll(t.previous.keySet())) {
            return undoRefused(spec, UNDO_BAD_TEXT);
        }
        SObject target = spec.name == CustomerSummaryActionCatalog.UPDATE_CONTACT
            ? (SObject) CustomerSummaryActionResolver.contactOnAccount(t.accountId, t.targetId)
            : (SObject) CustomerSummaryActionResolver.opportunityOnAccount(t.accountId, t.targetId, false);
        if (target == null) {
            return undoRefused(spec, UNDO_BAD_TEXT);
        }
        Schema.DescribeSObjectResult od = describe(spec.objectName);
        Map<String, Schema.SObjectField> fieldMap = od.fields.getMap();
        SObject rec = od.getSObjectType().newSObject(t.targetId);
        List<Field> restored = new List<Field>();
        try {
            for (String api : spec.allowed) {
                if (!t.previous.containsKey(api)) {
                    continue;
                }
                Schema.DescribeFieldResult dfr = fieldMap.get(api).getDescribe();
                if (!dfr.isUpdateable()) {
                    return undoRefused(spec, 'You can\'t edit ' + CHANGE_LABELS.get(api) + ' on ' + od.getLabelPlural().toLowerCase() + ' with your access, so nothing was changed.');
                }
                String text = t.previous.get(api);
                rec.put(api, typed(dfr, text));
                Field f = new Field();
                f.api = api;
                f.label = CHANGE_LABELS.get(api);
                f.value = text;
                f.display = text == null ? 'blank' : text;
                restored.add(f);
            }
            Database.update(rec, true, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            return undoRefused(spec, ACCESS_CODES.contains(String.valueOf(e.getDmlType(0)))
                ? 'You can\'t edit this ' + od.getLabel().toLowerCase() + ' with your access, so nothing was changed.'
                : UNDO_FAILED_TEXT);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryActions.undo failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return undoRefused(spec, UNDO_FAILED_TEXT);
        }
        removeOutcome(t);
        Result r = new Result();
        r.status = OK;
        r.action = spec.name;
        r.title = 'Change undone';
        r.objectName = spec.objectName;
        r.objectLabel = od.getLabel();
        r.recordId = t.targetId;
        r.label = String.valueOf(target.get('Name'));
        r.linkPath = linkPath(spec.objectName, t.targetId);
        r.message = UNDONE_TEXT;
        r.fields = restored;
        r.cards = new List<AnswerCard>{ AnswerCard.actionResult(r) };
        return r;
    }

    // ------------------------------------------------------------------ building a draft

    private static Built build(String actionType, Id accountId, Map<String, Object> input) {
        Built b = new Built();
        b.today = now().date();
        b.input = lowerKeys(input);
        b.d.accountId = accountId;
        b.d.action = actionType;
        b.spec = CustomerSummaryActionCatalog.find(actionType);
        if (b.spec == null) {
            return refuse(b, UNKNOWN_ACTION_TEXT);
        }
        b.d.action = b.spec.name;
        b.d.actionLabel = b.spec.label;
        b.d.objectName = b.spec.objectName;
        b.d.mode = b.spec.mode;
        Schema.DescribeSObjectResult od = describe(b.spec.objectName);
        b.d.objectLabel = od.getLabel();
        Account a = visibleAccount(accountId);
        if (a == null) {
            return refuse(b, NO_ACCOUNT_TEXT);
        }
        b.d.accountName = a.Name;
        b.d.targetLabel = a.Name;
        Boolean allowed = b.spec.isUpdate() ? od.isUpdateable() : od.isCreateable();
        if (!allowed) {
            return refuse(b, 'You can\'t ' + (b.spec.isUpdate() ? 'edit ' : 'create ') + od.getLabelPlural().toLowerCase() + ' with your access.');
        }
        b.fieldMap = od.fields.getMap();
        b.rec = od.getSObjectType().newSObject();
        switch on b.spec.name {
            when 'create_task' {
                buildTask(b);
            }
            when 'create_event' {
                buildEvent(b);
            }
            when 'log_call' {
                buildCall(b);
            }
            when 'create_case' {
                buildCase(b);
            }
            when else {
                buildUpdate(b);
            }
        }
        return settle(b);
    }

    private static void buildTask(Built b) {
        textField(b, 'Subject', 'Subject', 'subject', true, null);
        dateField(b, 'ActivityDate', 'Due', 'dueDate', true);
        contact(b, 'WhoId', false);
        related(b, 'WhatId');
        picklist(b, 'Priority', 'Priority', 'priority');
        textField(b, 'Description', 'Description', 'description', false, null);
    }

    private static void buildEvent(Built b) {
        textField(b, 'Subject', 'Subject', 'subject', true, null);
        Field start = addField(b, 'StartDateTime', 'Start', true);
        Datetime s = moment(b, start, 'startDateTime');
        Field fin = addField(b, 'EndDateTime', 'End', false);
        Datetime e = moment(b, fin, 'endDateTime');
        String lengthWords = str(b.input, 'durationminutes');
        if (e == null && fin.error == null && s != null) {
            Integer minutes = String.isBlank(lengthWords) ? EVENT_MINUTES : CustomerSummaryActionResolver.toMinutes(lengthWords);
            if (minutes == null) {
                fin.said = lengthWords;
                fin.display = lengthWords;
                fin.error = 'I couldn\'t read "' + lengthWords + '" as a length of time.';
            } else {
                e = s.addMinutes(minutes);
            }
        }
        if (s != null && e != null && e <= s) {
            fin.error = 'The end must be after the start.';
            fin.display = displayTime(e);
            e = null;
        }
        setMoment(b, start, s, 'startDateTime');
        setMoment(b, fin, e, 'endDateTime');
        contact(b, 'WhoId', false);
        related(b, 'WhatId');
        textField(b, 'Description', 'Description', 'description', false, null);
    }

    /** F17: a completed call Task (the default), or (LOG_CALL_AS = 'Event') an Event that ends now and started CALL_MINUTES before. */
    private static void buildCall(Built b) {
        textField(b, 'Subject', 'Subject', 'subject', true, 'Call');
        contact(b, 'WhoId', true);
        related(b, 'WhatId');
        textField(b, 'Description', 'Notes', 'description', false, null);
        if (b.spec.objectName == 'Task') {
            Date day = CustomerSummaryActionResolver.toDate(str(b.input, 'duedate'), b.today);
            Field f = addField(b, 'ActivityDate', 'Date', true);
            setDate(b, f, day == null ? b.today : day, 'dueDate');
            b.rec.put('Status', 'Completed');
            b.rec.put('TaskSubtype', 'Call');
            return;
        }
        Field start = addField(b, 'StartDateTime', 'Start', true);
        Field fin = addField(b, 'EndDateTime', 'End', true);
        Datetime s = moment(b, start, 'startDateTime');
        Datetime e = moment(b, fin, 'endDateTime');
        Datetime n = now();
        Datetime minute = Datetime.newInstance(n.date(), Time.newInstance(n.hour(), n.minute(), 0, 0));
        if (s == null && start.error == null) {
            s = e == null ? minute.addMinutes(-CALL_MINUTES) : e.addMinutes(-CALL_MINUTES);
        }
        if (e == null && fin.error == null && s != null) {
            e = s.addMinutes(CALL_MINUTES);
        }
        setMoment(b, start, s, 'startDateTime');
        setMoment(b, fin, e, 'endDateTime');
    }

    private static void buildCase(Built b) {
        textField(b, 'Subject', 'Subject', 'subject', true, null);
        textField(b, 'Description', 'Description', 'description', false, null);
        picklist(b, 'Priority', 'Priority', 'priority');
        contact(b, 'ContactId', false);
        related(b, 'AccountId');
    }

    private static void buildUpdate(Built b) {
        Boolean isContact = b.spec.name == CustomerSummaryActionCatalog.UPDATE_CONTACT;
        Field target = addField(b, 'Id', isContact ? 'Contact' : 'Opportunity', true);
        target.lookup = true;
        SObject found = isContact ? (SObject) resolveContact(b, target) : (SObject) resolveOpportunity(b, target);
        if (found == null) {
            if (target.error == null && target.choices.isEmpty()) {
                target.missing = true;
            }
            return;
        }
        target.value = found.Id;
        target.display = String.valueOf(found.get('Name'));
        b.rec = found.getSObjectType().newSObject(found.Id);
        b.d.targetId = found.Id;
        b.d.targetLabel = target.display;
        changes(b, found.Id);
    }

    /** The update's changes: only allow-listed fields, each checked, with its value before. */
    private static void changes(Built b, Id targetId) {
        Map<String, Object> raw = lowerKeys(asMap(b.input.get('changes')));
        Set<String> allowedLower = new Set<String>();
        for (String api : b.spec.allowed) {
            allowedLower.add(api.toLowerCase());
        }
        for (String key : raw.keySet()) {
            if (!allowedLower.contains(key)) {
                b.d.warnings.add('"' + key + '" can\'t be changed here, so it was left out.');
            }
        }
        List<String> asked = new List<String>();
        List<String> readable = new List<String>();
        for (String api : b.spec.allowed) {
            if (raw.containsKey(api.toLowerCase())) {
                asked.add(api);
                if (b.fieldMap.get(api).getDescribe().isAccessible()) {
                    readable.add(api);
                }
            }
        }
        if (asked.isEmpty()) {
            Field none = addField(b, 'changes', 'Change', true);
            none.missing = true;
            return;
        }
        SObject current = currentValues(b, targetId, readable);
        Map<String, Object> kept = new Map<String, Object>();
        for (String api : asked) {
            Field f = addField(b, api, CHANGE_LABELS.get(api), false);
            Object said = raw.get(api.toLowerCase());
            String words = said == null ? '' : String.valueOf(said).trim();
            if (!readable.contains(api) || current == null) {
                f.error = 'You can\'t see ' + f.label + ' with your access.';
                continue;
            }
            Object before = current.get(api);
            String beforeText = before == null ? null : String.valueOf(before);
            if (beforeText != null && String.isBlank(beforeText)) {
                beforeText = null;
            }
            f.previous = beforeText == null ? 'blank' : display(before);
            if (String.isBlank(words)) {
                f.error = 'Give a new value for ' + f.label + '.';
                continue;
            }
            if (changeValue(b, f, api, words)) {
                b.previous.put(api, beforeText);
                kept.put(api, f.value);
            }
        }
        b.resolved.put('changes', kept);
    }

    /** Turns one change's words into its typed value on the record. False when the words do not fit the field. */
    private static Boolean changeValue(Built b, Field f, String api, String words) {
        Schema.DescribeFieldResult dfr = b.fieldMap.get(api).getDescribe();
        Object value;
        String text;
        String shown;
        switch on api {
            when 'StageName' {
                text = picklistValue(dfr, words);
                value = text;
                shown = text;
            }
            when 'CloseDate' {
                Date d = CustomerSummaryActionResolver.toDate(words, b.today);
                value = d;
                text = d == null ? null : String.valueOf(d);
                shown = text;
            }
            when 'Amount' {
                Decimal amount = toAmount(words);
                value = amount;
                text = amount == null ? null : String.valueOf(amount);
                shown = amount == null ? null : amount.format();
            }
            when 'Email' {
                text = EMAIL.matcher(words).matches() ? words : null;
                value = text;
                shown = text;
            }
            when else {
                text = words;
                value = words;
                shown = words;
            }
        }
        if (value == null) {
            f.said = words;
            f.display = words;
            f.error = '"' + words + '" can\'t be used as the ' + f.label.toLowerCase() + '.';
            return false;
        }
        return setValue(b, f, value, text, shown);
    }

    private static SObject currentValues(Built b, Id targetId, List<String> fields) {
        Set<String> names = new Set<String>{ 'Id', 'Name' };
        names.addAll(fields);
        Id accountId = b.d.accountId;
        String soql = 'SELECT ' + String.join(new List<String>(names), ', ') + ' FROM ' + b.spec.objectName
            + ' WHERE Id = :targetId AND AccountId = :accountId LIMIT 1';
        List<SObject> rows = Database.queryWithBinds(soql,
            new Map<String, Object>{ 'targetId' => targetId, 'accountId' => accountId }, AccessLevel.USER_MODE);
        return rows.isEmpty() ? null : rows[0];
    }

    // ------------------------------------------------------------------ fields

    private static Field addField(Built b, String api, String label, Boolean required) {
        Field f = new Field();
        f.api = api;
        f.label = label;
        f.required = required;
        b.d.fields.add(f);
        return f;
    }

    /** Puts a value on the record when the user may set the field. False (with a plain error) when they may not. */
    private static Boolean setValue(Built b, Field f, Object value, String text, String shown) {
        Schema.SObjectField sf = b.fieldMap.get(f.api);
        Schema.DescribeFieldResult dfr = sf == null ? null : sf.getDescribe();
        Boolean can = dfr != null && (b.spec.isUpdate() ? dfr.isUpdateable() : dfr.isCreateable());
        f.display = shown;
        if (!can) {
            f.error = 'You can\'t set ' + f.label + ' with your access.';
            return false;
        }
        b.rec.put(f.api, value);
        f.value = text;
        return true;
    }

    private static void textField(Built b, String api, String label, String key, Boolean required, String fallback) {
        Field f = addField(b, api, label, required);
        String v = str(b.input, key.toLowerCase());
        if (String.isBlank(v)) {
            v = fallback;
        }
        if (String.isBlank(v)) {
            f.missing = required;
            return;
        }
        b.resolved.put(key, v);
        setValue(b, f, v, v, v);
    }

    private static void dateField(Built b, String api, String label, String key, Boolean required) {
        Field f = addField(b, api, label, required);
        String words = str(b.input, key.toLowerCase());
        if (String.isBlank(words)) {
            f.missing = required;
            return;
        }
        Date d = CustomerSummaryActionResolver.toDate(words, b.today);
        if (d == null) {
            f.said = words;
            f.display = words;
            f.error = 'I couldn\'t read "' + words + '" as a date.';
            return;
        }
        setDate(b, f, d, key);
    }

    private static void setDate(Built b, Field f, Date d, String key) {
        String iso = String.valueOf(d);
        b.resolved.put(key, iso);
        setValue(b, f, d, iso, iso);
    }

    /** A date and time from the input's words; null (with an error when words were given) when they do not read. */
    private static Datetime moment(Built b, Field f, String key) {
        String words = str(b.input, key.toLowerCase());
        if (String.isBlank(words)) {
            return null;
        }
        Datetime dt = CustomerSummaryActionResolver.toDatetime(words, b.today);
        if (dt == null) {
            f.said = words;
            f.display = words;
            f.error = 'I couldn\'t read "' + words + '" as a day and a time.';
        }
        return dt;
    }

    private static void setMoment(Built b, Field f, Datetime dt, String key) {
        if (f.error != null) {
            return;
        }
        if (dt == null) {
            f.missing = f.required;
            return;
        }
        String iso = dt.format('yyyy-MM-dd\'T\'HH:mm');
        b.resolved.put(key, iso);
        setValue(b, f, dt, iso, displayTime(dt));
    }

    /** A picklist from words, matched to an active value; the field's default when none is said. */
    private static void picklist(Built b, String api, String label, String key) {
        Field f = addField(b, api, label, false);
        Schema.DescribeFieldResult dfr = b.fieldMap.get(api).getDescribe();
        String words = str(b.input, key.toLowerCase());
        String v = String.isBlank(words) ? picklistDefault(dfr) : picklistValue(dfr, words);
        if (String.isNotBlank(words) && v == null) {
            f.said = words;
            f.display = words;
            f.error = '"' + words + '" can\'t be used as the ' + label.toLowerCase() + '.';
            return;
        }
        if (v == null) {
            return;
        }
        b.resolved.put(key, v);
        setValue(b, f, v, v, v);
    }

    /** The account the record goes on, shown by name. */
    private static void related(Built b, String api) {
        Field f = addField(b, api, api == 'AccountId' ? 'Account' : 'Related to', false);
        f.lookup = true;
        setValue(b, f, b.d.accountId, b.d.accountId, b.d.accountName);
    }

    private static void contact(Built b, String api, Boolean required) {
        Field f = addField(b, api, 'Contact', required);
        f.lookup = true;
        Contact c = resolveContact(b, f);
        if (c != null) {
            setValue(b, f, c.Id, c.Id, c.Name);
        } else if (f.error == null && f.choices.isEmpty()) {
            f.missing = required;
        }
    }

    /** A contact on the account from contactId or the words said. Null when none, unresolved or a choice. */
    private static Contact resolveContact(Built b, Field f) {
        Id given = toId(str(b.input, 'contactid'));
        if (given != null) {
            Contact c = CustomerSummaryActionResolver.contactOnAccount(b.d.accountId, given);
            if (c == null) {
                f.error = 'That contact is not on this account, or you can\'t see it.';
            } else {
                b.resolved.put('contactId', c.Id);
            }
            return c;
        }
        String words = str(b.input, 'contact');
        if (String.isBlank(words)) {
            return null;
        }
        List<Contact> hits = CustomerSummaryActionResolver.contacts(b.d.accountId, words);
        if (hits.size() == 1) {
            b.resolved.put('contactId', hits[0].Id);
            return hits[0];
        }
        b.resolved.put('contact', words);
        unresolved(b, f, words, hits, 'contact');
        return null;
    }

    /** An open opportunity on the account from opportunityId or the words said. */
    private static Opportunity resolveOpportunity(Built b, Field f) {
        Id given = toId(str(b.input, 'opportunityid'));
        if (given != null) {
            Opportunity o = CustomerSummaryActionResolver.opportunityOnAccount(b.d.accountId, given, true);
            if (o == null) {
                f.error = 'That opportunity is not open on this account, or you can\'t see it.';
            } else {
                b.resolved.put('opportunityId', o.Id);
            }
            return o;
        }
        String words = str(b.input, 'opportunity');
        if (String.isBlank(words)) {
            return null;
        }
        List<Opportunity> hits = CustomerSummaryActionResolver.openOpportunities(b.d.accountId, words);
        if (hits.size() == 1) {
            b.resolved.put('opportunityId', hits[0].Id);
            return hits[0];
        }
        b.resolved.put('opportunity', words);
        unresolved(b, f, words, hits, 'open opportunity');
        return null;
    }

    /** No match is an error to fix; several are a choice. Never a guess. */
    private static void unresolved(Built b, Field f, String words, List<SObject> hits, String noun) {
        f.said = words;
        f.display = words;
        if (hits.isEmpty()) {
            f.error = 'No ' + noun + ' matches "' + words + '" on this account. Pick one or clear the field.';
            return;
        }
        for (SObject s : hits) {
            Choice c = new Choice();
            c.id = s.Id;
            c.label = String.valueOf(s.get('Name'));
            f.choices.add(c);
        }
        String plural = noun.endsWith('y') ? noun.removeEnd('y') + 'ies' : noun + 's';
        b.d.warnings.add(hits.size() + ' ' + plural + ' match "' + words + '"; choose one or clear the field.');
    }

    private static Built settle(Built b) {
        Boolean needs = false;
        for (Field f : b.d.fields) {
            if (f.missing) {
                b.d.missing.add(f.api);
            }
            needs = needs || f.missing || f.error != null || !f.choices.isEmpty();
        }
        b.d.status = needs ? NEEDS_INPUT : READY;
        b.d.inputJson = JSON.serialize(b.resolved);
        return b;
    }

    private static Built refuse(Built b, String message) {
        b.d.status = REFUSED;
        b.d.message = message;
        b.d.fields = new List<Field>();
        b.d.inputJson = '{}';
        return b;
    }

    // ------------------------------------------------------------------ results

    private static Result resultOf(Built b, String status) {
        Result r = new Result();
        r.status = status;
        r.action = b == null ? null : b.d.action;
        r.objectName = b == null ? null : b.d.objectName;
        r.objectLabel = b == null ? null : b.d.objectLabel;
        if (b != null && status == OK) {
            for (Field f : b.d.fields) {
                if (f.value != null) {
                    r.fields.add(f);
                }
            }
        }
        return r;
    }

    private static Result notSaved(Built b, String status, String message) {
        Result r = resultOf(b, status);
        r.title = 'Not saved';
        r.message = message;
        r.cards = new List<AnswerCard>{ AnswerCard.actionResult(r) };
        return r;
    }

    private static Result undoRefused(CustomerSummaryActionCatalog.Spec spec, String message) {
        Result r = new Result();
        r.status = REFUSED;
        r.action = spec == null ? null : spec.name;
        r.objectName = spec == null ? null : spec.objectName;
        r.title = 'Not undone';
        r.message = message;
        r.cards = new List<AnswerCard>{ AnswerCard.actionResult(r) };
        return r;
    }

    private static String needsText(Draft d) {
        List<String> labels = new List<String>();
        for (Field f : d.fields) {
            if (f.missing || f.error != null || !f.choices.isEmpty()) {
                labels.add(f.label);
            }
        }
        return 'This draft still needs: ' + String.join(labels, ', ') + '.';
    }

    /** A DML failure in plain words: an access refusal, the platform's own message for a rule, or a fixed line. */
    private static String saveMessage(Built b, DmlException e) {
        String code = String.valueOf(e.getDmlType(0));
        if (ACCESS_CODES.contains(code)) {
            return accessText(b);
        }
        if (PLAIN_CODES.contains(code) && String.isNotBlank(e.getDmlMessage(0))) {
            return NOTHING_SAVED_TEXT + ' ' + e.getDmlMessage(0);
        }
        System.debug(LoggingLevel.WARN, 'CustomerSummaryActions.commitDraft failed: ' + code + ': ' + e.getMessage());
        return SAVE_FAILED_TEXT;
    }

    private static String failureStatus(Exception e) {
        return e instanceof System.SecurityException || e instanceof System.NoAccessException ? REFUSED : ERROR;
    }

    private static String failureMessage(Built b, Exception e, String fallback) {
        if (e instanceof System.SecurityException || e instanceof System.NoAccessException) {
            return accessText(b);
        }
        System.debug(LoggingLevel.WARN, 'CustomerSummaryActions.commitDraft failed: ' + e.getTypeName() + ': ' + e.getMessage());
        return fallback;
    }

    private static String accessText(Built b) {
        String what = b.spec.isUpdate() ? 'edit this ' : 'create this ';
        return 'You can\'t ' + what + b.d.objectLabel.toLowerCase() + ' with your access, so nothing was saved.';
    }

    private static String recordLabel(Built b) {
        if (b.spec.isUpdate()) {
            return b.d.targetLabel;
        }
        for (Field f : b.d.fields) {
            if (f.api == 'Subject') {
                return f.display;
            }
        }
        return b.d.actionLabel;
    }

    private static String linkPath(String objectName, Id recordId) {
        return recordId == null ? null : '/lightning/r/' + objectName + '/' + recordId + '/view';
    }

    /** One Action outcome on the account. A failure is logged and returns null: the action stands. */
    private static Id recordOutcome(Built b, Result r) {
        try {
            CustomerOutcomes.Input i = new CustomerOutcomes.Input(b.d.accountId, CustomerOutcomes.ACTION);
            i.title = b.spec.done + ': ' + r.label;
            i.body = fieldLines(b.d.fields);
            i.relatedRecordId = String.valueOf(r.recordId);
            i.skill = b.spec.name;
            return CustomerOutcomes.record(i);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryActions: the action was saved but its outcome was not: '
                + e.getTypeName() + ': ' + e.getMessage());
            return null;
        }
    }

    /** The outcome the token names, removed only when it is this action's outcome on this account. */
    private static void removeOutcome(UndoToken t) {
        Id outcomeId = t.outcomeId;
        if (outcomeId == null || outcomeId.getSObjectType() != Customer_Outcome__c.SObjectType) {
            return;
        }
        try {
            List<Customer_Outcome__c> rows = [SELECT Id, Account__c, Outcome_Type__c, Related_Record_Id__c
                                              FROM Customer_Outcome__c WHERE Id = :outcomeId WITH USER_MODE LIMIT 1];
            if (rows.isEmpty() || rows[0].Account__c != t.accountId || rows[0].Outcome_Type__c != CustomerOutcomes.ACTION
                    || rows[0].Related_Record_Id__c != String.valueOf(t.targetId)) {
                return;
            }
            CustomerOutcomes.remove(rows[0].Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CustomerSummaryActions.undo: the change was undone but its outcome was not removed: '
                + e.getTypeName() + ': ' + e.getMessage());
        }
    }

    private static String fieldLines(List<Field> fields) {
        List<String> lines = new List<String>();
        for (Field f : fields) {
            if (f.value == null || f.api == 'Id') {
                continue;
            }
            lines.add(f.label + ': ' + f.display + (f.previous == null ? '' : ' (was ' + f.previous + ')'));
        }
        return String.join(lines, '\n');
    }

    // ------------------------------------------------------------------ the undo token

    private static String token(Built b, Id outcomeId) {
        UndoToken t = new UndoToken();
        t.v = TOKEN_VERSION;
        t.action = b.spec.name;
        t.accountId = b.d.accountId;
        t.targetId = b.d.targetId;
        t.at = now().getTime();
        t.previous = b.previous;
        t.outcomeId = outcomeId;
        return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(t)));
    }

    private static UndoToken readToken(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        try {
            UndoToken t = (UndoToken) JSON.deserialize(EncodingUtil.base64Decode(text).toString(), UndoToken.class);
            return t != null && t.v == TOKEN_VERSION ? t : null;
        } catch (Exception e) {
            return null; // not a token this service wrote
        }
    }

    private static Object typed(Schema.DescribeFieldResult dfr, String text) {
        if (text == null) {
            return null;
        }
        Schema.DisplayType kind = dfr.getType();
        if (kind == Schema.DisplayType.DATE) {
            return Date.valueOf(text);
        }
        if (kind == Schema.DisplayType.CURRENCY || kind == Schema.DisplayType.DOUBLE || kind == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(text);
        }
        return text;
    }

    // ------------------------------------------------------------------ small parts

    private static Draft notAnAction(Id accountId) {
        Draft d = new Draft();
        d.status = NOT_AN_ACTION;
        d.accountId = accountId;
        d.message = NOT_AN_ACTION_TEXT;
        d.inputJson = '{}';
        return d;
    }

    private static Draft errorDraft(Id accountId) {
        Draft d = new Draft();
        d.status = ERROR;
        d.accountId = accountId;
        d.message = MODEL_TEXT;
        d.inputJson = '{}';
        d.cards = new List<AnswerCard>{ AnswerCard.error('err', MODEL_TEXT) };
        return d;
    }

    private static Draft refusedDraft(String actionType, Id accountId, String message) {
        Built b = new Built();
        b.d.accountId = accountId;
        b.spec = CustomerSummaryActionCatalog.find(actionType);
        b.d.action = b.spec == null ? actionType : b.spec.name;
        b.d.actionLabel = b.spec == null ? null : b.spec.label;
        b.d.mode = b.spec == null ? null : b.spec.mode;
        b.d.objectName = b.spec == null ? null : b.spec.objectName;
        Draft d = refuse(b, message).d;
        d.cards = new List<AnswerCard>{ AnswerCard.actionDraft(d) };
        return d;
    }

    private static Account visibleAccount(Id accountId) {
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType || !Schema.SObjectType.Account.isAccessible()) {
            return null;
        }
        List<Account> rows = [SELECT Id, Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * BE-22: the model names a person or a deal the request never named. Keep a contact or opportunity only when
     * one of its words is in the request, so a name the user did not say never reaches the draft.
     */
    private static Map<String, Object> onlyNamed(Map<String, Object> fields, String request) {
        String said = ' ' + request.toLowerCase().replaceAll('[^a-z0-9\\s]', ' ').normalizeSpace() + ' ';
        Map<String, Object> kept = new Map<String, Object>();
        for (String key : fields.keySet()) {
            Object v = fields.get(key);
            String k = key.toLowerCase();
            if ((k == 'contact' || k == 'opportunity') && v != null && !anyWordIn(String.valueOf(v), said)) {
                continue;
            }
            kept.put(key, v);
        }
        return kept;
    }

    private static Boolean anyWordIn(String name, String said) {
        for (String w : name.toLowerCase().replace('\'s', '').replaceAll('[^a-z0-9\\s]', ' ').normalizeSpace().split(' ')) {
            if (w.length() > 1 && w != 'the' && said.contains(' ' + w + ' ')) {
                return true;
            }
        }
        return false;
    }

    private static Schema.DescribeSObjectResult describe(String objectName) {
        return Schema.describeSObjects(new List<String>{ objectName })[0];
    }

    private static String picklistValue(Schema.DescribeFieldResult dfr, String words) {
        String w = words.trim();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive() && (e.getValue().equalsIgnoreCase(w) || e.getLabel().equalsIgnoreCase(w))) {
                return e.getValue();
            }
        }
        return null;
    }

    private static String picklistDefault(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive() && e.isDefaultValue()) {
                return e.getValue();
            }
        }
        return null;
    }

    /** '50000', '$50,000', '50k', '1.2m' to a number; null when the words are not one. */
    private static Decimal toAmount(String words) {
        String w = words.toLowerCase().replace('$', '').replace(',', '').replace(' ', '');
        Decimal times = 1;
        if (w.endsWith('k')) {
            times = 1000;
            w = w.removeEnd('k');
        } else if (w.endsWith('m')) {
            times = 1000000;
            w = w.removeEnd('m');
        }
        try {
            return Decimal.valueOf(w) * times;
        } catch (TypeException e) {
            return null; // not a number: the field asks again
        }
    }

    private static String display(Object v) {
        if (v instanceof Date) {
            return String.valueOf(v);
        }
        if (v instanceof Decimal) {
            return ((Decimal) v).format();
        }
        return String.valueOf(v);
    }

    private static String displayTime(Datetime dt) {
        return dt.format('yyyy-MM-dd HH:mm');
    }

    private static Datetime now() {
        return nowForTest != null ? nowForTest : Datetime.now();
    }

    private static Id toId(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        try {
            return Id.valueOf(text);
        } catch (StringException e) {
            return null; // not an Id: treated as unset
        }
    }

    private static String str(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        String s = v == null ? null : String.valueOf(v).trim();
        return String.isBlank(s) ? null : s;
    }

    private static Map<String, Object> lowerKeys(Map<String, Object> m) {
        Map<String, Object> out = new Map<String, Object>();
        if (m != null) {
            for (String k : m.keySet()) {
                if (k != null) {
                    out.put(k.toLowerCase(), m.get(k));
                }
            }
        }
        return out;
    }

    /** A JSON object (as text, or already parsed) to a map; null when it is not one. */
    private static Map<String, Object> asMap(Object o) {
        if (o == null) {
            return null;
        }
        try {
            Object parsed;
            if (o instanceof String) {
                String s = (String) o;
                Integer open = s.indexOf('{');
                Integer close = s.lastIndexOf('}');
                if (open < 0 || close <= open) {
                    return null;
                }
                parsed = JSON.deserializeUntyped(s.substring(open, close + 1));
            } else {
                parsed = JSON.deserializeUntyped(JSON.serialize(o));
            }
            return parsed instanceof Map<String, Object> ? (Map<String, Object>) parsed : null;
        } catch (JSONException e) {
            return null; // not JSON: the caller refuses or reports it
        }
    }
}
