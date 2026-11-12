@IsTest
private class AccountBriefSectionErrorTest {
    private static User minimalUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'sec' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'secmin',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Section Minimal',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.sectiontest'
        );
        insert u;
        return u;
    }

    @IsTest
    static void everySectionFailsClosedAndKeepsTheCauseForAUserWithoutAccess() {
        Account a = new Account(Name = 'Section Error Account');
        insert a;
        User u = minimalUser();
        List<String> failures = new List<String>();

        System.runAs(u) {
            for (AccountBrief.Source reg : AccountBrief.registry) {
                AccountBriefSource src = (AccountBriefSource) Type.forName(reg.className).newInstance();
                AccountBriefSection s = src.build(a.Id);
                if (s.status != AccountBriefSection.ERROR) {
                    failures.add(reg.key + ' gave ' + s.status + ' instead of ERROR');
                } else if (String.isBlank(s.cause) || !s.cause.contains('Exception')) {
                    failures.add(reg.key + ' lost its cause: ' + s.cause);
                } else if (s.body.contains('QueryException')) {
                    failures.add(reg.key + ' leaked the cause into the user-facing body');
                }
            }
        }

        Assert.areEqual(new List<String>(), failures);
    }

    @IsTest
    static void aNullAccountIdGivesAnErrorWithItsCause() {
        AccountBriefSection s = new AccountBriefActivitySection().build(null);
        Assert.areEqual(AccountBriefSection.ERROR, s.status);
        Assert.isTrue(s.cause.startsWith('System.IllegalArgumentException'), s.cause);
        Assert.isTrue(s.cause.contains('accountId is required'), s.cause);
        Assert.areEqual('Couldn\'t load Recent activity right now.', s.body);
    }
}
