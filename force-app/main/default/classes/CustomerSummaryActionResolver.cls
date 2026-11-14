/**
 * CustomerSummaryActionResolver: turns the plain words in an action request into records and dates (BE-27).
 *
 * People and deals resolve inside the open account only, in user mode, so a rep never reaches a record they cannot
 * see. Each lookup returns every match: the caller treats 0 as unresolved and 2 or more as a choice, and never
 * guesses (BE-22: the model fills in a person the request never named, so this check is the guard).
 *
 * Dates resolve from words such as 'tomorrow', 'next Tuesday', 'in 3 days', 'end of next month', 'Nov 17' or
 * 'YYYY-MM-DD'; date-times from those plus a time ('at 2pm', '14:30', 'noon'). Words that do not read as a date give
 * null, so the field comes back for the user to fill. No DML or callout.
 */
public with sharing class CustomerSummaryActionResolver {
    private static final Integer MAX_ROWS = 200;
    private static final Date A_MONDAY = Date.newInstance(1900, 1, 1);
    private static final Map<String, Integer> WEEKDAYS = new Map<String, Integer>{
        'monday' => 0, 'mon' => 0, 'tuesday' => 1, 'tue' => 1, 'tues' => 1, 'wednesday' => 2, 'wed' => 2,
        'thursday' => 3, 'thu' => 3, 'thur' => 3, 'thurs' => 3, 'friday' => 4, 'fri' => 4,
        'saturday' => 5, 'sat' => 5, 'sunday' => 6, 'sun' => 6
    };
    private static final Map<String, Integer> MONTHS = new Map<String, Integer>{
        'january' => 1, 'jan' => 1, 'february' => 2, 'feb' => 2, 'march' => 3, 'mar' => 3, 'april' => 4, 'apr' => 4,
        'may' => 5, 'june' => 6, 'jun' => 6, 'july' => 7, 'jul' => 7, 'august' => 8, 'aug' => 8,
        'september' => 9, 'sep' => 9, 'sept' => 9, 'october' => 10, 'oct' => 10, 'november' => 11, 'nov' => 11,
        'december' => 12, 'dec' => 12
    };
    private static final Map<String, Integer> NUMBERS = new Map<String, Integer>{
        'a' => 1, 'an' => 1, 'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5, 'six' => 6,
        'seven' => 7, 'eight' => 8, 'nine' => 9, 'ten' => 10
    };
    private static final Pattern ISO_DATE = Pattern.compile('^(\\d{4}-\\d{2}-\\d{2})$');
    private static final Pattern ISO_DATETIME = Pattern.compile('^(\\d{4}-\\d{2}-\\d{2})[t ](\\d{1,2}):(\\d{2})(:\\d{2}(\\.\\d+)?)?z?$');
    private static final Pattern IN_N = Pattern.compile('^in (\\w+) (day|days|week|weeks|month|months)$');
    private static final Pattern MONTH_DAY = Pattern.compile('^([a-z]+) (\\d{1,2})(st|nd|rd|th)?(,? (\\d{4}))?$');
    private static final Pattern DAY_MONTH = Pattern.compile('^(\\d{1,2})(st|nd|rd|th)? (of )?([a-z]+)(,? (\\d{4}))?$');
    private static final Pattern CLOCK = Pattern.compile(
        '(\\bat\\s+)?\\b(\\d{1,2})(?::(\\d{2}))?\\s*(a\\.?m\\.?|p\\.?m\\.?)?(?=\\s|$|,)'
    );
    private static final Pattern MINUTES = Pattern.compile('^(\\d{1,4})\\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)?$');

    // ------------------------------------------------------------------ people and deals

    /**
     * Contacts on the account whose first, last or full name is the words, in user mode.
     * @param accountId the open account
     * @param words a name as said, such as 'Maria', 'maria lopez' or "Maria's"
     * @return every match, empty for none or blank words
     */
    public static List<Contact> contacts(Id accountId, String words) {
        String w = nameWords(words);
        List<Contact> hits = new List<Contact>();
        if (accountId == null || String.isBlank(w)) {
            return hits;
        }
        for (Contact c : [SELECT Id, Name, FirstName, LastName FROM Contact WHERE AccountId = :accountId
                          WITH USER_MODE ORDER BY LastName, FirstName LIMIT :MAX_ROWS]) {
            String first = c.FirstName == null ? '' : c.FirstName.toLowerCase();
            String last = c.LastName == null ? '' : c.LastName.toLowerCase();
            if (w == first || w == last || w == (first + ' ' + last).trim()) {
                hits.add(c);
            }
        }
        return hits;
    }

    /**
     * One contact by Id, only when it is on the account and the user can see it.
     * @param accountId the open account
     * @param contactId the contact a chip or an edited draft names
     * @return the contact, or null
     */
    public static Contact contactOnAccount(Id accountId, Id contactId) {
        if (accountId == null || contactId == null || contactId.getSObjectType() != Contact.SObjectType) {
            return null;
        }
        List<Contact> rows = [SELECT Id, Name FROM Contact WHERE Id = :contactId AND AccountId = :accountId WITH USER_MODE LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * Open opportunities on the account whose name holds the words, in user mode. A name that is exactly the words
     * wins over names that only hold them.
     * @param accountId the open account
     * @param words a deal's name as said, such as 'the Core Router Refresh deal'
     * @return every match, empty for none or blank words
     */
    public static List<Opportunity> openOpportunities(Id accountId, String words) {
        String w = dealWords(words);
        List<Opportunity> hits = new List<Opportunity>();
        if (accountId == null || String.isBlank(w)) {
            return hits;
        }
        List<Opportunity> exact = new List<Opportunity>();
        for (Opportunity o : [SELECT Id, Name FROM Opportunity WHERE AccountId = :accountId AND IsClosed = false
                              WITH USER_MODE ORDER BY CloseDate, Name LIMIT :MAX_ROWS]) {
            String name = o.Name.toLowerCase();
            if (name == w) {
                exact.add(o);
            } else if (name.contains(w)) {
                hits.add(o);
            }
        }
        return exact.isEmpty() ? hits : exact;
    }

    /**
     * One opportunity by Id, only when it is on the account and the user can see it.
     * @param accountId the open account
     * @param opportunityId the deal a chip, an edited draft or an undo names
     * @param openOnly true to refuse a closed deal (a new update), false to allow one (an undo of a stage change)
     * @return the opportunity, or null
     */
    public static Opportunity opportunityOnAccount(Id accountId, Id opportunityId, Boolean openOnly) {
        if (accountId == null || opportunityId == null || opportunityId.getSObjectType() != Opportunity.SObjectType) {
            return null;
        }
        List<Opportunity> rows = [SELECT Id, Name, IsClosed FROM Opportunity WHERE Id = :opportunityId AND AccountId = :accountId
                                  WITH USER_MODE LIMIT 1];
        if (rows.isEmpty() || (openOnly == true && rows[0].IsClosed)) {
            return null;
        }
        return rows[0];
    }

    // ------------------------------------------------------------------ dates

    /**
     * A day from plain words.
     * @param words such as 'today', 'tomorrow', 'Friday', 'next Tuesday', 'this Friday', 'in 3 days', 'next week'
     *        (the Monday after today), 'next month' (its first day), 'end of the week' (Friday), 'end of next month',
     *        'end of the quarter', 'Nov 17', '17 November 2027' or 'YYYY-MM-DD'
     * @param today the day the words are counted from
     * @return the day, or null when the words are not a date this reads
     */
    public static Date toDate(String words, Date today) {
        String w = dateWords(words);
        if (String.isBlank(w) || today == null) {
            return null;
        }
        Matcher iso = ISO_DATE.matcher(w);
        if (iso.matches()) {
            return isoDate(iso.group(1));
        }
        Date fixed = fixedWord(w, today);
        if (fixed != null) {
            return fixed;
        }
        Date weekday = weekdayWords(w, today);
        if (weekday != null) {
            return weekday;
        }
        Date counted = inN(w, today);
        if (counted != null) {
            return counted;
        }
        return monthAndDay(w, today);
    }

    /**
     * A moment from plain words: a day (as toDate, today when none is said) and a time, in the user's time zone.
     * A bare hour from 1 to 7 with no am or pm is read as afternoon ('at 2' is 2pm).
     * @param words such as 'tomorrow at 2pm', 'next Tuesday 10:30am', 'at noon', 'YYYY-MM-DDTHH:MM'
     * @param today the day the words are counted from
     * @return the moment, or null when no time is said or the words do not read
     */
    public static Datetime toDatetime(String words, Date today) {
        String w = dateWords(words);
        if (String.isBlank(w) || today == null) {
            return null;
        }
        Matcher iso = ISO_DATETIME.matcher(w);
        if (iso.matches()) {
            Date day = isoDate(iso.group(1));
            Integer h = Integer.valueOf(iso.group(2));
            Integer m = Integer.valueOf(iso.group(3));
            return day == null || h > 23 || m > 59 ? null : Datetime.newInstance(day, Time.newInstance(h, m, 0, 0));
        }
        Time t;
        String rest = w;
        if (w.contains('noon') || w.contains('midday')) {
            t = Time.newInstance(12, 0, 0, 0);
            rest = w.replace('at noon', ' ').replace('at midday', ' ').replace('noon', ' ').replace('midday', ' ');
        } else {
            Matcher m = CLOCK.matcher(w);
            while (m.find()) {
                Boolean marked = m.group(1) != null || m.group(3) != null || m.group(4) != null;
                if (!marked) {
                    continue;
                }
                t = clock(Integer.valueOf(m.group(2)), m.group(3) == null ? 0 : Integer.valueOf(m.group(3)), m.group(4));
                rest = w.substring(0, m.start()) + ' ' + w.substring(m.end());
                break;
            }
        }
        if (t == null) {
            return null;
        }
        rest = rest.normalizeSpace();
        Date day = String.isBlank(rest) ? today : toDate(rest, today);
        return day == null ? null : Datetime.newInstance(day, t);
    }

    /**
     * Minutes from words or a number: '30', '45 minutes', '1 hour', 'an hour', 'half an hour'.
     * @param words the length as said
     * @return the minutes, or null when they do not read or are not positive
     */
    public static Integer toMinutes(String words) {
        if (String.isBlank(words)) {
            return null;
        }
        String w = words.toLowerCase().normalizeSpace();
        if (w == 'half an hour' || w == 'half hour') {
            return 30;
        }
        if (w == 'an hour' || w == 'one hour') {
            return 60;
        }
        Matcher m = MINUTES.matcher(w.removeEnd('.0'));
        if (!m.matches()) {
            return null;
        }
        Integer n = Integer.valueOf(m.group(1));
        String unit = m.group(2);
        if (unit != null && unit.startsWith('h')) {
            n = n * 60;
        }
        return n > 0 ? n : null;
    }

    // ------------------------------------------------------------------ helpers

    private static String nameWords(String words) {
        if (String.isBlank(words)) {
            return '';
        }
        String w = words.toLowerCase().replace('’', '\'').normalizeSpace();
        w = w.removeStart('with ').removeStart('to ').removeEnd('\'s').removeEnd('.');
        return w.trim();
    }

    private static String dealWords(String words) {
        if (String.isBlank(words)) {
            return '';
        }
        String w = words.toLowerCase().replace('’', '\'').normalizeSpace();
        w = w.removeStart('the ').removeEnd('.').removeEnd('\'s');
        w = w.removeEnd(' opportunity').removeEnd(' deal').removeEnd(' opp');
        return w.trim();
    }

    private static String dateWords(String words) {
        if (String.isBlank(words)) {
            return '';
        }
        String w = words.toLowerCase().replace(',', ' ').normalizeSpace().removeEnd('.');
        for (String lead : new List<String>{ 'on ', 'by ', 'due ', 'for ', 'starting ' }) {
            w = w.removeStart(lead);
        }
        return w.trim();
    }

    /** YYYY-MM-DD as a real day; a day the month does not have, such as 2026-02-30, is null. */
    private static Date isoDate(String text) {
        List<String> parts = text.split('-');
        Integer month = Integer.valueOf(parts[1]);
        if (month < 1 || month > 12) {
            return null;
        }
        return validDay(Integer.valueOf(parts[0]), month, Integer.valueOf(parts[2]));
    }

    private static Date fixedWord(String w, Date today) {
        String plain = w.replace(' the ', ' ');
        switch on plain {
            when 'today', 'now' {
                return today;
            }
            when 'tomorrow' {
                return today.addDays(1);
            }
            when 'yesterday' {
                return today.addDays(-1);
            }
            when 'next week' {
                return today.addDays(7 - weekday(today));
            }
            when 'next month' {
                return today.toStartOfMonth().addMonths(1);
            }
            when 'end of week', 'end of this week' {
                Integer ahead = 4 - weekday(today);
                return today.addDays(ahead >= 0 ? ahead : ahead + 7);
            }
            when 'end of month', 'end of this month' {
                return today.toStartOfMonth().addMonths(1).addDays(-1);
            }
            when 'end of next month' {
                return today.toStartOfMonth().addMonths(2).addDays(-1);
            }
            when 'end of quarter', 'end of this quarter' {
                Integer endMonth = ((today.month() - 1) / 3) * 3 + 3;
                return Date.newInstance(today.year(), endMonth, 1).addMonths(1).addDays(-1);
            }
            when else {
                return null;
            }
        }
    }

    /** 'friday' and 'next friday' are the first Friday after today; 'this friday' may be today. */
    private static Date weekdayWords(String w, Date today) {
        Boolean onOrAfter = w.startsWith('this ');
        String name = w.removeStart('next ').removeStart('this ').trim();
        if (!WEEKDAYS.containsKey(name)) {
            return null;
        }
        Integer ahead = Math.mod(WEEKDAYS.get(name) - weekday(today) + 7, 7);
        if (ahead == 0 && !onOrAfter) {
            ahead = 7;
        }
        return today.addDays(ahead);
    }

    private static Date inN(String w, Date today) {
        Matcher m = IN_N.matcher(w);
        if (!m.matches()) {
            return null;
        }
        Integer n = m.group(1).isNumeric() ? Integer.valueOf(m.group(1)) : NUMBERS.get(m.group(1));
        if (n == null) {
            return null;
        }
        String unit = m.group(2);
        if (unit.startsWith('day')) {
            return today.addDays(n);
        }
        if (unit.startsWith('week')) {
            return today.addDays(7 * n);
        }
        return today.addMonths(n);
    }

    /** 'nov 17', 'november 17th 2027', '17 november', '17th of nov': a month day with no year is the next one to come. */
    private static Date monthAndDay(String w, Date today) {
        String monthName;
        String dayText;
        String yearText;
        Matcher md = MONTH_DAY.matcher(w);
        Matcher dm = DAY_MONTH.matcher(w);
        if (md.matches()) {
            monthName = md.group(1);
            dayText = md.group(2);
            yearText = md.group(5);
        } else if (dm.matches()) {
            monthName = dm.group(4);
            dayText = dm.group(1);
            yearText = dm.group(6);
        } else {
            return null;
        }
        Integer month = MONTHS.get(monthName);
        if (month == null) {
            return null;
        }
        Integer year = yearText == null ? today.year() : Integer.valueOf(yearText);
        Date d = validDay(year, month, Integer.valueOf(dayText));
        if (d != null && yearText == null && d < today) {
            d = validDay(year + 1, month, Integer.valueOf(dayText));
        }
        return d;
    }

    private static Date validDay(Integer year, Integer month, Integer day) {
        if (day < 1 || day > Date.daysInMonth(year, month)) {
            return null;
        }
        return Date.newInstance(year, month, day);
    }

    /** 0 for Monday to 6 for Sunday, in any locale. */
    private static Integer weekday(Date d) {
        return Math.mod(A_MONDAY.daysBetween(d), 7);
    }

    private static Time clock(Integer hour, Integer minute, String half) {
        Integer h = hour;
        if (half != null && half.startsWith('p') && h < 12) {
            h += 12;
        } else if (half != null && half.startsWith('a') && h == 12) {
            h = 0;
        } else if (half == null && h >= 1 && h <= 7) {
            h += 12;
        }
        if (h > 23 || minute > 59) {
            return null;
        }
        return Time.newInstance(h, minute, 0, 0);
    }
}
