@IsTest
private class DataExplorerTest {
    /** Returns scripted replies in order and records every user prompt; never reaches a model. */
    private class Script implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        List<String> prompts = new List<String>();
        Integer failAt = -1;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            prompts.add(userPrompt);
            if (prompts.size() == failAt) {
                throw new AgentLlm.LlmException('model down');
            }
            return prompts.size() <= replies.size() ? replies[prompts.size() - 1] : '{"action":"answer","text":"fallback"}';
        }
    }

    private static Script script(List<String> replies) {
        Script s = new Script();
        s.replies = replies;
        AgentLlm.stub = s;
        return s;
    }

    private static String query(String planJson) {
        return '{"action":"query","plan":' + planJson + '}';
    }

    private static String answer(String text) {
        return '{"action":"answer","text":"' + text + '","followups":["Which deals closed?","Who owns them?"]}';
    }

    private static final String OPPS_OF_ACME =
        '{"object":"Opportunity","fields":["Name","Amount","StageName"],'
        + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}],"orderBy":{"field":"Amount","dir":"DESC"}}';

    @TestSetup
    static void data() {
        Account acme = new Account(Name = 'Explore Acme', Industry = 'Technology');
        Account beta = new Account(Name = 'Explore Beta');
        insert new List<Account>{ acme, beta };
        insert new List<Opportunity>{
            new Opportunity(AccountId = acme.Id, Name = 'Acme One', StageName = 'Closed Won', Amount = 1000, CloseDate = Date.today()),
            new Opportunity(AccountId = acme.Id, Name = 'Acme Two', StageName = 'Prospecting', Amount = 2000, CloseDate = Date.today()),
            new Opportunity(AccountId = acme.Id, Name = 'Acme Three', StageName = 'Closed Won', Amount = 3000, CloseDate = Date.today())
        };
        Contact c = new Contact(AccountId = acme.Id, LastName = 'Rivera', Title = 'Buyer');
        insert c;
        insert new Task(WhatId = acme.Id, WhoId = c.Id, Subject = 'Explore call', Status = 'Completed');
    }

    private static Account acme() {
        return [SELECT Id, Name FROM Account WHERE Name = 'Explore Acme' LIMIT 1];
    }

    @IsTest
    static void oneQueryAnswer() {
        Script s = script(new List<String>{ query(OPPS_OF_ACME), answer('Acme has three deals.') });

        DataExplorer.Result r = DataExplorer.explore('What deals does Acme have?', null, null);

        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual('Acme has three deals.', r.answer);
        Assert.areEqual(1, r.resultSets.size());
        Assert.areEqual(3, r.resultSets[0].shown);
        Assert.areEqual(3000, ((Decimal) r.resultSets[0].rows[0].get('Amount')).intValue());
        Assert.areEqual('Opportunity | Account.Name = Explore Acme | 3 rows', r.trail[0]);
        Assert.areEqual(2, r.followups.size());
        Assert.areEqual(2, s.prompts.size());
        Assert.isTrue(s.prompts[0].contains('Queries left: 4'));
        Assert.isTrue(s.prompts[0].contains('Opportunity: Id(id)'), 'catalog reaches the model');
        Assert.isTrue(s.prompts[1].contains('RESULT Opportunity rows=3 total=3'));
        Assert.isTrue(s.prompts[1].contains('Name | Amount | StageName'));
        Assert.isTrue(s.prompts[1].contains('Acme Three | 3000'));
        Assert.isTrue(s.prompts[1].contains('Queries left: 3'));
    }

    @IsTest
    static void twoQueryChain() {
        Id acmeId = acme().Id;
        Script s = script(new List<String>{
            query('{"object":"Account","fields":["Id","Name"],"filters":[{"field":"Name","op":"LIKE","value":"Explore A%"}]}'),
            query('{"object":"Contact","fields":["Name","Title"],"filters":[{"field":"AccountId","op":"=","value":"' + acmeId + '"}]}'),
            answer('Rivera is the buyer.')
        });

        DataExplorer.Result r = DataExplorer.explore('Who is the buyer at Acme?', null, null);

        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual(2, r.resultSets.size());
        Assert.areEqual('Account', r.resultSets[0].objectName);
        Assert.areEqual('Contact', r.resultSets[1].objectName);
        Assert.areEqual('Buyer', r.resultSets[1].rows[0].get('Title'));
        Assert.areEqual(2, r.trail.size());
        Assert.isTrue(s.prompts[2].contains('RESULT Account rows=1') && s.prompts[2].contains('RESULT Contact rows=1'));
    }

    @IsTest
    static void invalidRepliesAreFedBackAndCorrected() {
        Script s = script(new List<String>{
            query('{"object":"Opportunity","fields":["Name","Amout"]}'),
            'Sure, here is what I found.',
            '{"action":"guess"}',
            '```json\n' + query('{"object":"Opportunity","fields":["Name","Amount"]}') + '\n```',
            answer('Three deals.')
        });

        DataExplorer.Result r = DataExplorer.explore('List deals', null, null);

        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual(1, r.resultSets.size());
        Assert.isTrue(s.prompts[1].contains('[1] INVALID: Unknown field "Amout" on Opportunity.'), s.prompts[1]);
        Assert.isTrue(s.prompts[2].contains('[2] INVALID: the reply was not one JSON object.'));
        Assert.isTrue(s.prompts[3].contains('[3] INVALID: "action" must be "query" or "answer".'));
        Assert.isTrue(s.prompts[4].contains('[4] RESULT Opportunity'));
        Assert.isTrue(s.prompts[1].contains('Queries left: 4'), 'an invalid plan does not use a query');
    }

    @IsTest
    static void queryCapForcesAnswer() {
        String q = query(OPPS_OF_ACME);
        Script s = script(new List<String>{ q, q, q, q, answer('Done.') });

        DataExplorer.Result r = DataExplorer.explore('Keep looking', null, null);

        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual(4, r.resultSets.size());
        Assert.areEqual(5, s.prompts.size());
        Assert.isTrue(s.prompts[4].contains('Queries left: 0'));
    }

    @IsTest
    static void queryPastCapIsRefusedAndRunningOutOfTurnsKeepsTheResults() {
        String q = query(OPPS_OF_ACME);
        Script s = script(new List<String>{ q, q, q, q, q });

        DataExplorer.Result r = DataExplorer.explore('Keep looking', null, null);

        Assert.areEqual(DataExplorer.OK, r.status, 'the turn cap with rows in hand is not an error');
        Assert.areNotEqual(DataExplorer.ERROR_TEXT, r.answer);
        Assert.areEqual(DataExplorer.TURN_CAP_TEXT, r.answer, 'with a note that the turn cap was hit');
        Assert.areEqual(4, r.resultSets.size(), 'result sets already read are kept');
        Assert.areEqual(3, r.resultSets[3].shown);
        Assert.areEqual(4, r.trail.size());
        Assert.areEqual(DataExplorer.MAX_TURNS, s.prompts.size());
        Assert.isTrue(r.followups.isEmpty());
    }

    @IsTest
    static void runningOutOfTurnsWithNoResultsIsAnError() {
        Script s = script(new List<String>{ 'no json', 'no json', 'no json', 'no json', 'no json' });

        DataExplorer.Result r = DataExplorer.explore('Anything', null, null);

        Assert.areEqual(DataExplorer.ERROR, r.status);
        Assert.areEqual(DataExplorer.ERROR_TEXT, r.answer);
        Assert.isTrue(r.resultSets.isEmpty());
        Assert.areEqual(DataExplorer.MAX_TURNS, s.prompts.size());
    }

    @IsTest
    static void aggregateOverTheRowCapIsFedBackAndCountsAsAQuery() {
        ExploreQuery.rowCap = 2;
        Script s = script(new List<String>{
            query('{"object":"Opportunity","aggregates":[{"fn":"SUM","field":"Amount"}]}'),
            answer('Add a filter.')
        });

        DataExplorer.Result r = DataExplorer.explore('Total pipeline?', null, null);

        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.isTrue(r.resultSets.isEmpty());
        Assert.isTrue(s.prompts[1].contains('[1] INVALID: That would read more than 2 rows.'), s.prompts[1]);
        Assert.isTrue(s.prompts[1].contains('Queries left: 3'), 'a refused aggregate still counts');
    }

    @IsTest
    static void objectOutsideCatalogIsRejected() {
        Script s = script(new List<String>{
            query('{"object":"Lead","fields":["Name"]}'),
            '{"action":"answer","text":"I can only read the catalog objects.","followups":[]}'
        });

        DataExplorer.Result r = DataExplorer.explore('Show leads', null, null);

        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.isTrue(r.resultSets.isEmpty());
        Assert.isTrue(s.prompts[1].contains('INVALID: Unknown object "Lead". Use one of: Account, Contact, Opportunity'), s.prompts[1]);
    }

    @IsTest
    static void queryExceptionIsFedBackAndCountsAsAQuery() {
        // Pretend long text is filterable so a plan passes validation but the database rejects it.
        ExploreCatalog.find('Account').field('Description').filterable = true;
        Script s = script(new List<String>{
            query('{"object":"Account","fields":["Name"],"filters":[{"field":"Description","op":"=","value":"x"}]}'),
            answer('Done.')
        });

        DataExplorer.Result r = DataExplorer.explore('Accounts described as x', null, null);

        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.isTrue(r.resultSets.isEmpty());
        Assert.isTrue(s.prompts[1].contains('[1] INVALID: '), s.prompts[1]);
        Assert.isTrue(s.prompts[1].contains('Queries left: 3'), 'a query the database rejected still counts');
    }

    @IsTest
    static void modelFailureKeepsResultSets() {
        Script s = script(new List<String>{ query(OPPS_OF_ACME) });
        s.failAt = 2;

        DataExplorer.Result r = DataExplorer.explore('What deals does Acme have?', null, null);

        Assert.areEqual(DataExplorer.ERROR, r.status);
        Assert.areEqual('I couldn\'t finish that right now. Try again in a minute.', r.answer);
        Assert.areEqual(1, r.resultSets.size());
        Assert.areEqual(1, r.trail.size());
    }

    @IsTest
    static void blankQuestionIsEmpty() {
        Script s = script(new List<String>());
        DataExplorer.Result r = DataExplorer.explore('  ', null, null);
        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.areEqual(DataExplorer.NO_QUESTION_TEXT, r.answer);
        Assert.isTrue(s.prompts.isEmpty());
    }

    @IsTest
    static void contextAndHistoryReachThePrompt() {
        Account a = acme();
        Script s = script(new List<String>{ '{"action":"answer","text":"   "}', answer('Fine.') });
        String history = '[{"question":"Earlier question?","answer":"Earlier answer."},"junk",{"question":"Second?"}]';

        DataExplorer.Result r = DataExplorer.explore('How is this account?', a.Id, history);

        Assert.areEqual(DataExplorer.EMPTY, r.status, 'answered without rows');
        Assert.isTrue(s.prompts[0].contains('object=Account id=' + a.Id + ' name=Explore Acme'), s.prompts[0]);
        Assert.isTrue(s.prompts[0].contains('Q: Earlier question?\nA: Earlier answer.\nQ: Second?'));
        Assert.isTrue(s.prompts[1].contains('INVALID: an answer needs "text".'));
    }

    @IsTest
    static void unreadableHistoryAndNoContextAreNone() {
        Assert.areEqual('(none)', DataExplorer.historyText('not json'));
        Assert.areEqual('(none)', DataExplorer.historyText('{"question":"x"}'));
        Assert.areEqual('(none)', DataExplorer.historyText(null));
        Assert.areEqual('(none)', DataExplorer.contextText(null));
        String userContext = DataExplorer.contextText(UserInfo.getUserId());
        Assert.isTrue(userContext.startsWith('object=User id='));
    }

    @IsTest
    static void followupsAreCappedAndQueryNeedsPlan() {
        Script s = script(new List<String>{
            '{"action":"query"}',
            '{"action":"answer","text":"Ok.","followups":["a","b","",3,"c","d","e"]}'
        });

        DataExplorer.Result r = DataExplorer.explore('Anything', null, null);

        Assert.areEqual(new List<String>{ 'a', 'b', 'c', 'd' }, r.followups);
        Assert.isTrue(s.prompts[1].contains('INVALID: a query needs a "plan" object.'));
    }

    @IsTest
    static void parseReplyToleratesWrappingOnly() {
        Assert.isNull(DataExplorer.parseReply(null));
        Assert.isNull(DataExplorer.parseReply('no braces'));
        Assert.isNull(DataExplorer.parseReply('{not json}'));
        Assert.isNull(DataExplorer.parseReply('} backwards {'));
        Assert.areEqual('answer', DataExplorer.parseReply('Here: {"action":"answer"} done').get('action'));
        Assert.areEqual('abc', DataExplorer.clip('abc', 5));
        Assert.areEqual('ab...', DataExplorer.clip('abcdef', 5));
    }

    @IsTest
    static void drillByRecord() {
        Account a = acme();
        ExploreQuery.ResultSet rs = DataExplorer.drill(a.Id, null);
        Assert.areEqual('Account', rs.objectName);
        Assert.areEqual(1, rs.shown);
        Assert.areEqual('Explore Acme', rs.rows[0].get('Name'));
        Assert.areEqual('Technology', rs.rows[0].get('Industry'));
        Assert.isTrue(rs.columns.contains('Owner.Name'));
        Assert.isTrue(rs.soql.contains('LIMIT 1'));
    }

    @IsTest
    static void drillByRelatedObject() {
        Account a = acme();

        ExploreQuery.ResultSet opps = DataExplorer.drill(a.Id, ' opportunity ');
        Assert.areEqual('Opportunity', opps.objectName);
        Assert.areEqual(3, opps.shown);
        Assert.isTrue(opps.soql.contains('WHERE AccountId = :b0'), opps.soql);
        Assert.isTrue(opps.soql.contains('ORDER BY CreatedDate DESC'));

        ExploreQuery.ResultSet tasks = DataExplorer.drill(a.Id, 'Task');
        Assert.isTrue(tasks.soql.contains('WHERE AccountId = :b0'), 'single-object lookup beats WhatId: ' + tasks.soql);
        Assert.areEqual(1, tasks.shown);

        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1];
        ExploreQuery.ResultSet contactTasks = DataExplorer.drill(c.Id, 'Task');
        Assert.isTrue(contactTasks.soql.contains('WHERE WhoId = :b0'), contactTasks.soql);
        Assert.areEqual(1, contactTasks.shown);
    }

    @IsTest
    static void drillRefusesWhatTheCatalogDoesNotJoin() {
        Account a = acme();
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1];
        Map<String, String> expected = new Map<String, String>{
            'null' => 'Pick a record',
            'lead' => 'Lead is not in the explore catalog.',
            'org' => 'Organization is not in the explore catalog.',
            'nolookup' => 'Account has no lookup to Contact.'
        };
        Map<String, String> got = new Map<String, String>();
        for (String k : expected.keySet()) {
            try {
                if (k == 'null') {
                    DataExplorer.drill(null, null);
                } else if (k == 'lead') {
                    DataExplorer.drill(a.Id, 'Lead');
                } else if (k == 'org') {
                    DataExplorer.drill(UserInfo.getOrganizationId(), null);
                } else {
                    DataExplorer.drill(c.Id, 'Account');
                }
                got.put(k, 'no exception');
            } catch (DataExplorer.ExploreException e) {
                got.put(k, e.getMessage());
            }
        }
        for (String k : expected.keySet()) {
            Assert.isTrue(got.get(k).startsWith(expected.get(k)), k + ': ' + got.get(k));
        }
    }
}
