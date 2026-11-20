/**
 * Generates a short AI summary of a case with the "Case_Summary" Prompt Builder
 * template and saves it to Case.AI_Summary__c.
 *
 * Deploy this folder only to an org with Agentforce / Prompt Builder enabled:
 *   sf project deploy start --source-dir agentforce-extension
 *
 * Can be called from:
 *   - an LWC or quick action  (summarize)
 *   - Flow or an agent action (summarizeCases)
 */
public with sharing class CaseSummaryService {
    public static final String TEMPLATE_API_NAME = 'Case_Summary';

    @AuraEnabled
    public static String summarize(Id caseId) {
        try {
            String summary = generate(caseId);
            update as user new Case(Id = caseId, AI_Summary__c = summary);
            return summary;
        } catch (Exception e) {
            Logger.error('CaseSummaryService.summarize', e, caseId);
            AuraHandledException ex = new AuraHandledException('Could not generate a summary right now.');
            ex.setMessage('Could not generate a summary right now.');
            throw ex;
        }
    }

    @InvocableMethod(
        label='Summarize Case'
        description='Generates an AI summary of a case and stores it on the case record.'
        category='Support Portal'
    )
    public static List<String> summarizeCases(List<Id> caseIds) {
        List<String> summaries = new List<String>();
        List<Case> updates = new List<Case>();
        for (Id caseId : caseIds) {
            // One LLM call per case; agents and quick actions send one id at a time.
            String summary;
            try {
                summary = generate(caseId);
                updates.add(new Case(Id = caseId, AI_Summary__c = summary));
            } catch (Exception e) {
                Logger.error('CaseSummaryService.summarizeCases', e, caseId);
                summary = 'Summary unavailable.';
            }
            summaries.add(summary);
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false, AccessLevel.USER_MODE);
        }
        return summaries;
    }

    @TestVisible
    private static String generate(Id caseId) {
        ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
        caseValue.value = new Map<String, String>{ 'id' => caseId };

        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;
        input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Case' => caseValue };
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptBuilderPreview';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
            TEMPLATE_API_NAME,
            input
        );
        if (output.generations == null || output.generations.isEmpty()) {
            throw new SummaryException('The prompt template returned no text.');
        }
        return output.generations[0].text;
    }

    public class SummaryException extends Exception {
    }
}
