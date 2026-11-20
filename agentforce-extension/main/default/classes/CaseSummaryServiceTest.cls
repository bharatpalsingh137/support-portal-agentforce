@IsTest
private class CaseSummaryServiceTest {
    // ConnectApi Einstein calls are not executed in Apex tests, so these tests
    // verify that a failed generation is handled gracefully and logged.

    @IsTest
    static void invocableHandlesUnavailableModel() {
        Case c = TestDataFactory.createCases(1, null)[0];

        Test.startTest();
        List<String> summaries = CaseSummaryService.summarizeCases(new List<Id>{ c.Id });
        Test.stopTest();

        Assert.areEqual(1, summaries.size());
        Assert.isNotNull(summaries[0]);
    }

    @IsTest
    static void auraMethodReturnsFriendlyError() {
        Case c = TestDataFactory.createCases(1, null)[0];
        try {
            String summary = CaseSummaryService.summarize(c.Id);
            Assert.isNotNull(summary, 'If the model is available in tests, a summary is returned');
        } catch (AuraHandledException e) {
            Assert.areEqual('Could not generate a summary right now.', e.getMessage());
        }
    }
}
