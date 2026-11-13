@IsTest
private class AgentLlmTest {
    private class Stub implements AgentLlm.Provider {
        String systemPrompt;
        String userPrompt;
        Integer maxTokens;
        String reply = '  model text  ';
        Exception toThrow;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (toThrow != null) {
                throw toThrow;
            }
            this.systemPrompt = systemPrompt;
            this.userPrompt = userPrompt;
            this.maxTokens = maxTokens;
            return reply;
        }
    }

    /** A provider that also takes the model a prompt's setting names. */
    private class ModelStub implements AgentLlm.ModelProvider {
        String model = 'not called';
        Integer maxTokens;
        String userPrompt;
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            return complete(systemPrompt, userPrompt, maxTokens, null);
        }
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens, String model) {
            this.model = model;
            this.maxTokens = maxTokens;
            this.userPrompt = userPrompt;
            return 'model text';
        }
    }

    private class TemplateStub implements AgentLlm.TemplateProvider {
        String templateName;
        Map<String, String> inputs;
        Integer maxTokens;
        Integer calls = 0;
        String reply = '  template text  ';
        Exception toThrow;
        public String generate(String templateName, Map<String, String> inputs, Integer maxTokens) {
            calls++;
            if (toThrow != null) {
                throw toThrow;
            }
            this.templateName = templateName;
            this.inputs = inputs;
            this.maxTokens = maxTokens;
            return reply;
        }
    }

    private static final String DEAL = 'BriefDealHistory';
    private static final Map<String, String> DEAL_VARS = new Map<String, String>{ 'deal_history' => 'Won 3 of 4.' };

    private static Stub install() {
        Stub s = new Stub();
        AgentLlm.stub = s;
        AgentLlm.settingsForTest = new Map<String, Agent_Prompt_Setting__mdt>();
        return s;
    }

    private static TemplateStub installTemplate() {
        TemplateStub t = new TemplateStub();
        AgentLlm.templateStub = t;
        return t;
    }

    /** Only these settings exist for this test. */
    private static void useSettings(List<Agent_Prompt_Setting__mdt> rows) {
        Map<String, Agent_Prompt_Setting__mdt> byName = new Map<String, Agent_Prompt_Setting__mdt>();
        for (Agent_Prompt_Setting__mdt row : rows) {
            byName.put(row.DeveloperName, row);
        }
        AgentLlm.settingsForTest = byName;
    }

    private static Agent_Prompt_Setting__mdt templateSetting(String inputs) {
        return new Agent_Prompt_Setting__mdt(
            DeveloperName = DEAL,
            Source__c = AgentLlm.SOURCE_TEMPLATE,
            Template_Name__c = 'Customer_Summary_Deal_History',
            Template_Inputs__c = inputs,
            Max_Tokens__c = 300
        );
    }

    private static User rep() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = 'llmrep' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(Alias = 'llmrep', Email = uniq + '@example.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Prompt Rep', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York', Username = uniq + '@example.com.agentllmtest');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Customer_Summary_Data_Access' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    private static String failure(String promptName, Map<String, String> vars) {
        try {
            AgentLlm.complete(promptName, vars, 100);
        } catch (AgentLlm.LlmException e) {
            return e.getMessage();
        }
        return null;
    }

    @IsTest
    static void loadsPromptAndFillsPlaceholders() {
        Stub stub = install();
        // A literal '$1' and a nested placeholder must survive untouched.
        String value = 'Won 3 of 4, average $1,250,000. {{deal_history}}';

        String out = AgentLlm.complete('BriefDealHistory', new Map<String, String>{ 'deal_history' => value }, 400);

        Assert.areEqual('model text', out);
        Assert.areEqual(400, stub.maxTokens);
        Assert.areEqual('Deal history:\n' + value, stub.userPrompt);
        Assert.isTrue(stub.systemPrompt.startsWith('Role:'));
        Assert.isFalse(stub.systemPrompt.contains('---'));
    }

    @IsTest
    static void everyBriefPromptHasBothParts() {
        for (String name : new List<String>{ 'BriefEngagement', 'BriefDealHistory', 'SummarySynthesis' }) {
            String raw = AgentLlm.loadPrompt(name);
            Assert.isTrue(AgentLlm.part(raw, '---system---', '---user---', name).length() > 0, name);
            Assert.isTrue(AgentLlm.part(raw, '---user---', null, name).contains('{{'), name);
        }
    }

    @IsTest
    static void missingPromptFailsClearly() {
        install();
        Assert.isTrue(failure('NoSuchPromptZz', null).contains('AgentPrompt_NoSuchPromptZz'));
        Assert.isTrue(failure(null, null).contains('Prompt not found'));
    }

    @IsTest
    static void missingVariableFailsClearly() {
        install();
        Assert.isTrue(failure('BriefDealHistory', new Map<String, String>()).contains('{{deal_history}}'));
        Assert.isTrue(failure('BriefDealHistory', null).contains('{{deal_history}}'));
    }

    @IsTest
    static void malformedPromptFailsClearly() {
        for (String raw : new List<String>{ 'no markers at all', '---user---\nu\n---system---\ns', null }) {
            try {
                AgentLlm.part(raw, '---system---', '---user---', 'Bad');
                Assert.fail('expected LlmException');
            } catch (AgentLlm.LlmException e) {
                Assert.isTrue(e.getMessage().contains('Prompt Bad must have'));
            }
        }
    }

    @IsTest
    static void fillHandlesNullsAndSpacing() {
        Assert.areEqual('plain', AgentLlm.fill('plain', null, 'P'));
        Assert.areEqual('a  b', AgentLlm.fill('a {{ x }} b', new Map<String, String>{ 'x' => null }, 'P'));
        Assert.areEqual('1-2', AgentLlm.fill('{{x}}-{{y}}', new Map<String, String>{ 'x' => '1', 'y' => '2' }, 'P'));
    }

    @IsTest
    static void blankModelTextFails() {
        Stub stub = install();
        stub.reply = '   ';
        Assert.isTrue(failure('BriefDealHistory', new Map<String, String>{ 'deal_history' => 'x' }).contains('no text'));
    }

    @IsTest
    static void providerDefaultsToModelsApi() {
        AgentLlm.stub = null;
        Assert.isTrue(AgentLlm.provider() instanceof AgentLlmModelsApi);
        Stub stub = install();
        Assert.areEqual(stub, AgentLlm.provider());
    }

    @IsTest
    static void anyProviderExceptionBecomesAnLlmException() {
        Stub stub = install();
        stub.toThrow = new CalloutException('socket closed');
        String message = failure('BriefDealHistory', new Map<String, String>{ 'deal_history' => 'x' });
        Assert.isNotNull(message, 'the provider exception must come back as an LlmException');
        Assert.isTrue(message.contains('CalloutException'), message);
        Assert.isTrue(message.contains('socket closed'), message);

        stub.toThrow = new AgentLlm.LlmException('already ours');
        Assert.areEqual('already ours', failure('BriefDealHistory', new Map<String, String>{ 'deal_history' => 'x' }));
    }

    @IsTest
    static void replyLengthIsCappedFromMaxTokens() {
        Stub stub = install();
        stub.reply = 'word '.repeat(2000);
        String out = AgentLlm.complete('BriefDealHistory', new Map<String, String>{ 'deal_history' => 'x' }, 50);
        Assert.isTrue(out.length() <= 200, 'about four characters a token: ' + out.length());
        Assert.isTrue(out.length() > 100, 'it is cut, not emptied: ' + out.length());

        String uncapped = AgentLlm.complete('BriefDealHistory', new Map<String, String>{ 'deal_history' => 'x' }, null);
        Assert.areEqual(('word '.repeat(2000)).trim().length(), uncapped.length(), 'no maxTokens means no cap');
    }

    @IsTest
    static void aPromptIsLoadedOncePerTransaction() {
        Integer before = Limits.getQueries();
        String first = AgentLlm.loadPrompt('BriefDealHistory');
        String second = AgentLlm.loadPrompt('BriefDealHistory');
        Assert.areEqual(1, Limits.getQueries() - before, 'the second load is served from the cache');
        Assert.areEqual(first, second);

        AgentLlm.loadPrompt('BriefEngagement');
        Assert.areEqual(2, Limits.getQueries() - before, 'another prompt is its own query');
    }

    // ---- Per-prompt settings (BE-33) ----

    @IsTest
    static void aPromptWithNoSettingKeepsTodaysBehaviour() {
        install();
        ModelStub model = new ModelStub();
        AgentLlm.stub = model;

        String out = AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual('model text', out);
        Assert.areEqual(400, model.maxTokens, 'the caller\'s length is used');
        Assert.isNull(model.model, 'no model is named, so the provider keeps its own default');
        AgentLlm.Setting s = AgentLlm.setting(DEAL);
        Assert.areEqual(AgentLlm.SOURCE_FILE, s.source, 'the prompt file is the default source');
        Assert.isFalse(s.trace, 'the trace is off by default');
    }

    @IsTest
    static void theSettingsModelReachesTheProvider() {
        install();
        ModelStub model = new ModelStub();
        AgentLlm.stub = model;
        useSettings(new List<Agent_Prompt_Setting__mdt>{
            new Agent_Prompt_Setting__mdt(DeveloperName = DEAL, Model__c = ' sfdc_ai__SomeOtherModel ')
        });

        AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual('sfdc_ai__SomeOtherModel', model.model, 'the model named on the prompt\'s setting, trimmed');
        Assert.areEqual(400, model.maxTokens, 'a blank maximum length keeps the caller\'s');
    }

    @IsTest
    static void aSettingOnlyAppliesToItsOwnPrompt() {
        install();
        ModelStub model = new ModelStub();
        AgentLlm.stub = model;
        useSettings(new List<Agent_Prompt_Setting__mdt>{
            new Agent_Prompt_Setting__mdt(DeveloperName = 'BriefEngagement', Model__c = 'sfdc_ai__SomeOtherModel', Max_Tokens__c = 10)
        });

        AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.isNull(model.model, 'another prompt\'s model is not used');
        Assert.areEqual(400, model.maxTokens, 'another prompt\'s length is not used');
    }

    @IsTest
    static void theSettingsMaximumLengthWinsAndTheCapStaysABackstop() {
        Stub stub = install();
        stub.reply = 'word '.repeat(2000);
        useSettings(new List<Agent_Prompt_Setting__mdt>{
            new Agent_Prompt_Setting__mdt(DeveloperName = DEAL, Max_Tokens__c = 50)
        });

        String out = AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual(50, stub.maxTokens, 'the setting\'s maximum length is sent to the provider');
        Assert.areEqual(('word '.repeat(40)).trim(), out, 'the reply is cut at 50 tokens times 4 characters (40 words), then trimmed');
    }

    @IsTest
    static void aPlainProviderStillWorksWhenTheSettingNamesAModel() {
        Stub stub = install();
        useSettings(new List<Agent_Prompt_Setting__mdt>{
            new Agent_Prompt_Setting__mdt(DeveloperName = DEAL, Model__c = 'sfdc_ai__SomeOtherModel')
        });

        Assert.areEqual('model text', AgentLlm.complete(DEAL, DEAL_VARS, 400));
        Assert.areEqual('Deal history:\nWon 3 of 4.', stub.userPrompt, 'a provider without a model setting is called as before');
    }

    @IsTest
    static void theShippedSettingsKeepTodaysValues() {
        AgentLlm.settingsForTest = null;
        AgentLlm.useOrgSettings = true;
        Map<String, Integer> lengths = new Map<String, Integer>{
            'BriefEngagement' => 600, 'BriefDealHistory' => 400, 'SummarySynthesis' => 1500, 'Explore' => 2000
        };
        for (String name : lengths.keySet()) {
            AgentLlm.Setting s = AgentLlm.setting(name);
            Assert.isTrue(s.found, 'a setting record ships for ' + name);
            Assert.areEqual(lengths.get(name), s.maxTokens, name + ' keeps its length');
            Assert.areEqual(AgentLlmModelsApi.MODEL, s.model, name + ' keeps today\'s model');
            Assert.isFalse(s.trace, name + ' ships with the trace off');
        }
        Assert.areEqual('Customer_Summary_Deal_History', AgentLlm.setting(DEAL).templateName, 'the sample template is named');
        Assert.areEqual('Deal_History', AgentLlm.setting(DEAL).templateInputs.get('deal_history'), 'and its input is mapped');
    }

    @IsTest
    static void aRepWithTheUserGroupsDataSetReadsPromptFilesAndSettings() {
        User u = rep();
        AgentLlm.settingsForTest = null;
        AgentLlm.useOrgSettings = true;
        String raw;
        AgentLlm.Setting s;
        Test.startTest();
        System.runAs(u) {
            raw = AgentLlm.loadPrompt(DEAL);
            s = AgentLlm.setting(DEAL);
        }
        Test.stopTest();
        Assert.isTrue(raw.contains('---user---'), 'the rep reads the prompt file in user mode');
        Assert.isTrue(s.found, 'the rep gets the prompt\'s setting although the type is not granted to them');
        Assert.areEqual(400, s.maxTokens);
    }

    // ---- The prompt template source ----

    @IsTest
    static void aTemplateSourceCallsTheTemplateWithMappedInputs() {
        Stub stub = install();
        AgentLlm.stub = null;
        TemplateStub t = installTemplate();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ templateSetting(' deal_history = Deal_History ') });

        String out = AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual('template text', out, 'the template\'s text comes back trimmed');
        Assert.areEqual('Customer_Summary_Deal_History', t.templateName);
        Assert.areEqual(new Map<String, String>{ 'Deal_History' => 'Won 3 of 4.' }, t.inputs, 'each variable goes to its mapped input');
        Assert.areEqual(300, t.maxTokens, 'the setting\'s maximum length is sent with the template call');
        Assert.isNull(stub.userPrompt, 'the prompt file path is not used');
    }

    @IsTest
    static void aTemplateCanTakeTheSystemSuffix() {
        install();
        TemplateStub t = installTemplate();
        useSettings(new List<Agent_Prompt_Setting__mdt>{
            templateSetting('deal_history=Deal_History; ' + AgentLlm.SYSTEM_SUFFIX_VAR + '=Brand_Lines')
        });

        AgentLlm.complete(DEAL, DEAL_VARS, 400, 'Tone: plain.');

        Assert.areEqual('Tone: plain.', t.inputs.get('Brand_Lines'), 'the suffix goes to the input mapped to ' + AgentLlm.SYSTEM_SUFFIX_VAR);
        Assert.areEqual('Won 3 of 4.', t.inputs.get('Deal_History'));
    }

    @IsTest
    static void aTemplateWithAnUnknownVariableFailsClearly() {
        install();
        installTemplate();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ templateSetting('deal_size=Deal_Size') });

        String message = failure(DEAL, DEAL_VARS);

        Assert.isNotNull(message, 'expected an LlmException');
        Assert.isTrue(message.contains('{{deal_size}}'), message);
    }

    @IsTest
    static void aTemplateSettingWithNoNameOrABadMapFailsClearly() {
        install();
        installTemplate();
        Agent_Prompt_Setting__mdt noName = templateSetting('deal_history=Deal_History');
        noName.Template_Name__c = ' ';
        useSettings(new List<Agent_Prompt_Setting__mdt>{ noName });
        String message = failure(DEAL, DEAL_VARS);
        Assert.isTrue(message.contains('names no prompt template'), message);

        useSettings(new List<Agent_Prompt_Setting__mdt>{ templateSetting('deal_history') });
        message = failure(DEAL, DEAL_VARS);
        Assert.isTrue(message.contains('variable=Input_Name'), message);
    }

    @IsTest
    static void aTemplateFailureBecomesAnLlmException() {
        install();
        TemplateStub t = installTemplate();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ templateSetting('deal_history=Deal_History') });

        t.toThrow = new CalloutException('template timed out');
        String message = failure(DEAL, DEAL_VARS);
        Assert.isTrue(message.contains('prompt template'), message);
        Assert.isTrue(message.contains('CalloutException'), message);
        Assert.isTrue(message.contains('template timed out'), message);

        t.toThrow = null;
        t.reply = '  ';
        Assert.isTrue(failure(DEAL, DEAL_VARS).contains('no text'), 'a blank template reply fails like a blank model reply');
    }

    @IsTest
    static void aProviderStubWinsOverATemplateSourceInTests() {
        Stub stub = install();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ templateSetting('deal_history=Deal_History') });

        Assert.areEqual('model text', AgentLlm.complete(DEAL, DEAL_VARS, 400));
        Assert.areEqual('Deal history:\nWon 3 of 4.', stub.userPrompt,
            'a test that stubs only the model provider never reaches the platform template call');
    }

    @IsTest
    static void theTemplateProviderIsReachedByClassName() {
        AgentLlm.templateStub = null;
        Assert.isTrue(AgentLlm.templateProvider() instanceof AgentLlmPromptTemplate);
        TemplateStub t = installTemplate();
        Assert.areEqual(t, AgentLlm.templateProvider());
    }

    // ---- The prompt trace ----

    @IsTest
    static void theTraceIsOffByDefault() {
        install();
        AgentLlm.traceSink = new List<String>();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ new Agent_Prompt_Setting__mdt(DeveloperName = DEAL) });

        AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual(0, AgentLlm.traceSink.size(), 'nothing is traced: ' + AgentLlm.traceSink);
    }

    @IsTest
    static void theTraceWritesTheFilledTextAndTheReplyLengthForItsPromptOnly() {
        install();
        AgentLlm.traceSink = new List<String>();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ new Agent_Prompt_Setting__mdt(DeveloperName = DEAL, Trace__c = true) });

        AgentLlm.complete(DEAL, DEAL_VARS, 400);
        AgentLlm.complete('BriefEngagement', new Map<String, String>{
            'account_name' => 'A', 'contacts' => 'c', 'activity' => 'a', 'calls' => 'k'
        }, 600);

        String all = String.join(AgentLlm.traceSink, '\n');
        Assert.areEqual(3, AgentLlm.traceSink.size(), all);
        Assert.isTrue(AgentLlm.traceSink[0].startsWith('AgentLlm trace ' + DEAL + ' system: Role:'), all);
        Assert.areEqual('AgentLlm trace ' + DEAL + ' user: Deal history:\nWon 3 of 4.', AgentLlm.traceSink[1]);
        Assert.areEqual('AgentLlm trace ' + DEAL + ' reply: 10 characters', AgentLlm.traceSink[2]);
        Assert.isFalse(all.contains('BriefEngagement'), 'a prompt without the trace on is not traced');
    }

    @IsTest
    static void theTraceNeverWritesRecordIds() {
        install();
        AgentLlm.traceSink = new List<String>();
        useSettings(new List<Agent_Prompt_Setting__mdt>{ new Agent_Prompt_Setting__mdt(DeveloperName = DEAL, Trace__c = true) });
        Account a = new Account(Name = 'Trace Account');
        insert a;
        String id18 = String.valueOf(a.Id);
        String id15 = id18.left(15);

        AgentLlm.complete(DEAL, new Map<String, String>{ 'deal_history' => 'Won ' + id18 + ' and (' + id15 + ').' }, 400);

        String all = String.join(AgentLlm.traceSink, '\n');
        Assert.isFalse(all.contains(id15), 'no record Id, in either length, reaches the trace: ' + all);
        Assert.isTrue(all.contains('Won [id] and ([id]).'), all);
        Assert.isTrue(all.contains('Role:'), 'ordinary words are kept');
    }

    @IsTest
    static void theTraceCoversTheTemplatePath() {
        install();
        installTemplate();
        AgentLlm.traceSink = new List<String>();
        Agent_Prompt_Setting__mdt row = templateSetting('deal_history=Deal_History');
        row.Trace__c = true;
        useSettings(new List<Agent_Prompt_Setting__mdt>{ row });

        AgentLlm.complete(DEAL, DEAL_VARS, 400);

        Assert.areEqual(new List<String>{
            'AgentLlm trace ' + DEAL + ' template: Customer_Summary_Deal_History',
            'AgentLlm trace ' + DEAL + ' input Deal_History: Won 3 of 4.',
            'AgentLlm trace ' + DEAL + ' reply: 13 characters'
        }, AgentLlm.traceSink);
    }
}
