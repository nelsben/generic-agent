@IsTest
private class ExploreActionTest {
    private class Script implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        Integer calls = 0;
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            if (calls >= replies.size()) {
                throw new AgentLlm.LlmException('model down');
            }
            return replies[calls++];
        }
    }

    private static void script(List<String> replies) {
        Script s = new Script();
        s.replies = replies;
        AgentLlm.stub = s;
    }

    private static ExploreAction.Request request(String question, Id contextRecordId) {
        ExploreAction.Request req = new ExploreAction.Request();
        req.question = question;
        req.contextRecordId = contextRecordId;
        return req;
    }

    @IsTest
    static void answerCarriesTheLastResultAsATable() {
        Account a = new Account(Name = 'Action Acme');
        insert a;
        insert new Opportunity(AccountId = a.Id, Name = 'Action Deal', StageName = 'Prospecting', Amount = 750, CloseDate = Date.today());
        script(new List<String>{
            '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Amount"]}}',
            '{"action":"answer","text":"One open deal.","followups":[]}'
        });

        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ request('Open deals?', a.Id) });

        Assert.areEqual(1, out.size());
        Assert.areEqual('OK', out[0].status);
        Assert.isTrue(out[0].answer.startsWith('One open deal.\n\nName | Amount\nAction Deal | 750'), out[0].answer);
    }

    @IsTest
    static void turnCapRelaysTheResultsWithANote() {
        Account a = new Account(Name = 'Action Cap Acme');
        insert a;
        insert new Opportunity(AccountId = a.Id, Name = 'Cap Deal', StageName = 'Prospecting', Amount = 900, CloseDate = Date.today());
        String q = '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Amount"]}}';
        script(new List<String>{ q, q, q, q, q });

        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ request('Keep looking', null) });

        Assert.areEqual('OK', out[0].status, out[0].answer);
        Assert.isTrue(out[0].answer.contains('ran out of steps'), out[0].answer);
        Assert.isTrue(out[0].answer.contains('\n\nName | Amount\nCap Deal | 900'), out[0].answer);
    }

    @IsTest
    static void modelFailureRelaysTheErrorText() {
        script(new List<String>());
        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ request('Anything?', null) });
        Assert.areEqual('ERROR', out[0].status);
        Assert.areEqual('I couldn\'t finish that right now. Try again in a minute.', out[0].answer);
    }

    @IsTest
    static void outputStaysUnderTheRelayCeiling() {
        ExploreQuery.ResultSet rs = new ExploreQuery.ResultSet();
        rs.columns = new List<String>{ 'Name', 'Note' };
        for (Integer i = 0; i < 200; i++) {
            rs.rows.add(new Map<String, Object>{ 'Name' => 'Row ' + i, 'Note' => 'x'.repeat(100) });
        }
        rs.shown = 200;
        rs.total = 450;
        DataExplorer.Result r = new DataExplorer.Result();
        r.status = 'OK';
        r.answer = 'Summary.';
        r.resultSets.add(rs);

        String text = ExploreAction.compose(r);
        Assert.isTrue(text.length() < 6000, String.valueOf(text.length()));
        Assert.isTrue(text.startsWith('Summary.\n\nName | Note\nRow 0 | ' + 'x'.repeat(37) + '...'));
        Assert.isTrue(text.endsWith(' of 450 rows)'), text.right(40));

        r.answer = 'y'.repeat(7000);
        String clipped = ExploreAction.compose(r);
        Assert.areEqual(ExploreAction.MAX_CHARS, clipped.length());
        Assert.isTrue(clipped.endsWith('...'));

        r.answer = 'z'.repeat(ExploreAction.MAX_CHARS - 20);
        Assert.areEqual(r.answer, ExploreAction.compose(r), 'no room for a row: text only');

        r.answer = 'No rows.';
        rs.rows.clear();
        Assert.areEqual('No rows.', ExploreAction.compose(r));
        r.resultSets.clear();
        Assert.areEqual('No rows.', ExploreAction.compose(r));
        r.answer = null;
        Assert.areEqual('', ExploreAction.compose(r));
    }

    @IsTest
    static void nullRequestsAreHandled() {
        Assert.isTrue(ExploreAction.explore(null).isEmpty());

        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ null });
        Assert.areEqual(1, out.size(), 'a null request still gets its own response');
        Assert.areEqual('EMPTY', out[0].status);
    }
}
