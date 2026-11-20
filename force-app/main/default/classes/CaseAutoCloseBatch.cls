/**
 * Closes cases that have been "Waiting on Customer" longer than
 * Support_Settings__mdt.Auto_Close_Days__c. Schedulable, so it runs nightly.
 *
 *   CaseAutoCloseBatch.scheduleDaily();                      // 2 AM every day
 *   Database.executeBatch(new CaseAutoCloseBatch(), 200);    // run now
 *
 * Runs without sharing on purpose: it is a system job that must see every
 * stale case, not only the ones the scheduling user owns.
 */
public without sharing class CaseAutoCloseBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    public static final String JOB_NAME = 'Support Portal - Case Auto Close';
    public static final String DAILY_AT_2AM = '0 0 2 * * ?';

    private final Integer days;
    @TestVisible
    private Integer closedCount = 0;
    @TestVisible
    private Integer failedCount = 0;
    private List<String> errors = new List<String>();

    public CaseAutoCloseBatch() {
        this(SupportSettings.autoCloseDays());
    }

    public CaseAutoCloseBatch(Integer days) {
        this.days = days;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Datetime cutoff = System.now().addDays(-days);
        String waitingStatus = CaseService.STATUS_WAITING;
        return Database.getQueryLocator(
            [SELECT Id, Status FROM Case WHERE Status = :waitingStatus AND Waiting_Since__c <= :cutoff]
        );
    }

    public void execute(Database.BatchableContext context, List<Case> scope) {
        String resolution = 'Auto-closed: no response from the customer within ' + days + ' days.';
        for (Case c : scope) {
            c.Status = CaseService.STATUS_CLOSED;
            c.Resolution__c = resolution;
        }

        List<Database.SaveResult> results = Database.update(scope, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                closedCount++;
            } else {
                failedCount++;
                if (errors.size() < 50) {
                    errors.add(scope[i].Id + ': ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        String summary = 'Closed ' + closedCount + ' case(s); ' + failedCount + ' failure(s).';
        if (failedCount > 0) {
            Logger.error('CaseAutoCloseBatch', summary + '\n' + String.join(errors, '\n'));
        } else {
            Logger.info('CaseAutoCloseBatch', summary);
        }
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new CaseAutoCloseBatch(), 200);
    }

    public static Id scheduleDaily() {
        return System.schedule(JOB_NAME, DAILY_AT_2AM, new CaseAutoCloseBatch());
    }
}
