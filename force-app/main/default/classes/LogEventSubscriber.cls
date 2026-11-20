/**
 * Subscriber for Log_Event__e. Runs as the Automated Process user after the
 * event is delivered and stores each event as an Application_Log__c record.
 */
public without sharing class LogEventSubscriber {
    public static void saveLogs(List<Log_Event__e> events) {
        List<Application_Log__c> logs = new List<Application_Log__c>();
        for (Log_Event__e event : events) {
            logs.add(
                new Application_Log__c(
                    Level__c = event.Level__c,
                    Source__c = event.Source__c,
                    Message__c = event.Message__c,
                    Stack_Trace__c = event.Stack_Trace__c,
                    Related_Record_Id__c = event.Related_Record_Id__c
                )
            );
        }
        // allOrNone = false: one bad log must not block the others.
        Database.insert(logs, false);
    }
}
