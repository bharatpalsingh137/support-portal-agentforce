/**
 * Apex controller for the portal Lightning Web Components
 * (caseCreateWizard, myCases, caseDetailTimeline, caseFeedback).
 *
 * Security: "with sharing" plus USER_MODE queries/DML in CaseSelector and here,
 * so customers only ever see and change records they have access to.
 */
public with sharing class PortalCaseController {
    private static final Integer MAX_CASES = 200;
    private static final String GENERIC_ERROR = 'Something went wrong. Please try again or contact support.';

    @TestVisible
    private static Id cachedContactId;
    private static Boolean contactLoaded = false;

    // ---------------------------------------------------------------------
    // Read methods (cacheable: no DML or logging allowed here)
    // ---------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<Case> getMyCases(String statusFilter) {
        try {
            return CaseSelector.selectMyCases(UserInfo.getUserId(), currentContactId(), statusFilter, MAX_CASES);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static CaseDetail getCaseDetail(Id caseId) {
        if (caseId == null) {
            throw toAuraException(new PortalException('Case Id is required.'));
        }
        try {
            Case record = CaseSelector.selectDetailById(caseId);
            if (record == null) {
                throw new PortalException('Case not found, or you do not have access to it.');
            }

            Boolean externalUser = isExternalUser();
            CaseDetail detail = new CaseDetail();
            detail.record = record;
            detail.hasFeedback = CaseSelector.hasFeedback(caseId);
            detail.timeline = buildTimeline(record, CaseSelector.selectComments(caseId, externalUser));
            return detail;
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FAQ__c> searchFaqs(String term, String category) {
        try {
            return FaqService.search(term, category, 5);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCategories() {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : Case.Product_Category__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    // ---------------------------------------------------------------------
    // Write methods
    // ---------------------------------------------------------------------

    @AuraEnabled
    public static Case createCase(String subject, String description, String category) {
        if (String.isBlank(subject)) {
            throw toAuraException(new PortalException('Please enter a subject.'));
        }
        try {
            Case newCase = new Case(
                Subject = subject.trim().left(255),
                Description = description,
                Product_Category__c = category,
                Source_Channel__c = CaseService.CHANNEL_PORTAL,
                ContactId = currentContactId()
            );
            Database.insert(newCase, AccessLevel.USER_MODE);

            return [
                SELECT Id, CaseNumber, Subject, Status, Priority
                FROM Case
                WHERE Id = :newCase.Id
                WITH USER_MODE
            ];
        } catch (Exception e) {
            Logger.error('PortalCaseController.createCase', e);
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static void addComment(Id caseId, String body) {
        if (caseId == null || String.isBlank(body)) {
            throw toAuraException(new PortalException('Please enter a comment.'));
        }
        try {
            Case record = CaseSelector.selectStatusById(caseId);
            if (record == null) {
                throw new PortalException('Case not found, or you do not have access to it.');
            }

            CaseComment comment = new CaseComment(ParentId = caseId, CommentBody = body.trim().left(4000));
            if (!isExternalUser()) {
                // Portal users' comments are always public; internal users choose explicitly.
                comment.IsPublished = true;
            }
            Database.insert(comment, AccessLevel.USER_MODE);

            if (CaseService.shouldReopenOnCustomerReply(record)) {
                record.Status = CaseService.STATUS_WORKING;
                Database.update(record, AccessLevel.USER_MODE);
            }
        } catch (Exception e) {
            Logger.error('PortalCaseController.addComment', e, caseId);
            throw toAuraException(e);
        }
    }

    @AuraEnabled
    public static Id submitFeedback(Id caseId, Integer rating, String comments) {
        if (caseId == null) {
            throw toAuraException(new PortalException('Case Id is required.'));
        }
        if (rating == null || rating < 1 || rating > 5) {
            throw toAuraException(new PortalException('Please choose a rating between 1 and 5 stars.'));
        }
        try {
            Case record = CaseSelector.selectStatusById(caseId);
            if (record == null) {
                throw new PortalException('Case not found, or you do not have access to it.');
            }
            if (!record.IsClosed) {
                throw new PortalException('You can leave feedback once your case is closed.');
            }
            if (CaseSelector.hasFeedback(caseId)) {
                throw new PortalException('You have already left feedback for this case. Thank you!');
            }

            Case_Feedback__c feedback = new Case_Feedback__c(
                Case__c = caseId,
                Rating__c = rating,
                Comments__c = comments?.left(5000)
            );
            Database.insert(feedback, AccessLevel.USER_MODE);
            return feedback.Id;
        } catch (Exception e) {
            if (!(e instanceof PortalException)) {
                Logger.error('PortalCaseController.submitFeedback', e, caseId);
            }
            throw toAuraException(e);
        }
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    @TestVisible
    private static List<TimelineItem> buildTimeline(Case record, List<CaseComment> comments) {
        List<TimelineItem> items = new List<TimelineItem>();
        items.add(
            new TimelineItem(
                'created-' + record.Id,
                'created',
                'Case opened',
                record.Description,
                record.CreatedBy?.Name,
                record.CreatedDate,
                true
            )
        );

        for (CaseComment c : comments) {
            Boolean fromCustomer = c.CreatedById == record.CreatedById;
            items.add(
                new TimelineItem(
                    c.Id,
                    'comment',
                    fromCustomer ? 'You replied' : 'Support replied',
                    c.CommentBody,
                    c.CreatedBy?.Name,
                    c.CreatedDate,
                    fromCustomer
                )
            );
        }

        if (record.IsClosed && record.ClosedDate != null) {
            items.add(
                new TimelineItem(
                    'closed-' + record.Id,
                    'closed',
                    'Case closed',
                    record.Resolution__c,
                    null,
                    record.ClosedDate,
                    false
                )
            );
        }
        return items;
    }

    private static Id currentContactId() {
        if (!contactLoaded) {
            List<User> users = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            cachedContactId = users.isEmpty() ? null : users[0].ContactId;
            contactLoaded = true;
        }
        return cachedContactId;
    }

    private static Boolean isExternalUser() {
        return UserInfo.getUserType() != 'Standard';
    }

    /** Converts any exception into a message that is safe and useful to show in the UI. */
    @TestVisible
    private static AuraHandledException toAuraException(Exception e) {
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        }

        String message = GENERIC_ERROR;
        if (e instanceof PortalException) {
            message = e.getMessage();
        } else if (e instanceof DmlException) {
            // Shows validation rule / addError messages written for end users.
            message = ((DmlException) e).getDmlMessage(0);
        }

        AuraHandledException auraException = new AuraHandledException(message);
        auraException.setMessage(message);
        return auraException;
    }

    // ---------------------------------------------------------------------
    // DTOs returned to LWC
    // ---------------------------------------------------------------------

    public class PortalException extends Exception {
    }

    public class CaseDetail {
        @AuraEnabled
        public Case record;
        @AuraEnabled
        public Boolean hasFeedback;
        @AuraEnabled
        public List<TimelineItem> timeline;
    }

    public class TimelineItem {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String itemType;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String body;
        @AuraEnabled
        public String author;
        @AuraEnabled
        public Datetime timestamp;
        @AuraEnabled
        public Boolean isCustomer;

        public TimelineItem(
            String id,
            String itemType,
            String title,
            String body,
            String author,
            Datetime timestamp,
            Boolean isCustomer
        ) {
            this.id = id;
            this.itemType = itemType;
            this.title = title;
            this.body = body;
            this.author = author;
            this.timestamp = timestamp;
            this.isCustomer = isCustomer;
        }
    }

    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}
