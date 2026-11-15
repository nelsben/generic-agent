// BE-53 door 1: one generateAiAgentResponse turn against SearchAgent (the Coworker Agent, connect-24h).
// Reads one seed account (SOQL only), asks for its open cases, makes one agent turn, and prints result lines only.
// No Ids, no session Id, no reply text. errMsg is shown in the debug log only; never copy it to a file unchecked.
// Output lines start with BE53| so the recorder can pick them out of the debug log.
Account a = [SELECT Name FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity) ORDER BY LastModifiedDate DESC LIMIT 1];
String msg = 'List the open cases for the account ' + a.Name;
Long t0 = System.now().getTime();
String status = 'ok';
String errType = '';
String errMsg = '';
Integer replyLen = 0;
Boolean namesAccount = false;
Boolean sessionReturned = false;
System.debug('BE53|step=before_invoke');
try {
    Invocable.Action act = Invocable.Action.createCustomAction('generateAiAgentResponse', 'SearchAgent');
    act.setInvocationParameter('userMessage', msg);
    List<Invocable.Action.Result> rs = act.invoke();
    System.debug('BE53|step=after_invoke');
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
System.debug('BE53|door=1|target=SearchAgent|status=' + status + '|errType=' + errType + '|errMsg=' + errMsg + '|replyLen=' + replyLen + '|namesAccount=' + namesAccount + '|sessionReturned=' + sessionReturned + '|seconds=' + secs);
