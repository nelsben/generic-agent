@IsTest
private class DataExplorerTest {
    /** Returns scripted replies in order and records every user prompt; never reaches a model. */
    private class Script implements AgentLlm.Provider {
        List<String> replies = new List<String>();
        List<String> prompts = new List<String>();
        List<String> systems = new List<String>();
        Integer failAt = -1;

        public String complete(String systemPrompt, String userPrompt, Integer maxTokens) {
            systems.add(systemPrompt);
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
    static void everyTurnsSystemPromptEndsWithTheBrandCompanyAndToneLines() {
        BrandSettings.rowsForTest = new List<Brand_Setting__mdt>{
            new Brand_Setting__mdt(Company_Name__c = 'Northwind Health', Tone__c = 'Warm and brief.')
        };
        Script s = script(new List<String>{ query(OPPS_OF_ACME), answer('Acme has three deals.') });

        DataExplorer.explore('What deals does Acme have?', null, null);

        Assert.areEqual(2, s.systems.size(), 'two model turns');
        for (String sys : s.systems) {
            Assert.isTrue(sys.startsWith('Role: You answer a sales user'), 'the prompt file\'s own text comes first');
            Assert.isTrue(sys.endsWith('\n\nCompany: the user works at Northwind Health.\nTone: Warm and brief.'),
                'the company line, then the tone line, end the explorer system prompt: ' + sys.right(200));
        }
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
        Assert.isTrue(s.prompts[1].contains('Name | Amount | Stage'));
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
    static void runningOutOfTurnsAfterAnEmptyLastQuerySaysSo() {
        String none = query('{"object":"Opportunity","fields":["Name"],"filters":[{"field":"Name","op":"=","value":"No such deal"}]}');
        script(new List<String>{ query(OPPS_OF_ACME), none, none, none, none });

        DataExplorer.Result r = DataExplorer.explore('Keep looking', null, null);

        Assert.areEqual(DataExplorer.OK, r.status, 'the first query found rows');
        Assert.areEqual(DataExplorer.TURN_CAP_NO_ROWS_TEXT, r.answer, 'no promise of a table that is not shown');
        Assert.areEqual(4, r.resultSets.size());
        Assert.areEqual(0, r.resultSets[3].shown);
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
        Assert.isTrue(rs.columns.contains('Owner'), 'Owner.Name is shown under its plain label: ' + rs.columns);
        Assert.isTrue(rs.soql.contains('LIMIT 1'));
    }

    /** A column that shows a record Id: Id itself, or a field ending in Id (AccountId, Account.OwnerId, WhoId). */
    private static List<String> idColumns(ExploreQuery.ResultSet rs) {
        List<String> out = new List<String>();
        for (String c : rs.columns) {
            String last = c.contains('.') ? c.substringAfterLast('.') : c;
            if (last.endsWithIgnoreCase('Id')) {
                out.add(c);
            }
        }
        return out;
    }

    @IsTest
    static void exploreNeverShowsAnIdColumnAndItsRowsStillDrill() {
        Script s = script(new List<String>{
            query('{"object":"Opportunity","fields":["Id","Name","Amount","AccountId","Account.Name","OwnerId"],'
                + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}],"orderBy":{"field":"Amount","dir":"DESC"}}'),
            answer('Acme Three leads at 3000.')
        });

        DataExplorer.Result r = DataExplorer.explore('Which Acme deals are largest?', null, null);

        ExploreQuery.ResultSet rs = r.resultSets[0];
        Assert.areEqual(new List<String>(), idColumns(rs), 'no Id column is displayed');
        Assert.areEqual(new List<String>{ 'Name', 'Amount', 'Account' }, rs.columns);
        Assert.areEqual(rs.columns, rs.labels);
        Opportunity top = [SELECT Id, Name FROM Opportunity WHERE Name = 'Acme Three' LIMIT 1];
        // The model still saw the Ids, so a follow-up can query those records again.
        Assert.isTrue(s.prompts[1].contains(String.valueOf(top.Id)), 'the model preview keeps the Ids');
        // Rows keep their Id for drill-down, and the drill opens that record.
        Assert.areEqual(top.Id, rs.rows[0].get('Id'));
        ExploreQuery.ResultSet drilled = DataExplorer.drill((Id) rs.rows[0].get('Id'), null);
        Assert.areEqual('Acme Three', drilled.rows[0].get('Name'));
        Assert.areEqual(new List<String>(), idColumns(drilled), 'the drill view shows no Id column either');
    }

    @IsTest
    static void relationshipColumnsShowPlainLabelsWithTheirValues() {
        script(new List<String>{
            query('{"object":"Opportunity","fields":["Name","Account.Name","Owner.Name"],'
                + '"filters":[{"field":"Name","op":"=","value":"Acme One"}]}'),
            answer('One deal.')
        });

        DataExplorer.Result r = DataExplorer.explore('Who owns Acme One?', null, null);

        ExploreQuery.ResultSet rs = r.resultSets[0];
        Assert.areEqual(new List<String>{ 'Name', 'Account', 'Owner' }, rs.columns);
        for (String c : rs.columns) {
            Assert.isFalse(c.contains('.'), 'dotted column: ' + c);
        }
        Assert.areEqual('Explore Acme', rs.rows[0].get('Account'));
        Assert.areEqual(UserInfo.getName(), rs.rows[0].get('Owner'));
        Assert.areEqual('Acme One', rs.rows[0].get('Name'));
    }

    @IsTest
    static void aFollowUpQueriesTheEarlierIdsWithoutShowingThem() {
        Script s = script(new List<String>{
            query('{"object":"Opportunity","fields":["Id","Name","Amount"],"orderBy":{"field":"Amount","dir":"DESC"},"limit":2,'
                + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}]}'),
            '{"action":"answer","text":"pending","followups":[]}'
        });
        DataExplorer.Result first = DataExplorer.explore('Top two Acme deals', null, null);
        List<Object> ids = new List<Object>();
        for (Map<String, Object> row : first.resultSets[0].rows) {
            ids.add(row.get('Id'));
        }
        Assert.areEqual(2, ids.size());

        s.prompts.clear();
        s.replies = new List<String>{
            query('{"object":"Opportunity","fields":["Id","Name","StageName"],'
                + '"filters":[{"field":"Id","op":"IN","value":' + JSON.serialize(ids) + '},{"field":"StageName","op":"=","value":"Closed Won"}]}'),
            answer('Of those 2 deals, 1 is won.')
        };
        DataExplorer.Result next = DataExplorer.explore('Which of those are won?', null, null);

        ExploreQuery.ResultSet rs = next.resultSets[0];
        Assert.areEqual(1, rs.shown);
        Assert.areEqual('Acme Three', rs.rows[0].get('Name'));
        Assert.areEqual(new List<String>{ 'Name', 'Stage' }, rs.columns);
        Assert.isNotNull(rs.rows[0].get('Id'));
        // The trail names how many records the follow-up filtered on, never their Ids.
        Assert.areEqual('Opportunity | Id IN (2 records) AND StageName = Closed Won | 1 rows', next.trail[0]);
    }

    @IsTest
    static void theTrailHidesRecordIdsOnly() {
        Id acmeId = acme().Id;
        Assert.areEqual('AccountId = a record', DataExplorer.withoutIds('AccountId = ' + acmeId));
        Assert.areEqual('Id IN (1 record)', DataExplorer.withoutIds('Id IN (' + String.valueOf(acmeId).left(15) + ')'));
        Assert.areEqual('Name IN (Acme, Beta)', DataExplorer.withoutIds('Name IN (Acme, Beta)'));
        Assert.areEqual('Industry = Telecommunications', DataExplorer.withoutIds('Industry = Telecommunications'));
        Assert.areEqual('no filters', DataExplorer.withoutIds('no filters'));
        Assert.isNull(DataExplorer.withoutIds(null));
    }

    @IsTest
    static void countsAndHandBuiltSetsKeepTheirOtherColumns() {
        ExploreQuery.ResultSet rs = new ExploreQuery.ResultSet();
        rs.objectName = 'Opportunity';
        rs.columns = new List<String>{ 'StageName', 'COUNT(Id)', 'WhatId' };
        rs.rows.add(new Map<String, Object>{ 'StageName' => 'Prospecting', 'COUNT(Id)' => 2, 'WhatId' => null });

        DataExplorer.forDisplay(rs);

        Assert.areEqual(new List<String>{ 'StageName', 'COUNT(Id)' }, rs.columns, 'a count of Ids is a number, not an Id');
        Assert.areEqual(rs.columns, rs.labels);
        Assert.areEqual(2, rs.rows[0].get('COUNT(Id)'));
        Assert.isNull(DataExplorer.forDisplay(null));
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

    // ---------------------------------------------------------------- follow-ups to a summary (BE-30)

    private static final String SUMMARY_TEXT =
        'Explore Acme has one open deal worth $2,000 and one buyer on record.\nTwo deals closed won this year.';

    /** A summary of the account as the last turn: remembered for this user, and sent back as the panel sends it. */
    private static String summaryHistory(Id accountId) {
        CustomerSummaryMemory.record(accountId, 'OK', null, SUMMARY_TEXT);
        return JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'question' => 'Summarize Explore Acme', 'answer' => SUMMARY_TEXT }
        });
    }

    private static Opportunity openDeal() {
        return [SELECT Id FROM Opportunity WHERE Name = 'Acme Two' LIMIT 1];
    }

    private static Contact rivera() {
        return [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1];
    }

    private static void assertNoIdShown(DataExplorer.Result r, List<Id> ids) {
        String shown = r.answer + ' ' + String.join(r.trail, ' ') + ' ' + String.join(r.followups, ' ');
        for (Id i : ids) {
            Assert.isFalse(shown.contains(String.valueOf(i)), 'no record Id is shown to people: ' + shown);
        }
    }

    @IsTest
    static void whichOfThoseCloseThisQuarterUsesTheSummarysDeals() {
        Account a = acme();
        Id dealId = openDeal().Id;
        // Matches the question (open, closes this quarter) but is on another account, so not behind the summary.
        Account beta = [SELECT Id FROM Account WHERE Name = 'Explore Beta' LIMIT 1];
        insert new Opportunity(AccountId = beta.Id, Name = 'Beta Open', StageName = 'Prospecting', Amount = 5000, CloseDate = Date.today());
        String history = summaryHistory(a.Id);
        Script s = script(new List<String>{
            query('{"object":"Opportunity","fields":["Name","Amount","CloseDate"],"filters":['
                + '{"field":"Id","op":"IN","value":["' + dealId + '"]},{"field":"CloseDate","op":"=","value":"THIS_QUARTER"}]}'),
            answer('Of those deals, 1 closes this quarter.')
        });

        Test.startTest();
        DataExplorer.Result r = DataExplorer.explore('Which of those close this quarter?', a.Id, history);
        Test.stopTest();

        Assert.isTrue(s.prompts[0].contains('Records behind that summary'), 'the summary context reaches the model: ' + s.prompts[0]);
        Assert.isTrue(s.prompts[0].contains('id=' + a.Id), 'the summarized account is named by Id');
        Assert.isTrue(s.prompts[0].contains('Acme Two') && s.prompts[0].contains('id=' + dealId), 'the open deal behind the summary');
        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual('Acme Two', r.resultSets[0].rows[0].get('Name'));
        // The plan's filter on the summary's deal Ids is what keeps the other account's open deal out.
        Assert.areEqual(1, r.resultSets[0].rows.size(), 'only the summary\'s deal comes back: ' + r.resultSets[0].rows);
        for (Map<String, Object> row : r.resultSets[0].rows) {
            Assert.areEqual(dealId, (Id) row.get('Id'), 'every returned row is one of the summary\'s deals');
        }
        assertNoIdShown(r, new List<Id>{ a.Id, dealId });
    }

    @IsTest
    static void whoThereHaveWeNotCalledUsesTheSummarysContacts() {
        Account a = acme();
        Id contactId = rivera().Id;
        // A contact on another account, with a call logged: not behind the summary.
        Account beta = [SELECT Id FROM Account WHERE Name = 'Explore Beta' LIMIT 1];
        Contact other = new Contact(AccountId = beta.Id, LastName = 'Okafor', Title = 'Buyer');
        insert other;
        insert new Task(WhatId = beta.Id, WhoId = other.Id, Subject = 'Other call', Status = 'Completed', TaskSubtype = 'Call');
        String history = summaryHistory(a.Id);
        Script s = script(new List<String>{
            query('{"object":"Task","fields":["Subject","WhoId"],"filters":['
                + '{"field":"WhoId","op":"IN","value":["' + contactId + '"]},{"field":"TaskSubtype","op":"=","value":"Call"}]}'),
            query('{"object":"Contact","fields":["Name","Title"],"filters":[{"field":"Id","op":"IN","value":["' + contactId + '"]}]}'),
            answer('Rivera has no call on record.')
        });

        Test.startTest();
        DataExplorer.Result r = DataExplorer.explore('Who there have we not called?', a.Id, history);
        Test.stopTest();

        Assert.isTrue(s.prompts[0].contains('Rivera') && s.prompts[0].contains('id=' + contactId),
            'the contacts behind the summary reach the model: ' + s.prompts[0]);
        Assert.areEqual(2, r.resultSets.size());
        Assert.areEqual('Rivera', r.resultSets[1].rows[0].get('Name'));
        // The scripted plan filters on the summary's contact Ids only (the plan language has no anti-join, BE-43):
        // the other account's contact and its call stay out of both tables.
        Assert.areEqual(0, r.resultSets[0].rows.size(), 'no call logged by the summary\'s contact: ' + r.resultSets[0].rows);
        Assert.areEqual(1, r.resultSets[1].rows.size(), 'only the summary\'s contact comes back: ' + r.resultSets[1].rows);
        for (Map<String, Object> row : r.resultSets[1].rows) {
            Assert.areEqual(contactId, (Id) row.get('Id'), 'every returned row is one of the summary\'s contacts');
        }
        assertNoIdShown(r, new List<Id>{ a.Id, contactId });
    }

    @IsTest
    static void anyOpenCasesOnTheBiggestDealUsesTheSummarysDealAndAccount() {
        Account a = acme();
        Id dealId = openDeal().Id;
        Case ownCase = new Case(AccountId = a.Id, Subject = 'Explore case', Status = 'New');
        // An open case on another account: matches the question, not behind the summary.
        Account beta = [SELECT Id FROM Account WHERE Name = 'Explore Beta' LIMIT 1];
        insert new List<Case>{ ownCase, new Case(AccountId = beta.Id, Subject = 'Beta case', Status = 'New') };
        String history = summaryHistory(a.Id);
        Script s = script(new List<String>{
            query('{"object":"OpportunityContactRole","fields":["ContactId","Contact.Name"],'
                + '"filters":[{"field":"OpportunityId","op":"=","value":"' + dealId + '"}]}'),
            query('{"object":"Case","fields":["CaseNumber","Subject","Status"],"filters":['
                + '{"field":"AccountId","op":"=","value":"' + a.Id + '"},{"field":"IsClosed","op":"=","value":false}]}'),
            answer('There is 1 open case on that account.')
        });

        Test.startTest();
        DataExplorer.Result r = DataExplorer.explore('Any open cases on the biggest deal?', a.Id, history);
        Test.stopTest();

        // The deal line carries its amount, so the model can tell which deal is biggest.
        Assert.isTrue(s.prompts[0].contains('2,000') && s.prompts[0].contains('id=' + dealId), s.prompts[0]);
        Assert.areEqual(DataExplorer.OK, r.status);
        Assert.areEqual('Explore case', r.resultSets[1].rows[0].get('Subject'));
        // The plan's filter on the summary's account Id is what keeps the other account's open case out.
        Assert.areEqual(1, r.resultSets[1].rows.size(), 'only the summary\'s account case comes back: ' + r.resultSets[1].rows);
        for (Map<String, Object> row : r.resultSets[1].rows) {
            Assert.areEqual(ownCase.Id, (Id) row.get('Id'), 'every returned row is a case of the summary\'s account');
        }
        assertNoIdShown(r, new List<Id>{ a.Id, dealId });
    }

    @IsTest
    static void anUnclearPronounAfterASummaryIsAskedBackWithNoQuery() {
        Account a = acme();
        String history = summaryHistory(a.Id);
        Script s = script(new List<String>{
            '{"action":"answer","text":"Do you mean the open deals or the contacts from that summary?",'
                + '"followups":["Which open deals matter most?","Which contacts matter most?"]}'
        });

        Test.startTest();
        DataExplorer.Result r = DataExplorer.explore('Which of those matter most?', a.Id, history);
        Test.stopTest();

        Assert.isTrue(s.systems[0].contains('When it is unclear which records the question means'), 'the pronoun rule is in the prompt');
        Assert.isTrue(s.prompts[0].contains(DataExplorer.SUMMARY_CONTEXT_HEADER), 'the context is there to choose from');
        Assert.areEqual(1, s.prompts.size(), 'one model call, no query');
        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.isTrue(r.resultSets.isEmpty());
        Assert.isTrue(r.answer.endsWith('?'), 'the answer asks: ' + r.answer);
        Assert.areEqual(2, r.followups.size(), 'the choices come back as follow-ups');
    }

    @IsTest
    static void noSummaryContextWhenTheLastTurnIsNotTheSummary() {
        Account a = acme();
        summaryHistory(a.Id);
        String afterAnExplore = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'question' => 'Summarize Explore Acme', 'answer' => SUMMARY_TEXT },
            new Map<String, Object>{ 'question' => 'Which deals are open?', 'answer' => 'One deal is open, Acme Two.' }
        });
        String summaryOnly = JSON.serialize(new List<Object>{ new Map<String, Object>{ 'question' => 'Q', 'answer' => SUMMARY_TEXT } });

        Test.startTest();
        String afterExplore = DataExplorer.summaryContext(a.Id, afterAnExplore);
        String notAnAccount = DataExplorer.summaryContext(rivera().Id, summaryOnly);
        String noRecord = DataExplorer.summaryContext(null, summaryOnly);
        String otherAccount = DataExplorer.summaryContext([SELECT Id FROM Account WHERE Name = 'Explore Beta' LIMIT 1].Id, summaryOnly);
        String clipped = DataExplorer.summaryContext(a.Id, JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'question' => 'Q', 'answer' => SUMMARY_TEXT.left(40) + '...' } }));
        Test.stopTest();

        Assert.areEqual('', afterExplore, 'the last turn is an explore answer');
        Assert.areEqual('', notAnAccount, 'the open record is not an account');
        Assert.areEqual('', noRecord);
        Assert.areEqual('', otherAccount, 'no summary of that account is remembered');
        Assert.isTrue(clipped.contains(DataExplorer.SUMMARY_CONTEXT_HEADER), 'a clipped summary answer (the agent\'s history) still matches');
        Assert.isFalse(DataExplorer.isLastSummary('Short.', 'Short. And more.'), 'too short to match');
        Assert.isFalse(DataExplorer.isLastSummary('A different answer entirely here.', SUMMARY_TEXT));
        Assert.isTrue(DataExplorer.isLastSummary(SUMMARY_TEXT.replace('\n', '  '), SUMMARY_TEXT), 'whitespace is collapsed');
    }

    @IsTest
    static void theSummaryContextIsCappedPerSectionAndInAll() {
        Id anyId = acme().Id;
        List<CustomerSummarySection> sections = new List<CustomerSummarySection>();
        for (Integer s = 0; s < 8; s++) {
            CustomerSummarySection sec = new CustomerSummarySection();
            sec.key = 'k' + s;
            sec.title = 'Section ' + s;
            sec.status = CustomerSummarySection.OK;
            List<String> lines = new List<String>{ 'A heading line without a record' };
            for (Integer i = 0; i < 30; i++) {
                lines.add(CustomerSummarySection.withId('- Record ' + s + '-' + i + ' ' + 'x'.repeat(200), anyId));
            }
            sec.body = String.join(lines, '\n');
            sections.add(sec);
        }
        CustomerSummarySection failed = new CustomerSummarySection();
        failed.status = CustomerSummarySection.ERROR;
        failed.body = CustomerSummarySection.withId('- Hidden', anyId);
        sections.add(failed);

        Test.startTest();
        String text = DataExplorer.summaryLines(anyId, sections);
        Test.stopTest();

        Assert.isTrue(text.length() <= DataExplorer.SUMMARY_CONTEXT_CHARS, 'capped in all: ' + text.length());
        List<String> section0 = text.substringAfter('Section 0:\n').substringBefore('\nSection 1:').split('\n');
        Assert.areEqual(DataExplorer.SUMMARY_ITEMS_PER_SECTION + 1, section0.size(), 'capped per section: ' + section0);
        Assert.areEqual('(20 more not listed)', section0[DataExplorer.SUMMARY_ITEMS_PER_SECTION], 'a cut says so');
        Assert.isTrue(section0[0].startsWith('- Record 0-0 x') && section0[0].endsWith(' id=' + anyId), section0[0]);
        Assert.isTrue(section0[0].length() < 160, 'each line is clipped: ' + section0[0].length());
        Assert.isFalse(text.contains('A heading line'), 'only lines that name a record');
        Assert.isFalse(text.contains('Hidden'), 'a section that did not load adds nothing');
        Assert.isFalse(text.contains('Section 7:'), 'sections past the cap are left out');
    }

    @IsTest
    static void agentPathKeepsTheTablesReadBeforeAModelFailure() {
        Script s = script(new List<String>{ query(OPPS_OF_ACME) });
        s.failAt = 2;
        ExploreAction.Request req = new ExploreAction.Request();
        req.question = 'What deals does Acme have?';

        Test.startTest();
        List<ExploreAction.Response> out = ExploreAction.explore(new List<ExploreAction.Request>{ req });
        Test.stopTest();

        Assert.areEqual(DataExplorer.ERROR, out[0].status, 'the status stays ERROR');
        Assert.isTrue(out[0].answer.startsWith(DataExplorer.ERROR_TEXT), 'the fixed failure line comes first: ' + out[0].answer);
        Assert.isTrue(out[0].answer.contains('Acme Three | 3000'), 'the table already read is kept: ' + out[0].answer);
    }

    @IsTest
    static void drillChildRowsCarryLabelsAndNamesAndKeepTheirIds() {
        Opportunity deal = openDeal();
        Contact c = rivera();
        Task t = new Task(WhatId = deal.Id, WhoId = c.Id, Subject = 'Deal call', Status = 'Not Started');
        insert t;

        Test.startTest();
        ExploreQuery.ResultSet rs = DataExplorer.drill(deal.Id, 'Task');
        Test.stopTest();

        Assert.areEqual(1, rs.shown);
        Assert.areEqual(t.Id, rs.rows[0].get('Id'), 'the row keeps its Id for opening the record');
        Assert.areEqual('Deal call', rs.rows[0].get(rs.columns[0]), 'the first column names the record');
        Assert.areEqual(rs.columns, rs.labels);
        Set<String> allowed = new Set<String>(rs.columns);
        allowed.add('Id');
        for (String key : rs.rows[0].keySet()) {
            Assert.isTrue(allowed.contains(key), 'a drill row carries only shown labels and its Id, not ' + key);
        }
        for (String col : rs.columns) {
            Assert.isFalse(col.contains('.') || col.endsWith('Id'), 'header is a label, not an API name: ' + col);
            String v = String.valueOf(rs.rows[0].get(col));
            Assert.isFalse(v == String.valueOf(deal.Id) || v == String.valueOf(c.Id) || v == String.valueOf(UserInfo.getUserId()),
                'no raw Id under ' + col);
        }
        Assert.isTrue(rs.rows[0].values().contains('Acme Two'), 'the deal shows by name: ' + rs.rows[0]);
        Assert.isTrue(rs.rows[0].values().contains('Rivera'), 'the contact shows by name: ' + rs.rows[0]);
    }

    @IsTest
    static void drillChildRowsWithoutANameFieldLeadWithTheOtherSidesName() {
        Opportunity deal = openDeal();
        Contact c = rivera();
        insert new OpportunityContactRole(OpportunityId = deal.Id, ContactId = c.Id, Role = 'Decision Maker');

        Test.startTest();
        ExploreQuery.ResultSet fromDeal = DataExplorer.drill(deal.Id, 'OpportunityContactRole');
        ExploreQuery.ResultSet fromContact = DataExplorer.drill(c.Id, 'OpportunityContactRole');
        Test.stopTest();

        Assert.areEqual('Rivera', fromDeal.rows[0].get(fromDeal.columns[0]), 'a role drilled from its deal leads with the contact');
        Assert.areEqual('Acme Two', fromContact.rows[0].get(fromContact.columns[0]), 'a role drilled from its contact leads with the deal');
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

    // ---- BE-39: cards next to the text ----

    private static List<String> keysOf(List<AnswerCard> cards) {
        List<String> keys = new List<String>();
        for (AnswerCard c : cards) {
            keys.add(c.key);
        }
        return keys;
    }

    private static AnswerCard card(DataExplorer.Result r, String key) {
        for (AnswerCard c : r.cards) {
            if (c.key == key) {
                return c;
            }
        }
        return null;
    }

    private static Map<String, AnswerCard.Ref> refsOf(AnswerCard c) {
        Map<String, AnswerCard.Ref> refs = new Map<String, AnswerCard.Ref>();
        for (AnswerCard.Ref ref : c.refs) {
            refs.put(ref.key, ref);
        }
        return refs;
    }

    /** No card's text holds a record Id, and every Id in the cards JSON is a ref's recordId. */
    private static void assertIdsOnlyInRefs(DataExplorer.Result r) {
        Set<String> rowIds = new Set<String>();
        for (ExploreQuery.ResultSet rs : r.resultSets) {
            for (Map<String, Object> row : rs.rows) {
                if (row.get('Id') != null) {
                    rowIds.add(String.valueOf(row.get('Id')));
                }
            }
        }
        String cardJson = JSON.serialize(r.cards, true);
        for (AnswerCard c : r.cards) {
            Assert.areEqual(AnswerCard.plainText(c), c.text, c.key);
            for (String i : rowIds) {
                Assert.isFalse(c.text.contains(i), 'an Id reached the text of ' + c.key);
            }
        }
        for (String i : rowIds) {
            Assert.isTrue(cardJson.countMatches(i) <= 1, 'an Id appears outside refs: ' + i);
        }
    }

    @IsTest
    static void cardsAgreeWithTheAnswerTheTableTheTrailAndTheFollowups() {
        script(new List<String>{ query(OPPS_OF_ACME), answer('Acme has **three** deals.') });

        DataExplorer.Result r = DataExplorer.explore('What deals does Acme have?', null, null);

        Assert.areEqual(new List<String>{ 'ans', 'tbl', 'trl', 'fol' }, keysOf(r.cards));
        AnswerCard text = card(r, 'ans');
        Assert.areEqual('text', text.type);
        Assert.areEqual('OK', text.status);
        Assert.areEqual('Acme has three deals.', text.text);
        Assert.areEqual(true, text.body[0].runs[1].strong, 'the answer\'s markup becomes runs');

        AnswerCard table = card(r, 'tbl');
        ExploreQuery.ResultSet rs = r.resultSets[0];
        Assert.areEqual('table', table.type);
        Assert.areEqual('Opportunity', table.title);
        Assert.areEqual(rs.total, table.total);
        Assert.areEqual(rs.shown, table.shown);
        Assert.areEqual(rs.rows.size(), table.rows.size());
        List<String> heads = new List<String>();
        List<String> kinds = new List<String>();
        for (AnswerCard.Column col : table.columns) {
            heads.add(col.label);
            kinds.add(col.kind);
        }
        Assert.areEqual(DataExplorer.headers(rs), heads, 'the columns the text shows, in its order');
        Assert.areEqual(new List<String>{ 'text', 'currency', 'text' }, kinds);
        Map<String, AnswerCard.Ref> refs = refsOf(table);
        for (Integer i = 0; i < rs.rows.size(); i++) {
            AnswerCard.Row row = table.rows[i];
            Assert.areEqual(rs.rows[i].get('Name'), row.cells[0], 'same row order as the result set');
            Assert.areEqual(String.valueOf(rs.rows[i].get('Id')), refs.get(row.ref).recordId, 'the row points at its own record');
            Assert.areEqual(row.cells[0], refs.get(row.ref).label, 'the ref is labelled by the row\'s first cell');
            Assert.areEqual('Opportunity', refs.get(row.ref).objectName);
        }
        Assert.areEqual(new List<String>{ 'Acme Three', '$3,000', 'Closed Won' }, table.rows[0].cells, 'cells are formatted strings');
        Assert.areEqual('Opportunity\nName | Amount | Stage\nAcme Three | $3,000 | Closed Won\nAcme Two | $2,000 | Prospecting\nAcme One | $1,000 | Closed Won',
            table.text);

        AnswerCard trail = card(r, 'trl');
        Assert.areEqual('Ran 1 query', trail.title);
        Assert.areEqual(r.trail.size(), trail.items.size());
        Assert.areEqual('Opportunity where Account.Name = Explore Acme', trail.items[0].label);
        Assert.areEqual('3 rows', trail.items[0].detail);

        AnswerCard fol = card(r, 'fol');
        Assert.areEqual(r.followups.size(), fol.items.size());
        Assert.areEqual(r.followups[0], fol.items[0].label);
        assertIdsOnlyInRefs(r);
    }

    @IsTest
    static void aCutTableSaysSoAndANoticeSaysHowToNarrowIt() {
        String limited = '{"object":"Opportunity","fields":["Name","Amount","StageName"],"limit":2,'
            + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}],"orderBy":{"field":"Amount","dir":"DESC"}}';
        script(new List<String>{ query(limited), answer('The two largest.') });

        DataExplorer.Result r = DataExplorer.explore('Largest deals?', null, null);

        Assert.areEqual(new List<String>{ 'ans', 'tbl', 'not', 'trl', 'fol' }, keysOf(r.cards));
        AnswerCard table = card(r, 'tbl');
        Assert.areEqual(3, table.total);
        Assert.areEqual(2, table.shown);
        Assert.isTrue(table.text.endsWith('\n(2 of 3 rows)'), table.text);
        Assert.areEqual('Showing 2 of 3 rows. Ask with a filter to narrow it.', card(r, 'not').text);
        Assert.areEqual('2 of 3 rows', card(r, 'trl').items[0].detail);
    }

    @IsTest
    static void anAggregateWithoutGroupsIsAMetric() {
        script(new List<String>{
            query('{"object":"Opportunity","aggregates":[{"fn":"SUM","field":"Amount"},{"fn":"COUNT","field":"Id"}],'
                + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}]}'),
            answer('Six thousand in all.')
        });

        DataExplorer.Result r = DataExplorer.explore('How much does Acme have?', null, null);

        Assert.areEqual(new List<String>{ 'ans', 'met', 'trl', 'fol' }, keysOf(r.cards));
        AnswerCard metric = card(r, 'met');
        Assert.areEqual('metric', metric.type);
        Assert.areEqual('Opportunity\nSum of Amount: $6,000\nCount: 3', metric.text);
        Assert.isTrue(metric.refs.isEmpty());
    }

    @IsTest
    static void groupedRowsAreATableWithoutRefs() {
        script(new List<String>{
            query('{"object":"Opportunity","groupBy":["StageName"],"aggregates":[{"fn":"SUM","field":"Amount"}],'
                + '"filters":[{"field":"Account.Name","op":"=","value":"Explore Acme"}],"orderBy":{"field":"StageName","dir":"ASC"}}'),
            answer('By stage.')
        });

        DataExplorer.Result r = DataExplorer.explore('Amount by stage?', null, null);

        AnswerCard table = card(r, 'tbl');
        Assert.isNotNull(table, 'cards: ' + keysOf(r.cards));
        Assert.areEqual(2, table.rows.size());
        ExploreQuery.ResultSet rs = r.resultSets[0];
        for (Integer i = 0; i < rs.rows.size(); i++) {
            Assert.areEqual(String.valueOf(rs.rows[i].get(rs.columns[0])), table.rows[i].cells[0], 'same row order as the result set');
        }
        Integer won = table.rows[0].cells[0] == 'Closed Won' ? 0 : 1;
        Assert.areEqual(new List<String>{ 'Closed Won', '$4,000' }, table.rows[won].cells, 'the sum is a formatted amount');
        Assert.isNull(table.rows[0].ref, 'a group is no one record');
        Assert.isTrue(table.refs.isEmpty());
    }

    @IsTest
    static void twoColumnsOfRecordsAreARecordListFromTheLastResult() {
        Id acmeId = acme().Id;
        script(new List<String>{
            query('{"object":"Account","fields":["Id","Name"],"filters":[{"field":"Name","op":"LIKE","value":"Explore A%"}]}'),
            query('{"object":"Contact","fields":["Name","Title"],"filters":[{"field":"AccountId","op":"=","value":"' + acmeId + '"}]}'),
            answer('Rivera is the buyer.')
        });

        DataExplorer.Result r = DataExplorer.explore('Who is the buyer at Acme?', null, null);

        Assert.areEqual(new List<String>{ 'ans', 'lst', 'trl', 'fol' }, keysOf(r.cards));
        AnswerCard lst = card(r, 'lst');
        Assert.areEqual('recordList', lst.type);
        Assert.areEqual('Contact', lst.title);
        Assert.areEqual(1, lst.items.size());
        Assert.areEqual('Rivera', lst.items[0].label);
        Assert.areEqual('Buyer', lst.items[0].detail);
        Assert.areEqual('Contact', refsOf(lst).get(lst.items[0].ref).objectName);
        AnswerCard trail = card(r, 'trl');
        Assert.areEqual('Ran 2 queries', trail.title);
        Assert.areEqual('Contact where AccountId = a record', trail.items[1].label, 'the trail hides Ids as the text does');
        assertIdsOnlyInRefs(r);
    }

    @IsTest
    static void aModelFailureIsAnErrorCardThenTheTableAlreadyRead() {
        Script s = script(new List<String>{ query(OPPS_OF_ACME) });
        s.failAt = 2;

        DataExplorer.Result r = DataExplorer.explore('What deals?', null, null);

        Assert.areEqual(DataExplorer.ERROR, r.status);
        Assert.areEqual(new List<String>{ 'err', 'tbl', 'trl' }, keysOf(r.cards), 'no followups on an error');
        Assert.areEqual('error', r.cards[0].type);
        Assert.areEqual(DataExplorer.ERROR_TEXT, r.cards[0].text);
    }

    @IsTest
    static void aBlankQuestionIsOneTextCardAndTheTextMembersAreUnchanged() {
        DataExplorer.Result r = DataExplorer.explore('  ', null, null);

        Map<String, Object> asJson = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(r));
        Assert.areEqual(new Set<String>{ 'status', 'answer', 'resultSets', 'trail', 'followups', 'cards' }, asJson.keySet(),
            'one new member, cards; every other member keeps its name');
        Assert.areEqual(DataExplorer.EMPTY, r.status);
        Assert.areEqual(DataExplorer.NO_QUESTION_TEXT, r.answer);
        Assert.areEqual(1, r.cards.size());
        Assert.areEqual('EMPTY', r.cards[0].status);
        Assert.areEqual(DataExplorer.NO_QUESTION_TEXT, r.cards[0].text);
    }

    @IsTest
    static void cardsForATextThatShowsNoRowsHoldNoTable() {
        script(new List<String>{ query(OPPS_OF_ACME), answer('Acme has three deals.') });
        DataExplorer.Result r = DataExplorer.explore('What deals does Acme have?', null, null);

        List<AnswerCard> cards = DataExplorer.cards(r, 0);

        Assert.areEqual(new List<String>{ 'ans', 'trl', 'fol' }, keysOf(cards), 'a table card holds no more rows than the text shows');
        List<AnswerCard> two = DataExplorer.cards(r, 2);
        Assert.areEqual(2, two[1].rows.size());
        Assert.areEqual(2, two[1].shown);
        Assert.areEqual(3, two[1].total);
    }

    // ------------------------------------------------------------------ customer outcomes (BE-35)

    /** A Standard User rep with the product's data-access and outcome sets. */
    private static User outcomeRep() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniq = 'dxo' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            u = new User(Alias = 'dxo', Email = uniq + '@example.com', EmailEncodingKey = 'UTF-8', LastName = 'Outcome Rep',
                LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
                Username = uniq + '@example.com.exploreoutcome');
            insert u;
            List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Customer_Summary_Data_Access', 'Customer_Summary_Outcome_Access')]) {
                grants.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
            insert grants;
        }
        return u;
    }

    /**
     * The MCP door's ask tool maps to ExploreAction: with an account open, the explorer's prompt carries the account's
     * outcome context (the last summary's headline and date).
     */
    @IsTest
    static void theActionSeesTheOpenAccountsOutcomeContext() {
        Account a = acme();
        User rep = outcomeRep();
        CustomerOutcomes.Input last = new CustomerOutcomes.Input(a.Id, CustomerOutcomes.SUMMARY);
        last.body = 'Renewal on track.\nTwo open deals.';
        Script s = script(new List<String>{ answer('Acme has three deals.') });

        ExploreAction.Request req = new ExploreAction.Request();
        req.question = 'What deals does Acme have?';
        req.contextRecordId = a.Id;
        Test.startTest();
        System.runAs(rep) {
            CustomerOutcomes.record(last);
            ExploreAction.explore(new List<ExploreAction.Request>{ req });
        }
        Test.stopTest();

        Assert.areEqual(1, s.prompts.size());
        Assert.isTrue(s.prompts[0].contains(CustomerOutcomes.CONTEXT_HEADER), s.prompts[0]);
        Assert.isTrue(s.prompts[0].contains('- Summary, ' + Datetime.now().format('yyyy-MM-dd') + ': Renewal on track.'), s.prompts[0]);
        Assert.isFalse(s.prompts[0].contains('Two open deals.'), 'the headline only');
    }

    @IsTest
    static void noOutcomeContextWithoutAnAccountOrOutcomes() {
        Assert.areEqual('', DataExplorer.outcomeContext(null));
        Assert.areEqual('', DataExplorer.outcomeContext(acme().Id), 'no outcomes yet');
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Assert.areEqual('', DataExplorer.outcomeContext(c.Id), 'only an open account carries outcomes');
    }
}
