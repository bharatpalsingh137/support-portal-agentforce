trigger LogEventTrigger on Log_Event__e(after insert) {
    LogEventSubscriber.saveLogs(Trigger.new);
}
