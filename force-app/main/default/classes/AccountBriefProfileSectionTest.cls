@IsTest
private class AccountBriefProfileSectionTest {
    private static String token() {
        return 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static String ownerName() {
        return [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;
    }

    @IsTest
    static void fullProfileFormatsEveryLine() {
        String t = token();
        Account parent = new Account(Name = t + ' Parent');
        insert parent;
        Account a = new Account(
            Name = t + ' Practice',
            Type = 'Customer',
            Industry = 'Healthcare',
            ParentId = parent.Id,
            AnnualRevenue = 1234567.89,
            NumberOfEmployees = 250,
            BillingCity = 'Austin',
            BillingState = 'Texas',
            BillingCountry = 'United States',
            Website = 'https://example.com',
            Description = 'Line one\n\n  line   two'
        );
        insert a;
        Date since = [SELECT CreatedDate FROM Account WHERE Id = :a.Id].CreatedDate.date();

        AccountBriefSection s = AccountBriefProfileSection.build(a.Id);
        Assert.areEqual('profile', s.key);
        Assert.areEqual('Account', s.title);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(1, s.total);
        Assert.areEqual(1, s.shown);
        Assert.isTrue(s.body.length() <= 1200);

        List<String> lines = s.body.split('\n');
        Assert.areEqual(11, lines.size());
        Assert.areEqual('Name: ' + t + ' Practice', lines[0]);
        Assert.areEqual('Type: Customer', lines[1]);
        Assert.areEqual('Industry: Healthcare', lines[2]);
        Assert.areEqual('Owner: ' + ownerName(), lines[3]);
        Assert.areEqual('Parent: ' + t + ' Parent', lines[4]);
        Assert.areEqual('Annual revenue: $1,234,568', lines[5]);
        Assert.areEqual('Employees: 250', lines[6]);
        Assert.areEqual('Location: Austin, Texas, United States', lines[7]);
        Assert.areEqual('Website: https://example.com', lines[8]);
        Assert.areEqual('Account since: ' + AccountBriefSection.fmtDate(since), lines[9]);
        Assert.areEqual('Description: Line one line two', lines[10]);
    }

    @IsTest
    static void missingValuesShowNotAvailableAndLongDescriptionIsClipped() {
        String t = token();
        Account a = new Account(Name = t + ' Bare', BillingCity = 'Austin', BillingCountry = 'United States');
        insert a;

        List<String> lines = AccountBriefProfileSection.build(a.Id).body.split('\n');
        Assert.areEqual(11, lines.size());
        Assert.areEqual('Type: n/a', lines[1]);
        Assert.areEqual('Industry: n/a', lines[2]);
        Assert.areEqual('Parent: n/a', lines[4]);
        Assert.areEqual('Annual revenue: n/a', lines[5]);
        Assert.areEqual('Employees: n/a', lines[6]);
        Assert.areEqual('Location: Austin, United States', lines[7]);
        Assert.areEqual('Website: n/a', lines[8]);
        Assert.areEqual('Description: n/a', lines[10]);

        Account blankLoc = new Account(Name = t + ' NoLoc');
        insert blankLoc;
        Assert.areEqual('Location: n/a', AccountBriefProfileSection.build(blankLoc.Id).body.split('\n')[7]);

        Account longDesc = new Account(Name = t + ' Long', Description = 'x'.repeat(500));
        insert longDesc;
        AccountBriefSection s = AccountBriefProfileSection.build(longDesc.Id);
        String descLine = s.body.split('\n')[10];
        Assert.areEqual('Description: '.length() + 300, descLine.length());
        Assert.isTrue(descLine.endsWith('…'));
        Assert.isTrue(s.body.length() <= 1200);
    }

    @IsTest
    static void unknownOrNullIdIsEmpty() {
        Account a = new Account(Name = token() + ' Gone');
        insert a;
        Id gone = a.Id;
        delete a;

        for (Id id : new List<Id>{ gone, null }) {
            AccountBriefSection s = AccountBriefProfileSection.build(id);
            Assert.areEqual('profile', s.key);
            Assert.areEqual(AccountBriefSection.EMPTY, s.status);
            Assert.areEqual('Account not found or not visible to you.', s.body);
            Assert.areEqual(0, s.total);
            Assert.areEqual(0, s.shown);
        }
    }
}
