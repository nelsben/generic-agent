// BE-22 probe: can a Confirm write and a model call share one transaction? run.py puts router.apex in front.
// Inserts one throwaway Task inside a savepoint, then tries the model call, then rolls back. Prints the exception type and the start of its message.
String result;
Savepoint sp = Database.setSavepoint();
try {
    Database.insert(new Task(Subject = 'BE22 spike probe'), true, AccessLevel.USER_MODE);
    Meter m = new Meter();
    try {
        callModel(m, 'Reply with the word OK.', 'OK?');
        result = 'exception=none|modelMs=' + m.modelMs;
    } catch (System.CalloutException e) {
        result = 'exception=CalloutException|message=' + e.getMessage().left(120).replace('|', '/');
    } catch (Exception e) {
        result = 'exception=' + e.getTypeName() + '|message=' + e.getMessage().left(120).replace('|', '/');
    }
} finally {
    Database.rollback(sp);
}
Integer remaining = [SELECT COUNT() FROM Task WHERE Subject = 'BE22 spike probe' WITH USER_MODE];
System.debug(LoggingLevel.ERROR, 'BE22X|' + result + '|left=' + remaining);
