// summary-accuracy.apex (BE-29): does every count, amount and date in a live summary come from the gathered sections?
//
// Runs CustomerSummary.run() for ONE sample account per execution: SAMPLE picks it from SAMPLE_NAMES (0 to 4),
// existing accounts from the seed data in data/sample/accounts.json. One account per run keeps each transaction to
// one brief (about 30 queries and up to 4 model calls (two pre-reduces, the sentiment call and the synthesis)) instead of five. Run it once per sample, for example:
//   for i in 0 1 2 3 4; do sed "s/^Integer SAMPLE = 0;/Integer SAMPLE = $i;/" scripts/summary-accuracy.apex > "$TMP/s$i.apex"; \
//     sf apex run --file "$TMP/s$i.apex" --target-org agent-probe --json > "$TMP/s$i.json"; done
// Not wrapped in a savepoint: the model calls must run, and a savepoint before a callout fails it. The run writes
// the product's own memory row for (this user, this account), as any summary does. It spends up to 4 model calls (two pre-reduces, the sentiment call and the synthesis).
//
// It prints only counts and true/false checks, plus each unmatched value with the answer section it sits in.
// It never prints an account name, an Id or answer text. Every line starts with 'ACC|' so it can be read out of
// the debug log. The check is textual: it normalises the answer's tokens and the sections' tokens and compares them.
//   date    yyyy-MM-dd, or a month name with day and year, "Month D" or "Month YYYY": matched against section dates.
//   amount  $ with digits, optionally K/M/B or thousand/million/billion: matched within the precision written.
//   percent n%: matched against the section percents.
//   count   any other whole number: matched against the section numbers.
// Numbers written as words ("three deals") are not checked.

Integer SAMPLE = 0;
List<String> SAMPLE_NAMES = new List<String>{
    'Edge Communications', 'Brindlewick Hydroponics', 'Tamsin Ridge Logistics', 'Oddfellow Marine Supply', 'Pimble Quarry Works'
};
String label = 'sample=' + (SAMPLE + 1);

List<Account> picked = [SELECT Id FROM Account WHERE Name = :SAMPLE_NAMES[SAMPLE] WITH USER_MODE ORDER BY CreatedDate LIMIT 1];
if (picked.isEmpty()) {
    throw new IllegalArgumentException('ACC|' + label + ' found=false');
}
Id accountId = picked[0].Id;
Integer sessionsBefore = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId()];

CustomerSummary.Result r = CustomerSummary.run(accountId, null, null);

Integer sessionsAfter = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId()];
Integer sessionsTouched = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId() AND Account__c = :accountId AND LastModifiedDate = TODAY];

// ---- The gathered sections: every token they hold. ----
Map<String, Integer> monthOf = new Map<String, Integer>{
    'jan' => 1, 'feb' => 2, 'mar' => 3, 'apr' => 4, 'may' => 5, 'jun' => 6,
    'jul' => 7, 'aug' => 8, 'sep' => 9, 'oct' => 10, 'nov' => 11, 'dec' => 12
};
Pattern isoDate = Pattern.compile('\\b(\\d{4})-(\\d{2})-(\\d{2})\\b');
Pattern namedDate = Pattern.compile('(?i)\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?\\b');
Pattern monthYear = Pattern.compile('(?i)\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s+(\\d{4})\\b');
Pattern money = Pattern.compile('(?i)\\$\\s?(\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.(\\d+))?\\s?(k|m|b|thousand|million|billion)?\\b');
Pattern percent = Pattern.compile('(\\d+(?:\\.\\d+)?)\\s?%');
Pattern wholeNumber = Pattern.compile('(?<![\\d.,])(\\d{1,3}(?:,\\d{3})+|\\d+)(?![\\d%])');

String sectionText = '';
Integer ok = 0;
Integer empty = 0;
Integer failedSections = 0;
for (CustomerSummarySection s : r.sections) {
    sectionText += '\n' + CustomerSummarySection.withoutIds(s.body);
    if (s.status == CustomerSummarySection.OK) {
        ok++;
    } else if (s.status == CustomerSummarySection.EMPTY) {
        empty++;
    } else {
        failedSections++;
    }
}

Set<String> sectionDates = new Set<String>();
List<Decimal> sectionAmounts = new List<Decimal>();
Set<Decimal> sectionPercents = new Set<Decimal>();
Set<Long> sectionNumbers = new Set<Long>();
String masked = sectionText;
Matcher m = isoDate.matcher(sectionText);
while (m.find()) {
    sectionDates.add(m.group(0));
    sectionNumbers.add(Long.valueOf(m.group(1)));
    masked = masked.replace(m.group(0), ' ');
}
m = money.matcher(masked);
while (m.find()) {
    sectionAmounts.add(Decimal.valueOf(m.group(1).replace(',', '') + (m.group(2) == null ? '' : '.' + m.group(2))));
}
masked = money.matcher(masked).replaceAll(' ');
m = percent.matcher(masked);
while (m.find()) {
    sectionPercents.add(Decimal.valueOf(m.group(1)).stripTrailingZeros());
}
masked = percent.matcher(masked).replaceAll(' ');
m = wholeNumber.matcher(masked);
while (m.find()) {
    sectionNumbers.add(Long.valueOf(m.group(1).replace(',', '')));
}

// ---- The answer: each token, the answer section it sits in, and whether the sections hold it. ----
String answer = r.answer == null ? '' : r.answer;
List<String> labels = new List<String>{ 'Account', 'Open deals', 'People & engagement', 'Service health', 'Deal history', 'Watch next' };
List<Integer> labelAt = new List<Integer>();
List<String> labelName = new List<String>();
Integer offset = 0;
for (String line : answer.split('\n')) {
    if (labels.contains(line.trim())) {
        labelAt.add(offset);
        labelName.add(line.trim());
    }
    offset += line.length() + 1;
}

Map<String, Integer> seen = new Map<String, Integer>{ 'date' => 0, 'amount' => 0, 'percent' => 0, 'count' => 0 };
Map<String, Integer> unmatched = new Map<String, Integer>{ 'date' => 0, 'amount' => 0, 'percent' => 0, 'count' => 0 };
List<String> misses = new List<String>();
// Masking keeps offsets: a matched token is replaced by spaces of the same length.
String rest = answer;

// Dates first, so their digits are not read again as counts.
List<Pattern> datePatterns = new List<Pattern>{ isoDate, namedDate, monthYear };
for (Integer p = 0; p < datePatterns.size(); p++) {
    m = datePatterns[p].matcher(rest);
    while (m.find()) {
        String token;
        Boolean found = false;
        if (p == 0) {
            token = m.group(0);
            found = sectionDates.contains(token);
        } else if (p == 1) {
            Integer mon = monthOf.get(m.group(1).toLowerCase().left(3));
            String md = String.valueOf(mon).leftPad(2, '0') + '-' + m.group(2).leftPad(2, '0');
            token = (m.group(3) == null ? '' : m.group(3) + '-') + md;
            for (String d : sectionDates) {
                found = found || (m.group(3) == null ? d.endsWith('-' + md) : d == token);
            }
        } else {
            Integer mon = monthOf.get(m.group(1).toLowerCase().left(3));
            token = m.group(2) + '-' + String.valueOf(mon).leftPad(2, '0');
            for (String d : sectionDates) {
                found = found || d.startsWith(token + '-');
            }
        }
        seen.put('date', seen.get('date') + 1);
        if (!found) {
            unmatched.put('date', unmatched.get('date') + 1);
            Integer at = m.start();
            String place = 'headline';
            for (Integer i = 0; i < labelAt.size(); i++) {
                if (labelAt[i] <= at) {
                    place = labelName[i];
                }
            }
            misses.add('date ' + token + ' in=' + place);
        }
        rest = rest.substring(0, m.start()) + ' '.repeat(m.end() - m.start()) + rest.substring(m.end());
    }
}

m = money.matcher(rest);
while (m.find()) {
    Decimal value = Decimal.valueOf(m.group(1).replace(',', '') + (m.group(2) == null ? '' : '.' + m.group(2)));
    String unit = m.group(3) == null ? '' : m.group(3).toLowerCase().left(1);
    Decimal mult = unit == 'k' || unit == 't' ? 1000 : unit == 'm' ? 1000000 : unit == 'b' ? 1000000000 : 1;
    Integer decimals = m.group(2) == null ? 0 : m.group(2).length();
    // Half a unit of the last digit written: "$1.2M" covers 1,150,000 to 1,250,000; "$45,000" only 45,000 (to the dollar).
    Decimal tolerance = mult == 1 ? 0.5 : mult * 0.5 / Decimal.valueOf(Math.pow(10, decimals));
    Decimal amount = value * mult;
    Boolean found = false;
    for (Decimal s : sectionAmounts) {
        found = found || Math.abs(s - amount) <= tolerance;
    }
    seen.put('amount', seen.get('amount') + 1);
    if (!found) {
        unmatched.put('amount', unmatched.get('amount') + 1);
        String place = 'headline';
        for (Integer i = 0; i < labelAt.size(); i++) {
            if (labelAt[i] <= m.start()) {
                place = labelName[i];
            }
        }
        misses.add('amount ' + amount.setScale(0) + ' in=' + place);
    }
}
rest = money.matcher(rest).replaceAll(' ');
// replaceAll changes lengths, so the answer-section labels are looked up again in rest from here on.
labelAt.clear();
labelName.clear();
offset = 0;
for (String line : rest.split('\n')) {
    if (labels.contains(line.trim())) {
        labelAt.add(offset);
        labelName.add(line.trim());
    }
    offset += line.length() + 1;
}

m = percent.matcher(rest);
while (m.find()) {
    Decimal value = Decimal.valueOf(m.group(1)).stripTrailingZeros();
    seen.put('percent', seen.get('percent') + 1);
    if (!sectionPercents.contains(value)) {
        unmatched.put('percent', unmatched.get('percent') + 1);
        String place = 'headline';
        for (Integer i = 0; i < labelAt.size(); i++) {
            if (labelAt[i] <= m.start()) {
                place = labelName[i];
            }
        }
        misses.add('percent ' + value + ' in=' + place);
    }
}
rest = rest.replaceAll('(\\d+(?:\\.\\d+)?)\\s?%', '');
labelAt.clear();
labelName.clear();
offset = 0;
for (String line : rest.split('\n')) {
    if (labels.contains(line.trim())) {
        labelAt.add(offset);
        labelName.add(line.trim());
    }
    offset += line.length() + 1;
}

m = wholeNumber.matcher(rest);
while (m.find()) {
    Long value = Long.valueOf(m.group(1).replace(',', ''));
    seen.put('count', seen.get('count') + 1);
    if (!sectionNumbers.contains(value)) {
        unmatched.put('count', unmatched.get('count') + 1);
        String place = 'headline';
        for (Integer i = 0; i < labelAt.size(); i++) {
            if (labelAt[i] <= m.start()) {
                place = labelName[i];
            }
        }
        misses.add('count ' + value + ' in=' + place);
    }
}

Integer totalSeen = seen.get('date') + seen.get('amount') + seen.get('percent') + seen.get('count');
Integer totalMissed = unmatched.get('date') + unmatched.get('amount') + unmatched.get('percent') + unmatched.get('count');
Boolean saysNotLoaded = answer.containsIgnoreCase('could not be loaded') || answer.containsIgnoreCase('couldn\'t be loaded')
    || answer.containsIgnoreCase('couldn\'t load') || answer.containsIgnoreCase('could not load');

System.debug(LoggingLevel.ERROR, 'ACC|' + label + ' status=' + r.status + ' sections=' + r.sections.size() + ' ok=' + ok
    + ' empty=' + empty + ' error=' + failedSections + ' answer_chars=' + answer.length()
    + ' cut_marker=' + answer.endsWith('[Cut short: this summary reached its length limit.]'));
System.debug(LoggingLevel.ERROR, 'ACC|' + label + ' dates=' + seen.get('date') + '/' + unmatched.get('date')
    + ' amounts=' + seen.get('amount') + '/' + unmatched.get('amount')
    + ' percents=' + seen.get('percent') + '/' + unmatched.get('percent')
    + ' counts=' + seen.get('count') + '/' + unmatched.get('count')
    + ' (seen/unmatched) tokens=' + totalSeen + ' unmatched=' + totalMissed + ' all_matched=' + (totalMissed == 0));
System.debug(LoggingLevel.ERROR, 'ACC|' + label + ' error_sections=' + failedSections
    + ' says_not_loaded=' + saysNotLoaded + ' error_rule_ok=' + (failedSections == 0 || saysNotLoaded));
System.debug(LoggingLevel.ERROR, 'ACC|' + label + ' session_rows_before=' + sessionsBefore + ' session_rows_after=' + sessionsAfter
    + ' session_rows_written_today_for_account=' + sessionsTouched);
for (String miss : misses) {
    System.debug(LoggingLevel.ERROR, 'ACC|' + label + ' unmatched ' + miss);
}
