/**
 * CustomerSummaryActionCommitAction: commit_action, the second half of a write action for MCP or an agent (BE-27).
 * It writes the draft draft_action returned, as the user, and only once the user has confirmed it. The service
 * rebuilds and checks the draft again before it writes, so a changed draft writes nothing it would not show.
 * It never calls a model, so its write never meets a callout. The result card (BE-39's actionResult) comes back as
 * JSON next to the other outputs.
 */
public with sharing class CustomerSummaryActionCommitAction {
    public class Request {
        @InvocableVariable(label='Draft JSON' description='The Draft JSON output of Draft Action, unchanged. Send it only after the user has confirmed the draft.' required=true)
        public String draftJson;
    }

    public class Response {
        @InvocableVariable(label='Status' description='OK: saved. REFUSED: not saved because of the user\'s access or a draft that still needs input. ERROR: not saved; try again later.')
        public String status;
        @InvocableVariable(label='Record Id' description='The record created or changed. Empty when nothing was saved.')
        public Id recordId;
        @InvocableVariable(label='Label' description='The record\'s name or subject.')
        public String label;
        @InvocableVariable(label='Link Path' description='The record\'s page as a path in this org, such as /lightning/r/Task/<id>/view.')
        public String linkPath;
        @InvocableVariable(label='Undo Token' description='For an update only: lets the change be undone within 15 seconds from the panel. Do not show it to the user.')
        public String undoToken;
        @InvocableVariable(label='Message' description='What happened, in plain words. Relay it to the user.')
        public String message;
        @InvocableVariable(label='Cards' description='The result as an actionResult card in JSON, for a client that can show cards. Record Ids appear only in its refs.')
        public String cards;
        @InvocableVariable(label='Is Success' description='True when the record was saved.')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message' description='The plain message when Is Success is false.')
        public String errorMessage;
    }

    @InvocableMethod(label='Commit Action' category='Customer Summary' description='Saves a drafted CRM action as the user, after the user has confirmed the draft from Draft Action. Never call it without that confirmation.')
    public static List<Response> commitDrafts(List<Request> requests) {
        List<Response> out = new List<Response>();
        // One confirmed draft per request; each is its own all-or-nothing write in user mode.
        for (Request req : requests == null ? new List<Request>() : requests) {
            CustomerSummaryActions.Result r = CustomerSummaryActions.commitJson(req == null ? null : req.draftJson);
            Response res = new Response();
            res.status = r.status;
            res.recordId = r.recordId;
            res.label = r.label;
            res.linkPath = r.linkPath;
            res.undoToken = r.undoToken;
            res.message = r.message;
            res.cards = AnswerCard.toJson(r.cards);
            res.isSuccess = r.status == CustomerSummaryActions.OK;
            res.errorMessage = res.isSuccess ? null : r.message;
            out.add(res);
        }
        return out;
    }
}
