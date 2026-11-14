@IsTest
private class CustomerSentimentTest {
    private static final List<String> EVIDENCE = new List<String>{ 'open_deals', 'cases', 'activity', 'calls', 'deal_history' };

    /** A scripted model: returns reply, or throws when fail is set. Records every prompt. Never reaches a model. */
    private class Scripted implements AgentLlm.Provider {
        String reply;
        Boolean fail = false;
        List<String> systems = new List<String>();
        List<String> users = new List<String>();

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            systems.add(systemPrompt);
            users.add(userPrompt);
            if (fail) {
                throw new AgentLlm.LlmException('model down');
            }
            return reply;
        }
    }

    private static Scripted script(String reply) {
        Scripted s = new Scripted();
        s.reply = reply;
        AgentLlm.stub = s;
        return s;
    }

    private static String json(Object score, String label, String reason) {
        return JSON.serialize(new Map<String, Object>{ 'score' => score, 'label' => label, 'reason' => reason });
    }

    private static CustomerSummarySection section(String key, String status, String body) {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = key;
        s.title = key;
        s.status = status;
        s.body = body;
        return s;
    }

    /** Every evidence section with the given status, plus a profile. */
    private static Map<String, CustomerSummarySection> built(String status) {
        Map<String, CustomerSummarySection> out = new Map<String, CustomerSummarySection>{
            'profile' => section('profile', CustomerSummarySection.OK, 'Name: Sentiment Co')
        };
        for (String key : EVIDENCE) {
            out.put(key, section(key, status, status == CustomerSummarySection.OK ? key + ' facts' : 'none'));
        }
        return out;
    }

    private static Map<String, String> reduced() {
        return new Map<String, String>{
            'profile' => 'Name: Sentiment Co',
            'open_deals' => '2 open, $10,000 total pipeline, 1 overdue',
            'cases' => '1 open (1 high priority)\n- 00001001 — Outage — High — Escalated — open 4 days',
            'engagement_summary' => 'Two calls last week.',
            'deal_history_summary' => 'Won one deal last month.'
        };
    }

    // ---------------------------------------------------------------- parse: each score

    @IsTest
    static void minusTwoParsesAsAtRisk() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(-2, 'At risk', 'Two escalated cases and a slipped renewal.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(-2, r.score.intValue());
        Assert.areEqual('At risk', r.label);
        Assert.areEqual('Two escalated cases and a slipped renewal.', r.reason);
    }

    @IsTest
    static void minusOneParsesAsConcerned() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(-1, 'Concerned', 'One overdue deal and an open high-priority case.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(-1, r.score.intValue());
        Assert.areEqual('Concerned', r.label);
    }

    @IsTest
    static void zeroParsesAsNeutral() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(0, 'Neutral', 'A recent win offset by an overdue deal.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(0, r.score.intValue());
        Assert.areEqual('Neutral', r.label);
    }

    @IsTest
    static void plusOneParsesAsPositive() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(1, 'Positive', 'A deal won last month and no open cases.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(1, r.score.intValue());
        Assert.areEqual('Positive', r.label);
    }

    @IsTest
    static void plusTwoParsesAsVeryPositive() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(2, 'Very positive', 'Two recent wins and weekly calls.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(2, r.score.intValue());
        Assert.areEqual('Very positive', r.label);
    }

    @IsTest
    static void theLabelIsMatchedIgnoringCaseAndStoredAsTheTableSaysIt() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(1, ' positive ', 'A recent win.'));
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual('Positive', r.label);
    }

    @IsTest
    static void oneCodeFenceAroundTheObjectIsAccepted() {
        CustomerSentiment.Reading r = CustomerSentiment.parse('```json\n' + json(-1, 'Concerned', 'An overdue deal.') + '\n```');
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(-1, r.score.intValue());
    }

    @IsTest
    static void everyScoreHasOneLabel() {
        Assert.areEqual('At risk', CustomerSentiment.labelFor(-2));
        Assert.areEqual('Concerned', CustomerSentiment.labelFor(-1));
        Assert.areEqual('Neutral', CustomerSentiment.labelFor(0));
        Assert.areEqual('Positive', CustomerSentiment.labelFor(1));
        Assert.areEqual('Very positive', CustomerSentiment.labelFor(2));
        Assert.isNull(CustomerSentiment.labelFor(3));
        Assert.isNull(CustomerSentiment.labelFor(null));
    }

    // ---------------------------------------------------------------- sparse data

    @IsTest
    static void theModelsNotEnoughActivityHasNoScore() {
        CustomerSentiment.Reading r = CustomerSentiment.parse(json(null, 'Not enough activity', 'Only one open deal and nothing else on record.'));
        Assert.areEqual(CustomerSentiment.SPARSE, r.status);
        Assert.isNull(r.score, 'never a guess');
        Assert.areEqual(CustomerSentiment.NOT_ENOUGH, r.label);
        Assert.areEqual('Only one open deal and nothing else on record.', r.reason);
    }

    @IsTest
    static void aScoreWithTheNotEnoughLabelIsMalformed() {
        assertMalformed(json(0, 'Not enough activity', 'Little on record.'));
    }

    @IsTest
    static void noEvidenceOnRecordIsNotEnoughActivityWithNoModelCall() {
        Scripted s = script(json(2, 'Very positive', 'Should never be asked.'));
        CustomerSentiment.Reading r = CustomerSentiment.forBrief(built(CustomerSummarySection.EMPTY), reduced());
        Assert.areEqual(CustomerSentiment.SPARSE, r.status);
        Assert.isNull(r.score);
        Assert.areEqual(CustomerSentiment.NOT_ENOUGH, r.label);
        Assert.areEqual(CustomerSentiment.NO_EVIDENCE_REASON, r.reason);
        Assert.areEqual(0, s.systems.size(), 'no model call when nothing is on record');
    }

    @IsTest
    static void aPartialSummaryIsNotScored() {
        Scripted s = script(json(1, 'Positive', 'Should never be asked.'));
        Map<String, CustomerSummarySection> partial = built(CustomerSummarySection.OK);
        partial.remove('cases');
        CustomerSentiment.Reading r = CustomerSentiment.forBrief(partial, reduced());
        Assert.areEqual(CustomerSentiment.NONE, r.status);
        Assert.isNull(r.score);
        Assert.isNull(r.label);
        Assert.isNull(r.reason);
        Assert.areEqual(0, s.systems.size(), 'a summary that left out evidence is not a sentiment reading');
    }

    @IsTest
    static void aFailedEvidenceSectionIsNotScored() {
        Scripted s = script(json(1, 'Positive', 'Should never be asked.'));
        Map<String, CustomerSummarySection> withError = built(CustomerSummarySection.OK);
        withError.put('cases', section('cases', CustomerSummarySection.ERROR, 'could not load'));
        CustomerSentiment.Reading r = CustomerSentiment.forBrief(withError, reduced());
        Assert.areEqual(CustomerSentiment.NONE, r.status);
        Assert.isNull(r.label);
        Assert.areEqual(0, s.systems.size(), 'a part that did not load is never read as calm');
    }

    // ---------------------------------------------------------------- the model call

    @IsTest
    static void aFullSummaryIsScoredFromItsReducedSectionsInOneCall() {
        Scripted s = script(json(-1, 'Concerned', 'One escalated case and an overdue deal.'));
        Test.startTest();
        CustomerSentiment.Reading r = CustomerSentiment.forBrief(built(CustomerSummarySection.OK), reduced());
        Test.stopTest();

        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.areEqual(-1, r.score.intValue());
        Assert.areEqual('Concerned', r.label);
        Assert.areEqual('One escalated case and an overdue deal.', r.reason);
        Assert.areEqual(1, s.systems.size(), 'one focused call');
        Assert.isTrue(s.systems[0].contains('customer sentiment'), 'the sentiment prompt file: ' + s.systems[0].left(200));
        String user = s.users[0];
        Assert.isTrue(user.contains('Today: ' + Datetime.now().format('yyyy-MM-dd')), user.left(200));
        Assert.isTrue(user.contains('Open deals:\n2 open, $10,000 total pipeline, 1 overdue'), user);
        Assert.isTrue(user.contains('Escalated'), user);
        Assert.isTrue(user.contains('Engagement summary:\nTwo calls last week.'), user);
        Assert.isTrue(user.contains('Deal history summary:\nWon one deal last month.'), user);
        Assert.isFalse(user.contains('Name: Sentiment Co'), 'the profile is not evidence');
        Assert.isFalse(user.contains('{{'), 'every placeholder is filled');
    }

    @IsTest
    static void aMissingReducedValueIsSentAsNotRequested() {
        Scripted s = script(json(0, 'Neutral', 'Mixed signals.'));
        Map<String, String> partial = reduced();
        partial.remove('deal_history_summary');
        CustomerSentiment.Reading r = CustomerSentiment.score(partial);
        Assert.areEqual(CustomerSentiment.SCORED, r.status);
        Assert.isTrue(s.users[0].contains('Deal history summary:\nEMPTY: not requested'), s.users[0]);
    }

    @IsTest
    static void theSentimentPromptHasItsOwnSettingAndASparseRule() {
        AgentLlm.settingsForTest = null;
        AgentLlm.useOrgSettings = true;
        AgentLlm.Setting setting = AgentLlm.setting(CustomerSentiment.PROMPT);
        Assert.isTrue(setting.found, 'a setting record ships for the sentiment prompt');
        Assert.areEqual(CustomerSentiment.MAX_TOKENS, setting.maxTokens);
        Assert.areEqual(AgentLlmModelsApi.MODEL, setting.model);
        Assert.isFalse(setting.trace, 'ships with the trace off');
        Assert.isFalse(setting.isTemplate(), 'the prompt file is the source');

        String raw = AgentLlm.loadPrompt(CustomerSentiment.PROMPT);
        Assert.isTrue(raw.contains(CustomerSentiment.NOT_ENOUGH), 'the prompt names the sparse answer');
        for (Integer score = -2; score <= 2; score++) {
            Assert.isTrue(raw.contains('"' + CustomerSentiment.labelFor(score) + '"'), 'the prompt lists the label for ' + score);
        }
        for (String marker : new List<String>{ 'engagement data', 'deal history for one account', 'final account summary' }) {
            Assert.isFalse(raw.contains(marker), 'the other prompts\' markers stay theirs: ' + marker);
        }
    }

    // ---------------------------------------------------------------- malformed output and failure

    private static void assertMalformed(String reply) {
        CustomerSentiment.Reading r = CustomerSentiment.parse(reply);
        String shown = 'malformed: ' + String.valueOf(reply);
        Assert.areEqual(CustomerSentiment.NONE, r.status, shown);
        Assert.isNull(r.score, shown);
        Assert.isNull(r.label, shown);
        Assert.isNull(r.reason, shown);
    }

    @IsTest
    static void proseIsMalformed() {
        assertMalformed('The customer seems happy overall.');
    }

    @IsTest
    static void textAroundTheObjectIsMalformed() {
        assertMalformed('Here is the score: ' + json(1, 'Positive', 'A recent win.'));
    }

    @IsTest
    static void aBlankReplyIsMalformed() {
        assertMalformed('  ');
    }

    @IsTest
    static void aNullReplyIsMalformed() {
        assertMalformed(null);
    }

    @IsTest
    static void aJsonArrayIsMalformed() {
        assertMalformed('[' + json(1, 'Positive', 'A recent win.') + ']');
    }

    @IsTest
    static void aScoreOutOfRangeIsMalformed() {
        assertMalformed(json(3, 'Very positive', 'Everything is great.'));
    }

    @IsTest
    static void aFractionalScoreIsMalformed() {
        assertMalformed('{"score": 1.5, "label": "Positive", "reason": "A recent win."}');
    }

    @IsTest
    static void aScoreAsTextIsMalformed() {
        assertMalformed(json('1', 'Positive', 'A recent win.'));
    }

    @IsTest
    static void aLabelThatDisagreesWithTheScoreIsMalformed() {
        assertMalformed(json(-2, 'Positive', 'Two escalated cases.'));
    }

    @IsTest
    static void aMissingReasonIsMalformed() {
        assertMalformed('{"score": 1, "label": "Positive"}');
    }

    @IsTest
    static void aBlankReasonIsMalformed() {
        assertMalformed(json(1, 'Positive', ' '));
    }

    @IsTest
    static void aReasonOverTwoLinesIsMalformed() {
        assertMalformed(json(1, 'Positive', 'A recent win.\nAnd weekly calls.'));
    }

    @IsTest
    static void aReasonPastTheFieldLengthIsMalformed() {
        assertMalformed(json(1, 'Positive', 'A'.repeat(CustomerSentiment.MAX_REASON_CHARS + 1)));
    }

    @IsTest
    static void anExtraKeyIsMalformed() {
        assertMalformed('{"score": 1, "label": "Positive", "reason": "A recent win.", "confidence": 0.9}');
    }

    @IsTest
    static void aModelReplyThatIsMalformedIsStoredAsNoScore() {
        script('Sentiment: positive.');
        CustomerSentiment.Reading r = CustomerSentiment.score(reduced());
        Assert.areEqual(CustomerSentiment.NONE, r.status);
        Assert.isNull(r.score);
        Assert.isNull(r.label);
    }

    @IsTest
    static void aModelFailureIsNoScoreAndNeverThrows() {
        Scripted s = script(null);
        s.fail = true;
        CustomerSentiment.Reading r = CustomerSentiment.forBrief(built(CustomerSummarySection.OK), reduced());
        Assert.areEqual(1, s.systems.size(), 'the call was made');
        Assert.areEqual(CustomerSentiment.NONE, r.status);
        Assert.isNull(r.score);
        Assert.isNull(r.label);
        Assert.isNull(r.reason);
    }

    @IsTest
    static void anEmptyModelReplyIsNoScore() {
        script('');
        CustomerSentiment.Reading r = CustomerSentiment.score(reduced());
        Assert.areEqual(CustomerSentiment.NONE, r.status, 'AgentLlm refuses an empty reply; that is a failure, not a score');
    }

    @IsTest
    static void aNullInputIsNotScored() {
        Scripted s = script(json(1, 'Positive', 'A recent win.'));
        Assert.areEqual(CustomerSentiment.NONE, CustomerSentiment.forBrief(null, reduced()).status);
        Assert.areEqual(CustomerSentiment.NONE, CustomerSentiment.forBrief(built(CustomerSummarySection.OK), null).status);
        Assert.areEqual(0, s.systems.size());
    }
}
