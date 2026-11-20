/**
 * Agentforce action: look up the status of a case after verifying the
 * customer's email matches the case contact.
 */
public with sharing class AgentGetCaseStatusAction {
    public class Request {
        @InvocableVariable(label='Case Number' description='Case number given by the customer, e.g. 00001027 or 1027.' required=true)
        public String caseNumber;

        @InvocableVariable(
            label='Customer Email'
            description='Email of the customer. Must match the contact on the case.'
            required=true
        )
        public String customerEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True when the case exists and the customer was verified.')
        public Boolean found;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Priority')
        public String priority;

        @InvocableVariable(label='Subject')
        public String subject;

        @InvocableVariable(label='Last Updated')
        public Datetime lastUpdated;

        @InvocableVariable(label='Latest Support Reply' description='Most recent public comment on the case.')
        public String latestReply;

        @InvocableVariable(label='Message' description='Summary to relay to the customer.')
        public String message;
    }

    @InvocableMethod(
        label='Get Case Status'
        description='Returns the current status and latest reply for a customer\'s case. Requires the case number and the customer email.'
        category='Support Portal'
    )
    public static List<Response> getStatus(List<Request> requests) {
        Set<String> caseNumbers = new Set<String>();
        for (Request r : requests) {
            String normalized = CaseService.normalizeCaseNumber(r.caseNumber);
            if (normalized != null) {
                caseNumbers.add(normalized);
            }
        }
        Map<String, Case> casesByNumber = CaseSelector.selectByCaseNumbers(caseNumbers);

        List<Response> responses = new List<Response>();
        for (Request r : requests) {
            Case c = casesByNumber.get(CaseService.normalizeCaseNumber(r.caseNumber));
            Response res = new Response();

            if (!AgentActionUtils.isVerifiedCustomer(c, r.customerEmail)) {
                // Same message whether the case is missing or the email is wrong,
                // so the agent never confirms that someone else's case exists.
                res.found = false;
                res.message = 'I could not find a case with that number for your email address. Please check both and try again.';
            } else {
                res.found = true;
                res.status = c.Status;
                res.priority = c.Priority;
                res.subject = c.Subject;
                res.lastUpdated = c.LastModifiedDate;
                res.latestReply = c.CaseComments.isEmpty() ? null : c.CaseComments[0].CommentBody;
                res.message =
                    'Case ' +
                    c.CaseNumber +
                    ' ("' +
                    c.Subject +
                    '") is currently ' +
                    c.Status +
                    ' with ' +
                    c.Priority +
                    ' priority.';
            }
            responses.add(res);
        }
        return responses;
    }
}
