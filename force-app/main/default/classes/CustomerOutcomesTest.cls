/**
 * Customer outcomes (BE-35): each type and its retention, the purge batch, sharing through the account, the rule on
 * what others see (F79, F87), a read-only rep's write, remove, the invocable, listing and the outcome context.
 *
 * Reps here are the Minimum Access profile plus the product's data-access set and, when they work with outcomes,
 * the outcome set, which grants Read on Account (the outcome's master) and nothing else on it: a rep with read-only
 * access to the account. Removing the outcome set is how a rep loses the account. agent-probe's account sharing is
 * Public Read/Write, so record sharing cannot hide one, and outcome access cannot exist without Account read.
 */
@IsTest
private class CustomerOutcomesTest {

    private static User newUser(String profileName, String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = alias + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return new User(
            Alias = alias,
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Outcome ' + alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.outcometest'
        );
    }

    /** A rep: Minimum Access, the data-access set, and (when outcomes) the outcome set with its Account read. */
    private static User rep(String alias, Boolean dataAccess, Boolean outcomes) {
        User u = newUser('Minimum Access - Salesforce', alias);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('Customer_Summary_Data_Access', 'Customer_Summary_Outcome_Access')]) {
                if ((ps.Name == 'Customer_Summary_Data_Access' && dataAccess) || (ps.Name == OUTCOME_SET && outcomes)) {
                    grants.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
                }
            }
            insert grants;
        }
        return u;
    }

    private static final String OUTCOME_SET = 'Customer_Summary_Outcome_Access';

    private static void loseAccounts(User u) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSet.Name = :OUTCOME_SET];
        }
    }

    private static Account account(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Customer_Outcome_Type__mdt type(String name, String label, Decimal days, Boolean shares) {
        return new Customer_Outcome_Type__mdt(DeveloperName = name, MasterLabel = label, Retention_Days__c = days, Share_Text__c = shares);
    }

    /** The three types as they ship: summaries kept forever, the rest two years, none sharing its text. */
    private static void shippedTypes() {
        CustomerOutcomes.typesForTest = new Map<String, Customer_Outcome_Type__mdt>{
            'Summary' => type('Summary', 'Summary', null, false),
            'Action' => type('Action', 'Action', 730, false),
            'Saved_Answer' => type('Saved_Answer', 'Saved answer', 730, false)
        };
    }

    private static CustomerOutcomes.Input summary(Id accountId, String body) {
        CustomerOutcomes.Input i = new CustomerOutcomes.Input(accountId, CustomerOutcomes.SUMMARY);
        i.title = 'Summary';
        i.headline = body.substringBefore('\n');
        i.body = body;
        i.skill = 'summary';
        i.surface = 'panel';
        i.model = 'test-model';
        i.sentimentScore = 1;
        i.sentimentLabel = 'Positive';
        i.sentimentReason = 'Two renewals closed this quarter';
        return i;
    }

    private static CustomerOutcomes.Input taskAction(Id accountId, Id taskId) {
        CustomerOutcomes.Input i = new CustomerOutcomes.Input(accountId, CustomerOutcomes.ACTION);
        i.title = 'Call Dana about the renewal';
        i.headline = 'Task created: Call Dana about the renewal';
        i.body = 'Created a task "Call Dana about the renewal", due Friday.';
        i.relatedRecordId = taskId;
        i.skill = 'create_task';
        i.surface = 'panel';
        return i;
    }

    private static Customer_Outcome__c stored(Id outcomeId) {
        return [
            SELECT Id, Account__c, Outcome_Type__c, Title__c, Headline__c, Body__c, Related_Record_Id__c, Skill__c, Surface__c,
                Model__c, Sentiment_Score__c, Sentiment_Label__c, Sentiment_Reason__c, Expires__c, CreatedById
            FROM Customer_Outcome__c WHERE Id = :outcomeId WITH SYSTEM_MODE
        ];
    }

    // ------------------------------------------------------------------ types and retention

    @IsTest
    static void theShippedTypesExist() {
        Map<String, Customer_Outcome_Type__mdt> types = CustomerOutcomes.types();
        for (String name : new List<String>{ CustomerOutcomes.SUMMARY, CustomerOutcomes.ACTION, CustomerOutcomes.SAVED_ANSWER }) {
            Assert.isTrue(types.containsKey(name), 'type record ' + name + ' ships with the product');
        }
    }

    @IsTest
    static void aSummaryIsKeptForeverWithEveryField() {
        shippedTypes();
        User author = rep('oever', true, true);
        Account a = account('Outcome Forever');
        Id outcomeId;
        Test.startTest();
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(summary(a.Id, 'Renewal on track.\nTwo open cases.'));
        }
        Test.stopTest();

        Customer_Outcome__c row = stored(outcomeId);
        Assert.areEqual(a.Id, row.Account__c);
        Assert.areEqual('Summary', row.Outcome_Type__c);
        Assert.areEqual('Renewal on track.', row.Headline__c);
        Assert.areEqual('Renewal on track.\nTwo open cases.', row.Body__c);
        Assert.areEqual('summary', row.Skill__c);
        Assert.areEqual('panel', row.Surface__c);
        Assert.areEqual('test-model', row.Model__c);
        Assert.areEqual(1, row.Sentiment_Score__c);
        Assert.areEqual('Positive', row.Sentiment_Label__c);
        Assert.areEqual('Two renewals closed this quarter', row.Sentiment_Reason__c);
        Assert.isNull(row.Expires__c, 'a type with no retention keeps its outcomes forever');
    }

    @IsTest
    static void anActionAndASavedAnswerExpireAfterTheirTypesRetention() {
        shippedTypes();
        User author = rep('oret', true, true);
        Account a = account('Outcome Retention');
        CustomerOutcomes.Input saved = new CustomerOutcomes.Input(a.Id, 'saved answer');
        saved.title = 'Biggest open deal';
        saved.body = 'Orion expansion, 120,000.';
        List<Id> ids;
        System.runAs(author) {
            ids = CustomerOutcomes.recordAll(new List<CustomerOutcomes.Input>{ taskAction(a.Id, null), saved });
        }

        Assert.areEqual(2, ids.size());
        Assert.areEqual(Date.today().addDays(730), stored(ids[0]).Expires__c, 'an action lives two years');
        Customer_Outcome__c answer = stored(ids[1]);
        Assert.areEqual('Saved_Answer', answer.Outcome_Type__c, 'a type is matched by its label too');
        Assert.areEqual(Date.today().addDays(730), answer.Expires__c);
        Assert.areEqual('Biggest open deal', answer.Title__c);
        Assert.areEqual('Orion expansion, 120,000.', answer.Headline__c, 'the headline defaults to the first line of the body');
    }

    @IsTest
    static void aTypeWithItsOwnRetentionIsHonoured() {
        CustomerOutcomes.typesForTest = new Map<String, Customer_Outcome_Type__mdt>{ 'Note' => type('Note', 'Note', 30, false) };
        User author = rep('onote', true, true);
        Account a = account('Outcome Custom Type');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(new CustomerOutcomes.Input(a.Id, 'Note'));
        }
        Assert.areEqual(Date.today().addDays(30), stored(outcomeId).Expires__c, 'room for more types, each with its own retention');
    }

    @IsTest
    static void anUnknownTypeOrAMissingAccountIsRejected() {
        shippedTypes();
        Account a = account('Outcome Unknown Type');
        try {
            CustomerOutcomes.record(new CustomerOutcomes.Input(a.Id, 'Diary'));
            Assert.fail('an unknown type is rejected');
        } catch (CustomerOutcomes.OutcomeException e) {
            Assert.isTrue(e.getMessage().contains('Diary'), e.getMessage());
        }
        try {
            CustomerOutcomes.record(new CustomerOutcomes.Input(null, CustomerOutcomes.SUMMARY));
            Assert.fail('an outcome needs an account');
        } catch (CustomerOutcomes.OutcomeException e) {
            Assert.isTrue(e.getMessage().contains('account'), e.getMessage());
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    @IsTest
    static void theBatchDeletesOnlyExpiredOutcomes() {
        Account a = account('Outcome Purge');
        List<Customer_Outcome__c> rows = new List<Customer_Outcome__c>{
            new Customer_Outcome__c(Account__c = a.Id, Outcome_Type__c = 'Action', Expires__c = Date.today().addDays(-1)),
            new Customer_Outcome__c(Account__c = a.Id, Outcome_Type__c = 'Action', Expires__c = Date.today()),
            new Customer_Outcome__c(Account__c = a.Id, Outcome_Type__c = 'Summary', Expires__c = null)
        };
        insert as system rows;

        Test.startTest();
        Database.executeBatch(new CustomerOutcomeRetentionBatch(), 200);
        Test.stopTest();

        List<Customer_Outcome__c> left = [SELECT Id FROM Customer_Outcome__c WITH SYSTEM_MODE ORDER BY Expires__c NULLS LAST];
        Assert.areEqual(2, left.size(), 'only the outcome past its expiry date is deleted');
        Assert.isFalse(new Map<Id, Customer_Outcome__c>(left).containsKey(rows[0].Id));
    }

    @IsTest
    static void theBatchSeesEveryRepsOutcomes() {
        shippedTypes();
        User author = rep('opurge', true, true);
        Account a = account('Outcome Purge Others');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(taskAction(a.Id, null));
        }
        update as system new Customer_Outcome__c(Id = outcomeId, Expires__c = Date.today().addDays(-5));

        Test.startTest();
        Database.executeBatch(new CustomerOutcomeRetentionBatch(), 200);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    @IsTest
    static void theScheduleStartsTheBatch() {
        Test.startTest();
        Id jobId = System.schedule('Outcome retention test', CustomerOutcomeRetentionBatch.DAILY_CRON, new CustomerOutcomeRetentionBatch());
        Test.stopTest();
        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId WITH SYSTEM_MODE];
        Assert.areEqual(CustomerOutcomeRetentionBatch.DAILY_CRON, ct.CronExpression);
    }

    // ------------------------------------------------------------------ sharing and what others see

    @IsTest
    static void aReadOnlyRepStillHasTheirOutcomeRecorded() {
        shippedTypes();
        User reader = rep('oread', true, true);
        Account a = account('Outcome Read Only');
        Id outcomeId;
        System.runAs(reader) {
            Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Id = :a.Id WITH USER_MODE], 'the rep can read the account');
            Assert.isFalse(Schema.SObjectType.Account.isUpdateable(), 'the rep cannot edit accounts');
            outcomeId = CustomerOutcomes.record(summary(a.Id, 'Read-only summary.'));
        }
        Customer_Outcome__c row = stored(outcomeId);
        Assert.areEqual(reader.Id, row.CreatedById, 'the record is written as the rep');
        Assert.areEqual('Read-only summary.', row.Body__c);
    }

    @IsTest
    static void aRepWithoutTheOutcomeSetCannotRecord() {
        shippedTypes();
        User outsider = rep('onoset', true, false);
        Account a = account('Outcome No Access');
        System.runAs(outsider) {
            try {
                CustomerOutcomes.record(summary(a.Id, 'Should not save.'));
                Assert.fail('the record is written in user mode');
            } catch (Exception e) {
                Assert.isFalse(e instanceof CustomerOutcomes.OutcomeException, 'the platform refuses the insert: ' + e.getMessage());
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    @IsTest
    static void aRepWhoCannotSeeTheAccountSeesNoOutcomes() {
        shippedTypes();
        User author = rep('oauth', true, true);
        User stranger = rep('ostra', true, false);
        Account a = account('Outcome Hidden');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(summary(a.Id, 'Hidden summary.'));
        }
        System.runAs(stranger) {
            Assert.areEqual(0, CustomerOutcomes.listOutcomes(a.Id, null, 10).size());
            Assert.isNull(CustomerOutcomes.getOutcome(outcomeId));
            Assert.areEqual('', CustomerOutcomes.contextFor(a.Id));
        }
    }

    @IsTest
    static void anAuthorWhoLosesTheAccountLosesItsOutcomes() {
        shippedTypes();
        User author = rep('olose', true, true);
        Account a = account('Outcome Lost');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(summary(a.Id, 'Before the territory change.'));
            Assert.areEqual(1, CustomerOutcomes.listOutcomes(a.Id, null, 10).size());
        }
        loseAccounts(author);
        System.runAs(author) {
            Assert.areEqual(0, CustomerOutcomes.listOutcomes(a.Id, null, 10).size(), 'N6: memory no longer outlives access');
            Assert.isNull(CustomerOutcomes.getOutcome(outcomeId));
        }
    }

    @IsTest
    static void theAuthorSeesEverything() {
        shippedTypes();
        User author = rep('oself', true, true);
        Account a = account('Outcome Own');
        Task t = new Task(Subject = 'Call Dana about the renewal');
        insert t;
        System.runAs(author) {
            Id outcomeId = CustomerOutcomes.record(taskAction(a.Id, t.Id));
            CustomerOutcomes.Outcome o = CustomerOutcomes.getOutcome(outcomeId);
            Assert.isTrue(o.mine);
            Assert.isTrue(o.textShown);
            Assert.areEqual('Call Dana about the renewal', o.title);
            Assert.areEqual('Task created: Call Dana about the renewal', o.headline);
            Assert.areEqual('Created a task "Call Dana about the renewal", due Friday.', o.body);
            Assert.areEqual(String.valueOf(t.Id), o.relatedRecordId);
            Assert.areEqual('Action', o.type);
        }
    }

    @IsTest
    static void anotherRepSeesTypeDatePhraseAndLabelButNoText() {
        shippedTypes();
        User author = rep('oone', true, true);
        User other = rep('otwo', true, true);
        Account a = account('Outcome Others');
        Task t = new Task(Subject = 'Call Dana about the renewal');
        insert t;
        Id actionId;
        Id summaryId;
        System.runAs(author) {
            actionId = CustomerOutcomes.record(taskAction(a.Id, t.Id));
            summaryId = CustomerOutcomes.record(summary(a.Id, 'Deal at risk.\nDetails only the author could read.'));
        }
        System.runAs(other) {
            List<CustomerOutcomes.Outcome> listed = CustomerOutcomes.listOutcomes(a.Id, null, 10);
            Assert.areEqual(2, listed.size(), 'sharing follows the account');
            for (CustomerOutcomes.Outcome o : listed) {
                Assert.isFalse(o.mine);
                Assert.isFalse(o.textShown);
                Assert.isNotNull(o.createdDate);
                Assert.isNull(o.headline, 'no headline for another rep');
                Assert.isNull(o.body, 'no body for another rep');
                Assert.isNull(o.relatedRecordId, 'no record link for another rep');
                Assert.isNull(o.sentimentReason, 'no sentiment reason for another rep');
            }
            CustomerOutcomes.Outcome action = CustomerOutcomes.getOutcome(actionId);
            Assert.areEqual('Task created', action.title, 'a fixed phrase for the kind of action, never its title');
            Assert.isNull(action.body);
            CustomerOutcomes.Outcome summary = CustomerOutcomes.getOutcome(summaryId);
            Assert.areEqual('Summary', summary.title);
            Assert.areEqual('Positive', summary.sentimentLabel, 'the sentiment label is shown to anyone who sees the account');
            Assert.isNull(summary.body);
            Assert.isNull(summary.sentimentReason);
        }
    }

    @IsTest
    static void aTypeMarkedToShareShowsItsTextToOthers() {
        shippedTypes();
        CustomerOutcomes.typesForTest.put('Summary', type('Summary', 'Summary', null, true));
        User author = rep('oshr1', true, true);
        User other = rep('oshr2', true, true);
        Account a = account('Outcome Shared');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(summary(a.Id, 'Shared headline.\nShared body.'));
        }
        System.runAs(other) {
            CustomerOutcomes.Outcome o = CustomerOutcomes.getOutcome(outcomeId);
            Assert.isFalse(o.mine);
            Assert.isTrue(o.textShown);
            Assert.areEqual('Shared headline.\nShared body.', o.body);
            Assert.areEqual('Two renewals closed this quarter', o.sentimentReason);
            Assert.isTrue(CustomerOutcomes.contextFor(a.Id).contains('Shared headline.'));
        }
    }

    @IsTest
    static void noRepGetsTheTextFromAUserModeQuery() {
        shippedTypes();
        User author = rep('oqry1', true, true);
        User other = rep('oqry2', true, true);
        Account a = account('Outcome Query');
        System.runAs(author) {
            CustomerOutcomes.record(summary(a.Id, 'Private headline.\nPrivate body.'));
        }
        for (User u : new List<User>{ other, author }) {
            System.runAs(u) {
                Assert.areEqual(1, [SELECT COUNT() FROM Customer_Outcome__c WHERE Account__c = :a.Id WITH USER_MODE],
                    'the record itself follows the account');
                for (String field : new List<String>{ 'Body__c', 'Headline__c', 'Title__c', 'Sentiment_Reason__c' }) {
                    try {
                        Database.query('SELECT ' + field + ' FROM Customer_Outcome__c', AccessLevel.USER_MODE);
                        Assert.fail(field + ' is readable in user mode');
                    } catch (QueryException e) {
                        Assert.isTrue(e.getMessage().contains(field) || e.getMessage().contains('access'), e.getMessage());
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ remove

    @IsTest
    static void anAuthorRemovesTheirOwnOutcome() {
        shippedTypes();
        User author = rep('orem1', true, true);
        Account a = account('Outcome Remove');
        System.runAs(author) {
            Id outcomeId = CustomerOutcomes.record(taskAction(a.Id, null));
            CustomerOutcomes.remove(outcomeId);
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    @IsTest
    static void aRepCannotRemoveAnotherRepsOutcome() {
        shippedTypes();
        User author = rep('orem2', true, true);
        User other = rep('orem3', true, true);
        Account a = account('Outcome Remove Other');
        Id outcomeId;
        System.runAs(author) {
            outcomeId = CustomerOutcomes.record(taskAction(a.Id, null));
        }
        System.runAs(other) {
            try {
                CustomerOutcomes.remove(outcomeId);
                Assert.fail('only the author removes an outcome');
            } catch (CustomerOutcomes.OutcomeException e) {
                Assert.areEqual(CustomerOutcomes.NOT_YOURS_TEXT, e.getMessage());
            }
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    // ------------------------------------------------------------------ the invocable

    @IsTest
    static void theInvocableSavesAnAnswerAndNothingElse() {
        shippedTypes();
        User author = rep('oinv', true, true);
        Account a = account('Outcome Invocable');
        List<CustomerOutcomeSaveAnswer.Response> out;
        System.runAs(author) {
            CustomerOutcomeSaveAnswer.Request ok = new CustomerOutcomeSaveAnswer.Request();
            ok.accountId = a.Id;
            ok.title = 'Who signs the renewal';
            ok.answer = 'Dana Rivera, the CFO.';
            CustomerOutcomeSaveAnswer.Request blank = new CustomerOutcomeSaveAnswer.Request();
            blank.accountId = a.Id;
            out = CustomerOutcomeSaveAnswer.save(new List<CustomerOutcomeSaveAnswer.Request>{ ok, blank, null });
        }
        Assert.areEqual(3, out.size());
        Assert.isTrue(out[0].isSuccess, 'saved: ' + out[0].errorMessage);
        Assert.isFalse(out[1].isSuccess, 'an empty answer is not saved');
        Assert.isFalse(out[2].isSuccess);
        Customer_Outcome__c row = stored(out[0].outcomeId);
        Assert.areEqual('Saved_Answer', row.Outcome_Type__c, 'the invocable writes a saved answer only');
        Assert.areEqual('Dana Rivera, the CFO.', row.Body__c);
        Assert.isNull(row.Sentiment_Label__c);
        Assert.isNull(row.Sentiment_Score__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Outcome__c WITH SYSTEM_MODE]);
    }

    // ------------------------------------------------------------------ listing and the outcome context

    @IsTest
    static void listingIsNewestFirstFilteredAndCapped() {
        shippedTypes();
        User author = rep('olist', true, true);
        Account a = account('Outcome Listing');
        List<CustomerOutcomes.Input> inputs = new List<CustomerOutcomes.Input>();
        for (Integer i = 0; i < 4; i++) {
            inputs.add(taskAction(a.Id, null));
        }
        inputs.add(summary(a.Id, 'Newest summary.'));
        List<Id> ids;
        System.runAs(author) {
            ids = CustomerOutcomes.recordAll(inputs);
        }
        for (Integer i = 0; i < ids.size(); i++) {
            Test.setCreatedDate(ids[i], Datetime.now().addDays(i - 10));
        }

        System.runAs(author) {
            List<CustomerOutcomes.Outcome> all = CustomerOutcomes.listOutcomes(a.Id, null, null);
            Assert.areEqual(5, all.size());
            Assert.areEqual(ids[4], all[0].id, 'newest first');
            Assert.areEqual(ids[0], all[4].id);
            Assert.areEqual('Newest summary.', all[0].headline, 'the author sees the headline in the list');
            Assert.isNull(all[0].body, 'the list carries no body; getOutcome does');

            List<CustomerOutcomes.Outcome> actions = CustomerOutcomes.listOutcomes(a.Id, new List<String>{ 'Action' }, 2);
            Assert.areEqual(2, actions.size());
            Assert.areEqual(ids[3], actions[0].id);
            Assert.areEqual(0, CustomerOutcomes.listOutcomes(null, null, 5).size());
        }
    }

    @IsTest
    static void theContextGivesTheAuthorTheLastSummaryHeadlineAndRecentActions() {
        shippedTypes();
        User author = rep('octx1', true, true);
        Account a = account('Outcome Context');
        System.runAs(author) {
            CustomerOutcomes.record(summary(a.Id, 'Renewal on track.\nMore.'));
            CustomerOutcomes.record(taskAction(a.Id, null));
            String ctx = CustomerOutcomes.contextFor(a.Id);
            Assert.isTrue(ctx.startsWith(CustomerOutcomes.CONTEXT_HEADER), ctx);
            Assert.isTrue(ctx.contains('Renewal on track.'), ctx);
            Assert.isTrue(ctx.contains(Datetime.now().format('yyyy-MM-dd')), ctx);
            Assert.isTrue(ctx.contains('Task created: Call Dana about the renewal'), ctx);
            Assert.isFalse(ctx.contains('More.'), 'only the headline, never the body: ' + ctx);
        }
    }

    @IsTest
    static void oneRepsHeadlineNeverReachesAnotherRepsContext() {
        shippedTypes();
        User author = rep('octx2', true, true);
        User other = rep('octx3', true, true);
        Account a = account('Outcome Context Others');
        System.runAs(author) {
            CustomerOutcomes.record(summary(a.Id, 'Secret headline.\nMore.'));
            CustomerOutcomes.record(taskAction(a.Id, null));
        }
        System.runAs(other) {
            String ctx = CustomerOutcomes.contextFor(a.Id);
            Assert.isTrue(ctx.contains('Summary, ' + Datetime.now().format('yyyy-MM-dd')), ctx);
            Assert.isTrue(ctx.contains('Action, '), ctx);
            Assert.isFalse(ctx.contains('Secret headline.'), ctx);
            Assert.isFalse(ctx.contains('Call Dana'), ctx);
            Assert.isFalse(ctx.contains('Task created'), 'only type and date for another rep: ' + ctx);
        }
    }

    @IsTest
    static void theContextIsCapped() {
        shippedTypes();
        Account a = account('Outcome Context Cap');
        List<CustomerOutcomes.Input> inputs = new List<CustomerOutcomes.Input>{ summary(a.Id, 'S'.repeat(250)) };
        for (Integer i = 0; i < 12; i++) {
            CustomerOutcomes.Input act = taskAction(a.Id, null);
            act.headline = 'H'.repeat(250);
            inputs.add(act);
        }
        User author = rep('ocap', true, true);
        Account empty = account('Outcome Context Empty');
        System.runAs(author) {
            CustomerOutcomes.recordAll(inputs);

            String ctx = CustomerOutcomes.contextFor(a.Id);
            List<String> lines = ctx.split('\n');
            Assert.areEqual(1 + 1 + CustomerOutcomes.CONTEXT_ITEMS, lines.size(), 'header, the last summary and the last few others: ' + ctx);
            Assert.isTrue(ctx.length() <= CustomerOutcomes.CONTEXT_CHARS, 'context length ' + ctx.length());
            Assert.areEqual('', CustomerOutcomes.contextFor(empty.Id), 'no outcomes, no context');
        }
    }

    // ------------------------------------------------------------------ helpers

    @IsTest
    static void removingAnOutcomeThatIsNotThereSaysSo() {
        for (Id missing : new List<Id>{ null, UserInfo.getUserId() }) {
            try {
                CustomerOutcomes.remove(missing);
                Assert.fail('nothing to remove');
            } catch (CustomerOutcomes.OutcomeException e) {
                Assert.areEqual(CustomerOutcomes.NOT_FOUND_TEXT, e.getMessage());
            }
        }
    }

    @IsTest
    static void theSurfaceAndModelAreNamed() {
        Assert.areEqual('test', CustomerOutcomes.currentSurface());
        Assert.isTrue(String.isNotBlank(CustomerOutcomes.modelFor('SummarySynthesis')));
        Assert.isTrue(String.isNotBlank(CustomerOutcomes.modelFor('No such prompt')));
        Assert.isNull(CustomerOutcomes.getOutcome(null));
        Assert.areEqual('', CustomerOutcomes.contextForVisibleAccount(null));
    }
}
