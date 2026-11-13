/**
 * AnswerCardTest: the card contract (BE-39) against FE-18's page, docs/research/fr2-card-architecture.md.
 * Every card type is built from that page's fixture and must equal it, record Ids aside (each ref's recordId is
 * compared as 'record-id:<key>', the page's placeholder). Every row of the page's 'Rich text' table is a case here.
 */
@IsTest
private class AnswerCardTest {
    // The JSON examples from FE-18's page, one per card type, minified. Record Ids are the page's placeholders.
    private static final String FIX_SUMMARY =
        '{"type":"summary","version":1,"key":"sum","title":"Edge Communications: steady service, one large renewal at risk","meta":"Account summary","status":"OK","text":"Edge Communications: steady service, one large renewal at risk\\nOpen deals: 3 worth $412,000; the largest closes this quarter.\\nService health: 2 open cases, one high priority for 9 days.\\n- Renewal owner has not logged a call in 41 days\\n- Two contacts on their side have never been called","body":[{"kind":"p","runs":[{"text":"Open deals:","strong":true},{"text":" 3 worth $412,000; the largest closes this quarter."}]},{"kind":"p","runs":[{"text":"Service health:","strong":true},{"text":" 2 open cases, one "},{"text":"high priority","em":true},{"text":" for 9 days."}]},{"kind":"li","runs":[{"text":"Renewal owner has not logged a call in 41 days"}]},{"kind":"li","runs":[{"text":"Two contacts on their side have never been called"}]}],"refs":[]}';
    private static final String FIX_SECTION =
        '{"type":"section","version":1,"key":"sec-deals","title":"Open deals","status":"OK","text":"Open deals (3 of 3)\\n- Edge Emergency Generator — Proposal · $250,000 · closes 2026-12-18\\n- Edge Installation — Negotiation · $112,000 · closes 2027-01-30\\n- Edge SLA — Qualification · $50,000 · closes 2027-03-02","body":[],"total":3,"shown":3,"items":[{"label":"Edge Emergency Generator","detail":"Proposal · $250,000 · closes 2026-12-18","ref":"o1"},{"label":"Edge Installation","detail":"Negotiation · $112,000 · closes 2027-01-30","ref":"o2"},{"label":"Edge SLA","detail":"Qualification · $50,000 · closes 2027-03-02","ref":"o3"}],"refs":[{"key":"o1","recordId":"record-id:o1","objectName":"Opportunity","label":"Edge Emergency Generator"},{"key":"o2","recordId":"record-id:o2","objectName":"Opportunity","label":"Edge Installation"},{"key":"o3","recordId":"record-id:o3","objectName":"Opportunity","label":"Edge SLA"}]}';
    private static final String FIX_SECTION_ERROR =
        '{"type":"section","version":1,"key":"sec-calls","title":"Calls","status":"ERROR","text":"Calls\\nCouldn\'t load Calls right now.","body":[{"kind":"p","runs":[{"text":"Couldn\'t load Calls right now."}]}],"total":0,"shown":0,"items":[],"refs":[]}';
    private static final String FIX_TEXT =
        '{"type":"text","version":1,"key":"ans","title":"","status":"OK","text":"There are 212 open opportunities; the 6 largest are below. The top one is Edge Emergency Generator, at $250,000.","body":[{"kind":"p","runs":[{"text":"There are "},{"text":"212","strong":true},{"text":" open opportunities; the 6 largest are below. The top one is "},{"text":"Edge Emergency Generator","ref":"o1"},{"text":", at "},{"text":"$250,000","code":true},{"text":"."}]}],"refs":[{"key":"o1","recordId":"record-id:o1","objectName":"Opportunity","label":"Edge Emergency Generator"}]}';
    private static final String FIX_TABLE =
        '{"type":"table","version":1,"key":"tbl","title":"Opportunity","status":"OK","text":"Opportunity\\nName | Stage | Amount | Close date\\nEdge Emergency Generator | Proposal | $250,000 | 2026-12-18\\nJuniper Project B | Negotiation | $180,000 | 2026-12-04\\nFernhollow Project C | Proposal | $160,000 | 2027-01-12\\nEdge Installation | Negotiation | $112,000 | 2027-01-30\\nPimble Project B | Qualification | $95,000 | 2027-02-20\\nEdge SLA | Qualification | $50,000 | 2027-03-02\\n(6 of 212 rows)","body":[],"columns":[{"key":"Name","label":"Name","kind":"text"},{"key":"StageName","label":"Stage","kind":"text"},{"key":"Amount","label":"Amount","kind":"currency"},{"key":"CloseDate","label":"Close date","kind":"date"}],"rows":[{"ref":"o1","cells":["Edge Emergency Generator","Proposal","$250,000","2026-12-18"]},{"ref":"o4","cells":["Juniper Project B","Negotiation","$180,000","2026-12-04"]},{"ref":"o5","cells":["Fernhollow Project C","Proposal","$160,000","2027-01-12"]},{"ref":"o2","cells":["Edge Installation","Negotiation","$112,000","2027-01-30"]},{"ref":"o6","cells":["Pimble Project B","Qualification","$95,000","2027-02-20"]},{"ref":"o3","cells":["Edge SLA","Qualification","$50,000","2027-03-02"]}],"total":212,"shown":6,"refs":[{"key":"o1","recordId":"record-id:o1","objectName":"Opportunity","label":"Edge Emergency Generator"},{"key":"o4","recordId":"record-id:o4","objectName":"Opportunity","label":"Juniper Project B"},{"key":"o5","recordId":"record-id:o5","objectName":"Opportunity","label":"Fernhollow Project C"},{"key":"o2","recordId":"record-id:o2","objectName":"Opportunity","label":"Edge Installation"},{"key":"o6","recordId":"record-id:o6","objectName":"Opportunity","label":"Pimble Project B"},{"key":"o3","recordId":"record-id:o3","objectName":"Opportunity","label":"Edge SLA"}]}';
    private static final String FIX_METRIC =
        '{"type":"metric","version":1,"key":"met","title":"Open pipeline","status":"OK","text":"Open pipeline\\nOpen opportunities: 212 — in your access\\nTotal amount: $18.4M\\nClosing this quarter: 37","body":[],"items":[{"label":"Open opportunities","value":"212","detail":"in your access"},{"label":"Total amount","value":"$18.4M"},{"label":"Closing this quarter","value":"37"}],"refs":[]}';
    private static final String FIX_RECORD =
        '{"type":"record","version":1,"key":"rec","title":"Edge Emergency Generator","meta":"Opportunity","status":"OK","text":"Edge Emergency Generator · Opportunity\\nAccount: Edge Communications\\nStage: Proposal\\nAmount: $250,000\\nClose date: 2026-12-18\\nOwner: Seller One","body":[],"fields":[{"key":"AccountId","label":"Account","value":"Edge Communications","ref":"a1"},{"key":"StageName","label":"Stage","value":"Proposal"},{"key":"Amount","label":"Amount","value":"$250,000"},{"key":"CloseDate","label":"Close date","value":"2026-12-18"},{"key":"OwnerId","label":"Owner","value":"Seller One"}],"items":[{"label":"Tasks","kind":"related"},{"label":"Events","kind":"related"},{"label":"Opportunity Contact Roles","kind":"related"}],"refs":[{"key":"a1","recordId":"record-id:a1","objectName":"Account","label":"Edge Communications"}]}';
    private static final String FIX_RECORD_LIST =
        '{"type":"recordList","version":1,"key":"lst","title":"Contacts never called","status":"OK","text":"Contacts never called\\n- Contact One — VP Facilities\\n- Contact Two — Procurement lead\\n- Contact Three — IT director\\n(3 of 4)","body":[],"total":4,"shown":3,"items":[{"label":"Contact One","detail":"VP Facilities","ref":"c1"},{"label":"Contact Two","detail":"Procurement lead","ref":"c2"},{"label":"Contact Three","detail":"IT director","ref":"c3"}],"refs":[{"key":"c1","recordId":"record-id:c1","objectName":"Contact","label":"Contact One"},{"key":"c2","recordId":"record-id:c2","objectName":"Contact","label":"Contact Two"},{"key":"c3","recordId":"record-id:c3","objectName":"Contact","label":"Contact Three"}]}';
    private static final String FIX_TIMELINE =
        '{"type":"timeline","version":1,"key":"tml","title":"Recent activity","status":"OK","text":"Recent activity\\n2026-11-10 · Call: renewal check-in — Seller One\\n2026-11-04 · Email: revised proposal sent — Seller One\\n2026-10-28 · Case comment: generator fault — Support","body":[],"items":[{"at":"2026-11-10","kind":"call","label":"Call: renewal check-in","detail":"Seller One","ref":"t1"},{"at":"2026-11-04","kind":"email","label":"Email: revised proposal sent","detail":"Seller One","ref":"t2"},{"at":"2026-10-28","kind":"case","label":"Case comment: generator fault","detail":"Support","ref":"k1"}],"refs":[{"key":"t1","recordId":"record-id:t1","objectName":"Task","label":"Call: renewal check-in"},{"key":"t2","recordId":"record-id:t2","objectName":"Task","label":"Email: revised proposal sent"},{"key":"k1","recordId":"record-id:k1","objectName":"Case","label":"Generator fault"}]}';
    private static final String FIX_COMPARISON =
        '{"type":"comparison","version":1,"key":"cmp","title":"Two largest open deals","status":"OK","text":"Two largest open deals\\nField | Edge Emergency Generator | Juniper Project B\\nStage | Proposal | Negotiation\\nAmount | $250,000 | $180,000\\nClose date | 2026-12-18 | 2026-12-04\\nLast activity | 3 days ago | 19 days ago","body":[],"columns":[{"key":"field","label":"Field","kind":"text"},{"key":"o1","label":"Edge Emergency Generator","kind":"text"},{"key":"o4","label":"Juniper Project B","kind":"text"}],"rows":[{"cells":["Stage","Proposal","Negotiation"]},{"cells":["Amount","$250,000","$180,000"]},{"cells":["Close date","2026-12-18","2026-12-04"]},{"cells":["Last activity","3 days ago","19 days ago"]}],"refs":[]}';
    private static final String FIX_CHOICE =
        '{"type":"choice","version":1,"key":"cho","title":"More than one account matches \\"edge\\". Which one?","status":"AMBIGUOUS","text":"More than one account matches \\"edge\\". Which one?\\n1. Edge Communications — Austin\\n2. Edge Communications — Toronto\\n3. Edgewater Freight — Portland","body":[],"items":[{"label":"Edge Communications","detail":"Austin","ref":"a1"},{"label":"Edge Communications","detail":"Toronto","ref":"a2"},{"label":"Edgewater Freight","detail":"Portland","ref":"a3"}],"refs":[{"key":"a1","recordId":"record-id:a1","objectName":"Account","label":"Edge Communications"},{"key":"a2","recordId":"record-id:a2","objectName":"Account","label":"Edge Communications"},{"key":"a3","recordId":"record-id:a3","objectName":"Account","label":"Edgewater Freight"}]}';
    private static final String FIX_FOLLOWUPS =
        '{"type":"followups","version":1,"key":"fol","title":"Ask next","text":"Ask next\\n- Which of these close this quarter?\\n- Who on their side have we not called?\\n- Show the open cases","body":[],"items":[{"label":"Which of these close this quarter?"},{"label":"Who on their side have we not called?"},{"label":"Show the open cases"}],"refs":[]}';
    private static final String FIX_TRAIL =
        '{"type":"trail","version":1,"key":"trl","title":"Ran 2 queries","text":"Ran 2 queries\\n1. Opportunity where IsClosed = false: COUNT() — 212 rows\\n2. Opportunity where IsClosed = false, by Amount descending, first 6 — 6 of 212 rows","body":[],"items":[{"label":"Opportunity where IsClosed = false: COUNT()","detail":"212 rows"},{"label":"Opportunity where IsClosed = false, by Amount descending, first 6","detail":"6 of 212 rows"}],"refs":[]}';
    private static final String FIX_NOTICE =
        '{"type":"notice","version":1,"key":"not","title":"","status":"OK","text":"Showing 50 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it.","body":[{"kind":"p","runs":[{"text":"Showing 50 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it."}]}],"refs":[]}';
    private static final String FIX_ERROR =
        '{"type":"error","version":1,"key":"err","title":"","status":"ERROR","text":"I couldn\'t finish that right now. Try again in a minute.","body":[{"kind":"p","runs":[{"text":"I couldn\'t finish that right now. Try again in a minute."}]}],"refs":[]}';
    private static final String FIX_ACTION_DRAFT =
        '{"type":"actionDraft","version":1,"key":"drf","title":"Create a task","meta":"Task · create","status":"NEEDS_INPUT","text":"Create a task · Task · create\\nSubject: Follow up on the generator proposal\\nDue: 2026-11-17\\nContact: Jordan (choose one)\\nRelated to: Edge Emergency Generator\\nPriority: (needed)\\nNote: Two contacts match \\"Jordan\\"; choose one or clear the field.\\nOptions: Confirm, Edit, Cancel","body":[],"fields":[{"key":"Subject","label":"Subject","value":"Follow up on the generator proposal"},{"key":"ActivityDate","label":"Due","value":"2026-11-17"},{"key":"WhoId","label":"Contact","value":"Jordan","state":"choose","choices":["c1","c4"]},{"key":"WhatId","label":"Related to","value":"Edge Emergency Generator","ref":"o1"},{"key":"Priority","label":"Priority","value":"","state":"missing"}],"items":[{"label":"Two contacts match \\"Jordan\\"; choose one or clear the field."}],"controls":[{"key":"confirm","label":"Confirm","kind":"primary"},{"key":"edit","label":"Edit","kind":"neutral"},{"key":"cancel","label":"Cancel","kind":"link"}],"refs":[{"key":"c1","recordId":"record-id:c1","objectName":"Contact","label":"Jordan Lee"},{"key":"c4","recordId":"record-id:c4","objectName":"Contact","label":"Jordan Park"},{"key":"o1","recordId":"record-id:o1","objectName":"Opportunity","label":"Edge Emergency Generator"}]}';
    private static final String FIX_ACTION_RESULT =
        '{"type":"actionResult","version":1,"key":"res","title":"Task created","meta":"Task","status":"OK","text":"Task created · Task\\nSubject: Follow up on the generator proposal\\nDue: 2026-11-17\\nContact: Jordan Lee\\nSaved as you, with your access. Undo is offered for 15 seconds after an update.","body":[{"kind":"p","runs":[{"text":"Saved as you, with your access. Undo is offered for 15 seconds after an update."}]}],"fields":[{"key":"Subject","label":"Subject","value":"Follow up on the generator proposal","ref":"t9"},{"key":"ActivityDate","label":"Due","value":"2026-11-17"},{"key":"WhoId","label":"Contact","value":"Jordan Lee"}],"controls":[{"key":"open","label":"Open task","kind":"primary"}],"refs":[{"key":"t9","recordId":"record-id:t9","objectName":"Task","label":"Follow up on the generator proposal"}]}';

    private static Id fakeId(Schema.SObjectType t, Integer n) {
        return Id.valueOf(t.getDescribe().getKeyPrefix() + String.valueOf(n).leftPad(12, '0'));
    }

    private static AnswerCard.Ref ref(String key, String objectName, String label) {
        return AnswerCard.newRef(key, 'record-id:' + key, objectName, label);
    }

    private static AnswerCard.Item item(String label, String value, String detail, String ref) {
        return AnswerCard.newItem(label, value, detail, ref);
    }

    /** The built card equals the page's fixture, Ids aside; its text is its type's rule; its version is 1. */
    private static void assertMatchesFixture(String fixture, AnswerCard built) {
        String cardJson = JSON.serialize(built, true);
        for (AnswerCard.Ref r : built.refs) {
            if (r.recordId != null && !r.recordId.startsWith('record-id:')) {
                Assert.isFalse(built.text.contains(r.recordId), 'the text never holds a record Id: ' + built.text);
                Assert.areEqual(1, cardJson.countMatches(r.recordId), 'a record Id appears only in refs: ' + cardJson);
            }
            r.recordId = 'record-id:' + r.key;
        }
        String expected = JSON.serialize(JSON.deserialize(fixture, AnswerCard.class), true);
        Assert.areEqual(expected, JSON.serialize(built, true), 'the ' + built.type + ' card equals FE-18\'s fixture, Ids aside');
        Assert.areEqual(1, built.version, 'version 1 for every type today');
        Assert.areEqual(AnswerCard.plainText(built), built.text, 'the text is the rule for ' + built.type);
        Assert.isTrue(String.isNotBlank(built.text), 'every card carries its plain-text fallback');
    }

    // ------------------------------------------------------------------ one test per card type

    @IsTest
    static void summaryIsTheHeadlineAsTitleAndTheRestAsRuns() {
        String answer = 'Edge Communications: steady service, one large renewal at risk\n'
            + '**Open deals:** 3 worth $412,000; the largest closes this quarter.\n'
            + '**Service health:** 2 open cases, one *high priority* for 9 days.\n'
            + '- Renewal owner has not logged a call in 41 days\n'
            + '- Two contacts on their side have never been called';
        assertMatchesFixture(FIX_SUMMARY, AnswerCard.summary('sum', 'OK', answer));
    }

    @IsTest
    static void sectionListsItsRecordsAsItemsWithTheirIdsInRefs() {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = 'deals';
        s.title = 'Open deals';
        s.status = CustomerSummarySection.OK;
        s.total = 3;
        s.shown = 3;
        s.body = String.join(new List<String>{
            CustomerSummarySection.withId('- Edge Emergency Generator — Proposal — $250,000 — closes 2026-12-18', fakeId(Opportunity.SObjectType, 1)),
            CustomerSummarySection.withId('- Edge Installation — Negotiation — $112,000 — closes 2027-01-30', fakeId(Opportunity.SObjectType, 2)),
            CustomerSummarySection.withId('- Edge SLA — Qualification — $50,000 — closes 2027-03-02', fakeId(Opportunity.SObjectType, 3))
        }, '\n');
        assertMatchesFixture(FIX_SECTION, AnswerCard.section(s));
    }

    @IsTest
    static void aFailedSectionIsASectionCardWithItsFixedMessage() {
        CustomerSummarySection s = CustomerSummarySection.failed('calls', 'Calls', new DmlException('boom'));
        AnswerCard c = AnswerCard.section(s);
        assertMatchesFixture(FIX_SECTION_ERROR, c);
        Assert.isFalse(JSON.serialize(c).contains('boom'), 'the cause never reaches a card');
    }

    @IsTest
    static void textParsesTheAnswerIntoRunsWithLinksByRef() {
        String answer = 'There are **212** open opportunities; the 6 largest are below. The top one is '
            + '[Edge Emergency Generator](ref:o1), at `$250,000`.';
        AnswerCard c = AnswerCard.text('ans', 'OK', answer, new List<AnswerCard.Ref>{ ref('o1', 'Opportunity', 'Edge Emergency Generator') });
        assertMatchesFixture(FIX_TEXT, c);
    }

    @IsTest
    static void tableHoldsFormattedCellsAndItsCounts() {
        List<AnswerCard.Column> columns = new List<AnswerCard.Column>{
            AnswerCard.newColumn('Name', 'Name', 'text'),
            AnswerCard.newColumn('StageName', 'Stage', 'text'),
            AnswerCard.newColumn('Amount', 'Amount', 'currency'),
            AnswerCard.newColumn('CloseDate', 'Close date', 'date')
        };
        List<List<String>> data = new List<List<String>>{
            new List<String>{ 'o1', 'Edge Emergency Generator', 'Proposal', '$250,000', '2026-12-18' },
            new List<String>{ 'o4', 'Juniper Project B', 'Negotiation', '$180,000', '2026-12-04' },
            new List<String>{ 'o5', 'Fernhollow Project C', 'Proposal', '$160,000', '2027-01-12' },
            new List<String>{ 'o2', 'Edge Installation', 'Negotiation', '$112,000', '2027-01-30' },
            new List<String>{ 'o6', 'Pimble Project B', 'Qualification', '$95,000', '2027-02-20' },
            new List<String>{ 'o3', 'Edge SLA', 'Qualification', '$50,000', '2027-03-02' }
        };
        List<AnswerCard.Row> rows = new List<AnswerCard.Row>();
        List<AnswerCard.Ref> refs = new List<AnswerCard.Ref>();
        for (List<String> d : data) {
            rows.add(AnswerCard.newRow(d[0], new List<String>{ d[1], d[2], d[3], d[4] }));
            refs.add(ref(d[0], 'Opportunity', d[1]));
        }
        AnswerCard c = AnswerCard.table('tbl', 'Opportunity', columns, rows, 212, refs);
        assertMatchesFixture(FIX_TABLE, c);
        Assert.areEqual(6, c.shown, 'shown is the rows the card holds');
    }

    @IsTest
    static void metricLeadsWithItsFirstFigure() {
        AnswerCard c = AnswerCard.metric('met', 'Open pipeline', new List<AnswerCard.Item>{
            item('Open opportunities', '212', 'in your access', null),
            item('Total amount', '$18.4M', null, null),
            item('Closing this quarter', '37', null, null)
        });
        assertMatchesFixture(FIX_METRIC, c);
    }

    @IsTest
    static void recordHoldsFieldsLookupsAsLinksAndRelatedObjects() {
        AnswerCard c = AnswerCard.record('rec', 'Edge Emergency Generator', 'Opportunity',
            new List<AnswerCard.Field>{
                AnswerCard.newField('AccountId', 'Account', 'Edge Communications', 'a1'),
                AnswerCard.newField('StageName', 'Stage', 'Proposal', null),
                AnswerCard.newField('Amount', 'Amount', '$250,000', null),
                AnswerCard.newField('CloseDate', 'Close date', '2026-12-18', null),
                AnswerCard.newField('OwnerId', 'Owner', 'Seller One', null)
            },
            new List<String>{ 'Tasks', 'Events', 'Opportunity Contact Roles' },
            new List<AnswerCard.Ref>{ ref('a1', 'Account', 'Edge Communications') });
        assertMatchesFixture(FIX_RECORD, c);
    }

    @IsTest
    static void recordListEndsOnItsCountWhenCut() {
        AnswerCard c = AnswerCard.recordList('lst', 'Contacts never called', new List<AnswerCard.Item>{
            item('Contact One', null, 'VP Facilities', 'c1'),
            item('Contact Two', null, 'Procurement lead', 'c2'),
            item('Contact Three', null, 'IT director', 'c3')
        }, 4, new List<AnswerCard.Ref>{
            ref('c1', 'Contact', 'Contact One'), ref('c2', 'Contact', 'Contact Two'), ref('c3', 'Contact', 'Contact Three')
        });
        assertMatchesFixture(FIX_RECORD_LIST, c);
    }

    @IsTest
    static void timelineLinesLeadWithTheirDate() {
        List<AnswerCard.Item> items = new List<AnswerCard.Item>{
            item('Call: renewal check-in', null, 'Seller One', 't1'),
            item('Email: revised proposal sent', null, 'Seller One', 't2'),
            item('Case comment: generator fault', null, 'Support', 'k1')
        };
        List<String> ats = new List<String>{ '2026-11-10', '2026-11-04', '2026-10-28' };
        List<String> kinds = new List<String>{ 'call', 'email', 'case' };
        for (Integer i = 0; i < items.size(); i++) {
            items[i].at = ats[i];
            items[i].kind = kinds[i];
        }
        AnswerCard c = AnswerCard.timeline('tml', 'Recent activity', items, new List<AnswerCard.Ref>{
            ref('t1', 'Task', 'Call: renewal check-in'), ref('t2', 'Task', 'Email: revised proposal sent'), ref('k1', 'Case', 'Generator fault')
        });
        assertMatchesFixture(FIX_TIMELINE, c);
    }

    @IsTest
    static void comparisonIsAGridWithTheFieldFirst() {
        AnswerCard c = AnswerCard.comparison('cmp', 'Two largest open deals',
            new List<AnswerCard.Column>{
                AnswerCard.newColumn('field', 'Field', 'text'),
                AnswerCard.newColumn('o1', 'Edge Emergency Generator', 'text'),
                AnswerCard.newColumn('o4', 'Juniper Project B', 'text')
            },
            new List<AnswerCard.Row>{
                AnswerCard.newRow(null, new List<String>{ 'Stage', 'Proposal', 'Negotiation' }),
                AnswerCard.newRow(null, new List<String>{ 'Amount', '$250,000', '$180,000' }),
                AnswerCard.newRow(null, new List<String>{ 'Close date', '2026-12-18', '2026-12-04' }),
                AnswerCard.newRow(null, new List<String>{ 'Last activity', '3 days ago', '19 days ago' })
            },
            new List<AnswerCard.Ref>());
        assertMatchesFixture(FIX_COMPARISON, c);
    }

    @IsTest
    static void choiceNumbersItsCandidatesAndIsAmbiguous() {
        AnswerCard c = AnswerCard.choice('cho', 'More than one account matches "edge". Which one?', new List<AnswerCard.Item>{
            item('Edge Communications', null, 'Austin', 'a1'),
            item('Edge Communications', null, 'Toronto', 'a2'),
            item('Edgewater Freight', null, 'Portland', 'a3')
        }, new List<AnswerCard.Ref>{
            ref('a1', 'Account', 'Edge Communications'), ref('a2', 'Account', 'Edge Communications'), ref('a3', 'Account', 'Edgewater Freight')
        });
        assertMatchesFixture(FIX_CHOICE, c);
    }

    @IsTest
    static void followupsAreChipsUnderAskNext() {
        AnswerCard c = AnswerCard.followups('fol', new List<String>{
            'Which of these close this quarter?', 'Who on their side have we not called?', 'Show the open cases'
        });
        assertMatchesFixture(FIX_FOLLOWUPS, c);
    }

    @IsTest
    static void trailCountsItsQueries() {
        AnswerCard c = AnswerCard.trail('trl', new List<AnswerCard.Item>{
            item('Opportunity where IsClosed = false: COUNT()', null, '212 rows', null),
            item('Opportunity where IsClosed = false, by Amount descending, first 6', null, '6 of 212 rows', null)
        });
        assertMatchesFixture(FIX_TRAIL, c);
        Assert.areEqual('Ran 1 query', AnswerCard.trail('t', new List<AnswerCard.Item>{ item('Account', null, '1 rows', null) }).title);
    }

    @IsTest
    static void noticeIsOneSentence() {
        AnswerCard c = AnswerCard.notice('not', 'OK', 'Showing 50 of 212 rows. Ask with a filter, such as a stage or a close date, to narrow it.');
        assertMatchesFixture(FIX_NOTICE, c);
    }

    @IsTest
    static void errorCarriesTheFixedMessage() {
        assertMatchesFixture(FIX_ERROR, AnswerCard.error('err', 'I couldn\'t finish that right now. Try again in a minute.'));
    }

    /** AnswerCard builds neither action card (BE-27 fills them); its types hold both, and its text rule matches. */
    @IsTest
    static void theActionDraftAndResultFitTheTypesAndTheirTextRules() {
        for (String fixture : new List<String>{ FIX_ACTION_DRAFT, FIX_ACTION_RESULT }) {
            AnswerCard c = (AnswerCard) JSON.deserialize(fixture, AnswerCard.class);
            Assert.areEqual(AnswerCard.plainText(c), c.text, 'the ' + c.type + ' text rule matches FE-18\'s fixture');
            Assert.areEqual(JSON.serialize(JSON.deserializeUntyped(fixture)).length(), JSON.serialize(c, true).length(),
                'every member of the ' + c.type + ' fixture survives the typed round trip');
        }
        AnswerCard draft = (AnswerCard) JSON.deserialize(FIX_ACTION_DRAFT, AnswerCard.class);
        Assert.areEqual('choose', draft.fields[2].state);
        Assert.areEqual(new List<String>{ 'c1', 'c4' }, draft.fields[2].choices);
        Assert.areEqual('primary', draft.controls[0].kind);
    }

    // ------------------------------------------------------------------ rich text: every row of the page's table

    private static void assertRuns(String source, String expectedRuns) {
        List<AnswerCard.Ref> refs = new List<AnswerCard.Ref>{ ref('o3', 'Opportunity', 'Edge SLA') };
        List<AnswerCard.Block> blocks = AnswerCard.parse(source, refs);
        Assert.areEqual(1, blocks.size(), source);
        Assert.areEqual('p', blocks[0].kind, source);
        Assert.areEqual(expectedRuns, JSON.serialize(blocks[0].runs, true), 'runs of: ' + source);
    }

    @IsTest
    static void plainWordsAreOnePlainRun() {
        assertRuns('plain words', '[{"text":"plain words"}]');
    }

    @IsTest
    static void boldAndItalicAreStrongAndEmRuns() {
        assertRuns('**212** open, *high priority*', '[{"text":"212","strong":true},{"text":" open, "},{"text":"high priority","em":true}]');
    }

    @IsTest
    static void aLoneStarIsLiteral() {
        assertRuns('5 * 3 = 15', '[{"text":"5 * 3 = 15"}]');
        assertRuns('2 * 3 * 4', '[{"text":"2 * 3 * 4"}]');
    }

    @IsTest
    static void backticksAreACodeRun() {
        assertRuns('costs `$250,000`', '[{"text":"costs "},{"text":"$250,000","code":true}]');
    }

    @IsTest
    static void aRefLinkIsALinkRunOnlyWhenTheCardCarriesTheRef() {
        assertRuns('[Edge SLA](ref:o3)', '[{"text":"Edge SLA","ref":"o3"}]');
        assertRuns('[Edge SLA](ref:zz)', '[{"text":"Edge SLA"}]');
    }

    @IsTest
    static void otherLinksHtmlAndUnclosedMarkersAreLiteral() {
        assertRuns('[site](https://example.com)', '[{"text":"[site](https://example.com)"}]');
        assertRuns('<b>x</b>', '[{"text":"<b>x</b>"}]');
        assertRuns('**unclosed', '[{"text":"**unclosed"}]');
    }

    @IsTest
    static void linesBecomeParagraphsBulletsAndNumberedItems() {
        List<AnswerCard.Block> blocks = AnswerCard.parse('First line\n\n- one\n• two\n1. three\n2) four\n   plain   \n', new List<AnswerCard.Ref>());
        List<String> kinds = new List<String>();
        for (AnswerCard.Block b : blocks) {
            kinds.add(b.kind);
        }
        Assert.areEqual(new List<String>{ 'p', 'li', 'li', 'ol', 'ol', 'p' }, kinds);
        AnswerCard c = AnswerCard.text('t', 'OK', 'First line\n\n- one\n• two\n1. three\n2) four\n   plain   ', new List<AnswerCard.Ref>());
        Assert.areEqual('First line\n- one\n- two\n1. three\n2. four\nplain', c.text);
        Assert.isTrue(AnswerCard.parse(null, null).isEmpty(), 'no text, no blocks');
    }

    // ------------------------------------------------------------------ sections from real section text

    @IsTest
    static void aSectionKeepsItsItemsToTheShownRecordsAndEveryIdInRefs() {
        Id deal1 = fakeId(Opportunity.SObjectType, 1);
        Id deal2 = fakeId(Opportunity.SObjectType, 2);
        Id contact = fakeId(Contact.SObjectType, 1);
        Id meeting = fakeId(Event.SObjectType, 1);
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = 'open_deals';
        s.title = 'Open deals';
        s.status = CustomerSummarySection.OK;
        s.total = 5;
        s.shown = 2;
        s.body = String.join(new List<String>{
            '5 open, $3,000 total pipeline, 0 overdue',
            CustomerSummarySection.withId('- Deal A — Prospecting — $1,000 — closes 2026-12-01 — owner Pat', deal1),
            CustomerSummarySection.withId(' • Jordan Lee (Decision Maker)', contact),
            CustomerSummarySection.withId('- Deal B — Proposal — $2,000 — closes 2027-01-01 — owner Pat', deal2),
            '- …and 3 more not shown',
            'Left out because you can\'t see these fields: Call notes.',
            CustomerSummarySection.withId('Next: 2026-11-20 — Review', meeting)
        }, '\n');

        AnswerCard c = AnswerCard.section(s);

        Assert.areEqual('sec-open_deals', c.key);
        Assert.areEqual(5, c.total);
        Assert.areEqual(2, c.shown);
        Assert.areEqual(s.shown, c.items.size(), 'one item per record the section shows');
        Assert.areEqual('Deal A', c.items[0].label);
        Assert.areEqual('Prospecting · $1,000 · closes 2026-12-01 · owner Pat', c.items[0].detail);
        Assert.areEqual('o1', c.items[0].ref);
        Assert.areEqual('Deal B', c.items[1].label);
        Assert.areEqual('o2', c.items[1].ref);
        Assert.areEqual(4, c.refs.size(), 'every record the section names has a ref');
        Assert.areEqual('Contact', c.refs[1].objectName);
        Assert.areEqual('Jordan Lee (Decision Maker)', c.refs[1].label);
        Assert.areEqual('Event', c.refs[3].objectName);
        Assert.areEqual(4, c.body.size(), 'the header, the contact line, the left-out line and the Next line');
        Assert.areEqual('5 open, $3,000 total pipeline, 0 overdue', c.body[0].runs[0].text);
        Assert.areEqual('li', c.body[1].kind);
        Assert.areEqual('c1', c.body[1].runs[0].ref);
        Assert.areEqual('Next: 2026-11-20 — Review', c.body[3].runs[0].text);
        Assert.areEqual('Open deals (2 of 5)\n- Deal A — Prospecting · $1,000 · closes 2026-12-01 · owner Pat\n'
            + '- Deal B — Proposal · $2,000 · closes 2027-01-01 · owner Pat', c.text);
        String cardJson = JSON.serialize(c, true);
        for (Id i : new List<Id>{ deal1, deal2, contact, meeting }) {
            Assert.areEqual(1, cardJson.countMatches(String.valueOf(i)), 'each Id appears once, in refs: ' + cardJson);
            Assert.isFalse(c.text.contains(String.valueOf(i)));
        }
    }

    @IsTest
    static void aSectionWithNoRecordsShowsItsLines() {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = 'contacts';
        s.title = 'Contacts';
        s.status = CustomerSummarySection.EMPTY;
        s.body = 'No contacts on this account.';
        AnswerCard c = AnswerCard.section(s);
        Assert.areEqual('EMPTY', c.status);
        Assert.areEqual('Contacts\nNo contacts on this account.', c.text);
        Assert.isTrue(c.items.isEmpty());
        Assert.isNull(AnswerCard.section(null), 'no section, no card');
    }

    @IsTest
    static void sectionDataIsNeverParsedAsMarkup() {
        CustomerSummarySection s = new CustomerSummarySection();
        s.key = 'profile';
        s.title = 'Account';
        s.status = CustomerSummarySection.OK;
        s.total = 1;
        s.shown = 1;
        s.body = 'Description: **not bold** and [x](ref:o1)';
        AnswerCard c = AnswerCard.section(s);
        Assert.areEqual(1, c.body[0].runs.size(), 'record data is literal text, never rich text');
        Assert.areEqual('Description: **not bold** and [x](ref:o1)', c.body[0].runs[0].text);
        Assert.isNull(c.body[0].runs[0].strong);
    }

    // ------------------------------------------------------------------ refs, JSON and its cap

    @IsTest
    static void refKeysAreTheObjectsLetterAndOneKeyPerRecord() {
        List<AnswerCard.Ref> refs = new List<AnswerCard.Ref>();
        Id contact = fakeId(Contact.SObjectType, 1);
        Assert.areEqual('c1', AnswerCard.addRef(refs, contact, 'Jordan'));
        Assert.areEqual('c2', AnswerCard.addRef(refs, fakeId(Case.SObjectType, 1), '00001001'));
        Assert.areEqual('c1', AnswerCard.addRef(refs, contact, 'Jordan again'), 'the same record keeps its key');
        Assert.areEqual('o1', AnswerCard.addRef(refs, fakeId(Opportunity.SObjectType, 1), 'Deal'));
        Assert.areEqual(3, refs.size());
        Assert.areEqual('Case', refs[1].objectName);
        Assert.isNull(AnswerCard.addRef(refs, null, 'nothing'), 'no Id, no ref');
    }

    @IsTest
    static void cardsJsonParsesBackToTheSameCards() {
        List<AnswerCard> cards = new List<AnswerCard>{
            AnswerCard.summary('sum', 'OK', 'Headline\n**Bold** line\n- a bullet'),
            AnswerCard.error('err', 'Fixed line.'),
            AnswerCard.followups('fol', new List<String>{ 'Next?' })
        };
        String cardJson = AnswerCard.toJson(cards);
        List<AnswerCard> back = AnswerCard.fromJson(cardJson);
        Assert.areEqual(3, back.size());
        Assert.areEqual(cardJson, AnswerCard.toJson(back), 'the JSON parses back to the same cards');
        Assert.areEqual('summary', back[0].type);
        Assert.areEqual(true, back[0].body[0].runs[0].strong);
        Assert.areEqual('[]', AnswerCard.toJson(null));
        Assert.isTrue(AnswerCard.fromJson('').isEmpty());
        Assert.isTrue(AnswerCard.fromJson('not json').isEmpty(), 'unreadable JSON gives no cards, never an exception');
    }

    @IsTest
    static void cardsOverTheCapGiveEmptyJsonNeverCutJson() {
        String big = 'x'.repeat(AnswerCard.MAX_JSON_CHARS);
        String cardJson = AnswerCard.toJson(new List<AnswerCard>{ AnswerCard.text('ans', 'OK', big, null) });
        Assert.areEqual('', cardJson, 'over the cap the cards output is empty');
        String fits = AnswerCard.toJson(new List<AnswerCard>{ AnswerCard.text('ans', 'OK', 'x'.repeat(1000), null) });
        Assert.isTrue(fits.startsWith('[') && fits.endsWith(']'), fits.left(40));
    }

    @IsTest
    static void plainTextOfAnUnknownTypeIsItsOwnText() {
        AnswerCard c = new AnswerCard();
        c.type = 'gauge';
        c.text = 'Kept as is';
        Assert.areEqual('Kept as is', AnswerCard.plainText(c));
        Assert.areEqual('', AnswerCard.plainText(null));
    }
}
