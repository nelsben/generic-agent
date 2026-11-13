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

    private static Stub install() {
        Stub s = new Stub();
        AgentLlm.stub = s;
        return s;
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
}
