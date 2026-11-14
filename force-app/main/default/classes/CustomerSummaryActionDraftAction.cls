/**
 * CustomerSummaryActionDraftAction: draft_action, the first half of a write action for MCP or an agent (BE-27).
 * It drafts one action and writes nothing; commit_action (CustomerSummaryActionCommitAction) writes it once the user
 * confirms. Both go through CustomerSummaryActions, the service the panel uses, in user mode.
 *
 * Give either Text (the user's sentence, drafted through the model) or Action Type with Input JSON. The draft comes
 * back as JSON text to pass to commit_action unchanged, with its card (BE-39's actionDraft) as JSON next to it.
 * No MCP tool exposes this in FR2 without Ben's go; it is ready for one.
 */
public with sharing class CustomerSummaryActionDraftAction {
    public class Request {
        @InvocableVariable(label='Account Id' description='The account the action is for: the account the user has open.' required=true)
        public Id accountId;
        @InvocableVariable(label='Text' description='The user\'s request in their own words, such as "create a follow-up with Maria for next Tuesday". Give this, or Action Type and Input JSON.')
        public String text;
        @InvocableVariable(label='Action Type' description='One of create_task, create_event, log_call, update_contact, create_case, update_opportunity. Used when Text is empty.')
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

    @InvocableMethod(callout=true label='Draft Action' category='Customer Summary' description='Drafts one CRM write action for the open account (a task, an event, a logged call, a contact update, a case or an opportunity update) and writes nothing. Show the draft to the user; call Commit Action only after they confirm.')
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
        } else {
            d = CustomerSummaryActions.draftJson(req.actionType, req.accountId, req.inputJson);
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
}
