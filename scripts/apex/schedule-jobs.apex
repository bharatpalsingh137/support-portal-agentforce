// Schedules the nightly auto-close job (2 AM, org time zone).
// Run with: sf apex run --file scripts/apex/schedule-jobs.apex

for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :CaseAutoCloseBatch.JOB_NAME]) {
    System.abortJob(ct.Id);
}
Id jobId = CaseAutoCloseBatch.scheduleDaily();
System.debug('Scheduled job: ' + jobId);
