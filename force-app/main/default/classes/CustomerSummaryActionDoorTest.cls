/**
 * CustomerSummaryActionDoorTest: the MCP door's allow-list (OPS-59). Through draft_action and commit_action
 * (CustomerSummaryActionDraftAction, CustomerSummaryActionCommitAction) only create_task and log_call are allowed;
 * any other action gets the fixed refusal and writes nothing. The panel calls CustomerSummaryActions, which keeps
 * all six. The clock is fixed at Friday 2026-11-13 10:00; the model is a stub and never reached.
 */
@IsTest
private class CustomerSummaryActionDoorTest {
    private static final Datetime NOW = Datetime.newInstance(2026, 11, 13, 10, 0, 0);

    /** Scripted replies in order; never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        Integer calls = 0;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            calls++;
            return replies.isEmpty() ? '{"action":"none"}' : replies.remove(0);
        }
    }

    @TestSetup
    static void data() {
        Account a = new Account(Name = 'Door Acme');
        insert a;
        insert new Contact(AccountId = a.Id, FirstName = 'Maria', LastName = 'Lopez', Title = 'Buyer');
    }

    private static Id acme() {
        CustomerSummaryActions.nowForTest = NOW;
        return [SELECT Id FROM Account WHERE Name = 'Door Acme' LIMIT 1].Id;
    }

    private static CustomerSummaryActionDraftAction.Request byType(Id accountId, String actionType, String inputJson) {
        CustomerSummaryActionDraftAction.Request r = new CustomerSummaryActionDraftAction.Request();
        r.accountId = accountId;
        r.actionType = actionType;
        r.inputJson = inputJson;
        return r;
    }

    /** A draft as JSON, the way draft_action returns it (without its card). */
    private static String asJson(CustomerSummaryActions.Draft d) {
        d.cards = new List<AnswerCard>();
        return JSON.serialize(d);
    }

    private static Integer written() {
        Integer cases = [SELECT COUNT() FROM Case];
        Integer tasks = [SELECT COUNT() FROM Task];
        Integer events = [SELECT COUNT() FROM Event];
        return cases + tasks + events;
    }

    @IsTest
    static void anActionTheDoorDoesNotAllowIsRefusedAndWritesNothing() {
        Id accountId = acme();
        Id mariaId = [SELECT Id FROM Contact WHERE LastName = 'Lopez' LIMIT 1].Id;
        Stub s = new Stub();
        s.replies = new List<String>{ '{"action":"create_case","fields":{"subject":"Portal is down"}}' };
        AgentLlm.stub = s;
        CustomerSummaryActionDraftAction.Request byText = new CustomerSummaryActionDraftAction.Request();
        byText.accountId = accountId;
        byText.text = 'Create a case that the portal is down';
        // A draft the panel could make, sent straight to commit_action by a client.
        String handMade = asJson(CustomerSummaryActions.draft('create_case', accountId,
            new Map<String, Object>{ 'subject' => 'Portal is down' }));
        String contactUpdate = asJson(CustomerSummaryActions.draft('update_contact', accountId,
            new Map<String, Object>{ 'contact' => 'Maria', 'changes' => new Map<String, Object>{ 'Title' => 'CFO' } }));
        CustomerSummaryActionCommitAction.Request commitCase = new CustomerSummaryActionCommitAction.Request();
        commitCase.draftJson = handMade;
        CustomerSummaryActionCommitAction.Request commitUpdate = new CustomerSummaryActionCommitAction.Request();
        commitUpdate.draftJson = contactUpdate;
        Test.startTest();
        List<CustomerSummaryActionDraftAction.Response> drafts = CustomerSummaryActionDraftAction.draft(
            new List<CustomerSummaryActionDraftAction.Request>{
                byType(accountId, 'update_contact', '{"contact":"Maria","changes":{"Title":"CFO"}}'),
                byType(accountId, 'CREATE_CASE', '{"subject":"Portal is down"}'),
                byText
            });
        List<CustomerSummaryActionCommitAction.Response> results = CustomerSummaryActionCommitAction.commitDrafts(
            new List<CustomerSummaryActionCommitAction.Request>{ commitCase, commitUpdate });
        Integer dml = Limits.getDmlStatements();
        Test.stopTest();
        Assert.areEqual(0, dml, 'a refused action writes nothing');
        Assert.areEqual(1, s.calls, 'the sentence was drafted, then refused for its action');
        for (CustomerSummaryActionDraftAction.Response d : drafts) {
            Assert.areEqual(CustomerSummaryActions.REFUSED, d.status, d.draftText);
            Assert.areEqual(CustomerSummaryActionDraftAction.DOOR_REFUSED_TEXT, d.message);
            Assert.areEqual(CustomerSummaryActionDraftAction.DOOR_REFUSED_TEXT, d.errorMessage);
            Assert.isFalse(d.isSuccess);
            Assert.isNull(d.draftJson, 'nothing to commit');
            Assert.isFalse(d.cards.contains('"actionDraft"'), d.cards);
        }
        for (CustomerSummaryActionCommitAction.Response r : results) {
            Assert.areEqual(CustomerSummaryActions.REFUSED, r.status, r.message);
            Assert.areEqual(CustomerSummaryActionDraftAction.DOOR_REFUSED_TEXT, r.message);
            Assert.isFalse(r.isSuccess);
            Assert.isNull(r.recordId);
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Case]);
        Assert.areEqual('Buyer', [SELECT Title FROM Contact WHERE Id = :mariaId].Title, 'the contact is unchanged');
    }

    @IsTest
    static void aLoggedCallThroughTheDoorIsDraftedThenWritten() {
        Id accountId = acme();
        Test.startTest();
        List<CustomerSummaryActionDraftAction.Response> drafts = CustomerSummaryActionDraftAction.draft(
            new List<CustomerSummaryActionDraftAction.Request>{
                byType(accountId, 'log_call', '{"contact":"Maria","description":"Wants a quote"}'),
                byType(accountId, 'create_task', '{"subject":"Send pricing","dueDate":"tomorrow"}')
            });
        Integer draftDml = Limits.getDmlStatements();
        CustomerSummaryActionCommitAction.Request confirm = new CustomerSummaryActionCommitAction.Request();
        confirm.draftJson = drafts[0].draftJson;
        List<CustomerSummaryActionCommitAction.Response> results = CustomerSummaryActionCommitAction.commitDrafts(
            new List<CustomerSummaryActionCommitAction.Request>{ confirm });
        Test.stopTest();
        Assert.areEqual(0, draftDml, 'drafting writes nothing');
        Assert.areEqual(CustomerSummaryActions.READY, drafts[0].status, drafts[0].draftText);
        Assert.areEqual(CustomerSummaryActions.READY, drafts[1].status, drafts[1].draftText);
        Assert.areEqual(CustomerSummaryActions.OK, results[0].status, results[0].message);
        Assert.isTrue(results[0].isSuccess);
        Assert.areEqual(CustomerSummaryActions.logCallObject(), results[0].recordId.getSObjectType().getDescribe().getName(), 'F17');
        Assert.areEqual(1, written(), 'only the confirmed call was written');
    }

    @IsTest
    static void thePanelKeepsAllSix() {
        User rep = CustomerSummaryTestUsers.productUser();
        System.runAs(rep) {
            Id accountId = acme();
            Test.startTest();
            List<String> names = new List<String>();
            for (CustomerSummaryActionCatalog.Spec spec : CustomerSummaryActionCatalog.all()) {
                names.add(spec.name);
                CustomerSummaryActions.Draft d = CustomerSummaryActions.draft(spec.name, accountId, new Map<String, Object>());
                Assert.areEqual(spec.name, d.action);
                Assert.areNotEqual(CustomerSummaryActionDraftAction.DOOR_REFUSED_TEXT, d.message, spec.name);
                Assert.areNotEqual(CustomerSummaryActions.UNKNOWN_ACTION_TEXT, d.message, spec.name);
            }
            CustomerSummaryActions.Result r = CustomerSummaryActions.commitJson(asJson(CustomerSummaryActions.draft(
                'create_case', accountId, new Map<String, Object>{ 'subject' => 'Portal is down' })));
            Test.stopTest();
            Assert.areEqual(new List<String>{ 'create_task', 'create_event', 'log_call', 'update_contact', 'create_case',
                'update_opportunity' }, names);
            Assert.areEqual(CustomerSummaryActions.OK, r.status, 'the panel still writes a case: ' + r.message);
            Assert.areEqual(1, [SELECT COUNT() FROM Case]);
            Assert.isTrue(CustomerSummaryActionDraftAction.allowed('log_call'));
            Assert.isFalse(CustomerSummaryActionDraftAction.allowed('create_case'));
            Assert.isFalse(CustomerSummaryActionDraftAction.allowed(null));

        }
    }
}
