/**
 * CustomerSummary: the only entry point for an account summary. Gather, then reduce.
 *
 * run() (1) checks the account is visible to the user, (2) builds the included gather sources
 * from the registry, in registry order, (3) reduces them with the model through AgentLlm,
 * (4) records the turn in CustomerSummaryMemory and the summary as a customer outcome, (5) returns a Result.
 * runAll() does the same for several briefs in one transaction: every brief's model calls first, then one memory
 * write and one outcome write, each on its own: a failed write is logged and the briefs still return (BE-35).
 * The synthesis also sees the account's outcome context (CustomerOutcomes.contextFor): the last summary's headline
 * and date and the last few outcomes, by type and date only for anyone but their author.
 * runAll() builds at most MAX_BRIEFS_PER_CALL briefs; each Ask past that gets ERROR with fixed text, so a
 * caller that sends many requests in one call never reaches a governor limit it cannot catch (N1).
 * An answer longer than MAX_ANSWER_CHARS is cut at a sentence or line end and ends on CUT_MARKER (N8).
 *
 * Gather is deterministic Apex (CustomerSummarySource classes, no LLM). Reduce is data-driven:
 * PRE_REDUCES says which source keys a pre-reduce prompt condenses first; every other source
 * goes straight to the synthesis prompt. All prose lives in the prompt files, not here.
 * Runs with sharing. The only writes are the memory record and the outcome, made after every model call.
 * A brief where no section is OK and at least one failed is an ERROR, not EMPTY, and calls no model.
 */
public with sharing class CustomerSummary {
    public static final String OK = 'OK';
    public static final String EMPTY = 'EMPTY';
    public static final String NOT_FOUND = 'NOT_FOUND';
    public static final String ERROR = 'ERROR';

    @TestVisible private static final String NOT_FOUND_TEXT = 'I can\'t see that account. Check the name or your access.';
    @TestVisible private static final String ERROR_TEXT = 'I couldn\'t finish the brief right now. Try again in a minute.';
    @TestVisible private static final String NO_SECTIONS_TEXT = 'None of those sections exist. Valid sections: ';
    @TestVisible private static final String EMPTY_TEXT = 'Nothing is on record for the requested sections.';
    @TestVisible private static final String NOT_REQUESTED = 'EMPTY: not requested';
    @TestVisible private static final String SKIPPED = 'EMPTY';
    /**
     * Briefs built in one runAll call. One brief runs at most about 25 SOQL queries and 3 model calls;
     * three briefs and the memory write stay well inside the 100-query limit
     * (CustomerSummaryTest.threeFullRequestsAtTheCapStayWellInsideTheQueryLimit). A fourth could reach it.
     */
    @TestVisible private static final Integer MAX_BRIEFS_PER_CALL = 3;
    @TestVisible private static final String OVER_CAP_TEXT = 'I can build up to ' + MAX_BRIEFS_PER_CALL
        + ' summaries in one request. Ask for this account again on its own.';
    /** The longest answer returned, marker included: under the chat relay's limit of about 6,000 characters. */
    @TestVisible private static final Integer MAX_ANSWER_CHARS = 5900;
    @TestVisible private static final String CUT_MARKER = '\n[Cut short: this summary reached its length limit.]';
    private static final String SYNTHESIS_PROMPT = 'SummarySynthesis';
    private static final Integer SYNTHESIS_MAX_TOKENS = 1500;

    /** The gather registry, in brief order. One line per source: key, then Apex class name. */
    @TestVisible private static List<Source> registry = new List<Source>{
        new Source('profile', 'CustomerSummaryProfileSection'),
        new Source('open_deals', 'CustomerSummaryOpenDealsSection'),
        new Source('cases', 'CustomerSummaryCasesSection'),
        new Source('contacts', 'CustomerSummaryContactsSection'),
        new Source('activity', 'CustomerSummaryActivitySection'),
        new Source('calls', 'CustomerSummaryCallsSection'),
        new Source('deal_history', 'CustomerSummaryDealHistorySection')
    };

    /** Which source keys each pre-reduce prompt condenses, and the synthesis variable it fills. */
    private static final List<PreReduce> PRE_REDUCES = new List<PreReduce>{
        new PreReduce('BriefEngagement', 'engagement_summary', 600, new List<String>{ 'contacts', 'activity', 'calls' }),
        new PreReduce('BriefDealHistory', 'deal_history_summary', 400, new List<String>{ 'deal_history' })
    };

    public class Result {
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public String answer;
        @AuraEnabled public List<CustomerSummarySection> sections = new List<CustomerSummarySection>();
        @AuraEnabled public List<String> ignored = new List<String>();
        /** The same brief as cards (BE-39), built from the members above: no new query or model call. */
        @AuraEnabled public List<AnswerCard> cards = new List<AnswerCard>();
    }

    /** One brief for runAll: the same three inputs run() takes. */
    public class Ask {
        public Id accountId;
        public String question;
        public Set<String> include;

        public Ask(Id accountId, String question, Set<String> include) {
            this.accountId = accountId;
            this.question = question;
            this.include = include;
        }
    }

    /** One registry source as a picker lists it. */
    public class SourceInfo {
        @AuraEnabled public String key;
        @AuraEnabled public String title;
    }

    /** The registry's keys and titles, in brief order. Reads no data and calls no model. */
    public static List<SourceInfo> sources() {
        List<SourceInfo> out = new List<SourceInfo>();
        for (Source src : registry) {
            SourceInfo info = new SourceInfo();
            info.key = src.key;
            info.title = src.key;
            try {
                info.title = ((CustomerSummarySource) Type.forName(src.className).newInstance()).title();
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CustomerSummary source ' + src.key + ' has no title: ' + e.getTypeName() + ': ' + e.getMessage());
            }
            out.add(info);
        }
        return out;
    }

    @TestVisible
    private class Source {
        public String key;
        public String className;
        public Source(String key, String className) {
            this.key = key;
            this.className = className;
        }
    }

    private class PreReduce {
        String prompt;
        String output;
        Integer maxTokens;
        List<String> sources;
        PreReduce(String prompt, String output, Integer maxTokens, List<String> sources) {
            this.prompt = prompt;
            this.output = output;
            this.maxTokens = maxTokens;
            this.sources = sources;
        }
    }

    /**
     * The brief for one account. include picks sources by key; null or empty means all.
     * Keys are matched trimmed and case-insensitively; unknown keys are listed in Result.ignored.
     */
    public static Result run(Id accountId, String question, Set<String> include) {
        return runAll(new List<Ask>{ new Ask(accountId, question, include) })[0];
    }

    /**
     * Several briefs in one transaction, one Result per Ask in the same order (a null Ask gives NOT_FOUND).
     * Only the first MAX_BRIEFS_PER_CALL Asks are built; each later one gets ERROR with OVER_CAP_TEXT and
     * runs no query and no model call.
     * Each brief's model callouts run in turn; the memory writes are collected and saved in one upsert
     * after the last callout, because a callout after uncommitted DML fails.
     */
    public static List<Result> runAll(List<Ask> asks) {
        List<Result> results = new List<Result>();
        List<CustomerSummaryMemory.Entry> memory = new List<CustomerSummaryMemory.Entry>();
        List<CustomerOutcomes.Input> outcomes = new List<CustomerOutcomes.Input>();
        for (Ask a : asks == null ? new List<Ask>() : asks) {
            if (results.size() >= MAX_BRIEFS_PER_CALL) {
                results.add(finish(new Result(), ERROR, OVER_CAP_TEXT, OVER_CAP_TEXT));
            } else {
                results.add(a == null
                    ? brief(null, null, null, memory, outcomes)
                    : brief(a.accountId, a.question, a.include, memory, outcomes));
            }
        }

        for (Result r : results) {
            r.cards = cardsOf(r);
        }

        // 4. Memory, last: DML before a callout would fail the model calls above.
        if (!memory.isEmpty()) {
            try {
                CustomerSummaryMemory.recordAll(memory);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CustomerSummaryMemory.recordAll failed: ' + e.getTypeName() + ': ' + e.getMessage());
            }
        }

        // 4b. The summaries as customer outcomes, after the memory write and apart from it: an outcome that cannot
        // be saved (no outcome permission set, a refused write) is logged, rolls back only itself, and the brief stands.
        if (!outcomes.isEmpty()) {
            try {
                CustomerOutcomes.recordAll(outcomes);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CustomerOutcomes.recordAll failed: ' + e.getTypeName() + ': ' + e.getMessage());
            }
        }

        // 5. Return.
        return results;
    }

    /**
     * Steps 1-3 for one brief. A brief that should be remembered adds its turn to memory and its summary to
     * outcomes; nothing is written here.
     */
    private static Result brief(
        Id accountId, String question, Set<String> include, List<CustomerSummaryMemory.Entry> memory,
        List<CustomerOutcomes.Input> outcomes
    ) {
        Result r = new Result();

        // 1. Visibility gate.
        Account acct = visibleAccount(accountId);
        if (acct == null) {
            return finish(r, NOT_FOUND, NOT_FOUND_TEXT, NOT_FOUND_TEXT);
        }

        Set<String> wanted = selectKeys(include, r.ignored);
        if (wanted.isEmpty()) {
            String text = NO_SECTIONS_TEXT + String.join(allKeys(), ', ') + '.';
            return finish(r, EMPTY, text, text);
        }

        // 2. Gather.
        Map<String, CustomerSummarySection> built = new Map<String, CustomerSummarySection>();
        Boolean anyOk = false;
        Boolean anyError = false;
        for (Source src : registry) {
            if (wanted.contains(src.key)) {
                CustomerSummarySection s = buildSource(src, accountId);
                r.sections.add(s);
                built.put(src.key, s);
                anyOk = anyOk || s.status == CustomerSummarySection.OK;
                anyError = anyError || s.status == CustomerSummarySection.ERROR;
            }
        }
        // Nothing loaded and something failed: the brief failed. Saying "nothing on record" would be wrong.
        if (!anyOk && anyError) {
            return finish(r, ERROR, ERROR_TEXT, ERROR_TEXT);
        }

        // 3. Reduce. Any model failure ends the brief here, with no memory write.
        String answer;
        try {
            answer = reduce(acct.Name, question, built, CustomerOutcomes.contextForVisibleAccount(accountId));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerSummary reduce failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return finish(r, ERROR, ERROR_TEXT, ERROR_TEXT);
        }
        finish(r, anyOk ? OK : EMPTY, anyOk ? '' : EMPTY_TEXT, clampAnswer(answer));
        memory.add(new CustomerSummaryMemory.Entry(accountId, r.status, question, r.answer));
        outcomes.add(summaryOutcome(accountId, question, r.answer));
        return r;
    }

    /** The summary as an outcome: the question (or "Summary") as title, the answer as body, its first line as headline. */
    private static CustomerOutcomes.Input summaryOutcome(Id accountId, String question, String answer) {
        CustomerOutcomes.Input o = new CustomerOutcomes.Input(accountId, CustomerOutcomes.SUMMARY);
        o.title = String.isBlank(question) ? 'Summary' : question.trim();
        o.body = answer;
        o.skill = 'summary';
        o.model = CustomerOutcomes.modelFor(SYNTHESIS_PROMPT);
        // BE-36 sets o.sentimentScore, o.sentimentLabel and o.sentimentReason here, from the synthesis it adds.
        return o;
    }

    /**
     * The answer as it is relayed: unchanged up to MAX_ANSWER_CHARS. A longer one (the model ran past the
     * prompt's length rule, or AgentLlm cut it at the output cap) is cut back to the last sentence or line
     * end that fits, and ends on CUT_MARKER, so it never stops mid-sentence without notice.
     */
    @TestVisible
    private static String clampAnswer(String text) {
        if (text == null || text.length() <= MAX_ANSWER_CHARS) {
            return text;
        }
        String head = text.left(MAX_ANSWER_CHARS - CUT_MARKER.length());
        Integer cut = head.lastIndexOf('\n');
        for (String stop : new List<String>{ '. ', '! ', '? ', '.\n', '!\n', '?\n' }) {
            Integer at = head.lastIndexOf(stop);
            cut = at < 0 ? cut : Math.max(cut, at + 1);
        }
        if (head.endsWith('.') || head.endsWith('!') || head.endsWith('?')) {
            cut = head.length();
        }
        // No sentence or line end in the second half: cut at the last space instead of mid-word.
        if (cut < head.length() / 2) {
            cut = Math.max(head.lastIndexOf(' '), head.length() / 2);
        }
        return head.left(cut).trim() + CUT_MARKER;
    }

    /**
     * The brief as cards (BE-39): the answer, then one card per section in the sections' order. The answer is a
     * summary card (its first line the title), an error card on ERROR, or one notice when there is nothing to
     * summarise (NOT_FOUND, or no valid sections). A failure building them gives no cards and changes nothing else.
     */
    private static List<AnswerCard> cardsOf(Result r) {
        List<AnswerCard> cards = new List<AnswerCard>();
        try {
            if (r.status == NOT_FOUND || (r.status == EMPTY && r.sections.isEmpty())) {
                cards.add(AnswerCard.notice('not', r.status, r.answer));
                return cards;
            }
            cards.add(r.status == ERROR ? AnswerCard.error('err', r.answer) : AnswerCard.summary('sum', r.status, r.answer));
            for (CustomerSummarySection s : r.sections) {
                if (s != null) {
                    cards.add(AnswerCard.section(s));
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerSummary cards not built: ' + e.getTypeName() + ': ' + e.getMessage());
            cards.clear();
        }
        return cards;
    }

    private static Result finish(Result r, String status, String message, String answer) {
        r.status = status;
        r.message = message;
        r.answer = answer;
        return r;
    }

    private static Account visibleAccount(Id accountId) {
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType) {
            return null;
        }
        try {
            List<Account> rows = [SELECT Id, Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
            return rows.isEmpty() ? null : rows[0];
        } catch (QueryException e) {
            // No read access to Account or its Name: the account is not visible to this user.
            System.debug(LoggingLevel.WARN, 'CustomerSummary visibility check failed: ' + e.getTypeName() + ': ' + e.getMessage());
            return null;
        }
    }

    private static List<String> allKeys() {
        List<String> keys = new List<String>();
        for (Source src : registry) {
            keys.add(src.key);
        }
        return keys;
    }

    /** Registry keys to build. Null, empty or all-blank include means every key. */
    private static Set<String> selectKeys(Set<String> include, List<String> ignored) {
        Set<String> known = new Set<String>(allKeys());
        Set<String> wanted = new Set<String>();
        if (include != null) {
            for (String raw : include) {
                if (String.isBlank(raw)) {
                    continue;
                }
                String key = raw.trim().toLowerCase();
                if (known.contains(key)) {
                    wanted.add(key);
                } else {
                    ignored.add(raw.trim());
                }
            }
        }
        return wanted.isEmpty() && ignored.isEmpty() ? known : wanted;
    }

    private static CustomerSummarySection buildSource(Source src, Id accountId) {
        CustomerSummarySection s;
        Exception failure;
        try {
            CustomerSummarySource impl = (CustomerSummarySource) Type.forName(src.className).newInstance();
            s = impl.build(accountId);
        } catch (Exception e) {
            failure = e;
        }
        if (s == null) {
            s = CustomerSummarySection.failed(src.key, src.key, failure);
        }
        return s;
    }

    /**
     * Pre-reduces where the map says, then synthesizes. Throws on any model failure. outcomeContext (may be blank)
     * goes after the brand lines in the synthesis system text, so the prompt file is unchanged.
     */
    private static String reduce(String accountName, String question, Map<String, CustomerSummarySection> built, String outcomeContext) {
        Map<String, String> synthesisVars = new Map<String, String>();
        Set<String> preReduced = new Set<String>();

        for (PreReduce p : PRE_REDUCES) {
            Map<String, String> vars = new Map<String, String>{ 'account_name' => accountName };
            Boolean hasData = false;
            List<String> failed = new List<String>();
            for (String key : p.sources) {
                CustomerSummarySection s = built.get(key);
                vars.put(key, sectionText(s));
                hasData = hasData || (s != null && s.status != CustomerSummarySection.EMPTY);
                if (s != null && s.status == CustomerSummarySection.ERROR) {
                    failed.add(sectionText(s));
                }
                preReduced.add(key);
            }
            String condensed = hasData ? AgentLlm.complete(p.prompt, vars, p.maxTokens) : SKIPPED;
            // A failed source stays visible after the pre-reduce as its own 'ERROR: ...' line, so the synthesis
            // prompt's ERROR rule applies to it and the brief never states "none" for a part that did not load.
            List<String> lines = new List<String>{ condensed };
            lines.addAll(failed);
            synthesisVars.put(p.output, String.join(lines, '\n'));
        }

        for (Source src : registry) {
            if (!preReduced.contains(src.key)) {
                synthesisVars.put(src.key, sectionText(built.get(src.key)));
            }
        }
        synthesisVars.put('account_name', accountName);
        synthesisVars.put('question', question == null ? '' : question.trim());
        // The brand's company and tone lines go after the synthesis prompt's own system text (BE-24), then the
        // account's earlier outcomes (BE-35).
        String suffix = BrandSettings.promptLines();
        if (String.isNotBlank(outcomeContext)) {
            suffix += '\n\n' + outcomeContext;
        }
        return AgentLlm.complete(SYNTHESIS_PROMPT, synthesisVars, SYNTHESIS_MAX_TOKENS, suffix);
    }

    /**
     * What a prompt sees for one source: the body if OK, '<STATUS>: <body>' otherwise.
     * The record Ids at line ends are for the panel's drill only: they never reach a model.
     */
    private static String sectionText(CustomerSummarySection s) {
        if (s == null) {
            return NOT_REQUESTED;
        }
        String body = CustomerSummarySection.withoutIds(s.body);
        if (s.status == CustomerSummarySection.OK) {
            return body;
        }
        return s.status + ': ' + body;
    }
}
