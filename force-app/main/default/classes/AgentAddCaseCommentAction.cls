/**
 * Agentforce action: add the customer's update to an existing case.
 * If the case was waiting on the customer, it moves back to "Working".
 */
public with sharing class AgentAddCaseCommentAction {
    public class Request {
        @InvocableVariable(label='Case Number' required=true)
        public String caseNumber;

        @InvocableVariable(label='Customer Email' description='Must match the contact on the case.' required=true)
        public String customerEmail;

        @InvocableVariable(label='Comment' description='The update from the customer.' required=true)
        public String comment;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Add Comment to Case'
        description='Adds the customer\'s update or extra information to an existing case.'
        category='Support Portal'
    )
    public static List<Response> addComments(List<Request> requests) {
        Set<String> caseNumbers = new Set<String>();
        for (Request r : requests) {
            String normalized = CaseService.normalizeCaseNumber(r.caseNumber);
            if (normalized != null) {
                caseNumbers.add(normalized);
            }
        }
        Map<String, Case> casesByNumber = CaseSelector.selectByCaseNumbers(caseNumbers);

        List<Response> responses = new List<Response>();
        List<CaseComment> comments = new List<CaseComment>();
        List<Integer> commentToResponse = new List<Integer>();
        Map<Id, Case> casesToReopen = new Map<Id, Case>();

        for (Request r : requests) {
            Case c = casesByNumber.get(CaseService.normalizeCaseNumber(r.caseNumber));
            Response res = new Response();
            responses.add(res);

            if (!AgentActionUtils.isVerifiedCustomer(c, r.customerEmail)) {
                res.success = false;
                res.message = 'I could not find a case with that number for your email address.';
                continue;
            }
            if (String.isBlank(r.comment)) {
                res.success = false;
                res.message = 'There was no update to add to the case.';
                continue;
            }

            comments.add(new CaseComment(ParentId = c.Id, CommentBody = r.comment.left(4000), IsPublished = true));
            commentToResponse.add(responses.size() - 1);
            if (CaseService.shouldReopenOnCustomerReply(c)) {
                casesToReopen.put(c.Id, new Case(Id = c.Id, Status = CaseService.STATUS_WORKING));
            }
        }

        if (!comments.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(comments, false, AccessLevel.USER_MODE);
            for (Integer i = 0; i < results.size(); i++) {
                Response res = responses[commentToResponse[i]];
                res.success = results[i].isSuccess();
                res.message = res.success
                    ? 'Thanks, I have added your update to the case. The support team has been notified.'
                    : 'Sorry, I could not add your update: ' + results[i].getErrors()[0].getMessage();
            }
        }
        if (!casesToReopen.isEmpty()) {
            Database.update(casesToReopen.values(), false, AccessLevel.USER_MODE);
        }
        return responses;
    }
}
