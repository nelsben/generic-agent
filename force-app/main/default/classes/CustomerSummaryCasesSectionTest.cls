@IsTest
private class CustomerSummaryCasesSectionTest {
    private static String token() {
        return 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Account mkAccount() {
        Account a = new Account(Name = token() + ' Practice');
        insert a;
        return a;
    }

    private static Case mkCase(Account a, String subject, String priority, Integer ageDays) {
        Case c = new Case(AccountId = a.Id, Subject = subject, Priority = priority, Status = 'New');
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-ageDays));
        return c;
    }

    private static String line(Case c, String priority, Integer ageDays) {
        String num = [SELECT CaseNumber FROM Case WHERE Id = :c.Id].CaseNumber;
        return '- ' + num + ' — ' + c.Subject + ' — ' + priority + ' — New — open ' + ageDays + ' days';
    }

    @IsTest
    static void overCapShowsFiveOrderedByPriorityThenAge() {
        Account a = mkAccount();
        String t = token();
        // Inserted out of order so the ordering rule, not insert order, decides the rows.
        Case low30 = mkCase(a, t + ' low30', 'Low', 30);
        Case med5 = mkCase(a, t + ' med5', 'Medium', 5);
        Case high10 = mkCase(a, t + ' high10', 'High', 10);
        Case low2 = mkCase(a, t + ' low2', 'Low', 2);
        Case med25 = mkCase(a, t + ' med25', 'Medium', 25);
        Case high20 = mkCase(a, t + ' high20', 'High', 20);
        Case low1 = mkCase(a, t + ' low1', 'Low', 1);
        insert new Case(AccountId = a.Id, Subject = t + ' done', Priority = 'High', Status = 'Closed');

        CustomerSummarySection s = new CustomerSummaryCasesSection().build(a.Id);
        Assert.areEqual('cases', s.key);
        Assert.areEqual('Service health', s.title);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        Assert.areEqual(7, s.total);
        Assert.areEqual(5, s.shown);
        Assert.isTrue(s.total > CustomerSummaryCasesSection.ROW_CAP);
        Assert.isTrue(CustomerSummarySection.withoutIds(s.body).length() <= 1200);

        List<String> lines = CustomerSummarySection.withoutIds(s.body).split('\n');
        Assert.areEqual(7, lines.size());
        Assert.areEqual('7 open (2 high priority), 1 closed in last 90 days, oldest open 30 days', lines[0]);
        Assert.areEqual(line(high20, 'High', 20), lines[1]);
        Assert.areEqual(line(high10, 'High', 10), lines[2]);
        Assert.areEqual(line(med25, 'Medium', 25), lines[3]);
        Assert.areEqual(line(med5, 'Medium', 5), lines[4]);
        Assert.areEqual(line(low30, 'Low', 30), lines[5]);
        Assert.isFalse(s.body.contains(t + ' low2'));
        Assert.isFalse(s.body.contains(t + ' low1'));
        Assert.isFalse(s.body.contains(t + ' done'));
        Assert.areEqual('- …and 2 more not shown', lines[6]);
    }

    @IsTest
    static void subjectIsClippedToOneHundredCharacters() {
        Account a = mkAccount();
        Case c = mkCase(a, 'y'.repeat(150), 'High', 3);
        List<String> lines = CustomerSummarySection.withoutIds(new CustomerSummaryCasesSection().build(a.Id).body).split('\n');
        Assert.areEqual(2, lines.size());
        Assert.areEqual('1 open (1 high priority), 0 closed in last 90 days, oldest open 3 days', lines[0]);
        String num = [SELECT CaseNumber FROM Case WHERE Id = :c.Id].CaseNumber;
        Assert.areEqual('- ' + num + ' — ' + 'y'.repeat(99) + '… — High — New — open 3 days', lines[1]);
    }

    @IsTest
    static void onlyClosedCasesSaysNoOpenCases() {
        Account a = mkAccount();
        insert new List<Case>{
            new Case(AccountId = a.Id, Subject = token() + ' one', Status = 'Closed'),
            new Case(AccountId = a.Id, Subject = token() + ' two', Status = 'Closed')
        };

        CustomerSummarySection s = new CustomerSummaryCasesSection().build(a.Id);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
        Assert.areEqual(
            '0 open (0 high priority), 2 closed in last 90 days, oldest open n/a\nNo open cases.',
            s.body
        );
    }

    @IsTest
    static void noCasesIsEmpty() {
        CustomerSummarySection s = new CustomerSummaryCasesSection().build(mkAccount().Id);
        Assert.areEqual('cases', s.key);
        Assert.areEqual(CustomerSummarySection.EMPTY, s.status);
        Assert.areEqual('No cases on this account.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);

        CustomerSummarySection nullId = new CustomerSummaryCasesSection().build(null);
        Assert.areEqual(CustomerSummarySection.EMPTY, nullId.status);
        Assert.areEqual(0, nullId.total);
    }
}
