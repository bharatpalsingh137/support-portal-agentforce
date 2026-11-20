/**
 * Shared helpers for the Agentforce invocable actions.
 */
public inherited sharing class AgentActionUtils {
    /** Contacts keyed by lower-cased email. */
    public static Map<String, Contact> contactsByEmail(Set<String> emails) {
        Map<String, Contact> result = new Map<String, Contact>();
        Set<String> cleaned = new Set<String>();
        for (String email : emails) {
            if (String.isNotBlank(email)) {
                cleaned.add(email.trim().toLowerCase());
            }
        }
        if (cleaned.isEmpty()) {
            return result;
        }
        for (Contact c : [
            SELECT Id, AccountId, Email
            FROM Contact
            WHERE Email IN :cleaned
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ]) {
            String key = c.Email.toLowerCase();
            if (!result.containsKey(key)) {
                result.put(key, c);
            }
        }
        return result;
    }

    /** Maps free text from the LLM ("technical issue", "BILLING") to a valid picklist value. */
    public static String normalizeCategory(String category) {
        if (String.isBlank(category)) {
            return 'Other';
        }
        String lower = category.toLowerCase();
        for (Schema.PicklistEntry entry : Case.Product_Category__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && lower.contains(entry.getValue().toLowerCase())) {
                return entry.getValue();
            }
        }
        return 'Other';
    }

    /**
     * Simple identity check before sharing case details: the email the customer
     * gives the agent must match the contact on the case.
     */
    public static Boolean isVerifiedCustomer(Case c, String email) {
        return c != null &&
            String.isNotBlank(email) &&
            c.Contact != null &&
            String.isNotBlank(c.Contact.Email) &&
            c.Contact.Email.equalsIgnoreCase(email.trim());
    }

    public static String lower(String value) {
        return value == null ? null : value.trim().toLowerCase();
    }
}
