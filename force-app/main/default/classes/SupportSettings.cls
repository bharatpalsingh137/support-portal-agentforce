/**
 * Reads Support_Settings__mdt (record "Default"). Falls back to safe defaults
 * if the record is missing. Tests can inject values through testOverride.
 */
public inherited sharing class SupportSettings {
    public static final Integer DEFAULT_AUTO_CLOSE_DAYS = 7;
    public static final Integer DEFAULT_MAX_OPEN_CASES = 10;

    @TestVisible
    private static Support_Settings__mdt testOverride;
    private static Support_Settings__mdt cached;

    public static Support_Settings__mdt get() {
        if (testOverride != null) {
            return testOverride;
        }
        if (cached == null) {
            cached = Support_Settings__mdt.getInstance('Default');
            if (cached == null) {
                cached = new Support_Settings__mdt(
                    Auto_Close_Days__c = DEFAULT_AUTO_CLOSE_DAYS,
                    Max_Open_Cases__c = DEFAULT_MAX_OPEN_CASES
                );
            }
        }
        return cached;
    }

    public static Integer autoCloseDays() {
        Decimal value = get().Auto_Close_Days__c;
        return value == null ? DEFAULT_AUTO_CLOSE_DAYS : value.intValue();
    }

    public static Integer maxOpenCasesPerContact() {
        Decimal value = get().Max_Open_Cases__c;
        return value == null ? DEFAULT_MAX_OPEN_CASES : value.intValue();
    }
}
