/**
 * AccountBriefAgentClient: one user message to the registered Account_Brief agent, and its reply.
 *
 * The panel's "Ask the agent" calls this through AccountBriefPanelController.askAgent. It runs the
 * standard invocable action generateAiAgentResponse for Account_Brief: the input userMessage and an
 * optional sessionId, the outputs agentResponse (a {"type":"Text","value":"..."} envelope) and
 * sessionId. Passing a turn's sessionId back continues that agent session.
 *
 * The open record goes in the message text, the way the probe proved
 * (docs/research/panel-agent-1.md). Any failure, of any kind, comes back as FAILURE_TEXT with
 * failed = true: raw platform text never reaches the panel.
 *
 * The action cannot run in an Apex test, so the call sits behind Transport; tests set transport.
 */
public with sharing class AccountBriefAgentClient {
    public static final String FAILURE_TEXT = 'The agent could not answer right now. Try again in a minute.';
    @TestVisible private static final String AGENT_API_NAME = 'Account_Brief';
    @TestVisible private static final String ACTION_NAME = 'generateAiAgentResponse';

    /** Sends one user message to the agent and returns the action's output parameters. */
    public interface Transport {
        Map<String, Object> send(String userMessage, String sessionId);
    }

    /** Test seam: the agent call. Tests replace it with a scripted Transport. */
    @TestVisible private static Transport transport = new ActionTransport();

    /** One agent turn as the panel receives it. */
    public class Reply {
        /** The agent's reply text, or FAILURE_TEXT. */
        @AuraEnabled public String text;
        /** The agent session to pass back for a follow-up; null when the turn failed. */
        @AuraEnabled public String sessionId;
        /** True when text is FAILURE_TEXT. */
        @AuraEnabled public Boolean failed = false;
    }

    private class AgentException extends Exception {}

    /**
     * One agent turn.
     * @param message the user's text, sent as typed (trimmed)
     * @param sessionId the session of an earlier turn to continue, or blank to start a new one
     * @param contextRecordId the record the user has open, or null; appended to the message
     * @return the reply text and session, or FAILURE_TEXT with failed = true
     */
    public static Reply ask(String message, String sessionId, Id contextRecordId) {
        if (String.isBlank(message)) {
            return failure();
        }
        try {
            Map<String, Object> outputs = transport.send(
                userMessage(message, contextRecordId), String.isBlank(sessionId) ? null : sessionId);
            String text = unwrap(outputs == null ? null : outputs.get('agentResponse'));
            if (String.isBlank(text)) {
                throw new AgentException('The agent returned no reply.');
            }
            Reply r = new Reply();
            r.text = text;
            r.sessionId = outputs.get('sessionId') == null ? null : String.valueOf(outputs.get('sessionId'));
            return r;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AccountBriefAgentClient.ask: ' + e.getTypeName() + ': ' + e.getMessage());
            return failure();
        }
    }

    /** The fixed failure reply. */
    public static Reply failure() {
        Reply r = new Reply();
        r.text = FAILURE_TEXT;
        r.failed = true;
        return r;
    }

    /** The message the agent receives: the user's text, then the open record when there is one. */
    @TestVisible
    private static String userMessage(String message, Id contextRecordId) {
        String text = message.trim();
        return contextRecordId == null ? text : text + '\n\nThe record I have open is ' + contextRecordId + '.';
    }

    /** The value of a {"type":"Text","value":"..."} envelope; a reply that is not one stays as it is. */
    @TestVisible
    private static String unwrap(Object raw) {
        if (raw == null) {
            return null;
        }
        String s = String.valueOf(raw);
        try {
            Object parsed = JSON.deserializeUntyped(s);
            if (parsed instanceof Map<String, Object>) {
                Object value = ((Map<String, Object>) parsed).get('value');
                return value == null ? null : String.valueOf(value);
            }
        } catch (JSONException e) {
            // Not JSON: the reply is the text itself.
            return s;
        }
        return s;
    }

    /** The real call: the generateAiAgentResponse action of Account_Brief. Not reachable from tests. */
    private class ActionTransport implements Transport {
        public Map<String, Object> send(String userMessage, String sessionId) {
            Invocable.Action action = Invocable.Action.createCustomAction(ACTION_NAME, AGENT_API_NAME);
            action.setInvocationParameter('userMessage', userMessage);
            if (sessionId != null) {
                action.setInvocationParameter('sessionId', sessionId);
            }
            Invocable.Action.Result result = action.invoke()[0];
            if (!result.isSuccess()) {
                throw new AgentException('generateAiAgentResponse failed: ' + result.getErrors().size() + ' error(s)');
            }
            return result.getOutputParameters();
        }
    }
}
