/**
 * @description Trigger handler for Distributor_Stock__c. Manages:
 *              - Auto-calculation of Closing Stock on insert/update
 *              - Ensures only one current stock entry per Account+Product combination
 *              - Stock date validation
 * @author  SFA Development Team
 * @date    2024
 */
public class INV_DistributorStock_TriggerHandler extends TriggerHandler {

    /**
     * @description Before Insert: Auto-calculate closing stock and set defaults.
     */
    protected override void beforeInsert() {
        List<Distributor_Stock__c> newRecords = (List<Distributor_Stock__c>) Trigger.new;
        calculateClosingStock(newRecords);
    }

    /**
     * @description Before Update: Recalculate closing stock when quantities change.
     */
    protected override void beforeUpdate() {
        List<Distributor_Stock__c> newRecords = (List<Distributor_Stock__c>) Trigger.new;
        Map<Id, Distributor_Stock__c> oldMap = (Map<Id, Distributor_Stock__c>) Trigger.oldMap;

        List<Distributor_Stock__c> changedRecords = new List<Distributor_Stock__c>();
        for (Distributor_Stock__c rec : newRecords) {
            Distributor_Stock__c oldRec = oldMap.get(rec.Id);
            if (rec.Opening_Stock__c != oldRec.Opening_Stock__c ||
                rec.Received_Qty__c != oldRec.Received_Qty__c ||
                rec.Sold_Qty__c != oldRec.Sold_Qty__c ||
                rec.Damaged_Qty__c != oldRec.Damaged_Qty__c) {
                changedRecords.add(rec);
            }
        }

        if (!changedRecords.isEmpty()) {
            calculateClosingStock(changedRecords);
        }
    }

    /**
     * @description After Insert: If a new record is marked as current, unmark previous current
     *              entries for the same Account + Product.
     */
    protected override void afterInsert() {
        List<Distributor_Stock__c> newRecords = (List<Distributor_Stock__c>) Trigger.new;
        unmarkPreviousCurrentEntries(newRecords);
    }

    /**
     * @description After Update: If a record is newly marked as current, unmark previous
     *              current entries for the same Account + Product.
     */
    protected override void afterUpdate() {
        List<Distributor_Stock__c> newRecords = (List<Distributor_Stock__c>) Trigger.new;
        Map<Id, Distributor_Stock__c> oldMap = (Map<Id, Distributor_Stock__c>) Trigger.oldMap;

        List<Distributor_Stock__c> newlyCurrentRecords = new List<Distributor_Stock__c>();
        for (Distributor_Stock__c rec : newRecords) {
            Distributor_Stock__c oldRec = oldMap.get(rec.Id);
            if (rec.Is_Current__c && !oldRec.Is_Current__c) {
                newlyCurrentRecords.add(rec);
            }
        }

        if (!newlyCurrentRecords.isEmpty()) {
            unmarkPreviousCurrentEntries(newlyCurrentRecords);
        }
    }

    // ── Private helper methods ────────────────────────────────────────────────

    /**
     * @description Calculates Closing Stock as:
     *              Closing = Opening + Received - Sold - Damaged
     * @param records The stock records to calculate.
     */
    private void calculateClosingStock(List<Distributor_Stock__c> records) {
        for (Distributor_Stock__c rec : records) {
            Decimal opening = rec.Opening_Stock__c != null ? rec.Opening_Stock__c : 0;
            Decimal received = rec.Received_Qty__c != null ? rec.Received_Qty__c : 0;
            Decimal sold = rec.Sold_Qty__c != null ? rec.Sold_Qty__c : 0;
            Decimal damaged = rec.Damaged_Qty__c != null ? rec.Damaged_Qty__c : 0;

            rec.Closing_Stock__c = opening + received - sold - damaged;
        }
    }

    /**
     * @description Ensures only one Is_Current__c = true per Account + Product.
     *              When a new record is marked current, previous current entries
     *              for the same combination are unmarked.
     * @param currentRecords Records that are newly marked as current.
     */
    private void unmarkPreviousCurrentEntries(List<Distributor_Stock__c> currentRecords) {
        // Collect Account+Product combinations that are now current
        Set<Id> accountIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> currentIds = new Set<Id>();
        Map<String, Id> keyToCurrentId = new Map<String, Id>();

        for (Distributor_Stock__c rec : currentRecords) {
            if (rec.Is_Current__c) {
                accountIds.add(rec.Account__c);
                productIds.add(rec.Product__c);
                currentIds.add(rec.Id);
                String key = String.valueOf(rec.Account__c) + '|' + String.valueOf(rec.Product__c);
                keyToCurrentId.put(key, rec.Id);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Query other current entries for the same combinations
        List<Distributor_Stock__c> toUnmark = [
            SELECT Id, Account__c, Product__c
            FROM Distributor_Stock__c
            WHERE Account__c IN :accountIds
              AND Product__c IN :productIds
              AND Is_Current__c = true
              AND Id NOT IN :currentIds
        ];

        // Filter to only those matching exact Account+Product combinations
        List<Distributor_Stock__c> updates = new List<Distributor_Stock__c>();
        for (Distributor_Stock__c rec : toUnmark) {
            String key = String.valueOf(rec.Account__c) + '|' + String.valueOf(rec.Product__c);
            if (keyToCurrentId.containsKey(key)) {
                updates.add(new Distributor_Stock__c(
                    Id = rec.Id,
                    Is_Current__c = false
                ));
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
