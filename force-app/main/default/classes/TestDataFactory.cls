/**
 * Builds test records in one place so every test class creates data the same way.
 */
@IsTest
public class TestDataFactory {
    public static Account createAccount() {
        Account acc = new Account(Name = 'Acme Test Account');
        insert acc;
        return acc;
    }

    public static Contact createContact(Id accountId, String email) {
        Contact con = new Contact(FirstName = 'Test', LastName = 'Customer', Email = email, AccountId = accountId);
        insert con;
        return con;
    }

    public static List<Case> buildCases(Integer count, Map<SObjectField, Object> fieldValues) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            Case c = new Case(Subject = 'Test case ' + i, Description = 'Description ' + i);
            if (fieldValues != null) {
                for (SObjectField field : fieldValues.keySet()) {
                    c.put(field, fieldValues.get(field));
                }
            }
            cases.add(c);
        }
        return cases;
    }

    public static List<Case> createCases(Integer count, Map<SObjectField, Object> fieldValues) {
        List<Case> cases = buildCases(count, fieldValues);
        insert cases;
        return cases;
    }

    public static Case closeCase(Case c) {
        c.Status = CaseService.STATUS_CLOSED;
        c.Resolution__c = 'Resolved in test';
        update c;
        return c;
    }

    public static List<FAQ__c> createFaqs() {
        List<FAQ__c> faqs = new List<FAQ__c>{
            new FAQ__c(
                Name = 'How do I reset my password?',
                Answer__c = 'Click "Forgot password" on the login page and follow the email link.',
                Category__c = 'Account',
                Active__c = true
            ),
            new FAQ__c(
                Name = 'Why was I charged twice?',
                Answer__c = 'Duplicate charges are usually pending authorisations and drop off within 3 business days.',
                Category__c = 'Billing',
                Active__c = true
            ),
            new FAQ__c(
                Name = 'Old shipping policy',
                Answer__c = 'Retired article.',
                Category__c = 'Shipping',
                Active__c = false
            )
        };
        insert faqs;
        return faqs;
    }

    public static User createStandardUser(String permissionSetName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueKey = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'tuser',
            Email = 'tuser' + uniqueKey + '@example.com',
            Username = 'tuser' + uniqueKey + '@support-portal.test',
            LastName = 'Tester',
            ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata'
        );
        insert u;

        if (permissionSetName != null) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }
}
