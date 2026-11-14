/**
 * CustomerSummaryActionUpdatesTest: update_contact and update_opportunity, their allow-lists and checks, and undo
 * (BE-27). An update shows each value before, writes only allow-listed fields as the user, and can be undone for 15
 * seconds by a token that carries the previous values. The clock is fixed at Friday 2026-11-13 10:00.
 */
@IsTest
private class CustomerSummaryActionUpdatesTest {
    private static final Datetime NOW = Datetime.newInstance(2026, 11, 13, 10, 0, 0);
    private static final Date CLOSE = Date.newInstance(2026, 12, 15);

    @TestSetup
    static void data() {
        Account a = new Account(Name = 'Updates Acme');
        Account other = new Account(Name = 'Updates Other');
        insert new List<Account>{ a, other };
        insert new List<Contact>{
            new Contact(AccountId = a.Id, FirstName = 'Maria', LastName = 'Lopez', Title = 'Buyer'),
            new Contact(AccountId = other.Id, FirstName = 'Sam', LastName = 'Stone', Title = 'Owner')
        };
        insert new List<Opportunity>{
            new Opportunity(AccountId = a.Id, Name = 'Router Refresh', StageName = 'Prospecting', Amount = 1000, CloseDate = CLOSE),
            new Opportunity(AccountId = a.Id, Name = 'Old Deal', StageName = 'Closed Won', CloseDate = CLOSE.addDays(-90))
        };
    }

    private static Id acme() {
        CustomerSummaryActions.nowForTest = NOW;
        return [SELECT Id FROM Account WHERE Name = 'Updates Acme' LIMIT 1].Id;
    }

    private static Contact maria() {
        return [SELECT Id, Title, Department, LastName FROM Contact WHERE LastName = 'Lopez' LIMIT 1];
    }

    private static Opportunity router() {
        return [SELECT Id, StageName, Amount, CloseDate, NextStep FROM Opportunity WHERE Name = 'Router Refresh' LIMIT 1];
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
        return [SELECT COUNT() FROM Customer_Outcome__c WHERE Related_Record_Id__c = :related];
    }

    private static CustomerSummaryActions.Draft contactDraft(Id accountId, Map<String, Object> changes) {
        return CustomerSummaryActions.draft('update_contact', accountId,
            new Map<String, Object>{ 'contact' => 'Maria', 'changes' => changes });
    }

    /** An open stage other than the first, read from the org so the test holds in any org. */
    private static String anotherOpenStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (e.isActive() && e.getValue() != 'Prospecting' && !e.getValue().startsWith('Closed')) {
                return e.getValue();
            }
        }
        return null;
    }

    /** A token with one member changed, as a caller might forge it. */
    private static String forged(String token, String key, Object value) {
        Map<String, Object> t = (Map<String, Object>) JSON.deserializeUntyped(EncodingUtil.base64Decode(token).toString());
        t.put(key, value);
        return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(t)));
    }

    // ------------------------------------------------------------------ update_contact

    @IsTest
    static void aContactUpdateShowsTheValuesBeforeAndUndoRestoresThem() {
        Id accountId = acme();
        Contact before = maria();
        Test.startTest();
        CustomerSummaryActions.Draft d = contactDraft(accountId, new Map<String, Object>{ 'Title' => 'VP Sales', 'Department' => 'Operations' });
        Assert.areEqual(0, Limits.getDmlStatements(), 'a draft writes nothing');
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Contact changed = maria();
        Integer outcomesAfterCommit = outcomesFor(before.Id);
        CustomerSummaryActions.nowForTest = NOW.addSeconds(10);
        CustomerSummaryActions.Result u = CustomerSummaryActions.undo(r.undoToken);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status, JSON.serialize(d.fields));
        Assert.areEqual(before.Id, d.targetId);
        Assert.areEqual('Maria Lopez', d.targetLabel);
        Assert.areEqual('Buyer', field(d, 'Title').previous);
        Assert.areEqual('blank', field(d, 'Department').previous);
        Assert.isTrue(d.cards[0].text.contains('Title: VP Sales (was Buyer)'), d.cards[0].text);
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Assert.areEqual('Contact updated', r.title);
        Assert.areEqual(CustomerSummaryActions.SAVED_TEXT + ' ' + CustomerSummaryActions.UNDO_OFFER_TEXT, r.message);
        Assert.isNotNull(r.undoToken);
        Assert.areEqual('undo', r.cards[0].controls[1].key);
        Assert.areEqual('VP Sales', changed.Title);
        Assert.areEqual('Operations', changed.Department);
        Assert.areEqual(1, outcomesAfterCommit, 'one Action outcome');
        Assert.areEqual(CustomerSummaryActions.OK, u.status, u.message);
        Assert.areEqual('Change undone', u.title);
        Assert.areEqual(CustomerSummaryActions.UNDONE_TEXT, u.message);
        Contact restored = maria();
        Assert.areEqual('Buyer', restored.Title);
        Assert.isNull(restored.Department, 'a blank value before is blank again');
        Assert.areEqual(0, outcomesFor(before.Id), 'undo removes the outcome');
    }

    @IsTest
    static void undoIsOfferedForFifteenSecondsOnly() {
        Id accountId = acme();
        Test.startTest();
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(contactDraft(accountId, new Map<String, Object>{ 'Title' => 'VP Sales' }));
        CustomerSummaryActions.nowForTest = NOW.addSeconds(CustomerSummaryActions.UNDO_SECONDS + 1);
        CustomerSummaryActions.Result late = CustomerSummaryActions.undo(r.undoToken);
        CustomerSummaryActions.nowForTest = NOW.addSeconds(-1);
        CustomerSummaryActions.Result early = CustomerSummaryActions.undo(r.undoToken);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.REFUSED, late.status);
        Assert.areEqual(CustomerSummaryActions.UNDO_EXPIRED_TEXT, late.message);
        Assert.areEqual(CustomerSummaryActions.REFUSED, early.status, 'a token from the future is not honoured');
        Assert.areEqual('VP Sales', maria().Title, 'nothing changed');
        Assert.areEqual(1, outcomesFor(maria().Id), 'the outcome stays');
    }

    @IsTest
    static void aChangedTokenChangesNothing() {
        Id accountId = acme();
        Contact sam = [SELECT Id FROM Contact WHERE LastName = 'Stone' LIMIT 1];
        Test.startTest();
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(contactDraft(accountId, new Map<String, Object>{ 'Title' => 'VP Sales' }));
        List<String> tokens = new List<String>{
            forged(r.undoToken, 'previous', new Map<String, Object>{ 'Title' => 'Buyer', 'OwnerId' => UserInfo.getUserId() }),
            forged(r.undoToken, 'previous', new Map<String, Object>{ 'LastName' => 'Hacked' }),
            forged(r.undoToken, 'targetId', sam.Id),
            forged(r.undoToken, 'action', 'create_task'),
            forged(r.undoToken, 'v', 2),
            forged(r.undoToken, 'targetId', accountId),
            'not-a-token',
            EncodingUtil.base64Encode(Blob.valueOf('{"v":1}')),
            null
        };
        List<CustomerSummaryActions.Result> results = new List<CustomerSummaryActions.Result>();
        for (String t : tokens) {
            results.add(CustomerSummaryActions.undo(t));
        }
        Test.stopTest();
        for (Integer n = 0; n < results.size(); n++) {
            Assert.areEqual(CustomerSummaryActions.REFUSED, results[n].status, 'token ' + n);
            Assert.areEqual(CustomerSummaryActions.UNDO_BAD_TEXT, results[n].message, 'token ' + n);
        }
        Assert.areEqual('VP Sales', maria().Title);
        Assert.areEqual('Lopez', maria().LastName);
        Assert.areEqual('Owner', [SELECT Title FROM Contact WHERE Id = :sam.Id].Title, 'another account\'s contact is untouched');
    }

    @IsTest
    static void onlyAllowListedFieldsChangeAndTheRestAreNamed() {
        Id accountId = acme();
        Test.startTest();
        CustomerSummaryActions.Draft d = contactDraft(accountId,
            new Map<String, Object>{ 'Title' => 'CEO', 'LastName' => 'Hacked', 'OwnerId' => UserInfo.getUserId() });
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status);
        Assert.isTrue(d.warnings.contains('"lastname" can\'t be changed here, so it was left out.'), String.valueOf(d.warnings));
        Assert.isTrue(d.warnings.contains('"ownerid" can\'t be changed here, so it was left out.'), String.valueOf(d.warnings));
        Assert.isFalse(d.inputJson.toLowerCase().contains('lastname'), d.inputJson);
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Contact c = maria();
        Assert.areEqual('CEO', c.Title);
        Assert.areEqual('Lopez', c.LastName, 'a field off the allow-list is never written');
    }

    @IsTest
    static void aContactUpdateChecksItsValues() {
        Id accountId = acme();
        CustomerSummaryActions.Draft email = contactDraft(accountId, new Map<String, Object>{ 'Email' => 'not-an-email' });
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, email.status);
        Assert.areEqual('"not-an-email" can\'t be used as the email.', field(email, 'Email').error);
        CustomerSummaryActions.Draft blank = contactDraft(accountId, new Map<String, Object>{ 'Title' => ' ' });
        Assert.areEqual('Give a new value for Title.', field(blank, 'Title').error);
        CustomerSummaryActions.Draft none = contactDraft(accountId, new Map<String, Object>());
        Assert.areEqual(new List<String>{ 'changes' }, none.missing);
        CustomerSummaryActions.Draft nobody = CustomerSummaryActions.draft('update_contact', accountId,
            new Map<String, Object>{ 'changes' => new Map<String, Object>{ 'Title' => 'CEO' } });
        Assert.areEqual(new List<String>{ 'Id' }, nobody.missing, 'an update needs its record');
        CustomerSummaryActions.Draft stranger = CustomerSummaryActions.draft('update_contact', accountId,
            new Map<String, Object>{ 'contact' => 'Sam', 'changes' => new Map<String, Object>{ 'Title' => 'CEO' } });
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, stranger.status, 'a contact on another account never resolves');
    }

    @IsTest
    static void aValueThePlatformRejectsSavesNothing() {
        Id accountId = acme();
        Test.startTest();
        CustomerSummaryActions.Draft d = contactDraft(accountId, new Map<String, Object>{ 'Title' => 'x'.repeat(200) });
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status);
        Assert.areEqual(CustomerSummaryActions.ERROR, r.status);
        Assert.isTrue(r.message.startsWith(CustomerSummaryActions.NOTHING_SAVED_TEXT), r.message);
        Assert.isFalse(r.message.contains('DmlException'), 'plain words, never the exception type');
        Assert.isNull(r.undoToken);
        Assert.isNull(r.recordId);
        Assert.areEqual('Buyer', maria().Title);
        Assert.areEqual(0, outcomesFor(maria().Id));
    }

    // ------------------------------------------------------------------ update_opportunity

    @IsTest
    static void anOpportunityUpdateWritesTypedValuesAndUndoRestoresThem() {
        Id accountId = acme();
        String stage = anotherOpenStage();
        Assert.isNotNull(stage, 'the org has a second open stage');
        Test.startTest();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('update_opportunity', accountId, new Map<String, Object>{
            'opportunity' => 'the router deal',
            'changes' => new Map<String, Object>{
                'StageName' => stage.toUpperCase(), 'CloseDate' => 'end of next month', 'Amount' => '$50k', 'NextStep' => 'Legal review'
            }
        });
        Assert.areEqual(0, Limits.getDmlStatements());
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Opportunity changed = router();
        CustomerSummaryActions.nowForTest = NOW.addSeconds(5);
        CustomerSummaryActions.Result u = CustomerSummaryActions.undo(r.undoToken);
        Test.stopTest();
        Assert.areEqual(CustomerSummaryActions.READY, d.status, JSON.serialize(d.fields));
        Assert.areEqual('Router Refresh', d.targetLabel);
        Assert.areEqual('Prospecting', field(d, 'StageName').previous);
        Assert.areEqual('2026-12-31', field(d, 'CloseDate').value);
        Assert.areEqual('blank', field(d, 'NextStep').previous);
        Assert.areEqual(CustomerSummaryActions.OK, r.status, r.message);
        Assert.areEqual(stage, changed.StageName);
        Assert.areEqual(Date.newInstance(2026, 12, 31), changed.CloseDate);
        Assert.areEqual(50000, changed.Amount.intValue());
        Assert.areEqual('Legal review', changed.NextStep);
        Assert.areEqual(CustomerSummaryActions.OK, u.status, u.message);
        Opportunity restored = router();
        Assert.areEqual('Prospecting', restored.StageName);
        Assert.areEqual(CLOSE, restored.CloseDate);
        Assert.areEqual(1000, restored.Amount.intValue());
        Assert.isNull(restored.NextStep);
    }

    @IsTest
    static void anOpportunityUpdateChecksItsValues() {
        Id accountId = acme();
        CustomerSummaryActions.Draft d = CustomerSummaryActions.draft('update_opportunity', accountId, new Map<String, Object>{
            'opportunity' => 'Router Refresh',
            'changes' => new Map<String, Object>{ 'StageName' => 'Blorp', 'CloseDate' => 'someday', 'Amount' => 'lots' }
        });
        Assert.areEqual(CustomerSummaryActions.NEEDS_INPUT, d.status);
        Assert.areEqual('"Blorp" can\'t be used as the stage.', field(d, 'StageName').error);
        Assert.areEqual('"someday" can\'t be used as the close date.', field(d, 'CloseDate').error);
        Assert.areEqual('"lots" can\'t be used as the amount.', field(d, 'Amount').error);
        CustomerSummaryActions.Result r = CustomerSummaryActions.commitDraft(d);
        Assert.areEqual(CustomerSummaryActions.REFUSED, r.status);
        Assert.areEqual('Nothing was saved. This draft still needs: Change.', r.message);
        Assert.areEqual(1000, router().Amount.intValue());
    }

    @IsTest
    static void aClosedOpportunityIsNeverUpdated() {
        Id accountId = acme();
        Opportunity closed = [SELECT Id FROM Opportunity WHERE Name = 'Old Deal' LIMIT 1];
        CustomerSummaryActions.Draft byName = CustomerSummaryActions.draft('update_opportunity', accountId, new Map<String, Object>{
            'opportunity' => 'Old Deal', 'changes' => new Map<String, Object>{ 'NextStep' => 'Reopen' }
        });
        Assert.areEqual('No open opportunity matches "Old Deal" on this account. Pick one or clear the field.', field(byName, 'Id').error);
        CustomerSummaryActions.Draft byId = CustomerSummaryActions.draft('update_opportunity', accountId, new Map<String, Object>{
            'opportunityId' => closed.Id, 'changes' => new Map<String, Object>{ 'NextStep' => 'Reopen' }
        });
        Assert.areEqual('That opportunity is not open on this account, or you can\'t see it.', field(byId, 'Id').error);
        Assert.areEqual(CustomerSummaryActions.REFUSED, CustomerSummaryActions.commitDraft(byId).status);
    }
}
