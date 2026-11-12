@IsTest
private class AccountBriefPanelControllerTest {
    /** Scripted replies in order, then a fixed brief text; records every user prompt. Never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        List<String> prompts = new List<String>();

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            prompts.add(userPrompt);
            if (!replies.isEmpty()) {
                return replies.remove(0);
            }
            return 'Panel headline.\nFirst point.\nSecond point.';
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
        Account acme = new Account(Name = 'Panel Acme', Industry = 'Technology');
        Account one = new Account(Name = 'Panel Twin One', BillingCity = 'Austin');
        Account two = new Account(Name = 'Panel Twin Two');
        insert new List<Account>{ acme, one, two };
        insert new Opportunity(AccountId = acme.Id, Name = 'Panel Deal', StageName = 'Prospecting', Amount = 500, CloseDate = Date.today().addDays(30));
        insert new Contact(AccountId = acme.Id, LastName = 'Panelist', Title = 'Buyer');
    }

    private static Account acme() {
        return [SELECT Id, Name FROM Account WHERE Name = 'Panel Acme' LIMIT 1];
    }

    /** The JSON the LWC receives carries every named field. */
    private static Map<String, Object> wire(Object o, List<String> fields) {
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(o));
        for (String f : fields) {
            Assert.isTrue(m.containsKey(f), 'serialized object lacks ' + f + ': ' + JSON.serialize(o));
        }
        return m;
    }

    @IsTest
    static void resolveDelegatesAndCarriesPanelFields() {
        Account a = acme();
        Test.startTest();
        AccountBriefResolver.Response byId = AccountBriefPanelController.resolve(null, a.Id);
        AccountBriefResolver.Response byName = AccountBriefPanelController.resolve('Panel Acme', null);
        AccountBriefResolver.Response ambiguous = AccountBriefPanelController.resolve('Panel Twin', null);
        AccountBriefResolver.Response missing = AccountBriefPanelController.resolve('Nobody Here Inc', null);
        Test.stopTest();

        Assert.areEqual(AccountBriefResolver.RESOLVED, byId.status);
        Assert.areEqual(String.valueOf(a.Id), byId.accountId);
        Assert.areEqual(String.valueOf(a.Id), byName.accountId);
        Map<String, Object> m = wire(byId, new List<String>{ 'status', 'accountId', 'accountName', 'message' });
        Assert.areEqual('Panel Acme', m.get('accountName'));

        Assert.areEqual(AccountBriefResolver.AMBIGUOUS, ambiguous.status);
        // The panel turns each "Name — city — Id" line into a re-resolve button.
        Account twin = [SELECT Id FROM Account WHERE Name = 'Panel Twin One' LIMIT 1];
        Assert.isTrue(ambiguous.message.contains('Panel Twin One — Austin — ' + String.valueOf(twin.Id)), ambiguous.message);
        Assert.areEqual(AccountBriefResolver.NOT_FOUND, missing.status);
        Assert.isTrue(String.isNotBlank((String) wire(missing, new List<String>{ 'status', 'message' }).get('message')));
    }

    @IsTest
    static void getBriefDelegatesAndCarriesSectionFields() {
        Account a = acme();
        stub(new List<String>());
        Test.startTest();
        AccountBrief.Result r = AccountBriefPanelController.getBrief(a.Id, 'How is it going?', new List<String>{ 'profile', 'open_deals', 'nope' });
        Test.stopTest();

        Assert.areEqual(AccountBrief.OK, r.status);
        Assert.areEqual('Panel headline.\nFirst point.\nSecond point.', r.answer);
        Assert.areEqual(2, r.sections.size());
        Assert.areEqual('profile', r.sections[0].key);
        Assert.areEqual(new List<String>{ 'nope' }, r.ignored);

        Map<String, Object> m = wire(r, new List<String>{ 'status', 'message', 'answer', 'sections', 'ignored' });
        Map<String, Object> section = (Map<String, Object>) ((List<Object>) m.get('sections'))[1];
        for (String f : new List<String>{ 'key', 'title', 'status', 'body', 'total', 'shown' }) {
            Assert.isTrue(section.containsKey(f), 'section lacks ' + f);
        }
        Assert.areEqual('open_deals', section.get('key'));
        Assert.areEqual(1, section.get('total'));
        Assert.areEqual(1, section.get('shown'));
    }

    @IsTest
    static void getBriefWithNullIncludeBriefsEverySourceAndHistoryRemembersIt() {
        Account a = acme();
        stub(new List<String>());
        Test.startTest();
        AccountBrief.Result r = AccountBriefPanelController.getBrief(a.Id, 'Q1', null);
        List<AccountBriefMemory.Turn> turns = AccountBriefPanelController.history(a.Id);
        Test.stopTest();

        Assert.areEqual(AccountBrief.sources().size(), r.sections.size());
        Assert.areEqual(1, turns.size());
        Assert.areEqual('Q1', turns[0].question);
        Assert.areEqual('Panel headline.', turns[0].headline);
        wire(turns[0], new List<String>{ 'at', 'status', 'question', 'headline' });
    }

    @IsTest
    static void getBriefNotFoundRelaysTextVerbatim() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        AccountBrief.Result r = AccountBriefPanelController.getBrief(c.Id, null, new List<String>());
        Assert.areEqual(AccountBrief.NOT_FOUND, r.status);
        Assert.areEqual(AccountBrief.NOT_FOUND_TEXT, r.message);
    }

    @IsTest
    static void exploreDelegatesAndCarriesPanelFields() {
        Account a = acme();
        Stub s = stub(new List<String>{
            '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Amount"],'
                + '"filters":[{"field":"AccountId","op":"=","value":"' + a.Id + '"}]}}',
            '{"action":"answer","text":"One open deal.","followups":["Who owns it?"]}'
        });
        String history = JSON.serialize(new List<Object>{ new Map<String, Object>{ 'question' => 'Earlier Q', 'answer' => 'Earlier A' } });
        Test.startTest();
        DataExplorer.Result r = AccountBriefPanelController.explore('What deals are open?', a.Id, history);
        Test.stopTest();

        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual('One open deal.', r.answer);
        Assert.areEqual(new List<String>{ 'Who owns it?' }, r.followups);
        Assert.areEqual(1, r.trail.size());
        Assert.isTrue(s.prompts[0].contains('Earlier Q'), 'history reaches the engine');
        Assert.isTrue(s.prompts[0].contains(String.valueOf(a.Id)), 'context reaches the engine');

        Map<String, Object> m = wire(r, new List<String>{ 'status', 'answer', 'resultSets', 'trail', 'followups' });
        Map<String, Object> rs = (Map<String, Object>) ((List<Object>) m.get('resultSets'))[0];
        for (String f : new List<String>{ 'objectName', 'columns', 'rows', 'total', 'shown' }) {
            Assert.isTrue(rs.containsKey(f), 'result set lacks ' + f);
        }
        Map<String, Object> row = (Map<String, Object>) ((List<Object>) rs.get('rows'))[0];
        Assert.isTrue(row.containsKey('Id'), 'rows carry the Id the panel drills with');
        Assert.areEqual('Panel Deal', row.get('Name'));
    }

    @IsTest
    static void drillRecordListsRelatedObjectsAndDrillsIntoThem() {
        Account a = acme();
        Test.startTest();
        AccountBriefPanelController.Drill rec = AccountBriefPanelController.drill(a.Id, null);
        AccountBriefPanelController.Drill opps = AccountBriefPanelController.drill(a.Id, 'Opportunity');
        Test.stopTest();

        Assert.areEqual('Account', rec.result.objectName);
        Assert.areEqual(1, rec.result.rows.size());
        Assert.areEqual('Panel Acme', rec.result.rows[0].get('Name'));
        Assert.isTrue(rec.related.contains('Opportunity'), String.valueOf(rec.related));
        Assert.isTrue(rec.related.contains('Contact'), String.valueOf(rec.related));
        Assert.isFalse(rec.related.contains('Account'), 'Account has no lookup to itself in the catalog');

        Assert.areEqual('Opportunity', opps.result.objectName);
        Assert.areEqual(1, opps.result.rows.size());
        Assert.isTrue(opps.related.isEmpty(), 'a related-rows drill lists no further objects');

        Map<String, Object> m = wire(rec, new List<String>{ 'result', 'related' });
        wire(m.get('result'), new List<String>{ 'objectName', 'columns', 'rows', 'total', 'shown' });
    }

    @IsTest
    static void drillFailureBecomesHandledText() {
        Account a = acme();
        try {
            AccountBriefPanelController.drill(a.Id, 'Lead');
            Assert.fail('expected an AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Lead is not in the explore catalog.', e.getMessage());
        }
        try {
            AccountBriefPanelController.drill(null, null);
            Assert.fail('expected an AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Pick a record to drill into.', e.getMessage());
        }
    }

    private class PanelTestException extends Exception {}

    private static final String FIXED_ERROR = 'I couldn\'t finish that right now. Try again in a minute.';

    /** Calls one panel method; it must throw AuraHandledException with the fixed text, never the raw text. */
    private static void assertFixed(String method, String raw) {
        Account a = acme();
        try {
            if (method == 'resolve') {
                AccountBriefPanelController.resolve('Panel Acme', null);
            } else if (method == 'getBrief') {
                AccountBriefPanelController.getBrief(a.Id, null, null);
            } else if (method == 'explore') {
                AccountBriefPanelController.explore('Any deals?', a.Id, null);
            } else if (method == 'drill') {
                AccountBriefPanelController.drill(a.Id, null);
            } else if (method == 'sources') {
                AccountBriefPanelController.sources();
            } else {
                AccountBriefPanelController.history(a.Id);
            }
            Assert.fail(method + ': expected an AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual(FIXED_ERROR, e.getMessage(), method);
            Assert.isFalse(e.getMessage().contains(raw), method + ' leaked the raw exception text');
        }
    }

    @IsTest
    static void unexpectedExceptionsBecomeFixedText() {
        stub(new List<String>());
        String raw = 'Too many SOQL queries: 101 (raw platform text)';
        AccountBriefPanelController.failure = new PanelTestException(raw);
        Test.startTest();
        for (String method : new List<String>{ 'resolve', 'getBrief', 'explore', 'drill', 'history', 'sources' }) {
            assertFixed(method, raw);
        }
        Test.stopTest();
    }

    @IsTest
    static void sourcesMatchTheRegistry() {
        List<AccountBrief.SourceInfo> sources = AccountBriefPanelController.sources();
        Assert.areEqual(AccountBrief.registry.size(), sources.size());
        for (Integer i = 0; i < sources.size(); i++) {
            Assert.areEqual(AccountBrief.registry[i].key, sources[i].key);
            Assert.isTrue(String.isNotBlank(sources[i].title));
        }
        Assert.areEqual('Open deals', sources[1].title);
        wire(sources[0], new List<String>{ 'key', 'title' });
    }

    @IsTest
    static void agentIdIsABotDefinitionIdOrNull() {
        String id = AccountBriefPanelController.agentId();
        List<SObject> bots = Database.query('SELECT Id FROM BotDefinition WHERE DeveloperName = \'Account_Brief\' LIMIT 1');
        if (bots.isEmpty()) {
            Assert.isNull(id);
        } else {
            Assert.areEqual(String.valueOf(bots[0].Id), id);
        }
    }
}
