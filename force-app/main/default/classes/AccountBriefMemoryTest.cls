@IsTest
private class AccountBriefMemoryTest {

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
        AccountBriefMemory.record(a.Id, 'ok', 'What is the status?', 'Healthy account.\nMore detail below.');

        List<Account_Brief_Session__c> rows = [
            SELECT Session_Key__c, User__c, Account__c, Brief_Count__c, Last_Status__c,
                   Last_Question__c, Last_Brief__c, Last_Activity__c
            FROM Account_Brief_Session__c
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, rows.size());
        System.assertEquals(String.valueOf(UserInfo.getUserId()) + '_' + String.valueOf(a.Id), rows[0].Session_Key__c);
        System.assertEquals(UserInfo.getUserId(), rows[0].User__c);
        System.assertEquals(a.Id, rows[0].Account__c);
        System.assertEquals(1, rows[0].Brief_Count__c);
        System.assertEquals('ok', rows[0].Last_Status__c);
        System.assertEquals('What is the status?', rows[0].Last_Question__c);
        System.assertEquals('Healthy account.\nMore detail below.', rows[0].Last_Brief__c);
        System.assertNotEquals(null, rows[0].Last_Activity__c);

        List<AccountBriefMemory.Turn> turns = AccountBriefMemory.history(a.Id);
        System.assertEquals(1, turns.size());
        System.assertEquals('Healthy account.', turns[0].headline);
        System.assertEquals('ok', turns[0].status);
        System.assertEquals('What is the status?', turns[0].question);
        System.assertNotEquals(null, turns[0].at);
        System.assertEquals('Healthy account.\nMore detail below.', AccountBriefMemory.lastBrief(a.Id));
    }

    @IsTest
    static void twelveRecordsKeepTenNewestFirst() {
        Account a = makeAccount();
        for (Integer i = 1; i <= 12; i++) {
            AccountBriefMemory.record(a.Id, 'ok', 'Q' + i, 'Headline ' + i);
        }

        System.assertEquals(1, [SELECT COUNT() FROM Account_Brief_Session__c WITH SYSTEM_MODE]);
        Account_Brief_Session__c row = [SELECT Brief_Count__c FROM Account_Brief_Session__c WITH SYSTEM_MODE LIMIT 1];
        System.assertEquals(12, row.Brief_Count__c);

        List<AccountBriefMemory.Turn> turns = AccountBriefMemory.history(a.Id);
        System.assertEquals(10, turns.size());
        System.assertEquals('Headline 12', turns[0].headline);
        System.assertEquals('Headline 3', turns[9].headline);
        System.assertEquals('Headline 12', AccountBriefMemory.lastBrief(a.Id));
    }

    @IsTest
    static void longAnswerHeadlineIsClipped() {
        Account a = makeAccount();
        AccountBriefMemory.record(a.Id, 'ok', 'Q', 'x'.repeat(500) + '\nsecond line');
        System.assertEquals(200, AccountBriefMemory.history(a.Id)[0].headline.length());
    }

    @IsTest
    static void twoUsersGetSeparateRows() {
        Account a = makeAccount();
        User u2 = makeUser('usrtwo');
        insert u2;

        AccountBriefMemory.record(a.Id, 'ok', 'Admin question', 'Admin headline');
        System.runAs(u2) {
            AccountBriefMemory.record(a.Id, 'partial', 'Other question', 'Other headline');
            List<AccountBriefMemory.Turn> mine = AccountBriefMemory.history(a.Id);
            System.assertEquals(1, mine.size());
            System.assertEquals('Other headline', mine[0].headline);
        }

        List<Account_Brief_Session__c> rows = [SELECT User__c FROM Account_Brief_Session__c WITH SYSTEM_MODE];
        System.assertEquals(2, rows.size());
        List<AccountBriefMemory.Turn> adminTurns = AccountBriefMemory.history(a.Id);
        System.assertEquals(1, adminTurns.size());
        System.assertEquals('Admin headline', adminTurns[0].headline);
    }

    @IsTest
    static void unknownAccountReturnsEmpty() {
        Account a = makeAccount();
        System.assertEquals(0, AccountBriefMemory.history(a.Id).size());
        System.assertEquals(null, AccountBriefMemory.lastBrief(a.Id));
        System.assertEquals(0, AccountBriefMemory.history(null).size());
    }

    @IsTest
    static void invocablePathRecords() {
        Account a = makeAccount();
        AccountBriefMemory.Request r = new AccountBriefMemory.Request();
        r.accountId = a.Id;
        r.status = 'ok';
        r.question = 'Flow question';
        r.answer = 'Flow headline\nbody';
        AccountBriefMemory.recordFromFlow(new List<AccountBriefMemory.Request>{ r });

        List<AccountBriefMemory.Turn> turns = AccountBriefMemory.history(a.Id);
        System.assertEquals(1, turns.size());
        System.assertEquals('Flow headline', turns[0].headline);
    }

    @IsTest
    static void invocableSwallowsFailures() {
        // A request with no account (and a null request) is ignored and must never throw.
        AccountBriefMemory.Request r = new AccountBriefMemory.Request();
        r.status = 'ok';
        AccountBriefMemory.recordFromFlow(new List<AccountBriefMemory.Request>{ r, null });
        System.assertEquals(0, [SELECT COUNT() FROM Account_Brief_Session__c WITH SYSTEM_MODE]);
    }
}
