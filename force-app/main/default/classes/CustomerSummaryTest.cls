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
        /** What the sentiment call returns (BE-36); a well-formed positive reading unless a test sets it. */
        String sentimentReply = '{"score": 1, "label": "Positive", "reason": "A deal won 20 days ago."}';
        /** Makes only the sentiment call fail. */
        Boolean failSentiment = false;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (fail) {
                throw new AgentLlm.LlmException('model down');
            }
            dmlAtCall.add(Limits.getDmlStatements());
            systems.add(systemPrompt);
            users.add(userPrompt);
            if (systemPrompt.contains(SENTIMENT_MARKER)) {
                if (failSentiment) {
                    throw new AgentLlm.LlmException('sentiment model down');
                }
                return sentimentReply;
            }
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

        /** The system text of the last synthesis call, or null. */
        String lastSynthesis() {
            for (Integer i = systems.size() - 1; i >= 0; i--) {
                if (systems[i].contains('final account summary')) {
                    return systems[i];
                }
            }
            return null;
        }

        /** The user text of the first sentiment call, or null. */
        String sentimentUser() {
            for (Integer i = 0; i < systems.size(); i++) {
                if (systems[i].contains(SENTIMENT_MARKER)) {
                    return users[i];
                }
            }
            return null;
        }
    }

    /** Words only the sentiment prompt file's system text holds. */
    private static final String SENTIMENT_MARKER = 'score customer sentiment';

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

        Assert.areEqual(4, stub.systems.size());
        Assert.areEqual(1, stub.count('engagement data'));
        Assert.areEqual(1, stub.count('deal history for one account'));
        Assert.isTrue(stub.systems[2].contains('final account summary'), 'synthesis runs after the pre-reduces');
        Assert.isTrue(stub.systems[3].contains(SENTIMENT_MARKER), 'the sentiment call ends the reduce step');

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

        User rep = outcomeRep('Standard User', 'sum3', true);
        List<CustomerSummaryGetAction.Response> out;
        Integer dml;
        Integer before;
        Integer firstHistory;
        Integer secondHistory;
        Test.startTest();
        Stub stub = install();
        System.runAs(rep) {
            before = Limits.getDmlStatements(); // System.runAs itself counts as one DML statement
            out = CustomerSummaryGetAction.getBriefs(requests);
            dml = Limits.getDmlStatements() - before;
            firstHistory = CustomerSummaryMemory.history(first.Id).size();
            secondHistory = CustomerSummaryMemory.history(second.Id).size();
        }
        Test.stopTest();

        Assert.areEqual(3, out.size());
        for (CustomerSummaryGetAction.Response resp : out) {
            Assert.areEqual(CustomerSummary.OK, resp.status, resp.answer);
            Assert.areEqual('Headline finding.\nAccount\nBody.', resp.answer);
        }
        Assert.areEqual(12, stub.dmlAtCall.size(), 'four model calls per brief: two pre-reduces, the synthesis, the sentiment');
        for (Integer i = 0; i < stub.dmlAtCall.size(); i++) {
            Assert.areEqual(before, stub.dmlAtCall[i], 'model call ' + (i + 1) + ' ran after DML: ' + stub.dmlAtCall);
        }
        Assert.areEqual(4, dml, 'one memory upsert and one outcome write (savepoint, insert, text update) for the whole invocation');
        Assert.areEqual(2, memoryRows(), 'one row per user and account');
        Assert.areEqual(2, firstHistory, 'both briefs of the first account are remembered');
        Assert.areEqual(1, secondHistory);
        Assert.areEqual(2, outcomeRows(first.Id).size(), 'one summary outcome per brief');
        Assert.areEqual(1, outcomeRows(second.Id).size());
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
        Assert.areEqual(4, stub.users.size(), 'the pre-reduces, the synthesis and the sentiment, each checked below');
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
        Assert.areEqual(12, stub.systems.size(), 'every brief at the cap is built, sentiment included');
        Assert.areEqual(3, stub.count(SENTIMENT_MARKER), 'one sentiment call per brief, within the budget');
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
        Assert.areEqual(12, stub.systems.size(), 'no model call for a request past the cap');
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

    // ---- BE-39: cards next to the text ----

    private static List<String> typesOf(List<AnswerCard> cards) {
        List<String> types = new List<String>();
        for (AnswerCard c : cards) {
            types.add(c.type);
        }
        return types;
    }

    /** Every 15- or 18-character record Id in the section bodies, from the line ends the panel reads. */
    private static Set<String> idsInSections(CustomerSummary.Result r) {
        Set<String> ids = new Set<String>();
        Pattern lineId = Pattern.compile('(?m) — ([0-9][0-9A-Za-z]{17})$');
        for (CustomerSummarySection s : r.sections) {
            Matcher m = lineId.matcher(s.body == null ? '' : s.body);
            while (m.find()) {
                ids.add(m.group(1));
            }
        }
        return ids;
    }

    @IsTest
    static void cardsAgreeWithTheSummaryTextAndItsSections() {
        Account a = mkFullAccount();
        install();

        Test.startTest();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual(r.sections.size() + 1, r.cards.size(), 'one summary card, then one card per section');
        AnswerCard head = r.cards[0];
        Assert.areEqual('summary', head.type);
        Assert.areEqual('OK', head.status);
        Assert.areEqual('Headline finding.', head.title, 'the answer\'s first line is the title');
        Assert.areEqual(r.answer, head.text, 'an answer without markup is its own plain text');
        for (Integer i = 0; i < r.sections.size(); i++) {
            CustomerSummarySection s = r.sections[i];
            AnswerCard c = r.cards[i + 1];
            Assert.areEqual('section', c.type);
            Assert.areEqual('sec-' + s.key, c.key, 'cards keep the sections\' order');
            Assert.areEqual(s.title, c.title);
            Assert.areEqual(s.status, c.status);
            Assert.areEqual(s.total, c.total, s.key);
            Assert.areEqual(s.shown, c.shown, s.key);
            Map<String, AnswerCard.Ref> refs = new Map<String, AnswerCard.Ref>();
            for (AnswerCard.Ref ref : c.refs) {
                refs.put(ref.key, ref);
            }
            // Items are the section's own record lines, in its order, each pointing at its record.
            List<String> recordLines = new List<String>();
            for (String line : s.body.split('\n')) {
                if (line.startsWith('- ') && Pattern.matches('.* — [0-9][0-9A-Za-z]{17}', line)) {
                    recordLines.add(line);
                }
            }
            Assert.areEqual(recordLines.size(), c.items.size(), s.key + ': ' + s.body);
            for (Integer j = 0; j < c.items.size(); j++) {
                AnswerCard.Item item = c.items[j];
                Assert.isTrue(recordLines[j].startsWith('- ' + item.label + ' — '), s.key + ' item ' + j + ': ' + item.label + ' vs ' + recordLines[j]);
                Assert.isTrue(refs.containsKey(item.ref), s.key + ' item ' + j + ' has no ref');
                Assert.isTrue(recordLines[j].endsWith(' — ' + refs.get(item.ref).recordId), 'the ref is the line\'s own record');
                Assert.areEqual(item.label, refs.get(item.ref).label, 'the ref is labelled as the item');
            }
        }
        // Every record Id the sections carry is in a card's refs, and in no card's text.
        Set<String> ids = idsInSections(r);
        Assert.isFalse(ids.isEmpty(), 'the fixture names records');
        String cardJson = AnswerCard.toJson(r.cards);
        Set<String> inRefs = new Set<String>();
        for (AnswerCard c : r.cards) {
            for (AnswerCard.Ref ref : c.refs) {
                inRefs.add(ref.recordId);
            }
            for (String i : ids) {
                Assert.isFalse(c.text.contains(i), 'an Id reached the text of ' + c.key);
            }
            Assert.areEqual(AnswerCard.plainText(c), c.text, c.key);
        }
        Assert.isTrue(inRefs.containsAll(ids), 'every record line has a ref');
        Assert.isFalse(Pattern.compile('"(text|label|value|detail|title)":"[^"]*[0-9][0-9A-Za-z]{17}"').matcher(cardJson).find(),
            'no Id outside refs: ' + cardJson.left(400));
    }

    @IsTest
    static void everyTextMemberACallerReadsIsUnchanged() {
        Account a = mkFullAccount();
        install();
        List<CustomerSummarySection> direct = new List<CustomerSummarySection>{
            new CustomerSummaryProfileSection().build(a.Id),
            new CustomerSummaryOpenDealsSection().build(a.Id),
            new CustomerSummaryCasesSection().build(a.Id),
            new CustomerSummaryContactsSection().build(a.Id),
            new CustomerSummaryActivitySection().build(a.Id),
            new CustomerSummaryCallsSection().build(a.Id),
            new CustomerSummaryDealHistorySection().build(a.Id)
        };

        Test.startTest();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, 'Risk?', new Set<String>{ 'bogus', 'profile', 'open_deals', 'cases', 'contacts', 'activity', 'calls', 'deal_history' });
        CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
        req.accountId = String.valueOf(a.Id);
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(new List<CustomerSummaryGetAction.Request>{ req });
        Test.stopTest();

        Map<String, Object> asJson = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(r));
        Assert.areEqual(new Set<String>{ 'status', 'message', 'answer', 'sections', 'ignored', 'cards' }, asJson.keySet(),
            'one new member, cards; every other member keeps its name');
        Assert.areEqual(CustomerSummary.OK, r.status);
        Assert.areEqual('', r.message);
        Assert.areEqual('Headline finding.\nAccount\nBody.', r.answer);
        Assert.areEqual(new List<String>{ 'bogus' }, r.ignored);
        Assert.areEqual(JSON.serialize(direct), JSON.serialize(r.sections), 'the sections are what their builders return, Ids and all');
        Map<String, Object> respJson = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(out[0]));
        Assert.areEqual(new Set<String>{ 'status', 'answer', 'cards' }, respJson.keySet());
        Assert.areEqual(CustomerSummary.OK, out[0].status);
        Assert.areEqual('Headline finding.\nAccount\nBody.', out[0].answer, 'the invocable answer is unchanged');
    }

    @IsTest
    static void invocableCardsJsonParsesBackToTheSameCards() {
        Account a = mkFullAccount();
        install();
        CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
        req.accountId = String.valueOf(a.Id);
        CustomerSummaryGetAction.Request badId = new CustomerSummaryGetAction.Request();
        badId.accountId = 'not-an-id';

        Test.startTest();
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(new List<CustomerSummaryGetAction.Request>{ req, badId });
        Test.stopTest();

        List<AnswerCard> back = AnswerCard.fromJson(out[0].cards);
        Assert.areEqual(8, back.size(), 'the summary and its seven sections');
        Assert.areEqual(out[0].cards, AnswerCard.toJson(back), 'the JSON parses back to the same cards');
        Assert.areEqual('summary', back[0].type);
        Assert.areEqual(out[0].answer, back[0].text);
        Assert.isTrue(out[0].cards.length() <= AnswerCard.MAX_JSON_CHARS, 'length: ' + out[0].cards.length());
        List<AnswerCard> notFound = AnswerCard.fromJson(out[1].cards);
        Assert.areEqual(1, notFound.size());
        Assert.areEqual('notice', notFound[0].type);
        Assert.areEqual(CustomerSummary.NOT_FOUND, notFound[0].status);
        Assert.areEqual(CustomerSummary.NOT_FOUND_TEXT, notFound[0].text);
    }

    @IsTest
    static void cardsOverTheCapLeaveTheCardsOutputEmptyAndTheAnswerAsIs() {
        Account a = mkAccount(true);
        install();
        AnswerCard.maxJsonChars = 50;
        CustomerSummaryGetAction.Request req = new CustomerSummaryGetAction.Request();
        req.accountId = String.valueOf(a.Id);

        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(new List<CustomerSummaryGetAction.Request>{ req });

        Assert.areEqual('', out[0].cards, 'over the cap: empty, never cut JSON');
        Assert.areEqual(CustomerSummary.OK, out[0].status);
        Assert.areEqual('Headline finding.\nAccount\nBody.', out[0].answer);
    }

    @IsTest
    static void theLargestBriefTheTestsBuildFitsTheCardsCap() {
        Account a = mkAccount(false);
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 60; i++) {
            contacts.add(new Contact(AccountId = a.Id, LastName = 'Cap contact with a long last name ' + i, Title = 'Vice President of Regional Facilities ' + i));
        }
        insert contacts;
        List<Opportunity> deals = new List<Opportunity>();
        for (Integer i = 0; i < 60; i++) {
            deals.add(new Opportunity(AccountId = a.Id, Name = 'Cap deal with a long descriptive name ' + i, StageName = i < 30 ? 'Prospecting' : 'Closed Won',
                Amount = 100000 + i, CloseDate = Date.today().addDays(i < 30 ? i - 10 : -i)));
        }
        insert deals;
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 60; i++) {
            cases.add(new Case(AccountId = a.Id, Subject = 'Cap case with a long subject line about a fault ' + i, Priority = 'High', Status = 'New'));
        }
        insert cases;
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 100; i++) {
            tasks.add(new Task(WhatId = a.Id, WhoId = contacts[Math.mod(i, 60)].Id, Subject = 'Cap task with a long subject line ' + i,
                TaskSubtype = 'Call', Status = 'Completed', ActivityDate = Date.today().addDays(-Math.mod(i, 80))));
        }
        insert tasks;
        Stub stub = install();
        stub.synthesisReply = 'Headline finding.\n' + 'This sentence is about the account and its deals. '.repeat(110);

        Test.startTest();
        List<CustomerSummaryGetAction.Response> out = CustomerSummaryGetAction.getBriefs(requestsFor(new List<Account>{ a }));
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, out[0].status, out[0].answer);
        Assert.isTrue(String.isNotBlank(out[0].cards), 'a full brief\'s cards fit the cap');
        System.debug(LoggingLevel.INFO, 'BE-39 largest test brief: cards JSON ' + out[0].cards.length() + ' chars, answer ' + out[0].answer.length());
    }

    @IsTest
    static void aFailedSectionStillGivesACardAndKeepsTheRest() {
        Account a = mkAccount(true);
        install();
        CustomerSummary.registry.add(new CustomerSummary.Source('broken', 'NoSuchBriefSourceZz'));

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, new Set<String>{ 'profile', 'broken' });

        Assert.areEqual(new List<String>{ 'summary', 'section', 'section' }, typesOf(r.cards));
        Assert.areEqual('sec-profile', r.cards[1].key);
        Assert.areEqual('OK', r.cards[1].status);
        Assert.areEqual('sec-broken', r.cards[2].key);
        Assert.areEqual('ERROR', r.cards[2].status);
        Assert.areEqual('broken\nCouldn\'t load broken right now.', r.cards[2].text);
    }

    @IsTest
    static void aFailedBriefIsAnErrorCardThenItsSections() {
        Account a = mkAccount(true);
        Stub stub = install();
        stub.fail = true;

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        Assert.areEqual(CustomerSummary.ERROR, r.status);
        Assert.areEqual(1 + ALL_KEYS.size(), r.cards.size(), 'the sections that loaded are still cards');
        Assert.areEqual('error', r.cards[0].type);
        Assert.areEqual('ERROR', r.cards[0].status);
        Assert.areEqual(CustomerSummary.ERROR_TEXT, r.cards[0].text);
        Assert.areEqual('sec-profile', r.cards[1].key);
    }

    @IsTest
    static void notFoundNoSectionsAndOverTheCapAreOneCardEach() {
        Account a = mkAccount(false);
        install();
        List<CustomerSummary.Result> results = CustomerSummary.runAll(new List<CustomerSummary.Ask>{
            new CustomerSummary.Ask(null, null, null),
            new CustomerSummary.Ask(a.Id, null, new Set<String>{ 'bogus' }),
            new CustomerSummary.Ask(null, null, null),
            new CustomerSummary.Ask(a.Id, null, null)
        });

        Assert.areEqual(new List<String>{ 'notice' }, typesOf(results[0].cards));
        Assert.areEqual(CustomerSummary.NOT_FOUND, results[0].cards[0].status);
        Assert.areEqual(new List<String>{ 'notice' }, typesOf(results[1].cards));
        Assert.areEqual(CustomerSummary.EMPTY, results[1].cards[0].status);
        Assert.areEqual(results[1].answer, results[1].cards[0].text);
        Assert.areEqual(new List<String>{ 'error' }, typesOf(results[3].cards), 'past the request cap');
        Assert.areEqual(CustomerSummary.OVER_CAP_TEXT, results[3].cards[0].text);
    }

    @IsTest
    static void noCardHoldsAFieldTheUserCannotRead() {
        Account a = new Account(Name = 'Card FLS ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Type = 'Customer',
            Industry = 'Healthcare', AnnualRevenue = 5000000, Description = 'Secret plans');
        insert a;
        User u = userWhoReadsOnlyAccountIndustry();
        install();

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, new Set<String>{ 'profile' });
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        String cardJson = AnswerCard.toJson(r.cards);
        Assert.isTrue(cardJson.contains('Industry: Healthcare'), cardJson);
        for (String hidden : new List<String>{ 'Secret plans', '5,000,000', '5000000', 'Type: Customer' }) {
            Assert.isFalse(cardJson.contains(hidden), 'an unreadable field reached a card: ' + hidden);
        }
    }

    private static User userWhoReadsOnlyAccountIndustry() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            String uniq = 'crd' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            u = new User(
                Alias = 'crdmin',
                Email = uniq + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Card Minimal',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York',
                Username = uniq + '@example.com.cardtest'
            );
            insert u;
            PermissionSet ps = new PermissionSet(Name = 'Crd_' + uniq.right(20), Label = 'Card test ' + uniq.right(10));
            insert ps;
            insert new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true, PermissionsViewAllRecords = true);
            insert new FieldPermissions(ParentId = ps.Id, SobjectType = 'Account', Field = 'Account.Industry', PermissionsRead = true);
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    // ------------------------------------------------------------------ customer outcomes (BE-35)

    private static List<Customer_Outcome__c> outcomeRows(Id accountId) {
        return [
            SELECT Outcome_Type__c, Title__c, Headline__c, Body__c, Skill__c, Surface__c, Model__c, CreatedById,
                Sentiment_Score__c, Sentiment_Label__c, Sentiment_Reason__c
            FROM Customer_Outcome__c WHERE Account__c = :accountId WITH SYSTEM_MODE ORDER BY CreatedDate, Id
        ];
    }

    private static User outcomeRep(String profileName, String alias, Boolean outcomes) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            String uniq = alias + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            u = new User(Alias = alias, Email = uniq + '@example.com', EmailEncodingKey = 'UTF-8', LastName = 'Outcome Rep',
                LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
                Username = uniq + '@example.com.summaryoutcome');
            insert u;
            List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('Customer_Summary_Data_Access', 'Customer_Summary_Outcome_Access')]) {
                if (ps.Name == 'Customer_Summary_Data_Access' || outcomes) {
                    grants.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
                }
            }
            PermissionSet industry = new PermissionSet(Name = 'Zqx_' + uniq.right(20), Label = 'Zqx outcome ' + uniq.right(10));
            insert industry;
            insert new FieldPermissions(ParentId = industry.Id, SobjectType = 'Account', Field = 'Account.Industry', PermissionsRead = true);
            grants.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = industry.Id));
            insert grants;
        }
        return u;
    }

    @IsTest
    static void aSummaryIsRecordedAsAnOutcomeAfterEveryModelCall() {
        Account a = mkAccount(true);
        User u = outcomeRep('Standard User', 'sumrec', true);
        Stub stub = install();

        CustomerSummary.Result r;
        Integer before;
        Test.startTest();
        System.runAs(u) {
            before = Limits.getDmlStatements(); // System.runAs itself counts as one DML statement
            r = CustomerSummary.run(a.Id, 'How is the renewal?', null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        for (Integer dml : stub.dmlAtCall) {
            Assert.areEqual(before, dml, 'no write before a model call');
        }
        List<Customer_Outcome__c> rows = outcomeRows(a.Id);
        Assert.areEqual(1, rows.size(), 'one summary outcome');
        Assert.areEqual(CustomerOutcomes.SUMMARY, rows[0].Outcome_Type__c);
        Assert.areEqual('How is the renewal?', rows[0].Title__c);
        Assert.areEqual('Headline finding.', rows[0].Headline__c);
        Assert.areEqual(r.answer, rows[0].Body__c);
        Assert.areEqual(u.Id, rows[0].CreatedById, 'written as the rep');
        Assert.areEqual('summary', rows[0].Skill__c);
        Assert.areEqual('test', rows[0].Surface__c);
        Assert.isTrue(String.isNotBlank(rows[0].Model__c));
        Assert.areEqual(1, memoryRows(), 'session memory still works');
    }

    @IsTest
    static void aFailedOutcomeWriteIsLoggedAndTheSummaryStillReturns() {
        Account a = mkAccount(true);
        install();
        CustomerOutcomes.failWritesForTest = true;

        Test.startTest();
        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual('Headline finding.\nAccount\nBody.', r.answer);
        Assert.areEqual(0, outcomeRows(a.Id).size(), 'no outcome');
        Assert.areEqual(1, memoryRows(), 'the memory write stands on its own');
    }

    @IsTest
    static void aReadOnlyRepsSummaryIsStillRecorded() {
        Account a = mkAccount(false);
        User u = outcomeRep('Minimum Access - Salesforce', 'sumro', true);
        install();

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            Assert.isFalse(Schema.SObjectType.Account.isUpdateable(), 'the rep only reads accounts');
            r = CustomerSummary.run(a.Id, null, new Set<String>{ 'profile' });
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        List<Customer_Outcome__c> rows = outcomeRows(a.Id);
        Assert.areEqual(1, rows.size(), 'read access to the account is enough to record a summary');
        Assert.areEqual(u.Id, rows[0].CreatedById);
        Assert.areEqual(r.answer, rows[0].Body__c);
    }

    @IsTest
    static void aRepWithoutTheOutcomeSetStillGetsTheSummary() {
        Account a = mkAccount(true);
        User u = outcomeRep('Standard User', 'sumno', false);
        Stub stub = install();

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.isFalse(stub.lastSynthesis().contains(CustomerOutcomes.CONTEXT_HEADER), 'no outcome context');
        Assert.areEqual(0, outcomeRows(a.Id).size(), 'no outcome without the outcome set');
        Assert.areEqual(1, memoryRows(), 'the memory write is unaffected');
    }

    /**
     * The MCP door's get_account_summary tool maps to CustomerSummaryGetAction: a second summary through it sees the
     * last summary's headline and date in its synthesis system text.
     */
    @IsTest
    static void aNewSummaryThroughTheActionSeesTheLastSummarysHeadlineAndDate() {
        Account a = mkAccount(true);
        User u = outcomeRep('Standard User', 'sumnew', true);
        Stub stub = install();
        List<CustomerSummaryGetAction.Response> out;
        System.runAs(u) {
            CustomerSummary.run(a.Id, null, null);
        }
        Assert.isFalse(stub.lastSynthesis().contains(CustomerOutcomes.CONTEXT_HEADER), 'nothing before the first summary');

        String authorDay; // the summary's date is the rep's (New York), not the running user's
        Test.startTest();
        System.runAs(u) {
            authorDay = Datetime.now().format('yyyy-MM-dd');
            out = CustomerSummaryGetAction.getBriefs(requestsFor(new List<Account>{ a }));
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, out[0].status, out[0].answer);
        String synthesis = stub.lastSynthesis();
        Assert.isTrue(synthesis.contains('final account summary'), 'the second summary\'s synthesis');
        Assert.isTrue(synthesis.contains(CustomerOutcomes.CONTEXT_HEADER), synthesis.right(400));
        Assert.isTrue(synthesis.contains('- Summary, ' + authorDay + ': Headline finding.'), synthesis.right(400));
        Assert.isFalse(synthesis.contains('Body.'), 'the headline only, never the body');
        Assert.areEqual(2, outcomeRows(a.Id).size());
    }

    // ---- BE-36: sentiment on the summary's outcome ----

    private static Customer_Outcome__c onlyOutcome(Id accountId) {
        List<Customer_Outcome__c> rows = outcomeRows(accountId);
        Assert.areEqual(1, rows.size(), 'one summary outcome');
        return rows[0];
    }

    @IsTest
    static void theSummarysOutcomeCarriesTheSentimentScoreLabelAndReason() {
        Account a = mkFullAccount();
        User u = outcomeRep('Standard User', 'sentok', true);
        Stub stub = install();
        stub.sentimentReply = '{"score": -2, "label": "At risk", "reason": "An open high-priority case and an overdue deal."}';

        CustomerSummary.Result r;
        Integer before;
        Test.startTest();
        System.runAs(u) {
            before = Limits.getDmlStatements();
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual('Headline finding.\nAccount\nBody.', r.answer, 'the answer is the synthesis alone');
        Assert.areEqual(before, stub.dmlAtCall[stub.dmlAtCall.size() - 1], 'the sentiment call runs before any write');
        Customer_Outcome__c row = onlyOutcome(a.Id);
        Assert.areEqual(-2, row.Sentiment_Score__c.intValue());
        Assert.areEqual('At risk', row.Sentiment_Label__c);
        Assert.areEqual('An open high-priority case and an overdue deal.', row.Sentiment_Reason__c);
    }

    @IsTest
    static void theSentimentReadsTheReducedSectionsAndNoRecordId() {
        Account a = mkFullAccount();
        Stub stub = install();

        Test.startTest();
        CustomerSummary.run(a.Id, null, null);
        Test.stopTest();

        String user = stub.sentimentUser();
        Assert.isNotNull(user, 'the sentiment call ran');
        Assert.isTrue(user.contains('Engagement summary:\nENGAGEMENT SUMMARY'), 'the pre-reduced engagement: ' + user);
        Assert.isTrue(user.contains('Deal history summary:\nDEAL HISTORY SUMMARY'), 'the pre-reduced deal history');
        Assert.isTrue(user.contains('Open full deal'), 'the open deals section as the synthesis sees it');
        Assert.isTrue(user.contains('Open full case'), 'the cases section as the synthesis sees it');
        List<Id> recordIds = new List<Id>{ a.Id };
        for (Opportunity o : [SELECT Id FROM Opportunity WHERE AccountId = :a.Id]) {
            recordIds.add(o.Id);
        }
        for (Case c : [SELECT Id FROM Case WHERE AccountId = :a.Id]) {
            recordIds.add(c.Id);
        }
        for (Id recordId : recordIds) {
            Assert.isFalse(user.contains(String.valueOf(recordId).left(15)), 'no record Id reaches the sentiment prompt');
        }
        Assert.isFalse(user.contains(a.Name), 'the account name is not evidence');
    }

    @IsTest
    static void aMalformedSentimentIsStoredAsNoScoreAndTheSummaryReturns() {
        Account a = mkFullAccount();
        User u = outcomeRep('Standard User', 'sentbad', true);
        Stub stub = install();
        stub.sentimentReply = 'They seem pretty happy.';

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual(1, stub.count(SENTIMENT_MARKER));
        Customer_Outcome__c row = onlyOutcome(a.Id);
        Assert.isNull(row.Sentiment_Score__c, 'no score');
        Assert.isNull(row.Sentiment_Label__c, 'no label');
        Assert.isNull(row.Sentiment_Reason__c, 'no reason');
        Assert.areEqual(r.answer, row.Body__c, 'the summary is still recorded');
    }

    @IsTest
    static void aFailedSentimentCallStillGivesTheSummaryAndItsOutcome() {
        Account a = mkFullAccount();
        User u = outcomeRep('Standard User', 'sentfail', true);
        Stub stub = install();
        stub.failSentiment = true;

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual('Headline finding.\nAccount\nBody.', r.answer);
        Customer_Outcome__c row = onlyOutcome(a.Id);
        Assert.isNull(row.Sentiment_Score__c);
        Assert.isNull(row.Sentiment_Label__c);
        Assert.areEqual(1, memoryRows(), 'the memory write is unaffected');
    }

    @IsTest
    static void anAccountWithNothingOnRecordIsNotEnoughActivityWithNoSentimentCall() {
        Account a = mkAccount(false);
        User u = outcomeRep('Standard User', 'sentnil', true);
        Stub stub = install();

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(0, stub.count(SENTIMENT_MARKER), 'sparse data costs no sentiment call');
        Assert.areEqual(1, stub.count('final account summary'), 'the summary is still written');
        Customer_Outcome__c row = onlyOutcome(a.Id);
        Assert.isNull(row.Sentiment_Score__c, 'never a guess');
        Assert.areEqual(CustomerSentiment.NOT_ENOUGH, row.Sentiment_Label__c);
        Assert.areEqual(CustomerSentiment.NO_EVIDENCE_REASON, row.Sentiment_Reason__c);
    }

    @IsTest
    static void aSummaryOfSomeSectionsHasNoSentimentCall() {
        Account a = mkFullAccount();
        User u = outcomeRep('Standard User', 'sentpart', true);
        Stub stub = install();

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, new Set<String>{ 'open_deals', 'cases' });
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual(0, stub.count(SENTIMENT_MARKER), 'a partial summary is not a sentiment reading');
        Assert.isNull(onlyOutcome(a.Id).Sentiment_Label__c);
    }

    @IsTest
    static void pastTheModelTimeBudgetTheSentimentIsSkippedAndTheSummaryStands() {
        Account a = mkFullAccount();
        User u = outcomeRep('Standard User', 'sentbud', true);
        Stub stub = install();
        CustomerSummary.modelMillis = CustomerSummary.SENTIMENT_TIME_BUDGET_MS;

        CustomerSummary.Result r;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummary.run(a.Id, null, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummary.OK, r.status, r.answer);
        Assert.areEqual(3, stub.systems.size(), 'the pre-reduces and the synthesis still run');
        Assert.areEqual(0, stub.count(SENTIMENT_MARKER), 'no sentiment call past the budget');
        Customer_Outcome__c row = onlyOutcome(a.Id);
        Assert.isNull(row.Sentiment_Score__c);
        Assert.isNull(row.Sentiment_Label__c);
        Assert.areEqual(r.answer, row.Body__c);
    }

    @IsTest
    static void underTheModelTimeBudgetTheSentimentRuns() {
        Account a = mkFullAccount();
        Stub stub = install();
        CustomerSummary.modelMillis = CustomerSummary.SENTIMENT_TIME_BUDGET_MS - 1000;

        Test.startTest();
        CustomerSummary.run(a.Id, null, null);
        Test.stopTest();

        Assert.areEqual(1, stub.count(SENTIMENT_MARKER), 'the stub returns at once, so the budget still has room');
    }

    @IsTest
    static void aFailedSummaryMakesNoSentimentCall() {
        Account a = mkFullAccount();
        Stub stub = install();
        stub.fail = true;

        CustomerSummary.Result r = CustomerSummary.run(a.Id, null, null);

        Assert.areEqual(CustomerSummary.ERROR, r.status);
        Assert.areEqual(0, stub.count(SENTIMENT_MARKER));
        Assert.areEqual(0, outcomeRows(a.Id).size(), 'an error is not an outcome');
    }
}
