@IsTest
private class CustomerSummaryHistoryTest {
    /** Scripted replies in order, then a fixed text; never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> replies = new List<String>();

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (!replies.isEmpty()) {
                return replies.remove(0);
            }
            return 'History headline.\nFirst point.';
        }
    }

    private static User newUser(String profileName, String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = alias + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return new User(
            Alias = alias,
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'History ' + alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.historytest'
        );
    }

    /** A rep: the given profile plus the product's data-access permission set. Setup DML runs apart from record DML. */
    private static User rep(String profileName, String alias) {
        User u = newUser(profileName, alias);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PermissionSet data = [SELECT Id FROM PermissionSet WHERE Name = 'Customer_Summary_Data_Access' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = data.Id);
        }
        return u;
    }

    private static Account account(String name, Id ownerId) {
        Account a = new Account(Name = name, OwnerId = ownerId);
        insert a;
        return a;
    }

    /** Session rows owned by the user, as the memory class leaves them, last active i minutes ago for i = 1..count. */
    private static List<Customer_Summary_Session__c> seedSessions(User u, Account a, Integer count) {
        List<Customer_Summary_Session__c> rows = new List<Customer_Summary_Session__c>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(new Customer_Summary_Session__c(
                OwnerId = u.Id,
                User__c = u.Id,
                Account__c = a.Id,
                Session_Key__c = String.valueOf(u.Id) + '_' + String.valueOf(a.Id) + '_seed' + i,
                Title__c = 'Session ' + i,
                Started__c = Datetime.now().addMinutes(-i - 5),
                Last_Activity__c = Datetime.now().addMinutes(-i),
                Turn_Count__c = i,
                Brief_Count__c = i,
                Turns_JSON__c = '[]'
            ));
        }
        Database.insert(rows, true, AccessLevel.SYSTEM_MODE);
        return rows;
    }

    private static Integer rowCount(Id accountId) {
        return [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :accountId WITH SYSTEM_MODE];
    }

    @IsTest
    static void sessionsAreListedNewestFirstWithTheDefaultLimit() {
        User u = rep('Standard User', 'hord');
        Account a = account('History Order', u.Id);
        seedSessions(u, a, 12);

        List<CustomerSummaryHistory.SessionSummary> listed;
        Test.startTest();
        System.runAs(u) {
            listed = CustomerSummaryHistory.listSessions(a.Id, null);
        }
        Test.stopTest();

        Assert.areEqual(CustomerSummaryHistory.DEFAULT_LIMIT, listed.size(), 'a null limit lists the default 10');
        Assert.areEqual('Session 1', listed[0].title, 'the most recently active session comes first');
        Assert.areEqual('Session 10', listed[9].title);
        Assert.areEqual(1, listed[0].turnCount);
        Assert.areEqual(a.Id, listed[0].accountId);
        Assert.isNotNull(listed[0].lastActive, 'last active is listed');
        Assert.isNotNull(listed[0].startedAt, 'started is listed');
        for (Integer i = 1; i < listed.size(); i++) {
            Assert.isTrue(listed[i - 1].lastActive >= listed[i].lastActive, 'newest first at ' + i);
        }
        Map<String, Object> wire = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(listed[0]));
        Assert.isFalse(wire.containsKey('turns'), 'a listing carries no turns');
    }

    @IsTest
    static void theLimitIsHonouredAndCappedAtFifty() {
        User u = rep('Standard User', 'hlim');
        Account a = account('History Limits', u.Id);
        seedSessions(u, a, 55);

        Integer three;
        Integer capped;
        Integer zero;
        Test.startTest();
        System.runAs(u) {
            three = CustomerSummaryHistory.listSessions(a.Id, 3).size();
            capped = CustomerSummaryHistory.listSessions(a.Id, 500).size();
            zero = CustomerSummaryHistory.listSessions(a.Id, 0).size();
        }
        Test.stopTest();

        Assert.areEqual(3, three, 'a limit of 3 lists 3');
        Assert.areEqual(CustomerSummaryHistory.MAX_LIMIT, capped, 'no more than 50, whatever is asked');
        Assert.areEqual(CustomerSummaryHistory.DEFAULT_LIMIT, zero, 'a limit below 1 lists the default');
    }

    @IsTest
    static void anAccountWithNoSessionsListsNone() {
        User u = rep('Standard User', 'hnon');
        Account a = account('History None', u.Id);

        List<CustomerSummaryHistory.SessionSummary> listed;
        CustomerSummaryHistory.SessionDetail none;
        Test.startTest();
        System.runAs(u) {
            listed = CustomerSummaryHistory.listSessions(a.Id, 10);
            none = CustomerSummaryHistory.getSession(null);
        }
        Test.stopTest();

        Assert.isNotNull(listed, 'an empty list, not null');
        Assert.areEqual(0, listed.size());
        Assert.isNull(none, 'no session Id, no session');
    }

    @IsTest
    static void aRepSeesNoneOfAnotherRepsSessionsEvenWhenShared() {
        User first = rep('Standard User', 'hon1');
        User second = rep('Standard User', 'hon2');
        Account a = account('History Own Only', first.Id);
        Customer_Summary_Session__c firstRow = seedSessions(first, a, 1)[0];
        Customer_Summary_Session__c secondRow = new Customer_Summary_Session__c(
            OwnerId = second.Id, User__c = second.Id, Account__c = a.Id,
            Session_Key__c = String.valueOf(second.Id) + '_' + String.valueOf(a.Id),
            Title__c = 'Mine', Started__c = Datetime.now(), Last_Activity__c = Datetime.now(), Turn_Count__c = 1
        );
        Database.insert(secondRow, true, AccessLevel.SYSTEM_MODE);
        // Share the first rep's row with the second, so only the own-only filter can keep it out.
        Database.insert(new Customer_Summary_Session__Share(
            ParentId = firstRow.Id, UserOrGroupId = second.Id, AccessLevel = 'Read', RowCause = 'Manual'
        ), true, AccessLevel.SYSTEM_MODE);

        Integer readableBySharing;
        List<CustomerSummaryHistory.SessionSummary> listed;
        CustomerSummaryHistory.SessionDetail other;
        Test.startTest();
        System.runAs(second) {
            readableBySharing = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Id = :firstRow.Id WITH USER_MODE];
            listed = CustomerSummaryHistory.listSessions(a.Id, 50);
            other = CustomerSummaryHistory.getSession(firstRow.Id);
        }
        Test.stopTest();

        Assert.areEqual(1, readableBySharing, 'the share lets the second rep read the row, so the filter is what hides it');
        Assert.areEqual(1, listed.size(), 'only the second rep own session');
        Assert.areEqual(secondRow.Id, listed[0].id);
        Assert.isNull(other, 'another rep session is never reopened');
    }

    @IsTest
    static void aSessionReopensWithItsTurnsInOrder() {
        User u = rep('Standard User', 'hreo');
        Account a = account('History Reopen', u.Id);
        String longQuestion = 'Tell me everything about the renewal, '.repeat(4);

        List<CustomerSummaryHistory.SessionSummary> listed;
        CustomerSummaryHistory.SessionDetail opened;
        Test.startTest();
        System.runAs(u) {
            CustomerSummaryMemory.record(a.Id, 'OK', longQuestion, 'First headline.\nMore.');
            CustomerSummaryMemory.recordAll(new List<CustomerSummaryMemory.Entry>{
                new CustomerSummaryMemory.Entry(a.Id, 'OK', 'Second question', 'Second headline.', CustomerSummaryMemory.KIND_EXPLORER)
            });
            CustomerSummaryMemory.record(a.Id, 'OK', 'Third question', 'Third headline.');
            listed = CustomerSummaryHistory.listSessions(a.Id, null);
            opened = CustomerSummaryHistory.getSession(listed[0].id);
        }
        Test.stopTest();

        Assert.areEqual(1, listed.size(), 'three quick turns are one session');
        Assert.areEqual(longQuestion.trim().left(80).trim(), listed[0].title, 'the title is the first question, at most 80 characters');
        Assert.isTrue(listed[0].title.length() <= 80);
        Assert.areEqual(3, listed[0].turnCount);
        Assert.areEqual(listed[0].id, opened.id);
        Assert.areEqual(listed[0].title, opened.title);
        Assert.areEqual(3, opened.turns.size());
        Assert.areEqual('First headline.', opened.turns[0].headline, 'turns come oldest first');
        Assert.areEqual('Second headline.', opened.turns[1].headline);
        Assert.areEqual('Third headline.', opened.turns[2].headline);
        Assert.areEqual(CustomerSummaryMemory.KIND_SUMMARY, opened.turns[0].kind);
        Assert.areEqual(CustomerSummaryMemory.KIND_EXPLORER, opened.turns[1].kind);
    }

    @IsTest
    static void anExplorerTurnFromThePanelIsRecordedAndReturned() {
        User u = rep('Standard User', 'hexp');
        Account a = account('History Explorer', u.Id);
        insert new Opportunity(AccountId = a.Id, OwnerId = u.Id, Name = 'History Deal', StageName = 'Prospecting',
            Amount = 700, CloseDate = Date.today().addDays(20));
        Stub s = new Stub();
        s.replies = new List<String>{
            '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Amount"],'
                + '"filters":[{"field":"AccountId","op":"=","value":"' + a.Id + '"}]}}',
            '{"action":"answer","text":"One open deal.\\nWorth 700.","followups":[]}'
        };
        AgentLlm.stub = s;

        DataExplorer.Result r;
        List<CustomerSummaryHistory.SessionSummary> listed;
        CustomerSummaryHistory.SessionDetail opened;
        Test.startTest();
        System.runAs(u) {
            r = CustomerSummaryPanelController.explore('What deals are open?', a.Id, null);
            listed = CustomerSummaryHistory.listSessions(a.Id, null);
            opened = listed.isEmpty() ? null : CustomerSummaryHistory.getSession(listed[0].id);
        }
        Test.stopTest();

        Assert.areEqual(DataExplorer.OK, r.status, 'the explorer answered: ' + r.answer);
        Assert.areEqual(1, listed.size(), 'the explorer question started a session');
        Assert.areEqual('What deals are open?', listed[0].title);
        Assert.areEqual(1, opened.turns.size());
        Assert.areEqual(CustomerSummaryMemory.KIND_EXPLORER, opened.turns[0].kind);
        Assert.areEqual('What deals are open?', opened.turns[0].question);
        Assert.areEqual('One open deal.', opened.turns[0].headline);
        Customer_Summary_Session__c row = [
            SELECT Brief_Count__c, Last_Brief__c FROM Customer_Summary_Session__c WHERE Account__c = :a.Id WITH SYSTEM_MODE
        ];
        Assert.areEqual(0, row.Brief_Count__c, 'an explorer turn is not a brief');
        Assert.isNull(row.Last_Brief__c, 'an explorer answer never replaces the last brief');
    }

    @IsTest
    static void aSessionIsHiddenOnceItsAccountIsNoLongerReadable() {
        User u = rep('Minimum Access - Salesforce', 'hlost');
        PermissionSetAssignment accountRead;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = new PermissionSet(Name = 'Zqx_History_Account_Read', Label = 'Zqx History Account Read');
            insert ps;
            insert new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true);
            accountRead = new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            insert accountRead;
        }
        Account a = account('History Lost Access', u.Id);

        List<CustomerSummaryHistory.SessionSummary> before;
        List<CustomerSummaryHistory.SessionSummary> after;
        CustomerSummaryHistory.SessionDetail reopened;
        Test.startTest();
        System.runAs(u) {
            CustomerSummaryMemory.record(a.Id, 'OK', 'Before the change', 'Renewal on track.');
            before = CustomerSummaryHistory.listSessions(a.Id, null);
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete accountRead;
        }
        System.runAs(u) {
            after = CustomerSummaryHistory.listSessions(a.Id, null);
            reopened = CustomerSummaryHistory.getSession(before[0].id);
        }
        Test.stopTest();

        Assert.areEqual(1, before.size(), 'listed while the account is readable');
        Assert.areEqual(0, after.size(), 'hidden once the account is not');
        Assert.isNull(reopened, 'and it cannot be reopened');
        Assert.areEqual(1, rowCount(a.Id), 'hidden, not deleted');
    }

    @IsTest
    static void aQuestionAfterTheTimeoutStartsANewSession() {
        User u = rep('Standard User', 'htim');
        Account a = account('History Timeout', u.Id);

        List<CustomerSummaryHistory.SessionSummary> listed;
        String lastBrief;
        Test.startTest();
        System.runAs(u) {
            CustomerSummaryMemory.record(a.Id, 'OK', 'First visit', 'First brief.');
            CustomerSummaryMemory.record(a.Id, 'OK', 'Still the first visit', 'Second brief.');
        }
        Assert.areEqual(1, rowCount(a.Id), 'a question within the timeout continues the session');
        Database.update(new Customer_Summary_Session__c(
            Id = [SELECT Id FROM Customer_Summary_Session__c WHERE Account__c = :a.Id WITH SYSTEM_MODE].Id,
            Last_Activity__c = Datetime.now().addMinutes(-(CustomerSummaryMemory.sessionTimeoutMinutes + 1))
        ), true, AccessLevel.SYSTEM_MODE);
        System.runAs(u) {
            CustomerSummaryMemory.record(a.Id, 'OK', 'Second visit', 'Third brief.');
            listed = CustomerSummaryHistory.listSessions(a.Id, null);
            lastBrief = CustomerSummaryMemory.lastBrief(a.Id);
        }
        Test.stopTest();

        Assert.areEqual(2, rowCount(a.Id), 'the question after the timeout started a new session');
        Assert.areEqual(2, listed.size());
        Assert.areEqual('Second visit', listed[0].title, 'the new session is newest');
        Assert.areEqual(1, listed[0].turnCount);
        Assert.areEqual('First visit', listed[1].title, 'the earlier session keeps its title');
        Assert.areEqual(2, listed[1].turnCount, 'and its turns');
        Assert.areEqual('Third brief.', lastBrief, 'the last brief follows the current session');
        String currentKey = String.valueOf(u.Id) + '_' + String.valueOf(a.Id);
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Session_Key__c = :currentKey AND Id = :listed[0].id WITH SYSTEM_MODE],
            'the current session holds the user-and-account key');
    }
}
