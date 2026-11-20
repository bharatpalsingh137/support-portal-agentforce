/**
 * All Case-related SOQL lives here (selector pattern), so queries are
 * consistent, reusable and easy to mock. User-facing queries run in USER_MODE
 * so object, field and sharing security are always enforced.
 */
public inherited sharing class CaseSelector {
    private static final String CASE_LIST_FIELDS =
        'Id, CaseNumber, Subject, Status, Priority, Product_Category__c, ' + 'IsClosed, CreatedDate, LastModifiedDate';

    /**
     * Cases for the portal "My Cases" list. Portal users match on ContactId;
     * internal users (for testing in the org) match on CreatedById.
     */
    public static List<Case> selectMyCases(Id userId, Id contactId, String statusFilter, Integer limitSize) {
        String soql = 'SELECT ' + CASE_LIST_FIELDS + ' FROM Case WHERE (CreatedById = :userId';
        if (contactId != null) {
            soql += ' OR ContactId = :contactId';
        }
        soql += ')';

        if (statusFilter == 'Open') {
            soql += ' AND IsClosed = false';
        } else if (statusFilter == 'Closed') {
            soql += ' AND IsClosed = true';
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT :limitSize';

        Map<String, Object> binds = new Map<String, Object>{
            'userId' => userId,
            'contactId' => contactId,
            'limitSize' => limitSize
        };
        return (List<Case>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public static Case selectDetailById(Id caseId) {
        List<Case> cases = [
            SELECT
                Id,
                CaseNumber,
                Subject,
                Description,
                Status,
                Priority,
                Product_Category__c,
                Resolution__c,
                IsClosed,
                ClosedDate,
                CreatedDate,
                CreatedById,
                CreatedBy.Name
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    public static Case selectStatusById(Id caseId) {
        List<Case> cases = [SELECT Id, Status, IsClosed FROM Case WHERE Id = :caseId WITH USER_MODE LIMIT 1];
        return cases.isEmpty() ? null : cases[0];
    }

    public static List<CaseComment> selectComments(Id caseId, Boolean publishedOnly) {
        if (publishedOnly) {
            return [
                SELECT Id, CommentBody, CreatedDate, CreatedById, CreatedBy.Name
                FROM CaseComment
                WHERE ParentId = :caseId AND IsPublished = TRUE
                WITH USER_MODE
                ORDER BY CreatedDate ASC
            ];
        }
        return [
            SELECT Id, CommentBody, CreatedDate, CreatedById, CreatedBy.Name
            FROM CaseComment
            WHERE ParentId = :caseId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    /** Used by the Agentforce actions; includes the contact email to verify the customer. */
    public static Map<String, Case> selectByCaseNumbers(Set<String> caseNumbers) {
        Map<String, Case> result = new Map<String, Case>();
        for (Case c : [
            SELECT
                Id,
                CaseNumber,
                Subject,
                Status,
                Priority,
                IsClosed,
                LastModifiedDate,
                Contact.Email,
                (
                    SELECT CommentBody, CreatedDate
                    FROM CaseComments
                    WHERE IsPublished = TRUE
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                )
            FROM Case
            WHERE CaseNumber IN :caseNumbers
            WITH USER_MODE
        ]) {
            result.put(c.CaseNumber, c);
        }
        return result;
    }

    /** System-mode count used by the trigger to enforce the open-case limit. */
    public static Map<Id, Integer> countOpenCasesByContact(Set<Id> contactIds) {
        Map<Id, Integer> result = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT ContactId cid, COUNT(Id) total
            FROM Case
            WHERE ContactId IN :contactIds AND IsClosed = FALSE
            GROUP BY ContactId
        ]) {
            result.put((Id) ar.get('cid'), (Integer) ar.get('total'));
        }
        return result;
    }

    public static Boolean hasFeedback(Id caseId) {
        return [SELECT COUNT() FROM Case_Feedback__c WHERE Case__c = :caseId WITH USER_MODE] > 0;
    }
}
