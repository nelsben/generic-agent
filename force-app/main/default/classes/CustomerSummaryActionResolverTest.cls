/**
 * CustomerSummaryActionResolverTest: plain words to dates, times, lengths, contacts and open deals (BE-27).
 * Dates count from Friday 2026-11-13.
 */
@IsTest
private class CustomerSummaryActionResolverTest {
    private static final Date FRIDAY = Date.newInstance(2026, 11, 13);

    @TestSetup
    static void data() {
        Account a = new Account(Name = 'Resolver Acme');
        Account other = new Account(Name = 'Resolver Other');
        insert new List<Account>{ a, other };
        insert new List<Contact>{
            new Contact(AccountId = a.Id, FirstName = 'Maria', LastName = 'Lopez'),
            new Contact(AccountId = a.Id, FirstName = 'Jordan', LastName = 'Lee'),
            new Contact(AccountId = a.Id, FirstName = 'Jordan', LastName = 'Park'),
            new Contact(AccountId = other.Id, FirstName = 'Sam', LastName = 'Stone')
        };
        insert new List<Opportunity>{
            new Opportunity(AccountId = a.Id, Name = 'Core Router Refresh', StageName = 'Prospecting', CloseDate = FRIDAY.addDays(30)),
            new Opportunity(AccountId = a.Id, Name = 'Router Spares', StageName = 'Prospecting', CloseDate = FRIDAY.addDays(60)),
            new Opportunity(AccountId = a.Id, Name = 'Old Router Deal', StageName = 'Closed Won', CloseDate = FRIDAY.addDays(-30))
        };
    }

    private static Id acme() {
        return [SELECT Id FROM Account WHERE Name = 'Resolver Acme' LIMIT 1].Id;
    }

    private static void assertDay(String words, Date expected) {
        Assert.areEqual(expected, CustomerSummaryActionResolver.toDate(words, FRIDAY), 'words: ' + words);
    }

    @IsTest
    static void fixedAndRelativeDayWords() {
        assertDay('today', FRIDAY);
        assertDay('tomorrow', Date.newInstance(2026, 11, 14));
        assertDay('Yesterday', Date.newInstance(2026, 11, 12));
        assertDay('in 3 days', Date.newInstance(2026, 11, 16));
        assertDay('in two weeks', Date.newInstance(2026, 11, 27));
        assertDay('in a month', Date.newInstance(2026, 12, 13));
        assertDay('next week', Date.newInstance(2026, 11, 16));
        assertDay('next month', Date.newInstance(2026, 12, 1));
        assertDay('2026-12-01', Date.newInstance(2026, 12, 1));
        assertDay('by tomorrow', Date.newInstance(2026, 11, 14));
    }

    @IsTest
    static void weekdaysCountForwardAndThisMayBeToday() {
        assertDay('Tuesday', Date.newInstance(2026, 11, 17));
        assertDay('next Tuesday', Date.newInstance(2026, 11, 17));
        assertDay('on Thursday', Date.newInstance(2026, 11, 19));
        assertDay('Friday', Date.newInstance(2026, 11, 20));
        assertDay('this Friday', FRIDAY);
        assertDay('next mon', Date.newInstance(2026, 11, 16));
    }

    @IsTest
    static void endsOfWeeksMonthsAndQuarters() {
        assertDay('end of the week', FRIDAY);
        assertDay('end of the month', Date.newInstance(2026, 11, 30));
        assertDay('end of next month', Date.newInstance(2026, 12, 31));
        assertDay('end of the quarter', Date.newInstance(2026, 12, 31));
    }

    @IsTest
    static void monthNamesTakeTheNextSuchDay() {
        assertDay('Nov 17', Date.newInstance(2026, 11, 17));
        assertDay('November 2', Date.newInstance(2027, 11, 2));
        assertDay('17th of December', Date.newInstance(2026, 12, 17));
        assertDay('March 3, 2027', Date.newInstance(2027, 3, 3));
    }

    @IsTest
    static void wordsThatAreNotADayAreNull() {
        assertDay('next blursday', null);
        assertDay('2026-02-30', null);
        assertDay('February 30', null);
        assertDay('soon', null);
        assertDay('', null);
    }

    @IsTest
    static void timesNeedATimeAndReadAfternoonForSmallHours() {
        Assert.areEqual(Datetime.newInstance(2026, 11, 14, 14, 0, 0), CustomerSummaryActionResolver.toDatetime('tomorrow at 2pm', FRIDAY));
        Assert.areEqual(Datetime.newInstance(2026, 11, 17, 10, 30, 0), CustomerSummaryActionResolver.toDatetime('next Tuesday 10:30am', FRIDAY));
        Assert.areEqual(Datetime.newInstance(2026, 11, 13, 15, 0, 0), CustomerSummaryActionResolver.toDatetime('at 3', FRIDAY), '1 to 7 with no am or pm is afternoon');
        Assert.areEqual(Datetime.newInstance(2026, 11, 13, 12, 0, 0), CustomerSummaryActionResolver.toDatetime('at noon', FRIDAY));
        Assert.areEqual(Datetime.newInstance(2026, 11, 14, 0, 0, 0), CustomerSummaryActionResolver.toDatetime('tomorrow at 12am', FRIDAY));
        Assert.areEqual(Datetime.newInstance(2026, 11, 17, 9, 15, 0), CustomerSummaryActionResolver.toDatetime('2026-11-17T09:15', FRIDAY));
        Assert.areEqual(Datetime.newInstance(2026, 11, 17, 16, 0, 0), CustomerSummaryActionResolver.toDatetime('Nov 17 at 4pm', FRIDAY));
        Assert.isNull(CustomerSummaryActionResolver.toDatetime('tomorrow', FRIDAY), 'a day with no time is not a moment');
        Assert.isNull(CustomerSummaryActionResolver.toDatetime('next blursday at 2pm', FRIDAY));
        Assert.isNull(CustomerSummaryActionResolver.toDatetime('at 25:00', FRIDAY));
    }

    @IsTest
    static void lengthsInMinutesOrHours() {
        Assert.areEqual(45, CustomerSummaryActionResolver.toMinutes('45 minutes'));
        Assert.areEqual(30, CustomerSummaryActionResolver.toMinutes('30'));
        Assert.areEqual(60, CustomerSummaryActionResolver.toMinutes('1 hour'));
        Assert.areEqual(60, CustomerSummaryActionResolver.toMinutes('an hour'));
        Assert.areEqual(30, CustomerSummaryActionResolver.toMinutes('half an hour'));
        Assert.areEqual(120, CustomerSummaryActionResolver.toMinutes('2 hrs'));
        Assert.isNull(CustomerSummaryActionResolver.toMinutes('a while'));
        Assert.isNull(CustomerSummaryActionResolver.toMinutes('0'));
    }

    @IsTest
    static void contactsMatchFirstLastOrFullNameOnThisAccountOnly() {
        Id a = acme();
        Assert.areEqual(1, CustomerSummaryActionResolver.contacts(a, 'Maria').size());
        Assert.areEqual(1, CustomerSummaryActionResolver.contacts(a, 'maria lopez').size());
        Assert.areEqual(1, CustomerSummaryActionResolver.contacts(a, 'Maria\'s').size());
        Assert.areEqual(2, CustomerSummaryActionResolver.contacts(a, 'Jordan').size(), 'two matches stay two: a choice, not a guess');
        Assert.areEqual(0, CustomerSummaryActionResolver.contacts(a, 'Sam').size(), 'a contact on another account never matches');
        Assert.areEqual(0, CustomerSummaryActionResolver.contacts(a, 'Mar').size(), 'part of a name is not a match');
        Contact sam = [SELECT Id FROM Contact WHERE LastName = 'Stone' LIMIT 1];
        Assert.isNull(CustomerSummaryActionResolver.contactOnAccount(a, sam.Id));
        Assert.isNull(CustomerSummaryActionResolver.contactOnAccount(a, a), 'an Id of another object is not a contact');
    }

    @IsTest
    static void dealsMatchOpenOpportunitiesByNameAndExactWins() {
        Id a = acme();
        Assert.areEqual(2, CustomerSummaryActionResolver.openOpportunities(a, 'router').size(), 'a closed deal is never a match');
        List<Opportunity> exact = CustomerSummaryActionResolver.openOpportunities(a, 'the Router Spares deal');
        Assert.areEqual(1, exact.size());
        Assert.areEqual('Router Spares', exact[0].Name);
        Assert.areEqual(1, CustomerSummaryActionResolver.openOpportunities(a, 'core router').size());
        Opportunity closed = [SELECT Id FROM Opportunity WHERE Name = 'Old Router Deal' LIMIT 1];
        Assert.isNull(CustomerSummaryActionResolver.opportunityOnAccount(a, closed.Id, true), 'a new update needs an open deal');
        Assert.isNotNull(CustomerSummaryActionResolver.opportunityOnAccount(a, closed.Id, false), 'an undo may restore a closed one');
    }
}
