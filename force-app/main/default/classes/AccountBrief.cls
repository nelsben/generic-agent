/**
 * AccountBrief: the only entry point for an account brief. Gather, then reduce.
 *
 * run() (1) checks the account is visible to the user, (2) builds the included gather sources
 * from the registry, in registry order, (3) reduces them with the model through AgentLlm,
 * (4) records the turn in AccountBriefMemory, (5) returns a Result.
 *
 * Gather is deterministic Apex (AccountBriefSource classes, no LLM). Reduce is data-driven:
 * PRE_REDUCES says which source keys a pre-reduce prompt condenses first; every other source
 * goes straight to the synthesis prompt. All prose lives in the prompt files, not here.
 * Runs with sharing. The only write is the memory record, made after every model call.
 */
public with sharing class AccountBrief {
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
    private static final String SYNTHESIS_PROMPT = 'BriefSynthesis';
    private static final Integer SYNTHESIS_MAX_TOKENS = 1500;

    /** The gather registry, in brief order. One line per source: key, then Apex class name. */
    @TestVisible private static List<Source> registry = new List<Source>{
        new Source('profile', 'AccountBriefProfileSection'),
        new Source('open_deals', 'AccountBriefOpenDealsSection'),
        new Source('cases', 'AccountBriefCasesSection'),
        new Source('contacts', 'AccountBriefContactsSection'),
        new Source('activity', 'AccountBriefActivitySection'),
        new Source('calls', 'AccountBriefCallsSection'),
        new Source('deal_history', 'AccountBriefDealHistorySection')
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
        @AuraEnabled public List<AccountBriefSection> sections = new List<AccountBriefSection>();
        @AuraEnabled public List<String> ignored = new List<String>();
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
                info.title = ((AccountBriefSource) Type.forName(src.className).newInstance()).title();
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'AccountBrief source ' + src.key + ' has no title: ' + e.getMessage());
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
        Map<String, AccountBriefSection> built = new Map<String, AccountBriefSection>();
        for (Source src : registry) {
            if (wanted.contains(src.key)) {
                AccountBriefSection s = buildSource(src, accountId);
                r.sections.add(s);
                built.put(src.key, s);
            }
        }

        // 3. Reduce. Any model failure ends the brief here, with no memory write.
        String answer;
        try {
            answer = reduce(acct.Name, question, built);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AccountBrief reduce failed: ' + e.getMessage());
            return finish(r, ERROR, ERROR_TEXT, ERROR_TEXT);
        }
        Boolean anyOk = false;
        for (AccountBriefSection s : r.sections) {
            anyOk = anyOk || s.status == AccountBriefSection.OK;
        }
        finish(r, anyOk ? OK : EMPTY, anyOk ? '' : EMPTY_TEXT, answer);

        // 4. Memory, last: DML before a callout would fail the model calls above.
        try {
            AccountBriefMemory.record(accountId, r.status, question, r.answer);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AccountBriefMemory.record failed: ' + e.getMessage());
        }

        // 5. Return.
        return r;
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
        List<Account> rows = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
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

    private static AccountBriefSection buildSource(Source src, Id accountId) {
        AccountBriefSection s;
        try {
            AccountBriefSource impl = (AccountBriefSource) Type.forName(src.className).newInstance();
            s = impl.build(accountId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AccountBrief source ' + src.key + ' failed: ' + e.getMessage());
            s = null;
        }
        if (s == null) {
            s = new AccountBriefSection();
            s.key = src.key;
            s.title = src.key;
            s.status = AccountBriefSection.ERROR;
            s.body = 'Couldn\'t load ' + src.key + ' right now.';
        }
        return s;
    }

    /** Pre-reduces where the map says, then synthesizes. Throws on any model failure. */
    private static String reduce(String accountName, String question, Map<String, AccountBriefSection> built) {
        Map<String, String> synthesisVars = new Map<String, String>();
        Set<String> preReduced = new Set<String>();

        for (PreReduce p : PRE_REDUCES) {
            Map<String, String> vars = new Map<String, String>{ 'account_name' => accountName };
            Boolean hasData = false;
            for (String key : p.sources) {
                AccountBriefSection s = built.get(key);
                vars.put(key, sectionText(s));
                hasData = hasData || (s != null && s.status != AccountBriefSection.EMPTY);
                preReduced.add(key);
            }
            synthesisVars.put(p.output, hasData ? AgentLlm.complete(p.prompt, vars, p.maxTokens) : SKIPPED);
        }

        for (Source src : registry) {
            if (!preReduced.contains(src.key)) {
                synthesisVars.put(src.key, sectionText(built.get(src.key)));
            }
        }
        synthesisVars.put('account_name', accountName);
        synthesisVars.put('question', question == null ? '' : question.trim());
        return AgentLlm.complete(SYNTHESIS_PROMPT, synthesisVars, SYNTHESIS_MAX_TOKENS);
    }

    /** What a prompt sees for one source: the body if OK, '<STATUS>: <body>' otherwise. */
    private static String sectionText(AccountBriefSection s) {
        if (s == null) {
            return NOT_REQUESTED;
        }
        if (s.status == AccountBriefSection.OK) {
            return s.body;
        }
        return s.status + ': ' + s.body;
    }
}
