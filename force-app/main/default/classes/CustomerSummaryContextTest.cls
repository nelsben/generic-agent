@IsTest
private class CustomerSummaryContextTest {

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static User minimalUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'ctx' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'ctxmin',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Context Minimal',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.contexttest'
        );
        insert u;
        return u;
    }

    private static Datetime daysAgo(Integer days) {
        return Datetime.newInstance(Date.today().addDays(-days), Time.newInstance(12, 0, 0, 0));
    }

    private static void assertEmpty(CustomerSummaryContext.Context ctx) {
        Assert.isNotNull(ctx, 'getContext never returns null');
        Assert.areEqual(0, ctx.openDeals.size(), 'no open deals');
        Assert.areEqual(0, ctx.recentActivity.size(), 'no recent activity');
        Assert.areEqual(0, ctx.openCases.size(), 'no open cases');
        Assert.isNull(ctx.lastSummary, 'no last summary');
    }

    @IsTest
    static void openDealsAreSoonestCloseFirstAndCappedAtFive() {
        Account a = makeAccount('Context Deals');
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 7; i >= 1; i--) {
            opps.add(new Opportunity(AccountId = a.Id, Name = 'Deal ' + i, StageName = 'Prospecting',
                Amount = 1000 * i, CloseDate = Date.today().addDays(i)));
        }
        opps.add(new Opportunity(AccountId = a.Id, Name = 'Won deal', StageName = 'Closed Won',
            Amount = 5, CloseDate = Date.today().addDays(-30)));
        insert opps;

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        Assert.areEqual(CustomerSummaryContext.DEAL_CAP, ctx.openDeals.size(), 'open deals are capped');
        for (Integer i = 0; i < ctx.openDeals.size(); i++) {
            CustomerSummaryContext.Deal d = ctx.openDeals[i];
            Assert.areEqual('Deal ' + (i + 1), d.name, 'soonest close first');
            Assert.areEqual('Prospecting', d.stage, 'stage');
            Assert.areEqual(1000 * (i + 1), d.amount, 'amount');
            Assert.areEqual(Date.today().addDays(i + 1), d.closeDate, 'close date');
            Assert.isNotNull(d.recordId, 'the rail keeps the Id to open the deal');
        }
    }

    @IsTest
    static void recentActivityMergesEverySourceNewestFirstCappedAtTen() {
        Account a = makeAccount('Context Activity');
        Contact c = new Contact(AccountId = a.Id, LastName = 'Rivera');
        insert c;
        Case cs = new Case(AccountId = a.Id, Subject = 'Broken router', Status = 'New', Priority = 'High');
        insert cs;

        // Twelve past items on distinct days (1 = newest), one future event and one task due later.
        insert new List<Task>{
            new Task(WhatId = a.Id, Subject = 'Call 1', TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-1), Status = 'Completed'),
            new Task(WhoId = c.Id, Subject = 'Task 4', ActivityDate = Date.today().addDays(-4), Status = 'Completed'),
            new Task(WhatId = a.Id, Subject = 'Task 7', ActivityDate = Date.today().addDays(-7), Status = 'Completed'),
            new Task(WhatId = a.Id, Subject = 'Task 12', ActivityDate = Date.today().addDays(-12), Status = 'Completed'),
            new Task(WhatId = a.Id, Subject = 'Future task', ActivityDate = Date.today().addDays(5), Status = 'Not Started')
        };
        insert new List<Event>{
            new Event(WhatId = a.Id, Subject = 'Event 2', StartDateTime = daysAgo(2), DurationInMinutes = 30),
            new Event(WhoId = c.Id, Subject = 'Event 5', StartDateTime = daysAgo(5), DurationInMinutes = 30),
            new Event(WhatId = a.Id, Subject = 'Event 9', StartDateTime = daysAgo(9), DurationInMinutes = 30),
            new Event(WhatId = a.Id, Subject = 'Future event', StartDateTime = Datetime.now().addDays(3), DurationInMinutes = 30)
        };
        insert new List<EmailMessage>{
            new EmailMessage(RelatedToId = a.Id, Subject = 'Email 3', FromName = 'Pat Buyer', MessageDate = daysAgo(3), Status = '3'),
            new EmailMessage(RelatedToId = a.Id, Subject = 'Email 10', FromName = 'Pat Buyer', MessageDate = daysAgo(10), Status = '3')
        };
        List<CaseComment> comments = new List<CaseComment>{
            new CaseComment(ParentId = cs.Id, CommentBody = 'Comment 6'),
            new CaseComment(ParentId = cs.Id, CommentBody = 'Comment 8'),
            new CaseComment(ParentId = cs.Id, CommentBody = 'Comment 11')
        };
        insert comments;
        Test.setCreatedDate(comments[0].Id, daysAgo(6));
        Test.setCreatedDate(comments[1].Id, daysAgo(8));
        Test.setCreatedDate(comments[2].Id, daysAgo(11));

        Test.startTest();
        Integer before = Limits.getQueries();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Integer used = Limits.getQueries() - before;
        Test.stopTest();

        Assert.isTrue(used <= 8, 'one call stays within 8 SOQL queries, used ' + used);
        List<String> texts = new List<String>();
        for (CustomerSummaryContext.Activity item : ctx.recentActivity) {
            texts.add(item.text);
            Assert.isNotNull(item.recordId, 'the rail keeps the Id to open the record');
            Assert.isNotNull(item.activityDate, 'each item has a date');
        }
        Assert.areEqual(new List<String>{
            'Call 1', 'Event 2', 'Email 3', 'Task 4', 'Event 5', 'Comment 6', 'Task 7', 'Comment 8', 'Event 9', 'Email 10'
        }, texts, 'newest ten across tasks, events, emails and case comments, newest first');

        Map<String, CustomerSummaryContext.Activity> byText = new Map<String, CustomerSummaryContext.Activity>();
        for (CustomerSummaryContext.Activity item : ctx.recentActivity) {
            byText.put(item.text, item);
        }
        Assert.areEqual('call', byText.get('Call 1').kind, 'a call task is a call');
        Assert.areEqual('event', byText.get('Event 2').kind, 'an event');
        Assert.areEqual('email', byText.get('Email 3').kind, 'an email');
        Assert.areEqual('Pat Buyer', byText.get('Email 3').who, 'an email is from its sender');
        Assert.areEqual('task', byText.get('Task 4').kind, 'a plain task');
        Assert.areEqual('Rivera', byText.get('Task 4').who, 'a task on a contact names the contact');
        Assert.areEqual('Rivera', byText.get('Event 5').who, 'an event on a contact names the contact');
        Assert.areEqual('case_comment', byText.get('Comment 6').kind, 'a case comment');
        Assert.areEqual(cs.Id, byText.get('Comment 6').recordId, 'a case comment opens its case');
        Assert.areEqual(UserInfo.getName(), byText.get('Comment 6').who, 'a case comment names its author');
        Assert.areEqual(Date.today().addDays(-6), byText.get('Comment 6').activityDate, 'a case comment is dated when written');
    }

    @IsTest
    static void anEmailLoggedOnADealShowsOnceWithAnExcerpt() {
        Account a = makeAccount('Context Email');
        Opportunity o = new Opportunity(AccountId = a.Id, Name = 'Rollout', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert o;
        String body = 'We would like to expand the rollout. '.repeat(10);
        // Related to the deal, not the account: it reaches the rail through the task it is logged as.
        EmailMessage em = new EmailMessage(RelatedToId = o.Id, TextBody = body, FromName = 'Ada Okafor',
            MessageDate = daysAgo(1), Status = '3');
        insert em;
        Id loggedAs = [SELECT ActivityId FROM EmailMessage WHERE Id = :em.Id WITH SYSTEM_MODE].ActivityId;

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        Assert.isNotNull(loggedAs, 'the platform logs the email as a task on the deal');
        Assert.areEqual(1, ctx.recentActivity.size(), 'the email replaces the task it was logged as');
        CustomerSummaryContext.Activity item = ctx.recentActivity[0];
        Assert.areEqual('email', item.kind, 'kind');
        Assert.areEqual(em.Id, item.recordId, 'opens the email');
        Assert.areEqual(CustomerSummaryContext.TEXT_MAX, item.text.length(), 'an excerpt is 140 characters');
        Assert.isTrue(body.startsWith(item.text.removeEnd('…')), 'the excerpt is the start of the body');
        Assert.areEqual('Ada Okafor', item.who, 'from the sender');
    }

    @IsTest
    static void openCasesAreMostUrgentFirstAndCappedAtFive() {
        Account a = makeAccount('Context Cases');
        List<Case> cases = new List<Case>{
            new Case(AccountId = a.Id, Subject = 'Low old', Priority = 'Low', Status = 'New'),
            new Case(AccountId = a.Id, Subject = 'Medium', Priority = 'Medium', Status = 'Working'),
            new Case(AccountId = a.Id, Subject = 'High new', Priority = 'High', Status = 'New'),
            new Case(AccountId = a.Id, Subject = 'High old', Priority = 'High', Status = 'Escalated'),
            new Case(AccountId = a.Id, Subject = 'Low new', Priority = 'Low', Status = 'New'),
            new Case(AccountId = a.Id, Subject = 'Low newest', Priority = 'Low', Status = 'New'),
            new Case(AccountId = a.Id, Subject = 'Closed high', Priority = 'High', Status = 'Closed')
        };
        insert cases;
        Test.setCreatedDate(cases[0].Id, daysAgo(40));
        Test.setCreatedDate(cases[1].Id, daysAgo(10));
        Test.setCreatedDate(cases[2].Id, daysAgo(2));
        Test.setCreatedDate(cases[3].Id, daysAgo(20));
        Test.setCreatedDate(cases[4].Id, daysAgo(5));
        Test.setCreatedDate(cases[5].Id, daysAgo(1));

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        List<String> subjects = new List<String>();
        for (CustomerSummaryContext.CaseRow row : ctx.openCases) {
            subjects.add(row.subject);
            Assert.isNotNull(row.recordId, 'the rail keeps the Id to open the case');
            Assert.isNotNull(row.caseNumber, 'case number');
        }
        Assert.areEqual(new List<String>{ 'High old', 'High new', 'Medium', 'Low old', 'Low new' }, subjects,
            'High, then Medium, then Low, oldest first within a priority, five at most');
        Assert.areEqual('Escalated', ctx.openCases[0].status, 'status');
        Assert.areEqual('High', ctx.openCases[0].priority, 'priority');
    }

    @IsTest
    static void lastSummaryIsTheFirstLinesOfTheUsersOwnNewestBrief() {
        Account a = makeAccount('Context Summary');
        CustomerSummaryMemory.record(a.Id, 'OK', 'summarize', 'Old brief.');
        CustomerSummaryMemory.record(a.Id, 'OK', 'summarize', 'Renewal at risk.\n\nTwo deals overdue.\nOne high case.\nMore detail.');

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        Assert.isNotNull(ctx.lastSummary, 'the stored brief is returned');
        Assert.areEqual('Renewal at risk.\nTwo deals overdue.\nOne high case.', ctx.lastSummary.firstLines,
            'the first three non-blank lines of the newest brief');
        Assert.areEqual(Date.today(), ctx.lastSummary.summaryDate.date(), 'dated when it was saved');
    }

    @IsTest
    static void aRepWithTheDataAccessSetReadsTheirOwnLastSummary() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = 'ctxrep' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User rep = new User(Alias = 'ctxrep', Email = uniq + '@example.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Context Rep', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York', Username = uniq + '@example.com.contexttest');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert rep;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Customer_Summary_Data_Access' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = rep.Id, PermissionSetId = ps.Id);
        }

        CustomerSummaryContext.Context ctx;
        Test.startTest();
        System.runAs(rep) {
            Account a = makeAccount('Context Rep Account');
            CustomerSummaryMemory.record(a.Id, 'OK', 'summarize', 'Quiet quarter.\nNo open cases.');
            ctx = CustomerSummaryContext.getContext(a.Id);
        }
        Test.stopTest();

        Assert.isNotNull(ctx.lastSummary, 'a rep reads their own stored summary in user mode');
        Assert.areEqual('Quiet quarter.\nNo open cases.', ctx.lastSummary.firstLines, 'first lines');
        Assert.areEqual(0, ctx.unavailable.size(), 'every part loads for a rep: ' + ctx.unavailable);
    }

    @IsTest
    static void anEmptyAccountGivesEmptyListsAndNoSummary() {
        Account a = makeAccount('Context Empty');

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        assertEmpty(ctx);
        Assert.areEqual(0, ctx.unavailable.size(), 'nothing failed to load');
    }

    @IsTest
    static void aNullAccountIdGivesAnEmptyContext() {
        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(null);
        Test.stopTest();

        assertEmpty(ctx);
    }

    @IsTest
    static void aUserWithoutAccessSeesNothingAndGetsNoError() {
        Account a = makeAccount('Context No Access');
        insert new Opportunity(AccountId = a.Id, Name = 'Hidden deal', StageName = 'Prospecting', CloseDate = Date.today());
        insert new Case(AccountId = a.Id, Subject = 'Hidden case', Status = 'New');
        insert new Task(WhatId = a.Id, Subject = 'Hidden task', ActivityDate = Date.today(), Status = 'Completed');
        CustomerSummaryMemory.record(a.Id, 'OK', 'summarize', 'Admin brief.');
        User u = minimalUser();

        CustomerSummaryContext.Context ctx;
        Test.startTest();
        System.runAs(u) {
            ctx = CustomerSummaryContext.getContext(a.Id);
        }
        Test.stopTest();

        assertEmpty(ctx);
    }

    @IsTest
    static void aMissingObjectLeavesOnlyThatListEmpty() {
        Account a = makeAccount('Context Missing');
        Case cs = new Case(AccountId = a.Id, Subject = 'Open case', Status = 'New', Priority = 'Low');
        insert cs;
        insert new CaseComment(ParentId = cs.Id, CommentBody = 'A comment');
        EmailMessage em = new EmailMessage(RelatedToId = a.Id, Subject = 'An email', MessageDate = daysAgo(2), Status = '3');
        insert em;
        insert new Task(WhatId = a.Id, Subject = 'A call', TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-3), Status = 'Completed');
        CustomerSummaryContext.unreadable = new Set<String>{ CustomerSummaryContext.EMAILS, CustomerSummaryContext.CASE_COMMENTS };

        Test.startTest();
        CustomerSummaryContext.Context ctx = CustomerSummaryContext.getContext(a.Id);
        Test.stopTest();

        Set<String> kinds = new Set<String>();
        Set<String> texts = new Set<String>();
        for (CustomerSummaryContext.Activity item : ctx.recentActivity) {
            kinds.add(item.kind);
            texts.add(item.text);
            Assert.areNotEqual(em.Id, item.recordId, 'no item comes from the unreadable emails');
        }
        Assert.isTrue(texts.contains('A call'), 'the call task still shows: ' + texts);
        Assert.isFalse(kinds.contains('case_comment'), 'case comments are left out: ' + kinds);
        Assert.areEqual(1, ctx.openCases.size(), 'the cases list still loads');
        Assert.areEqual(new List<String>{ CustomerSummaryContext.EMAILS, CustomerSummaryContext.CASE_COMMENTS }, ctx.unavailable,
            'the lists that could not load are named');
    }
}
