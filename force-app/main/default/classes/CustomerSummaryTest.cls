@IsTest
private class CustomerSummaryTest {
    private static final List<String> ALL_KEYS = new List<String>{
        'profile', 'open_deals', 'cases', 'contacts', 'activity', 'calls', 'deal_history'
    };

    /** Records every model call; never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> systems = new List<String>();
        List<String> users = new List<String>();
        /** DML statements already run in the transaction at each model call. A real callout after DML throws. */
        List<Integer> dmlAtCall = new List<Integer>();
        Boolean fail = false;
        /** When set, the synthesis call returns this instead of the short fixed brief. */
        String synthesisReply;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (fail) {
                throw new AgentLlm.LlmException('model down');
            }
            dmlAtCall.add(Limits.getDmlStatements());
            systems.add(systemPrompt);
            users.add(userPrompt);
            if (systemPrompt.contains('engagement data')) {
                return 'ENGAGEMENT SUMMARY';
            }
            if (systemPrompt.contains('deal history for one account')) {
                return 'DEAL HISTORY SUMMARY';
            }
            return synthesisReply != null ? synthesisReply : 'Headline finding.\nAccount\nBody.';
        }

        Integer count(String marker) {
            Integer n = 0;
            for (String s : systems) {
                if (s.contains(marker)) {
                    n++;
                }
            }
            return n;
        }

        String synthesisUser() {
            for (Integer i = 0; i < systems.size(); i++) {
                if (systems[i].contains('final account summary')) {
                    return users[i];
                }
            }
            return null;
        }
    }

    private static Stub install() {
        Stub s = new Stub();
        AgentLlm.stub = s;
        return s;
    }

    private static Account mkAccount(Boolean withData) {
        Account a = new Account(Name = 'Brief Engine Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
        insert a;
        if (withData) {
            insert new Contact(AccountId = a.Id, LastName = 'Rivera', Title = 'Buyer');
            insert new Opportunity(AccountId = a.Id, Name = 'Won deal', StageName = 'Closed Won', Amount = 5000, CloseDate = Date.today().addDays(-20));
        }
        return a;
    }

    private static Integer memoryRows() {
        return [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE];
    }

    private static List<String> keysOf(CustomerSummary.Result r) {
        List<String> keys = new List<String>();
        for (CustomerSummarySection s : r.sections) {
            keys.add(s.key);
        }
        return keys;
    }

    @IsTest
    static void synthesisPromptEndsWithTheBrandCompanyAndToneLines() {
        BrandSettings.rowsForTest = new List<Brand_Setting__mdt>{
            new Brand_Setting__mdt(Company_Name__c = 'Northwind Health', Tone__c = 'Warm and brief.')
        };
        Account a = mkAccount(true);
        Stub stub = install();

        Test.startTest();
        CustomerSummary.run(a.Id, null, null);
        Test.stopTest();

        String synthesis = stub.systems[2];
        Assert.isTrue(synthesis.contains('final account summary'), 'the prompt file\'s own text is still there');
        Assert.isTrue(synthesis.endsWith('\n\nCompany: the user works at Northwind Health.\nTone: Warm and brief.'),
            'the company line, then the tone line, end the synthesis system prompt: ' + synthesis.right(200));
        Assert.isFalse(stub.systems[0].contains('Northwind Health'), 'the pre-reduce prompts are unchanged');
        Assert.isFalse(stub.systems[1].contains('Tone: '), 'the pre-reduce prompts are unchanged');
    }

    @IsTest
    static void allSourcesByDefaultInRegistryOrder() {
        Account a = mkAccount(true);
        Stub stub = install();

        Test.startTest();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, ' What is the risk? ', null);
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status);
        Assert.areEqual('', r.message);
        Assert.areEqual('Headline finding.\nAccount\nBody.', r.answer);
        Assert.areEqual(ALL_KEYS, keysOf(r));
        Assert.isTrue(r.ignored.isEmpty());

        Assert.areEqual(3, stub.systems.size());
        Assert.areEqual(1, stub.count('engagement data'));
        Assert.areEqual(1, stub.count('deal history for one account'));
        Assert.isTrue(stub.systems[2].contains('final account summary'), 'synthesis runs last');

        String engagementUser = stub.users[0];
        Assert.isTrue(engagementUser.contains('Account: ' + a.Name));
        Assert.isTrue(engagementUser.contains('Rivera'));

        String synth = stub.synthesisUser();
        Assert.isTrue(synth.contains('Question:\nWhat is the risk?'));
        Assert.isTrue(synth.contains('Name: ' + a.Name));
        Assert.isTrue(synth.contains('Engagement summary:\nENGAGEMENT SUMMARY'));
        Assert.isTrue(synth.contains('Deal history summary:\nDEAL HISTORY SUMMARY'));
        Assert.isTrue(synth.contains('Cases:\nEMPTY: '));
        Assert.isFalse(synth.contains('{{'));

        Assert.areEqual(1, memoryRows());
        Assert.areEqual(r.answer, CustomerSummaryMemory.lastBrief(a.Id));
    }

    @IsTest
    static void everyRegistryKeyMatchesItsSource() {
        for (CustomerSummary.Source src : CustomerSummary.registry) {
            CustomerSummarySource impl = (CustomerSummarySource) Type.forName(src.className).newInstance();
            Assert.areEqual(src.key, impl.key(), src.className);
            Assert.isTrue(String.isNotBlank(impl.title()), src.className);
        }
    }

    @IsTest
    static void emptyIncludeMeansAll() {
        Account a = mkAccount(false);
        install();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ ' ', '' });
        Assert.areEqual(ALL_KEYS, keysOf(r));
        Assert.isTrue(r.ignored.isEmpty());
    }

    @IsTest
    static void includeFiltersAndSkipsEngagement() {
        Account a = mkAccount(true);
        Stub stub = install();

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'Open_Deals', ' deal_history ', 'bogus' });

        Assert.areEqual(new List<String>{ 'open_deals', 'deal_history' }, keysOf(r));
        Assert.areEqual(new List<String>{ 'bogus' }, r.ignored);
        Assert.areEqual(0, stub.count('engagement data'), 'no engagement source included');
        Assert.areEqual(1, stub.count('deal history for one account'));

        String synth = stub.synthesisUser();
        Assert.isTrue(synth.contains('Profile:\nEMPTY: not requested'));
        Assert.isTrue(synth.contains('Cases:\nEMPTY: not requested'));
        Assert.isTrue(synth.contains('Engagement summary:\nEMPTY\n'));
        Assert.isTrue(synth.contains('Deal history summary:\nDEAL HISTORY SUMMARY'));
        Assert.isTrue(synth.contains('Question:\n\n'));
    }

    @IsTest
    static void emptySourcesSkipPreReduceAndGiveEmpty() {
        Account a = mkAccount(false);
        Stub stub = install();

        CustomerSummary.Result r = CustomerSummary.run(a.Id, 'Anyone engaged?', new Set<String>{ 'contacts' });

        Assert.areEqual(CustomerSummary.EMPTY, r.status);
        Assert.areEqual(CustomerSummary.EMPTY_TEXT, r.message);
        Assert.areEqual(1, stub.systems.size(), 'only synthesis runs');
        Assert.isTrue(stub.synthesisUser().contains('Engagement summary:\nEMPTY\n'));
        Assert.areEqual(1, memoryRows());
    }

    @IsTest
    static void notFoundMakesNoModelCall() {
        Account a = mkAccount(false);
        Id goneId = a.Id;
        delete a;
        Stub stub = install();

        for (Id candidate : new List<Id>{ goneId, null, UserInfo.getUserId() }) {
            CustomerSummary.Result r = CustomerSummary.run(candidate, 'Hi', null);
            Assert.areEqual(CustomerSummary.NOT_FOUND, r.status);
            Assert.areEqual('I can\'t see that account. Check the name or your access.', r.message);
            Assert.areEqual(r.message, r.answer);
            Assert.isTrue(r.sections.isEmpty());
        }
        Assert.areEqual(0, stub.systems.size());
        Assert.areEqual(0, memoryRows());
    }

    @IsTest
    static void modelExceptionGivesErrorAndNoMemory() {
        Account a = mkAccount(true);
        Stub stub = install();
        stub.fail = true;

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        Assert.areEqual(CustomerSummary.ERROR, r.status);
        Assert.areEqual('I couldn\'t finish the brief right now. Try again in a minute.', r.answer);
        Assert.areEqual(ALL_KEYS, keysOf(r), 'sections still returned');
        Assert.areEqual(0, memoryRows());
    }

    @IsTest
    static void onlyUnknownKeysBuildsNothing() {
        Account a = mkAccount(false);
        Stub stub = install();

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'bogus' });

        Assert.areEqual(CustomerSummary.EMPTY, r.status);
        Assert.isTrue(r.answer.startsWith(CustomerSummary.NO_SECTIONS_TEXT));
        Assert.isTrue(r.answer.contains('deal_history'));
        Assert.areEqual(new List<String>{ 'bogus' }, r.ignored);
        Assert.isTrue(r.sections.isEmpty());
        Assert.areEqual(0, stub.systems.size());
        Assert.areEqual(0, memoryRows());
    }

    @IsTest
    static void brokenSourceBecomesErrorSection() {
        Account a = mkAccount(false);
        install();
        CustomerSummary.registry.add(new CustomerSummary.Source('broken', 'NoSuchBriefSourceZz'));

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'broken' });

        Assert.areEqual(1, r.sections.size());
        Assert.areEqual('broken', r.sections[0].key);
        Assert.areEqual(CustomerSummarySection.ERROR, r.sections[0].status);
    }

    @IsTest
    static void everySectionErrorGivesErrorNotEmpty() {
        Account a = mkAccount(false);
        Stub stub = install();
        CustomerSummary.registry.add(new CustomerSummary.Source('broken', 'NoSuchBriefSourceZz'));
        CustomerSummary.registry.add(new CustomerSummary.Source('broken_too', 'NoSuchBriefSourceZz'));

        CustomerSummary.Result r = CustomerSummary.run(a.Id, 'Anything?', new Set<String>{ 'broken', 'broken_too' });

        Assert.areEqual(2, r.sections.size());
        Assert.areEqual(CustomerSummary.ERROR, r.status, 'every section failed, so the brief failed');
        Assert.areEqual(CustomerSummary.ERROR_TEXT, r.message);
        Assert.areEqual(CustomerSummary.ERROR_TEXT, r.answer);
        Assert.areEqual(0, stub.systems.size(), 'no model call when nothing loaded');
        Assert.areEqual(0, memoryRows(), 'a failed brief is not remembered');
    }

    @IsTest
    static void errorAndEmptySectionsGiveError() {
        Account a = mkAccount(false);
        install();
        CustomerSummary.registry.add(new CustomerSummary.Source('broken', 'NoSuchBriefSourceZz'));

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'broken', 'contacts' });

        Assert.areEqual(CustomerSummarySection.EMPTY, r.sections[0].status, 'contacts is empty');
        Assert.areEqual(CustomerSummarySection.ERROR, r.sections[1].status, 'broken failed');
        Assert.areEqual(CustomerSummary.ERROR, r.status, 'no section is OK and one failed');
        Assert.areEqual(CustomerSummary.ERROR_TEXT, r.answer);
    }

    @IsTest
    static void threeRequestsMakeNoModelCallAfterDml() {
        Account first = mkAccount(true);
        Account second = mkAccount(true);
        List<CustomerSummaryGetAction.Request> requests = new List<CustomerSummaryGetAction.Request>();
        for (Account a : new List<Account>{ first, second, first }) {
            CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
            req.accountId = String.valueOf(a.Id);
            req.userQuestion = 'Status of ' + a.Name + '?';
            requests.add(req);
        }

        Test.startTest();
        Stub stub = install();
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(requests);
        Integer dml = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(3, out.size());
        for (CustomerSummaryGetAction.Response resp : out) {
            Assert.areEqual(CustomerSummary.OK, resp.status, resp.answer);
            Assert.areEqual('Headline finding.\nAccount\nBody.', resp.answer);
        }
        Assert.areEqual(9, stub.dmlAtCall.size(), 'three model calls per brief');
        for (Integer i = 0; i < stub.dmlAtCall.size(); i++) {
            Assert.areEqual(0, stub.dmlAtCall[i], 'model call ' + (i + 1) + ' ran after DML: ' + stub.dmlAtCall);
        }
        Assert.areEqual(1, dml, 'one memory upsert for the whole invocation');
        Assert.areEqual(2, memoryRows(), 'one row per user and account');
        Assert.areEqual(2, CustomerSummaryMemory.history(first.Id).size(), 'both briefs of the first account are remembered');
        Assert.areEqual(1, CustomerSummaryMemory.history(second.Id).size());
    }

    @IsTest
    static void bulkBriefOverThreeHundredTasksStaysWithinLimits() {
        Account a = mkAccount(false);
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 251; i++) {
            contacts.add(new Contact(AccountId = a.Id, LastName = 'Bulk ' + String.valueOf(i).leftPad(3, '0')));
        }
        insert contacts;
        List<String> subtypes = new List<String>{ 'Email', 'Call', 'Task' };
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 300; i++) {
            tasks.add(new Task(
                WhatId = a.Id,
                WhoId = contacts[Math.mod(i, contacts.size())].Id,
                Subject = 'Bulk task ' + i,
                TaskSubtype = subtypes[Math.mod(i, 3)],
                Status = 'Completed',
                ActivityDate = Date.today().addDays(-Math.mod(i, 80))
            ));
        }
        insert tasks;

        Test.startTest();
        install();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);
        Integer queries = Limits.getQueries();
        Integer rows = Limits.getQueryRows();
        Integer heap = Limits.getHeapSize();
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Map<String, CustomerSummarySection> byKey = new Map<String, CustomerSummarySection>();
        for (CustomerSummarySection s : r.sections) {
            byKey.put(s.key, s);
        }
        Assert.areEqual(CustomerSummarySection.OK, byKey.get('activity').status, byKey.get('activity').body);
        Assert.areEqual(300, byKey.get('activity').total);
        Assert.areEqual(CustomerSummaryActivitySection.CAP, byKey.get('activity').shown);
        Assert.areEqual(CustomerSummarySection.OK, byKey.get('contacts').status, byKey.get('contacts').body);
        Assert.areEqual(251, byKey.get('contacts').total);
        Assert.isTrue(queries < Limits.getLimitQueries(), 'SOQL queries: ' + queries);
        Assert.isTrue(rows < Limits.getLimitQueryRows(), 'query rows: ' + rows);
        Assert.isTrue(heap < Limits.getLimitHeapSize(), 'heap: ' + heap);
    }

    @IsTest
    static void invocableParsesInclude() {
        Account a = mkAccount(true);
        Stub stub = install();

        Assert.areEqual(new Set<String>{ 'open_deals', 'contacts' }, CustomerSummaryGetAction.parseInclude(' open_deals, contacts ,, '));
        Assert.isTrue(CustomerSummaryGetAction.parseInclude('  ').isEmpty());
        Assert.isTrue(CustomerSummaryGetAction.parseInclude(null).isEmpty());

        CustomerSummaryGetAction.Request ok = new CustomerSummaryGetAction.Request();
        ok.accountId = String.valueOf(a.Id);
        ok.userQuestion = 'Who is engaged?';
        ok.include = 'open_deals, contacts';
        CustomerSummaryGetAction.Request badId = new CustomerSummaryGetAction.Request();
        badId.accountId = 'not-an-id';

        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(
            new List<CustomerSummaryGetAction.Request>{ ok, badId, null }
        );

        Assert.areEqual(3, out.size());
        Assert.areEqual(CustomerSummary.OK, out[0].status);
        Assert.areEqual('Headline finding.\nAccount\nBody.', out[0].answer);
        Assert.areEqual(1, stub.count('engagement data'), 'contacts included and not empty');
        Assert.areEqual(0, stub.count('deal history for one account'), 'deal_history not included');
        Assert.areEqual(CustomerSummary.NOT_FOUND, out[1].status);
        Assert.areEqual(CustomerSummary.NOT_FOUND_TEXT, out[1].answer);
        Assert.areEqual(CustomerSummary.NOT_FOUND, out[2].status);
        Assert.isTrue(CustomerSummaryGetAction.getBriefs(null).isEmpty());
    }

    @IsTest
    static void someErrorSectionsStillGiveAnOkBrief() {
        Account a = mkAccount(true);
        Stub stub = install();
        CustomerSummary.registry.add(new CustomerSummary.Source('broken', 'NoSuchBriefSourceZz'));

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'profile', 'broken' });

        Assert.areEqual(CustomerSummary.OK, r.status, 'one section loaded, so the brief is OK');
        Assert.areEqual(CustomerSummarySection.OK, r.sections[0].status);
        Assert.areEqual(CustomerSummarySection.ERROR, r.sections[1].status, 'the failed section stays visible as ERROR');
        Assert.isNotNull(stub.synthesisUser(), 'the model still writes the brief');
        Assert.areEqual(1, memoryRows(), 'a brief that answered is remembered');
    }

    /** The line of s that contains text; it must end with ' — ' and the record's 18-character Id. */
    private static void assertLineEndsWithId(CustomerSummarySection s, String text, Id recordId) {
        Assert.isNotNull(s, 'section missing');
        for (String line : s.body.split('\n')) {
            if (line.contains(text)) {
                Assert.isTrue(line.endsWith(' — ' + String.valueOf(recordId)), s.key + ' line lacks its record Id: ' + line);
                return;
            }
        }
        Assert.fail(s.key + ' has no line containing "' + text + '": ' + s.body);
    }

    @IsTest
    static void recordIdsReachThePanelInSectionLinesButNeverAPrompt() {
        Account a = mkAccount(false);
        Contact c = new Contact(AccountId = a.Id, LastName = 'Drillable', Title = 'Buyer');
        insert c;
        Opportunity openDeal = new Opportunity(AccountId = a.Id, Name = 'Open drill deal', StageName = 'Prospecting', Amount = 900, CloseDate = Date.today().addDays(15));
        Opportunity wonDeal = new Opportunity(AccountId = a.Id, Name = 'Won drill deal', StageName = 'Closed Won', Amount = 700, CloseDate = Date.today().addDays(-15));
        insert new List<Opportunity>{ openDeal, wonDeal };
        insert new OpportunityContactRole(OpportunityId = openDeal.Id, ContactId = c.Id, Role = 'Decision Maker', IsPrimary = true);
        Case cs = new Case(AccountId = a.Id, Subject = 'Drill case', Priority = 'High', Status = 'New');
        insert cs;
        Task t = new Task(WhatId = a.Id, Subject = 'Drill task', TaskSubtype = 'Call', Status = 'Completed', ActivityDate = Date.today().addDays(-1));
        insert t;
        Event past = new Event(WhatId = a.Id, Subject = 'Drill call', StartDateTime = DateTime.now().addDays(-2), DurationInMinutes = 30, Description = 'Drill notes');
        Event next = new Event(WhatId = a.Id, Subject = 'Drill kickoff', StartDateTime = DateTime.now().addDays(3), DurationInMinutes = 30);
        insert new List<Event>{ past, next };
        Stub stub = install();

        Test.startTest();
        CustomerSummary.Result r = CustomerSummaryPanelController.getBrief(a.Id, null, null);
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status);
        Map<String, CustomerSummarySection> byKey = new Map<String, CustomerSummarySection>();
        for (CustomerSummarySection s : r.sections) {
            byKey.put(s.key, s);
        }

        // 1. The panel gets every record's Id at the end of that record's line.
        assertLineEndsWithId(byKey.get('open_deals'), 'Open drill deal', openDeal.Id);
        assertLineEndsWithId(byKey.get('open_deals'), 'Drillable (Decision Maker)', c.Id);
        assertLineEndsWithId(byKey.get('cases'), 'Drill case', cs.Id);
        assertLineEndsWithId(byKey.get('contacts'), 'Drillable', c.Id);
        assertLineEndsWithId(byKey.get('activity'), 'Drill task', t.Id);
        assertLineEndsWithId(byKey.get('calls'), 'Drill call', past.Id);
        assertLineEndsWithId(byKey.get('calls'), 'Next: ', next.Id);
        assertLineEndsWithId(byKey.get('deal_history'), 'Won drill deal', wonDeal.Id);
        // Summary, notes and "more" lines describe no one record and carry no Id.
        Integer withId = 0;
        for (CustomerSummarySection s : r.sections) {
            for (String line : s.body.split('\n')) {
                if (Pattern.matches('.* — [0-9][0-9A-Za-z]{17}', line)) {
                    withId++;
                }
            }
        }
        Assert.areEqual(8, withId, 'one Id per record line, none elsewhere');

        // 2. No Id reaches a model prompt, while the lines themselves do.
        Assert.areEqual(3, stub.users.size());
        List<String> prompts = new List<String>(stub.systems);
        prompts.addAll(stub.users);
        for (Id recordId : new List<Id>{ openDeal.Id, wonDeal.Id, c.Id, cs.Id, t.Id, past.Id, next.Id }) {
            for (String p : prompts) {
                Assert.isFalse(p.contains(String.valueOf(recordId)), 'record Id ' + recordId + ' reached a prompt: ' + p);
            }
        }
        String all = String.join(stub.users, '\n');
        for (String text : new List<String>{ 'Open drill deal', 'Drillable (Decision Maker)', 'Drill case', 'Drill task', 'Drill call', 'Drill notes', 'Drill kickoff', 'Won drill deal' }) {
            Assert.isTrue(all.contains(text), 'the prompt lost "' + text + '"');
        }
        Assert.isFalse(Pattern.compile('(?m) — [0-9][0-9A-Za-z]{17}$').matcher(all).find(), 'a line in a prompt still ends with an Id');
    }

    // ---- BE-29: N1 (request cap), N3 (ERROR rule), N8 (answer cap) ----

    /** An account with a row for every conditional section query, so a brief runs its most queries. */
    private static Account mkFullAccount() {
        Account a = mkAccount(false);
        Contact c = new Contact(AccountId = a.Id, LastName = 'Full', Title = 'Buyer');
        insert c;
        Opportunity openDeal = new Opportunity(AccountId = a.Id, Name = 'Open full deal', StageName = 'Prospecting', Amount = 900, CloseDate = Date.today().addDays(-3));
        insert new List<Opportunity>{
            openDeal,
            new Opportunity(AccountId = a.Id, Name = 'Won full deal', StageName = 'Closed Won', Amount = 700, CloseDate = Date.today().addDays(-15)),
            new Opportunity(AccountId = a.Id, Name = 'Lost full deal', StageName = 'Closed Lost', Amount = 500, CloseDate = Date.today().addDays(-40))
        };
        insert new OpportunityContactRole(OpportunityId = openDeal.Id, ContactId = c.Id, Role = 'Decision Maker', IsPrimary = true);
        insert new List<Case>{
            new Case(AccountId = a.Id, Subject = 'Open full case', Priority = 'High', Status = 'New'),
            new Case(AccountId = a.Id, Subject = 'Closed full case', Priority = 'Low', Status = 'Closed')
        };
        insert new List<Task>{
            new Task(WhatId = a.Id, WhoId = c.Id, Subject = 'Full call', TaskSubtype = 'Call', Status = 'Completed', ActivityDate = Date.today().addDays(-1)),
            new Task(WhatId = a.Id, Subject = 'Full overdue', Status = 'Not Started', ActivityDate = Date.today().addDays(-2))
        };
        insert new List<Event>{
            new Event(WhatId = a.Id, WhoId = c.Id, Subject = 'Full meeting', StartDateTime = DateTime.now().addDays(-2), DurationInMinutes = 30, Description = 'Notes'),
            new Event(WhatId = a.Id, Subject = 'Full next', StartDateTime = DateTime.now().addDays(3), DurationInMinutes = 30)
        };
        return a;
    }

    private static List<CustomerSummaryGetAction.Request> requestsFor(List<Account> accounts) {
        List<CustomerSummaryGetAction.Request> requests = new List<CustomerSummaryGetAction.Request>();
        for (Account a : accounts) {
            CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
            req.accountId = String.valueOf(a.Id);
            requests.add(req);
        }
        return requests;
    }

    @IsTest
    static void threeFullRequestsAtTheCapStayWellInsideTheQueryLimit() {
        List<Account> accounts = new List<Account>{ mkFullAccount(), mkFullAccount(), mkFullAccount() };

        Test.startTest();
        Stub stub = install();
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(requestsFor(accounts));
        Integer queries = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(3, out.size());
        for (CustomerSummaryGetAction.Response resp : out) {
            Assert.areEqual(CustomerSummary.OK, resp.status, resp.answer);
        }
        Assert.areEqual(9, stub.systems.size(), 'every brief at the cap is built');
        // Headroom for the memory write's DUPLICATE_VALUE retry (one more query) and a margin.
        Assert.isTrue(queries <= 90, 'SOQL queries for three full briefs and the memory write: ' + queries);
    }

    @IsTest
    static void requestsPastTheCapGetAFixedLineAndNoModelCall() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(mkAccount(true));
        }

        Test.startTest();
        Stub stub = install();
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(requestsFor(accounts));
        Test.stopTest();

        Assert.areEqual(5, out.size(), 'one response per request, in order');
        for (Integer i = 0; i < 3; i++) {
            Assert.areEqual(CustomerSummary.OK, out[i].status, out[i].answer);
        }
        for (Integer i = 3; i < 5; i++) {
            Assert.areEqual('ERROR', out[i].status);
            Assert.areEqual('I can build up to 3 summaries in one request. Ask for this account again on its own.', out[i].answer);
        }
        Assert.areEqual(9, stub.systems.size(), 'no model call for a request past the cap');
        Assert.areEqual(3, memoryRows(), 'only the briefs that ran are remembered');
    }

    @IsTest
    static void synthesisPromptHasARuleForAFailedSection() {
        String prompt = [SELECT Body FROM StaticResource WHERE Name = 'AgentPrompt_SummarySynthesis' LIMIT 1].Body.toString();
        String systemText = prompt.substringBefore('---user---');

        Assert.isTrue(systemText.contains('starts with "ERROR:"'), 'no rule for an ERROR input');
        Assert.isTrue(systemText.contains('could not be loaded'), 'the rule does not say the part could not be loaded');
        Assert.isTrue(systemText.contains('Never write "none"'), 'the rule does not forbid "none"');
        Assert.isTrue(systemText.contains('"no open cases"'), 'the rule does not forbid "no open cases"');
    }

    @IsTest
    static void aFailedSectionInsideAPreReduceStillReachesTheSynthesisAsError() {
        Account a = mkAccount(true);
        Stub stub = install();
        for (Integer i = 0; i < CustomerSummary.registry.size(); i++) {
            if (CustomerSummary.registry[i].key == 'calls') {
                CustomerSummary.registry[i] = new CustomerSummary.Source('calls', 'NoSuchBriefSourceZz');
            }
        }

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        String synthesis = stub.synthesisUser();
        Assert.isTrue(synthesis.contains('ENGAGEMENT SUMMARY\nERROR: Couldn\'t load calls right now.'),
            'the engagement pre-reduce hides the failed calls section: ' + synthesis);
    }

    @IsTest
    static void anAnswerPastTheLengthCapEndsOnAClearMarker() {
        Account a = mkAccount(true);
        Stub stub = install();
        stub.synthesisReply = 'Headline finding.\nAccount\n' + 'This sentence is about the account and its deals. '.repeat(200);

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        String marker = '\n[Cut short: this summary reached its length limit.]';
        Assert.areEqual(CustomerSummary.OK, r.status);
        Assert.isTrue(r.answer.length() <= 5900, 'answer length: ' + r.answer.length());
        Assert.isTrue(r.answer.endsWith(marker), 'no marker at the cut: ' + r.answer.right(120));
        Assert.isTrue(r.answer.removeEnd(marker).endsWith('deals.'), 'cut mid-sentence: ' + r.answer.right(120));
        Assert.areEqual(r.answer, CustomerSummaryMemory.lastBrief(a.Id), 'memory keeps the marked answer');
    }

    @IsTest
    static void anAnswerUnderTheCapIsUnchanged() {
        Account a = mkAccount(true);
        Stub stub = install();
        String reply = 'Headline finding.\nAccount\n' + 'Short line. '.repeat(100);
        stub.synthesisReply = reply;

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        Assert.areEqual(reply.trim(), r.answer);
    }
}
