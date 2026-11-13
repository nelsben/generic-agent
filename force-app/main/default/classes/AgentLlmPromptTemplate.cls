/**
 * AgentLlmPromptTemplate: the AgentLlm template provider. Runs a Prompt Builder prompt template by API name
 * through ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate. The only class in the repo that touches it.
 *
 * Reached by class name from AgentLlm (TEMPLATE_PROVIDER_CLASS) when a prompt's Agent_Prompt_Setting__mdt record
 * has Source Prompt template. Each input is sent as 'Input:<name>'. Unlike the Models API chat request, the
 * template request takes a maximum-token setting (additionalConfig.maxTokens), so the length is sent here.
 * The running user needs the Execute Prompt Templates permission (docs/research/fr2-model-door.md).
 * No DML. Any failure is an AgentLlm.LlmException, with the original exception as its cause.
 */
public with sharing class AgentLlmPromptTemplate implements AgentLlm.TemplateProvider {
    /** The application name the platform's own template invocable sends. */
    @TestVisible private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';
    private static final String INPUT_PREFIX = 'Input:';

    /**
     * Runs the template and returns the first generation's text.
     * @param templateName the prompt template's API name
     * @param inputs values by template input API name
     * @param maxTokens the maximum reply length in tokens, or null for the template's own
     * @return the generated text
     * @throws AgentLlm.LlmException when the name is blank, the call fails, or no text comes back
     */
    public String generate(String templateName, Map<String, String> inputs, Integer maxTokens) {
        if (String.isBlank(templateName)) {
            throw new AgentLlm.LlmException('No prompt template name was given.');
        }
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response;
        try {
            response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateName.trim(), buildInput(inputs, maxTokens));
        } catch (Exception e) {
            throw wrap(templateName, e);
        }
        return textOf(response);
    }

    @TestVisible
    private static ConnectApi.EinsteinPromptTemplateGenerationsInput buildInput(Map<String, String> inputs, Integer maxTokens) {
        Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();
        if (inputs != null) {
            for (String name : inputs.keySet()) {
                ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
                String value = inputs.get(name);
                wrapped.value = value == null ? '' : value;
                params.put(INPUT_PREFIX + name, wrapped);
            }
        }
        ConnectApi.EinsteinLlmAdditionalConfigInput config = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        config.applicationName = APPLICATION_NAME;
        if (maxTokens != null && maxTokens > 0) {
            config.maxTokens = maxTokens;
        }
        ConnectApi.EinsteinPromptTemplateGenerationsInput request = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        request.inputParams = params;
        request.additionalConfig = config;
        request.isPreview = false;
        return request;
    }

    /** The first generation's text. Throws when there is none. */
    @TestVisible
    private static String textOf(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response) {
        List<ConnectApi.EinsteinLLMGenerationItemOutput> generations = response?.generations;
        String text = generations == null || generations.isEmpty() ? null : generations[0].text;
        if (String.isBlank(text)) {
            throw new AgentLlm.LlmException('Prompt template returned no generation text.');
        }
        return text;
    }

    /** The seam's own error for any template failure, with the original exception kept as its cause. */
    @TestVisible
    private static AgentLlm.LlmException wrap(String templateName, Exception e) {
        AgentLlm.LlmException wrapped = new AgentLlm.LlmException(
            'Prompt template ' + templateName + ' failed: ' + e.getTypeName() + ': ' + e.getMessage());
        wrapped.initCause(e);
        return wrapped;
    }
}
