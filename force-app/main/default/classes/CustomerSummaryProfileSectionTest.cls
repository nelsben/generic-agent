@IsTest
private class CustomerSummaryProfileSectionTest {
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

        CustomerSummarySection s = new CustomerSummaryProfileSection().build(a.Id);
        Assert.areEqual('profile', s.key);
        Assert.areEqual('Account', s.title);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
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
        Assert.areEqual('Account since: ' + CustomerSummarySection.fmtDate(since), lines[9]);
        Assert.areEqual('Description: Line one line two', lines[10]);
    }

    @IsTest
    static void missingValuesShowNotAvailableAndLongDescriptionIsClipped() {
        String t = token();
        Account a = new Account(Name = t + ' Bare', BillingCity = 'Austin', BillingCountry = 'United States');
        insert a;

        List<String> lines = new CustomerSummaryProfileSection().build(a.Id).body.split('\n');
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
        Assert.areEqual('Location: n/a', new CustomerSummaryProfileSection().build(blankLoc.Id).body.split('\n')[7]);

        Account longDesc = new Account(Name = t + ' Long', Description = 'x'.repeat(500));
        insert longDesc;
        CustomerSummarySection s = new CustomerSummaryProfileSection().build(longDesc.Id);
        String descLine = s.body.split('\n')[10];
        Assert.areEqual('Description: '.length() + 300, descLine.length());
        Assert.isTrue(descLine.endsWith('…'));
        Assert.isTrue(s.body.length() <= 1200);
    }

    /**
     * A Minimum Access user with a permission set made in the test: read on every Account record and on
     * Industry, and no other optional Account field (Type, Parent, Annual revenue, Description and the rest).
     */
    private static User userWhoReadsOnlyIndustry() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            String uniq = 'prf' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            u = new User(
                Alias = 'prfmin',
                Email = uniq + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Profile Minimal',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York',
                Username = uniq + '@example.com.profiletest'
            );
            insert u;
            PermissionSet ps = new PermissionSet(Name = 'Prf_' + uniq.right(20), Label = 'Profile section test ' + uniq.right(10));
            insert ps;
            insert new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true, PermissionsViewAllRecords = true);
            insert new FieldPermissions(ParentId = ps.Id, SobjectType = 'Account', Field = 'Account.Industry', PermissionsRead = true);
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    @IsTest
    static void anUnreadableFieldIsLeftOutAndNamedInsteadOfFailingTheSection() {
        String t = token();
        Account a = new Account(Name = t + ' Partial', Type = 'Customer', Industry = 'Healthcare',
            AnnualRevenue = 5000000, Description = 'Secret plans');
        insert a;
        User u = userWhoReadsOnlyIndustry();

        CustomerSummarySection s;
        System.runAs(u) {
            s = new CustomerSummaryProfileSection().build(a.Id);
        }

        Assert.areEqual(CustomerSummarySection.OK, s.status, 'cause: ' + s.cause + ' body: ' + s.body);
        List<String> lines = s.body.split('\n');
        Assert.areEqual('Name: ' + t + ' Partial', lines[0]);
        Assert.isTrue(s.body.contains('\nIndustry: Healthcare'), s.body);
        for (String hidden : new List<String>{ 'Type:', 'Parent:', 'Annual revenue:', 'Description:', 'Website:', '5,000,000', 'Secret plans' }) {
            Assert.isFalse(s.body.contains(hidden), 'an unreadable field reached the body: ' + hidden + ' in ' + s.body);
        }
        String last = lines[lines.size() - 1];
        Assert.isTrue(last.startsWith('Left out because you can\'t see these fields: '), last);
        for (String label : new List<String>{ 'Type', 'Parent', 'Annual revenue', 'Description' }) {
            Assert.isTrue(last.contains(label), 'the left-out line does not name ' + label + ': ' + last);
        }
        Assert.isFalse(last.contains('Industry'), last);
    }

    @IsTest
    static void unknownOrNullIdIsEmpty() {
        Account a = new Account(Name = token() + ' Gone');
        insert a;
        Id gone = a.Id;
        delete a;

        for (Id id : new List<Id>{ gone, null }) {
            CustomerSummarySection s = new CustomerSummaryProfileSection().build(id);
            Assert.areEqual('profile', s.key);
            Assert.areEqual(CustomerSummarySection.EMPTY, s.status);
            Assert.areEqual('Account not found or not visible to you.', s.body);
            Assert.areEqual(0, s.total);
            Assert.areEqual(0, s.shown);
        }
    }
}
