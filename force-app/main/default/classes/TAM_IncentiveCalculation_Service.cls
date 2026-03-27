/**
 * @description Service class for computing incentive payouts from target achievements
 *              and incentive slab configurations. Matches achievement percentages to
 *              slab ranges and calculates payout amounts.
 */
public with sharing class TAM_IncentiveCalculation_Service {

    /**
     * @description Calculate incentives for a list of Target_Actual__c records in a period.
     *              Creates or updates Incentive__c records with calculated amounts.
     * @param actuals List of Target_Actual__c records to process.
     * @param periodId The Target_Period__c Id for this calculation run.
     * @return List of Incentive__c records that were upserted.
     */
    public static List<Incentive__c> calculateForTargetActuals(List<Target_Actual__c> actuals, Id periodId) {
        if (actuals == null || actuals.isEmpty()) return new List<Incentive__c>();

        // Load all active slabs (ordered by Sort_Order for deterministic matching)
        List<Incentive_Slab__c> allSlabs = [
            SELECT Id, Name, Target_Criteria__c, Min_Percent__c, Max_Percent__c,
                   Payout_Type__c, Payout_Value__c, Multiplier__c,
                   Is_Active__c, Effective_From__c, Effective_To__c
            FROM Incentive_Slab__c
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c ASC, Min_Percent__c ASC
        ];

        if (allSlabs.isEmpty()) return new List<Incentive__c>();

        // Load existing incentives for this period to support upsert
        Set<Id> userIds = new Set<Id>();
        Set<Id> criteriaIds = new Set<Id>();
        for (Target_Actual__c ta : actuals) {
            userIds.add(ta.User__c);
            criteriaIds.add(ta.Target_Criteria__c);
        }

        Map<String, Incentive__c> existingMap = new Map<String, Incentive__c>();
        for (Incentive__c inc : [
            SELECT Id, Salesperson__c, Target_Actual__c, Target_Criteria__c, Target_Period__c
            FROM Incentive__c
            WHERE Target_Period__c = :periodId
            AND Salesperson__c IN :userIds
            AND Target_Criteria__c IN :criteriaIds
        ]) {
            String key = inc.Salesperson__c + '-' + inc.Target_Criteria__c;
            existingMap.put(key, inc);
        }

        Date today = Date.today();
        List<Incentive__c> results = new List<Incentive__c>();

        for (Target_Actual__c ta : actuals) {
            Decimal targetValue = ta.Target_Value__c != null ? ta.Target_Value__c : 0;
            Decimal achievementValue = ta.Achievement_Value__c != null ? ta.Achievement_Value__c : 0;

            // Skip if no target set
            if (targetValue == 0) continue;

            Decimal achievementPercent = (achievementValue / targetValue) * 100;

            // Find matching slab
            Incentive_Slab__c matchedSlab = findMatchingSlab(achievementPercent, ta.Target_Criteria__c, allSlabs, today);

            if (matchedSlab == null) continue;

            // Compute payout
            Decimal payout = computePayout(targetValue, achievementPercent, matchedSlab);

            // Build incentive record
            String key = ta.User__c + '-' + ta.Target_Criteria__c;
            Incentive__c inc;

            if (existingMap.containsKey(key)) {
                inc = existingMap.get(key);
            } else {
                inc = new Incentive__c();
                inc.Salesperson__c = ta.User__c;
                inc.Target_Criteria__c = ta.Target_Criteria__c;
                inc.Target_Period__c = periodId;
            }

            inc.Target_Actual__c = ta.Id;
            inc.Achievement_Percent__c = achievementPercent.setScale(2, RoundingMode.HALF_UP);
            inc.Incentive_Slab_Ref__c = matchedSlab.Id;
            inc.Multiplier__c = matchedSlab.Multiplier__c;
            inc.Base_Amount__c = targetValue;
            inc.Calculated_Amount__c = payout.setScale(2, RoundingMode.HALF_UP);
            inc.Status__c = 'Calculated';

            results.add(inc);
        }

        if (!results.isEmpty()) {
            upsert results;
        }

        return results;
    }

    /**
     * @description Find the matching incentive slab for a given achievement percentage.
     *              Checks criteria-specific slabs first, then falls back to universal slabs.
     * @param achievementPercent The calculated achievement percentage.
     * @param criteriaId The Target_Criteria__c Id to match against.
     * @param allSlabs All active slabs to search through.
     * @param today Current date for effective date filtering.
     * @return The matched Incentive_Slab__c, or null if no match found.
     */
    public static Incentive_Slab__c findMatchingSlab(Decimal achievementPercent, Id criteriaId,
                                                      List<Incentive_Slab__c> allSlabs, Date today) {
        // First pass: criteria-specific slabs
        for (Incentive_Slab__c slab : allSlabs) {
            if (slab.Target_Criteria__c != criteriaId) continue;
            if (isSlabMatch(slab, achievementPercent, today)) return slab;
        }

        // Second pass: universal slabs (Target_Criteria__c is null)
        for (Incentive_Slab__c slab : allSlabs) {
            if (slab.Target_Criteria__c != null) continue;
            if (isSlabMatch(slab, achievementPercent, today)) return slab;
        }

        return null;
    }

    /**
     * @description Check if a slab matches the achievement percentage and effective dates.
     */
    private static Boolean isSlabMatch(Incentive_Slab__c slab, Decimal achievementPercent, Date today) {
        // Check percentage range
        if (achievementPercent < slab.Min_Percent__c || achievementPercent > slab.Max_Percent__c) {
            return false;
        }

        // Check effective dates (null means always effective)
        if (slab.Effective_From__c != null && today < slab.Effective_From__c) return false;
        if (slab.Effective_To__c != null && today > slab.Effective_To__c) return false;

        return true;
    }

    /**
     * @description Compute the payout amount based on slab rules.
     * @param targetValue The base target value.
     * @param achievementPercent The achievement percentage.
     * @param slab The matched incentive slab.
     * @return The calculated payout amount.
     */
    public static Decimal computePayout(Decimal targetValue, Decimal achievementPercent, Incentive_Slab__c slab) {
        Decimal multiplier = slab.Multiplier__c != null ? slab.Multiplier__c : 1;
        Decimal payoutValue = slab.Payout_Value__c != null ? slab.Payout_Value__c : 0;

        if (slab.Payout_Type__c == 'Percentage') {
            // Percentage of target value × multiplier
            return targetValue * (payoutValue / 100) * multiplier;
        } else {
            // Fixed amount × multiplier
            return payoutValue * multiplier;
        }
    }
}
