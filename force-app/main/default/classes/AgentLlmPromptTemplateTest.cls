@IsTest
private class AgentLlmPromptTemplateTest {
    // No test here runs a prompt template: only the request building and the response reading are exercised.

    @IsTest
    static void buildsTheTemplateRequestFromTheMappedInputs() {
        ConnectApi.EinsteinPromptTemplateGenerationsInput request = AgentLlmPromptTemplate.buildInput(
            new Map<String, String>{ 'Deal_History' => 'Won 3 of 4.', 'Brand_Lines' => null }, 400);

        Assert.areEqual(2, request.inputParams.size());
        Assert.areEqual('Won 3 of 4.', request.inputParams.get('Input:Deal_History').value, 'each input is keyed Input:<name>');
        Assert.areEqual('', request.inputParams.get('Input:Brand_Lines').value, 'a null value is sent as empty text');
        Assert.isFalse(request.isPreview, 'the template is run, not only resolved');
        Assert.areEqual(AgentLlmPromptTemplate.APPLICATION_NAME, request.additionalConfig.applicationName);
    }

    @IsTest
    static void sendsTheMaximumLengthAsTheRequestsOwnSetting() {
        ConnectApi.EinsteinPromptTemplateGenerationsInput request = AgentLlmPromptTemplate.buildInput(new Map<String, String>(), 400);
        Assert.areEqual(400, request.additionalConfig.maxTokens, 'the template call takes a maximum-token setting');

        request = AgentLlmPromptTemplate.buildInput(null, null);
        Assert.isNull(request.additionalConfig.maxTokens, 'no length means none is sent');
        Assert.areEqual(0, request.inputParams.size());
    }

    @IsTest
    static void readsTheFirstGenerationText() {
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
        ConnectApi.EinsteinLLMGenerationItemOutput first = new ConnectApi.EinsteinLLMGenerationItemOutput();
        first.text = 'The brief.';
        ConnectApi.EinsteinLLMGenerationItemOutput second = new ConnectApi.EinsteinLLMGenerationItemOutput();
        second.text = 'Another.';
        response.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>{ first, second };

        Assert.areEqual('The brief.', AgentLlmPromptTemplate.textOf(response));
    }

    @IsTest
    static void missingTextFailsClearly() {
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation empty = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation noGenerations = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
        noGenerations.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>();
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation blank = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
        ConnectApi.EinsteinLLMGenerationItemOutput item = new ConnectApi.EinsteinLLMGenerationItemOutput();
        item.text = '  ';
        blank.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>{ item };

        for (ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response
                : new List<ConnectApi.EinsteinPromptTemplateGenerationsRepresentation>{ null, empty, noGenerations, blank }) {
            try {
                AgentLlmPromptTemplate.textOf(response);
                Assert.fail('expected LlmException');
            } catch (AgentLlm.LlmException e) {
                Assert.isTrue(e.getMessage().contains('no generation text'), e.getMessage());
            }
        }
    }

    @IsTest
    static void anyTemplateFailureIsWrappedWithItsCause() {
        CalloutException raw = new CalloutException('read timed out');
        AgentLlm.LlmException wrapped = AgentLlmPromptTemplate.wrap('Customer_Summary_Deal_History', raw);
        Assert.isTrue(wrapped.getMessage().contains('Customer_Summary_Deal_History'), wrapped.getMessage());
        Assert.isTrue(wrapped.getMessage().contains('System.CalloutException'), wrapped.getMessage());
        Assert.isTrue(wrapped.getMessage().contains('read timed out'), wrapped.getMessage());
        Assert.areEqual(raw, wrapped.getCause());
    }

    @IsTest
    static void aBlankTemplateNameFailsBeforeAnyCall() {
        try {
            new AgentLlmPromptTemplate().generate(' ', new Map<String, String>(), 100);
            Assert.fail('expected LlmException');
        } catch (AgentLlm.LlmException e) {
            Assert.isTrue(e.getMessage().contains('No prompt template name'), e.getMessage());
        }
    }
}
