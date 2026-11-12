@IsTest
private class ExploreCatalogTest {
    private static User minimalUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'exp' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'expmin',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Explore Minimal',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.exploretest'
        );
        insert u;
        return u;
    }

    @IsTest
    static void curatedObjectsAndFieldsAreDescribed() {
        ExploreCatalog.Entry opp = ExploreCatalog.find(' opportunity ');
        Assert.areEqual('Opportunity', opp.name);
        Assert.areEqual('StageName', opp.field('STAGENAME').path);
        Assert.areEqual(ExploreCatalog.KIND_NUMBER, opp.field('Amount').kind);
        Assert.areEqual(ExploreCatalog.KIND_DATE, opp.field('CloseDate').kind);
        Assert.areEqual(ExploreCatalog.KIND_BOOLEAN, opp.field('IsWon').kind);
        Assert.areEqual(ExploreCatalog.KIND_ID, opp.field('AccountId').kind);
        Assert.areEqual(new List<String>{ 'Account' }, opp.field('AccountId').referenceTo);
        Assert.isFalse(opp.field('Description').filterable, 'long text is not filterable');
        Assert.isTrue(opp.field('Name').filterable);
        Assert.isFalse(opp.field('StageName').picklistValues.isEmpty());

        ExploreCatalog.Field ownerName = opp.field('owner.name');
        Assert.areEqual('Owner.Name', ownerName.path);
        Assert.isTrue(ownerName.filterable);
        Assert.areEqual('Account.Name', ExploreCatalog.find('Contact').field('Account.Name').path);
        Assert.areEqual('Who.Name', ExploreCatalog.find('Task').field('Who.Name').path, 'polymorphic parent kept');
        Assert.isNotNull(ExploreCatalog.find('Case').field('Owner.Name'), 'polymorphic owner kept');
        Assert.areEqual(ExploreCatalog.KIND_DATETIME, ExploreCatalog.find('Event').field('StartDateTime').kind);
        Assert.areEqual(ExploreCatalog.KIND_INTEGER, ExploreCatalog.find('Account').field('NumberOfEmployees').kind);

        ExploreCatalog.Entry users = ExploreCatalog.find('User');
        for (ExploreCatalog.Field f : users.fields) {
            Assert.isTrue(new Set<String>{ 'Id', 'Name', 'Title' }.contains(f.path), 'User is limited: ' + f.path);
        }
        Assert.isNull(ExploreCatalog.find('Lead'));
        Assert.isNull(ExploreCatalog.find(null));
        Assert.isNull(opp.field(null));
        Assert.isTrue(ExploreCatalog.entries().size() >= 6);
    }

    @IsTest
    static void missingObjectsAndFieldsAreDropped() {
        ExploreCatalog.CURATED.put('NoSuchObjectZz__c', new List<String>{ 'Id' });
        ExploreCatalog.CURATED.get('Account').addAll(new List<String>{
            'NoSuchFieldZz__c', 'Owner.NoSuchFieldZz', 'NoSuchRelZz.Name', 'Owner.Manager.Name', 'Name'
        });

        ExploreCatalog.Entry acct = ExploreCatalog.find('Account');

        Assert.isNull(ExploreCatalog.find('NoSuchObjectZz__c'));
        Assert.isNull(acct.field('NoSuchFieldZz__c'));
        Assert.isNull(acct.field('Owner.NoSuchFieldZz'));
        Assert.isNull(acct.field('NoSuchRelZz.Name'));
        Assert.isNull(acct.field('Owner.Manager.Name'), 'only one parent level');
        Integer names = 0;
        for (ExploreCatalog.Field f : acct.fields) {
            names += f.path == 'Name' ? 1 : 0;
        }
        Assert.areEqual(1, names, 'a repeated path is listed once');
    }

    @IsTest
    static void describeForPromptIsCompact() {
        String text = ExploreCatalog.describeForPrompt();
        List<String> lines = text.split('\n');
        Assert.areEqual(ExploreCatalog.entries().size(), lines.size());
        Assert.isTrue(text.contains('Opportunity: Id(id), Name(string), StageName(picklist: '), text.left(400));
        Assert.isTrue(text.contains('Description(textarea: no filter)'));
        Assert.isTrue(text.contains('Owner.Name(string)'));
        Assert.isTrue(text.contains('User: Id(id), Name(string)'));
    }

    @IsTest
    static void userWithoutAccessHasObjectsDropped() {
        User u = minimalUser();
        Assert.isNotNull(ExploreCatalog.find('Opportunity'), 'the admin sees Opportunity');
        System.runAs(u) {
            Assert.isNull(ExploreCatalog.find('Opportunity'));
            Assert.isNull(ExploreCatalog.find('Account'));
            Assert.isFalse(ExploreCatalog.describeForPrompt().contains('Opportunity:'));
            List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson('{"object":"Opportunity","fields":["Name"]}'));
            Assert.isTrue(errs[0].startsWith('Unknown object "Opportunity"'), errs[0]);
        }
    }

    @IsTest
    static void parentLabelsAreDotFree() {
        Assert.areEqual('Account', ExploreCatalog.parentLabel('Account ID', 'Account', 'Account Name', 'Name'));
        Assert.areEqual('Owner', ExploreCatalog.parentLabel('Owner ID', 'Owner', 'Full Name', 'Name'));
        Assert.areEqual('Account Industry', ExploreCatalog.parentLabel('Account ID', 'Account', 'Industry', 'Industry'));
        Assert.areEqual('Acme Co', ExploreCatalog.parentLabel('Acme.Co ID', 'Acme__r', 'Name', 'Name'));
        Assert.areEqual('Rel', ExploreCatalog.plainLabel('  ', 'Rel'));
        Assert.areEqual('a b', ExploreCatalog.plainLabel('a.b', 'x'));
        for (ExploreCatalog.Entry e : ExploreCatalog.entries()) {
            for (ExploreCatalog.Field f : e.fields) {
                Assert.isFalse(String.isBlank(f.label), e.name + '.' + f.path);
                Assert.isFalse(f.label.contains('.'), e.name + '.' + f.path + ' -> ' + f.label);
            }
        }
    }
}
