/**
 * Minimal trigger framework: one trigger per object, all logic in a handler class.
 *
 * Usage:
 *   trigger CaseTrigger on Case (before insert, ...) { new CaseTriggerHandler().run(); }
 *
 * Handlers can be switched off for a transaction (e.g. data loads, tests):
 *   TriggerHandler.bypass('CaseTriggerHandler');
 */
public virtual class TriggerHandler {
    private static Set<String> bypassedHandlers = new Set<String>();

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public void run() {
        if (!Trigger.isExecuting || isBypassed(getHandlerName())) {
            return;
        }

        switch on Trigger.operationType {
            when BEFORE_INSERT {
                beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                beforeUpdate(Trigger.new, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                beforeDelete(Trigger.oldMap);
            }
            when AFTER_INSERT {
                afterInsert(Trigger.new);
            }
            when AFTER_UPDATE {
                afterUpdate(Trigger.new, Trigger.oldMap);
            }
            when AFTER_DELETE {
                afterDelete(Trigger.oldMap);
            }
            when AFTER_UNDELETE {
                afterUndelete(Trigger.new);
            }
        }
    }

    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    // Override only the events you need.
    protected virtual void beforeInsert(List<SObject> newRecords) {
    }
    protected virtual void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
    }
    protected virtual void beforeDelete(Map<Id, SObject> oldMap) {
    }
    protected virtual void afterInsert(List<SObject> newRecords) {
    }
    protected virtual void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
    }
    protected virtual void afterDelete(Map<Id, SObject> oldMap) {
    }
    protected virtual void afterUndelete(List<SObject> newRecords) {
    }
}
