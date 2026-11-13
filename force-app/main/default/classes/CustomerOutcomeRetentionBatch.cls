/**
 * Deletes customer outcomes past their expiry date (Expires__c before today). The expiry is set from the outcome's
 * type when it is written, so a type with blank retention is never deleted. Schedule it with
 * scripts/schedule-outcome-retention.apex; never run or schedule it in agent-probe without an approved row.
 */
// system-context: the purge deletes every expired outcome, whoever wrote it, and no rep can see them all
public without sharing class CustomerOutcomeRetentionBatch implements Database.Batchable<SObject>, Schedulable {
    /** Daily at 02:30. */
    public static final String DAILY_CRON = '0 30 2 * * ?';
    public static final Integer BATCH_SIZE = 200;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocatorWithBinds(
            'SELECT Id FROM Customer_Outcome__c WHERE Expires__c < :today',
            new Map<String, Object>{ 'today' => Date.today() },
            AccessLevel.SYSTEM_MODE
        );
    }

    public void execute(Database.BatchableContext bc, List<Customer_Outcome__c> scope) {
        Database.delete(scope, false, AccessLevel.SYSTEM_MODE);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'CustomerOutcomeRetentionBatch finished.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CustomerOutcomeRetentionBatch(), BATCH_SIZE);
    }
}
