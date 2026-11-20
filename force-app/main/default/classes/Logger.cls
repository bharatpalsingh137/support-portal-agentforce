/**
 * Logging utility. Publishes Log_Event__e (publish immediately), and
 * LogEventSubscriber turns each event into an Application_Log__c record.
 *
 * Why a platform event? When an @AuraEnabled method throws, Salesforce rolls back
 * every DML in the transaction, including a normal insert of a log record.
 * A publish-immediately event is not rolled back, so the error is still recorded.
 */
public without sharing class Logger {
    public enum Level {
        ERROR,
        WARN,
        INFO
    }

    private static final Integer MAX_TEXT = 131072;

    @TestVisible
    private static List<Log_Event__e> publishedEvents = new List<Log_Event__e>();

    public static void error(String source, Exception e) {
        error(source, e, null);
    }

    public static void error(String source, Exception e, Id relatedRecordId) {
        publish(
            Level.ERROR,
            source,
            e.getTypeName() + ': ' + e.getMessage(),
            e.getStackTraceString(),
            relatedRecordId
        );
    }

    public static void error(String source, String message) {
        publish(Level.ERROR, source, message, null, null);
    }

    public static void warn(String source, String message) {
        publish(Level.WARN, source, message, null, null);
    }

    public static void info(String source, String message) {
        publish(Level.INFO, source, message, null, null);
    }

    private static void publish(Level logLevel, String source, String message, String stackTrace, Id relatedRecordId) {
        Log_Event__e event = new Log_Event__e(
            Level__c = logLevel.name(),
            Source__c = source?.left(255),
            Message__c = message?.left(MAX_TEXT),
            Stack_Trace__c = stackTrace?.left(MAX_TEXT),
            Related_Record_Id__c = relatedRecordId
        );
        publishedEvents.add(event);

        Database.SaveResult result = EventBus.publish(event);
        if (!result.isSuccess()) {
            // Last resort: never let logging break the business transaction.
            System.debug(LoggingLevel.ERROR, 'Logger could not publish event: ' + result.getErrors());
        }
    }
}
