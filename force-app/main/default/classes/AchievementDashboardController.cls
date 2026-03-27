/**
 * @description Controller for the Achievement Dashboard LWC component.
 *              Provides targets vs achievements, leaderboard ranking, and
 *              territory drill-down using the dynamic Target_Actual__c model.
 *
 *              Replaces the legacy Target__c-based implementation with
 *              criteria-driven Target_Actual__c + Target_Criteria__c data.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class AchievementDashboardController {

    // ── Get Targets and Achievements (Aggregated) ─────────────────────────────

    /**
     * @description Retrieves aggregated target and achievement values for a user
     *              in a given period, grouped by Target_Criteria__c name.
     *              Returns a single map with keys like Revenue_Target__c, Revenue_Actual__c, etc.
     * @param userId The User Id.
     * @param period The period type ('Monthly' or 'Quarterly').
     * @param year   The four-digit year integer.
     * @return Map of aggregated KPI metric names to their values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTargetsAndAchievements(Id userId, String period, Integer year) {
        Map<String, Object> result = new Map<String, Object>();

        // Derive date range
        Date startDate;
        Date endDate;
        if (period == 'Quarterly') {
            Integer currentMonth = Date.today().month();
            Integer quarterStart = ((currentMonth - 1) / 3) * 3 + 1;
            startDate = Date.newInstance(year, quarterStart, 1);
            endDate = startDate.addMonths(3).addDays(-1);
        } else {
            // Monthly — use current month
            Integer currentMonth = Date.today().month();
            startDate = Date.newInstance(year, currentMonth, 1);
            endDate = startDate.addMonths(1).addDays(-1);
        }

        // Query target actuals for the user within the period
        List<Target_Actual__c> actuals = [
            SELECT Id, Target_Value__c, Achievement_Value__c,
                   Target_Criteria__c, Target_Criteria__r.Name
            FROM Target_Actual__c
            WHERE User__c = :userId
            AND Target_Period__r.Start_Date__c >= :startDate
            AND Target_Period__r.End_Date__c <= :endDate
            AND Target_Criteria__r.Active__c = true
        ];

        // Aggregate by criteria name
        Map<String, Decimal> targetMap = new Map<String, Decimal>();
        Map<String, Decimal> achievementMap = new Map<String, Decimal>();

        for (Target_Actual__c ta : actuals) {
            String criteriaName = ta.Target_Criteria__r.Name;
            if (String.isBlank(criteriaName)) continue;

            // Normalize name for key (e.g., "Revenue Target" → "Revenue")
            String key = criteriaName.trim();

            Decimal tv = ta.Target_Value__c != null ? ta.Target_Value__c : 0;
            Decimal av = ta.Achievement_Value__c != null ? ta.Achievement_Value__c : 0;

            targetMap.put(key, (targetMap.containsKey(key) ? targetMap.get(key) : 0) + tv);
            achievementMap.put(key, (achievementMap.containsKey(key) ? achievementMap.get(key) : 0) + av);
        }

        // Map to expected LWC field names
        result.put('Revenue_Target__c', targetMap.get('Revenue') != null ? targetMap.get('Revenue') : 0);
        result.put('Revenue_Actual__c', achievementMap.get('Revenue') != null ? achievementMap.get('Revenue') : 0);
        result.put('Volume_Target__c', targetMap.get('Volume') != null ? targetMap.get('Volume') : 0);
        result.put('Volume_Actual__c', achievementMap.get('Volume') != null ? achievementMap.get('Volume') : 0);
        result.put('Collection_Target__c', targetMap.get('Collection') != null ? targetMap.get('Collection') : 0);
        result.put('Collection_Actual__c', achievementMap.get('Collection') != null ? achievementMap.get('Collection') : 0);
        result.put('Coverage_Target__c', targetMap.get('Coverage') != null ? targetMap.get('Coverage') : 0);
        result.put('Coverage_Actual__c', achievementMap.get('Coverage') != null ? achievementMap.get('Coverage') : 0);
        result.put('New_Outlet_Target__c', targetMap.get('New Outlets') != null ? targetMap.get('New Outlets') : 0);
        result.put('New_Outlet_Actual__c', achievementMap.get('New Outlets') != null ? achievementMap.get('New Outlets') : 0);

        return result;
    }

    // ── Get Leaderboard ───────────────────────────────────────────────────────

    /**
     * @description Retrieves a leaderboard of top performers for a given period,
     *              ranked by revenue achievement percentage.
     * @param period The period type ('Monthly' or 'Quarterly').
     * @param year   The four-digit year integer.
     * @return List of maps representing top performers.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLeaderboard(String period, Integer year) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        Date startDate;
        Date endDate;
        if (period == 'Quarterly') {
            Integer currentMonth = Date.today().month();
            Integer quarterStart = ((currentMonth - 1) / 3) * 3 + 1;
            startDate = Date.newInstance(year, quarterStart, 1);
            endDate = startDate.addMonths(3).addDays(-1);
        } else {
            Integer currentMonth = Date.today().month();
            startDate = Date.newInstance(year, currentMonth, 1);
            endDate = startDate.addMonths(1).addDays(-1);
        }

        // Get revenue criteria targets grouped by user
        List<AggregateResult> aggResults = [
            SELECT User__c userId,
                   User__r.Name userName,
                   SUM(Target_Value__c) totalTarget,
                   SUM(Achievement_Value__c) totalAchievement
            FROM Target_Actual__c
            WHERE Target_Period__r.Start_Date__c >= :startDate
            AND Target_Period__r.End_Date__c <= :endDate
            AND Target_Criteria__r.Active__c = true
            AND Target_Criteria__r.Name = 'Revenue'
            GROUP BY User__c, User__r.Name
            ORDER BY SUM(Achievement_Value__c) DESC
            LIMIT 20
        ];

        for (AggregateResult ar : aggResults) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id', (Id) ar.get('userId'));
            row.put('User_Name__c', (String) ar.get('userName'));
            row.put('Name', (String) ar.get('userName'));

            Decimal totalTarget = (Decimal) ar.get('totalTarget');
            Decimal totalAchievement = (Decimal) ar.get('totalAchievement');
            totalTarget = totalTarget != null ? totalTarget : 0;
            totalAchievement = totalAchievement != null ? totalAchievement : 0;

            row.put('Revenue_Target__c', totalTarget);
            row.put('Revenue_Actual__c', totalAchievement);
            row.put('Territory__c', '');

            results.add(row);
        }

        return results;
    }

    // ── Get Drill-Down ────────────────────────────────────────────────────────

    /**
     * @description Retrieves a user-level breakdown of targets and achievements
     *              for the subordinates of a given user (manager view).
     * @param userId The manager's User Id.
     * @param period The period type.
     * @param year   The four-digit year integer.
     * @return List of maps with per-user target/achievement breakdowns.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDrillDown(Id userId, String period, Integer year) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        Date startDate;
        Date endDate;
        if (period == 'Quarterly') {
            Integer currentMonth = Date.today().month();
            Integer quarterStart = ((currentMonth - 1) / 3) * 3 + 1;
            startDate = Date.newInstance(year, quarterStart, 1);
            endDate = startDate.addMonths(3).addDays(-1);
        } else {
            Integer currentMonth = Date.today().month();
            startDate = Date.newInstance(year, currentMonth, 1);
            endDate = startDate.addMonths(1).addDays(-1);
        }

        // Get subordinate users
        Set<Id> subordinateIds = TAM_RoleHierarchy_Service.getRoleSubordinateUsers(userId);

        if (subordinateIds.isEmpty()) return results;

        // Get all target actuals for subordinates
        List<Target_Actual__c> allActuals = [
            SELECT Id, User__c, User__r.Name,
                   Target_Value__c, Achievement_Value__c,
                   Target_Criteria__c, Target_Criteria__r.Name
            FROM Target_Actual__c
            WHERE User__c IN :subordinateIds
            AND Target_Period__r.Start_Date__c >= :startDate
            AND Target_Period__r.End_Date__c <= :endDate
            AND Target_Criteria__r.Active__c = true
        ];

        // Group by user, then by criteria name
        Map<Id, Map<String, Object>> userDataMap = new Map<Id, Map<String, Object>>();

        for (Target_Actual__c ta : allActuals) {
            if (!userDataMap.containsKey(ta.User__c)) {
                Map<String, Object> userData = new Map<String, Object>();
                userData.put('Id', ta.User__c);
                userData.put('Name', ta.User__r.Name);
                userData.put('Is_Territory__c', false);
                userData.put('Revenue_Target__c', 0);
                userData.put('Revenue_Actual__c', 0);
                userData.put('Volume_Actual__c', 0);
                userData.put('Collection_Actual__c', 0);
                userData.put('Coverage_Percent__c', 0);
                userDataMap.put(ta.User__c, userData);
            }

            Map<String, Object> userData = userDataMap.get(ta.User__c);
            String criteriaName = ta.Target_Criteria__r.Name;
            Decimal tv = ta.Target_Value__c != null ? ta.Target_Value__c : 0;
            Decimal av = ta.Achievement_Value__c != null ? ta.Achievement_Value__c : 0;

            if (criteriaName == 'Revenue') {
                userData.put('Revenue_Target__c', (Decimal) userData.get('Revenue_Target__c') + tv);
                userData.put('Revenue_Actual__c', (Decimal) userData.get('Revenue_Actual__c') + av);
            } else if (criteriaName == 'Volume') {
                userData.put('Volume_Actual__c', (Decimal) userData.get('Volume_Actual__c') + av);
            } else if (criteriaName == 'Collection') {
                userData.put('Collection_Actual__c', (Decimal) userData.get('Collection_Actual__c') + av);
            } else if (criteriaName == 'Coverage') {
                Decimal coverageTarget = tv > 0 ? tv : 1;
                userData.put('Coverage_Percent__c', (av / coverageTarget * 100).setScale(1, RoundingMode.HALF_UP));
            }
        }

        results.addAll(userDataMap.values());
        return results;
    }
}
