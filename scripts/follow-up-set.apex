// follow-up-set.apex (BE-30): do follow-ups after a summary resolve against the summary's own records?
//
// For ONE sample account per execution (SAMPLE, 0 or 1, from the seed data in data/sample/accounts.json):
//   STEP 0     runs CustomerSummary.run(), which writes the product's memory row for (this user, this account).
//   STEP 1..5  asks two of the ten follow-ups each, every one directly after the summary: the history is the
//              summary turn (question plus the remembered summary text) and the open record is the account,
//              which is what the panel sends after a summary.
// The summary and the follow-ups run in separate executions because the summary writes its row after its model
// calls, and a model call after an uncommitted write fails. Two follow-ups per execution keeps each transaction
// well under the query limit (each follow-up rebuilds the summary's sections for its context) and the callout time.
//   for s in 0 1; do for t in 0 1 2 3 4 5; do
//     sed -e "s/^Integer SAMPLE = 0;/Integer SAMPLE = $s;/" -e "s/^Integer STEP = 0;/Integer STEP = $t;/" \
//       scripts/follow-up-set.apex > "$TMP/f$s$t.apex"
//     sf apex run --file "$TMP/f$s$t.apex" --target-org agent-probe --json > "$TMP/f$s$t.json"; done; done
// To ask only some questions again, set ONLY to their numbers (1 to 10) and run STEP 1 with PER_STEP 10:
// the listed questions run in that one execution.
// Not wrapped in a savepoint: the model calls must run, and a savepoint before a callout fails it.
//
// It prints only pass or fail per question, the objects queried, the queries run and the model calls used, plus
// a short reason code on a fail. It never prints a name, an Id or answer text. Every line starts with 'FU|'.
// Pass rules, checked against the account's own records (read here in user mode):
//   - the status is not ERROR and the answer text carries no record Id;
//   - an "ask" question passes only when the explorer ran no query and its answer asks back ('?');
//   - any other question passes when the last query is on one of the expected objects, its rows are all
//     records in that question's allowed set (the account's open deals, contacts, cases or activities), and
//     a result with no record rows (an aggregate, or no match) has a plan that filters on the account or on
//     any record the summary lists (its open deals, contacts, cases, contact roles or activities).
// Each line also says whether the answer asks back (asked=, a '?' in it) and holds a digit (number=), so a
// no-query answer can be told apart: a question back, or an answer worked out from the context text.
// Model calls: a Models API call does not count in Limits.getCallouts() (step 0 measured 0 for a summary that made
// its calls), and the script cannot see the explorer's turns. Each explorer turn is one model call whose reply is
// either one query or the answer, so calls_min = queries run + 1 is a floor. Two cases add a call the script cannot
// see, so the real count can be higher: a reply the plan check refused (INVALID), and a query that threw (it
// reaches no result set).

Integer SAMPLE = 0;
Integer STEP = 0;
Integer PER_STEP = 2;
Set<Integer> ONLY = new Set<Integer>();
List<String> SAMPLE_NAMES = new List<String>{ 'Edge Communications', 'Brindlewick Hydroponics' };
String label = 'sample=' + (SAMPLE + 1);

List<Account> picked = [SELECT Id FROM Account WHERE Name = :SAMPLE_NAMES[SAMPLE] WITH USER_MODE ORDER BY CreatedDate LIMIT 1];
if (picked.isEmpty()) {
    throw new IllegalArgumentException('FU|' + label + ' found=false');
}
Id accountId = picked[0].Id;
Id me = UserInfo.getUserId();

if (STEP == 0) {
    Integer before = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :me];
    CustomerSummary.Result s = CustomerSummary.run(accountId, null, null);
    Integer after = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :me];
    Integer touched = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :me AND Account__c = :accountId AND LastModifiedDate = TODAY];
    System.debug(LoggingLevel.ERROR, 'FU|' + label + ' step=0 summary status=' + s.status
        + ' sessions_before=' + before + ' sessions_after=' + after + ' sessions_for_account_today=' + touched);
} else {

    String brief = CustomerSummaryMemory.lastBrief(accountId);
    if (String.isBlank(brief)) {
        throw new IllegalArgumentException('FU|' + label + ' step=' + STEP + ' no_summary_remembered (run step 0 first)');
    }
    String history = JSON.serialize(new List<Object>{
        new Map<String, Object>{ 'question' => 'Summarize this account', 'answer' => brief }
    });

    // ---- The account's own records: what each question may return. ----
    Set<Id> openDeals = new Map<Id, Opportunity>([SELECT Id FROM Opportunity WHERE AccountId = :accountId AND IsClosed = false WITH USER_MODE]).keySet();
    Set<Id> contacts = new Map<Id, Contact>([SELECT Id FROM Contact WHERE AccountId = :accountId WITH USER_MODE]).keySet();
    Set<Id> cases = new Map<Id, Case>([SELECT Id FROM Case WHERE AccountId = :accountId WITH USER_MODE]).keySet();
    Set<Id> activities = new Set<Id>();
    activities.addAll(new Map<Id, Task>([SELECT Id FROM Task WHERE AccountId = :accountId WITH USER_MODE LIMIT 500]).keySet());
    activities.addAll(new Map<Id, Event>([SELECT Id FROM Event WHERE AccountId = :accountId WITH USER_MODE LIMIT 500]).keySet());
    Set<Id> roles = new Map<Id, OpportunityContactRole>([SELECT Id FROM OpportunityContactRole WHERE OpportunityId IN :openDeals WITH USER_MODE]).keySet();
    Set<Id> people = new Set<Id>(contacts);
    people.addAll(roles);

    // question | expected objects (comma-separated, or 'ask') | allowed set key
    List<List<String>> QUESTIONS = new List<List<String>>{
        new List<String>{ 'Which of those close this quarter?', 'Opportunity', 'deals' },
        new List<String>{ 'Who there have we not called?', 'Contact', 'contacts' },
        new List<String>{ 'Any open cases on the biggest deal?', 'Case', 'cases' },
        new List<String>{ 'Which of those deals has the largest amount?', 'Opportunity', 'deals' },
        new List<String>{ 'Who are the contacts on those deals?', 'OpportunityContactRole,Contact', 'people' },
        new List<String>{ 'How many open cases do they have?', 'Case', 'cases' },
        new List<String>{ 'Which of those deals are past their close date?', 'Opportunity', 'deals' },
        new List<String>{ 'What is the total amount of those deals?', 'Opportunity', 'deals' },
        new List<String>{ 'When did we last log an activity there?', 'Task,Event', 'activities' },
        new List<String>{ 'Which of those matter most?', 'ask', '' }
    };
    Map<String, Set<Id>> allowed = new Map<String, Set<Id>>{
        'deals' => openDeals, 'contacts' => contacts, 'cases' => cases, 'people' => people, 'activities' => activities
    };
    Set<Id> anyListed = new Set<Id>();
    for (Set<Id> ids : allowed.values()) {
        anyListed.addAll(ids);
    }
    Pattern idInText = Pattern.compile('\\b[0-9][0-9A-Za-z]{14}(?:[0-9A-Za-z]{3})?\\b');

    Integer first = (STEP - 1) * PER_STEP;
    for (Integer q = first; q < Math.min(first + PER_STEP, QUESTIONS.size()); q++) {
        if (!ONLY.isEmpty() && !ONLY.contains(q + 1)) {
            continue;
        }
        List<String> spec = QUESTIONS[q];
        DataExplorer.Result r;
        String reason = '';
        try {
            r = DataExplorer.explore(spec[0], accountId, history);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FU|' + label + ' q=' + (q + 1) + ' pass=false reason=threw:' + e.getTypeName());
            continue;
        }
        List<String> objects = new List<String>();
        for (ExploreQuery.ResultSet rs : r.resultSets) {
            objects.add(rs.objectName);
        }
        String answer = r.answer == null ? '' : r.answer;
        if (r.status == DataExplorer.ERROR) {
            reason = 'error';
        } else if (idInText.matcher(answer).find()) {
            reason = 'id_in_answer';
        } else if (spec[1] == 'ask') {
            if (!r.resultSets.isEmpty()) {
                reason = 'queried_instead_of_asking';
            } else if (!answer.contains('?')) {
                reason = 'did_not_ask';
            }
        } else if (r.resultSets.isEmpty()) {
            reason = 'no_query';
        } else {
            ExploreQuery.ResultSet last = r.resultSets[r.resultSets.size() - 1];
            Set<Id> ok = allowed.get(spec[2]);
            if (!new Set<String>(spec[1].split(',')).contains(last.objectName)) {
                reason = 'wrong_object';
            } else if (!last.rows.isEmpty() && last.rows[0].containsKey('Id')) {
                for (Map<String, Object> row : last.rows) {
                    if (!ok.contains((Id) row.get('Id'))) {
                        reason = 'record_outside_summary';
                        break;
                    }
                }
            } else {
                Boolean scoped = last.planJson != null && last.planJson.contains(String.valueOf(accountId).left(15));
                for (Id i : anyListed) {
                    scoped = scoped || (last.planJson != null && last.planJson.contains(String.valueOf(i).left(15)));
                }
                if (!scoped) {
                    reason = 'aggregate_not_scoped';
                }
            }
        }
        System.debug(LoggingLevel.ERROR, 'FU|' + label + ' q=' + (q + 1) + ' pass=' + String.isBlank(reason)
            + (String.isBlank(reason) ? '' : ' reason=' + reason) + ' status=' + r.status
            + ' objects=' + (objects.isEmpty() ? 'none' : String.join(objects, '>')) + ' queries=' + objects.size()
            + ' calls_min=' + (objects.size() + 1) + ' asked=' + answer.contains('?')
            + ' number=' + Pattern.compile('\\d').matcher(answer).find());
    }
    Integer sessions = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :me];
    System.debug(LoggingLevel.ERROR, 'FU|' + label + ' step=' + STEP + ' sessions_now=' + sessions);
}
