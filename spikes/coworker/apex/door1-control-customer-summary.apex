// BE-47 door 1, control call. One generateAiAgentResponse turn against Customer_Summary (the agent this repo owns).
// Door 1 proper (the platform Search Agent) is not in agent-probe (0 BotDefinition rows), so it is recorded as not tried.
// Reads one seed account (SOQL only), makes one agent turn, and prints result lines only: no Ids, no session Id, no reply text.
// Output lines start with BE47| so the recorder can pick them out of the debug log.
Account a = [SELECT Name FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity) ORDER BY LastModifiedDate DESC LIMIT 1];
String msg = 'Give me a brief on ' + a.Name;
Long t0 = System.now().getTime();
String status = 'ok';
String errType = '';
String errMsg = '';
Integer replyLen = 0;
Boolean namesAccount = false;
Boolean sessionReturned = false;
try {
    Invocable.Action act = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Customer_Summary');
    act.setInvocationParameter('userMessage', msg);
    List<Invocable.Action.Result> rs = act.invoke();
    if (rs[0].isSuccess() == false) {
        status = 'action_error';
        errMsg = String.join(rs[0].getErrors(), ' | ');
    } else {
        Map<String, Object> o = rs[0].getOutputParameters();
        String reply = String.valueOf(o.get('agentResponse'));
        replyLen = reply == null ? 0 : reply.length();
        namesAccount = reply != null && reply.containsIgnoreCase(a.Name);
        sessionReturned = o.get('sessionId') != null;
    }
} catch (Exception e) {
    status = 'exception';
    errType = e.getTypeName();
    errMsg = e.getMessage();
}
Integer secs = Integer.valueOf((System.now().getTime() - t0) / 1000);
System.debug('BE47|door=control|target=Customer_Summary|status=' + status + '|errType=' + errType + '|errMsg=' + errMsg + '|replyLen=' + replyLen + '|namesAccount=' + namesAccount + '|sessionReturned=' + sessionReturned + '|seconds=' + secs);
