/**
 * @description Scheduler for monthly incentive calculation. Runs for the previous
 *              month's period. Schedule via:
 *              System.schedule('TAM Monthly Incentive Calc', '0 0 2 1 * ?', new TAM_IncentiveCalculation_Scheduler());
 *              (Runs at 2 AM on the 1st of every month)
 */
public class TAM_IncentiveCalculation_Scheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        // Find the period that ended most recently (previous month)
        Date today = Date.today();
        List<Target_Period__c> periods = [
            SELECT Id, Name, Start_Date__c, End_Date__c
            FROM Target_Period__c
            WHERE End_Date__c < :today
            AND Is_Active__c = true
            ORDER BY End_Date__c DESC
            LIMIT 1
        ];

        if (!periods.isEmpty()) {
            Database.executeBatch(
                new TAM_IncentiveCalculation_Batch(periods[0].Id), 50
            );
        }
    }
}
