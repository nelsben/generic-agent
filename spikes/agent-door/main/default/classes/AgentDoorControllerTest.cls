@IsTest
private class AgentDoorControllerTest {
    private class StubGateway implements AgentDoorController.AgentGateway {
        public List<String> messages = new List<String>();
        public List<String> sessionsIn = new List<String>();
        public String agentSeen;
        public Boolean fail = false;
        public Map<String, Object> send(String agentApiName, String userMessage, String sessionId) {
            if (fail) {
                throw new AuraHandledException('stub failure');
            }
            agentSeen = agentApiName;
            messages.add(userMessage);
            sessionsIn.add(sessionId);
            return new Map<String, Object>{
                'agentResponse' => '{"type":"Text","value":"Reply ' + messages.size() + '"}',
                'sessionId' => 'stub-session-1'
            };
        }
    }

    @IsTest
    static void twoTurnsShareOneSession() {
        StubGateway stub = new StubGateway();
        AgentDoorController.gateway = stub;
        AgentDoorController.TurnResult t1 = AgentDoorController.sendMessage('Give me a brief', null, null);
        AgentDoorController.TurnResult t2 = AgentDoorController.sendMessage('What about cases?', t1.sessionId, null);
        System.assertEquals('Customer_Summary', stub.agentSeen);
        System.assertEquals('Reply 1', t1.reply);
        System.assertEquals('stub-session-1', t1.sessionId);
        System.assertEquals(null, stub.sessionsIn[0], 'turn 1 starts a new session');
        System.assertEquals('stub-session-1', stub.sessionsIn[1], 'turn 2 sends turn 1 session back');
        System.assertEquals('Reply 2', t2.reply);
        System.assertEquals(7, t2.replyLength);
    }

    @IsTest
    static void firstTurnAddsTheAccountNameReadInUserMode() {
        Account a = new Account(Name = 'Door Test Account');
        insert as user a;
        StubGateway stub = new StubGateway();
        AgentDoorController.gateway = stub;
        AgentDoorController.sendMessage('Give me a brief', null, a.Id);
        AgentDoorController.sendMessage('And its cases?', 'stub-session-1', a.Id);
        System.assert(stub.messages[0].contains('Door Test Account'));
        System.assertEquals('And its cases?', stub.messages[1], 'turn 2 is sent as typed');
    }

    @IsTest
    static void blankMessageIsRefused() {
        AgentDoorController.gateway = new StubGateway();
        try {
            AgentDoorController.sendMessage('  ', null, null);
            System.assert(false, 'expected an AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void gatewayFailureSurfaces() {
        StubGateway stub = new StubGateway();
        stub.fail = true;
        AgentDoorController.gateway = stub;
        try {
            AgentDoorController.sendMessage('hello', null, null);
            System.assert(false, 'expected an AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void endSessionReleasesAndSaysItIsNotEndedOnThePlatform() {
        AgentDoorController.EndResult r = AgentDoorController.endSession('stub-session-1');
        System.assertEquals(true, r.released);
        System.assertEquals(false, r.endedOnPlatform);
        System.assertEquals(false, AgentDoorController.endSession(null).released);
    }

    @IsTest
    static void replyTextFallsBackToTheRawString() {
        System.assertEquals('plain text', AgentDoorController.replyText('plain text'));
        System.assertEquals('hi', AgentDoorController.replyText('{"type":"Text","value":"hi"}'));
        System.assertEquals('', AgentDoorController.replyText(null));
    }
}
