/**
 * FE-24 spike only. Tests for CoworkerSpikeCardAction and the spike card classes. No test reaches a
 * model: AgentLlm.stub answers every call. Written with the spike and not yet run in an org (FE-24 ran
 * no deploy); a validate with RunLocalTests runs it.
 */
@IsTest
private class CoworkerSpikeCardActionTest {
    private class Stub implements AgentLlm.Provider {
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (systemPrompt.contains('score customer sentiment')) {
                return '{"score": 1, "label": "Positive", "reason": "A deal won 20 days ago."}';
            }
            return 'Spike Account: steady\n**Open deals:** one won.';
        }
    }

    private static Account mkAccount() {
        Account a = new Account(Name = 'Coworker Spike Card ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
        insert a;
        insert new Opportunity(AccountId = a.Id, Name = 'Won deal', StageName = 'Closed Won', Amount = 5000, CloseDate = Date.today().addDays(-20));
        return a;
    }

    @IsTest
    static void aResolvedAccountGivesItsSummaryCard() {
        Account a = mkAccount();
        AgentLlm.stub = new Stub();
        CoworkerSpikeCardAction.Request req = new CoworkerSpikeCardAction.Request();
        req.accountName = a.Name;

        Test.startTest();
        List<CoworkerSpikeCardAction.Response> out = CoworkerSpikeCardAction.getCards(new List<CoworkerSpikeCardAction.Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, out.size());
        Assert.areEqual('OK', out[0].status, out[0].answer);
        Assert.isNotNull(out[0].card, 'a summary card');
        Assert.areEqual('summary', out[0].card.type);
        Assert.areEqual(1, out[0].card.version);
        Assert.areEqual('sum', out[0].card.key);
        Assert.areEqual('Spike Account: steady', out[0].card.title);
        Assert.isFalse(out[0].card.text.contains(String.valueOf(a.Id)), 'no Id in the card text');
        Assert.isTrue(out[0].cards.startsWith('['), 'the summary cards JSON travels too');
    }

    @IsTest
    static void anUnknownNameGivesAFixedNotice() {
        AgentLlm.stub = new Stub();
        CoworkerSpikeCardAction.Response res = CoworkerSpikeCardAction.run('No Such Account Anywhere 9f2c');
        Assert.areEqual(CustomerSummaryResolver.NOT_FOUND, res.status);
        Assert.areEqual('notice', res.card.type);
        Assert.areEqual(CoworkerSpikeCardAction.NOT_FOUND_TEXT, res.card.text);
        Assert.areEqual(1, res.card.body.size());
        Assert.areEqual('[]', res.cards);
    }

    @IsTest
    static void nullRequestsGiveNothing() {
        Assert.isTrue(CoworkerSpikeCardAction.getCards(null).isEmpty());
    }

    @IsTest
    static void firstOfReadsBe39JsonAndIgnoresOtherMembers() {
        String cardsJson = '[{"type":"section","version":1,"key":"sec-deals","title":"Open deals","text":"Open deals","total":3,"shown":3,"items":[],"body":[],"refs":[]},'
            + '{"type":"summary","version":1,"key":"sum","title":"Edge","meta":"Account summary","status":"OK","text":"Edge\\nOpen deals: 3",'
            + '"body":[{"kind":"p","runs":[{"text":"Open deals:","strong":true},{"text":" 3"}]}],"refs":[]}]';
        CoworkerSpikeSummaryCard c = CoworkerSpikeSummaryCard.firstOf(cardsJson, 'summary');
        Assert.areEqual('sum', c.key);
        Assert.areEqual('Account summary', c.meta);
        Assert.areEqual(2, c.body[0].runs.size());
        Assert.isTrue(c.body[0].runs[0].strong);
        Assert.isNull(CoworkerSpikeSummaryCard.firstOf('not json', 'summary'));
        Assert.isNull(CoworkerSpikeSummaryCard.firstOf('', 'summary'));
        Assert.isNull(CoworkerSpikeSummaryCard.firstOf('[]', 'summary'));
    }
}
