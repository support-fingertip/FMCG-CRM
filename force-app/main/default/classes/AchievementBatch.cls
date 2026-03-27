public class AchievementBatch implements Database.Batchable<SObject>, Database.Stateful {

    public List<Target_Criteria__c> criterias;

    public AchievementBatch() {
        criterias = [
            SELECT Id, Name, Object__c, Operator__c, Field__c,
                   Date_Field__c, User_Field__c, Filters__c, Filter_Logic__c
            FROM Target_Criteria__c
            WHERE Active__c = TRUE
        ];
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id,Name, Start_Date__c, End_Date__c
                                         FROM Target_Period__c
                                         WHERE Start_Date__c <= :Date.today()
                                         AND End_Date__c >= :Date.today() AND Is_Active__c = true]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        Target_Period__c periodRec = (Target_Period__c) scope[0];
        Date startDate = periodRec.Start_Date__c;
        Date endDate   = periodRec.End_Date__c;

        for (Target_Criteria__c crit : criterias) {

            // Build dynamic SOQL
            String soql = DynamicSOQLBuilder.buildSOQL(crit, startDate, endDate);

            // Query aggregated results
            List<AggregateResult> results = Database.query(soql);

            Map<Id, Decimal> userToValue = new Map<Id, Decimal>();
            for (AggregateResult ar : results) {
                userToValue.put((Id) ar.get(crit.User_Field__c), (Decimal) ar.get('expr0'));
            }

            // Load targets
            List<Target_Actual__c> targets = [
                SELECT Id, User__c, Achievement_Value__c
                FROM Target_Actual__c
                WHERE Target_Criteria__c = :crit.Id
                AND Target_Period__c = :periodRec.Id
            ];

            // Update targets
            for (Target_Actual__c t : targets) {
                if (userToValue.containsKey(t.User__c)) {
                    t.Achievement_Value__c = userToValue.get(t.User__c);
                } else {
                    t.Achievement_Value__c = 0;
                }
                t.Last_Updated__c = System.now();
            }

            update targets;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Achievement batch completed.');
    }
}