/**
 * AccountBriefGetAction: the Get Account Brief action. Stage two of the gate (resolve, then brief):
 * call it only with an Account Id that AccountBriefResolver returned as RESOLVED.
 * A thin adapter over AccountBrief.run(); all behavior lives there.
 */
public with sharing class AccountBriefGetAction {
    public class Request {
        @InvocableVariable(label='Account Id' required=true description='18-character Id of the resolved account.')
        public String accountId;
        @InvocableVariable(label='User Question' description='The user\'s question, copied as asked. Blank for a general brief.')
        public String userQuestion;
        @InvocableVariable(label='Include' description='Optional comma-separated section keys; blank means all. Valid keys: profile, open_deals, cases, contacts, activity, calls, deal_history.')
        public String include;
    }

    public class Response {
        @InvocableVariable(label='Status' description='OK, EMPTY, NOT_FOUND or ERROR')
        public String status;
        @InvocableVariable(label='Answer' description='The brief, or the message for a non-OK status. Relay it verbatim.')
        public String answer;
    }

    @InvocableMethod(
        label='Get Account Brief'
        description='Builds the account brief for one resolved account: gathers the requested sections and writes the brief. Relay the answer verbatim.'
    )
    public static List<Response> getBriefs(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null) {
            return out;
        }
        for (Request req : requests) {
            AccountBrief.Result r = req == null
                ? AccountBrief.run(null, null, null)
                : AccountBrief.run(toId(req.accountId), req.userQuestion, parseInclude(req.include));
            Response resp = new Response();
            resp.status = r.status;
            resp.answer = r.answer;
            out.add(resp);
        }
        return out;
    }

    /** Comma-separated keys to a set of trimmed, non-blank keys. Blank input gives an empty set (all). */
    @TestVisible
    private static Set<String> parseInclude(String raw) {
        Set<String> keys = new Set<String>();
        if (String.isBlank(raw)) {
            return keys;
        }
        for (String part : raw.split(',')) {
            if (String.isNotBlank(part)) {
                keys.add(part.trim());
            }
        }
        return keys;
    }

    private static Id toId(String raw) {
        try {
            return String.isBlank(raw) ? null : Id.valueOf(raw.trim());
        } catch (Exception e) {
            return null;
        }
    }
}
