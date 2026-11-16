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
        Assert.areEqual(ExploreCatalog.entries().size() + 1, lines.size(), 'one line per described object, then the index');
        Assert.isTrue(lines[lines.size() - 1].startsWith('Other objects (fields listed after a plan names one): '), lines[lines.size() - 1]);
        Assert.isTrue(text.contains('Opportunity: Id(id), Name(string), StageName(picklist: '), text.left(400));
        Assert.isFalse(text.contains('Description('), 'long text only when the question mentions it');
        Assert.isTrue(text.contains('Owner.Name(string)'));
        Assert.isTrue(text.contains('User: Id(id), Name(string)'));
        String mentioned = ExploreCatalog.describeForPrompt('Which accounts mention renewal in their description?');
        Assert.isTrue(mentioned.contains('Description(textarea: no filter)'), 'a field the question mentions is shown');
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

    // ---- BE-42: describe-driven catalog, deny list, on-demand describe, size cap ----

    private static final List<String> BE31_QUESTIONS = new List<String>{
        'How many open opportunities are there?',
        'What is the total amount of open pipeline?',
        'Show open pipeline by stage, with the total amount for each stage.',
        'Which 5 open opportunities have the largest amounts?',
        'Which open opportunities close this month?',
        'How many contacts work at accounts in the Communications industry?',
        'Which open cases belong to accounts in the Communications industry?',
        'How many open opportunities are at prospect accounts?',
        'Which opportunity contact roles are on opportunities at accounts in the Communications industry?',
        'How many opportunity contact roles are for contacts at Customer - Direct accounts?',
        'Which accounts have no opportunities at all?',
        'Which opportunities have no contact roles?',
        'How many contacts have a role on at least one opportunity?',
        'For each account with open cases, how many open cases does it have?',
        'Which accounts have more than 3 open opportunities?',
        'How many cases are escalated or high priority?',
        'Which open opportunities are in Prospecting or have an amount over 250,000?',
        'How many accounts are in the Energy or Technology industries?',
        'Which tasks are either not started or due in the next 7 days?',
        'How many open opportunities either close this quarter with an amount over 200,000, or are in Negotiation/Review?',
        'Which accounts have an open case?',
        'Which accounts have both an open case and an open opportunity over 200,000?',
        'Which contacts work at accounts that have an open case?',
        'Which accounts have an open case and no completed task in the last 30 days?',
        'Which accounts mention renewal in their description?',
        'Which events have a description that mentions pricing?',
        'Of the 5 largest open opportunities, which close before the end of this year?',
        'What is the total open pipeline at accounts that have an open case?',
        'How many active products are there?',
        'How many customer summary sessions have been saved?'
    };

    private static Explore_Deny_Rule__mdt rule(String type, String value, String objectName) {
        return new Explore_Deny_Rule__mdt(Rule_Type__c = type, Value__c = value, Object__c = objectName);
    }

    /** The org's default deny rows plus extra ones. */
    private static void useRules(List<Explore_Deny_Rule__mdt> extra) {
        List<Explore_Deny_Rule__mdt> rows = new List<Explore_Deny_Rule__mdt>(Explore_Deny_Rule__mdt.getAll().values());
        rows.addAll(extra);
        ExploreCatalog.rulesForTest = rows;
        ExploreCatalog.reset();
    }

    @IsTest
    static void objectOutsideTheCoreEightResolvesOnDemand() {
        Assert.isNull(ExploreCatalog.find('Product2'), 'not described until asked for');
        Assert.isTrue(ExploreCatalog.isAllowed('Product2'));
        Assert.isTrue(ExploreCatalog.describeForPrompt('How many active products are there?').contains('Product2'),
            'the index names the object the question is about');

        Test.startTest();
        ExploreCatalog.Entry p = ExploreCatalog.describe('product2');
        Test.stopTest();

        Assert.areEqual('Product2', p.name);
        Assert.areEqual(p, ExploreCatalog.find('Product2'), 'described once, then found');
        Assert.areEqual(ExploreCatalog.KIND_BOOLEAN, p.field('IsActive').kind);
        Assert.isNotNull(p.field('Name'));
        List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson(
            '{"object":"Product2","fields":["Name"],"filters":[{"field":"IsActive","op":"=","value":true}]}'));
        Assert.isTrue(errs.isEmpty(), String.join(errs, ' '));
        Assert.isTrue(ExploreCatalog.describeForPrompt('How many active products are there?').contains('Product2: Id(id)'),
            'its fields are in the next catalog');
    }

    @IsTest
    static void deniedObjectsAreRefused() {
        List<String> denied = new List<String>{
            'Customer_Summary_Session__c', 'Customer_Outcome__c', 'SetupAuditTrail', 'LoginHistory', 'AuthSession',
            'PermissionSet', 'Profile', 'ApexClass', 'StaticResource', 'Organization', 'Group',
            'AccountShare', 'AccountHistory', 'AccountFeed', 'AccountChangeEvent', 'Brand_Setting__mdt'
        };
        for (String name : denied) {
            Assert.isFalse(ExploreCatalog.isAllowed(name), name);
            Assert.isNull(ExploreCatalog.describe(name), name);
            List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson('{"object":"' + name + '","fields":["Id"]}'));
            Assert.isTrue(errs[0].startsWith('Unknown object "' + name + '"'), errs[0]);
        }
        for (String name : new List<String>{ 'Widget__Share', 'Ping__e', 'Ext__x', 'Big__b', 'Faq__kav', 'Pings__chn', 'Thing__mdt' }) {
            Assert.isFalse(ExploreCatalog.nameAllowed(name), 'suffix family: ' + name);
        }
        Assert.isTrue(ExploreCatalog.nameAllowed('Lead'));
        Assert.isFalse(ExploreCatalog.isAllowed('NoSuchObjectZz'), 'an object the org does not have');
    }

    @IsTest
    static void customObjectIsDeniedUntilAnAdminAllowsIt() {
        Assert.isFalse(ExploreCatalog.nameAllowed('Widget__c'), 'a new custom object is denied by default');
        Assert.isFalse(ExploreCatalog.nameAllowed('acme__Widget__c'), 'so is a packaged one');

        useRules(new List<Explore_Deny_Rule__mdt>{
            rule(ExploreCatalog.RULE_ALLOW_OBJECT, 'Widget__c', null),
            rule(ExploreCatalog.RULE_ALLOW_OBJECT, 'Customer_Outcome__c', null),
            rule(ExploreCatalog.RULE_ALLOW_OBJECT, 'Ping__e', null)
        });

        Assert.isTrue(ExploreCatalog.nameAllowed('Widget__c'), 'an Allow Object row allows it');
        Assert.isFalse(ExploreCatalog.nameAllowed('Customer_Outcome__c'), 'a deny beats an allow');
        Assert.isFalse(ExploreCatalog.isAllowed('Customer_Outcome__c'), 'a deny beats an allow');
        Assert.isFalse(ExploreCatalog.nameAllowed('Ping__e'), 'a suffix deny beats an allow');
    }

    @IsTest
    static void fieldTypeRulesRefuseCompoundAndBinaryFields() {
        ExploreCatalog.Entry acct = ExploreCatalog.find('Account');
        Assert.isNull(acct.field('BillingAddress'), 'address compound');
        Assert.isNull(acct.field('ShippingAddress'), 'address compound');
        Assert.isNotNull(acct.field('BillingCity'), 'its parts stay');
        Assert.isNotNull(acct.field('Phone'), 'any other allowed field resolves');
        ExploreCatalog.Entry att = ExploreCatalog.describe('Attachment');
        Assert.isNull(att.field('Body'), 'base64');
        Assert.isNotNull(att.field('Name'));

        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Notes__c', 'Notes', 'ENCRYPTEDSTRING', true), 'encrypted text');
        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Notes__c', 'Notes', 'STRING', true), 'any encrypted field');
        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Body__c', 'Body', 'BASE64', false), 'base64');
        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Site__c', 'Site', 'LOCATION', false), 'location compound');
        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Mail__c', 'Mail', 'ADDRESS', false), 'address compound');
        Assert.isFalse(ExploreCatalog.fieldDenied('Account', 'Industry', 'Industry', 'PICKLIST', false));
    }

    @IsTest
    static void secretNamedFieldsAreRefused() {
        Map<String, String> secretNamed = new Map<String, String>{
            'Password__c' => 'Password', 'Api_Token__c' => 'API Token', 'Client_Secret__c' => 'Client Secret',
            'SSN__c' => 'SSN', 'Gov_Number__c' => 'Social Security Number', 'Tax_Id__c' => 'Tax ID',
            'Credit_Card__c' => 'Credit Card', 'Bank_Account__c' => 'Bank Account', 'Iban__c' => 'IBAN'
        };
        for (String name : secretNamed.keySet()) {
            Assert.isTrue(ExploreCatalog.fieldDenied('Contact', name, secretNamed.get(name), 'STRING', false), name);
        }
        Assert.isTrue(ExploreCatalog.fieldDenied('Contact', 'Code__c', 'Login password hint', 'STRING', false), 'a label match counts');
        for (String name : new List<String>{ 'ClassName__c', 'Lesson__c', 'Scorecard__c', 'Title' }) {
            Assert.isFalse(ExploreCatalog.fieldDenied('Contact', name, name, 'STRING', false), name);
        }
    }

    @IsTest
    static void userShowsOnlyItsListedFields() {
        ExploreCatalog.Entry users = ExploreCatalog.find('User');
        Assert.isNotNull(users.field('Title'));
        Assert.isNull(users.field('Email'), 'User shows only Id, Name and Title');
        Assert.isNull(ExploreCatalog.find('Opportunity').field('Owner.Email'), 'nor through a parent path');
        Assert.isNotNull(ExploreCatalog.find('Opportunity').field('Owner.Name'));
    }

    @IsTest
    static void deniedNamesAreRefusedInAParentPath() {
        useRules(new List<Explore_Deny_Rule__mdt>{
            rule(ExploreCatalog.RULE_FIELD_PATTERN, 'industry', 'Account'),
            rule(ExploreCatalog.RULE_OBJECT, 'Contract', null)
        });

        ExploreCatalog.Entry contact = ExploreCatalog.find('Contact');
        Assert.isNull(ExploreCatalog.find('Account').field('Industry'), 'a scoped field pattern');
        Assert.isNull(contact.field('Account.Industry'), 'the denied field through a parent path');
        Assert.isNotNull(contact.field('Account.Name'), 'the rest of the parent stays');

        useRules(new List<Explore_Deny_Rule__mdt>{ rule(ExploreCatalog.RULE_OBJECT, 'Account', null) });
        Assert.isNull(ExploreCatalog.find('Account'), 'a denied core object is gone');
        Assert.isNull(ExploreCatalog.find('Contact').field('Account.Name'), 'a denied object through a parent path');
        List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson('{"object":"Contact","fields":["Name","Account.Name"]}'));
        Assert.isTrue(String.join(errs, ' ').contains('Unknown field "Account.Name"'), String.join(errs, ' '));
    }

    @IsTest
    static void deniedNamesAreRefusedInASemiJoinPosition() {
        // The plan grammar has no sub-select: a nested plan or SOQL text never becomes a query.
        List<String> plans = new List<String>{
            '{"object":"Account","fields":["Name"],"filters":[{"field":"Id","op":"IN","value":{"object":"LoginHistory","fields":["UserId"]}}]}',
            '{"object":"Account","fields":["Name"],"filters":[{"field":"BillingAddress","op":"IN","value":["x"]}]}',
            '{"object":"Account","fields":["Name"],"sub":{"object":"SetupAuditTrail","fields":["Id"]}}'
        };
        for (String plan : plans) {
            List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson(plan));
            Assert.isFalse(errs.isEmpty(), plan);
        }
        ExplorePlan.Resolved r = ExplorePlan.resolve(ExplorePlan.fromJson(
            '{"object":"Account","fields":["Name"],"filters":[{"field":"Name","op":"IN","value":["SELECT Id FROM LoginHistory"]}]}'));
        Assert.isTrue(r.errors.isEmpty(), String.join(r.errors, ' '));
        Assert.areEqual('Name', r.filters[0].field.path, 'the text is a bound value, never an object');
    }

    @IsTest
    static void emptyDenyListRefusesEverything() {
        ExploreCatalog.rulesForTest = new List<Explore_Deny_Rule__mdt>();
        ExploreCatalog.reset();

        Assert.isTrue(ExploreCatalog.entries().isEmpty());
        Assert.isNull(ExploreCatalog.find('Account'));
        Assert.isFalse(ExploreCatalog.isAllowed('Account'));
        Assert.isNull(ExploreCatalog.describe('Lead'));
        Assert.areEqual('', ExploreCatalog.describeForPrompt('How many accounts?'));
        Assert.isTrue(ExploreCatalog.fieldDenied('Account', 'Name', 'Name', 'STRING', false));
        List<String> errs = ExplorePlan.validate(ExplorePlan.fromJson('{"object":"Account","fields":["Name"]}'));
        Assert.isTrue(errs[0].startsWith('Unknown object "Account"'), errs[0]);
    }

    @IsTest
    static void unreadableDenyListRefusesEverything() {
        ExploreCatalog.failReadForTest = true;
        ExploreCatalog.reset();
        Assert.isTrue(ExploreCatalog.entries().isEmpty());
        Assert.isFalse(ExploreCatalog.isAllowed('Lead'));

        ExploreCatalog.failReadForTest = false;
        useRules(new List<Explore_Deny_Rule__mdt>{ rule(ExploreCatalog.RULE_FIELD_PATTERN, '(unclosed', null) });
        Assert.isTrue(ExploreCatalog.entries().isEmpty(), 'a pattern that does not compile refuses too');
        Assert.isFalse(ExploreCatalog.isAllowed('Account'));
    }

    @IsTest
    static void perCallCatalogStaysUnderTheCapOnTheBe31Questions() {
        List<Integer> sizes = new List<Integer>();
        Test.startTest();
        for (String q : BE31_QUESTIONS) {
            sizes.add(ExploreCatalog.describeForPrompt(q).length());
        }
        // A later turn, with objects described on demand, stays under the cap too.
        ExploreCatalog.describe('Product2');
        ExploreCatalog.describe('Lead');
        ExploreCatalog.describe('Campaign');
        for (String q : BE31_QUESTIONS) {
            sizes.add(ExploreCatalog.describeForPrompt(q).length());
        }
        Test.stopTest();

        List<Integer> sorted = new List<Integer>(sizes);
        sorted.sort();
        System.debug(LoggingLevel.INFO, 'BE42 catalog chars: median=' + sorted[sorted.size() / 2] + ' max=' + sorted[sorted.size() - 1]);
        for (Integer i = 0; i < sizes.size(); i++) {
            Assert.isTrue(sizes[i] <= ExploreCatalog.MAX_PROMPT_CHARS, 'call ' + i + ': ' + sizes[i]);
            Assert.isTrue(sizes[i] > 0, 'call ' + i);
        }
    }

    @IsTest
    static void aNamedPicklistValuePastTheFirstTwelveIsShown() {
        List<String> active = new List<String>();
        for (Schema.PicklistEntry p : Schema.SObjectType.Account.fields.getMap().get('Industry').getDescribe().getPicklistValues()) {
            if (p.isActive()) {
                active.add(p.getValue());
            }
        }
        Assert.isTrue(active.size() > 12, 'Account.Industry has more than 12 active values: ' + active.size());
        String last = active[active.size() - 1];
        String text = ExploreCatalog.describeForPrompt('Industry ' + last);
        String account = '';
        for (String line : text.split('\n')) {
            if (line.startsWith('Account: ')) {
                account = line;
            }
        }
        String shown = account.substringAfter('Industry(picklist: ').substringBefore(')');
        Assert.isTrue(new Set<String>(shown.split('\\|')).contains(last), 'the named value is shown: ' + last + ' in ' + shown);
    }
}
