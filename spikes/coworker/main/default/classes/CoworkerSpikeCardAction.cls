/**
 * FE-24 spike only: the one action of the spike agent Customer_Summary_Coworker_Spike.
 *
 * It resolves the account the user named and builds its summary with the product's own classes
 * (CustomerSummaryResolver, then CustomerSummaryGetAction), unchanged. It returns the summary's cards
 * JSON as BE-39 builds it (`cards`), and the summary card itself as the Apex class behind the spike
 * Lightning type coworkerSpikeSummaryCard (`card`), which the agent's output ties to the type.
 *
 * When the name does not resolve to one account, `card` is a notice with a fixed text. The resolver's
 * AMBIGUOUS message lists candidates with their Ids (BE-39 page, "Open: Ids in the AMBIGUOUS message"),
 * so it is not put on the card.
 */
public with sharing class CoworkerSpikeCardAction {
    public static final String AMBIGUOUS_TEXT = 'Several accounts match that name. Ask again with the full account name and the words card spike.';
    public static final String NOT_FOUND_TEXT = 'No account matches that name. Ask again with the full account name and the words card spike.';
    public static final String ERROR_TEXT = 'The summary card could not be built. Please try again in a moment.';

    public class Request {
        @InvocableVariable(label='Account Name' required=true description='The account name as the user wrote it, without the rest of the request.')
        public String accountName;
    }

    public class Response {
        @InvocableVariable(label='Status' description='OK, EMPTY, AMBIGUOUS, NOT_FOUND or ERROR.')
        public String status;
        @InvocableVariable(label='Answer' description='The summary as text, or the message for a non-OK status.')
        public String answer;
        @InvocableVariable(label='Card' description='The summary card of the FR2 card contract, drawn by the spike Lightning type coworkerSpikeSummaryCard.')
        public CoworkerSpikeSummaryCard card;
        @InvocableVariable(label='Cards' description='All of the summary\'s cards as BE-39 JSON. Record Ids appear only in each card\'s refs. Not for the user.')
        public String cards;
    }

    @InvocableMethod(
        callout=true
        label='Coworker Spike: Summary Card'
        description='FE-24 spike only. Resolves one account by name and returns its summary as a card for the coworkerSpikeSummaryCard Lightning type.'
    )
    public static List<Response> getCards(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null) {
            return out;
        }
        for (Request req : requests) {
            out.add(run(req == null ? null : req.accountName));
        }
        return out;
    }

    public static Response run(String accountName) {
        Response res = new Response();
        CustomerSummaryResolver.Response resolved = CustomerSummaryResolver.resolve(accountName, null);
        if (resolved == null || resolved.status != CustomerSummaryResolver.RESOLVED) {
            String status = resolved == null ? CustomerSummaryResolver.ERROR : resolved.status;
            res.status = status;
            res.answer = textFor(status);
            res.cards = '[]';
            res.card = CoworkerSpikeSummaryCard.notice(status, res.answer);
            return res;
        }
        CustomerSummaryGetAction.Request ask = new CustomerSummaryGetAction.Request();
        ask.accountId = resolved.accountId;
        List<CustomerSummaryGetAction.Response> briefs = CustomerSummaryGetAction.getBriefs(
            new List<CustomerSummaryGetAction.Request>{ ask }
        );
        CustomerSummaryGetAction.Response brief = briefs.isEmpty() ? null : briefs[0];
        if (brief == null) {
            res.status = CustomerSummaryResolver.ERROR;
            res.answer = ERROR_TEXT;
            res.cards = '[]';
            res.card = CoworkerSpikeSummaryCard.notice(res.status, ERROR_TEXT);
            return res;
        }
        res.status = brief.status;
        res.answer = brief.answer;
        res.cards = brief.cards;
        res.card = CoworkerSpikeSummaryCard.firstOf(brief.cards, 'summary');
        if (res.card == null) {
            // EMPTY, NOT_FOUND or ERROR give no summary card; the summary's own text is Id-free.
            res.card = CoworkerSpikeSummaryCard.notice(brief.status, brief.answer);
        }
        return res;
    }

    private static String textFor(String status) {
        if (status == CustomerSummaryResolver.AMBIGUOUS) {
            return AMBIGUOUS_TEXT;
        }
        if (status == CustomerSummaryResolver.NOT_FOUND) {
            return NOT_FOUND_TEXT;
        }
        return ERROR_TEXT;
    }
}
