/**
 * BE-56 spike: the custom UI's door to the agent through the invocable action generateAiAgentResponse.
 *
 * The caller (an LWC, or anonymous Apex) holds the session Id. sendMessage returns it after turn 1 and takes it
 * back for turn 2, so both turns land in one agent session. The invocable has no end-session call, so
 * endSession releases the session on our side only (see the research page, Undo).
 */
public with sharing class AgentDoorController {
    public static final String AGENT_API_NAME = 'Customer_Summary';

    /** The seam an Apex test replaces: the platform cannot run the agent invocable inside a test. */
    public interface AgentGateway {
        Map<String, Object> send(String agentApiName, String userMessage, String sessionId);
    }

    public class InvocableGateway implements AgentGateway {
        public Map<String, Object> send(String agentApiName, String userMessage, String sessionId) {
            Invocable.Action act = Invocable.Action.createCustomAction('generateAiAgentResponse', agentApiName);
            act.setInvocationParameter('userMessage', userMessage);
            if (String.isNotBlank(sessionId)) {
                act.setInvocationParameter('sessionId', sessionId);
            }
            List<Invocable.Action.Result> results = act.invoke();
            if (results.isEmpty() || !results[0].isSuccess()) {
                String why = results.isEmpty() ? 'no result' : String.join(results[0].getErrors(), ' | ');
                throw new AuraHandledException('The agent did not answer: ' + why);
            }
            return results[0].getOutputParameters();
        }
    }

    @TestVisible
    private static AgentGateway gateway = new InvocableGateway();

    public class TurnResult {
        @AuraEnabled public String reply;
        @AuraEnabled public String sessionId;
        @AuraEnabled public Integer seconds;
        @AuraEnabled public Integer replyLength;
    }

    public class EndResult {
        @AuraEnabled public Boolean released;
        @AuraEnabled public Boolean endedOnPlatform;
        @AuraEnabled public String note;
    }

    /**
     * One turn. Pass a blank sessionId on turn 1 and the returned sessionId on turn 2. With an accountId, the
     * account name (read in user mode) is added to the first turn so the agent knows which account is meant.
     */
    @AuraEnabled
    public static TurnResult sendMessage(String message, String sessionId, Id accountId) {
        if (String.isBlank(message)) {
            throw new AuraHandledException('Type a message first.');
        }
        String text = message.trim();
        if (String.isBlank(sessionId) && accountId != null) {
            List<Account> accounts = [SELECT Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
            if (!accounts.isEmpty() && !text.containsIgnoreCase(accounts[0].Name)) {
                text += ' (account: ' + accounts[0].Name + ')';
            }
        }
        Long started = System.now().getTime();
        Map<String, Object> out = gateway.send(AGENT_API_NAME, text, sessionId);
        TurnResult r = new TurnResult();
        r.seconds = Integer.valueOf((System.now().getTime() - started) / 1000);
        r.reply = replyText(out.get('agentResponse'));
        r.replyLength = r.reply.length();
        r.sessionId = out.get('sessionId') == null ? sessionId : String.valueOf(out.get('sessionId'));
        return r;
    }

    /**
     * The invocable offers no end call (checked in connect-24h: no standard or custom action ends a session),
     * and the Agent API end call needs an External Client App token. So this releases the session here and says
     * so: the platform ends it on its own timer.
     */
    @AuraEnabled
    public static EndResult endSession(String sessionId) {
        EndResult r = new EndResult();
        r.released = String.isNotBlank(sessionId);
        r.endedOnPlatform = false;
        r.note = 'Released here. No in-org call ends an agent session; the platform expires it.';
        return r;
    }

    /** The reply is a JSON envelope {"type":"Text","value":"..."}; fall back to the raw string. */
    @TestVisible
    private static String replyText(Object raw) {
        String s = raw == null ? '' : String.valueOf(raw);
        try {
            Object parsed = JSON.deserializeUntyped(s);
            if (parsed instanceof Map<String, Object>) {
                Object v = ((Map<String, Object>) parsed).get('value');
                if (v != null) {
                    return String.valueOf(v);
                }
            }
        } catch (Exception e) {
            // Not JSON: the raw string is the reply.
        }
        return s;
    }
}
