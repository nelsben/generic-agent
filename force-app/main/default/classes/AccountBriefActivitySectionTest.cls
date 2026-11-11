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
        List<String> lines = s.body.split('\n');
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
        Assert.isTrue(s.body.length() <= 1200);
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
            s.body
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
