/**
 * @description Batch job for bulk incentive calculation across all Target_Actual__c
 *              records for a given period. Processes in chunks and creates/updates
 *              Incentive__c records via TAM_IncentiveCalculation_Service.
 */
public class TAM_IncentiveCalculation_Batch implements Database.Batchable<SObject>, Database.Stateful {

    private Id periodId;
    private Integer totalProcessed = 0;
    private Integer totalIncentivesCreated = 0;

    /**
     * @param periodId The Target_Period__c Id to calculate incentives for.
     */
    public TAM_IncentiveCalculation_Batch(Id periodId) {
        this.periodId = periodId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, User__c, Target_Criteria__c, Target_Criteria__r.Name,
                   Target_Value__c, Achievement_Value__c,
                   Target_Period__c, Target_Period__r.Start_Date__c,
                   Target_Period__r.End_Date__c
            FROM Target_Actual__c
            WHERE Target_Period__c = :periodId
            AND Target_Criteria__r.Active__c = true
            AND Target_Value__c > 0
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Target_Actual__c> scope) {
        if (scope.isEmpty()) return;

        List<Incentive__c> results = TAM_IncentiveCalculation_Service.calculateForTargetActuals(scope, periodId);

        totalProcessed += scope.size();
        totalIncentivesCreated += results.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('TAM_IncentiveCalculation_Batch completed. Processed: ' +
            totalProcessed + ', Incentives created/updated: ' + totalIncentivesCreated);
    }
}
