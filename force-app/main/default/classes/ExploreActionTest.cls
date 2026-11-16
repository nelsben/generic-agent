@IsTest
private class ExploreActionTest {
    private class Script implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        List<String> prompts = new List<String>();
        Integer calls = 0;
        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            prompts.add(userPrompt);
            if (calls >= replies.size()) {
                throw new AgentLlm.LlmException('model down');
            }
            return replies[calls++];
        }
    }

    private static Script script(List<String> replies) {
        Script s = new Script();
        s.replies = replies;
        AgentLlm.stub = s;
        return s;
    }

    /** The first dotted field path (Account.Name) in the text, or null. */
    private static String dottedPath(String text) {
        Matcher m = Pattern.compile('[A-Za-z_]+\\.[A-Za-z_]+').matcher(text);
        return m.find() ? m.group() : null;
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

    @IsTest
    static void parentFieldsGetPlainLabelsInTheAnswerAndTheModelPreview() {
        Account a = new Account(Name = 'Label Acme', Industry = 'Technology');
        insert a;
        insert new Opportunity(AccountId = a.Id, Name = 'Label Deal', StageName = 'Prospecting', Amount = 500, CloseDate = Date.today());
        Script s = script(new List<String>{
            '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Account.Name","Owner.Name"]}}',
            '{"action":"answer","text":"One deal.","followups":[]}'
        });

        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ request('Deals with owners?', null) });

        Assert.areEqual('OK', out[0].status, out[0].answer);
        Assert.isNull(dottedPath(out[0].answer), 'dotted path in the answer: ' + out[0].answer);
        Assert.isTrue(out[0].answer.contains('Name | Account | Owner\nLabel Deal | Label Acme | '), out[0].answer);
        // The rows the model sees come back under the same plain labels.
        String seen = s.prompts[1].substringAfter('RESULT Opportunity');
        Assert.isNull(dottedPath(seen), 'dotted path in the model preview: ' + seen);
        Assert.isTrue(seen.contains('Name | Account | Owner'), seen);
    }

    @IsTest
    static void withoutHistoryTheExplorerSeesNone() {
        Script s = script(new List<String>{ '{"action":"answer","text":"There are 36 open opportunities.","followups":[]}' });
        ExploreAction.Request req = request('How many open opportunities are there?', null);
        req.history = '';

        ExploreAction.explore(new List<ExploreAction.Request>{ req });

        Assert.isTrue(s.prompts[0].contains('Earlier in this conversation:\n(none)\n'), s.prompts[0]);
    }

    @IsTest
    static void historyFromOneTurnReachesTheNextTurnsPrompt() {
        Script s = script(new List<String>{
            '{"action":"answer","text":"There are 36 open opportunities.","followups":[]}',
            '{"action":"answer","text":"Two close this quarter.","followups":[]}'
        });

        ExploreAction.Response first = ExploreAction.explore(new List<ExploreAction.Request>{
            request('How many open opportunities are there?', null)
        })[0];
        ExploreAction.Request next = request('Which close this quarter?', null);
        next.history = first.history;
        ExploreAction.explore(new List<ExploreAction.Request>{ next });

        Assert.isTrue(s.prompts[0].contains('Earlier in this conversation:\n(none)\n'), s.prompts[0]);
        Assert.isTrue(
            s.prompts[1].contains('Earlier in this conversation:\nQ: How many open opportunities are there?\nA: There are 36 open opportunities.\n'),
            s.prompts[1]
        );
    }

    @IsTest
    static void historyOutputIsThisQuestionAndAnswerClipped() {
        script(new List<String>{ '{"action":"answer","text":"' + 'w'.repeat(900) + '","followups":[]}' });

        ExploreAction.Response res = ExploreAction.explore(new List<ExploreAction.Request>{ request('  Long one?  ', null) })[0];

        List<Object> items = (List<Object>) JSON.deserializeUntyped(res.history);
        Assert.areEqual(1, items.size(), res.history);
        Map<String, Object> item = (Map<String, Object>) items[0];
        Assert.areEqual('Long one?', item.get('question'));
        String answer = (String) item.get('answer');
        Assert.areEqual(ExploreAction.HISTORY_CHARS, answer.length());
        Assert.isTrue(answer.endsWith('...'), answer.right(10));
    }

    // ---- BE-39: the cards output ----

    @IsTest
    static void cardsComeAsJsonNextToAnUnchangedAnswer() {
        Account a = new Account(Name = 'Card Acme');
        insert a;
        Opportunity deal = new Opportunity(AccountId = a.Id, Name = 'Card Deal', StageName = 'Prospecting', Amount = 750, CloseDate = Date.today());
        insert deal;
        script(new List<String>{
            '{"action":"query","plan":{"object":"Opportunity","fields":["Name","Amount","StageName"]}}',
            '{"action":"answer","text":"One open deal.","followups":["Who owns it?"]}'
        });

        ExploreAction.Response res = ExploreAction.explore(new List<ExploreAction.Request>{ request('Open deals?', a.Id) })[0];

        Assert.isTrue(res.answer.startsWith('One open deal.\n\nName | Amount | Stage\nCard Deal | 750.00 | Prospecting'), res.answer);
        Map<String, Object> asJson = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(res));
        Assert.areEqual(new Set<String>{ 'status', 'answer', 'history', 'cards' }, asJson.keySet());
        List<AnswerCard> cards = AnswerCard.fromJson(res.cards);
        Assert.areEqual(res.cards, AnswerCard.toJson(cards), 'the JSON parses back to the same cards');
        List<String> types = new List<String>();
        for (AnswerCard c : cards) {
            types.add(c.type);
        }
        Assert.areEqual(new List<String>{ 'text', 'table', 'trail', 'followups' }, types);
        Assert.areEqual('One open deal.', cards[0].text);
        Assert.areEqual(1, cards[1].rows.size());
        Assert.areEqual(new List<String>{ 'Card Deal', '$750', 'Prospecting' }, cards[1].rows[0].cells);
        Assert.areEqual(String.valueOf(deal.Id), cards[1].refs[0].recordId);
        Assert.isFalse(res.answer.contains(String.valueOf(deal.Id)), 'the text never holds an Id');
    }

    @IsTest
    static void theCardTableHoldsTheRowsTheAnswerShowsAndNoMore() {
        ExploreQuery.ResultSet rs = new ExploreQuery.ResultSet();
        rs.objectName = 'Opportunity';
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
        List<AnswerCard> cards = AnswerCard.fromJson(ExploreAction.cardsJson(r));

        Integer textRows = text.substringAfter('Name | Note\n').substringBeforeLast('\n(').split('\n').size();
        Assert.isTrue(textRows < 200, 'the text cut the rows: ' + textRows);
        Assert.areEqual('table', cards[1].type);
        Assert.areEqual(textRows, cards[1].rows.size(), 'the same rows the text shows');
        Assert.areEqual(textRows, cards[1].shown);
        Assert.areEqual(450, cards[1].total);
        Assert.areEqual('notice', cards[2].type);

        r.answer = 'z'.repeat(ExploreAction.MAX_CHARS - 20);
        List<String> types = new List<String>();
        for (AnswerCard c : AnswerCard.fromJson(ExploreAction.cardsJson(r))) {
            types.add(c.type);
        }
        Assert.areEqual(new List<String>{ 'text' }, types, 'no room for a row in the text: no table card');
    }

    @IsTest
    static void cardsOverTheCapLeaveTheCardsOutputEmptyAndTheAnswerAsIs() {
        script(new List<String>{ '{"action":"answer","text":"There are 36 open opportunities.","followups":[]}' });
        AnswerCard.maxJsonChars = 20;

        ExploreAction.Response res = ExploreAction.explore(new List<ExploreAction.Request>{ request('How many?', null) })[0];

        Assert.areEqual('', res.cards);
        Assert.areEqual('There are 36 open opportunities.', res.answer);
        Assert.areEqual('OK', res.status, 'no result set came back and the model answered in text');
    }

    @IsTest
    static void blankQuestionOrNullRequestGivesNoHistory() {
        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ request('  ', null), null });
        Assert.areEqual('', out[0].history);
        Assert.areEqual('', out[1].history);
    }
}
