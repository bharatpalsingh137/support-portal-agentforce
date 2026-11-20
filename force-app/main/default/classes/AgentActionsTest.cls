@IsTest
private class AgentActionsTest {
    private static final String EMAIL = 'priya.customer@example.com';

    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount();
        TestDataFactory.createContact(acc.Id, EMAIL);
    }

    private static Case createCaseForCustomer(String status) {
        Contact con = [SELECT Id, AccountId FROM Contact WHERE Email = :EMAIL];
        Case c = new Case(Subject = 'Order not delivered', ContactId = con.Id, AccountId = con.AccountId, Status = status);
        insert c;
        return [SELECT Id, CaseNumber, Status FROM Case WHERE Id = :c.Id];
    }

    @IsTest
    static void createCaseLinksContactAndNormalisesCategory() {
        AgentCreateCaseAction.Request req = new AgentCreateCaseAction.Request();
        req.subject = 'App crashes on login';
        req.description = 'Crashes every time since the last update';
        req.category = 'technical issue';
        req.customerEmail = EMAIL.toUpperCase();

        List<AgentCreateCaseAction.Response> responses = AgentCreateCaseAction.createCases(
            new List<AgentCreateCaseAction.Request>{ req }
        );

        Assert.isTrue(responses[0].success, responses[0].message);
        Case c = [
            SELECT Contact.Email, Product_Category__c, Source_Channel__c, Priority
            FROM Case
            WHERE Id = :responses[0].caseId
        ];
        Assert.areEqual(EMAIL, c.Contact.Email);
        Assert.areEqual('Technical', c.Product_Category__c);
        Assert.areEqual(CaseService.CHANNEL_AI_AGENT, c.Source_Channel__c);
        Assert.areEqual('High', c.Priority);
        Assert.isTrue(responses[0].message.contains(responses[0].caseNumber));
    }

    @IsTest
    static void createCaseWorksForUnknownCustomer() {
        AgentCreateCaseAction.Request req = new AgentCreateCaseAction.Request();
        req.subject = 'Question';
        req.customerEmail = 'nobody@example.com';

        AgentCreateCaseAction.Response res = AgentCreateCaseAction.createCases(
            new List<AgentCreateCaseAction.Request>{ req }
        )[0];

        Assert.isTrue(res.success);
        Assert.areEqual('Other', [SELECT Product_Category__c FROM Case WHERE Id = :res.caseId].Product_Category__c);
    }

    @IsTest
    static void createCaseReportsFailures() {
        SupportSettings.testOverride = new Support_Settings__mdt(Max_Open_Cases__c = 0, Auto_Close_Days__c = 7);
        AgentCreateCaseAction.Request req = new AgentCreateCaseAction.Request();
        req.subject = 'Blocked by limit';
        req.customerEmail = EMAIL;

        AgentCreateCaseAction.Response res = AgentCreateCaseAction.createCases(
            new List<AgentCreateCaseAction.Request>{ req }
        )[0];

        Assert.isFalse(res.success);
        Assert.isTrue(res.message.contains('could not be created'));
    }

    @IsTest
    static void getStatusRequiresMatchingEmail() {
        Case c = createCaseForCustomer(CaseService.STATUS_WORKING);
        insert new CaseComment(ParentId = c.Id, CommentBody = 'We have shipped a replacement.', IsPublished = true);

        AgentGetCaseStatusAction.Request good = new AgentGetCaseStatusAction.Request();
        good.caseNumber = String.valueOf(Integer.valueOf(c.CaseNumber)); // customer types "1027" not "00001027"
        good.customerEmail = EMAIL;

        AgentGetCaseStatusAction.Request bad = new AgentGetCaseStatusAction.Request();
        bad.caseNumber = c.CaseNumber;
        bad.customerEmail = 'attacker@example.com';

        List<AgentGetCaseStatusAction.Response> responses = AgentGetCaseStatusAction.getStatus(
            new List<AgentGetCaseStatusAction.Request>{ good, bad }
        );

        Assert.isTrue(responses[0].found);
        Assert.areEqual(CaseService.STATUS_WORKING, responses[0].status);
        Assert.areEqual('We have shipped a replacement.', responses[0].latestReply);

        Assert.isFalse(responses[1].found);
        Assert.isNull(responses[1].status, 'No case details for an unverified customer');
    }

    @IsTest
    static void addCommentReopensWaitingCase() {
        Case c = createCaseForCustomer(CaseService.STATUS_WAITING);

        AgentAddCaseCommentAction.Request req = new AgentAddCaseCommentAction.Request();
        req.caseNumber = c.CaseNumber;
        req.customerEmail = EMAIL;
        req.comment = 'The tracking number is ABC123';

        AgentAddCaseCommentAction.Request wrongEmail = new AgentAddCaseCommentAction.Request();
        wrongEmail.caseNumber = c.CaseNumber;
        wrongEmail.customerEmail = 'someone@else.com';
        wrongEmail.comment = 'Should not be added';

        AgentAddCaseCommentAction.Request empty = new AgentAddCaseCommentAction.Request();
        empty.caseNumber = c.CaseNumber;
        empty.customerEmail = EMAIL;
        empty.comment = ' ';

        List<AgentAddCaseCommentAction.Response> responses = AgentAddCaseCommentAction.addComments(
            new List<AgentAddCaseCommentAction.Request>{ req, wrongEmail, empty }
        );

        Assert.isTrue(responses[0].success, responses[0].message);
        Assert.isFalse(responses[1].success);
        Assert.isFalse(responses[2].success);
        Assert.areEqual(1, [SELECT COUNT() FROM CaseComment WHERE ParentId = :c.Id]);
        Assert.areEqual(CaseService.STATUS_WORKING, [SELECT Status FROM Case WHERE Id = :c.Id].Status);
    }

    @IsTest
    static void searchFaqFallsBackToAllCategories() {
        List<FAQ__c> faqs = TestDataFactory.createFaqs();
        Test.setFixedSearchResults(new List<Id>{ faqs[1].Id });

        AgentSearchFaqAction.Request req = new AgentSearchFaqAction.Request();
        req.question = 'Why was I charged twice this month?';
        req.category = 'billing';

        AgentSearchFaqAction.Response res = AgentSearchFaqAction.search(new List<AgentSearchFaqAction.Request>{ req })[0];
        Assert.isTrue(res.found);
        Assert.areEqual(1, res.articleCount);
        Assert.isTrue(res.answers.contains('pending authorisations'));
    }

    @IsTest
    static void searchFaqWithNoMatches() {
        Test.setFixedSearchResults(new List<Id>());
        AgentSearchFaqAction.Request req = new AgentSearchFaqAction.Request();
        req.question = 'Something nobody has asked before';

        AgentSearchFaqAction.Response res = AgentSearchFaqAction.search(new List<AgentSearchFaqAction.Request>{ req })[0];
        Assert.isFalse(res.found);
        Assert.areEqual('No matching FAQ found.', res.answers);
    }
}
