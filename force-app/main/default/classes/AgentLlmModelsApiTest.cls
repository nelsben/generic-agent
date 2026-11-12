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
