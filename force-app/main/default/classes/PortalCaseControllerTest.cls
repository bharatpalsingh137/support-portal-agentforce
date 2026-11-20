@IsTest
private class PortalCaseControllerTest {
    @IsTest
    static void createCaseSetsPortalDefaults() {
        Test.startTest();
        Case created = PortalCaseController.createCase('Cannot log in', 'Password reset email never arrives', 'Technical');
        Test.stopTest();

        Case c = [SELECT Source_Channel__c, Priority, Product_Category__c FROM Case WHERE Id = :created.Id];
        Assert.isNotNull(created.CaseNumber);
        Assert.areEqual(CaseService.CHANNEL_PORTAL, c.Source_Channel__c);
        Assert.areEqual('High', c.Priority);
    }

    @IsTest
    static void createCaseRequiresSubject() {
        try {
            PortalCaseController.createCase('  ', 'desc', 'Billing');
            Assert.fail('Expected an exception');
        } catch (AuraHandledException e) {
            Assert.areEqual('Please enter a subject.', e.getMessage());
        }
    }

    @IsTest
    static void getMyCasesFiltersByStatus() {
        List<Case> cases = TestDataFactory.createCases(2, null);
        TestDataFactory.closeCase(cases[0]);

        Assert.areEqual(2, PortalCaseController.getMyCases('All').size());
        Assert.areEqual(1, PortalCaseController.getMyCases('Open').size());
        Assert.areEqual(1, PortalCaseController.getMyCases('Closed').size());
    }

    @IsTest
    static void addCommentReopensWaitingCaseAndShowsInTimeline() {
        Case c = TestDataFactory.createCases(
                1,
                new Map<SObjectField, Object>{ Case.Status => CaseService.STATUS_WAITING }
            )[0];

        Test.startTest();
        PortalCaseController.addComment(c.Id, 'Here are the screenshots you asked for.');
        Test.stopTest();

        Assert.areEqual(CaseService.STATUS_WORKING, [SELECT Status FROM Case WHERE Id = :c.Id].Status);

        PortalCaseController.CaseDetail detail = PortalCaseController.getCaseDetail(c.Id);
        Assert.areEqual(2, detail.timeline.size(), 'Expected "created" + 1 comment');
        Assert.areEqual('created', detail.timeline[0].itemType);
        Assert.areEqual('comment', detail.timeline[1].itemType);
        Assert.isTrue(detail.timeline[1].isCustomer);
        Assert.isFalse(detail.hasFeedback);
    }

    @IsTest
    static void addCommentRequiresBody() {
        Case c = TestDataFactory.createCases(1, null)[0];
        try {
            PortalCaseController.addComment(c.Id, '');
            Assert.fail('Expected an exception');
        } catch (AuraHandledException e) {
            Assert.areEqual('Please enter a comment.', e.getMessage());
        }
    }

    @IsTest
    static void closedCaseTimelineIncludesResolution() {
        Case c = TestDataFactory.closeCase(TestDataFactory.createCases(1, null)[0]);

        PortalCaseController.CaseDetail detail = PortalCaseController.getCaseDetail(c.Id);
        PortalCaseController.TimelineItem last = detail.timeline[detail.timeline.size() - 1];
        Assert.areEqual('closed', last.itemType);
        Assert.areEqual('Resolved in test', last.body);
    }

    @IsTest
    static void getCaseDetailHandlesMissingCase() {
        Case c = TestDataFactory.createCases(1, null)[0];
        Id caseId = c.Id;
        delete c;
        try {
            PortalCaseController.getCaseDetail(caseId);
            Assert.fail('Expected an exception');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not found'));
        }
    }

    @IsTest
    static void lowRatingFeedbackEscalatesCaseViaFlow() {
        Case c = TestDataFactory.closeCase(TestDataFactory.createCases(1, null)[0]);

        Test.startTest();
        Id feedbackId = PortalCaseController.submitFeedback(c.Id, 1, 'Not happy with the answer');
        Test.stopTest();

        Assert.isNotNull(feedbackId);
        Case escalated = [SELECT Status, Priority, IsEscalated FROM Case WHERE Id = :c.Id];
        Assert.areEqual(CaseService.STATUS_ESCALATED, escalated.Status, 'Flow should re-open the case');
        Assert.areEqual('High', escalated.Priority);
        Assert.isTrue(escalated.IsEscalated);
    }

    @IsTest
    static void goodFeedbackDoesNotEscalateAndCannotBeDuplicated() {
        Case c = TestDataFactory.closeCase(TestDataFactory.createCases(1, null)[0]);
        PortalCaseController.submitFeedback(c.Id, 5, 'Great support');

        Assert.areEqual(CaseService.STATUS_CLOSED, [SELECT Status FROM Case WHERE Id = :c.Id].Status);
        Assert.isTrue(PortalCaseController.getCaseDetail(c.Id).hasFeedback);

        try {
            PortalCaseController.submitFeedback(c.Id, 4, 'Again');
            Assert.fail('Duplicate feedback should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('already'));
        }
    }

    @IsTest
    static void feedbackValidation() {
        Case openCase = TestDataFactory.createCases(1, null)[0];

        try {
            PortalCaseController.submitFeedback(openCase.Id, 6, null);
            Assert.fail('Rating 6 should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('between 1 and 5'));
        }

        try {
            PortalCaseController.submitFeedback(openCase.Id, 3, null);
            Assert.fail('Feedback on open case should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('once your case is closed'));
        }
    }

    @IsTest
    static void searchFaqsReturnsOnlyActiveMatches() {
        List<FAQ__c> faqs = TestDataFactory.createFaqs();
        Test.setFixedSearchResults(new List<Id>{ faqs[0].Id, faqs[1].Id, faqs[2].Id });

        List<FAQ__c> results = PortalCaseController.searchFaqs('charged twice', null);
        Assert.areEqual(2, results.size(), 'Inactive FAQ must be filtered out');

        Assert.areEqual(0, PortalCaseController.searchFaqs('ab', null).size(), 'Short terms are ignored');
    }

    @IsTest
    static void searchTermIsSanitised() {
        Assert.areEqual('refund OR please', FaqService.buildSearchTerm('refund? (please!)'));
        Assert.areEqual('billing OR issue', FaqService.buildSearchTerm('billing AND issue'));
        Assert.isNull(FaqService.buildSearchTerm('!!!!'));
    }

    @IsTest
    static void categoriesComeFromPicklist() {
        List<PortalCaseController.PicklistOption> options = PortalCaseController.getCategories();
        Assert.isFalse(options.isEmpty());
        Assert.areEqual('Billing', options[0].value);
    }

    @IsTest
    static void unexpectedErrorsBecomeFriendlyMessages() {
        AuraHandledException e = PortalCaseController.toAuraException(new NullPointerException());
        Assert.areEqual('Something went wrong. Please try again or contact support.', e.getMessage());
    }

    @IsTest
    static void standardUserWithPermissionSetCanCreateCase() {
        User agent = TestDataFactory.createStandardUser('Support_Agent');
        System.runAs(agent) {
            Case created = PortalCaseController.createCase('Run-as test', 'desc', 'Billing');
            Assert.isNotNull(created.Id);
            Assert.areEqual(1, PortalCaseController.getMyCases('Open').size());
        }
    }
}
