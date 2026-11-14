/**
 * CustomerSummaryActionDraftAction: draft_action, the first half of a write action for MCP or an agent (BE-27).
 * It drafts one action and writes nothing; commit_action (CustomerSummaryActionCommitAction) writes it once the user
 * confirms. Both go through CustomerSummaryActions, the service the panel uses, in user mode.
 *
 * Give either Text (the user's sentence, drafted through the model) or Action Type with Input JSON. The draft comes
 * back as JSON text to pass to commit_action unchanged, with its card (BE-39's actionDraft) as JSON next to it.
 *
 * OPS-59: this is the MCP door's draft_action tool. The door allows two actions only, create_task and log_call
 * (DOOR_ACTIONS). Any other action, named or drafted from words, comes back REFUSED with DOOR_REFUSED_TEXT, no draft
 * and no card. The panel does not come through here (it calls CustomerSummaryActions), so it keeps all six.
 */
public with sharing class CustomerSummaryActionDraftAction {
    /** The actions the door allows (Ben, OPS-59 Approvals row): create a task, log a call. */
    public static final Set<String> DOOR_ACTIONS = new Set<String>{ 'create_task', 'log_call' };
    /** The fixed refusal for any other action. */
    public static final String DOOR_REFUSED_TEXT = 'Only two actions are allowed here: create a task (create_task) and log a call (log_call). Nothing was drafted or saved.';

    /** @return true when the door allows the action */
    public static Boolean allowed(String action) {
        return action != null && DOOR_ACTIONS.contains(action);
    }

    public class Request {
        @InvocableVariable(label='Account Id' description='The account the action is for: the account the user has open.' required=true)
        public Id accountId;
        @InvocableVariable(label='Text' description='The user\'s request in their own words, such as "create a follow-up with Maria for next Tuesday". Give this, or Action Type and Input JSON.')
        public String text;
        @InvocableVariable(label='Action Type' description='create_task or log_call, the only two actions allowed here. Used when Text is empty.')
        public String actionType;
        @InvocableVariable(label='Input JSON' description='The action\'s fields as a JSON object, such as {"subject":"Send pricing","dueDate":"tomorrow","contact":"Maria"}. For an update, put the fields to change under "changes". Used with Action Type.')
        public String inputJson;
    }

    public class Response {
        @InvocableVariable(label='Status' description='READY: show the draft and ask the user to confirm. NEEDS_INPUT: ask the user for the fields marked needed or to choose. NOT_AN_ACTION: treat the text as a question. REFUSED or ERROR: tell the user the message.')
        public String status;
        @InvocableVariable(label='Draft JSON' description='The draft. Pass it unchanged to commit_action, and only after the user confirms it. Do not show it to the user.')
        public String draftJson;
        @InvocableVariable(label='Draft Text' description='The draft in plain words, to show the user before they confirm.')
        public String draftText;
        @InvocableVariable(label='Cards' description='The draft as an actionDraft card in JSON, for a client that can show cards. Record Ids appear only in its refs.')
        public String cards;
        @InvocableVariable(label='Message' description='Why the draft was refused or is not an action, in plain words. Empty otherwise.')
        public String message;
        @InvocableVariable(label='Is Success' description='True when a draft came back (READY or NEEDS_INPUT).')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message' description='The plain message when Is Success is false.')
        public String errorMessage;
    }

    @InvocableMethod(callout=true label='Draft Action' category='Customer Summary' description='Drafts one CRM write action for the open account, a task or a logged call, and writes nothing. Show the draft to the user; call Commit Action only after they confirm.')
    public static List<Response> draft(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests == null ? new List<Request>() : requests) {
            out.add(respond(req));
        }
        return out;
    }

    private static Response respond(Request req) {
        CustomerSummaryActions.Draft d;
        if (req == null) {
            d = CustomerSummaryActions.draftJson(null, null, null);
        } else if (String.isNotBlank(req.text) && String.isBlank(req.actionType)) {
            d = CustomerSummaryActions.draftFromText(req.accountId, req.text);
        } else if (String.isNotBlank(req.actionType) && !allowed(req.actionType.trim().toLowerCase())) {
            return refused();
        } else {
            d = CustomerSummaryActions.draftJson(req.actionType, req.accountId, req.inputJson);
        }
        // Words can draft any action, so the drafted action is checked too, not only the one named.
        if (d.action != null && d.status != CustomerSummaryActions.NOT_AN_ACTION && !allowed(d.action)) {
            return refused();
        }
        Response res = new Response();
        res.status = d.status;
        res.message = d.message;
        res.cards = AnswerCard.toJson(d.cards);
        res.draftText = d.cards.isEmpty() ? d.message : d.cards[0].text;
        res.isSuccess = d.status == CustomerSummaryActions.READY || d.status == CustomerSummaryActions.NEEDS_INPUT;
        res.errorMessage = res.isSuccess ? null : d.message;
        List<AnswerCard> cards = d.cards;
        d.cards = new List<AnswerCard>();
        res.draftJson = JSON.serialize(d);
        d.cards = cards;
        return res;
    }

    /** The door's fixed refusal: nothing drafted, no draft JSON, no card. */
    private static Response refused() {
        Response res = new Response();
        res.status = CustomerSummaryActions.REFUSED;
        res.message = DOOR_REFUSED_TEXT;
        res.draftText = DOOR_REFUSED_TEXT;
        res.cards = AnswerCard.toJson(new List<AnswerCard>());
        res.isSuccess = false;
        res.errorMessage = DOOR_REFUSED_TEXT;
        return res;
    }
}
