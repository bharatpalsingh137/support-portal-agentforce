/**
 * Business rules for Case. Called from CaseTriggerHandler, PortalCaseController
 * and the Agentforce actions. All methods are bulk-safe.
 */
public inherited sharing class CaseService {
    public static final String STATUS_NEW = 'New';
    public static final String STATUS_WORKING = 'Working';
    public static final String STATUS_WAITING = 'Waiting on Customer';
    public static final String STATUS_ESCALATED = 'Escalated';
    public static final String STATUS_CLOSED = 'Closed';

    public static final String CHANNEL_PORTAL = 'Portal';
    public static final String CHANNEL_AI_AGENT = 'AI Agent';
    public static final String CHANNEL_EMAIL = 'Email';
    public static final String CHANNEL_PHONE = 'Phone';

    @TestVisible
    private static final Map<String, String> PRIORITY_BY_CATEGORY = new Map<String, String>{
        'Technical' => 'High',
        'Billing' => 'High',
        'Account' => 'Medium',
        'Shipping' => 'Medium',
        'Other' => 'Low'
    };

    /**
     * Before insert: fill in the source channel, prioritise self-service cases
     * by category, and stamp Waiting_Since__c if a case starts as waiting.
     */
    public static void applyDefaults(List<Case> cases) {
        Boolean isExternalUser = UserInfo.getUserType() != 'Standard';

        for (Case c : cases) {
            if (String.isBlank(c.Source_Channel__c)) {
                c.Source_Channel__c = deriveChannel(c.Origin, isExternalUser);
            }

            Boolean isSelfService = c.Source_Channel__c == CHANNEL_PORTAL || c.Source_Channel__c == CHANNEL_AI_AGENT;
            if (isSelfService && PRIORITY_BY_CATEGORY.containsKey(c.Product_Category__c)) {
                c.Priority = PRIORITY_BY_CATEGORY.get(c.Product_Category__c);
            }

            if (c.Status == STATUS_WAITING && c.Waiting_Since__c == null) {
                c.Waiting_Since__c = System.now();
            }
        }
    }

    @TestVisible
    private static String deriveChannel(String origin, Boolean isExternalUser) {
        if (isExternalUser || origin == 'Web') {
            return CHANNEL_PORTAL;
        }
        if (origin == 'Email') {
            return CHANNEL_EMAIL;
        }
        return CHANNEL_PHONE;
    }

    /**
     * Before update: Waiting_Since__c is set when a case enters "Waiting on Customer"
     * and cleared when it leaves, so the auto-close batch only sees genuinely stale cases.
     */
    public static void trackWaitingStatus(List<Case> cases, Map<Id, Case> oldMap) {
        for (Case c : cases) {
            Case previous = oldMap.get(c.Id);
            if (previous == null || c.Status == previous.Status) {
                continue;
            }
            c.Waiting_Since__c = (c.Status == STATUS_WAITING) ? System.now() : null;
        }
    }

    /**
     * Before insert: stop one contact from opening more cases than the configured limit.
     * Uses one aggregate query for the whole batch and counts cases inside the batch too.
     */
    public static void enforceOpenCaseLimit(List<Case> cases) {
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases) {
            if (c.ContactId != null && c.Status != STATUS_CLOSED) {
                contactIds.add(c.ContactId);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        Integer maxOpen = SupportSettings.maxOpenCasesPerContact();
        Map<Id, Integer> openCountByContact = CaseSelector.countOpenCasesByContact(contactIds);

        for (Case c : cases) {
            if (c.ContactId == null || c.Status == STATUS_CLOSED) {
                continue;
            }
            Integer current = openCountByContact.containsKey(c.ContactId) ? openCountByContact.get(c.ContactId) : 0;
            if (current >= maxOpen) {
                c.addError(
                    'This customer already has ' +
                        current +
                        ' open cases. Please add a comment to an existing case instead of opening a new one.'
                );
            } else {
                openCountByContact.put(c.ContactId, current + 1);
            }
        }
    }

    /** True when the customer replying should move the case back to the support team. */
    public static Boolean shouldReopenOnCustomerReply(Case c) {
        return c != null && c.Status == STATUS_WAITING;
    }

    /** Case numbers are stored zero-padded (00001234). Customers usually type "1234". */
    public static String normalizeCaseNumber(String caseNumber) {
        if (String.isBlank(caseNumber)) {
            return null;
        }
        String digits = caseNumber.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) {
            return null;
        }
        return digits.length() >= 8 ? digits : digits.leftPad(8, '0');
    }
}
