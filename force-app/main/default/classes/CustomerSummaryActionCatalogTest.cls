/**
 * CustomerSummaryActionCatalogTest: the six actions and the pre-check (BE-22's filler and verb lists, kept as they
 * ran). Each phrasing below was written fresh for BE-27 and is pinned to what the pre-check does with it today,
 * misses included, so a change to the lists shows up here.
 */
@IsTest
private class CustomerSummaryActionCatalogTest {
    /** Actions the pre-check sends on to the model. */
    private static final List<String> ACTIONS_CAUGHT = new List<String>{
        'Create a task to call Maria next Tuesday',
        'Add a follow-up for Friday',
        'Schedule a demo with Maria on Thursday at 3pm',
        'Book a meeting with the CFO next week',
        'Log a call with Maria, she wants a quote',
        'Remind me to send the contract tomorrow',
        'Update Maria\'s phone to 555 0100',
        'Change the close date on the Router deal to next month',
        'Open a case: the portal is down',
        'Push the renewal close date out two weeks',
        'Move the stage of the router deal to Negotiation',
        'Make a task to review the pricing',
        'Set the next step on the router deal to legal review',
        'Please create a follow-up for next Monday',
        'Can you log a call with Maria',
        'Could you schedule a call with Maria tomorrow at 10',
        'uh so remind me to ping Maria on Friday',
        'I need to log a call with Maria',
        'Okay, add a task to send the deck',
        'Hey, update the amount on the router deal to 50000',
        'Would you open a high priority case'
    };
    /** Actions the pre-check misses: each comes back NOT_AN_ACTION, so the caller treats it as a question. */
    private static final List<String> ACTIONS_MISSED = new List<String>{
        'Follow up with Maria next week',
        'Call Maria back tomorrow',
        'Just log a call with Maria',
        'Go ahead and create a case for the outage',
        'Note that Maria called about the invoice',
        'Mark the router deal as closed won',
        'New task: send Maria the pricing sheet',
        'File a case about the broken router',
        'I\'d like to schedule a meeting with Maria'
    };
    /** Questions the pre-check keeps away from the model. */
    private static final List<String> QUESTIONS_KEPT = new List<String>{
        'Which of their open deals close this quarter?',
        'What did Maria say on the last call?',
        'Show me open cases for this account',
        'How many tasks are overdue?',
        'Who is the main contact here?',
        'Is the router deal still open?',
        'Can you tell me when the renewal closes?',
        'Summarize the last three calls',
        'Any meetings booked with Maria next week?',
        'Do they have any escalated cases?',
        'Tell me about the renewal'
    };
    /** Questions that start with a verb: each costs one model call, which answers {"action":"none"}. */
    private static final List<String> QUESTIONS_SENT = new List<String>{
        'Open cases on this account?',
        'Update on the router deal?'
    };

    private class CountingStub implements AgentLlm.Provider {
        Integer calls = 0;
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            calls++;
            return '{"action":"none"}';
        }
    }

    private static void assertAll(List<String> phrasings, Boolean expected) {
        for (String p : phrasings) {
            Assert.areEqual(expected, CustomerSummaryActionCatalog.looksLikeAction(p), 'pre-check on: ' + p);
        }
    }

    @IsTest
    static void thePhrasingsArePinnedAndThereAreAtLeastThirty() {
        Integer total = ACTIONS_CAUGHT.size() + ACTIONS_MISSED.size() + QUESTIONS_KEPT.size() + QUESTIONS_SENT.size();
        Assert.isTrue(total >= 30, 'at least 30 phrasings: ' + total);
        assertAll(ACTIONS_CAUGHT, true);
        assertAll(ACTIONS_MISSED, false);
        assertAll(QUESTIONS_KEPT, false);
        assertAll(QUESTIONS_SENT, true);
    }

    @IsTest
    static void aPreCheckMissIsNotAnActionWithNoModelCall() {
        Account a = new Account(Name = 'Catalog Acme');
        insert a;
        CountingStub s = new CountingStub();
        AgentLlm.stub = s;
        List<String> misses = new List<String>(ACTIONS_MISSED);
        misses.addAll(QUESTIONS_KEPT);
        misses.add('');
        misses.add('   ');
        Test.startTest();
        for (String p : misses) {
            CustomerSummaryActions.Draft d = CustomerSummaryActions.draftFromText(a.Id, p);
            Assert.areEqual(CustomerSummaryActions.NOT_AN_ACTION, d.status, p);
            Assert.areEqual(0, d.cards.size(), 'not an action carries no card');
        }
        Test.stopTest();
        Assert.areEqual(0, s.calls, 'no model call for a pre-check miss');
    }

    @IsTest
    static void aVerbQuestionCostsOneCallAndComesBackNotAnAction() {
        Account a = new Account(Name = 'Catalog Acme');
        insert a;
        CountingStub s = new CountingStub();
        AgentLlm.stub = s;
        Test.startTest();
        for (String p : QUESTIONS_SENT) {
            Assert.areEqual(CustomerSummaryActions.NOT_AN_ACTION, CustomerSummaryActions.draftFromText(a.Id, p).status, p);
        }
        Test.stopTest();
        Assert.areEqual(QUESTIONS_SENT.size(), s.calls);
    }

    @IsTest
    static void firstWordSkipsFillerAndPunctuation() {
        Assert.areEqual('add', CustomerSummaryActionCatalog.firstWord('Okay, so, please add a task'));
        Assert.areEqual('add', CustomerSummaryActionCatalog.firstWord('Let’s add a task'), 'a curly apostrophe reads as a straight one');
        Assert.areEqual('', CustomerSummaryActionCatalog.firstWord('uh um so'));
        Assert.areEqual('', CustomerSummaryActionCatalog.firstWord(null));
    }

    @IsTest
    static void theSixActionsAndWhatTheyWrite() {
        List<CustomerSummaryActionCatalog.Spec> all = CustomerSummaryActionCatalog.all();
        Assert.areEqual(6, all.size());
        Assert.areEqual('Task', CustomerSummaryActionCatalog.find('log_call').objectName, 'F17: a logged call is a Task');
        Assert.areEqual(CustomerSummaryActions.LOG_CALL_AS, CustomerSummaryActionCatalog.find('LOG_CALL').objectName);
        Assert.isTrue(CustomerSummaryActionCatalog.find('update_contact').isUpdate());
        Assert.isFalse(CustomerSummaryActionCatalog.find('create_case').isUpdate());
        Assert.areEqual(new List<String>{ 'Title', 'Phone', 'MobilePhone', 'Email', 'Department' },
            CustomerSummaryActionCatalog.find('update_contact').allowed);
        Assert.areEqual(new List<String>{ 'StageName', 'CloseDate', 'NextStep', 'Amount' },
            CustomerSummaryActionCatalog.find('update_opportunity').allowed);
        Assert.isNull(CustomerSummaryActionCatalog.find('send_email'), 'no email drafting');
        Assert.isNull(CustomerSummaryActionCatalog.find(null));
    }
}
