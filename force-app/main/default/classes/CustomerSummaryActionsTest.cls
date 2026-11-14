/**
 * CustomerSummaryActionsTest: the create actions, draftFromText through a stubbed model, the invocables and access
 * (BE-27). A draft writes nothing; a commit writes what the draft showed, as the user, and records one outcome.
 * Updates and undo are in CustomerSummaryActionUpdatesTest. The clock is fixed at Friday 2026-11-13 10:00.
 */
@IsTest
private class CustomerSummaryActionsTest {
    private static final Datetime NOW = Datetime.newInstance(2026, 11, 13, 10, 0, 0);

    /** Scripted replies in order, recording every user prompt; a reply of 'THROW' throws. Never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        List<String> prompts = new List<String>();

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            prompts.add(userPrompt);
            String reply = replies.isEmpty() ? '{"action":"none"}' : replies.remove(0);
            if (reply == 'THROW') {
                throw new CalloutException('model unreachable (raw platform text)');
            }
            return reply;
        }
    }

    private static Stub stub(List<String> replies) {
        Stub s = new Stub();
        s.replies = replies;
        AgentLlm.stub = s;
        return s;
    }

    @TestSetup
    static void data() {
        Account a = new Account(Name = 'Actions Acme');
        Account other = new Account(Name = 'Actions Other');
        insert new List<Account>{ a, other };
        insert new List<Contact>{
            new Contact(AccountId = a.Id, FirstName = 'Maria', LastName = 'Lopez', Title = 'Buyer'),
            new Contact(AccountId = a.Id, FirstName = 'Jordan', LastName = 'Lee'),
            new Contact(AccountId = a.Id, FirstName = 'Jordan', LastName = 'Park'),
            new Contact(AccountId = other.Id, FirstName = 'Sam', LastName = 'Stone')
        };
    }

    private static Id acme() {
        CustomerSummaryActions.nowForTest = NOW;
        return [SELECT Id FROM Account WHERE Name = 'Actions Acme' LIMIT 1].Id;
    }

    private static Contact maria() {
        return [SELECT Id, Title FROM Contact WHERE LastName = 'Lopez' LIMIT 1];
    }

    private static CustomerSummaryActions.Field field(CustomerSummaryActions.Draft d, String api) {
        for (CustomerSummaryActions.Field f : d.fields) {
            if (f.api == api) {
                return f;
            }
        }
        return null;
    }

    private static Integer outcomesFor(Id recordId) {
        String related = String.valueOf(recordId);
        return [SELECT COUNT() FROM Customer_Outcome__c WHERE Related_Record_Id__c = :related
                AND Outcome_Type__c = :CustomerOutcomes.ACTION];
    }

    // ------------------------------------------------------------------ create_task

    @IsTest
    static void aTaskDraftMakesNoDmlAndConfirmWritesIt() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Send pricing', 'dueDate' => 'tomorrow', 'contact' => 'Maria' });
        Assert.areEqual(0, Limits.getDmlStatements(), 'a draft writes nothing');
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status, JSON.serialize(d.fields));
        Assert.areEqual('2026-11-14', field(d, 'ActivityDate').value);
        Assert.areEqual('Maria Lopez', field(d, 'WhoId').display, 'a person shows by name');
        Assert.areEqual('Actions Acme', field(d, 'WhatId').display);
        Assert.areEqual('actionDraft', d.cards[0].type);
        Assert.isFalse(d.cards[0].text.contains(String.valueOf(mariaId)), 'no Id in the card text');
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Task t = [SELECT Subject, ActivityDate, WhoId, WhatId FROM Task WHERE Id = :r.recordId];
        Assert.areEqual('Send pricing', t.Subject);
        Assert.areEqual(Date.newInstance(2026, 11, 14), t.ActivityDate);
        Assert.areEqual(mariaId, t.WhoId);
        Assert.areEqual(accountId, t.WhatId);
        Assert.areEqual('Task created', r.title);
        Assert.areEqual('Send pricing', r.label);
        Assert.areEqual('/lightning/r/Task/' + r.recordId + '/view', r.linkPath);
        Assert.areEqual(CustomerSummaryActions.SAVED_TEXT, r.message);
        Assert.isNull(r.undoToken, 'a created record has no undo');
        Assert.areEqual('actionResult', r.cards[0].type);
        String related = String.valueOf(r.recordId);
        Customer_Outcome__c o = [SELECT Account__c, Skill__c, Title__c, Outcome_Type__c FROM Customer_Outcome__c
                                 WHERE Related_Record_Id__c = :related WITH SYSTEM_MODE];
        Assert.areEqual(accountId, o.Account__c);
        Assert.areEqual(CustomerOutcomes.ACTION, o.Outcome_Type__c);
        Assert.areEqual('create_task', o.Skill__c);
        Assert.areEqual('Task created: Send pricing', o.Title__c);
    }

    @IsTest
    static void aTaskWithNoDueDateOrAnUnreadableOneNeedsInput() {
        Id accountId = acme();
        Test.startTest();
        CustomerSummaryActions.Draft none = CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Send pricing' });
        CustomerSummaryActions.Draft bad = CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Send pricing', 'dueDate' => 'next blursday' });
        Assert.areEqual(0, Limits.getDmlStatements());
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, none.status);
        Assert.areEqual(new List<String>{ 'ActivityDate' }, none.missing);
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, bad.status);
        Assert.areEqual('I couldn\'t read "next blursday" as a date.', field(bad, 'ActivityDate').error);
        Assert.areEqual('missing', bad.cards[0].fields[1].state);
    }

    @IsTest
    static void twoMatchingContactsAreAChoiceAndAPickedOneIsReady() {
        Id accountId = acme();
        Map<String, Object> input = new Map<String, Object>{ 'subject' => 'Intro', 'dueDate' => 'Monday', 'contact' => 'Jordan' };
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_task', accountId, input);
        CustomerSummaryActions.Result refused = CustomerSummaryActions.commitDraft(d);
        CustomerSummaryActions.Field who = field(d, 'WhoId');
        input.put('contactId', who.choices[1].id);
        CustomerSummaryActions.Draft picked = CustomerSummaryActions.draft('create_task', accountId, input);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual(2, who.choices.size(), 'two matches are a choice, never a guess');
        Assert.areEqual('2 contacts match "Jordan"; choose one or clear the field.', d.warnings[0]);
        Assert.areEqual('choose', d.cards[0].fields[2].state);
        Assert.areEqual(CustomerSummaryActions.REFUSED, refused.status);
        Assert.areEqual('Nothing was saved. This draft still needs: Contact.', refused.message);
        Assert.areEqual(CustomerSummaryActions.READY, picked.status);
        Assert.areEqual(who.choices[1].label, field(picked, 'WhoId').display);
        Assert.areEqual(0, [SELECT COUNT() FROM Task], 'nothing was written');
    }

    @IsTest
    static void aContactNotOnTheAccountNeverResolves() {
        Id accountId = acme();
        Contact sam = [SELECT Id FROM Contact WHERE LastName = 'Stone' LIMIT 1];
        Test.startTest();
        CustomerSummaryActions.Draft byName = CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Intro', 'dueDate' => 'today', 'contact' => 'Sam Stone' });
        CustomerSummaryActions.Draft ready = CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Intro', 'dueDate' => 'today', 'contact' => 'Maria' });
        Map<String, Object> changed = (Map<String, Object>) JSON.deserializeUntyped(ready.inputJson);
        changed.put('contactId', sam.Id);
        ready.inputJson = JSON.serialize(changed);
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(ready);
        Test.stopTest();
        Assert.areEqual('No contact matches "Sam Stone" on this account. Pick one or clear the field.', field(byName, 'WhoId').error);
        Assert.areEqual(CustomerSummaryActions.REFUSED, r.status, 'commit checks the draft again');
        Assert.areEqual('Nothing was saved. This draft still needs: Contact.', r.message);
        Assert.areEqual(0, [SELECT COUNT() FROM Task]);
    }

    @IsTest
    static void aFailedOutcomeNeverUndoesTheAction() {
        Id accountId = acme();
        CustomerOutcomes.failWritesForTest = true;
        Test.startTest();
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(CustomerSummaryActions.draft('create_task', accountId,
            new Map<String, Object>{ 'subject' => 'Send pricing', 'dueDate' => 'today' }));
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.OK, r.status);
        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE Id = :r.recordId], 'the task stands');
        Assert.areEqual(0, outcomesFor(r.recordId));
    }

    // ------------------------------------------------------------------ create_event and log_call

    @IsTest
    static void anEventReadsItsStartAndLength() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_event', accountId, new Map<String, Object>{
            'subject' => 'Demo', 'startDateTime' => 'next Tuesday at 2pm', 'durationMinutes' => '45 minutes', 'contact' => 'Maria'
        });
        CustomerSummaryActions.Draft plain = CustomerSummaryActions.draft('create_event', accountId,
            new Map<String, Object>{ 'subject' => 'Sync', 'startDateTime' => 'tomorrow at 9am' });
        Assert.areEqual(0, Limits.getDmlStatements());
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, plain.status);
        Assert.areEqual('2026-11-14T09:30', field(plain, 'EndDateTime').value, 'no length said is 30 minutes');
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Event e = [SELECT StartDateTime, EndDateTime, WhoId, WhatId FROM Event WHERE Id = :r.recordId];
        Assert.areEqual(Datetime.newInstance(2026, 11, 17, 14, 0, 0), e.StartDateTime);
        Assert.areEqual(Datetime.newInstance(2026, 11, 17, 14, 45, 0), e.EndDateTime);
        Assert.areEqual(mariaId, e.WhoId);
        Assert.areEqual(accountId, e.WhatId);
        Assert.areEqual(1, outcomesFor(r.recordId));
    }

    @IsTest
    static void anEventThatEndsBeforeItStartsNeedsInput() {
        Id accountId = acme();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_event', accountId, new Map<String, Object>{
            'subject' => 'Demo', 'startDateTime' => 'tomorrow at 3pm', 'endDateTime' => 'tomorrow at 2pm'
        });
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual('The end must be after the start.', field(d, 'EndDateTime').error);
        CustomerSummaryActions.Draft noTime = CustomerSummaryActions.draft('create_event', accountId,
            new Map<String, Object>{ 'subject' => 'Demo', 'startDateTime' => 'tomorrow' });
        Assert.areEqual('I couldn\'t read "tomorrow" as a day and a time.', field(noTime, 'StartDateTime').error);
        CustomerSummaryActions.Draft badLength = CustomerSummaryActions.draft('create_event', accountId,
            new Map<String, Object>{ 'subject' => 'Demo', 'startDateTime' => 'tomorrow at 3pm', 'durationMinutes' => 'a while' });
        Assert.areEqual('I couldn\'t read "a while" as a length of time.', field(badLength, 'EndDateTime').error);
    }

    @IsTest
    static void aLoggedCallIsAFifteenMinuteEventEndingNow() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('log_call', accountId,
            new Map<String, Object>{ 'contact' => 'Maria', 'description' => 'Wants a quote' });
        Assert.areEqual(0, Limits.getDmlStatements());
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual('Event', d.objectName, 'F17');
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Assert.areEqual('Call logged', r.title);
        Event e = [SELECT Subject, Description, StartDateTime, EndDateTime, WhoId FROM Event WHERE Id = :r.recordId];
        Assert.areEqual('Call', e.Subject);
        Assert.areEqual('Wants a quote', e.Description);
        Assert.areEqual(NOW.addMinutes(-CustomerSummaryActions.CALL_MINUTES), e.StartDateTime);
        Assert.areEqual(NOW, e.EndDateTime);
        Assert.areEqual(mariaId, e.WhoId);
    }

    @IsTest
    static void aLoggedCallCanBeACompletedTask() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        CustomerSummaryActions.logCallAs = 'Task';
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('log_call', accountId,
            new Map<String, Object>{ 'contact' => 'Maria', 'subject' => 'Pricing call' });
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual('Task', d.objectName);
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Task t = [SELECT Subject, Status, TaskSubtype, ActivityDate, WhoId FROM Task WHERE Id = :r.recordId];
        Assert.areEqual('Pricing call', t.Subject);
        Assert.areEqual('Completed', t.Status);
        Assert.areEqual('Call', t.TaskSubtype);
        Assert.areEqual(NOW.date(), t.ActivityDate);
        Assert.areEqual(mariaId, t.WhoId);
    }

    @IsTest
    static void aLoggedCallNeedsAContact() {
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('log_call', acme(), new Map<String, Object>());
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual(new List<String>{ 'WhoId' }, d.missing);
        Assert.areEqual('Call', field(d, 'Subject').value, 'the subject defaults to Call');
    }

    // ------------------------------------------------------------------ create_case

    @IsTest
    static void aCaseGoesOnTheAccountWithItsContactAndPriority() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_case', accountId, new Map<String, Object>{
            'subject' => 'Portal is down', 'priority' => 'high', 'contact' => 'Maria', 'description' => 'Since 9am'
        });
        Assert.areEqual(0, Limits.getDmlStatements());
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Case c = [SELECT Subject, Priority, AccountId, ContactId, Description FROM Case WHERE Id = :r.recordId];
        Assert.areEqual('Portal is down', c.Subject);
        Assert.areEqual('High', c.Priority, 'a picklist matches its value in any case');
        Assert.areEqual(accountId, c.AccountId);
        Assert.areEqual(mariaId, c.ContactId);
        Assert.areEqual('Since 9am', c.Description);
    }

    @IsTest
    static void aPriorityThatIsNotAValueNeedsInput() {
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('create_case', acme(),
            new Map<String, Object>{ 'subject' => 'Portal is down', 'priority' => 'Urgentest' });
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual('"Urgentest" can\'t be used as the priority.', field(d, 'Priority').error);
    }

    // ------------------------------------------------------------------ refusals

    @IsTest
    static void anUnknownActionOrAnUnseenAccountIsRefused() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        CustomerSummaryActions.Draft unknown = CustomerSummaryActions.draft('send_email', accountId, new Map<String, Object>());
        Assert.areEqual(CustomerSummaryActions.REFUSED, unknown.status);
        Assert.areEqual(CustomerSummaryActions.UNKNOWN_ACTION_TEXT, unknown.message);
        Assert.areEqual(1, unknown.cards[0].controls.size(), 'a refused draft offers only Cancel');
        Assert.areEqual('cancel', unknown.cards[0].controls[0].key);
        CustomerSummaryActions.Draft noAccount = CustomerSummaryActions.draft('create_task', null, new Map<String, Object>());
        Assert.areEqual(CustomerSummaryActions.NO_ACCOUNT_TEXT, noAccount.message);
        CustomerSummaryActions.Draft notAccount = CustomerSummaryActions.draft('create_task', mariaId, new Map<String, Object>());
        Assert.areEqual(CustomerSummaryActions.NO_ACCOUNT_TEXT, notAccount.message);
        CustomerSummaryActions.Draft badJson = CustomerSummaryActions.draftJson('create_task', accountId, '[1, 2]');
        Assert.areEqual(CustomerSummaryActions.BAD_INPUT_TEXT, badJson.message);
        Assert.areEqual(CustomerSummaryActions.REFUSED, CustomerSummaryActions.commitDraft(null).status);
        Assert.areEqual(CustomerSummaryActions.REFUSED, CustomerSummaryActions.commitJson('not a draft').status);
    }

    /** A user who can read accounts and contacts (and see all of them) but edit nothing. */
    private static User readOnlyUser() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            String uniq = 'actro' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            u = new User(Alias = 'actro', Email = uniq + '@example.com', EmailEncodingKey = 'UTF-8', LastName = 'Actions Reader',
                LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
                Username = uniq + '@example.com.actionstest');
            insert u;
            PermissionSet ps = new PermissionSet(Name = 'Act_Read_' + uniq.right(8), Label = 'Actions read only');
            insert ps;
            insert new List<ObjectPermissions>{
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true, PermissionsViewAllRecords = true),
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Contact', PermissionsRead = true, PermissionsViewAllRecords = true)
            };
            insert new FieldPermissions(ParentId = ps.Id, SobjectType = 'Contact', Field = 'Contact.Title', PermissionsRead = true, PermissionsEdit = false);
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    @IsTest
    static void aUserWithoutEditRightsIsRefusedAtDraftAndAtCommit() {
        Id accountId = acme();
        Contact m = maria();
        User u = readOnlyUser();
        CustomerSummaryActions.Draft d;
        CustomerSummaryActions.Result r;
        Test.startTest();
        System.runAs(u) {
            d = CustomerSummaryActions.draft('update_contact', accountId,
                new Map<String, Object>{ 'contact' => 'Maria', 'changes' => new Map<String, Object>{ 'Title' => 'CEO' } });
            CustomerSummaryActions.Draft forged = new CustomerSummaryActions.Draft();
            forged.action = 'update_contact';
            forged.accountId = accountId;
            forged.status = CustomerSummaryActions.READY;
            forged.inputJson = JSON.serialize(new Map<String, Object>{ 'contactId' => m.Id, 'changes' => new Map<String, Object>{ 'Title' => 'CEO' } });
            r = CustomerSummaryActions.commitDraft(forged);
        }
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.REFUSED, d.status);
        Assert.areEqual('You can\'t edit contacts with your access.', d.message);
        Assert.areEqual(CustomerSummaryActions.REFUSED, r.status);
        Assert.areEqual('Nothing was saved. You can\'t edit contacts with your access.', r.message);
        Assert.areEqual('Buyer', maria().Title, 'nothing changed');
    }

    // ------------------------------------------------------------------ draftFromText

    @IsTest
    static void aSentenceBecomesADraftThroughTheModelSeam() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        Stub s = stub(new List<String>{
            'Here it is: {"action":"create_task","fields":{"subject":"Send Maria the pricing","dueDate":"next Tuesday","contact":"Maria"},"missing":[]}'
        });
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(accountId, 'Create a task to send Maria the pricing next Tuesday');
        Assert.areEqual(0, Limits.getDmlStatements());
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status, JSON.serialize(d.fields));
        Assert.areEqual('create_task', d.action);
        Assert.areEqual('2026-11-17', field(d, 'ActivityDate').value);
        Assert.areEqual(String.valueOf(mariaId), field(d, 'WhoId').value);
        Assert.areEqual(1, s.prompts.size());
        Assert.isTrue(s.prompts[0].contains('Today is 2026-11-13'), s.prompts[0]);
        Assert.isTrue(s.prompts[0].contains('The open account is Actions Acme.'), s.prompts[0]);
        Assert.isTrue(s.prompts[0].contains('Request: Create a task to send Maria the pricing next Tuesday'), s.prompts[0]);
    }

    @IsTest
    static void aSentenceMissingARequiredFieldNeedsInput() {
        stub(new List<String>{ '{"action":"create_task","fields":{"subject":"Call Maria back"},"missing":["dueDate"]}' });
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(acme(), 'Add a task to call Maria back');
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual(new List<String>{ 'ActivityDate' }, d.missing);
    }

    @IsTest
    static void aPersonTheRequestNeverNamedIsDropped() {
        stub(new List<String>{ '{"action":"log_call","fields":{"subject":"Renewal pricing","contact":"Maria Lopez"}}' });
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(acme(), 'Log a call about the renewal pricing');
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual(new List<String>{ 'WhoId' }, d.missing, 'BE-22: the model added a contact the request never named');
        Assert.isFalse(JSON.serialize(d).contains('Maria'), JSON.serialize(d));
    }

    @IsTest
    static void aModelThatSaysNoneOrNamesNoActionIsNotAnAction() {
        stub(new List<String>{ '{"action":"none"}', '{"action":"send_email","fields":{}}' });
        Id accountId = acme();
        Assert.areEqual(CustomerSummaryActions.NOT_AN_ACTION, CustomerSummaryActions.draftFromText(accountId, 'Update on the router deal?').status);
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(accountId, 'Make an email to Maria');
        Assert.areEqual(CustomerSummaryActions.NOT_AN_ACTION, d.status);
        Assert.areEqual(CustomerSummaryActions.NOT_AN_ACTION_TEXT, d.message);
    }

    @IsTest
    static void aModelFailureIsAnErrorWithTheFixedText() {
        stub(new List<String>{ 'THROW', 'Sure! I can help with that.' });
        Id accountId = acme();
        for (Integer n = 0; n < 2; n++) {
            CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(accountId, 'Create a task for tomorrow');
            Assert.areEqual(CustomerSummaryActions.ERROR, d.status);
            Assert.areEqual(CustomerSummaryActions.MODEL_TEXT, d.message);
            Assert.areEqual('error', d.cards[0].type);
            Assert.isFalse(JSON.serialize(d).contains('raw platform text'));
        }
    }

    @IsTest
    static void aSentenceForAnUnseenAccountIsRefusedWithNoModelCall() {
        Stub s = stub(new List<String>());
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(maria().Id, 'Create a task for tomorrow');
        Assert.areEqual(CustomerSummaryActions.REFUSED, d.status);
        Assert.areEqual(0, s.prompts.size());
    }

    // ------------------------------------------------------------------ the invocables

    @IsTest
    static void theDraftAndCommitInvocablesWriteOnlyAConfirmedDraft() {
        Id accountId = acme();
        Id mariaId = maria().Id;
        stub(new List<String>{ '{"action":"create_task","fields":{"subject":"Send pricing","dueDate":"tomorrow","contact":"Maria"}}' });
        CustomerSummaryActionDraftAction.Request byText = new CustomerSummaryActionDraftAction.Request();
        byText.accountId = accountId;
        byText.text = 'Create a task to send Maria pricing tomorrow';
        CustomerSummaryActionDraftAction.Request byType = new CustomerSummaryActionDraftAction.Request();
        byType.accountId = accountId;
        byType.actionType = 'create_case';
        byType.inputJson = '{"subject":"Portal is down"}';
        CustomerSummaryActionDraftAction.Request bad = new CustomerSummaryActionDraftAction.Request();
        bad.accountId = accountId;
        bad.actionType = 'create_case';
        bad.inputJson = 'not json';
        Test.startTest();
        List<CustomerSummaryActionDraftAction.Response> drafts = CustomerSummaryActionDraftAction.draft(
            new List<CustomerSummaryActionDraftAction.Request>{ byText, byType, bad });
        Integer draftDml = Limits.getDmlStatements();
        CustomerSummaryActionCommitAction.Request confirm = new CustomerSummaryActionCommitAction.Request();
        confirm.draftJson = drafts[0].draftJson;
        CustomerSummaryActionCommitAction.Request junk = new CustomerSummaryActionCommitAction.Request();
        junk.draftJson = '{"action":"create_task"}';
        List<CustomerSummaryActionCommitAction.Response> results = CustomerSummaryActionCommitAction.commitDrafts(
            new List<CustomerSummaryActionCommitAction.Request>{ confirm, junk });
        Test.stopTest();
        Assert.areEqual(0, draftDml, 'drafting writes nothing');
        Assert.areEqual(CustomerSummaryActions.READY, drafts[0].status, drafts[0].draftText);
        Assert.isTrue(drafts[0].isSuccess);
        Assert.isTrue(drafts[0].draftText.contains('Contact: Maria Lopez'), drafts[0].draftText);
        Assert.isFalse(drafts[0].draftText.contains(String.valueOf(mariaId)), 'no Id in the text a user sees');
        Assert.isTrue(drafts[0].cards.contains('"actionDraft"'), drafts[0].cards);
        Assert.areEqual(CustomerSummaryActions.READY, drafts[1].status, drafts[1].draftText);
        Assert.isFalse(drafts[2].isSuccess);
        Assert.areEqual(CustomerSummaryActions.BAD_INPUT_TEXT, drafts[2].errorMessage);
        Assert.areEqual(CustomerSummaryActions.OK, results[0].status, results[0].message);
        Assert.isTrue(results[0].isSuccess);
        Assert.areEqual('Send pricing', [SELECT Subject FROM Task WHERE Id = :results[0].recordId].Subject);
        Assert.areEqual(CustomerSummaryActions.REFUSED, results[1].status);
        Assert.isFalse(results[1].isSuccess);
        Assert.isNull(results[1].recordId);
        Assert.areEqual(1, [SELECT COUNT() FROM Task], 'only the confirmed draft was written');
        Assert.areEqual(0, [SELECT COUNT() FROM Case], 'a draft alone writes nothing');
    }
}
