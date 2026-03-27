public class AchievementBatchV2 implements Database.Batchable<SObject>, Database.Stateful {

    // Start: return all target rows belonging to ACTIVE periods
    public Database.QueryLocator start(Database.BatchableContext bc) {

        Date today = Date.today();

        return Database.getQueryLocator([
            SELECT Id, User__c, Target_Criteria__c, Target_Period__c,
                   Target_Period__r.Start_Date__c, Target_Period__r.End_Date__c,
                   User__r.ManagerId
            FROM Target_Actual__c
            WHERE Target_Period__r.Start_Date__c <= :today
            AND Target_Period__r.End_Date__c >= :today
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Target_Actual__c> scope) {

        if (scope.isEmpty()) return;

        // 1) GROUP RECORDS BY CRITERIA & PERIOD
        Map<String, List<Target_Actual__c>> groupMap = new Map<String, List<Target_Actual__c>>();

        for (Target_Actual__c row : scope) {
            String key = row.Target_Criteria__c + '-' + row.Target_Period__c;
            if (!groupMap.containsKey(key)) {
                groupMap.put(key, new List<Target_Actual__c>());
            }
            groupMap.get(key).add(row);
        }

        // 2) Load all criterias in this scope
        Set<Id> criteriaIds = new Set<Id>();
        for (Target_Actual__c t : scope) criteriaIds.add(t.Target_Criteria__c);

        Map<Id, Target_Criteria__c> critMap = new Map<Id, Target_Criteria__c>(
            [
                SELECT Id, Name, Object__c, Operator__c, Field__c,
                       Date_Field__c, User_Field__c, Filters__c, Filter_Logic__c
                FROM Target_Criteria__c
                WHERE Id IN :criteriaIds
            ]
        );

        // Results collection
        List<Target_Actual__c> updates = new List<Target_Actual__c>();

        // 3) PROCESS EACH (CRITERIA, PERIOD) GROUP
        for (String key : groupMap.keySet()) {

            List<Target_Actual__c> rows = groupMap.get(key);

            // Extract CriteriaId + PeriodId
            List<String> splitKey = key.split('-');
            Id critId   = splitKey[0];
            Id periodId = splitKey[1];

            Target_Criteria__c crit = critMap.get(critId);

            // Period dates (same for all rows in group)
            Date startD = rows[0].Target_Period__r.Start_Date__c;
            Date endD   = rows[0].Target_Period__r.End_Date__c;

            // Collect user IDs in this chunk (IMPORTANT)
            Set<Id> userIds = new Set<Id>();
            for (Target_Actual__c ta : rows) userIds.add(ta.User__c);

            // Build SOQL for ONLY THESE USERS
            DynamicSOQLBuilderV2.QueryContext ctx =
                DynamicSOQLBuilderV2.fromCriteria(crit, startD, endD);

            String soql = DynamicSOQLBuilderV2.buildSOQL(ctx);
            soql += ' HAVING ' + crit.User_Field__c + ' IN :userIds';

            System.debug('Final SOQL => ' + soql);

            List<AggregateResult> agg = Database.query(soql);

            // Map user → achievement
            Map<Id, Decimal> userAchMap = new Map<Id, Decimal>();
            for (AggregateResult ar : agg) {
                userAchMap.put(
                    (Id) ar.get(crit.User_Field__c),
                    (Decimal) ar.get('expr1')
                );
            }

            // Assign achievement values to Target_Actual__c rows
            for (Target_Actual__c ta : rows) {
                ta.Achievement_Value__c =
                    userAchMap.containsKey(ta.User__c)
                        ? userAchMap.get(ta.User__c)
                        : 0;

                ta.Last_Updated__c = System.now();
                updates.add(ta);
            }
        }

        if (!updates.isEmpty()) update updates;

        // 4) Run partial rollups ONLY for impacted users
        RollupEngineV2.run(scope);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('AchievementBatchV3 completed successfully.');
    }
}