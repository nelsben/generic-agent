@IsTest
private class CustomerSummaryContactsSectionTest {
    private static Account mkAccount() {
        Account a = new Account(Name = 'Zqx' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + ' Contacts');
        insert a;
        return a;
    }

    private static Contact mkContact(Id accountId, String last, String title) {
        return new Contact(AccountId = accountId, FirstName = 'Pat', LastName = last, Title = title);
    }

    private static Task mkTask(Id who, String subtype, Integer daysAgo) {
        return new Task(
            WhoId = who,
            Subject = subtype + ' ' + daysAgo,
            TaskSubtype = subtype,
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-daysAgo)
        );
    }

    private static Event mkEvent(Id who, Integer daysAgo) {
        return new Event(
            WhoId = who,
            Subject = 'Meeting ' + daysAgo,
            StartDateTime = DateTime.now().addDays(-daysAgo),
            DurationInMinutes = 30
        );
    }

    /** Re-reads the Contact so LastActivityDate is whatever the platform computed. */
    private static Contact reread(Id contactId) {
        return [SELECT Id, Name, Title, LastActivityDate FROM Contact WHERE Id = :contactId];
    }

    private static String expectedLine(Contact c, String title, Integer e, Integer calls, Integer m, Boolean quiet) {
        return '- ' + c.Name + ' — ' + title + ' — 90d: ' + e + ' emails, ' + calls + ' calls, ' + m + ' meetings'
            + ' — last touch ' + (c.LastActivityDate == null ? 'none' : CustomerSummarySection.fmtDate(c.LastActivityDate))
            + (quiet ? ' (quiet)' : '');
    }

    @IsTest
    static void capsAtSixOrderedByTouchCount() {
        Account a = mkAccount();
        List<Contact> contacts = new List<Contact>();
        for (Integer k = 1; k <= 8; k++) {
            contacts.add(mkContact(a.Id, 'Contact' + k, 'Title ' + k));
        }
        insert contacts;
        // Contact k gets k email touches; inserted lowest first so ordering is not insert order.
        List<Task> tasks = new List<Task>();
        for (Integer k = 1; k <= 8; k++) {
            for (Integer j = 0; j < k; j++) {
                tasks.add(mkTask(contacts[k - 1].Id, 'Email', 1 + j));
            }
        }
        insert tasks;

        CustomerSummarySection s = new CustomerSummaryContactsSection().build(a.Id);
        Assert.areEqual('contacts', s.key);
        Assert.areEqual('Contacts', s.title);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        Assert.areEqual(8, s.total);
        Assert.areEqual(6, s.shown);
        List<String> lines = CustomerSummarySection.withoutIds(s.body).split('\n');
        Assert.areEqual(6, lines.size());
        for (Integer i = 0; i < 6; i++) {
            Integer k = 8 - i;
            Assert.areEqual(expectedLine(reread(contacts[k - 1].Id), 'Title ' + k, k, 0, 0, false), lines[i]);
        }
        Assert.isFalse(s.body.contains('Contact1'));
        Assert.isFalse(s.body.contains('Contact2'));
        Assert.isTrue(CustomerSummarySection.withoutIds(s.body).length() <= 1200);
    }

    @IsTest
    static void countsEmailsCallsAndMeetingsWithinNinetyDays() {
        Account a = mkAccount();
        Contact busy = mkContact(a.Id, 'Busy', null);
        insert busy;
        insert new List<Task>{
            mkTask(busy.Id, 'Email', 3),
            mkTask(busy.Id, 'Email', 90),
            mkTask(busy.Id, 'Call', 5),
            mkTask(busy.Id, 'Task', 7),
            mkTask(busy.Id, 'Email', 91)
        };
        insert new List<Event>{ mkEvent(busy.Id, 10), mkEvent(busy.Id, 120) };

        CustomerSummarySection s = new CustomerSummaryContactsSection().build(a.Id);
        Assert.areEqual(CustomerSummarySection.OK, s.status);
        Assert.areEqual(1, s.total);
        Assert.areEqual(1, s.shown);
        // 91-day Email and 120-day Event fall outside the window; the 'Task' touch counts toward
        // ordering but has no column of its own.
        Assert.areEqual(expectedLine(reread(busy.Id), 'no title', 2, 1, 1, false), CustomerSummarySection.withoutIds(s.body));
    }

    @IsTest
    static void tieOnTouchesBreaksByMostRecentLastActivityThenQuietLast() {
        Account a = mkAccount();
        Contact recent = mkContact(a.Id, 'Recent', 'Dir');
        Contact older = mkContact(a.Id, 'Older', 'Dir');
        Contact oldOnly = mkContact(a.Id, 'OldOnly', 'Dir');
        Contact never = mkContact(a.Id, 'Never', 'Dir');
        insert new List<Contact>{ never, oldOnly, older, recent };
        insert new List<Task>{
            mkTask(older.Id, 'Call', 20),
            mkTask(recent.Id, 'Call', 2),
            mkTask(oldOnly.Id, 'Email', 200)
        };

        Contact rRecent = reread(recent.Id);
        Contact rOlder = reread(older.Id);
        Contact rOldOnly = reread(oldOnly.Id);
        Contact rNever = reread(never.Id);
        Assert.isNotNull(rRecent.LastActivityDate, 'platform should have computed LastActivityDate');
        Assert.isNotNull(rOldOnly.LastActivityDate);
        Assert.isNull(rNever.LastActivityDate);

        CustomerSummarySection s = new CustomerSummaryContactsSection().build(a.Id);
        Assert.areEqual(4, s.total);
        Assert.areEqual(4, s.shown);
        List<String> lines = CustomerSummarySection.withoutIds(s.body).split('\n');
        Assert.areEqual(expectedLine(rRecent, 'Dir', 0, 1, 0, false), lines[0]);
        Assert.areEqual(expectedLine(rOlder, 'Dir', 0, 1, 0, false), lines[1]);
        // Quiet contacts follow, the one with a past touch before the one with none.
        Assert.areEqual(expectedLine(rOldOnly, 'Dir', 0, 0, 0, true), lines[2]);
        Assert.areEqual(expectedLine(rNever, 'Dir', 0, 0, 0, true), lines[3]);
        Assert.isTrue(lines[3].endsWith('last touch none (quiet)'));
    }

    @IsTest
    static void accountWithoutContactsIsEmpty() {
        Account a = mkAccount();
        CustomerSummarySection s = new CustomerSummaryContactsSection().build(a.Id);
        Assert.areEqual(CustomerSummarySection.EMPTY, s.status);
        Assert.areEqual('No contacts on this account.', s.body);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }

    @IsTest
    static void otherAccountsContactsAreIgnored() {
        Account a = mkAccount();
        Account b = mkAccount();
        insert mkContact(b.Id, 'Elsewhere', 'Dir');
        CustomerSummarySection s = new CustomerSummaryContactsSection().build(a.Id);
        Assert.areEqual(CustomerSummarySection.EMPTY, s.status);
    }

    @IsTest
    static void failureReturnsErrorSectionInsteadOfThrowing() {
        CustomerSummarySection s = new CustomerSummaryContactsSection().build(null);
        Assert.areEqual(CustomerSummarySection.ERROR, s.status);
        Assert.areEqual('Couldn\'t load Contacts right now.', s.body);
        Assert.areEqual('contacts', s.key);
        Assert.areEqual(0, s.total);
        Assert.areEqual(0, s.shown);
    }
}
