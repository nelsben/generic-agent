@IsTest
private class CustomerSummaryMemoryTest {

    private static Account makeAccount() {
        Account a = new Account(Name = 'Memory Test Account');
        insert a;
        return a;
    }

    private static User makeUser(String suffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = suffix + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        return new User(
            Alias = suffix.left(5),
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Memory ' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.memorytest'
        );
    }

    @IsTest
    static void firstRecordCreatesOneRow() {
        Account a = makeAccount();
        CustomerSummaryMemory.record(a.Id, 'ok', 'What is the status?', 'Healthy account.\nMore detail below.');

        List<Customer_Summary_Session__c> rows = [
            SELECT Session_Key__c, User__c, Account__c, Brief_Count__c, Last_Status__c,
                   Last_Question__c, Last_Brief__c, Last_Activity__c
            FROM Customer_Summary_Session__c
            WITH SYSTEM_MODE
        ];
        Assert.areEqual(1, rows.size());
        Assert.areEqual(String.valueOf(UserInfo.getUserId()) + '_' + String.valueOf(a.Id), rows[0].Session_Key__c);
        Assert.areEqual(UserInfo.getUserId(), rows[0].User__c);
        Assert.areEqual(a.Id, rows[0].Account__c);
        Assert.areEqual(1, rows[0].Brief_Count__c);
        Assert.areEqual('ok', rows[0].Last_Status__c);
        Assert.areEqual('What is the status?', rows[0].Last_Question__c);
        Assert.areEqual('Healthy account.\nMore detail below.', rows[0].Last_Brief__c);
        Assert.areNotEqual(null, rows[0].Last_Activity__c);

        List<CustomerSummaryMemory.Turn> turns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(1, turns.size());
        Assert.areEqual('Healthy account.', turns[0].headline);
        Assert.areEqual('ok', turns[0].status);
        Assert.areEqual('What is the status?', turns[0].question);
        Assert.areNotEqual(null, turns[0].at);
        Assert.areEqual('Healthy account.\nMore detail below.', CustomerSummaryMemory.lastBrief(a.Id));
    }

    @IsTest
    static void twelveRecordsKeepTenNewestFirst() {
        Account a = makeAccount();
        for (Integer i = 1; i <= 12; i++) {
            CustomerSummaryMemory.record(a.Id, 'ok', 'Q' + i, 'Headline ' + i);
        }

        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE]);
        Customer_Summary_Session__c row = [SELECT Brief_Count__c FROM Customer_Summary_Session__c WITH SYSTEM_MODE LIMIT 1];
        Assert.areEqual(12, row.Brief_Count__c);

        List<CustomerSummaryMemory.Turn> turns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(10, turns.size());
        Assert.areEqual('Headline 12', turns[0].headline);
        Assert.areEqual('Headline 3', turns[9].headline);
        Assert.areEqual('Headline 12', CustomerSummaryMemory.lastBrief(a.Id));
    }

    @IsTest
    static void longAnswerHeadlineIsClipped() {
        Account a = makeAccount();
        CustomerSummaryMemory.record(a.Id, 'ok', 'Q', 'x'.repeat(500) + '\nsecond line');
        Assert.areEqual(200, CustomerSummaryMemory.history(a.Id)[0].headline.length());
    }

    @IsTest
    static void twoUsersGetSeparateRows() {
        User u2 = makeUser('usrtwo');
        insert u2;
        // Owned by the second user, so both can read it whatever the org's account sharing: history re-checks access.
        Account a = new Account(Name = 'Memory Test Account', OwnerId = u2.Id);
        insert a;

        CustomerSummaryMemory.record(a.Id, 'ok', 'Admin question', 'Admin headline');
        System.runAs(u2) {
            CustomerSummaryMemory.record(a.Id, 'partial', 'Other question', 'Other headline');
            List<CustomerSummaryMemory.Turn> mine = CustomerSummaryMemory.history(a.Id);
            Assert.areEqual(1, mine.size());
            Assert.areEqual('Other headline', mine[0].headline);
        }

        List<Customer_Summary_Session__c> rows = [SELECT User__c FROM Customer_Summary_Session__c WITH SYSTEM_MODE];
        Assert.areEqual(2, rows.size());
        List<CustomerSummaryMemory.Turn> adminTurns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(1, adminTurns.size());
        Assert.areEqual('Admin headline', adminTurns[0].headline);
    }

    @IsTest
    static void recordAllSavesSeveralTurnsWithOneWrite() {
        Account a = makeAccount();
        Account b = makeAccount();
        List<CustomerSummaryMemory.Entry> entries = new List<CustomerSummaryMemory.Entry>{
            new CustomerSummaryMemory.Entry(a.Id, 'OK', 'First?', 'A one'),
            null,
            new CustomerSummaryMemory.Entry(b.Id, 'EMPTY', 'Second?', 'B one'),
            new CustomerSummaryMemory.Entry(null, 'OK', 'No account', 'skipped'),
            new CustomerSummaryMemory.Entry(a.Id, 'OK', 'Third?', 'A two')
        };

        Test.startTest();
        CustomerSummaryMemory.recordAll(entries);
        Integer queries = Limits.getQueries();
        Integer dml = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(2, queries, 'one query for every existing row, one for the per-user row cap');
        Assert.areEqual(1, dml, 'one write for every row');
        Assert.areEqual(2, [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE], 'one row per account');
        List<CustomerSummaryMemory.Turn> turnsA = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(2, turnsA.size(), 'both turns for the same account land on one row');
        Assert.areEqual('A two', turnsA[0].headline, 'newest first, in list order');
        Assert.areEqual('A one', turnsA[1].headline);
        Assert.areEqual('A two', CustomerSummaryMemory.lastBrief(a.Id));
        Assert.areEqual(1, CustomerSummaryMemory.history(b.Id).size());
    }

    @IsTest
    static void recordAllAddsToAnExistingRow() {
        Account a = makeAccount();
        CustomerSummaryMemory.record(a.Id, 'OK', 'Before?', 'Earlier');

        CustomerSummaryMemory.recordAll(new List<CustomerSummaryMemory.Entry>{
            new CustomerSummaryMemory.Entry(a.Id, 'OK', 'After?', 'Later')
        });
        CustomerSummaryMemory.recordAll(null);

        Customer_Summary_Session__c row = [SELECT Brief_Count__c, Last_Brief__c FROM Customer_Summary_Session__c WITH SYSTEM_MODE];
        Assert.areEqual(2, row.Brief_Count__c);
        Assert.areEqual('Later', row.Last_Brief__c);
    }

    @IsTest
    static void unknownAccountReturnsEmpty() {
        Account a = makeAccount();
        Assert.areEqual(0, CustomerSummaryMemory.history(a.Id).size());
        Assert.areEqual(null, CustomerSummaryMemory.lastBrief(a.Id));
        Assert.areEqual(0, CustomerSummaryMemory.history(null).size());
    }

    private static Customer_Summary_Session__c rowFor(Id accountId) {
        return [
            SELECT Id, Brief_Count__c, Turns_JSON__c, Last_Activity__c
            FROM Customer_Summary_Session__c
            WHERE Account__c = :accountId AND User__c = :UserInfo.getUserId()
            WITH SYSTEM_MODE
        ];
    }

    @IsTest
    static void aRowSavedByAnotherTransactionIsKeptNotOverwritten() {
        Account a = makeAccount();
        CustomerSummaryMemory.Turn rival = new CustomerSummaryMemory.Turn();
        rival.at = '2026-01-01T00:00:00.000Z';
        rival.status = 'OK';
        rival.question = 'Rival question';
        rival.headline = 'Rival headline';
        // The rival row lands after our read found nothing and before our write: the lost-turn race.
        CustomerSummaryMemory.racingRows = new List<Customer_Summary_Session__c>{
            new Customer_Summary_Session__c(
                Session_Key__c = String.valueOf(UserInfo.getUserId()) + '_' + String.valueOf(a.Id),
                User__c = UserInfo.getUserId(),
                Account__c = a.Id,
                Brief_Count__c = 1,
                Turns_JSON__c = JSON.serialize(new List<CustomerSummaryMemory.Turn>{ rival })
            )
        };

        CustomerSummaryMemory.record(a.Id, 'OK', 'Our question', 'Our headline');

        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE], 'still one row for the key');
        Assert.areEqual(2, rowFor(a.Id).Brief_Count__c, 'both briefs are counted');
        List<CustomerSummaryMemory.Turn> turns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(2, turns.size(), 'neither turn is lost');
        Assert.areEqual('Our headline', turns[0].headline);
        Assert.areEqual('Rival headline', turns[1].headline);
    }

    @IsTest
    static void rowsPerUserAreCappedAndTheOldestGoFirst() {
        CustomerSummaryMemory.maxRowsPerUser = 3;
        Account a1 = makeAccount();
        Account a2 = makeAccount();
        Account a3 = makeAccount();
        for (Account a : new List<Account>{ a1, a2, a3 }) {
            CustomerSummaryMemory.record(a.Id, 'OK', 'Q', 'Headline');
        }
        Assert.areEqual(3, [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE]);
        // a2 is the stalest, then a1... make the order explicit.
        // System mode, like CustomerSummaryMemory's own writes: in a fresh org the deploying user has no
        // field access to this object, and a plain update failed there with "fields being inaccessible".
        Database.update(new List<Customer_Summary_Session__c>{
            new Customer_Summary_Session__c(Id = rowFor(a2.Id).Id, Last_Activity__c = Datetime.now().addDays(-30)),
            new Customer_Summary_Session__c(Id = rowFor(a1.Id).Id, Last_Activity__c = Datetime.now().addDays(-10)),
            new Customer_Summary_Session__c(Id = rowFor(a3.Id).Id, Last_Activity__c = Datetime.now().addDays(-1))
        }, true, AccessLevel.SYSTEM_MODE);

        Account a4 = makeAccount();
        CustomerSummaryMemory.record(a4.Id, 'OK', 'Q', 'Newest');

        Assert.areEqual(3, [SELECT COUNT() FROM Customer_Summary_Session__c WITH SYSTEM_MODE], 'the cap holds');
        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :a2.Id WITH SYSTEM_MODE], 'the stalest row went');
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :a4.Id WITH SYSTEM_MODE], 'the new row stays');
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :a1.Id WITH SYSTEM_MODE]);
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :a3.Id WITH SYSTEM_MODE]);
    }

    @IsTest
    static void theCapNeverPurgesAnotherUsersRows() {
        CustomerSummaryMemory.maxRowsPerUser = 1;
        Account a = makeAccount();
        Account b = makeAccount();
        User other = makeUser('usrcap');
        insert other;
        System.runAs(other) {
            CustomerSummaryMemory.record(a.Id, 'OK', 'Q', 'Other user');
        }

        CustomerSummaryMemory.record(a.Id, 'OK', 'Q', 'Mine one');
        CustomerSummaryMemory.record(b.Id, 'OK', 'Q', 'Mine two');

        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId() WITH SYSTEM_MODE]);
        Assert.areEqual(1, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :other.Id WITH SYSTEM_MODE]);
    }

    @IsTest
    static void aRowSavedBeforeSessionsGetsItsTitleStartAndCountFromItsTurns() {
        Account a = makeAccount();
        CustomerSummaryMemory.Turn old = new CustomerSummaryMemory.Turn();
        old.at = '2026-01-02T03:04:05.000Z';
        old.status = 'OK';
        old.question = 'An old question';
        old.headline = 'Old headline';
        Database.insert(new Customer_Summary_Session__c(
            Session_Key__c = String.valueOf(UserInfo.getUserId()) + '_' + String.valueOf(a.Id),
            User__c = UserInfo.getUserId(),
            Account__c = a.Id,
            Brief_Count__c = 1,
            Last_Activity__c = Datetime.now(),
            Turns_JSON__c = JSON.serialize(new List<CustomerSummaryMemory.Turn>{ old })
        ), true, AccessLevel.SYSTEM_MODE);

        CustomerSummaryMemory.record(a.Id, 'OK', 'A new question', 'New headline');

        Customer_Summary_Session__c row = [
            SELECT Title__c, Started__c, Turn_Count__c, Brief_Count__c
            FROM Customer_Summary_Session__c WHERE Account__c = :a.Id WITH SYSTEM_MODE
        ];
        Assert.areEqual('An old question', row.Title__c, 'the oldest kept question titles the session');
        Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 2, 3, 4, 5), row.Started__c, 'started at the oldest kept turn');
        Assert.areEqual(2, row.Turn_Count__c, 'the kept turn and the new one');
        Assert.areEqual(2, row.Brief_Count__c);
        List<CustomerSummaryMemory.Turn> turns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(2, turns.size(), 'a turn without a kind counts as a summary');
        Assert.areEqual(CustomerSummaryMemory.KIND_SUMMARY, turns[0].kind);
        Assert.isNull(turns[1].kind);
    }

    @IsTest
    static void historyListsOnlySummariesAcrossSessions() {
        Account a = makeAccount();
        CustomerSummaryMemory.record(a.Id, 'OK', 'Earlier session', 'Earlier brief');
        Database.update(new Customer_Summary_Session__c(
            Id = rowFor(a.Id).Id, Last_Activity__c = Datetime.now().addDays(-2)
        ), true, AccessLevel.SYSTEM_MODE);
        CustomerSummaryMemory.recordAll(new List<CustomerSummaryMemory.Entry>{
            new CustomerSummaryMemory.Entry(a.Id, 'OK', 'Explorer question', 'Explorer answer', CustomerSummaryMemory.KIND_EXPLORER),
            new CustomerSummaryMemory.Entry(a.Id, 'OK', 'Current session', 'Current brief')
        });

        List<CustomerSummaryMemory.Turn> turns = CustomerSummaryMemory.history(a.Id);
        Assert.areEqual(2, [SELECT COUNT() FROM Customer_Summary_Session__c WHERE Account__c = :a.Id WITH SYSTEM_MODE], 'two sessions');
        Assert.areEqual(2, turns.size(), 'the explorer turn is not an earlier summary');
        Assert.areEqual('Current brief', turns[0].headline);
        Assert.areEqual('Earlier brief', turns[1].headline, 'summaries of ended sessions are still listed');
        Assert.areEqual('Current brief', CustomerSummaryMemory.lastBrief(a.Id));
    }
}
