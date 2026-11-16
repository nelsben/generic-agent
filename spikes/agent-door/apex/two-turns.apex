// BE-56: one two-turn conversation with Customer_Summary through the DEPLOYED AgentDoorController.
// Reads the Edge Communications account Id in user mode, sends turn 1 (no session), then turn 2 with the session
// Id turn 1 returned, then calls endSession. Prints result lines only: no Ids, no session Id.
// Lines start with BE56| so the recorder can pick them out. Edit m1 and m2 for each conversation.
String m1 = 'Give me a brief on Edge Communications';
String m2 = 'What about its open cases?';
Account a = [SELECT Id, Name FROM Account WHERE Name = 'Edge Communications' WITH USER_MODE LIMIT 1];
AgentDoorController.TurnResult t1;
AgentDoorController.TurnResult t2;
String err = '';
try {
    t1 = AgentDoorController.sendMessage(m1, null, a.Id);
    t2 = AgentDoorController.sendMessage(m2, t1.sessionId, a.Id);
} catch (Exception e) {
    err = e.getTypeName() + ': ' + e.getMessage();
}
if (t1 != null) {
    System.debug('BE56|turn=1|seconds=' + t1.seconds + '|replyLen=' + t1.replyLength + '|sessionReturned=' + (t1.sessionId != null));
}
if (t2 != null) {
    AgentDoorController.EndResult er = AgentDoorController.endSession(t2.sessionId);
    System.debug('BE56|turn=2|seconds=' + t2.seconds + '|replyLen=' + t2.replyLength + '|sameSessionAsTurn1=' + (t2.sessionId == t1.sessionId)
        + '|namesEdge=' + t2.reply.containsIgnoreCase('Edge') + '|released=' + er.released + '|endedOnPlatform=' + er.endedOnPlatform);
    System.debug('BE56TEXT|turn=2|' + t2.reply.left(260).replace('\n', ' '));
}
System.debug('BE56|error=' + err);
