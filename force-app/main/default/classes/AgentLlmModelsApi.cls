/**
 * AgentLlmModelsApi: the default AgentLlm provider. Calls the Salesforce Models API
 * (chat generations) from Apex. The only class in the repo that touches that API.
 *
 * The chat generations request takes messages, localization, tags and contentModeration only (API 68.0):
 * no maximum-token or temperature setting. So maxTokens is accepted for the Provider contract and not sent;
 * AgentLlm.complete caps the reply length for every provider. The model is the one named on the prompt's
 * Agent_Prompt_Setting__mdt record (AgentLlm.ModelProvider), else MODEL.
 * No DML. Any failure is an AgentLlm.LlmException, with the original exception as its cause.
 */
public with sharing class AgentLlmModelsApi implements AgentLlm.ModelProvider {
    public static final String MODEL = 'sfdc_ai__DefaultBedrockAnthropicClaude45Sonnet';

    public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
        return complete(systemPrompt, userPrompt, maxTokens, null);
    }

    /** As complete(systemPrompt, userPrompt, maxTokens), with the given model (Apex names are case-blind, so the parameter is not called model); blank means MODEL. */
    public String complete(String systemPrompt, String userPrompt, Integer maxTokens, String modelName) {
        return textOf(call(buildRequest(systemPrompt, userPrompt, modelName)));
    }

    private static Object call(aiplatform.ModelsAPI.createChatGenerations_Request request) {
        try {
            return new aiplatform.ModelsAPI().createChatGenerations(request);
        } catch (Exception e) {
            throw wrap(e);
        }
    }

    /** The seam's own error for any provider failure, with the original exception kept as its cause. */
    @TestVisible
    private static AgentLlm.LlmException wrap(Exception e) {
        String detail = e instanceof aiplatform.ModelsAPI.createChatGenerations_ResponseException
            ? 'Models API error ' + ((aiplatform.ModelsAPI.createChatGenerations_ResponseException) e).responseCode + ': ' + e.getMessage()
            : 'Models API call failed: ' + e.getTypeName() + ': ' + e.getMessage();
        AgentLlm.LlmException wrapped = new AgentLlm.LlmException(detail);
        wrapped.initCause(e);
        return wrapped;
    }

    @TestVisible
    private static aiplatform.ModelsAPI.createChatGenerations_Request buildRequest(String systemPrompt, String userPrompt) {
        return buildRequest(systemPrompt, userPrompt, null);
    }

    @TestVisible
    private static aiplatform.ModelsAPI.createChatGenerations_Request buildRequest(String systemPrompt, String userPrompt, String modelName) {
        List<aiplatform.ModelsAPI_ChatMessageRequest> messages = new List<aiplatform.ModelsAPI_ChatMessageRequest>();
        if (String.isNotBlank(systemPrompt)) {
            messages.add(message('system', systemPrompt));
        }
        messages.add(message('user', userPrompt == null ? '' : userPrompt));

        aiplatform.ModelsAPI_ChatGenerationsRequest body = new aiplatform.ModelsAPI_ChatGenerationsRequest();
        body.messages = messages;

        aiplatform.ModelsAPI.createChatGenerations_Request request = new aiplatform.ModelsAPI.createChatGenerations_Request();
        request.modelName = String.isBlank(modelName) ? MODEL : modelName.trim();
        request.body = body;
        return request;
    }

    private static aiplatform.ModelsAPI_ChatMessageRequest message(String role, String content) {
        aiplatform.ModelsAPI_ChatMessageRequest m = new aiplatform.ModelsAPI_ChatMessageRequest();
        m.role = role;
        m.content = content;
        return m;
    }

    /**
     * The first generation's text from a chat generations response, read through its JSON shape
     * (Code200.generationDetails.generations[0].content). Throws when there is none.
     */
    @TestVisible
    private static String textOf(Object response) {
        Object node = response == null ? null : JSON.deserializeUntyped(JSON.serialize(response));
        for (String step : new List<String>{ 'Code200', 'generationDetails', 'generations' }) {
            node = node instanceof Map<String, Object> ? ((Map<String, Object>) node).get(step) : null;
        }
        List<Object> generations = node instanceof List<Object> ? (List<Object>) node : new List<Object>();
        Object first = generations.isEmpty() ? null : generations[0];
        Object content = first instanceof Map<String, Object> ? ((Map<String, Object>) first).get('content') : null;
        if (!(content instanceof String) || String.isBlank((String) content)) {
            throw new AgentLlm.LlmException('Models API returned no generation text.');
        }
        return (String) content;
    }
}
