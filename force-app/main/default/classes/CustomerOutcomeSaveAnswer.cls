/**
 * The one outcome an agent or flow may write: a saved answer, kept when a rep asks to keep one. It never takes a
 * type or the sentiment fields; summaries and actions are recorded by the code that produced them.
 */
public with sharing class CustomerOutcomeSaveAnswer {
    @TestVisible private static final String NO_ANSWER_TEXT = 'There is no answer to save.';
    @TestVisible private static final String NOT_SAVED_TEXT = 'I couldn\'t save that answer. Check you can see the account.';

    public class Request {
        @InvocableVariable(label='Account Id' required=true description='18-character Id of the account the answer is about.')
        public Id accountId;
        @InvocableVariable(label='Title' description='A short name for the answer, such as the question it answers.')
        public String title;
        @InvocableVariable(label='Answer' required=true description='The answer to keep, as shown to the rep.')
        public String answer;
        @InvocableVariable(label='Skill' description='Optional: what produced the answer, such as explorer or summary.')
        public String skill;
    }

    public class Response {
        @InvocableVariable(label='Saved' description='True when the answer was saved.')
        public Boolean isSuccess = false;
        @InvocableVariable(label='Outcome Id' description='The saved outcome. Not for the user.')
        public Id outcomeId;
        @InvocableVariable(label='Error Message' description='Why the answer was not saved. Relay it verbatim.')
        public String errorMessage;
        @InvocableVariable(label='Error Type' description='The exception type behind a failure. Not for the user.')
        public String errorType;
    }

    @InvocableMethod(
        label='Save Answer'
        description='Saves an answer to the account so the rep can find it again. Use only when the rep asks to keep or save an answer.'
    )
    public static List<Response> save(List<Request> requests) {
        List<Response> out = new List<Response>();
        List<CustomerOutcomes.Input> inputs = new List<CustomerOutcomes.Input>();
        List<Response> pending = new List<Response>();
        for (Request req : requests == null ? new List<Request>() : requests) {
            Response resp = new Response();
            out.add(resp);
            if (req == null || req.accountId == null || String.isBlank(req.answer)) {
                resp.errorMessage = NO_ANSWER_TEXT;
                continue;
            }
            CustomerOutcomes.Input i = new CustomerOutcomes.Input(req.accountId, CustomerOutcomes.SAVED_ANSWER);
            i.title = String.isBlank(req.title) ? null : req.title.trim();
            i.body = req.answer.trim();
            i.skill = String.isBlank(req.skill) ? 'saved_answer' : req.skill.trim();
            inputs.add(i);
            pending.add(resp);
        }
        if (inputs.isEmpty()) {
            return out;
        }
        try {
            List<Id> ids = CustomerOutcomes.recordAll(inputs);
            for (Integer n = 0; n < ids.size(); n++) {
                pending[n].isSuccess = true;
                pending[n].outcomeId = ids[n];
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerOutcomeSaveAnswer failed: ' + e.getTypeName() + ': ' + e.getMessage());
            for (Response resp : pending) {
                resp.errorMessage = NOT_SAVED_TEXT;
                resp.errorType = e.getTypeName();
            }
        }
        return out;
    }
}
