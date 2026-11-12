@IsTest
private class AccountBriefActivitySectionTest {
    private static Account mkAccount() {
        Account a = new Account(Name = 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + ' Activity');
        insert a;
        return a;
    }

    private static Task mkTask(Id accountId, Id who, String subtype, String subject, Integer daysAgo, Boolean open) {
        return new Task(
            WhatId = accountId,
            WhoId = who,
            Subject = subject,
            TaskSubtype = subtype,
            Status = open ? 'Not Started' : 'Completed',
            ActivityDate = Date.today().addDays(-daysAgo)
        );
    }

    private static String bullet(Integer daysAgo, String kind, String subject, String who) {
        return '- ' + AccountBriefSection.fmtDate(Date.today().addDays(-daysAgo)) + ' — ' + kind + ' — ' + subject + ' — ' + who;
    }

    @IsTest
    static void capsAtFiveWithCountsAndOverdueLine() {
        Account a = mkAccount();
        Account other = mkAccount();
        Contact pat = new Contact(AccountId = a.Id, FirstName = 'Pat', LastName = 'Lee');
        insert pat;
        String longSubject = 'Q'.repeat(200);
        // Inserted oldest first so the ordering is not insert order.
        insert new List<Task>{
            mkTask(a.Id, null, 'Task', 'Old follow-up', 8, true), // open and overdue
            mkTask(a.Id, null, 'Call', 'Call seven', 7, false),
            mkTask(a.Id, null, 'Email', 'Email six', 6, false),
            mkTask(a.Id, null, 'Task', 'Prep five', 5, true), // open and overdue
            mkTask(a.Id, null, 'Call', 'Call four', 4, false),
            mkTask(a.Id, null, 'Email', 'Email three', 3, false),
            mkTask(a.Id, null, 'Email', 'Email two', 2, false),
            mkTask(a.Id, pat.Id, 'Email', longSubject, 1, false),
            mkTask(a.Id, null, 'Task', 'Due today', 0, true), // open, not overdue
            mkTask(a.Id, null, 'Email', 'Outside window', 91, false),
            mkTask(a.Id, null, 'Email', 'Outside window overdue', 120, true),
            mkTask(other.Id, null, 'Email', 'Other account', 1, false)
        };

        AccountBriefSection s = new AccountBriefActivitySection().build(a.Id);
        Assert.areEqual('activity', s.key);
        Assert.areEqual('Recent activity', s.title);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(9, s.total);
        Assert.areEqual(5, s.shown);
        List<String> lines = AccountBriefSection.withoutIds(s.body).split('\n');
        Assert.areEqual(6, lines.size());
        Assert.areEqual('90d: 4 emails, 2 calls, 3 other; 2 open tasks overdue', lines[0]);
        Assert.areEqual(bullet(0, 'Task', 'Due today', 'n/a'), lines[1]);
        Assert.areEqual(bullet(1, 'Email', AccountBriefSection.clip(longSubject, 120), 'Pat Lee'), lines[2]);
        Assert.areEqual(bullet(2, 'Email', 'Email two', 'n/a'), lines[3]);
        Assert.areEqual(bullet(3, 'Email', 'Email three', 'n/a'), lines[4]);
        Assert.areEqual(bullet(4, 'Call', 'Call four', 'n/a'), lines[5]);
        Assert.isTrue(lines[2].contains('…'));
        Assert.isFalse(s.body.contains('Outside window'));
        Assert.isFalse(s.body.contains('Other account'));
        Assert.isTrue(AccountBriefSection.withoutIds(s.body).length() <= 1200);
    }

    @IsTest
    static void newestFirstRegardlessOfInsertOrder() {
        Account a = mkAccount();
        insert new List<Task>{
            mkTask(a.Id, null, 'Call', 'Middle', 10, false),
            mkTask(a.Id, null, 'Email', 'Newest', 1, false),
            mkTask(a.Id, null, 'Email', 'Oldest', 30, false)
        };
        AccountBriefSection s = new AccountBriefActivitySection().build(a.Id);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(3, s.total);
        Assert.areEqual(3, s.shown);
        Assert.areEqual(
            '90d: 2 emails, 1 calls, 0 other; 0 open tasks overdue\n'
                + bullet(1, 'Email', 'Newest', 'n/a') + '\n'
                + bullet(10, 'Call', 'Middle', 'n/a') + '\n'
                + bullet(30, 'Email', 'Oldest', 'n/a'),
            AccountBriefSection.withoutIds(s.body)
        );
    }

    @IsTest
    static void onlyOldTasksIsEmpty() {
        Account a = mkAccount();
        insert mkTask(a.Id, null, 'Email', 'Ancient', 100, false);
        AccountBriefSection s = new AccountBriefActivitySection().build(a.Id);
        Assert.areEqual(AccountBriefSection.EMPTY, s.status);
        Assert.areEqual('No tasks in the last 90 days.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }

    /** Answers every model call with a fixed text and records the prompts; never reaches a model. */
    private class Stub implements AgentLlm.Provider {
        List<String> prompts = new List<String>();
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            prompts.add(userPrompt);
            return 'Brief text.';
        }
    }

    private static User newUser(String profileName, String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = alias + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return new User(
            Alias = alias,
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Activity ' + alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.activitytest'
        );
    }

    /**
     * A Minimum Access user who can read Accounts and Task.ActivityDate but has no read access to
     * Task.WhoId. Setup DML runs as the test user so it does not mix with the record DML.
     */
    private static User restrictedUser() {
        User u = newUser('Minimum Access - Salesforce', 'actmin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PermissionSet ps = new PermissionSet(Name = 'Zqx_Activity_Restricted', Label = 'Zqx Activity Restricted');
            insert ps;
            insert new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true);
            insert new FieldPermissions(ParentId = ps.Id, SobjectType = 'Task', Field = 'Task.ActivityDate', PermissionsRead = true);
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    @IsTest
    static void taskTheUserCannotReadIsNotInTheBrief() {
        User u = restrictedUser();
        Account a = new Account(Name = 'Zqx Restricted Activity', OwnerId = u.Id);
        insert a;
        insert mkTask(a.Id, null, 'Call', 'Hidden renewal call', 1, false);
        Stub stub = new Stub();
        AgentLlm.stub = stub;

        AccountBriefSection s;
        AccountBrief.Result r;
        Test.startTest();
        System.runAs(u) {
            s = new AccountBriefActivitySection().build(a.Id);
            r = AccountBrief.run(a.Id, null, new Set<String>{ 'activity' });
        }
        Test.stopTest();

        String seen = s.status + ': ' + s.body;
        Assert.isFalse(s.body.contains('Hidden renewal call'), 'the section read Task fields the user lacks: ' + seen);
        Assert.areEqual(AccountBriefSection.ERROR, s.status, seen);
        Assert.areEqual(1, r.sections.size());
        Assert.isFalse(r.sections[0].body.contains('Hidden renewal call'), r.sections[0].body);
        for (String prompt : stub.prompts) {
            Assert.isFalse(prompt.contains('Hidden renewal call'), 'the Task reached the model');
        }
        Assert.isFalse(r.answer.contains('Hidden renewal call'), r.answer);
    }

    @IsTest
    static void standardUserReadsTasksInUserMode() {
        User u = newUser('Standard User', 'actstd');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        Account a = new Account(Name = 'Zqx Standard Activity', OwnerId = u.Id);
        insert a;
        insert mkTask(a.Id, null, 'Call', 'Visible renewal call', 1, false);

        AccountBriefSection s;
        System.runAs(u) {
            s = new AccountBriefActivitySection().build(a.Id);
        }

        Assert.areEqual(AccountBriefSection.OK, s.status, s.body);
        Assert.areEqual(1, s.total);
        Assert.areEqual(
            '90d: 0 emails, 1 calls, 0 other; 0 open tasks overdue\n' + bullet(1, 'Call', 'Visible renewal call', 'n/a'),
            AccountBriefSection.withoutIds(s.body)
        );
    }

    @IsTest
    static void failureReturnsErrorSectionInsteadOfThrowing() {
        AccountBriefSection s = new AccountBriefActivitySection().build(null);
        Assert.areEqual(AccountBriefSection.ERROR, s.status);
        Assert.areEqual('Couldn\'t load Recent activity right now.', s.body);
        Assert.areEqual('activity', s.key);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }
}
