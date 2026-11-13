@IsTest
private class CustomerSummaryResolverTest {
    private static String token() {
        return 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Account mk(String name, String city) {
        return new Account(Name = name, BillingCity = city);
    }

    @IsTest
    static void knownIdResolvesWithoutNameSearch() {
        Account a = mk(token() + ' Known', 'Hartford');
        insert a;
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve('something unrelated', a.Id);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(String.valueOf(a.Id), r.accountId);
        Assert.areEqual(18, r.accountId.length());
        Assert.areEqual(a.Name, r.accountName);
        Assert.areEqual('Resolved: ' + a.Name, r.message);
    }

    @IsTest
    static void invalidKnownIdFallsBackToName() {
        Account a = mk(token() + ' Fallback', null);
        insert a;
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(a.Name, 'not-an-id');
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(String.valueOf(a.Id), r.accountId);
    }

    @IsTest
    static void idPastedInsideTextWins() {
        String t = token();
        Account a = mk(t + ' Same', 'Boston');
        Account b = mk(t + ' Same', 'Austin');
        insert new List<Account>{ a, b };
        String id18 = String.valueOf(b.Id);
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve('the Austin one: ' + id18 + ' please', null);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(id18, r.accountId);

        CustomerSummaryResolver.Response r15 = CustomerSummaryResolver.resolve(id18.substring(0, 15), null);
        Assert.areEqual('RESOLVED', r15.status);
        Assert.areEqual(id18, r15.accountId);
    }

    @IsTest
    static void manyPastedIdsUseOneQuery() {
        Account target = mk(token() + ' Bulk Target', 'Denver');
        insert target;
        // 150 well-formed Account Ids that match no record, then the visible one. The old per-Id loop
        // would need 151 queries and hit the 100-query limit.
        List<String> parts = new List<String>();
        for (Integer i = 1; i <= 150; i++) {
            parts.add('001' + String.valueOf(i).leftPad(12, '0'));
        }
        parts.add(String.valueOf(target.Id));

        Test.startTest();
        Integer before = Limits.getQueries();
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(String.join(parts, ' '), null);
        Integer used = Limits.getQueries() - before;
        Test.stopTest();

        Assert.areEqual('RESOLVED', r.status, r.message);
        Assert.areEqual(String.valueOf(target.Id), r.accountId);
        Assert.areEqual(1, used, 'all pasted Ids are looked up in one query');
    }

    @IsTest
    static void firstVisiblePastedIdInTextOrderWins() {
        String t = token();
        Account a = mk(t + ' Alpha', null);
        Account b = mk(t + ' Beta', null);
        insert new List<Account>{ a, b };
        String text = '0010000000000Zz or ' + String.valueOf(b.Id) + ' or ' + String.valueOf(a.Id);

        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(text, null);

        Assert.areEqual('RESOLVED', r.status, r.message);
        Assert.areEqual(String.valueOf(b.Id), r.accountId, 'the first visible Id in the text wins');
    }

    @IsTest
    static void exactNameBeatsPartialMatches() {
        String t = token();
        insert new List<Account>{ mk(t + ' Clinic', 'A'), mk(t + ' Clinic East', 'B'), mk(t + ' Clinic West', 'C') };
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve('  ' + t.toLowerCase() + ' CLINIC ', null);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(t + ' Clinic', r.accountName);
    }

    @IsTest
    static void singlePartialMatchResolves() {
        String t = token();
        insert mk(t + ' Pediatrics Group', 'Boston');
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(t + ' Pedia', null);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(t + ' Pediatrics Group', r.accountName);
    }

    @IsTest
    static void tenMatchesAreAmbiguousWithEightLinesAndMore() {
        String t = token();
        List<Account> accts = new List<Account>();
        for (Integer i = 10; i < 20; i++) {
            accts.add(mk(t + ' Practice ' + i, i == 10 ? null : 'City' + i));
        }
        insert accts;
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(t + ' Practice', null);
        Assert.areEqual('AMBIGUOUS', r.status);
        Assert.isNull(r.accountId);
        List<String> lines = r.message.split('\n');
        Assert.areEqual('Several accounts match "' + t + ' Practice". Which one?', lines[0]);
        Integer candidates = 0;
        for (String line : lines) {
            if (line.contains(' — ')) {
                candidates++;
            }
        }
        Assert.areEqual(8, candidates);
        Assert.areEqual(10, lines.size());
        Assert.areEqual('…and 2 more', lines[9]);
        Assert.areEqual(t + ' Practice 10 — no city — ' + String.valueOf(accts[0].Id), lines[1]);
        Assert.isTrue(lines[2].startsWith(t + ' Practice 11 — City11 — '));
    }

    @IsTest
    static void unknownNameIsNotFound() {
        String term = token() + ' Nothing Here';
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(term, null);
        Assert.areEqual('NOT_FOUND', r.status);
        Assert.areEqual('No account matches "' + term + '". Try a fuller or different account name.', r.message);
    }

    @IsTest
    static void blankInputIsNotFound() {
        String expected = 'Which account? Give me the account\'s name.';
        for (String blank : new List<String>{ null, '', '   ' }) {
            CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(blank, null);
            Assert.areEqual('NOT_FOUND', r.status);
            Assert.areEqual(expected, r.message);
        }
    }

    @IsTest
    static void likeWildcardsInTermAreLiteral() {
        insert mk(token() + ' Plain', null);
        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve('%', null);
        Assert.areEqual('NOT_FOUND', r.status);
    }

    @IsTest
    static void invocableMethodDelegates() {
        Account a = mk(token() + ' Flow', null);
        insert a;
        CustomerSummaryResolver.Request rq = new CustomerSummaryResolver.Request();
        rq.knownAccountId = a.Id;
        List<CustomerSummaryResolver.Response> out = CustomerSummaryResolver.resolveAccounts(new List<CustomerSummaryResolver.Request>{ rq });
        Assert.areEqual(1, out.size());
        Assert.areEqual('RESOLVED', out[0].status);
        Assert.areEqual(0, CustomerSummaryResolver.resolveAccounts(null).size());
    }

    @IsTest
    static void clipAndFmtDate() {
        Assert.areEqual('n/a', CustomerSummarySection.clip(null, 10));
        Assert.areEqual('n/a', CustomerSummarySection.clip('  \n\t ', 10));
        Assert.areEqual('a b c', CustomerSummarySection.clip('  a \n b\t\tc  ', 50));
        String cut = CustomerSummarySection.clip('abcdefghij', 5);
        Assert.areEqual(5, cut.length());
        Assert.isTrue(cut.endsWith('…'));
        Assert.areEqual('abcd…', cut);
        Assert.areEqual('abcde', CustomerSummarySection.clip('abcde', 5));
        Assert.areEqual('2026-03-07', CustomerSummarySection.fmtDate(Date.newInstance(2026, 3, 7)));
        Assert.areEqual('n/a', CustomerSummarySection.fmtDate(null));
        CustomerSummarySection s = new CustomerSummarySection();
        Assert.areEqual('', s.body);
        Assert.areEqual('OK', CustomerSummarySection.OK);
        Assert.areEqual('EMPTY', CustomerSummarySection.EMPTY);
        Assert.areEqual('ERROR', CustomerSummarySection.ERROR);
    }

    /** A Minimum Access user: no read access to Account, so every resolver query throws. */
    private static User minimalUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'res' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'resmin',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Resolver Minimal',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.resolvertest'
        );
        insert u;
        return u;
    }

    @IsTest
    static void aQueryErrorIsAnErrorWithFixedTextNotNotFound() {
        String name = token() + ' Access';
        insert mk(name, null);
        User u = minimalUser();

        System.runAs(u) {
            for (String typed : new List<String>{ name, 'Anything else' }) {
                CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(typed, null);
                Assert.areEqual('ERROR', r.status, r.message);
                Assert.areEqual('I couldn\'t search accounts. You may not have access to them: ask your Salesforce admin to check your access.', r.message);
                Assert.isNull(r.accountId);
                Assert.isNull(r.accountName);
            }
        }
    }

    // ---------------------------------------------------------------- cards (BE-46)

    private static List<AnswerCard> cardsOf(CustomerSummaryResolver.Response r) {
        return AnswerCard.fromJson(r.cards);
    }

    /** The card with its refs emptied, as JSON: whatever is left must hold no record Id. */
    private static void assertNoIdOutsideRefs(AnswerCard c, List<String> ids) {
        AnswerCard copy = AnswerCard.fromJson(AnswerCard.toJson(new List<AnswerCard>{ c }))[0];
        copy.refs = new List<AnswerCard.Ref>();
        String json = JSON.serialize(copy);
        for (String id : ids) {
            Assert.isFalse(json.contains(id), 'the card holds an Id outside refs: ' + json);
            Assert.isFalse(json.contains(id.substring(0, 15)), 'the card holds a 15-character Id outside refs: ' + json);
        }
    }

    @IsTest
    static void ambiguousGivesOneChoiceCardInTheMessagesOrderWithIdsOnlyInRefs() {
        String t = token();
        List<Account> accts = new List<Account>();
        for (Integer i = 10; i < 20; i++) {
            accts.add(mk(t + ' Practice ' + i, i == 10 ? null : 'City' + i));
        }
        insert accts;

        CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(t + ' Practice', null);

        Assert.areEqual('AMBIGUOUS', r.status);
        List<AnswerCard> cards = cardsOf(r);
        Assert.areEqual(1, cards.size());
        AnswerCard c = cards[0];
        Assert.areEqual('choice', c.type);
        Assert.areEqual('AMBIGUOUS', c.status);
        List<String> lines = r.message.split('\n');
        Assert.areEqual(lines[0], c.title, 'the question is the title');
        Assert.areEqual(8, c.items.size());
        Assert.areEqual(8, c.refs.size());
        for (Integer i = 0; i < c.items.size(); i++) {
            List<String> parts = lines[i + 1].split(' — ');
            Assert.areEqual(parts[0], c.items[i].label, 'item ' + i + ' is the message\'s candidate ' + i);
            Assert.areEqual(parts[1], c.items[i].detail);
            AnswerCard.Ref ref = null;
            for (AnswerCard.Ref candidate : c.refs) {
                if (candidate.key == c.items[i].ref) {
                    ref = candidate;
                }
            }
            Assert.isNotNull(ref, 'item ' + i + ' points at a ref');
            Assert.areEqual(parts[2], ref.recordId, 'the ref holds the Id the message shows');
            Assert.areEqual('Account', ref.objectName);
            Assert.areEqual(parts[0], ref.label);
            Assert.isFalse(c.text.contains(parts[2]), 'text never holds an Id');
        }
        Assert.areEqual(t + ' Practice 10', c.items[0].label);
        Assert.areEqual('no city', c.items[0].detail);
        Assert.areEqual('City11', c.items[1].detail);
        List<String> ids = new List<String>();
        for (Account a : accts) {
            ids.add(String.valueOf(a.Id));
        }
        assertNoIdOutsideRefs(c, ids);
    }

    @IsTest
    static void everyExistingOutputIsUnchangedBesideTheCards() {
        String t = token();
        Account a = mk(t + ' Twin', 'Austin');
        Account b = mk(t + ' Twin', 'Boston');
        insert new List<Account>{ a, b };

        CustomerSummaryResolver.Response amb = CustomerSummaryResolver.resolve(t + ' Twin', null);
        Assert.areEqual('AMBIGUOUS', amb.status);
        Assert.isNull(amb.accountId);
        Assert.isNull(amb.accountName);
        Assert.areEqual('Several accounts match "' + t + ' Twin". Which one?\n'
            + t + ' Twin — Austin — ' + String.valueOf(a.Id) + '\n'
            + t + ' Twin — Boston — ' + String.valueOf(b.Id), amb.message, 'the message keeps its Ids');

        CustomerSummaryResolver.Response res = CustomerSummaryResolver.resolve(null, a.Id);
        Assert.areEqual('RESOLVED', res.status);
        Assert.areEqual(String.valueOf(a.Id), res.accountId);
        Assert.areEqual(t + ' Twin', res.accountName);
        Assert.areEqual('Resolved: ' + t + ' Twin', res.message);
    }

    @IsTest
    static void notFoundGivesOneNoticeCard() {
        String term = token() + ' Nothing Here';
        for (CustomerSummaryResolver.Response r : new List<CustomerSummaryResolver.Response>{
            CustomerSummaryResolver.resolve(term, null),
            CustomerSummaryResolver.resolve('  ', null)
        }) {
            Assert.areEqual('NOT_FOUND', r.status);
            List<AnswerCard> cards = cardsOf(r);
            Assert.areEqual(1, cards.size());
            Assert.areEqual('notice', cards[0].type);
            Assert.areEqual('NOT_FOUND', cards[0].status);
            Assert.areEqual(r.message, cards[0].text);
            Assert.isTrue(cards[0].refs.isEmpty());
        }
    }

    @IsTest
    static void resolvedAndErrorGiveNoCard() {
        Account a = mk(token() + ' Plain', null);
        insert a;
        CustomerSummaryResolver.Response res = CustomerSummaryResolver.resolve(null, a.Id);
        Assert.areEqual('RESOLVED', res.status);
        Assert.isTrue(cardsOf(res).isEmpty());
        Assert.areEqual('[]', res.cards);

        User u = minimalUser();
        System.runAs(u) {
            CustomerSummaryResolver.Response err = CustomerSummaryResolver.resolve('Anything', null);
            Assert.areEqual('ERROR', err.status);
            Assert.isTrue(cardsOf(err).isEmpty());
        }
    }

    @IsTest
    static void theInvocablesCardsJsonParsesBackToTheSameCards() {
        String t = token();
        insert new List<Account>{ mk(t + ' Pair', 'Austin'), mk(t + ' Pair', null) };
        List<CustomerSummaryResolver.Request> reqs = new List<CustomerSummaryResolver.Request>();
        for (String name : new List<String>{ t + ' Pair', t + ' Missing' }) {
            CustomerSummaryResolver.Request rq = new CustomerSummaryResolver.Request();
            rq.accountName = name;
            reqs.add(rq);
        }
        List<CustomerSummaryResolver.Response> out = CustomerSummaryResolver.resolveAccounts(reqs);
        Assert.areEqual('AMBIGUOUS', out[0].status);
        Assert.areEqual('NOT_FOUND', out[1].status);
        for (CustomerSummaryResolver.Response r : out) {
            List<AnswerCard> cards = cardsOf(r);
            Assert.areEqual(1, cards.size());
            Assert.areEqual(r.cards, AnswerCard.toJson(cards), 'the JSON round-trips to the same cards');
        }
        Assert.areEqual('choice', cardsOf(out[0])[0].type);
        Assert.areEqual('notice', cardsOf(out[1])[0].type);
    }

    /** A user who can read every Account but has no field access to BillingCity. */
    private static User userWithoutCityAccess() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'rescard' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rescard',
            Email = uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Resolver Cards',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniq + '@example.com.resolvertest'
        );
        insert u;
        PermissionSet ps = new PermissionSet(Name = 'Res_Cards_' + uniq.right(8), Label = 'Resolver cards');
        insert ps;
        insert new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Account', PermissionsRead = true, PermissionsViewAllRecords = true);
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    @IsTest
    static void aCardHoldsNoFieldTheRunningUserCannotRead() {
        User u = userWithoutCityAccess();
        String t = token();
        insert new List<Account>{ mk(t + ' Hidden', 'Zzcityhidden'), mk(t + ' Hidden', 'Yycityhidden') };
        System.runAs(u) {
            CustomerSummaryResolver.Response r = CustomerSummaryResolver.resolve(t + ' Hidden', null);
            Assert.areEqual('AMBIGUOUS', r.status, r.message);
            List<AnswerCard> cards = cardsOf(r);
            Assert.areEqual(1, cards.size());
            Assert.areEqual(2, cards[0].items.size());
            for (AnswerCard.Item i : cards[0].items) {
                Assert.areEqual('no city', i.detail, 'a city the user cannot read is not on the card');
            }
            Assert.isFalse(r.cards.contains('cityhidden'));
            Assert.isFalse(cards[0].text.contains('cityhidden'));
        }
    }
}
