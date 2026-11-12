@IsTest
private class AccountBriefResolverTest {
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve('something unrelated', a.Id);
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve(a.Name, 'not-an-id');
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve('the Austin one: ' + id18 + ' please', null);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(id18, r.accountId);

        AccountBriefResolver.Response r15 = AccountBriefResolver.resolve(id18.substring(0, 15), null);
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve(String.join(parts, ' '), null);
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

        AccountBriefResolver.Response r = AccountBriefResolver.resolve(text, null);

        Assert.areEqual('RESOLVED', r.status, r.message);
        Assert.areEqual(String.valueOf(b.Id), r.accountId, 'the first visible Id in the text wins');
    }

    @IsTest
    static void exactNameBeatsPartialMatches() {
        String t = token();
        insert new List<Account>{ mk(t + ' Clinic', 'A'), mk(t + ' Clinic East', 'B'), mk(t + ' Clinic West', 'C') };
        AccountBriefResolver.Response r = AccountBriefResolver.resolve('  ' + t.toLowerCase() + ' CLINIC ', null);
        Assert.areEqual('RESOLVED', r.status);
        Assert.areEqual(t + ' Clinic', r.accountName);
    }

    @IsTest
    static void singlePartialMatchResolves() {
        String t = token();
        insert mk(t + ' Pediatrics Group', 'Boston');
        AccountBriefResolver.Response r = AccountBriefResolver.resolve(t + ' Pedia', null);
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve(t + ' Practice', null);
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
        AccountBriefResolver.Response r = AccountBriefResolver.resolve(term, null);
        Assert.areEqual('NOT_FOUND', r.status);
        Assert.areEqual('No account matches "' + term + '". Try the full name or open the account and ask again.', r.message);
    }

    @IsTest
    static void blankInputIsNotFound() {
        String expected = 'Which account? Give me its name or open the account record.';
        for (String blank : new List<String>{ null, '', '   ' }) {
            AccountBriefResolver.Response r = AccountBriefResolver.resolve(blank, null);
            Assert.areEqual('NOT_FOUND', r.status);
            Assert.areEqual(expected, r.message);
        }
    }

    @IsTest
    static void likeWildcardsInTermAreLiteral() {
        insert mk(token() + ' Plain', null);
        AccountBriefResolver.Response r = AccountBriefResolver.resolve('%', null);
        Assert.areEqual('NOT_FOUND', r.status);
    }

    @IsTest
    static void invocableMethodDelegates() {
        Account a = mk(token() + ' Flow', null);
        insert a;
        AccountBriefResolver.Request rq = new AccountBriefResolver.Request();
        rq.knownAccountId = a.Id;
        List<AccountBriefResolver.Response> out = AccountBriefResolver.resolveAccounts(new List<AccountBriefResolver.Request>{ rq });
        Assert.areEqual(1, out.size());
        Assert.areEqual('RESOLVED', out[0].status);
        Assert.areEqual(0, AccountBriefResolver.resolveAccounts(null).size());
    }

    @IsTest
    static void clipAndFmtDate() {
        Assert.areEqual('n/a', AccountBriefSection.clip(null, 10));
        Assert.areEqual('n/a', AccountBriefSection.clip('  \n\t ', 10));
        Assert.areEqual('a b c', AccountBriefSection.clip('  a \n b\t\tc  ', 50));
        String cut = AccountBriefSection.clip('abcdefghij', 5);
        Assert.areEqual(5, cut.length());
        Assert.isTrue(cut.endsWith('…'));
        Assert.areEqual('abcd…', cut);
        Assert.areEqual('abcde', AccountBriefSection.clip('abcde', 5));
        Assert.areEqual('2026-03-07', AccountBriefSection.fmtDate(Date.newInstance(2026, 3, 7)));
        Assert.areEqual('n/a', AccountBriefSection.fmtDate(null));
        AccountBriefSection s = new AccountBriefSection();
        Assert.areEqual('', s.body);
        Assert.areEqual('OK', AccountBriefSection.OK);
        Assert.areEqual('EMPTY', AccountBriefSection.EMPTY);
        Assert.areEqual('ERROR', AccountBriefSection.ERROR);
    }
}
