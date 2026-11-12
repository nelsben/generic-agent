@IsTest
private class AccountBriefAgentClientTest {
    private static final String FAILURE_TEXT = 'The agent could not answer right now. Try again in a minute.';
    private static final String SESSION = '00000000-0000-4000-8000-000000000001';

    /** Scripted agent: records every call and answers from a queue; never reaches the action. */
    private class FakeAgent implements AccountBriefAgentClient.Transport {
        List<String> messages = new List<String>();
        List<String> sessions = new List<String>();
        List<Object> replies = new List<Object>();
        String sessionToReturn = SESSION;
        Exception failure;

        public Map<String, Object> send(String userMessage, String sessionId) {
            messages.add(userMessage);
            sessions.add(sessionId);
            if (failure != null) {
                throw failure;
            }
            Object reply = replies.isEmpty() ? envelope('Default reply.') : replies.remove(0);
            return new Map<String, Object>{ 'agentResponse' => reply, 'sessionId' => sessionToReturn };
        }
    }

    private class AgentTestException extends Exception {}

    private static String envelope(String value) {
        return JSON.serialize(new Map<String, Object>{ 'type' => 'Text', 'value' => value });
    }

    private static FakeAgent fake() {
        FakeAgent f = new FakeAgent();
        AccountBriefAgentClient.transport = f;
        return f;
    }

    @IsTest
    static void unwrapsTheTypeValueEnvelope() {
        FakeAgent f = fake();
        f.replies.add(envelope('Five open deals.\nTwo are overdue.'));

        Test.startTest();
        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('What are the open deals?', null, null);
        Test.stopTest();

        Assert.areEqual('Five open deals.\nTwo are overdue.', r.text);
        Assert.areEqual(SESSION, r.sessionId);
        Assert.isFalse(r.failed);
    }

    @IsTest
    static void keepsAPlainReplyThatIsNotAnEnvelope() {
        FakeAgent f = fake();
        f.replies.add('Plain reply, not JSON.');

        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('Hello', null, null);

        Assert.areEqual('Plain reply, not JSON.', r.text);
        Assert.isFalse(r.failed);
    }

    @IsTest
    static void anExceptionBecomesTheFixedFailureText() {
        FakeAgent f = fake();
        String raw = 'INVALID_SESSION_ID raw platform text';
        f.failure = new AgentTestException(raw);

        Test.startTest();
        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('What are the open deals?', SESSION, null);
        Test.stopTest();

        Assert.areEqual(FAILURE_TEXT, r.text);
        Assert.isTrue(r.failed);
        Assert.isNull(r.sessionId, 'a failed turn hands back no session');
        Assert.isFalse(r.text.contains(raw), 'raw exception text leaked');
    }

    @IsTest
    static void aBlankReplyBecomesTheFixedFailureText() {
        FakeAgent f = fake();
        f.replies.add(envelope('   '));

        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('Hello', null, null);

        Assert.areEqual(FAILURE_TEXT, r.text);
        Assert.isTrue(r.failed);
    }

    @IsTest
    static void aNullReplyBecomesTheFixedFailureText() {
        FakeAgent f = fake();
        f.replies.add(null);

        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('Hello', null, null);

        Assert.areEqual(FAILURE_TEXT, r.text);
        Assert.isTrue(r.failed);
    }

    @IsTest
    static void aBlankMessageNeverReachesTheAgent() {
        FakeAgent f = fake();

        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('  ', null, null);

        Assert.areEqual(FAILURE_TEXT, r.text);
        Assert.isTrue(r.failed);
        Assert.areEqual(0, f.messages.size());
    }

    @IsTest
    static void aFollowUpReusesTheSessionItIsGiven() {
        FakeAgent f = fake();
        f.replies.add(envelope('Five open deals.'));
        f.replies.add(envelope('Five open cases.'));

        Test.startTest();
        AccountBriefAgentClient.Reply first = AccountBriefAgentClient.ask('What are the open deals?', null, null);
        AccountBriefAgentClient.Reply second = AccountBriefAgentClient.ask('What about their open cases?', first.sessionId, null);
        Test.stopTest();

        Assert.areEqual(2, f.sessions.size());
        Assert.isNull(f.sessions[0], 'the first turn starts a new session');
        Assert.areEqual(SESSION, f.sessions[1], 'the follow-up sends the first turn\'s session');
        Assert.areEqual('Five open cases.', second.text);
        Assert.areEqual(SESSION, second.sessionId);
    }

    @IsTest
    static void aBlankSessionStartsANewOne() {
        FakeAgent f = fake();

        AccountBriefAgentClient.ask('Hello', '  ', null);

        Assert.isNull(f.sessions[0]);
    }

    @IsTest
    static void theOpenRecordIsSentAsContext() {
        Account a = new Account(Name = 'Agent Client Acme');
        insert a;
        FakeAgent f = fake();

        Test.startTest();
        AccountBriefAgentClient.ask('What are the open deals at this account?', null, a.Id);
        Test.stopTest();

        Assert.areEqual('What are the open deals at this account?\n\nThe record I have open is ' + a.Id + '.', f.messages[0]);
    }

    @IsTest
    static void noOpenRecordSendsTheMessageAsTyped() {
        FakeAgent f = fake();

        AccountBriefAgentClient.ask('  How many open cases are there?  ', null, null);

        Assert.areEqual('How many open cases are there?', f.messages[0]);
    }

    @IsTest
    static void theReplyCarriesItsPanelFields() {
        fake();
        AccountBriefAgentClient.Reply r = AccountBriefAgentClient.ask('Hello', null, null);
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(r));
        for (String field : new List<String>{ 'text', 'sessionId', 'failed' }) {
            Assert.isTrue(m.containsKey(field), 'reply lacks ' + field);
        }
    }
}
