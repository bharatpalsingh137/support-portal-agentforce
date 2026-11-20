/**
 * SOSL search over FAQ__c. Used for case deflection in the portal wizard
 * and by the Agentforce "Search FAQs" action.
 */
public inherited sharing class FaqService {
    public static final Integer MIN_TERM_LENGTH = 3;
    public static final Integer MAX_RESULTS = 20;

    public static List<FAQ__c> search(String term, String category, Integer maxResults) {
        String searchTerm = buildSearchTerm(term);
        if (searchTerm == null) {
            return new List<FAQ__c>();
        }
        Integer resultLimit = (maxResults == null || maxResults < 1) ? 5 : Math.min(maxResults, MAX_RESULTS);

        List<List<SObject>> results;
        if (String.isBlank(category)) {
            results = [
                FIND :searchTerm
                IN ALL FIELDS
                RETURNING FAQ__c(Id, Name, Answer__c, Category__c WHERE Active__c = TRUE ORDER BY Name)
                LIMIT :resultLimit
            ];
        } else {
            results = [
                FIND :searchTerm
                IN ALL FIELDS
                RETURNING
                    FAQ__c(
                        Id,
                        Name,
                        Answer__c,
                        Category__c
                        WHERE Active__c = TRUE AND Category__c = :category
                        ORDER BY Name)
                LIMIT :resultLimit
            ];
        }
        return (List<FAQ__c>) results[0];
    }

    /**
     * Removes SOSL reserved characters and ORs the words together, so
     * "refund for double charge" matches FAQs containing any of those words.
     * Returns null when there is nothing worth searching for.
     */
    @TestVisible
    private static String buildSearchTerm(String term) {
        if (String.isBlank(term) || term.trim().length() < MIN_TERM_LENGTH) {
            return null;
        }
        String cleaned = term.replaceAll('[?&|!{}\\[\\]()^~*:\\\\"\'+\\-]', ' ').normalizeSpace();

        List<String> words = new List<String>();
        for (String word : cleaned.split(' ')) {
            if (word.length() >= 2 && !isOperator(word)) {
                words.add(word);
            }
        }
        return words.isEmpty() ? null : String.join(words, ' OR ');
    }

    private static Boolean isOperator(String word) {
        String upper = word.toUpperCase();
        return upper == 'AND' || upper == 'OR' || upper == 'NOT';
    }
}
