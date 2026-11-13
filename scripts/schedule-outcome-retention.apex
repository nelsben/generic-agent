// Schedules the customer outcome retention purge (BE-35): daily at 02:30, deleting outcomes past their expiry date.
// Run it once per org with: sf apex run --file scripts/schedule-outcome-retention.apex --target-org <alias>
// Do not run it in agent-probe: scheduling or running the purge there needs its own approved row in the plan.
String jobName = 'Customer outcome retention';
if ([SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :jobName WITH SYSTEM_MODE] == 0) {
    System.schedule(jobName, CustomerOutcomeRetentionBatch.DAILY_CRON, new CustomerOutcomeRetentionBatch());
    System.debug(LoggingLevel.INFO, 'Scheduled: ' + jobName);
} else {
    System.debug(LoggingLevel.INFO, 'Already scheduled: ' + jobName);
}
