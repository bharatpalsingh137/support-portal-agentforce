/**
 * Agentforce action: search the FAQ library so the agent can answer
 * common questions before creating a case (case deflection).
 */
public with sharing class AgentSearchFaqAction {
    private static final Integer MAX_ARTICLES = 3;

    public class Request {
        @InvocableVariable(label='Question' description='The customer\'s question, in their own words.' required=true)
        public String question;

        @InvocableVariable(label='Category' description='Optional: Billing, Technical, Account, Shipping or Other.')
        public String category;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True when at least one FAQ matched.')
        public Boolean found;

        @InvocableVariable(label='Article Count')
        public Integer articleCount;

        @InvocableVariable(
            label='Answers'
            description='Matching FAQs formatted as question and answer pairs. Use these to answer the customer.'
        )
        public String answers;
    }

    @InvocableMethod(
        label='Search FAQs'
        description='Searches the FAQ library for answers to the customer\'s question. Always try this before creating a case.'
        category='Support Portal'
    )
    public static List<Response> search(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request r : requests) {
            // SOSL in a loop is acceptable here: agents call actions one request at a time,
            // and each request needs its own search term.
            String category = String.isBlank(r.category) ? null : AgentActionUtils.normalizeCategory(r.category);
            List<FAQ__c> faqs = FaqService.search(r.question, category, MAX_ARTICLES);
            if (faqs.isEmpty() && category != null) {
                faqs = FaqService.search(r.question, null, MAX_ARTICLES);
            }

            Response res = new Response();
            res.found = !faqs.isEmpty();
            res.articleCount = faqs.size();

            List<String> parts = new List<String>();
            for (FAQ__c faq : faqs) {
                parts.add('Q: ' + faq.Name + '\nA: ' + faq.Answer__c);
            }
            res.answers = res.found ? String.join(parts, '\n\n') : 'No matching FAQ found.';
            responses.add(res);
        }
        return responses;
    }
}
