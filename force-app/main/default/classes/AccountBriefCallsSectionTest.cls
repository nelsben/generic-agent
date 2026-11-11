@IsTest
private class AccountBriefCallsSectionTest {
    private static Account mkAccount() {
        Account a = new Account(Name = 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + ' Calls');
        insert a;
        return a;
    }

    private static Event mkEvent(Id accountId, String subject, Integer daysFromNow, Integer minutes, String notes) {
        return new Event(
            WhatId = accountId,
            Subject = subject,
            StartDateTime = DateTime.now().addDays(daysFromNow),
            DurationInMinutes = minutes,
            Description = notes
        );
    }

    private static String dateOf(Integer daysFromNow) {
        return AccountBriefSection.fmtDate(DateTime.now().addDays(daysFromNow).date());
    }

    @IsTest
    static void capsAtFivePastWithNotesAndNextLine() {
        Account a = mkAccount();
        Account other = mkAccount();
        Contact pat = new Contact(AccountId = a.Id, FirstName = 'Pat', LastName = 'Lee');
        insert pat;
        String longNotes = 'N'.repeat(500);
        Event withWho = mkEvent(a.Id, 'Renewal call', -1, 45, 'Agreed   to\n\nrenew.');
        withWho.WhoId = pat.Id;
        // Inserted oldest first so the ordering is not insert order.
        insert new List<Event>{
            mkEvent(a.Id, 'Seven days ago', -7, 30, 'Should not show'),
            mkEvent(a.Id, 'Six days ago', -6, 30, null),
            mkEvent(a.Id, 'Five days ago', -5, 15, longNotes),
            mkEvent(a.Id, 'Four days ago', -4, 60, null),
            mkEvent(a.Id, 'Three days ago', -3, 20, 'Short note'),
            mkEvent(a.Id, 'Two days ago', -2, 25, null),
            withWho,
            mkEvent(a.Id, 'Later kickoff', 10, 30, 'Future notes are not shown'),
            mkEvent(a.Id, 'Soonest kickoff', 3, 30, null),
            mkEvent(other.Id, 'Other account', -1, 30, null)
        };

        AccountBriefSection s = new AccountBriefCallsSection().build(a.Id);
        Assert.areEqual('calls', s.key);
        Assert.areEqual('Calls & meetings', s.title);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(7, s.total);
        Assert.areEqual(5, s.shown);
        Assert.areEqual(
            '- ' + dateOf(-1) + ' — Renewal call — 45 min — with Pat Lee\n'
                + ' notes: Agreed to renew.\n'
                + '- ' + dateOf(-2) + ' — Two days ago — 25 min — with n/a\n'
                + '- ' + dateOf(-3) + ' — Three days ago — 20 min — with n/a\n'
                + ' notes: Short note\n'
                + '- ' + dateOf(-4) + ' — Four days ago — 60 min — with n/a\n'
                + '- ' + dateOf(-5) + ' — Five days ago — 15 min — with n/a\n'
                + ' notes: ' + AccountBriefSection.clip(longNotes, 300) + '\n'
                + 'Next: ' + dateOf(3) + ' — Soonest kickoff',
            s.body
        );
        Assert.isTrue(s.body.length() <= 1200);
    }

    @IsTest
    static void longNotesDropWholeBlocksToStayUnderBodyCap() {
        Account a = mkAccount();
        List<Event> events = new List<Event>();
        for (Integer i = 1; i <= 6; i++) {
            events.add(mkEvent(a.Id, 'Call ' + i, -i, 30, 'W'.repeat(600)));
        }
        events.add(mkEvent(a.Id, 'Upcoming', 2, 30, null));
        insert events;

        AccountBriefSection s = new AccountBriefCallsSection().build(a.Id);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(6, s.total);
        Assert.isTrue(s.shown >= 1 && s.shown < 5, 'blocks dropped, not cut: ' + s.shown);
        Assert.isTrue(s.body.length() <= 1200, 'body length ' + s.body.length());
        List<String> lines = s.body.split('\n');
        Assert.areEqual('Next: ' + dateOf(2) + ' — Upcoming', lines[lines.size() - 1]);
        Integer bullets = 0;
        for (String line : lines) {
            if (line.startsWith('- ')) {
                bullets++;
            }
        }
        Assert.areEqual(s.shown, bullets);
        // The newest events are the ones kept.
        Assert.isTrue(lines[0].contains('Call 1'));
    }

    @IsTest
    static void noEventsIsEmpty() {
        Account a = mkAccount();
        AccountBriefSection s = new AccountBriefCallsSection().build(a.Id);
        Assert.areEqual(AccountBriefSection.EMPTY, s.status);
        Assert.areEqual('No calls or meetings logged.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }

    @IsTest
    static void onlyFutureEventStillReportsNext() {
        Account a = mkAccount();
        insert mkEvent(a.Id, 'First meeting', 4, 30, null);
        AccountBriefSection s = new AccountBriefCallsSection().build(a.Id);
        Assert.areEqual(AccountBriefSection.OK, s.status);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
        Assert.areEqual('No past calls or meetings logged.\nNext: ' + dateOf(4) + ' — First meeting', s.body);
    }

    @IsTest
    static void missingDurationAndSubjectRenderAsNotAvailable() {
        Account a = mkAccount();
        insert new Event(WhatId = a.Id, Subject = null, StartDateTime = DateTime.now().addDays(-2), IsAllDayEvent = false, DurationInMinutes = 30);
        AccountBriefSection s = new AccountBriefCallsSection().build(a.Id);
        Assert.areEqual('- ' + dateOf(-2) + ' — n/a — 30 min — with n/a', s.body);
    }

    @IsTest
    static void failureReturnsErrorSectionInsteadOfThrowing() {
        AccountBriefSection s = new AccountBriefCallsSection().build(null);
        Assert.areEqual(AccountBriefSection.ERROR, s.status);
        Assert.areEqual('Couldn\'t load Calls & meetings right now.', s.body);
        Assert.areEqual('calls', s.key);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }
}
