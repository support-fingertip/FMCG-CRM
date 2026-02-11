/**
 * @description Controller for the Achievement Dashboard LWC component.
 *              Provides targets vs achievements, leaderboard ranking, territory
 *              drill-down, and aggregated KPI summaries for FMCG sales performance.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class AchievementDashboardController {

    // ── Get Targets and Achievements ────────────────────────────────────────────

    /**
     * @description Retrieves target records with achievement values for a user
     *              in a given month/year.
     * @param userId The Salesperson (User) Id.
     * @param month  The month (e.g. 'January' or '01').
     * @param year   The four-digit year string.
     * @return List of Target__c records with their Target_Line__c achievements.
     */
    @AuraEnabled(cacheable=true)
    public static List<Target__c> getTargetsAndAchievements(Id userId, String month, String year) {
        return [
            SELECT Id, Name, Target_Type__c, Target_Period__c, Month__c, Year__c,
                   Salesperson__c, Salesperson__r.Name,
                   Territory__c, Territory__r.Name,
                   Target_Value__c, Achievement_Value__c, Achievement_Percent__c,
                   Status__c,
                   (SELECT Id, Name, Product__c, Product__r.Name,
                           Product_Category__c, Product_Category__r.Name,
                           Target_Qty__c, Achievement_Qty__c,
                           Target_Value__c, Achievement_Value__c,
                           Achievement_Percent__c
                    FROM Target_Lines__r
                    ORDER BY Product__r.Name)
            FROM Target__c
            WHERE Salesperson__c = :userId
            AND Month__c = :month
            AND Year__c = :year
            ORDER BY Target_Type__c
        ];
    }

    // ── Get Leaderboard ─────────────────────────────────────────────────────────

    /**
     * @description Retrieves a leaderboard of top performers for a given period
     *              and target type, ranked by achievement percentage.
     * @param month      The month.
     * @param year       The year.
     * @param targetType The type of target (e.g. 'Revenue', 'Volume', 'Collection').
     * @return List of Target__c records sorted by achievement, limited to top 20.
     */
    @AuraEnabled(cacheable=true)
    public static List<Target__c> getLeaderboard(String month, String year, String targetType) {
        String query = 'SELECT Id, Salesperson__c, Salesperson__r.Name, ' +
                       'Salesperson__r.SmallPhotoUrl, ' +
                       'Territory__c, Territory__r.Name, ' +
                       'Target_Value__c, Achievement_Value__c, Achievement_Percent__c ' +
                       'FROM Target__c ' +
                       'WHERE Month__c = :month AND Year__c = :year';

        if (String.isNotBlank(targetType)) {
            query += ' AND Target_Type__c = :targetType';
        }

        query += ' AND Achievement_Percent__c != null ' +
                 'ORDER BY Achievement_Percent__c DESC ' +
                 'LIMIT 20';

        return Database.query(query);
    }

    // ── Get Territory Drill-Down ────────────────────────────────────────────────

    /**
     * @description Retrieves a territory-level breakdown of targets and achievements,
     *              useful for managers drilling down into their team's performance.
     * @param parentTerritoryId The parent Territory_Master__c Id.
     * @param month The month.
     * @param year  The year.
     * @return List of aggregated territory-level performance records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDrillDown(Id parentTerritoryId, String month, String year) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        // Get child territories
        List<Territory_Master__c> childTerritories = [
            SELECT Id, Name, Territory_Code__c
            FROM Territory_Master__c
            WHERE Id = :parentTerritoryId
            AND Is_Active__c = true
            ORDER BY Name
        ];

        Set<Id> territoryIds = new Set<Id>();
        Map<Id, Territory_Master__c> territoryMap = new Map<Id, Territory_Master__c>();
        for (Territory_Master__c t : childTerritories) {
            territoryIds.add(t.Id);
            territoryMap.put(t.Id, t);
        }

        if (territoryIds.isEmpty()) {
            return results;
        }

        // Aggregate targets by territory
        List<AggregateResult> aggResults = [
            SELECT Territory__c territoryId,
                   Target_Type__c targetType,
                   SUM(Target_Value__c) totalTarget,
                   SUM(Achievement_Value__c) totalAchievement,
                   COUNT(Id) targetCount
            FROM Target__c
            WHERE Territory__c IN :territoryIds
            AND Month__c = :month
            AND Year__c = :year
            GROUP BY Territory__c, Target_Type__c
            ORDER BY Territory__c
        ];

        for (AggregateResult ar : aggResults) {
            Map<String, Object> row = new Map<String, Object>();
            Id territoryId = (Id)ar.get('territoryId');
            Territory_Master__c territory = territoryMap.get(territoryId);

            row.put('territoryId', territoryId);
            row.put('territoryName', territory != null ? territory.Name : '');
            row.put('territoryCode', territory != null ? territory.Territory_Code__c : '');
            row.put('targetType', (String)ar.get('targetType'));

            Decimal totalTarget = (Decimal)ar.get('totalTarget');
            Decimal totalAchievement = (Decimal)ar.get('totalAchievement');
            totalTarget = totalTarget != null ? totalTarget : 0;
            totalAchievement = totalAchievement != null ? totalAchievement : 0;

            row.put('totalTarget', totalTarget);
            row.put('totalAchievement', totalAchievement);
            row.put('achievementPercent', totalTarget > 0
                ? (totalAchievement / totalTarget * 100).setScale(2, RoundingMode.HALF_UP)
                : 0);
            row.put('targetCount', (Integer)ar.get('targetCount'));

            results.add(row);
        }

        return results;
    }

    // ── Get KPI Summary ─────────────────────────────────────────────────────────

    /**
     * @description Retrieves aggregated KPI metrics for a user in a given month/year.
     *              Includes revenue achievement, volume, collection, visit metrics, etc.
     * @param userId The Salesperson (User) Id.
     * @param month  The month.
     * @param year   The year.
     * @return Map of KPI metric names to their computed values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getKPISummary(Id userId, String month, String year) {
        Map<String, Object> kpis = new Map<String, Object>();

        // Target-based KPIs
        List<Target__c> targets = [
            SELECT Id, Target_Type__c, Target_Value__c, Achievement_Value__c, Achievement_Percent__c
            FROM Target__c
            WHERE Salesperson__c = :userId
            AND Month__c = :month
            AND Year__c = :year
        ];

        Decimal revenueTarget = 0;
        Decimal revenueAchievement = 0;
        Decimal collectionTarget = 0;
        Decimal collectionAchievement = 0;
        Decimal volumeTarget = 0;
        Decimal volumeAchievement = 0;

        for (Target__c t : targets) {
            Decimal tv = t.Target_Value__c != null ? t.Target_Value__c : 0;
            Decimal av = t.Achievement_Value__c != null ? t.Achievement_Value__c : 0;
            if (t.Target_Type__c == 'Revenue') {
                revenueTarget += tv;
                revenueAchievement += av;
            } else if (t.Target_Type__c == 'Collection') {
                collectionTarget += tv;
                collectionAchievement += av;
            } else if (t.Target_Type__c == 'Volume') {
                volumeTarget += tv;
                volumeAchievement += av;
            }
        }

        kpis.put('revenueTarget', revenueTarget);
        kpis.put('revenueAchievement', revenueAchievement);
        kpis.put('revenuePercent', revenueTarget > 0
            ? (revenueAchievement / revenueTarget * 100).setScale(2, RoundingMode.HALF_UP) : 0);
        kpis.put('collectionTarget', collectionTarget);
        kpis.put('collectionAchievement', collectionAchievement);
        kpis.put('collectionPercent', collectionTarget > 0
            ? (collectionAchievement / collectionTarget * 100).setScale(2, RoundingMode.HALF_UP) : 0);
        kpis.put('volumeTarget', volumeTarget);
        kpis.put('volumeAchievement', volumeAchievement);
        kpis.put('volumePercent', volumeTarget > 0
            ? (volumeAchievement / volumeTarget * 100).setScale(2, RoundingMode.HALF_UP) : 0);

        // Derive date range from month/year for visit and order queries
        Date startDate = deriveStartDate(month, year);
        Date endDate = startDate.addMonths(1).addDays(-1);

        // Visit KPIs
        AggregateResult[] visitAgg = [
            SELECT COUNT(Id) totalVisits
            FROM Visit__c
            WHERE Salesperson__c = :userId
            AND Visit_Date__c >= :startDate
            AND Visit_Date__c <= :endDate
            AND Visit_Status__c = 'Completed'
        ];
        Integer totalVisits = visitAgg.isEmpty() ? 0 : (Integer)visitAgg[0].get('totalVisits');
        kpis.put('totalVisits', totalVisits);

        Integer productiveVisits = [
            SELECT COUNT()
            FROM Visit__c
            WHERE Salesperson__c = :userId
            AND Visit_Date__c >= :startDate
            AND Visit_Date__c <= :endDate
            AND Visit_Status__c = 'Completed'
            AND Is_Productive__c = true
        ];
        kpis.put('productiveVisits', productiveVisits);
        kpis.put('strikeRate', totalVisits > 0
            ? (Decimal.valueOf(productiveVisits) / Decimal.valueOf(totalVisits) * 100).setScale(2, RoundingMode.HALF_UP)
            : 0);

        // Order KPIs
        AggregateResult[] orderAgg = [
            SELECT COUNT(Id) totalOrders, SUM(Total_Net_Amount__c) totalOrderValue
            FROM Sales_Order__c
            WHERE Salesperson__c = :userId
            AND Order_Date__c >= :startDate
            AND Order_Date__c <= :endDate
            AND Status__c NOT IN ('Cancelled', 'Rejected')
        ];
        if (!orderAgg.isEmpty()) {
            kpis.put('totalOrders', (Integer)orderAgg[0].get('totalOrders'));
            Decimal ov = (Decimal)orderAgg[0].get('totalOrderValue');
            kpis.put('totalOrderValue', ov != null ? ov : 0);
        } else {
            kpis.put('totalOrders', 0);
            kpis.put('totalOrderValue', 0);
        }

        // Lines per call (average order lines per visit)
        Integer totalOrderCount = (Integer)kpis.get('totalOrders');
        kpis.put('linesPerCall', totalVisits > 0
            ? (Decimal.valueOf(totalOrderCount) / Decimal.valueOf(totalVisits)).setScale(2, RoundingMode.HALF_UP)
            : 0);

        // Attendance days
        Integer attendanceDays = [
            SELECT COUNT()
            FROM Day_Attendance__c
            WHERE Salesperson__c = :userId
            AND Attendance_Date__c >= :startDate
            AND Attendance_Date__c <= :endDate
            AND Status__c IN ('Started', 'Completed')
        ];
        kpis.put('attendanceDays', attendanceDays);

        return kpis;
    }

    // ── Private Helper: Derive Start Date ───────────────────────────────────────

    /**
     * @description Converts month name/number + year into a Date representing the
     *              first day of that month.
     */
    private static Date deriveStartDate(String month, String year) {
        Map<String, Integer> monthMap = new Map<String, Integer>{
            'January' => 1, 'February' => 2, 'March' => 3,
            'April' => 4, 'May' => 5, 'June' => 6,
            'July' => 7, 'August' => 8, 'September' => 9,
            'October' => 10, 'November' => 11, 'December' => 12
        };

        Integer monthNum;
        if (monthMap.containsKey(month)) {
            monthNum = monthMap.get(month);
        } else {
            try {
                monthNum = Integer.valueOf(month);
            } catch (Exception e) {
                monthNum = Date.today().month();
            }
        }

        Integer yearNum;
        try {
            yearNum = Integer.valueOf(year);
        } catch (Exception e) {
            yearNum = Date.today().year();
        }

        return Date.newInstance(yearNum, monthNum, 1);
    }
}
