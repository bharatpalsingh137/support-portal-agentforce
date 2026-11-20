@IsTest
private class CaseTriggerHandlerTest {
    @IsTest
    static void selfServiceCasesArePrioritisedByCategory() {
        List<Case> cases = TestDataFactory.createCases(
            200,
            new Map<SObjectField, Object>{
                Case.Source_Channel__c => CaseService.CHANNEL_PORTAL,
                Case.Product_Category__c => 'Technical',
                Case.Priority => 'Low'
            }
        );

        for (Case c : [SELECT Priority FROM Case WHERE Id IN :new Map<Id, Case>(cases).keySet()]) {
            Assert.areEqual('High', c.Priority, 'Technical portal cases should be High priority');
        }
    }

    @IsTest
    static void internalCasesKeepTheirPriority() {
        Case c = TestDataFactory.createCases(
                1,
                new Map<SObjectField, Object>{
                    Case.Origin => 'Phone',
                    Case.Product_Category__c => 'Technical',
                    Case.Priority => 'Low'
                }
            )[0];

        c = [SELECT Priority, Source_Channel__c FROM Case WHERE Id = :c.Id];
        Assert.areEqual('Low', c.Priority, 'Agent-entered priority should not be overwritten');
        Assert.areEqual(CaseService.CHANNEL_PHONE, c.Source_Channel__c);
    }

    @IsTest
    static void sourceChannelIsDerivedFromOrigin() {
        Assert.areEqual(CaseService.CHANNEL_EMAIL, CaseService.deriveChannel('Email', false));
        Assert.areEqual(CaseService.CHANNEL_PORTAL, CaseService.deriveChannel('Web', false));
        Assert.areEqual(CaseService.CHANNEL_PHONE, CaseService.deriveChannel(null, false));
        Assert.areEqual(CaseService.CHANNEL_PORTAL, CaseService.deriveChannel('Email', true));
    }

    @IsTest
    static void waitingSinceIsSetAndCleared() {
        Case c = TestDataFactory.createCases(1, null)[0];

        c.Status = CaseService.STATUS_WAITING;
        update c;
        c = [SELECT Id, Status, Waiting_Since__c FROM Case WHERE Id = :c.Id];
        Assert.isNotNull(c.Waiting_Since__c, 'Waiting_Since__c should be stamped');

        c.Status = CaseService.STATUS_WORKING;
        update c;
        c = [SELECT Waiting_Since__c FROM Case WHERE Id = :c.Id];
        Assert.isNull(c.Waiting_Since__c, 'Waiting_Since__c should be cleared');
    }

    @IsTest
    static void openCaseLimitIsEnforcedInBulk() {
        SupportSettings.testOverride = new Support_Settings__mdt(Max_Open_Cases__c = 2, Auto_Close_Days__c = 7);
        Contact con = TestDataFactory.createContact(TestDataFactory.createAccount().Id, 'limit@example.com');

        List<Case> cases = TestDataFactory.buildCases(3, new Map<SObjectField, Object>{ Case.ContactId => con.Id });
        List<Database.SaveResult> results = Database.insert(cases, false);

        Integer successes = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successes++;
            } else {
                Assert.isTrue(sr.getErrors()[0].getMessage().contains('open cases'));
            }
        }
        Assert.areEqual(2, successes, 'Only 2 open cases are allowed per contact');
    }

    @IsTest
    static void closingWithoutResolutionIsBlocked() {
        Case c = TestDataFactory.createCases(1, null)[0];
        c.Status = CaseService.STATUS_CLOSED;

        try {
            update c;
            Assert.fail('Expected the validation rule to block closing');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('resolution'), e.getMessage());
        }
    }

    @IsTest
    static void handlerCanBeBypassed() {
        TriggerHandler.bypass('CaseTriggerHandler');
        Assert.isTrue(TriggerHandler.isBypassed('CaseTriggerHandler'));

        Case c = TestDataFactory.createCases(
                1,
                new Map<SObjectField, Object>{
                    Case.Source_Channel__c => CaseService.CHANNEL_PORTAL,
                    Case.Product_Category__c => 'Technical',
                    Case.Priority => 'Low'
                }
            )[0];
        TriggerHandler.clearBypass('CaseTriggerHandler');

        Assert.areEqual('Low', [SELECT Priority FROM Case WHERE Id = :c.Id].Priority);
        Assert.isFalse(TriggerHandler.isBypassed('CaseTriggerHandler'));
    }

    @IsTest
    static void caseNumbersAreNormalised() {
        Assert.areEqual('00001027', CaseService.normalizeCaseNumber('#1027'));
        Assert.areEqual('00001027', CaseService.normalizeCaseNumber('00001027'));
        Assert.isNull(CaseService.normalizeCaseNumber('abc'));
        Assert.isNull(CaseService.normalizeCaseNumber(null));
    }

    @IsTest
    static void settingsFallBackToDefaults() {
        SupportSettings.testOverride = new Support_Settings__mdt();
        Assert.areEqual(SupportSettings.DEFAULT_AUTO_CLOSE_DAYS, SupportSettings.autoCloseDays());
        Assert.areEqual(SupportSettings.DEFAULT_MAX_OPEN_CASES, SupportSettings.maxOpenCasesPerContact());
    }
}
