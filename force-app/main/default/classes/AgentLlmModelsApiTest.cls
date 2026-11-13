@IsTest
private class AgentLlmModelsApiTest {
    // No test here calls the model: only request building and response reading are exercised.

    @IsTest
    static void buildsSystemAndUserMessagesForTheModel() {
        String body = JSON.serialize(AgentLlmModelsApi.buildRequest('Be brief.', 'Summarize this.'));
        Assert.isTrue(body.contains(AgentLlmModelsApi.MODEL));
        Assert.isTrue(body.contains('"role":"system"'));
        Assert.isTrue(body.contains('"content":"Be brief."'));
        Assert.isTrue(body.contains('"role":"user"'));
        Assert.isTrue(body.contains('"content":"Summarize this."'));
    }

    @IsTest
    static void thePromptsModelIsSentAndABlankOneFallsBack() {
        aiplatform.ModelsAPI.createChatGenerations_Request request = AgentLlmModelsApi.buildRequest('s', 'u', 'sfdc_ai__SomeOtherModel');
        Assert.areEqual('sfdc_ai__SomeOtherModel', request.modelName, 'the model named on the prompt\'s setting');

        Assert.areEqual(AgentLlmModelsApi.MODEL, AgentLlmModelsApi.buildRequest('s', 'u', ' ').modelName, 'blank falls back');
        Assert.areEqual(AgentLlmModelsApi.MODEL, AgentLlmModelsApi.buildRequest('s', 'u', null).modelName, 'null falls back');
        Assert.areEqual(AgentLlmModelsApi.MODEL, AgentLlmModelsApi.buildRequest('s', 'u').modelName, 'the old signature keeps the default');
    }

    @IsTest
    static void theRequestCarriesNoGenerationSettings() {
        // The chat generations body takes messages, localization, tags and contentModeration only (API 68.0):
        // no maximum tokens or temperature, so the reply length is capped in AgentLlm instead.
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            JSON.serialize(AgentLlmModelsApi.buildRequest('s', 'u', null).body));
        for (String key : body.keySet()) {
            Assert.isTrue(new Set<String>{ 'messages', 'localization', 'tags', 'contentModeration' }.contains(key.removeEnd('_set')), key);
        }
        Assert.isTrue(body.containsKey('messages'));
    }

    @IsTest
    static void blankSystemPromptSendsOnlyTheUserMessage() {
        String body = JSON.serialize(AgentLlmModelsApi.buildRequest(' ', null));
        Assert.isFalse(body.contains('"role":"system"'));
        Assert.isTrue(body.contains('"role":"user"'));
    }

    @IsTest
    static void readsTheFirstGenerationText() {
        Map<String, Object> response = new Map<String, Object>{
            'Code200' => new Map<String, Object>{
                'generationDetails' => new Map<String, Object>{
                    'generations' => new List<Object>{
                        new Map<String, Object>{ 'role' => 'assistant', 'content' => 'The brief.' }
                    }
                }
            }
        };
        Assert.areEqual('The brief.', AgentLlmModelsApi.textOf(response));
    }

    @IsTest
    static void missingTextFailsClearly() {
        List<Object> bad = new List<Object>{
            null,
            new Map<String, Object>{ 'Code200' => null },
            new Map<String, Object>{
                'Code200' => new Map<String, Object>{
                    'generationDetails' => new Map<String, Object>{ 'generations' => new List<Object>() }
                }
            }
        };
        for (Object response : bad) {
            try {
                AgentLlmModelsApi.textOf(response);
                Assert.fail('expected LlmException');
            } catch (AgentLlm.LlmException e) {
                Assert.isTrue(e.getMessage().contains('no generation text'));
            }
        }
    }

    @IsTest
    static void anyProviderFailureIsWrappedWithItsCause() {
        CalloutException raw = new CalloutException('read timed out');
        AgentLlm.LlmException wrapped = AgentLlmModelsApi.wrap(raw);
        Assert.isTrue(wrapped.getMessage().contains('System.CalloutException'), wrapped.getMessage());
        Assert.isTrue(wrapped.getMessage().contains('read timed out'), wrapped.getMessage());
        Assert.areEqual(raw, wrapped.getCause());
    }
}
