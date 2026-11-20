/**
 * Trigger handler for Case. Keeps the trigger logic-free and delegates
 * business rules to CaseService so they can be reused and unit tested.
 */
public with sharing class CaseTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(List<SObject> newRecords) {
        List<Case> cases = (List<Case>) newRecords;
        CaseService.applyDefaults(cases);
        CaseService.enforceOpenCaseLimit(cases);
    }

    protected override void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        CaseService.trackWaitingStatus((List<Case>) newRecords, (Map<Id, Case>) oldMap);
    }
}
