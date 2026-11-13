// prompt-try.apex (BE-33): run ONE named prompt for ONE sample account and print the reply, its length and the time.
//
// PROMPT is the prompt name, the same name as its Agent_Prompt_Setting__mdt record and its AgentPrompt_<name> file:
//   BriefDealHistory, BriefEngagement or SummarySynthesis. (Explore runs inside DataExplorer's own loop; try it there.)
// SAMPLE picks the account from SAMPLE_NAMES (0 to 4), existing accounts from the seed data in data/sample/accounts.json.
// The prompt runs through AgentLlm.complete, so its setting applies: model, maximum length, and Source (prompt file
// or prompt template). Turn the setting's Trace on to see the filled text in the debug log as well.
//   sf apex run --file scripts/prompt-try.apex --target-org agent-probe --json
//
// The vars are built the way CustomerSummary builds them: the gather sections' text with record Ids removed.
// SummarySynthesis first runs the two pre-reduce prompts, as CustomerSummary does, so it spends 3 model calls;
// the others spend 1. Not wrapped in a savepoint: a savepoint before a callout fails it. It writes no record:
// no summary session and no outcome row (it counts the summary sessions before and after to show that).
//
// It prints only the reply (with the account's name as [account]), counts and timings, never a name or an Id. Every line starts with 'TRY|'.

String PROMPT = 'BriefDealHistory';
Integer SAMPLE = 0;
List<String> SAMPLE_NAMES = new List<String>{
    'Edge Communications', 'Brindlewick Hydroponics', 'Tamsin Ridge Logistics', 'Oddfellow Marine Supply', 'Pimble Quarry Works'
};

List<Account> picked = [SELECT Id, Name FROM Account WHERE Name = :SAMPLE_NAMES[SAMPLE] WITH USER_MODE ORDER BY CreatedDate LIMIT 1];
if (picked.isEmpty()) {
    throw new IllegalArgumentException('TRY|sample=' + (SAMPLE + 1) + ' found=false');
}
Id accountId = picked[0].Id;
Integer sessionsBefore = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId() WITH USER_MODE];

Map<String, String> sourceClass = new Map<String, String>{
    'profile' => 'CustomerSummaryProfileSection', 'open_deals' => 'CustomerSummaryOpenDealsSection',
    'cases' => 'CustomerSummaryCasesSection', 'contacts' => 'CustomerSummaryContactsSection',
    'activity' => 'CustomerSummaryActivitySection', 'calls' => 'CustomerSummaryCallsSection',
    'deal_history' => 'CustomerSummaryDealHistorySection'
};
Map<String, List<String>> needs = new Map<String, List<String>>{
    'BriefDealHistory' => new List<String>{ 'deal_history' },
    'BriefEngagement' => new List<String>{ 'contacts', 'activity', 'calls' },
    'SummarySynthesis' => new List<String>(sourceClass.keySet())
};
if (!needs.containsKey(PROMPT)) {
    throw new IllegalArgumentException('TRY|prompt=' + PROMPT + ' supported=false');
}

Long gatherStart = System.currentTimeMillis();
Map<String, String> text = new Map<String, String>();
for (String key : needs.get(PROMPT)) {
    CustomerSummarySection s = ((CustomerSummarySource) Type.forName(sourceClass.get(key)).newInstance()).build(accountId);
    String body = CustomerSummarySection.withoutIds(s.body);
    text.put(key, s.status == CustomerSummarySection.OK ? body : s.status + ': ' + body);
}
Long gatherMs = System.currentTimeMillis() - gatherStart;

Map<String, String> vars = new Map<String, String>{ 'account_name' => picked[0].Name };
vars.putAll(text);
String suffix = null;
Integer calls = 1;
Long modelStart = System.currentTimeMillis();
if (PROMPT == 'SummarySynthesis') {
    Map<String, String> engagementVars = new Map<String, String>{
        'account_name' => picked[0].Name, 'contacts' => text.get('contacts'), 'activity' => text.get('activity'), 'calls' => text.get('calls')
    };
    vars.put('engagement_summary', AgentLlm.complete('BriefEngagement', engagementVars, 600));
    vars.put('deal_history_summary', AgentLlm.complete('BriefDealHistory', new Map<String, String>{ 'deal_history' => text.get('deal_history') }, 400));
    vars.put('question', '');
    suffix = BrandSettings.promptLines();
    calls = 3;
}
// The caller's lengths match CustomerSummary's; a setting's Max_Tokens__c wins over them.
Map<String, Integer> callerMax = new Map<String, Integer>{ 'BriefDealHistory' => 400, 'BriefEngagement' => 600, 'SummarySynthesis' => 1500 };
String reply = AgentLlm.complete(PROMPT, vars, callerMax.get(PROMPT), suffix);
Long modelMs = System.currentTimeMillis() - modelStart;

Integer sessionsAfter = [SELECT COUNT() FROM Customer_Summary_Session__c WHERE User__c = :UserInfo.getUserId() WITH USER_MODE];
AgentLlm.Setting setting = AgentLlm.setting(PROMPT);

System.debug(LoggingLevel.ERROR, 'TRY|prompt=' + PROMPT + ' sample=' + (SAMPLE + 1)
    + ' setting=' + setting.found + ' source=' + setting.source + ' model_calls=' + calls);
System.debug(LoggingLevel.ERROR, 'TRY|reply_chars=' + reply.length() + ' gather_ms=' + gatherMs + ' model_ms=' + modelMs);
System.debug(LoggingLevel.ERROR, 'TRY|sessions_before=' + sessionsBefore + ' sessions_after=' + sessionsAfter);
System.debug(LoggingLevel.ERROR, 'TRY|reply=' + CustomerSummarySection.withoutIds(reply).replace(picked[0].Name, '[account]').replace('\n', ' / '));
