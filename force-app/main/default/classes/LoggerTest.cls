@IsTest
private class LoggerTest {
    @IsTest
    static void logsAreStoredFromPlatformEvents() {
        Test.startTest();
        try {
            Integer zero = 0;
            Decimal result = 1 / zero;
            Assert.fail('Expected division by zero, got ' + result);
        } catch (MathException e) {
            Logger.error('LoggerTest', e);
        }
        Logger.warn('LoggerTest', 'A warning');
        Logger.info('LoggerTest', 'Some info');
        Test.stopTest(); // delivers the platform events

        Assert.areEqual(3, Logger.publishedEvents.size());
        List<Application_Log__c> logs = [
            SELECT Level__c, Source__c, Message__c, Stack_Trace__c
            FROM Application_Log__c
            ORDER BY Level__c
        ];
        Assert.areEqual(3, logs.size());
        Assert.areEqual('ERROR', logs[0].Level__c);
        Assert.isTrue(logs[0].Message__c.startsWith('System.MathException'));
        Assert.areEqual('LoggerTest', logs[0].Source__c);
    }

    @IsTest
    static void logSurvivesRollback() {
        Test.startTest();
        Savepoint sp = Database.setSavepoint();
        insert new Account(Name = 'Will be rolled back');
        Logger.error('LoggerTest', 'Error before rollback');
        Database.rollback(sp);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Name = 'Will be rolled back']);
        Assert.areEqual(1, [SELECT COUNT() FROM Application_Log__c WHERE Message__c = 'Error before rollback']);
    }
}
