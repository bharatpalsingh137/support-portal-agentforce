@IsTest
private class CaseAutoCloseBatchTest {
    @IsTest
    static void closesOnlyStaleWaitingCases() {
        List<Case> stale = TestDataFactory.createCases(
            50,
            new Map<SObjectField, Object>{
                Case.Status => CaseService.STATUS_WAITING,
                Case.Waiting_Since__c => System.now().addDays(-10)
            }
        );
        List<Case> recent = TestDataFactory.createCases(
            5,
            new Map<SObjectField, Object>{
                Case.Status => CaseService.STATUS_WAITING,
                Case.Waiting_Since__c => System.now().addDays(-1)
            }
        );
        TestDataFactory.createCases(5, new Map<SObjectField, Object>{ Case.Status => CaseService.STATUS_WORKING });

        CaseAutoCloseBatch job = new CaseAutoCloseBatch(7);
        Test.startTest();
        Database.executeBatch(job, 200);
        Test.stopTest();

        Assert.areEqual(50, [SELECT COUNT() FROM Case WHERE Id IN :new Map<Id, Case>(stale).keySet() AND IsClosed = TRUE]);
        Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE Id IN :new Map<Id, Case>(recent).keySet() AND IsClosed = TRUE]);
        Assert.areEqual(5, [SELECT COUNT() FROM Case WHERE Status = :CaseService.STATUS_WORKING]);

        Case sample = [SELECT Resolution__c FROM Case WHERE Id = :stale[0].Id];
        Assert.isTrue(sample.Resolution__c.startsWith('Auto-closed'));
    }

    @IsTest
    static void canBeScheduled() {
        Test.startTest();
        Id jobId = CaseAutoCloseBatch.scheduleDaily();
        Test.stopTest();

        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(CaseAutoCloseBatch.DAILY_AT_2AM, ct.CronExpression);
    }
}
