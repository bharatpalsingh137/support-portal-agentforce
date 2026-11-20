/**
 * Agentforce action: create a support case on behalf of the customer.
 * Add it to the "Case Management" topic in Agent Builder (see docs/SETUP.md).
 */
public with sharing class AgentCreateCaseAction {
    public class Request {
        @InvocableVariable(label='Subject' description='One-line summary of the customer issue.' required=true)
        public String subject;

        @InvocableVariable(label='Description' description='Full details of the issue in the customer\'s words.')
        public String description;

        @InvocableVariable(
            label='Category'
            description='Best matching category: Billing, Technical, Account, Shipping or Other.'
        )
        public String category;

        @InvocableVariable(
            label='Customer Email'
            description='Email address of the customer, used to link the case to their contact record.'
        )
        public String customerEmail;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when the case was created.')
        public Boolean success;

        @InvocableVariable(label='Case Id')
        public Id caseId;

        @InvocableVariable(label='Case Number' description='Case number to share with the customer.')
        public String caseNumber;

        @InvocableVariable(label='Message' description='Confirmation or error message to relay to the customer.')
        public String message;
    }

    @InvocableMethod(
        label='Create Support Case'
        description='Creates a support case when the customer\'s question cannot be answered from the FAQs. Returns the case number.'
        category='Support Portal'
    )
    public static List<Response> createCases(List<Request> requests) {
        Set<String> emails = new Set<String>();
        for (Request r : requests) {
            emails.add(r.customerEmail);
        }
        Map<String, Contact> contactsByEmail = AgentActionUtils.contactsByEmail(emails);

        List<Case> cases = new List<Case>();
        for (Request r : requests) {
            Contact customer = contactsByEmail.get(AgentActionUtils.lower(r.customerEmail));
            cases.add(
                new Case(
                    Subject = String.isBlank(r.subject) ? 'Support request' : r.subject.left(255),
                    Description = r.description,
                    Product_Category__c = AgentActionUtils.normalizeCategory(r.category),
                    Source_Channel__c = CaseService.CHANNEL_AI_AGENT,
                    ContactId = customer?.Id,
                    AccountId = customer?.AccountId
                )
            );
        }

        List<Database.SaveResult> results = Database.insert(cases, false, AccessLevel.USER_MODE);

        Set<Id> createdIds = new Set<Id>();
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                createdIds.add(sr.getId());
            }
        }
        Map<Id, Case> created = new Map<Id, Case>(
            [SELECT Id, CaseNumber FROM Case WHERE Id IN :createdIds WITH USER_MODE]
        );

        List<Response> responses = new List<Response>();
        for (Integer i = 0; i < results.size(); i++) {
            Response res = new Response();
            Database.SaveResult sr = results[i];
            if (sr.isSuccess()) {
                res.success = true;
                res.caseId = sr.getId();
                res.caseNumber = created.get(sr.getId())?.CaseNumber;
                res.message = 'Case ' + res.caseNumber + ' has been created. Our team will get back to you soon.';
            } else {
                res.success = false;
                res.message = 'The case could not be created: ' + sr.getErrors()[0].getMessage();
                Logger.error('AgentCreateCaseAction', sr.getErrors()[0].getMessage());
            }
            responses.add(res);
        }
        return responses;
    }
}
