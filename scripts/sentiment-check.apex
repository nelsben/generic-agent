// sentiment-check.apex (BE-36): does the summary's sentiment point the way the account's records do, run after run?
//
// Runs CustomerSummary.run() for ONE sample account per execution, with no question and every section, then reads
// the sentiment label off the Summary outcome that run recorded. SAMPLE picks the account (0 to 2) and RUN numbers
// the run (1 to 3); both are set with sed. Each sample is an existing account from the seed data
// (data/sample/*.json) whose direction was written down before the first live run, from its records alone:
//   0  Edge Communications       negative  an open escalated high-priority case, two open deals past their close date
//   1  Brindlewick Hydroponics   positive  a deal won about a month before the run
//   2  United Oil & Gas, UK      sparse    one open deal and nothing else on record: "Not enough activity"
// negative means At risk or Concerned, positive means Positive or Very positive, sparse means Not enough activity.
// Neutral agrees with none of them.
//
// One summary per execution: a second one in the same transaction would make a callout after the first one's
// writes. Not wrapped in a savepoint for the same reason. A run spends up to 4 model calls (two pre-reduces, the
// synthesis, the sentiment) and writes the product's own rows, as any summary does: one Customer Summary session row
// per user and account (updated on a repeat) and one Summary outcome.
//   for s in 0 1 2; do for n in 1 2 3; do
//     sed -e "s/^Integer SAMPLE = 0;/Integer SAMPLE = $s;/" -e "s/^Integer RUN = 1;/Integer RUN = $n;/" \
//       scripts/sentiment-check.apex > "$TMPDIR/sent-$s-$n.apex"
//     sf apex run --file "$TMPDIR/sent-$s-$n.apex" --target-org agent-probe --json > "$TMPDIR/sent-$s-$n.json"
//   done; done
//
// It prints one line per run and nothing else: the sample, the run, the expected direction and the returned label.
// The line starts with 'SENT|' so it can be read out of the debug log (which escapes '|' as '&#124;'). It never
// prints an account name, an Id, the answer, the score or the reason.

Integer SAMPLE = 0;
Integer RUN = 1;
List<String> SAMPLE_NAMES = new List<String>{ 'Edge Communications', 'Brindlewick Hydroponics', 'United Oil & Gas, UK' };
List<String> EXPECTED = new List<String>{ 'negative', 'positive', 'sparse' };
String line = 'SENT|sample=' + (SAMPLE + 1) + ' run=' + RUN + ' expected=' + EXPECTED[SAMPLE];

List<Account> picked = [SELECT Id FROM Account WHERE Name = :SAMPLE_NAMES[SAMPLE] WITH USER_MODE ORDER BY CreatedDate LIMIT 1];
if (picked.isEmpty()) {
    throw new IllegalArgumentException(line + ' found=false');
}
Id accountId = picked[0].Id;
List<String> summaryType = new List<String>{ CustomerOutcomes.SUMMARY };
Integer before = CustomerOutcomes.listOutcomes(accountId, summaryType, 200).size();

CustomerSummary.Result r = CustomerSummary.run(accountId, null, null);

List<CustomerOutcomes.Outcome> after = CustomerOutcomes.listOutcomes(accountId, summaryType, 200);
String returned;
if (r.status != CustomerSummary.OK && r.status != CustomerSummary.EMPTY) {
    returned = 'summary-' + r.status;
} else if (after.size() != before + 1) {
    returned = 'not-recorded';
} else {
    returned = String.isBlank(after[0].sentimentLabel) ? 'no-score' : after[0].sentimentLabel;
}
System.debug(LoggingLevel.ERROR, line + ' returned=' + returned);
